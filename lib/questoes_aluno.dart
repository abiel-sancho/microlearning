import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/disciplinas.dart';
import 'package:testeapp/tema.dart';

/// Mostra ao aluno, uma por vez, as questões de um microconteúdo (tabela
/// `questoes`, campo `microconteudo_id`) e grava cada resposta na tabela
/// `respostas` com `contexto = 'microconteudo'`.
///
/// O banco decide se acertou (trigger `respostas_preparar`) e, se errou, põe
/// a questão na fila do SM-2 para amanhã (trigger `respostas_atualizar_fila`).
/// Por isso a tela não calcula revisão nenhuma.
///
/// Em [previa] (microconteúdo ainda não publicado: autor ou revisor
/// conferindo), nada é gravado.
class QuestoesAluno extends StatefulWidget {
  const QuestoesAluno({
    super.key,
    required this.idMicroconteudo,
    this.previa = false,
  });

  final int idMicroconteudo;
  final bool previa;

  @override
  State<QuestoesAluno> createState() => _QuestoesAlunoState();
}

/// Uma alternativa lida do jsonb `questoes.alternativas`.
class _Alternativa {
  const _Alternativa(this.texto, this.feedback);

  final String texto;
  final String feedback;
}

/// Questão já convertida do formato do banco.
class _Questao {
  _Questao(Map<String, dynamic> linha)
      : id = linha['id'] as int,
        enunciado = (linha['enunciado'] ?? '').toString(),
        alternativas = [
          for (final a in (linha['alternativas'] as List? ?? []))
            _Alternativa(
              (a['texto'] ?? '').toString(),
              (a['feedback'] ?? '').toString(),
            ),
        ];

  final int id;
  final String enunciado;
  final List<_Alternativa> alternativas;

  /// Índice da correta, vindo da função gabaritos() (migration 10): na prévia,
  /// logo ao carregar; para o aluno, só depois que a resposta foi gravada.
  /// -1 enquanto não se sabe.
  int correta = -1;
}

/// Resposta dada pelo aluno nesta rodada (usada na tela de resultado).
class _Resposta {
  _Resposta(this.questao, this.escolhida, this.acertou);

  final _Questao questao;
  final int escolhida;

  /// Para o aluno, decidido pelo banco (trigger respostas_preparar).
  final bool acertou;
}

/// Fecha as telas abertas até a de Disciplinas (rota 'disciplinas', ver
/// inicio.dart). Se ela não estiver aberta (veio de Meus conteúdos ou das
/// revisões), volta ao Início e abre Disciplinas. Usada aqui e no resumo.
void irParaDisciplinas(BuildContext context) {
  final navegador = Navigator.of(context);
  var achou = false;
  navegador.popUntil((rota) {
    if (rota.settings.name == 'disciplinas') achou = true;
    return achou || rota.isFirst;
  });
  if (!achou) {
    navegador.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'disciplinas'),
        builder: (_) => const Disciplinas(),
      ),
    );
  }
}

/// Letra mostrada para a alternativa de índice [i] (0 → A, 1 → B...).
String _letra(int i) => String.fromCharCode(65 + i);

class _QuestoesAlunoState extends State<QuestoesAluno> {
  late Future<List<_Questao>> _questoesFuture = _carregarQuestoes();

  int _indice = 0;
  int? _selecionada;
  bool _confirmada = false;
  bool _salvando = false;
  bool _finalizado = false;
  final List<_Resposta> _respostas = [];

  Future<List<_Questao>> _carregarQuestoes() async {
    final dados = await Supabase.instance.client
        .from('questoes')
        // Sem `correta`: desde a migration 10 o app não lê essa coluna (erro
        // 42501). Ela vem de gabaritos(): na prévia, logo abaixo; para o aluno,
        // depois de gravar a resposta.
        .select('id, enunciado, alternativas, ordem')
        .eq('microconteudo_id', widget.idMicroconteudo)
        // ascending: true é obrigatório: no supabase_flutter o padrão do
        // .order() é decrescente (as questões vinham da última para a primeira).
        .order('ordem', ascending: true);
    final questoes = [for (final linha in dados) _Questao(linha)];
    // Na prévia (autor ou revisor), a função já libera todas as corretas.
    if (widget.previa && questoes.isNotEmpty) await _lerGabarito(questoes);
    return questoes;
  }

  /// Preenche `correta` nas questões que a função gabaritos() liberar.
  Future<void> _lerGabarito(List<_Questao> questoes) async {
    final linhas = await Supabase.instance.client
        .rpc('gabaritos', params: {'p_microconteudo': widget.idMicroconteudo}) as List;
    final gabarito = {for (final g in linhas) g['questao_id'] as int: g['correta'] as int};
    for (final q in questoes) {
      q.correta = gabarito[q.id] ?? q.correta;
    }
  }

