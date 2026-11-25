import 'package:flutter/material.dart';

/// Tela de criação (ou edição) de uma questão. Ela não grava nada no banco:
/// ao concluir, devolve os dados da questão (Navigator.pop) para a tela de
/// criação de conteúdo, que os salva junto com o microconteúdo.
///
/// Formato devolvido (o mesmo da tabela `questoes`):
/// {
///   'enunciado': String,
///   'alternativas': [ {'texto': String, 'feedback': String}, ... ],  // 2 a 5
///   'correta': int,   // índice da alternativa correta, começando em 0
/// }
class CriarQuestao extends StatefulWidget {
  const CriarQuestao({super.key, this.inicial});

  /// Questão já existente, para editar. Nulo = questão nova.
  final Map<String, dynamic>? inicial;

  @override
  State<CriarQuestao> createState() => _CriarQuestaoState();
}

/// Campos de uma alternativa: o texto e o feedback que o aluno verá
/// ao escolher essa alternativa.
class _Alternativa {
  _Alternativa({String texto = '', String feedback = ''})
      : texto = TextEditingController(text: texto),
        feedback = TextEditingController(text: feedback);
  final TextEditingController texto;
  final TextEditingController feedback;

  void dispose() {
    texto.dispose();
    feedback.dispose();
  }
}

class _CriarQuestaoState extends State<CriarQuestao> {
  static const _minAlternativas = 2;
  static const _maxAlternativas = 5;
  static const _letras = ['a', 'b', 'c', 'd', 'e'];

  final TextEditingController _enunciadoController = TextEditingController();
  final List<_Alternativa> _alternativas = [];
  int? _correta;

  @override
  void initState() {
    super.initState();
    final inicial = widget.inicial;
    if (inicial != null) {
      _enunciadoController.text = (inicial['enunciado'] ?? '').toString();
      for (final a in (inicial['alternativas'] as List? ?? [])) {
        _alternativas.add(_Alternativa(
          texto: (a['texto'] ?? '').toString(),
          feedback: (a['feedback'] ?? '').toString(),
        ));
      }
      _correta = inicial['correta'] as int?;
    }
    // Questão nova começa com 4 alternativas, como no layout original.
    while (_alternativas.length < 4 && inicial == null) {
      _alternativas.add(_Alternativa());
    }
    while (_alternativas.length < _minAlternativas) {
      _alternativas.add(_Alternativa());
    }
  }

  @override
  void dispose() {
    _enunciadoController.dispose();
    for (final a in _alternativas) {
      a.dispose();
    }
    super.dispose();
  }

  void _adicionarAlternativa() {
    if (_alternativas.length >= _maxAlternativas) return;
    setState(() => _alternativas.add(_Alternativa()));
  }

  void _removerAlternativa(int indice) {
    if (_alternativas.length <= _minAlternativas) return;
    setState(() {
      _alternativas.removeAt(indice).dispose();
      // Mantém a marcação da correta apontando para a mesma alternativa.
      if (_correta == indice) {
        _correta = null;
      } else if (_correta != null && _correta! > indice) {
        _correta = _correta! - 1;
      }
    });
  }

  void _salvarQuestao() {
    final semTexto = _alternativas.any((a) => a.texto.text.trim().isEmpty);
    if (_enunciadoController.text.trim().isEmpty || semTexto || _correta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha o enunciado, o texto de todas as alternativas e selecione a correta.'),
        ),
      );
      return;
    }

    Navigator.pop(context, <String, dynamic>{
      'enunciado': _enunciadoController.text.trim(),
      'alternativas': [
        for (final a in _alternativas)
          {'texto': a.texto.text.trim(), 'feedback': a.feedback.text.trim()},
      ],
      'correta': _correta,
    });
  }

  @override
  Widget build(BuildContext context) {
    final estiloAjuda = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.inicial == null ? 'Criar questão' : 'Editar questão'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 30),
            TextField(
              controller: _enunciadoController,
              minLines: 3,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: 'Insira o enunciado da questão',
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Alternativas (de 2 a 5). O feedback aparece para o aluno quando ele '
              'escolhe aquela alternativa: explique por que está certa ou errada.',
              style: estiloAjuda,
            ),
            const SizedBox(height: 10),

            for (var i = 0; i < _alternativas.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _alternativas[i].texto,
                      minLines: 1,
                      maxLines: 2,
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Text('${_letras[i]}) ', style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remover alternativa',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _alternativas.length > _minAlternativas
                        ? () => _removerAlternativa(i)
                        : null,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 32, right: 48),
                child: TextField(
                  controller: _alternativas[i].feedback,
                  minLines: 1,
                  maxLines: 3,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Feedback desta alternativa',
                    prefixIcon: Icon(Icons.chat_bubble_outline, size: 18),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (_alternativas.length < _maxAlternativas)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _adicionarAlternativa,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar alternativa'),
                ),
              ),
            const SizedBox(height: 20),

            const Text('Selecione a alternativa correta:', textAlign: TextAlign.center),
            const SizedBox(height: 10),

            // RadioGroup guarda qual alternativa está marcada (API atual do Flutter).
            RadioGroup<int>(
              groupValue: _correta,
              onChanged: (value) => setState(() => _correta = value),
              child: Wrap(
                alignment: WrapAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < _alternativas.length; i++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<int>(value: i),
                        Text('${_letras[i]})'),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: _salvarQuestao,
                icon: const Icon(Icons.save),
                label: const Text('Salvar questão'),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
