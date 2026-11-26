import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/criar_conteudo.dart';
import 'package:testeapp/resumo.dart';
import 'package:testeapp/tema.dart';

/// "Meus conteúdos": os microconteúdos de quem está logado (autor), menos os
/// arquivados, do mais recente para o mais antigo.
///
/// - Tocar abre a leitura (`Resumo`).
/// - Editar e apagar só aparecem em rascunho; o banco também só permite isso
///   (policies `microconteudos_editar_rascunho` e `microconteudos_apagar_rascunho`).
class MeusResumos extends StatefulWidget {
  const MeusResumos({super.key});

  @override
  State<MeusResumos> createState() => _MinhasState();
}

class _MinhasState extends State<MeusResumos> {
  final _supabase = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> _futuro = _carregar();

  Future<List<Map<String, dynamic>>> _carregar() async {
    final usuario = _supabase.auth.currentUser;
    if (usuario == null) return [];
    final linhas = await _supabase
        .from('microconteudos')
        .select('id, titulo, codigo, status, topicos(codigo, titulo)')
        .eq('autor_id', usuario.id)
        .neq('status', 'arquivado')
        .order('atualizado_em', ascending: false);
    return List<Map<String, dynamic>>.from(linhas);
  }

  Future<void> _recarregar() async {
    final futuro = _carregar();
    setState(() => _futuro = futuro);
    await futuro;
  }

  Future<void> _abrir(Map<String, dynamic> micro) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Resumo(idMicroconteudo: micro['id'].toString()),
      ),
    );
  }

  Future<void> _editar(Map<String, dynamic> micro) async {
    final salvou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CriarConteudoScreen(idMicroconteudo: micro['id'] as int),
      ),
    );
    if (salvou == true && mounted) _recarregar();
  }

  Future<void> _apagar(Map<String, dynamic> micro) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Excluir rascunho?'),
        content: Text('"${micro['titulo']}" e suas questões serão apagados.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: Text('Sim', style: TextStyle(color: Theme.of(contexto).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    try {
      // O RLS só apaga rascunho do próprio autor; as questões vão junto (cascade).
      final apagados = await _supabase
          .from('microconteudos')
          .delete()
          .eq('id', micro['id'])
          .select('id');
      if (!mounted) return;
      _mensagem(apagados.isEmpty
          ? 'Não foi possível excluir: o conteúdo não é mais rascunho.'
          : 'Rascunho excluído.');
      _recarregar();
    } catch (erro) {
      debugPrint('Erro ao excluir rascunho: $erro');
      _mensagem('Não foi possível excluir. Verifique sua internet e tente de novo.');
    }
  }

  void _mensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Meus conteúdos'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint('Erro ao carregar meus conteúdos: ${snapshot.error}');
            return _aviso('Não foi possível carregar seus conteúdos.\n'
                'Verifique sua internet e tente de novo.', comBotao: true);
          }
          final lista = snapshot.data ?? const [];

          return RefreshIndicator(
            onRefresh: _recarregar,
            child: lista.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 120),
                      _aviso('Você ainda não criou nenhum microconteúdo.\n'
                          'Use "Inserir microconteúdo" no menu ou "Criar microconteúdo" '
                          'na folha de um tópico.'),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: lista.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _cartao(context, lista[i]),
                  ),
          );
        },
      ),
    );
  }

  /// Cartão no mesmo estilo de antes (AppTema.cartao), agora com tópico e status.
  Widget _cartao(BuildContext context, Map<String, dynamic> micro) {
    final tema = Theme.of(context);
    final detalhe = tema.textTheme.bodySmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );
    final topico = micro['topicos'] as Map<String, dynamic>?;
    final rascunho = micro['status'] == 'rascunho';

    return GestureDetector(
      onTap: () => _abrir(micro),
      child: Container(
        decoration: AppTema.cartao(context),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (micro['titulo'] as String?) ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    topico == null ? '' : '${topico['codigo']} · ${topico['titulo']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: detalhe,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(micro['codigo'] as String?) ?? 'sem código'} · '
                    '${_rotuloStatus(micro['status'] as String?)}',
                    style: detalhe,
                  ),
                ],
              ),
            ),
            if (rascunho) ...[
              IconButton(
                tooltip: 'Editar rascunho',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editar(micro),
              ),
              IconButton(
                tooltip: 'Excluir rascunho',
                icon: const Icon(Icons.delete),
                onPressed: () => _apagar(micro),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _rotuloStatus(String? status) => switch (status) {
        'rascunho' => 'Rascunho',
        'em_revisao' => 'Em revisão',
        'publicado' => 'Publicado',
        _ => status ?? '',
      };

  Widget _aviso(String texto, {bool comBotao = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(texto, textAlign: TextAlign.center),
            if (comBotao) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _recarregar, child: const Text('Tentar de novo')),
            ],
          ],
        ),
      ),
    );
  }
}
