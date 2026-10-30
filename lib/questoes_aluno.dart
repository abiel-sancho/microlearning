import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/revisao_service.dart';
import 'package:testeapp/tema.dart';

/// Mostra ao aluno, uma por vez, as questões de um tópico e grava cada
/// resposta na tabela `respostas_aluno` para consulta posterior (feedback).
class QuestoesAluno extends StatefulWidget {
  const QuestoesAluno({super.key, required this.idTopico});

  final String idTopico;

  @override
  State<QuestoesAluno> createState() => _QuestoesAlunoState();
}

/// Resposta dada pelo aluno nesta rodada (usada na tela de resultado).
class _Resposta {
  _Resposta(this.questao, this.escolhida);

  final Map<String, dynamic> questao;
  final String escolhida;

  String get correta => _letraCorreta(questao);
  bool get acertou => escolhida == correta;
}

String _letraCorreta(Map<String, dynamic> questao) =>
    (questao['alt_correta'] ?? '').toString().trim().toLowerCase();

class _QuestoesAlunoState extends State<QuestoesAluno> {
  static const _letras = ['a', 'b', 'c', 'd'];

  late Future<List<Map<String, dynamic>>> _questoesFuture = _carregarQuestoes();

  int _indice = 0;
  String? _selecionada;
  bool _confirmada = false;
  bool _salvando = false;
  bool _finalizado = false;
  final List<_Resposta> _respostas = [];

  // Agendamento da próxima revisão (repetição espaçada) ao fim da rodada.
  ResultadoRevisao? _revisao;
  bool _registrandoRevisao = false;

  Future<List<Map<String, dynamic>>> _carregarQuestoes() async {
    final dados = await Supabase.instance.client
        .from('questoes')
        .select()
        .eq('id_topico', widget.idTopico)
        .order('id');
    return List<Map<String, dynamic>>.from(dados);
  }

  Future<void> _confirmar(Map<String, dynamic> questao) async {
    final escolhida = _selecionada;
    if (escolhida == null || _salvando) return;

    if (Supabase.instance.client.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não logado. Faça login primeiro.')),
      );
      return;
    }

    setState(() => _salvando = true);
    try {
      // user_id, id_topico e "correta" são preenchidos no banco
      // (ver supabase/respostas_aluno.sql), então o app só envia o essencial.
      await Supabase.instance.client.from('respostas_aluno').insert({
        'id_questao': questao['id'],
        'alternativa_escolhida': escolhida,
      });

      if (!mounted) return;
      setState(() {
        _respostas.add(_Resposta(questao, escolhida));
        _confirmada = true;
        _salvando = false;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar sua resposta: $erro')),
      );
    }
  }

  void _proxima(int total) {
    if (_indice + 1 >= total) {
      setState(() => _finalizado = true);
      _registrarRevisao();
      return;
    }
    setState(() {
      _indice++;
      _selecionada = null;
      _confirmada = false;
    });
  }

