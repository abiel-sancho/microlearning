import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/resumo.dart';
import 'package:testeapp/tema.dart';

/// Revisão por pares (CLAUDE.md 5.6). Não confundir com a revisão espaçada
/// (SM-2) dos alunos, que é o `PainelRevisoes` do Início.
///
/// - [RevisoesPendentes]: fila de quem está logado, pela função
///   `revisoes_pendentes()` (professor: colegas das suas disciplinas, menos os
///   próprios; admin: todos). Atrasados (> 7 dias) primeiro.
/// - [AvaliarConteudo]: ficha, questões e rubrica de 7 critérios. A decisão é
///   gravada e CALCULADA pela função `decidir_revisao()`; a prévia da tela é
///   só informativa.
class RevisoesPendentes extends StatefulWidget {
  const RevisoesPendentes({super.key});

  @override
  State<RevisoesPendentes> createState() => _RevisoesPendentesState();
}

class _RevisoesPendentesState extends State<RevisoesPendentes> {
  final _supabase = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> _futuro = _carregar();

  Future<List<Map<String, dynamic>>> _carregar() async {
    final linhas = await _supabase.rpc('revisoes_pendentes');
    return [for (final l in (linhas as List? ?? const [])) Map<String, dynamic>.from(l as Map)];
  }

  Future<void> _recarregar() async {
    final futuro = _carregar();
    setState(() => _futuro = futuro);
    await futuro;
  }

