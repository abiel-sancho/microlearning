import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/resumo.dart';
import 'package:testeapp/tema.dart';

/// Tópicos de uma disciplina, agrupados por unidade.
///
/// Caminho do aluno: Disciplina → Unidade → Tópico → Microconteúdo.
/// - Aluno (e professor de outra disciplina): só vê tópicos que já têm
///   microconteúdo publicado (regra 5.1).
/// - Professor da disciplina e admin: veem todos os tópicos, com o código
///   e a quantidade de microconteúdos (é neles que o conteúdo será criado).
class Topicos extends StatefulWidget {
  const Topicos({super.key, required this.idDisciplina});

  final String idDisciplina;

  @override
  State<Topicos> createState() => _TopicosState();
}

class _Unidade {
  _Unidade(this.numero, this.nome, this.topicos);
  final int numero;
  final String nome;
  final List<_Topico> topicos;
}

class _Topico {
  _Topico(this.id, this.numero, this.codigo, this.titulo, this.microconteudos);
  final int id;
  final int numero;
  final String codigo;
  final String titulo;

  /// Microconteúdos que quem está logado pode ver (o RLS do banco já filtra),
  /// sem os arquivados, na ordem de exibição.
  final List<Map<String, dynamic>> microconteudos;

  int get publicados =>
      microconteudos.where((m) => m['status'] == 'publicado').length;
}

/// Resultado da carga: nome da disciplina, unidades e se a pessoa vê tudo.
class _Dados {
  _Dados(this.nomeDisciplina, this.unidades, this.veTudo);
  final String nomeDisciplina;
  final List<_Unidade> unidades;
  final bool veTudo;
}

class _TopicosState extends State<Topicos> {
  final _supabase = Supabase.instance.client;
  late Future<_Dados> _futuro = _carregar();

  // ---------------------------------------------------------------------------
  // Dados
  // ---------------------------------------------------------------------------

  Future<_Dados> _carregar() async {
    final idDisciplina = int.parse(widget.idDisciplina);

    // Uma consulta traz unidades → tópicos → microconteúdos da disciplina.
    final linhas = await _supabase
        .from('unidades')
        .select('numero, nome, disciplinas(nome), '
            'topicos(id, numero, codigo, titulo, '
            'microconteudos(id, titulo, codigo, status, ordem))')
        .eq('disciplina_id', idDisciplina);

    final veTudo = await _podeVerTodosOsTopicos(idDisciplina);

    var nomeDisciplina = '';
    final unidades = <_Unidade>[];
    for (final u in linhas) {
      nomeDisciplina = (u['disciplinas']?['nome'] as String?) ?? nomeDisciplina;

      final topicos = <_Topico>[];
      for (final t in (u['topicos'] as List)) {
        final micros = List<Map<String, dynamic>>.from(t['microconteudos'] as List)
            .where((m) => m['status'] != 'arquivado')
            .where((m) => veTudo || m['status'] == 'publicado')
            .toList()
          ..sort((a, b) => (a['ordem'] as int).compareTo(b['ordem'] as int));

        final topico = _Topico(
          t['id'] as int,
          t['numero'] as int,
          t['codigo'] as String,
          t['titulo'] as String,
          micros,
        );
        // Regra 5.1: para o aluno, tópico sem publicado não aparece.
        if (veTudo || topico.publicados > 0) topicos.add(topico);
      }
      topicos.sort((a, b) => a.numero.compareTo(b.numero));

      // Unidade sem nenhum tópico visível também não aparece.
      if (topicos.isNotEmpty) {
        unidades.add(_Unidade(u['numero'] as int, u['nome'] as String, topicos));
      }
    }
    unidades.sort((a, b) => a.numero.compareTo(b.numero));

    return _Dados(nomeDisciplina, unidades, veTudo);
  }

  /// Admin vê tudo; professor vê tudo só nas disciplinas em que atua.
  Future<bool> _podeVerTodosOsTopicos(int idDisciplina) async {
    final usuario = _supabase.auth.currentUser;
    if (usuario == null) return false;
    try {
      final perfil = await _supabase
          .from('perfis')
          .select('papel')
          .eq('id', usuario.id)
          .maybeSingle();
      final papel = perfil?['papel'];
      if (papel == 'admin') return true;
      if (papel != 'professor') return false;

      final vinculo = await _supabase
          .from('professor_disciplinas')
          .select('disciplina_id')
          .eq('professor_id', usuario.id)
          .eq('disciplina_id', idDisciplina)
          .maybeSingle();
      return vinculo != null;
    } catch (erro, pilha) {
      // Na dúvida, mostra a visão do aluno (a mais restrita).
      debugPrint('Erro ao carregar o papel: $erro\n$pilha');
      return false;
    }
  }

