import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/quill_midia.dart';
import 'package:testeapp/criar_questao.dart';
import 'package:testeapp/tema.dart';

/// Formulário guiado de criação de microconteúdo (CLAUDE.md 5.5).
///
/// - Os campos, seus textos de ajuda e a ordem vêm da tabela `modelo_campos`:
///   mudar a tabela muda o formulário, sem nova versão do app.
/// - O conteúdo é gravado em `microconteudos` como RASCUNHO, ligado a um tópico.
///   Para salvar basta o tópico e o título; a conferência completa dos campos
///   obrigatórios será feita no envio para revisão (etapa futura).
/// - O texto do conteúdo central e do exemplo é guardado como Delta do Quill
///   (jsonb), sem conversão para Markdown.
/// - Com [idMicroconteudo], a mesma tela EDITA um rascunho já salvo (vinda de
///   "Meus conteúdos"). O banco só aceita a edição enquanto ele for rascunho
///   do próprio autor (policy `microconteudos_editar_rascunho`).
class CriarConteudoScreen extends StatefulWidget {
  const CriarConteudoScreen({super.key, this.topicoId, this.idMicroconteudo});

  /// Tópico já escolhido (quando a tela é aberta pela folha do tópico).
  final int? topicoId;

  /// Rascunho a editar; nulo = criar um novo.
  final int? idMicroconteudo;

  @override
  State<CriarConteudoScreen> createState() => _CriarConteudoScreenState();
}

// -----------------------------------------------------------------------------
// Dados auxiliares
// -----------------------------------------------------------------------------

/// Uma linha de `modelo_campos`.
class _Campo {
  _Campo(this.campo, this.rotulo, this.instrucao, this.exemplo, this.obrigatorio, this.ordem);
  final String campo;
  final String rotulo;
  final String instrucao;
  final String? exemplo;
  final bool obrigatorio;
  final int ordem;
}

/// Reserva usada só se `modelo_campos` não puder ser lida (mesmo conteúdo do
/// seed 02_modelo_campos.sql), para o formulário nunca ficar vazio.
final List<_Campo> _camposReserva = [
  _Campo('titulo', 'Título', 'Até 60 caracteres. Diga o assunto de forma direta.', null, true, 1),
  _Campo('objetivo', 'Objetivo de aprendizagem', 'Um único objetivo, começando por um verbo da taxonomia de Bloom.', null, true, 2),
  _Campo('nivel_bloom', 'Nível de Bloom', 'lembrar, entender, aplicar, analisar, avaliar ou criar.', null, true, 3),
  _Campo('dificuldade', 'Dificuldade', 'facil, media ou dificil.', null, true, 4),
  _Campo('publico_alvo', 'Público-alvo', 'Para quem é o conteúdo.', null, true, 5),
  _Campo('pre_requisitos', 'Pré-requisitos', 'Até 3 conhecimentos que o aluno precisa ter antes.', null, false, 6),
  _Campo('tempo_estimado_min', 'Tempo estimado', 'Em minutos, no máximo 10.', null, true, 7),
  _Campo('conteudo_central', 'Conteúdo central', 'Uma ideia só.', null, true, 8),
  _Campo('exemplo', 'Exemplo contextualizado e resolvido', 'Opcional.', null, false, 9),
  _Campo('questoes', 'Questões', 'De 2 a 5 questões, com feedback em cada alternativa.', null, true, 10),
  _Campo('referencias', 'Referências', 'Ao menos uma fonte confiável.', null, true, 11),
];

/// Disciplinas em que a pessoa pode criar, com unidades e tópicos.
class _Opcoes {
  _Opcoes(this.papel, this.disciplinas, this.campos);
  final String? papel;
  final List<Map<String, dynamic>> disciplinas;
  final List<_Campo> campos;
}

const _niveisBloom = {
  'lembrar': 'Lembrar',
  'entender': 'Entender',
  'aplicar': 'Aplicar',
  'analisar': 'Analisar',
  'avaliar': 'Avaliar',
  'criar': 'Criar',
};

