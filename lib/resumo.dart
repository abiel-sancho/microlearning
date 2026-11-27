import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/questoes_aluno.dart';
import 'package:testeapp/tema.dart';

/// Leitura de um microconteúdo (tabela `microconteudos`).
///
/// Mostra o conteúdo do jeito que o aluno verá: título, código, tempo,
/// objetivo, conteúdo central (Quill só leitura), exemplo resolvido (só se
/// houver) e referências. Quem pode abrir é decidido pelo RLS do banco
/// (policy `microconteudos_leitura`): publicado para todos; rascunho só para o
/// autor; em revisão para os professores da disciplina; admin vê tudo.
class Resumo extends StatefulWidget {
  const Resumo({super.key, required this.idMicroconteudo});

  final String idMicroconteudo;

  @override
  State<Resumo> createState() => _ResumoState();
}

class _ResumoState extends State<Resumo> {
  final _supabase = Supabase.instance.client;

  bool _carregando = true;
  String? _erro;

  /// Linha do microconteúdo; nula quando não existe ou o RLS não libera.
  Map<String, dynamic>? _micro;

  QuillController? _conteudoController;
  QuillController? _exemploController;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _conteudoController?.dispose();
    _exemploController?.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final id = int.tryParse(widget.idMicroconteudo);
    if (id == null) {
      setState(() {
        _carregando = false;
        _micro = null;
      });
      return;
    }

    try {
      final linha = await _supabase
          .from('microconteudos')
          .select('id, titulo, codigo, status, objetivo, tempo_estimado_min, '
              'conteudo_central, exemplo, referencias, '
              'topicos(codigo, titulo), questoes(count)')
          .eq('id', id)
          .maybeSingle();

      if (!mounted) return;

      // Troca os controladores antigos (caso de "puxar para atualizar").
      _conteudoController?.dispose();
      _exemploController?.dispose();
      _conteudoController = _controladorLeitura(linha?['conteudo_central']);
      _exemploController = _controladorLeitura(linha?['exemplo']);

      setState(() {
        _micro = linha;
        _erro = null;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar o conteúdo. Verifique a conexão.';
        _carregando = false;
      });
    }
  }

  /// Monta um controlador Quill só de leitura a partir do Delta salvo pelo
  /// formulário (`document.toDelta().toJson()`). Nulo quando não há texto.
  QuillController? _controladorLeitura(dynamic delta) {
    if (delta is! List || delta.isEmpty) return null;
    try {
      final documento = Document.fromJson(delta);
      if (documento.isEmpty()) return null;
      return QuillController(
        document: documento,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    } catch (_) {
      // Delta inválido: trata como "sem texto" em vez de travar a tela.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topico = _micro?['topicos'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text((topico?['titulo'] ?? '').toString()),
        actions: [
          IconButton(
            tooltip: 'Ir para Disciplinas',
            onPressed: () => irParaDisciplinas(context),
            icon: const Icon(Icons.menu_book),
          ),
        ],
      ),
      body: _corpo(context),
    );
  }

  Widget _corpo(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null) {
      return _aviso(context, Icons.wifi_off, _erro!, comBotao: true);
    }
    final micro = _micro;
    if (micro == null) {
      return _aviso(context, Icons.block, 'Conteúdo indisponível.');
    }

    final questoes = micro['questoes'];
    final totalQuestoes = (questoes is List && questoes.isNotEmpty)
        ? (questoes.first['count'] as int? ?? 0)
        : 0;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _carregar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _cabecalho(context, micro),
                const SizedBox(height: 16),
                _secao(
                  context,
                  null,
                  _conteudoController == null
                      ? const Text('Este conteúdo ainda não tem texto.')
                      : _leitorQuill(_conteudoController!),
                ),
                if (_exemploController != null) ...[
                  const SizedBox(height: 16),
                  _secao(context, 'Exemplo resolvido', _leitorQuill(_exemploController!)),
                ],
                ..._referencias(context, micro),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              // Não publicado (autor ou revisor conferindo): abre em prévia,
              // sem gravar respostas.
              child: FilledButton.icon(
                onPressed: totalQuestoes == 0
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuestoesAluno(
                              idMicroconteudo: micro['id'] as int,
                              previa: micro['status'] != 'publicado',
                            ),
                          ),
                        ),
                icon: const Icon(Icons.quiz),
                label: Text(totalQuestoes == 0
                    ? 'Sem questões'
                    : 'Questões · $totalQuestoes'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Título, código, tempo, selo de status (se não publicado) e objetivo.
  Widget _cabecalho(BuildContext context, Map<String, dynamic> micro) {
    final tema = Theme.of(context);
    final detalhe = tema.textTheme.bodySmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );
    final tempo = micro['tempo_estimado_min'];
    final objetivo = (micro['objetivo'] as String?)?.trim() ?? '';
    final selo = _rotuloStatus(micro['status'] as String?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(micro['titulo'] as String? ?? '', style: tema.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          [
            (micro['codigo'] as String?) ?? 'sem código',
            if (tempo != null) '$tempo min',
          ].join(' · '),
          style: detalhe,
        ),
        if (selo != null) ...[
          const SizedBox(height: 8),
          Chip(
            avatar: const Icon(Icons.visibility_outlined, size: 18),
            label: Text(selo),
            visualDensity: VisualDensity.compact,
          ),
        ],
        if (objetivo.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Objetivo', style: tema.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(objetivo),
        ],
      ],
    );
  }

  /// Avisa quem está vendo algo que o aluno ainda não vê.
  String? _rotuloStatus(String? status) => switch (status) {
        'rascunho' => 'Rascunho: só você vê',
        'em_revisao' => 'Em revisão: ainda não publicado',
        'arquivado' => 'Arquivado',
        _ => null,
      };

  /// Cartão com título opcional, no mesmo estilo dos demais cartões do app.
  Widget _secao(BuildContext context, String? titulo, Widget filho) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTema.cartao(context, sombra: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (titulo != null) ...[
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
          ],
          filho,
        ],
      ),
    );
  }

  /// Editor Quill só de leitura: sem barra, sem cursor, sem rolagem própria.
  Widget _leitorQuill(QuillController controller) {
    return QuillEditor.basic(
      controller: controller,
      config: const QuillEditorConfig(
        scrollable: false, // a lista da tela já rola
        showCursor: false,
        expands: false,
      ),
    );
  }

  List<Widget> _referencias(BuildContext context, Map<String, dynamic> micro) {
    final lista = (micro['referencias'] as List?)
            ?.map((r) => r.toString().trim())
            .where((r) => r.isNotEmpty)
            .toList() ??
        const <String>[];
    if (lista.isEmpty) return const [];

    final tema = Theme.of(context);
    return [
      const SizedBox(height: 16),
      Text('Referências', style: tema.textTheme.titleSmall),
      const SizedBox(height: 4),
      for (final r in lista)
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text('• $r', style: tema.textTheme.bodySmall),
        ),
    ];
  }

  Widget _aviso(BuildContext context, IconData icone, String texto, {bool comBotao = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center),
            if (comBotao) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() => _carregando = true);
                  _carregar();
                },
                child: const Text('Tentar de novo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