  Future<void> _abrir(Map<String, dynamic> item) async {
    final decidiu = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AvaliarConteudo(idMicroconteudo: item['microconteudo_id'] as int),
      ),
    );
    if (decidiu == true && mounted) _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar conteúdos')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint('Erro ao carregar a fila de revisão: ${snapshot.error}');
            return _Aviso(
              texto: 'Não foi possível carregar a fila de revisão.\n'
                  'Verifique sua internet e tente de novo.',
              aoTentarDeNovo: _recarregar,
            );
          }
          final lista = snapshot.data ?? const [];

          return RefreshIndicator(
            onRefresh: _recarregar,
            child: lista.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      _Aviso(texto: 'Nenhum conteúdo aguardando revisão.'),
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

  Widget _cartao(BuildContext context, Map<String, dynamic> item) {
    final tema = Theme.of(context);
    final detalhe = tema.textTheme.bodySmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );
    final dias = (item['dias_em_revisao'] as int?) ?? 0;
    final atrasada = item['atrasada'] == true;

    return GestureDetector(
      onTap: () => _abrir(item),
      child: Container(
        decoration: AppTema.cartao(context),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item['titulo'] as String?) ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item['disciplina_sigla'] ?? ''} · ${item['topico_codigo'] ?? ''} · '
                    '${item['topico_titulo'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: detalhe,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Autor: ${item['autor_nome'] ?? '—'} · '
                    '${dias == 0 ? 'enviado hoje' : dias == 1 ? 'em revisão há 1 dia' : 'em revisão há $dias dias'}',
                    style: detalhe,
                  ),
                  if (atrasada) ...[
                    const SizedBox(height: 6),
                    Chip(
                      avatar: Icon(Icons.schedule, size: 18, color: tema.colorScheme.error),
                      label: const Text('Atrasada (mais de 7 dias)'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Avaliar um conteúdo
// -----------------------------------------------------------------------------

/// Critério da rubrica: a chave é a mesma que o banco exige (`rubrica_valida`).
class _Criterio {
  const _Criterio(this.chave, this.nome, this.pergunta);
  final String chave;
  final String nome;
  final String pergunta;
}

const _criterios = [
  _Criterio('precisao_conceitual', 'Precisão conceitual',
      'O conteúdo está correto, sem erros conceituais? (precisa de nota 2 para aprovar)'),
  _Criterio('objetivo', 'Objetivo',
      'Há um único objetivo de aprendizagem, claro e com verbo de Bloom?'),
  _Criterio('alinhamento_objetivo_questoes', 'Alinhamento objetivo–questões',
      'As questões avaliam exatamente o objetivo proposto?'),
  _Criterio('foco_tamanho', 'Foco e tamanho',
      'Trata de uma só ideia e cabe em 5 a 10 minutos?'),
  _Criterio('clareza', 'Clareza',
      'A linguagem é clara e adequada ao ensino médio?'),
  _Criterio('contextualizacao', 'Contextualização',
      'Liga o assunto a situações reais ou ao cotidiano do aluno?'),
  _Criterio('completude', 'Completude',
      'Tem tudo o que o modelo pede (referências, feedbacks, metadados)?'),
];

const _bloom = {
  'lembrar': 'Lembrar',
  'entender': 'Entender',
  'aplicar': 'Aplicar',
  'analisar': 'Analisar',
  'avaliar': 'Avaliar',
  'criar': 'Criar',
};
const _dificuldades = {'facil': 'Fácil', 'media': 'Média', 'dificil': 'Difícil'};

class AvaliarConteudo extends StatefulWidget {
  const AvaliarConteudo({super.key, required this.idMicroconteudo});

  final int idMicroconteudo;

  @override
  State<AvaliarConteudo> createState() => _AvaliarConteudoState();
}

class _AvaliarConteudoState extends State<AvaliarConteudo> {
  final _supabase = Supabase.instance.client;
  final _comentarioController = TextEditingController();

  late Future<Map<String, dynamic>?> _futuro = _carregar();

  /// Nota de cada critério (null = ainda não avaliado).
  final Map<String, int?> _notas = {for (final c in _criterios) c.chave: null};
  bool _enviando = false;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _carregar() async {
    final micro = await _supabase
        .from('microconteudos')
        .select('id, titulo, status, objetivo, publico_alvo, pre_requisitos, '
            'tempo_estimado_min, referencias, nivel_bloom, dificuldade, '
            'topicos(codigo, titulo), '
            'questoes(id, enunciado, alternativas, ordem)')
        .eq('id', widget.idMicroconteudo)
        .maybeSingle();
    if (micro == null) return null;

    // A alternativa correta não vem mais com a questão (migration 10): o
    // revisor (professor da disciplina, conteúdo em revisão) e o admin a
    // recebem pela função gabaritos().
    final linhas = await _supabase
        .rpc('gabaritos', params: {'p_microconteudo': widget.idMicroconteudo}) as List;
    final gabarito = {for (final g in linhas) g['questao_id']: g['correta']};
    for (final q in (micro['questoes'] as List? ?? const [])) {
      (q as Map)['correta'] = gabarito[q['id']];
    }
    return micro;
  }

  bool get _tudoAvaliado => _notas.values.every((n) => n != null);
  int get _total => _notas.values.fold(0, (soma, n) => soma + (n ?? 0));

  /// Prévia da regra do banco (`rubrica_aprovada`): 11 ou mais e 2 em precisão.
  bool get _previaAprovado => _notas['precisao_conceitual'] == 2 && _total >= 11;

  Future<void> _enviar() async {
    if (_enviando) return;
    if (!_tudoAvaliado) {
      _mensagem('Dê uma nota (0, 1 ou 2) a cada um dos 7 critérios.');
      return;
    }
    final comentario = _comentarioController.text.trim();
    if (!_previaAprovado && comentario.isEmpty) {
      _mensagem('Para devolver com ajustes, escreva um comentário ao autor.');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Enviar avaliação?'),
        content: Text(_previaAprovado
            ? 'Nota $_total de 14. O conteúdo será APROVADO e publicado para os alunos, '
                'com um código definitivo.'
            : 'Nota $_total de 14. O conteúdo VOLTARÁ AO AUTOR como rascunho, '
                'com o seu comentário.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _enviando = true);
    try {
      final decisao = await _supabase.rpc('decidir_revisao', params: {
        'p_microconteudo': widget.idMicroconteudo,
        'p_notas': {for (final e in _notas.entries) e.key: e.value},
        'p_comentario': comentario.isEmpty ? null : comentario,
      });
      if (!mounted) return;

      if (decisao == 'aprovado') {
        // O código é gerado pelo banco na publicação; busca para mostrar.
        String? codigo;
        try {
          final linha = await _supabase
              .from('microconteudos')
              .select('codigo')
              .eq('id', widget.idMicroconteudo)
              .maybeSingle();
          codigo = linha?['codigo'] as String?;
        } catch (_) {
          // Sem o código, a mensagem sai sem ele.
        }
        _mensagem(codigo == null
            ? 'Aprovado e publicado!'
            : 'Aprovado e publicado com o código $codigo.');
      } else {
        _mensagem('Devolvido ao autor com ajustes.');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (erro) {
      debugPrint('Erro ao decidir a revisão: $erro');
      _mensagem(erro is PostgrestException && erro.code == 'P0001'
          ? erro.message
          : 'Não foi possível enviar a avaliação. Verifique sua internet e tente de novo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
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
    return FutureBuilder<Map<String, dynamic>?>(
      future: _futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          debugPrint('Erro ao carregar o conteúdo para revisão: ${snapshot.error}');
          return _telaAviso(
            'Não foi possível carregar o conteúdo.\nVerifique sua internet e tente de novo.',
            aoTentarDeNovo: () => setState(() => _futuro = _carregar()),
          );
        }
        final micro = snapshot.data;
        if (micro == null || micro['status'] != 'em_revisao') {
          // Retirado pelo autor, já decidido por outro revisor, ou sem permissão.
          return _telaAviso('Este conteúdo não está mais em revisão.');
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Avaliar conteúdo')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              _ficha(context, micro),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Ler o conteúdo como o aluno verá'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Resumo(idMicroconteudo: micro['id'].toString()),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _titulo(context, 'Questões'),
              ..._questoes(context, micro),
              const SizedBox(height: 24),
              _titulo(context, 'Referências'),
              _referencias(context, micro),
              const SizedBox(height: 24),
              _titulo(context, 'Rubrica'),
              for (final c in _criterios) _criterio(context, c),
              const SizedBox(height: 8),
              _placar(context),
              const SizedBox(height: 16),
              TextField(
                controller: _comentarioController,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: _tudoAvaliado && !_previaAprovado
                      ? 'Comentário ao autor (obrigatório)'
                      : 'Comentário ao autor (opcional)',
                  hintText: 'O que está bom e o que precisa mudar.',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: _enviando
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.gavel),
                label: const Text('Enviar avaliação'),
                onPressed: _enviando ? null : _enviar,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _titulo(BuildContext context, String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _ficha(BuildContext context, Map<String, dynamic> micro) {
    final tema = Theme.of(context);
    final topico = micro['topicos'] as Map<String, dynamic>?;
    final preRequisitos = [for (final p in (micro['pre_requisitos'] as List? ?? const [])) '$p'];
    final tempo = micro['tempo_estimado_min'];

    Widget linha(String rotulo, String? valor) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$rotulo: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: (valor == null || valor.trim().isEmpty) ? '—' : valor),
          ])),
        );

    return Container(
      decoration: AppTema.cartao(context),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text((micro['titulo'] as String?) ?? '', style: tema.textTheme.titleLarge),
          if (topico != null)
            Text('${topico['codigo']} · ${topico['titulo']}',
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
          // Mesma sequência do formulário (etapa 27): a ficha primeiro; as
          // referências vêm depois das questões, como no formulário.
          linha('Objetivo', micro['objetivo'] as String?),
          linha('Nível de Bloom', _bloom[micro['nivel_bloom']]),
          linha('Dificuldade', _dificuldades[micro['dificuldade']]),
          linha('Público-alvo', micro['publico_alvo'] as String?),
          linha('Pré-requisitos', preRequisitos.join('; ')),
          linha('Tempo estimado', tempo == null ? null : '$tempo min'),
        ],
      ),
    );
  }

  /// Referências numa seção própria, depois das questões (ordem do formulário).
  Widget _referencias(BuildContext context, Map<String, dynamic> micro) {
    final referencias = [for (final r in (micro['referencias'] as List? ?? const [])) '$r'];
    return Container(
      decoration: AppTema.cartao(context),
      padding: const EdgeInsets.all(12),
      child: referencias.isEmpty
          ? const Text('—')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in referencias)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $r'),
                  ),
              ],
            ),
    );
  }

  List<Widget> _questoes(BuildContext context, Map<String, dynamic> micro) {
    final tema = Theme.of(context);
    final questoes = [
      for (final q in (micro['questoes'] as List? ?? const [])) Map<String, dynamic>.from(q as Map),
    ]..sort((a, b) => ((a['ordem'] as int?) ?? 0).compareTo((b['ordem'] as int?) ?? 0));

    if (questoes.isEmpty) return [const Text('Nenhuma questão.')];

    return [
      for (var i = 0; i < questoes.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: AppTema.cartao(context),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${i + 1}. ${questoes[i]['enunciado'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              for (final (j, alt) in (questoes[i]['alternativas'] as List? ?? const []).indexed)
                _alternativa(tema, j, Map<String, dynamic>.from(alt as Map),
                    correta: questoes[i]['correta'] == j),
            ],
          ),
        ),
    ];
  }

  Widget _alternativa(ThemeData tema, int indice, Map<String, dynamic> alt,
      {required bool correta}) {
    final letra = String.fromCharCode(65 + indice);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: correta ? AppTema.acertoSuave : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text('$letra) ${alt['texto'] ?? ''}')),
              if (correta) const Icon(Icons.check_circle, color: AppTema.acerto, size: 20),
            ],
          ),
          const SizedBox(height: 2),
          Text('Feedback: ${alt['feedback'] ?? '—'}',
              style: tema.textTheme.bodySmall
                  ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _criterio(BuildContext context, _Criterio c) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(c.pergunta,
              style: tema.textTheme.bodySmall
                  ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('0')),
              ButtonSegment(value: 1, label: Text('1')),
              ButtonSegment(value: 2, label: Text('2')),
            ],
            selected: {if (_notas[c.chave] != null) _notas[c.chave]!},
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            onSelectionChanged: (escolha) =>
                setState(() => _notas[c.chave] = escolha.isEmpty ? null : escolha.first),
          ),
        ],
      ),
    );
  }

  Widget _placar(BuildContext context) {
    final tema = Theme.of(context);
    final String previa;
    final Color cor;
    if (!_tudoAvaliado) {
      final faltam = _notas.values.where((n) => n == null).length;
      previa = 'Faltam $faltam critério(s) para avaliar.';
      cor = tema.colorScheme.onSurfaceVariant;
    } else if (_previaAprovado) {
      previa = 'Prévia: será APROVADO e publicado.';
      cor = AppTema.acerto;
    } else {
      previa = _notas['precisao_conceitual'] != 2
          ? 'Prévia: voltará com ajustes (precisão conceitual precisa de nota 2).'
          : 'Prévia: voltará com ajustes (são necessários 11 pontos).';
      cor = tema.colorScheme.error;
    }
    return Container(
      decoration: AppTema.cartao(context),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nota: $_total de 14', style: tema.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(previa, style: TextStyle(color: cor)),
        ],
      ),
    );
  }

  Widget _telaAviso(String texto, {VoidCallback? aoTentarDeNovo}) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avaliar conteúdo')),
      body: _Aviso(texto: texto, aoTentarDeNovo: aoTentarDeNovo),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, this.aoTentarDeNovo});

  final String texto;
  final VoidCallback? aoTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(texto, textAlign: TextAlign.center),
            if (aoTentarDeNovo != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: aoTentarDeNovo, child: const Text('Tentar de novo')),
            ],
          ],
        ),
      ),
    );
  }
}