const _dificuldades = {'facil': 'Fácil', 'media': 'Média', 'dificil': 'Difícil'};

class _CriarConteudoScreenState extends State<CriarConteudoScreen> {
  final _supabase = Supabase.instance.client;

  // Carregado UMA vez (antes era buscado a cada redesenho da tela).
  late final Future<_Opcoes> _futuroOpcoes = _carregarOpcoes();

  // Onde o conteúdo vai ficar.
  int? _disciplinaId;
  int? _unidadeId;
  int? _topicoId;

  // Campos de texto.
  final _tituloController = TextEditingController();
  final _objetivoController = TextEditingController();
  final _publicoController = TextEditingController();
  final List<TextEditingController> _preRequisitos = [TextEditingController()];
  final List<TextEditingController> _referencias = [TextEditingController()];

  // Editores Quill (criados uma vez e liberados no dispose).
  final QuillController _conteudoController = QuillController.basic();
  final FocusNode _conteudoFoco = FocusNode();
  final ScrollController _conteudoRolagem = ScrollController();

  QuillController? _exemploController; // nulo = sem exemplo (recolhido)
  final FocusNode _exemploFoco = FocusNode();
  final ScrollController _exemploRolagem = ScrollController();

  // Demais campos.
  int? _tempo;
  String? _bloom;
  String? _dificuldade;

  // Questões criadas nesta tela. Ficam só em memória até salvar o rascunho;
  // então são gravadas ligadas ao id do microconteúdo recém-criado.
  // Na edição, as que já existem no banco guardam a chave 'id'.
  final List<Map<String, dynamic>> _questoes = [];
  // Na edição: ids das questões já salvas que o professor removeu.
  final List<int> _questoesRemovidas = [];
  static const _minQuestoes = 2;
  static const _maxQuestoes = 5;
  bool get maximoDeQuestoes => _questoes.length >= _maxQuestoes;

  bool _salvando = false;

  bool get _editando => widget.idMicroconteudo != null;

  /// Na edição: motivo para não abrir o formulário (não encontrado, não é
  /// mais rascunho). Nulo = pode editar.
  String? _avisoEdicao;

  @override
  void initState() {
    super.initState();
    _topicoId = widget.topicoId;
    // Redesenha o indicador de preenchimento quando o texto muda.
    for (final c in [_tituloController, _objetivoController, _publicoController]) {
      c.addListener(_atualizar);
    }
    _conteudoController.addListener(_atualizar);
  }

  void _atualizar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _objetivoController.dispose();
    _publicoController.dispose();
    for (final c in [..._preRequisitos, ..._referencias]) {
      c.dispose();
    }
    _conteudoController.dispose();
    _conteudoFoco.dispose();
    _conteudoRolagem.dispose();
    _exemploController?.dispose();
    _exemploFoco.dispose();
    _exemploRolagem.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Dados
  // ---------------------------------------------------------------------------