  /// Ao terminar as questões, agenda a próxima revisão do tópico com o SM-2.
  Future<void> _registrarRevisao() async {
    final acertos = _respostas.where((r) => r.acertou).length;
    final total = _respostas.length;

    setState(() => _registrandoRevisao = true);
    try {
      final resultado = await RevisaoService.registrarResultado(
        idTopico: widget.idTopico,
        acertos: acertos,
        total: total,
      );
      if (!mounted || !_finalizado) return;
      setState(() {
        _revisao = resultado;
        _registrandoRevisao = false;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _registrandoRevisao = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível agendar a revisão: $erro')),
      );
    }
  }

  void _refazer() {
    setState(() {
      _indice = 0;
      _selecionada = null;
      _confirmada = false;
      _finalizado = false;
      _respostas.clear();
      _revisao = null;
      _registrandoRevisao = false;
      _questoesFuture = _carregarQuestoes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Questões')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _questoesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _mensagem(
              'Não foi possível carregar as questões.\n${snapshot.error}',
              acao: FilledButton(
                onPressed: () {
                  setState(() {
                    _questoesFuture = _carregarQuestoes();
                  });
                },
                child: const Text('Tentar novamente'),
              ),
            );
          }

          final questoes = snapshot.data ?? [];
          if (questoes.isEmpty) {
            return _mensagem(
              'Este tópico ainda não tem questões.',
              acao: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Voltar ao resumo'),
              ),
            );
          }
          if (_finalizado) return _buildResultado();
          return _buildQuestao(questoes);
        },
      ),
    );
  }

  Widget _buildQuestao(List<Map<String, dynamic>> questoes) {
    final questao = questoes[_indice];
    final ultima = _indice == questoes.length - 1;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: (_indice + (_confirmada ? 1 : 0)) / questoes.length,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Questão ${_indice + 1} de ${questoes.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  '${questao['enunciado']}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                for (final letra in _letras) _buildAlternativa(questao, letra),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _confirmada
                ? FilledButton(
                    onPressed: () => _proxima(questoes.length),
                    child: Text(ultima ? 'Ver resultado' : 'Próxima questão'),
                  )
                : FilledButton(
                    onPressed: (_selecionada == null || _salvando)
                        ? null
                        : () => _confirmar(questao),
                    child: _salvando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirmar resposta'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativa(Map<String, dynamic> questao, String letra) {
    final correta = _letraCorreta(questao);
    final selecionada = _selecionada == letra;

    Color? cor;
    IconData? icone;
    Color? corIcone;
    if (_confirmada) {
      if (letra == correta) {
        cor = AppTema.acertoSuave;
        icone = Icons.check_circle;
        corIcone = AppTema.acerto;
      } else if (selecionada) {
        cor = Theme.of(context).colorScheme.errorContainer;
        icone = Icons.cancel;
        corIcone = Theme.of(context).colorScheme.error;
      }
    } else if (selecionada) {
      cor = Theme.of(context).colorScheme.primaryContainer;
    }

    return Card(
      color: cor,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () {
          if (_confirmada || _salvando) return;
          setState(() => _selecionada = letra);
        },
        leading: CircleAvatar(radius: 14, child: Text(letra.toUpperCase())),
        title: Text('${questao['alt_$letra']}'),
        trailing: icone == null ? null : Icon(icone, color: corIcone),
      ),
    );
  }

  Widget _buildResultado() {
    final acertos = _respostas.where((r) => r.acertou).length;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Você acertou $acertos de ${_respostas.length}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                _buildAvisoRevisao(),
                const SizedBox(height: 20),
                for (var i = 0; i < _respostas.length; i++)
                  _buildItemResultado(i, _respostas[i]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _refazer,
                    child: const Text('Refazer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Voltar ao resumo'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Mostra quando o aluno deve revisar este tópico de novo.
  Widget _buildAvisoRevisao() {
    final revisao = _revisao;
    final String texto;
    if (_registrandoRevisao) {
      texto = 'Agendando a próxima revisão...';
    } else if (revisao == null) {
      return const SizedBox.shrink();
    } else if (revisao.atualizado) {
      texto = 'Próxima revisão deste tópico: ${revisao.descricao}.';
    } else {
      texto = 'Esta rodada contou como prática extra. '
          'Sua próxima revisão continua marcada: ${revisao.descricao}.';
    }

    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.event_repeat),
            const SizedBox(width: 12),
            Expanded(child: Text(texto)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemResultado(int indice, _Resposta resposta) {
    final escolhida = resposta.escolhida.toUpperCase();
    return Card(
      child: ListTile(
        leading: Icon(
          resposta.acertou ? Icons.check_circle : Icons.cancel,
          color: resposta.acertou ? AppTema.acerto : Theme.of(context).colorScheme.error,
        ),
        title: Text(
          '${indice + 1}. ${resposta.questao['enunciado']}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          resposta.acertou
              ? 'Sua resposta: $escolhida'
              : 'Sua resposta: $escolhida · Correta: ${resposta.correta.toUpperCase()}',
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