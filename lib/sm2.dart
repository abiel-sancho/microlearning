import 'dart:math' as math;

/// Repetição espaçada baseada no algoritmo SuperMemo 2 (SM-2).
///
/// Cada tópico estudado é um "item" do SM-2. Depois que o aluno responde as
/// questões do tópico, o resultado vira uma nota de qualidade (0 a 5) e o
/// algoritmo decide quando o tópico deve ser revisado de novo.
///
/// Diferença em relação ao SM-2 original: os intervalos das primeiras
/// revisões bem-sucedidas são fixos (3, 7 e 15 dias) em vez de 1 e 6 dias.
/// A partir da quarta revisão seguida vale a regra clássica:
/// novo intervalo = intervalo anterior × fator de facilidade.
/// Errar qualquer questão recomeça a sequência, com revisão no dia seguinte.

/// Situação de um tópico na sequência de revisões de um aluno.
class EstadoRevisao {
  const EstadoRevisao({
    required this.repeticoes,
    required this.fatorFacilidade,
    required this.intervaloDias,
    required this.proximaRevisao,
  });

  /// Quantas revisões bem-sucedidas seguidas o aluno já fez.
  final int repeticoes;

  /// Fator de facilidade (EF) do SM-2. Começa em 2.5 e nunca fica abaixo de 1.3.
  final double fatorFacilidade;

  /// Intervalo, em dias, usado para chegar em [proximaRevisao].
  final int intervaloDias;

  /// Dia da próxima revisão (apenas a data, sem horário).
  final DateTime proximaRevisao;
}

class Sm2 {
  Sm2._();

  static const double fatorInicial = 2.5;
  static const double fatorMinimo = 1.3;

  /// Intervalos, em dias, das 3 primeiras revisões bem-sucedidas.
  static const List<int> intervalosIniciais = [3, 7, 15];

  /// Converte o resultado das questões de um tópico na nota de qualidade (0 a 5)
  /// do SM-2. Acertar tudo vale 5; errar alguma questão fica abaixo de 3, que o
  /// SM-2 trata como falha.
  static int qualidade({required int acertos, required int total}) {
    if (total <= 0) return 0;
    if (acertos >= total) return 5;
    return acertos / total >= 0.5 ? 2 : 1;
  }

  /// Mantém só a data (ano, mês, dia) de um [DateTime].
  static DateTime soData(DateTime data) =>
      DateTime(data.year, data.month, data.day);

  /// Calcula o novo estado do tópico depois de uma revisão feita em [hoje].
  ///
  /// [atual] é o estado antes da revisão, ou null se for a primeira vez que o
  /// aluno responde as questões do tópico.
  static EstadoRevisao calcular({
    EstadoRevisao? atual,
    required int qualidade,
    required DateTime hoje,
  }) {
    final dia = soData(hoje);
    var repeticoes = atual?.repeticoes ?? 0;
    var fator = atual?.fatorFacilidade ?? fatorInicial;
    var intervalo = atual?.intervaloDias ?? 0;

    if (qualidade < 3) {
      // Falhou: recomeça a sequência e revisa no dia seguinte.
      // No SM-2 original o fator de facilidade não muda quando o aluno falha.
      repeticoes = 0;
      intervalo = 1;
    } else {
      if (repeticoes < intervalosIniciais.length) {
        intervalo = intervalosIniciais[repeticoes];
      } else {
        intervalo = math.max(1, (intervalo * fator).round());
      }
      repeticoes += 1;

      final falta = 5 - qualidade;
      fator = math.max(
        fatorMinimo,
        fator + 0.1 - falta * (0.08 + falta * 0.02),
      );
    }

    return EstadoRevisao(
      repeticoes: repeticoes,
      fatorFacilidade: fator,
      intervaloDias: intervalo,
      // Somar pelo campo "dia" evita problemas de horário de verão.
      proximaRevisao: DateTime(dia.year, dia.month, dia.day + intervalo),
    );
  }
}