  Future<_Opcoes> _carregarOpcoes() async {
    final usuario = _supabase.auth.currentUser;
    if (usuario == null) return _Opcoes(null, [], _camposReserva);

    final perfil = await _supabase
        .from('perfis')
        .select('papel')
        .eq('id', usuario.id)
        .maybeSingle();
    final papel = perfil?['papel'] as String?;

    // Disciplinas permitidas: admin = todas; professor = as vinculadas a ele.
    var disciplinas = <Map<String, dynamic>>[];
    if (papel == 'admin' || papel == 'professor') {
      var consulta = _supabase.from('disciplinas').select(
          'id, sigla, nome, unidades(id, numero, nome, topicos(id, numero, codigo, titulo))');
      if (papel == 'professor') {
        final vinculos = await _supabase
            .from('professor_disciplinas')
            .select('disciplina_id')
            .eq('professor_id', usuario.id);
        final ids = [for (final v in vinculos) v['disciplina_id'] as int];
        consulta = consulta.inFilter('id', ids);
      }
      disciplinas = List<Map<String, dynamic>>.from(
          await consulta.order('area_id', ascending: true).order('id', ascending: true));
      // Ordena unidades e tópicos pelo número.
      for (final d in disciplinas) {
        final unidades = List<Map<String, dynamic>>.from(d['unidades'] as List)
          ..sort((a, b) => (a['numero'] as int).compareTo(b['numero'] as int));
        for (final u in unidades) {
          u['topicos'] = List<Map<String, dynamic>>.from(u['topicos'] as List)
            ..sort((a, b) => (a['numero'] as int).compareTo(b['numero'] as int));
        }
        d['unidades'] = unidades;
      }
    }

    // Campos do formulário, na ordem definida pela coordenação.
    var campos = _camposReserva;
    try {
      final linhas = await _supabase
          .from('modelo_campos')
          .select('campo, rotulo, instrucao, exemplo, obrigatorio, ordem')
          // ascending: true é obrigatório: no supabase_flutter o padrão do
          // .order() é DECRESCENTE (o formulário aparecia de trás para frente).
          .order('ordem', ascending: true);
      if (linhas.isNotEmpty) {
        campos = [
          for (final l in linhas)
            _Campo(
              l['campo'] as String,
              l['rotulo'] as String,
              l['instrucao'] as String,
              l['exemplo'] as String?,
              l['obrigatorio'] as bool,
              l['ordem'] as int,
            ),
        ];
      }
    } catch (erro) {
      debugPrint('modelo_campos indisponível, usando a reserva: $erro');
    }

    // Edição: preenche o formulário com o rascunho salvo (inclusive o tópico).
    if (_editando) await _carregarRascunho();

    // Veio pela folha do tópico (ou é edição): pré-seleciona disciplina e unidade.
    if (_topicoId != null) {
      for (final d in disciplinas) {
        for (final u in d['unidades'] as List) {
          if ((u['topicos'] as List).any((t) => t['id'] == _topicoId)) {
            _disciplinaId = d['id'] as int;
            _unidadeId = u['id'] as int;
          }
        }
      }
      if (_disciplinaId == null) _topicoId = null; // tópico fora das permitidas
    }

    return _Opcoes(papel, disciplinas, campos);
  }

  /// Lê o rascunho e suas questões e preenche os campos do formulário.
  Future<void> _carregarRascunho() async {
    final micro = await _supabase
        .from('microconteudos')
        .select('topico_id, autor_id, status, titulo, objetivo, publico_alvo, '
            'pre_requisitos, conteudo_central, exemplo, tempo_estimado_min, '
            'referencias, nivel_bloom, dificuldade, '
            'questoes(id, enunciado, alternativas, ordem)')
        .eq('id', widget.idMicroconteudo!)
        .maybeSingle();

    if (micro == null) {
      _avisoEdicao = 'Conteúdo indisponível.';
      return;
    }
    if (micro['status'] != 'rascunho') {
      _avisoEdicao = 'Este conteúdo não é mais rascunho e não pode ser editado aqui.';
      return;
    }

    _topicoId = micro['topico_id'] as int?;
    _tituloController.text = (micro['titulo'] as String?) ?? '';
    _objetivoController.text = (micro['objetivo'] as String?) ?? '';
    _publicoController.text = (micro['publico_alvo'] as String?) ?? '';
    _preencherLista(_preRequisitos, micro['pre_requisitos']);
    _preencherLista(_referencias, micro['referencias']);

    final conteudo = _documento(micro['conteudo_central']);
    if (conteudo != null) _conteudoController.document = conteudo;
    final exemplo = _documento(micro['exemplo']);
    if (exemplo != null) {
      _exemploController = QuillController(
        document: exemplo,
        selection: const TextSelection.collapsed(offset: 0),
      )..addListener(_atualizar);
    }

    _tempo = micro['tempo_estimado_min'] as int?;
    _bloom = micro['nivel_bloom'] as String?;
    _dificuldade = micro['dificuldade'] as String?;

    final questoes = List<Map<String, dynamic>>.from(micro['questoes'] as List? ?? [])
      ..sort((a, b) => (a['ordem'] as int).compareTo(b['ordem'] as int));

    // A alternativa correta não vem mais com a questão (migration 10): o autor
    // a recebe pela função gabaritos().
    final gabarito = <int, int>{};
    if (questoes.isNotEmpty) {
      final linhas = await _supabase
          .rpc('gabaritos', params: {'p_microconteudo': widget.idMicroconteudo!}) as List;
      for (final g in linhas) {
        gabarito[g['questao_id'] as int] = g['correta'] as int;
      }
    }
    _questoes
      ..clear()
      ..addAll([
        for (final q in questoes)
          {
            'id': q['id'],
            'enunciado': q['enunciado'],
            'alternativas': q['alternativas'],
            'correta': gabarito[q['id']],
          },
      ]);
  }

