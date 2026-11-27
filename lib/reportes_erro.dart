import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/resumo.dart';
import 'package:testeapp/tema.dart';

/// Tela "Reportes de erro" (CLAUDE.md 5.9; tabela `reportes_erro`).
///
/// - Autor (professor): vê os reportes sobre os **próprios** conteúdos, sem o
///   nome de quem reportou (o RLS de `perfis` não libera).
/// - Admin: vê todos, com o nome de quem reportou, e pode marcar como
///   resolvido (policy `reportes_erro_resolver`, só admin).
class ReportesErro extends StatefulWidget {
  const ReportesErro({super.key, required this.ehAdmin});

  final bool ehAdmin;

  @override
  State<ReportesErro> createState() => _ReportesErroState();
}

class _ReportesErroState extends State<ReportesErro> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _futuro = _carregar();

  /// O RLS já limita ao que cada um pode ver. Para o professor, a lista fica
  /// só com os conteúdos dele (sem os reportes que ele mesmo enviou sobre
  /// conteúdos de colegas, decisão 3 de 27/11).
  Future<List<Map<String, dynamic>>> _carregar() async {
    final campos = widget.ehAdmin
        ? 'id, descricao, status, criado_em, resolvido_em, microconteudo_id, '
            'microconteudos(titulo, codigo), perfis(nome)'
        : 'id, descricao, status, criado_em, resolvido_em, microconteudo_id, '
            'microconteudos!inner(titulo, codigo, autor_id)';
    var consulta = _supabase.from('reportes_erro').select(campos);
    if (!widget.ehAdmin) {
      consulta = consulta.eq('microconteudos.autor_id', _supabase.auth.currentUser!.id);
    }
    final dados = await consulta.order('criado_em', ascending: false);
    return List<Map<String, dynamic>>.from(dados);
  }

  void _recarregar() {
    setState(() => _futuro = _carregar());
  }

  Future<void> _resolver(Map<String, dynamic> reporte) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Marcar como resolvido?'),
        content: const Text('O reporte sai da aba "Abertos" e vai para "Resolvidos".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Marcar'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    final mensageiro = ScaffoldMessenger.of(context);
    try {
      await _supabase.from('reportes_erro').update({
        'status': 'resolvido',
        'resolvido_em': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', reporte['id'] as int);
      if (!mounted) return;
      mensageiro.showSnackBar(const SnackBar(content: Text('Reporte marcado como resolvido.')));
      _recarregar();
    } catch (erro, pilha) {
      debugPrint('Erro ao resolver reporte: $erro\n$pilha');
      mensageiro.showSnackBar(const SnackBar(
        content: Text('Não foi possível marcar como resolvido. Verifique a conexão.'),
      ));
    }
  }

  Future<void> _abrirConteudo(Map<String, dynamic> reporte) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Resumo(idMicroconteudo: reporte['microconteudo_id'].toString()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reportes de erro'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Abertos'), Tab(text: 'Resolvidos')],
          ),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _futuro,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              debugPrint('Erro ao carregar reportes: ${snapshot.error}');
              return _mensagem(
                'Não foi possível carregar os reportes. Verifique a conexão.',
                acao: FilledButton(
                  onPressed: _recarregar,
                  child: const Text('Tentar novamente'),
                ),
              );
            }
            final todos = snapshot.data ?? const <Map<String, dynamic>>[];
            final abertos = todos.where((r) => r['status'] == 'aberto').toList();
            final resolvidos = todos.where((r) => r['status'] == 'resolvido').toList();
            return TabBarView(
              children: [
                _lista(abertos, 'Nenhum reporte aberto.'),
                _lista(resolvidos, 'Nenhum reporte resolvido.'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _lista(List<Map<String, dynamic>> reportes, String vazio) {
    return RefreshIndicator(
      onRefresh: () async => _recarregar(),
      child: reportes.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Center(child: Text(vazio)),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [for (final r in reportes) _cartao(r)],
            ),
    );
  }

  Widget _cartao(Map<String, dynamic> reporte) {
    final tema = Theme.of(context);
    final micro = reporte['microconteudos'] as Map<String, dynamic>?;
    final nome = (reporte['perfis'] as Map<String, dynamic>?)?['nome'] as String?;
    final aberto = reporte['status'] == 'aberto';
    final criado = DateTime.tryParse((reporte['criado_em'] ?? '').toString())?.toLocal();
    final resolvido = DateTime.tryParse((reporte['resolvido_em'] ?? '').toString())?.toLocal();

    final linhaData = StringBuffer(criado == null ? '' : 'Enviado em ${_data(criado)}');
    if (widget.ehAdmin && nome != null && nome.trim().isNotEmpty) {
      linhaData.write(' por $nome');
    }
    if (!aberto && resolvido != null) {
      linhaData.write(' · resolvido em ${_data(resolvido)}');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  aberto ? Icons.flag : Icons.check_circle,
                  color: aberto ? tema.colorScheme.error : AppTema.acerto,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (micro?['titulo'] ?? 'Conteúdo').toString(),
                    style: tema.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if ((micro?['codigo'] ?? '').toString().isNotEmpty)
              Text(micro!['codigo'].toString(), style: tema.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text((reporte['descricao'] ?? '').toString()),
            const SizedBox(height: 8),
            Text(linhaData.toString(), style: tema.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _abrirConteudo(reporte),
                  child: const Text('Abrir o conteúdo'),
                ),
                if (widget.ehAdmin && aberto)
                  FilledButton(
                    onPressed: () => _resolver(reporte),
                    child: const Text('Marcar como resolvido'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mensagem(String texto, {Widget? acao}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(texto, textAlign: TextAlign.center),
            if (acao != null) ...[
              const SizedBox(height: 16),
              acao,
            ],
          ],
        ),
      ),
    );
  }
}

/// Data no formato dd/mm/aaaa (o app não usa o pacote intl).
String _data(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