  Future<void> _confirmar(_Questao questao) async {
    final escolhida = _selecionada;
    if (escolhida == null || _salvando) return;

    if (widget.previa) {
      setState(() {
        _respostas.add(_Resposta(questao, escolhida, escolhida == questao.correta));
        _confirmada = true;
      });
      return;
    }

    if (Supabase.instance.client.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não logado. Faça login primeiro.')),
      );
      return;
    }

    setState(() => _salvando = true);
    try {
      // aluno_id, acertou e respondida_em são preenchidos no banco
      // (trigger respostas_preparar), então o app só envia o essencial.
      // O select devolve o acerto decidido pelo banco.
      final linha = await Supabase.instance.client
          .from('respostas')
          .insert({
            'questao_id': questao.id,
            'alternativa_escolhida': escolhida,
            'contexto': 'microconteudo',
          })
          .select('acertou')
          .single();
      final acertou = linha['acertou'] as bool? ?? false;

      // Agora que respondeu, a função libera a correta desta questão.
      try {
        await _lerGabarito([questao]);
      } catch (erro) {
        // Sem a correta, a tela mostra só o acerto ou o erro da escolhida.
        debugPrint('Erro ao ler o gabarito: $erro');
      }

      if (!mounted) return;
      setState(() {
        _respostas.add(_Resposta(questao, escolhida, acertou));
        _confirmada = true;
        _salvando = false;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar sua resposta. Verifique a conexão.'),
        ),
      );
    }
  }

  void _proxima(int total) {
    if (_indice + 1 >= total) {
      setState(() => _finalizado = true);
      return;
    }
    setState(() {
      _indice++;
      _selecionada = null;
      _confirmada = false;
    });
  }

  void _refazer() {
    setState(() {
      _indice = 0;
      _selecionada = null;
      _confirmada = false;
      _finalizado = false;
      _respostas.clear();
      _questoesFuture = _carregarQuestoes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.previa ? 'Questões (prévia)' : 'Questões'),
      ),
      body: FutureBuilder<List<_Questao>>(
        future: _questoesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint('Erro ao carregar as questões: ${snapshot.error}');
            return _mensagem(
              'Não foi possível carregar as questões. Verifique a conexão.',
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
              'Este conteúdo ainda não tem questões.',
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

  Widget _buildQuestao(List<_Questao> questoes) {
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
                if (widget.previa) ...[
                  _avisoPrevia(),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Questão ${_indice + 1} de ${questoes.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  questao.enunciado,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < questao.alternativas.length; i++)
                  _buildAlternativa(questao, i),
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

  /// Cartão da alternativa [i]. Depois de confirmar, pinta a correta de verde,
  /// a escolhida errada de vermelho e mostra o feedback das duas.
  Widget _buildAlternativa(_Questao questao, int i) {
    final alternativa = questao.alternativas[i];
    final selecionada = _selecionada == i;
    final correta = i == questao.correta;

    Color? cor;
    IconData? icone;
    Color? corIcone;
    if (_confirmada) {
      if (correta) {
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

    final mostrarFeedback = _confirmada &&
        (selecionada || correta) &&
        alternativa.feedback.trim().isNotEmpty;

    return Card(
      color: cor,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () {
          if (_confirmada || _salvando) return;
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
                _buildAvisoRevisao(_respostas.length - acertos),
                const SizedBox(height: 20),
                for (var i = 0; i < _respostas.length; i++)
                  _buildItemResultado(i, _respostas[i]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextButton.icon(
              onPressed: () => irParaDisciplinas(context),
              icon: const Icon(Icons.menu_book),
              label: const Text('Ir para Disciplinas'),
            ),
          ),
        ],
      ),
    );
  }

  /// Diz o que acontece com as erradas (o banco já as pôs na fila do SM-2).
  Widget _buildAvisoRevisao(int erros) {
    final String texto;
    if (widget.previa) {
      texto = 'Prévia: as respostas não foram gravadas e nada entrou nas revisões.';
    } else if (erros == 0) {
      texto = 'Você acertou todas! Nenhuma questão entrou nas suas revisões.';
    } else if (erros == 1) {
      texto = '1 questão errada vai para as suas Revisões de amanhã.';
    } else {
      texto = '$erros questões erradas vão para as suas Revisões de amanhã.';
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

  Widget _avisoPrevia() {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.visibility),
            SizedBox(width: 12),
            Expanded(
              child: Text('Modo prévia: este conteúdo ainda não foi publicado, '
                  'então as respostas não são gravadas.'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemResultado(int indice, _Resposta resposta) {
    final escolhida = _letra(resposta.escolhida);
    return Card(
      child: ListTile(
        leading: Icon(
          resposta.acertou ? Icons.check_circle : Icons.cancel,
          color: resposta.acertou ? AppTema.acerto : Theme.of(context).colorScheme.error,
        ),
        title: Text(
          '${indice + 1}. ${resposta.questao.enunciado}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          (resposta.acertou || resposta.questao.correta < 0)
              ? 'Sua resposta: $escolhida'
              : 'Sua resposta: $escolhida · Correta: ${_letra(resposta.questao.correta)}',
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