  /// Troca o conteúdo de uma lista de caixas de texto (mínimo 1 caixa).
  void _preencherLista(List<TextEditingController> lista, dynamic valores) {
    final textos = [for (final v in (valores as List? ?? const [])) v.toString()];
    for (final c in lista) {
      c.dispose();
    }
    lista
      ..clear()
      ..addAll([for (final t in textos) TextEditingController(text: t)]);
    if (lista.isEmpty) lista.add(TextEditingController());
  }

  /// Delta salvo → documento do Quill. Nulo se vazio ou inválido.
  static Document? _documento(dynamic delta) {
    if (delta is! List || delta.isEmpty) return null;
    try {
      return Document.fromJson(delta);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _unidadesDe(_Opcoes o) {
    final d = o.disciplinas.where((d) => d['id'] == _disciplinaId);
    return d.isEmpty ? [] : List<Map<String, dynamic>>.from(d.first['unidades'] as List);
  }

  List<Map<String, dynamic>> _topicosDe(_Opcoes o) {
    final u = _unidadesDe(o).where((u) => u['id'] == _unidadeId);
    return u.isEmpty ? [] : List<Map<String, dynamic>>.from(u.first['topicos'] as List);
  }

  static List<String> _textos(List<TextEditingController> lista) =>
      [for (final c in lista) c.text.trim()]..removeWhere((t) => t.isEmpty);

  static String? _ouNulo(String texto) => texto.trim().isEmpty ? null : texto.trim();

  // ---------------------------------------------------------------------------
  // Preenchimento (indicador no topo)
  // ---------------------------------------------------------------------------

  bool _preenchido(String campo) => switch (campo) {
        'titulo' => _tituloController.text.trim().isNotEmpty,
        'objetivo' => _objetivoController.text.trim().isNotEmpty,
        'publico_alvo' => _publicoController.text.trim().isNotEmpty,
        'pre_requisitos' => _textos(_preRequisitos).isNotEmpty,
        'conteudo_central' => !_conteudoController.document.isEmpty(),
        'exemplo' => _exemploController != null && !_exemploController!.document.isEmpty(),
        'questoes' => _questoes.length >= _minQuestoes,
        'tempo_estimado_min' => _tempo != null,
        'referencias' => _textos(_referencias).isNotEmpty,
        'nivel_bloom' => _bloom != null,
        'dificuldade' => _dificuldade != null,
        _ => false,
      };

  // ---------------------------------------------------------------------------
  // Salvar rascunho
  // ---------------------------------------------------------------------------

  Future<void> _salvarRascunho() async {
    if (_salvando) return;
    if (_topicoId == null || _tituloController.text.trim().isEmpty) {
      _mensagem('Para salvar o rascunho, escolha o tópico e informe o título.', erro: true);
      return;
    }

    setState(() => _salvando = true);
    try {
      if (_editando) {
        await _atualizarRascunho();
        if (!mounted) return;
        _mensagem('Rascunho atualizado!');
        Navigator.pop(context, true);
        return;
      }

      final micro = await _supabase
          .from('microconteudos')
          // autor_id e status (rascunho) são preenchidos pelo banco.
          .insert(_dadosDoMicroconteudo())
          .select('id')
          .single();

      // As questões são gravadas ligadas ao id do microconteúdo recém-criado.
      if (_questoes.isNotEmpty) {
        try {
          await _supabase.from('questoes').insert([
            for (var i = 0; i < _questoes.length; i++)
              {
                'microconteudo_id': micro['id'],
                'enunciado': _questoes[i]['enunciado'],
                'alternativas': _questoes[i]['alternativas'],
                'correta': _questoes[i]['correta'],
                'ordem': i + 1,
              },
          ]);
        } catch (_) {
          // Não deixa um rascunho sem as questões: desfaz a criação dele.
          try {
            await _supabase.from('microconteudos').delete().eq('id', micro['id']);
          } catch (_) {
            // Se nem o desfazer funcionar, o erro original ainda é mostrado.
          }
          rethrow;
        }
      }

      if (!mounted) return;
      _mensagem('Rascunho salvo! Só você vê este conteúdo até enviá-lo para revisão.');
      Navigator.pop(context, true);
    } catch (erro, pilha) {
      debugPrint('Erro ao salvar rascunho: $erro\n$pilha');
      _mensagem(_traduzirErro(erro), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// Campos do microconteúdo, iguais na criação e na edição.
  Map<String, dynamic> _dadosDoMicroconteudo() {
    final exemplo = _exemploController;
    return {
      'topico_id': _topicoId,
      'titulo': _tituloController.text.trim(),
      'objetivo': _ouNulo(_objetivoController.text),
      'publico_alvo': _ouNulo(_publicoController.text),
      'pre_requisitos': _textos(_preRequisitos),
      'conteudo_central': _conteudoController.document.isEmpty()
          ? null
          : _conteudoController.document.toDelta().toJson(),
      'exemplo': (exemplo == null || exemplo.document.isEmpty())
          ? null
          : exemplo.document.toDelta().toJson(),
      'tempo_estimado_min': _tempo,
      'referencias': _textos(_referencias),
      'nivel_bloom': _bloom,
      'dificuldade': _dificuldade,
    };
  }

  /// Edição: grava o rascunho e sincroniza as questões (apaga as removidas,
  /// atualiza as existentes pelo id, insere as novas, renumera a ordem).
  /// [inferência] São várias operações seguidas, sem transação; se a conexão
  /// cair no meio, salvar de novo completa o que faltou.
  Future<void> _atualizarRascunho() async {
    final id = widget.idMicroconteudo!;

    // O RLS só deixa atualizar rascunho do próprio autor: se nada voltar,
    // o conteúdo não é mais rascunho (ou não é seu).
    final atualizados = await _supabase
        .from('microconteudos')
        .update(_dadosDoMicroconteudo())
        .eq('id', id)
        .select('id');
    if (atualizados.isEmpty) {
      throw const PostgrestException(message: 'sem permissão', code: '42501');
    }

    if (_questoesRemovidas.isNotEmpty) {
      await _supabase.from('questoes').delete().inFilter('id', _questoesRemovidas);
      _questoesRemovidas.clear();
    }

    for (var i = 0; i < _questoes.length; i++) {
      final q = _questoes[i];
      final dados = {
        'enunciado': q['enunciado'],
        'alternativas': q['alternativas'],
        'correta': q['correta'],
        'ordem': i + 1,
      };
      if (q['id'] != null) {
        await _supabase.from('questoes').update(dados).eq('id', q['id']);
      } else {
        final nova = await _supabase
            .from('questoes')
            .insert({...dados, 'microconteudo_id': id})
            .select('id')
            .single();
        q['id'] = nova['id']; // salvar de novo não duplica
      }
    }
  }

  String _traduzirErro(Object erro) {
    if (erro is PostgrestException) {
      switch (erro.code) {
        case '42501': // RLS / permissão
          return _editando
              ? 'Não foi possível salvar: este conteúdo não é mais um rascunho seu, '
                  'ou o tópico escolhido não é de uma disciplina sua.'
              : 'Você não tem permissão para criar conteúdo neste tópico.';
        case '23514': // check constraint
          return 'Algum campo está fora do limite permitido (título até 60 caracteres, '
              'até 3 pré-requisitos, tempo até 10 minutos).';
      }
    }
    if (erro is AuthException) {
      return 'Sua sessão expirou. Saia e entre novamente.';
    }
    return 'Não foi possível salvar. Verifique sua internet e tente de novo.';
  }

  void _mensagem(String texto, {bool erro = false}) {
    if (!mounted) return;
    final cores = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texto, style: erro ? TextStyle(color: cores.onError) : null),
        backgroundColor: erro ? cores.error : null,
      ));
  }

  // ---------------------------------------------------------------------------
  // Questões
  // ---------------------------------------------------------------------------

  Future<void> _abrirQuestao({int? indice}) async {
    // Não grava nada agora: a tela devolve os dados da questão e eles só vão
    // para o banco ao salvar o rascunho.
    final questao = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CriarQuestao(inicial: indice == null ? null : _questoes[indice]),
      ),
    );
    if (questao == null || !mounted) return;
    setState(() {
      if (indice == null) {
        _questoes.add(questao);
      } else {
        // Mantém o id da questão já salva (edição), para atualizar em vez de duplicar.
        final id = _questoes[indice]['id'];
        _questoes[indice] = {...questao, 'id': ?id};
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Interface
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Opcoes>(
      future: _futuroOpcoes,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: SizedBox(height: 50, width: 50, child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          debugPrint('Erro ao carregar o formulário: ${snapshot.error}');
          return _telaAviso('Não foi possível carregar o formulário.\n'
              'Verifique sua internet e tente de novo.');
        }

        final opcoes = snapshot.data!;
        if (_avisoEdicao != null) return _telaAviso(_avisoEdicao!);
        if (opcoes.papel != 'professor' && opcoes.papel != 'admin') {
          return _telaAviso('Somente professores podem criar microconteúdos.');
        }
        if (opcoes.disciplinas.isEmpty) {
          return _telaAviso('Você ainda não está vinculado a nenhuma disciplina.\n'
              'Peça à coordenação para fazer o vínculo.');
        }

        final obrigatorios = opcoes.campos.where((c) => c.obrigatorio).toList();
        final feitos = obrigatorios.where((c) => _preenchido(c.campo)).length;

        return Scaffold(
          appBar: AppBar(title: Text(_titulo), elevation: 0),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                _seletores(opcoes),
                const SizedBox(height: 16),
                _indicador(feitos, obrigatorios.length),
                const SizedBox(height: 8),
                for (final campo in opcoes.campos) ..._secao(campo),
                const SizedBox(height: 96), // espaço para o botão de salvar
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Salvar rascunho',
            onPressed: _salvando ? null : _salvarRascunho,
            child: _salvando
                ? const SizedBox(
                    width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
          ),
        );
      },
    );
  }

  String get _titulo => _editando ? 'Editar Conteúdo' : 'Criar Conteúdo';

  Widget _telaAviso(String texto) {
    return Scaffold(
      appBar: AppBar(title: Text(_titulo), elevation: 0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(texto, textAlign: TextAlign.center),
        ),
      ),
    );
  }

  /// Disciplina → Unidade → Tópico (o seletor de disciplina é o do layout original).
  Widget _seletores(_Opcoes opcoes) {
    final unidades = _unidadesDe(opcoes);
    final topicos = _topicosDe(opcoes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButton<int>(
          value: _disciplinaId,
          hint: const Text('Selecione uma disciplina'),
          isExpanded: true,
          items: [
            for (final d in opcoes.disciplinas)
              DropdownMenuItem(value: d['id'] as int, child: Text(d['nome'] as String)),
          ],
          onChanged: (valor) => setState(() {
            _disciplinaId = valor;
            _unidadeId = null;
            _topicoId = null;
          }),
        ),
        DropdownButton<int>(
          value: _unidadeId,
          hint: const Text('Selecione uma unidade'),
          isExpanded: true,
          items: [
            for (final u in unidades)
              DropdownMenuItem(
                value: u['id'] as int,
                child: Text('Unidade ${(u['numero'] as int).toString().padLeft(2, '0')} · ${u['nome']}',
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _disciplinaId == null
              ? null
              : (valor) => setState(() {
                    _unidadeId = valor;
                    _topicoId = null;
                  }),
        ),
        DropdownButton<int>(
          value: _topicoId,
          hint: const Text('Selecione um tópico'),
          isExpanded: true,
          items: [
            for (final t in topicos)
              DropdownMenuItem(
                value: t['id'] as int,
                child: Text('${t['codigo']} · ${t['titulo']}', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _unidadeId == null ? null : (valor) => setState(() => _topicoId = valor),
        ),
      ],
    );
  }

  Widget _indicador(int feitos, int total) {
    final cores = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Obrigatórios preenchidos: $feitos de $total',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: total == 0 ? 0 : feitos / total,
          backgroundColor: cores.surfaceContainerHighest,
        ),
        const SizedBox(height: 4),
        Text(
          'O rascunho pode ser salvo incompleto (basta tópico e título). '
          'Todos os obrigatórios serão exigidos no envio para revisão.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cores.onSurfaceVariant),
        ),
      ],
    );
  }

  /// Cabeçalho de cada campo: rótulo (* se obrigatório) e instrução, vindos
  /// de `modelo_campos`, seguido do componente do campo.
  List<Widget> _secao(_Campo campo) {
    final corpo = _componente(campo);
    if (corpo == null) return const []; // campo desconhecido: ignora
    final tema = Theme.of(context);
    return [
      const SizedBox(height: 20),
      Text(
        campo.obrigatorio ? '${campo.rotulo} *' : campo.rotulo,
        style: tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 2),
      Text(
        campo.instrucao,
        style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 8),
      corpo,
    ];
  }

  Widget? _componente(_Campo campo) {
    switch (campo.campo) {
      case 'titulo':
        return TextField(
          controller: _tituloController,
          maxLength: 60,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: campo.exemplo ?? 'Insira o título do microconteúdo',
          ),
        );
      case 'objetivo':
        return TextField(
          controller: _objetivoController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: campo.exemplo ?? 'Ex.: Explicar..., Identificar..., Comparar...',
          ),
        );
      case 'publico_alvo':
        return TextField(
          controller: _publicoController,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: campo.exemplo,
          ),
        );
      case 'pre_requisitos':
        return _listaDeTextos(_preRequisitos, maximo: 3, rotuloAdicionar: 'Adicionar pré-requisito',
            dica: campo.exemplo);
      case 'referencias':
        return _listaDeTextos(_referencias, rotuloAdicionar: 'Adicionar referência',
            dica: campo.exemplo ?? 'Autor, título, ano ou link');
      case 'conteudo_central':
        return _editorQuill(_conteudoController, _conteudoFoco, _conteudoRolagem,
            dica: campo.exemplo ?? 'Escreva aqui o conteúdo central');
      case 'exemplo':
        return _campoExemplo(campo);
      case 'questoes':
        return _campoQuestoes();
      case 'tempo_estimado_min':
        return DropdownButton<int>(
          value: _tempo,
          hint: const Text('Selecione o tempo'),
          isExpanded: true,
          items: [
            for (var m = 1; m <= 10; m++) DropdownMenuItem(value: m, child: Text('$m min')),
          ],
          onChanged: (valor) => setState(() => _tempo = valor),
        );
      case 'nivel_bloom':
        return DropdownButton<String>(
          value: _bloom,
          hint: const Text('Selecione o nível'),
          isExpanded: true,
          items: [
            for (final e in _niveisBloom.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (valor) => setState(() => _bloom = valor),
        );
      case 'dificuldade':
        return SegmentedButton<String>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: [
            for (final e in _dificuldades.entries)
              ButtonSegment(value: e.key, label: Text(e.value)),
          ],
          selected: {?_dificuldade},
          onSelectionChanged: (s) => setState(() => _dificuldade = s.isEmpty ? null : s.first),
        );
    }
    return null;
  }

  /// Lista de caixas de texto com "Adicionar" e remover (pré-requisitos, referências).
  Widget _listaDeTextos(List<TextEditingController> lista,
      {int? maximo, required String rotuloAdicionar, String? dica}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lista.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: lista[i],
                    onChanged: (_) => _atualizar(),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      hintText: i == 0 ? dica : null,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remover',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: lista.length > 1
                      ? () => setState(() => lista.removeAt(i).dispose())
                      : null,
                ),
              ],
            ),
          ),
        if (maximo == null || lista.length < maximo)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => lista.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: Text(rotuloAdicionar),
            ),
          ),
      ],
    );
  }

  /// Barra + editor Quill, com o mesmo visual do layout original
  /// (barra sem fonte, cor, alinhamento etc.; editor dentro de um cartão).
  Widget _editorQuill(QuillController controller, FocusNode foco, ScrollController rolagem,
      {String? dica}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuillSimpleToolbar(
          controller: controller,
          config: QuillSimpleToolbarConfig(
            // Imagem (galeria → Storage) e link (botão padrão do Quill): M2.5.
            embedButtons: botoesDeImagem(),
            showBackgroundColorButton: false,
            showAlignmentButtons: false,
            showFontFamily: false,
            showFontSize: false,
            showSubscript: false,
            showSuperscript: false,
            showColorButton: false,
            showListCheck: false,
            showInlineCode: false,
            showCodeBlock: false,
            showStrikeThrough: false,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTema.cartao(context, sombra: false),
            child: QuillEditor(
              controller: controller,
              focusNode: foco,
              scrollController: rolagem,
              config: QuillEditorConfig(
                embedBuilders: embedsDeImagem(),
                placeholder: dica,
                scrollable: false, // a tela inteira já rola
                minHeight: 160,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Exemplo opcional: recolhido até o professor pedir.
  Widget _campoExemplo(_Campo campo) {
    final exemplo = _exemploController;
    if (exemplo == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => setState(() {
            _exemploController = QuillController.basic()..addListener(_atualizar);
          }),
          icon: const Icon(Icons.add),
          label: const Text('Adicionar exemplo'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _editorQuill(exemplo, _exemploFoco, _exemploRolagem,
            dica: campo.exemplo ?? 'Escreva aqui o exemplo resolvido'),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _removerExemplo,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remover exemplo'),
          ),
        ),
      ],
    );
  }

  Future<void> _removerExemplo() async {
    final exemplo = _exemploController;
    if (exemplo == null) return;
    if (!exemplo.document.isEmpty()) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (contexto) => AlertDialog(
          title: const Text('Remover exemplo?'),
          content: const Text('O texto do exemplo será apagado.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Remover')),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    }
    setState(() => _exemploController = null);
    exemplo.dispose();
  }

  /// Lista de questões, como no layout original, com editar e remover.
  Widget _campoQuestoes() {
    return Column(
      children: [
        ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            ListTile(
              enabled: !maximoDeQuestoes,
              leading: const Icon(Icons.add),
              title: const Text('Adicionar questão'),
              subtitle: Text('${_questoes.length} de $_maxQuestoes (mínimo $_minQuestoes)'),
              onTap: () => _abrirQuestao(),
            ),
          ],
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _questoes.length,
          itemBuilder: (context, index) {
            return ListTile(
              leading: Text((index + 1).toString()),
              title: Text(
                _questoes[index]['enunciado'].toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('${(_questoes[index]['alternativas'] as List).length} alternativas'),
              onTap: () => _abrirQuestao(indice: index),
              trailing: IconButton(
                tooltip: 'Remover questão',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() {
                  final removida = _questoes.removeAt(index);
                  if (removida['id'] != null) _questoesRemovidas.add(removida['id'] as int);
                }),
              ),
            );
          },
        ),
      ],
    );
  }
}