  void _tentarDeNovo() {
    setState(() => _futuro = _carregar());
  }

  // ---------------------------------------------------------------------------
  // Textos
  // ---------------------------------------------------------------------------

  static String _doisDigitos(int n) => n.toString().padLeft(2, '0');

  static String _quantidade(int n) =>
      n == 1 ? '1 microconteúdo' : '$n microconteúdos';

  static String _rotuloStatus(Object? status) => switch (status) {
        'rascunho' => 'Rascunho',
        'em_revisao' => 'Em revisão',
        'publicado' => 'Publicado',
        _ => '',
      };

  // ---------------------------------------------------------------------------
  // Interface
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Dados>(
      future: _futuro,
      builder: (context, snapshot) {
        final dados = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
            ),
            title: Text(dados?.nomeDisciplina ?? ''),
          ),
          body: _corpo(context, snapshot),
        );
      },
    );
  }

  Widget _corpo(BuildContext context, AsyncSnapshot<_Dados> snapshot) {
    if (snapshot.hasError) {
      debugPrint('Erro ao carregar tópicos: ${snapshot.error}');
      return _mensagem(
        'Não foi possível carregar os tópicos.\nVerifique sua internet e tente de novo.',
        comBotao: true,
      );
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final dados = snapshot.data!;
    if (dados.unidades.isEmpty) {
      return _mensagem('Ainda não há conteúdos publicados nesta disciplina.');
    }

    final cores = Theme.of(context).colorScheme;
    return CustomScrollView(
      primary: false,
      slivers: <Widget>[
        for (final unidade in dados.unidades) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Unidade ${_doisDigitos(unidade.numero)} · ${unidade.nome}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cores.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: unidade.topicos.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _cartaoTopico(context, unidade.topicos[index], dados.veTudo),
            ),
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
      ],
    );
  }

  /// Card do tópico: mesmo estilo de antes (AppTema.cartao, texto centralizado),
  /// com altura livre para não cortar títulos longos.
  Widget _cartaoTopico(BuildContext context, _Topico topico, bool veTudo) {
    final estiloDetalhe = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return GestureDetector(
      onTap: () => _abrirMicroconteudos(context, topico, veTudo),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: AppTema.cartao(context),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_doisDigitos(topico.numero)} · ${topico.titulo}',
              textAlign: TextAlign.center,
            ),
            if (veTudo) ...[
              const SizedBox(height: 4),
              Text(
                '${topico.codigo} · ${_quantidade(topico.microconteudos.length)}',
                textAlign: TextAlign.center,
                style: estiloDetalhe,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Folha de baixo com os microconteúdos do tópico, na ordem de exibição.
  void _abrirMicroconteudos(BuildContext context, _Topico topico, bool veTudo) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (contextoFolha) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(contextoFolha).size.height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Text(
                  topico.titulo,
                  style: Theme.of(contextoFolha).textTheme.titleMedium,
                ),
                Text(
                  topico.codigo,
                  style: Theme.of(contextoFolha).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (topico.microconteudos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Nenhum microconteúdo neste tópico ainda.'),
                  ),
                for (final micro in topico.microconteudos)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.article_outlined),
                    title: Text(micro['titulo'] as String),
                    subtitle: Text([
                      (micro['codigo'] as String?) ?? 'sem código',
                      if (veTudo) _rotuloStatus(micro['status']),
                    ].join(' · ')),
                    onTap: () {
                      Navigator.pop(contextoFolha);
                      // TODO(resumo): o Resumo ainda lê a tabela antiga `topico`;
                      // ao ser adaptado, o parâmetro vira o id do microconteúdo.
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Resumo(idTopico: micro['id'].toString()),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mensagem(String texto, {bool comBotao = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(texto, textAlign: TextAlign.center),
            if (comBotao) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _tentarDeNovo,
                child: const Text('Tentar de novo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
