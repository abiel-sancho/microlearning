import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/questoes_aluno.dart';
import 'package:testeapp/resumo.dart';
import 'package:testeapp/tema.dart';

/// Tela "Revisões de hoje" (SM-2 por questão, CLAUDE.md 5.8).
///
/// As questões vencidas vêm da função `revisoes_de_hoje()` (migration 9), que
/// não devolve a alternativa correta. A tela agrupa por microconteúdo; cada
/// grupo tem "Rever o conteúdo" (sempre visível) e "Responder".
///
/// Cada resposta vai para `respostas` com `contexto = 'revisao'`. Quem decide
/// se acertou é o banco (trigger `respostas_preparar`), e quem reagenda é o
/// trigger `respostas_atualizar_fila`. As erradas voltam na mesma hora até o
/// aluno acertar (passo 7 do SM-2); essas repetições não mudam a fila.
class PainelRevisoes extends StatefulWidget {
  const PainelRevisoes({super.key});

  @override
  State<PainelRevisoes> createState() => _PainelRevisoesState();
}

/// Uma alternativa lida do jsonb `alternativas` (sem a correta).
class _Alternativa {
  const _Alternativa(this.texto, this.feedback);

  final String texto;
  final String feedback;
}

/// Questão vencida, como vem de `revisoes_de_hoje()`.
class _QuestaoRevisao {
  _QuestaoRevisao(Map<String, dynamic> linha)
      : id = linha['questao_id'] as int,
        enunciado = (linha['enunciado'] ?? '').toString(),
        errosSeguidos = linha['erros_seguidos'] as int? ?? 0,
        alternativas = [
          for (final a in (linha['alternativas'] as List? ?? []))
            _Alternativa(
              (a['texto'] ?? '').toString(),
              (a['feedback'] ?? '').toString(),
            ),
        ];

  final int id;
  final String enunciado;
  final int errosSeguidos;
  final List<_Alternativa> alternativas;
}

/// Questões vencidas de um mesmo microconteúdo.
class _Grupo {
  _Grupo(this.idMicroconteudo, this.titulo, this.codigo);

  final int idMicroconteudo;
  final String titulo;
  final String codigo;
  final List<_QuestaoRevisao> questoes = [];

  /// Sugere reler quando alguma questão já foi errada 2 vezes seguidas.
  bool get sugerirReler => questoes.any((q) => q.errosSeguidos >= 2);
}

/// Letra mostrada para a alternativa de índice [i] (0 → A, 1 → B...).
String _letra(int i) => String.fromCharCode(65 + i);

/// Data no formato dd/mm/aaaa (o app não usa o pacote intl).
String _data(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Abre a leitura do microconteúdo ("Rever o conteúdo").
Future<void> _abrirConteudo(BuildContext context, int idMicroconteudo) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Resumo(idMicroconteudo: idMicroconteudo.toString()),
    ),
  );
}

class _PainelRevisoesState extends State<PainelRevisoes> {
  late Future<List<_Grupo>> _futuro = _carregar();

  Future<List<_Grupo>> _carregar() async {
    final dados = await Supabase.instance.client.rpc('revisoes_de_hoje');
    // A função já devolve ordenado por microconteúdo e ordem da questão.
    final grupos = <int, _Grupo>{};
    for (final linha in List<Map<String, dynamic>>.from(dados as List)) {
      final id = linha['microconteudo_id'] as int;
      final grupo = grupos.putIfAbsent(
        id,
        () => _Grupo(
          id,
          (linha['microconteudo_titulo'] ?? '').toString(),
          (linha['microconteudo_codigo'] ?? '').toString(),
        ),
      );
      grupo.questoes.add(_QuestaoRevisao(linha));
    }
    return grupos.values.toList();
  }

  void _recarregar() {
    setState(() => _futuro = _carregar());
  }

  Future<void> _rever(_Grupo grupo) async {
    await _abrirConteudo(context, grupo.idMicroconteudo);
    // No resumo o aluno pode ter respondido as questões de novo.
    if (mounted) _recarregar();
  }

  Future<void> _responder(_Grupo grupo) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _SessaoRevisao(grupo: grupo)),
    );
    // As respondidas saem da lista de hoje.
    if (mounted) _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisões de hoje'),
        actions: [
          IconButton(
            tooltip: 'Ir para Disciplinas',
            onPressed: () => irParaDisciplinas(context),
            icon: const Icon(Icons.menu_book),
          ),
        ],
      ),
      body: FutureBuilder<List<_Grupo>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _mensagem(
              context,
              Icons.wifi_off,
              'Não foi possível carregar as revisões. Verifique a conexão.',
              acao: FilledButton(
                onPressed: _recarregar,
                child: const Text('Tentar novamente'),
              ),
            );
          }

          final grupos = snapshot.data ?? const <_Grupo>[];
          if (grupos.isEmpty) {
            return _mensagem(
              context,
              Icons.event_available,
              'Nenhuma revisão para hoje.\n'
              'Quando você errar uma questão, ela volta aqui no dia certo.',
            );
          }

          final total = grupos.fold<int>(0, (soma, g) => soma + g.questoes.length);
          return RefreshIndicator(
            onRefresh: () async => _recarregar(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  total == 1
                      ? '1 questão para revisar hoje'
                      : '$total questões para revisar hoje',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final grupo in grupos) _cartaoGrupo(context, grupo),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _cartaoGrupo(BuildContext context, _Grupo grupo) {
    final tema = Theme.of(context);
    final qtd = grupo.questoes.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(grupo.titulo, style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${grupo.codigo} · ${qtd == 1 ? '1 questão' : '$qtd questões'}',
              style: tema.textTheme.bodySmall,
            ),
            if (grupo.sugerirReler) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: tema.colorScheme.tertiary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Você já errou uma destas mais de uma vez. '
                        'Que tal reler o conteúdo antes?'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rever(grupo),
                    icon: const Icon(Icons.menu_book),
                    label: const Text('Rever o conteúdo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _responder(grupo),
                    icon: const Icon(Icons.quiz),
                    label: const Text('Responder'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Resultado da primeira tentativa de uma questão na sessão.
class _Resultado {
  _Resultado(this.questao, this.acertou);

  final _QuestaoRevisao questao;
  final bool acertou;

  /// Lidos de `revisao_espacada` depois de um acerto (nulos se falhar).
  DateTime? proximaRevisao;
  bool dominada = false;
}

/// Responde, uma por vez, as questões vencidas de um microconteúdo.
class _SessaoRevisao extends StatefulWidget {
  const _SessaoRevisao({required this.grupo});

  final _Grupo grupo;

  @override
  State<_SessaoRevisao> createState() => _SessaoRevisaoState();
}

class _SessaoRevisaoState extends State<_SessaoRevisao> {
  final _supabase = Supabase.instance.client;

  /// Questões da rodada atual. Na 1ª rodada, todas; depois, só as erradas.
  late List<_QuestaoRevisao> _rodada = List.of(widget.grupo.questoes);
  final List<_QuestaoRevisao> _erradasDaRodada = [];
  int _numeroRodada = 1;
  int _indice = 0;

  int? _selecionada;
  bool? _acertou; // nulo enquanto não confirmou
  bool _salvando = false;
  bool _finalizado = false;

  /// Primeira tentativa de cada questão (o que conta para o SM-2).
  final Map<int, _Resultado> _resultados = {};

  _QuestaoRevisao get _questao => _rodada[_indice];

  Future<void> _confirmar() async {
    final escolhida = _selecionada;
    if (escolhida == null || _salvando) return;

    setState(() => _salvando = true);
    try {
      // O banco preenche aluno_id e acertou (trigger respostas_preparar);
      // o select devolve o acerto sem o app conhecer a alternativa correta.
      final linha = await _supabase
          .from('respostas')
          .insert({
            'questao_id': _questao.id,
            'alternativa_escolhida': escolhida,
            'contexto': 'revisao',
          })
          .select('acertou')
          .single();
      final acertou = linha['acertou'] as bool? ?? false;

      if (_numeroRodada == 1) {
        final resultado = _Resultado(_questao, acertou);
        _resultados[_questao.id] = resultado;
        if (acertou) await _lerAgendamento(resultado);
      }
      if (!acertou) _erradasDaRodada.add(_questao);

      if (!mounted) return;
      setState(() {
        _acertou = acertou;
        _salvando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar sua resposta. Verifique a conexão.'),
        ),
      );
    }
  }

  /// Lê a nova data da questão, já reagendada pelo trigger do SM-2.
  Future<void> _lerAgendamento(_Resultado resultado) async {
    try {
      final fila = await _supabase
          .from('revisao_espacada')
          .select('proxima_revisao, status')
          .eq('questao_id', resultado.questao.id)
          .maybeSingle();
      if (fila == null) return;
      resultado.dominada = fila['status'] == 'dominada';
      resultado.proximaRevisao =
          DateTime.tryParse((fila['proxima_revisao'] ?? '').toString());
    } catch (_) {
      // Sem a data, o resultado mostra só "Acertou".
    }
  }

  void _proxima() {
    if (_indice + 1 < _rodada.length) {
      setState(() {
        _indice++;
        _selecionada = null;
        _acertou = null;
      });
      return;
    }
    // Fim da rodada: as erradas voltam até serem acertadas (passo 7).
    if (_erradasDaRodada.isNotEmpty) {
      setState(() {
        _rodada = List.of(_erradasDaRodada);
        _erradasDaRodada.clear();
        _numeroRodada++;
        _indice = 0;
        _selecionada = null;
        _acertou = null;
      });
      return;
    }
    setState(() => _finalizado = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.grupo.titulo),
        actions: [
          IconButton(
            tooltip: 'Rever o conteúdo',
            onPressed: () => _abrirConteudo(context, widget.grupo.idMicroconteudo),
            icon: const Icon(Icons.menu_book),
          ),
        ],
      ),
      body: _finalizado ? _buildResultado() : _buildQuestao(),
    );
  }

  Widget _buildQuestao() {
    final questao = _questao;
    final confirmada = _acertou != null;
    final ultimaDaRodada = _indice == _rodada.length - 1;
    final tema = Theme.of(context);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: (_indice + (confirmada ? 1 : 0)) / _rodada.length,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_numeroRodada > 1) ...[
                  Card(
                    color: tema.colorScheme.secondaryContainer,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.replay),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text('Tente de novo as que você errou. '
                                'Estas tentativas não mudam suas revisões.'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Questão ${_indice + 1} de ${_rodada.length}',
                  style: tema.textTheme.labelLarge,
                ),
                const SizedBox(height: 12),
                Text(questao.enunciado, style: tema.textTheme.titleMedium),
                const SizedBox(height: 20),
                for (var i = 0; i < questao.alternativas.length; i++)
                  _buildAlternativa(questao, i),
                if (_acertou == false) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () =>
                        _abrirConteudo(context, widget.grupo.idMicroconteudo),
                    icon: const Icon(Icons.menu_book),
                    label: const Text('Rever o conteúdo'),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: confirmada
                ? FilledButton(
                    onPressed: _proxima,
                    child: Text(_textoProxima(ultimaDaRodada)),
                  )
                : FilledButton(
                    onPressed: (_selecionada == null || _salvando) ? null : _confirmar,
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

  String _textoProxima(bool ultimaDaRodada) {
    if (!ultimaDaRodada) return 'Próxima questão';
    return _erradasDaRodada.isEmpty ? 'Ver resultado' : 'Tentar de novo as erradas';
  }

  /// Opção (a) de 27/11: ao errar, pinta só a escolhida de vermelho e mostra
  /// o feedback dela; a correta não é revelada (o aluno tenta de novo).
  Widget _buildAlternativa(_QuestaoRevisao questao, int i) {
    final alternativa = questao.alternativas[i];
    final selecionada = _selecionada == i;
    final confirmada = _acertou != null;
    final tema = Theme.of(context);

    Color? cor;
    IconData? icone;
    Color? corIcone;
    if (confirmada && selecionada) {
      if (_acertou!) {
        cor = AppTema.acertoSuave;
        icone = Icons.check_circle;
        corIcone = AppTema.acerto;
      } else {
        cor = tema.colorScheme.errorContainer;
        icone = Icons.cancel;
        corIcone = tema.colorScheme.error;
      }
    } else if (selecionada) {
      cor = tema.colorScheme.primaryContainer;
    }

    final mostrarFeedback =
        confirmada && selecionada && alternativa.feedback.trim().isNotEmpty;

    return Card(
      color: cor,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () {
          if (confirmada || _salvando) return;
          setState(() => _selecionada = i);
        },
        leading: CircleAvatar(radius: 14, child: Text(_letra(i))),
        title: Text(alternativa.texto),
        subtitle: mostrarFeedback
            ? Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(alternativa.feedback),
              )
            : null,
        trailing: icone == null ? null : Icon(icone, color: corIcone),
      ),
    );
  }

  Widget _buildResultado() {
    final resultados = _resultados.values.toList();
    final acertos = resultados.where((r) => r.acertou).length;
    final tema = Theme.of(context);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'De primeira, você acertou $acertos de ${resultados.length}',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < resultados.length; i++)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        resultados[i].acertou ? Icons.check_circle : Icons.cancel,
                        color: resultados[i].acertou
                            ? AppTema.acerto
                            : tema.colorScheme.error,
                      ),
                      title: Text(
                        '${i + 1}. ${resultados[i].questao.enunciado}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(_textoResultado(resultados[i])),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Voltar às revisões'),
            ),
          ),
        ],
      ),
    );
  }

  String _textoResultado(_Resultado r) {
    if (!r.acertou) return 'Errou de primeira: volta amanhã.';
    if (r.dominada) return 'Dominada! Saiu das suas revisões.';
    final data = r.proximaRevisao;
    return data == null ? 'Acertou.' : 'Acertou. Próxima revisão: ${_data(data)}.';
  }
}

Widget _mensagem(BuildContext context, IconData icone, String texto, {Widget? acao}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
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
