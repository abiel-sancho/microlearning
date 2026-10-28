import 'package:flutter_test/flutter_test.dart';
import 'package:testeapp/sm2.dart';

void main() {
  // O horário é ignorado: só a data importa.
  final hoje = DateTime(2026, 10, 18, 21, 30);

  group('qualidade', () {
    test('acertar tudo vale 5', () {
      expect(Sm2.qualidade(acertos: 4, total: 4), 5);
    });

    test('errar alguma questão fica abaixo de 3', () {
      expect(Sm2.qualidade(acertos: 3, total: 4), lessThan(3));
      expect(Sm2.qualidade(acertos: 0, total: 4), lessThan(3));
    });
  });

  group('calcular', () {
    test('primeira vez e errou: revisar no dia seguinte', () {
      final estado = Sm2.calcular(qualidade: 2, hoje: hoje);
      expect(estado.intervaloDias, 1);
      expect(estado.repeticoes, 0);
      expect(estado.proximaRevisao, DateTime(2026, 10, 19));
      expect(estado.fatorFacilidade, Sm2.fatorInicial);
    });

    test('primeira vez e acertou: revisar depois de 3 dias', () {
      final estado = Sm2.calcular(qualidade: 5, hoje: hoje);
      expect(estado.intervaloDias, 3);
      expect(estado.repeticoes, 1);
      expect(estado.proximaRevisao, DateTime(2026, 10, 21));
    });

    test('acertos seguidos seguem 3, 7 e 15 dias e depois usam o fator', () {
      var estado = Sm2.calcular(qualidade: 5, hoje: hoje);
      expect(estado.intervaloDias, 3);

      estado = Sm2.calcular(
        atual: estado,
        qualidade: 5,
        hoje: estado.proximaRevisao,
      );
      expect(estado.intervaloDias, 7);

      estado = Sm2.calcular(
        atual: estado,
        qualidade: 5,
        hoje: estado.proximaRevisao,
      );
      expect(estado.intervaloDias, 15);
      expect(estado.fatorFacilidade, closeTo(2.8, 0.001));

      // A partir daqui: 15 dias × fator 2.8 = 42 dias.
      estado = Sm2.calcular(
        atual: estado,
        qualidade: 5,
        hoje: estado.proximaRevisao,
      );
      expect(estado.intervaloDias, 42);
      expect(estado.repeticoes, 4);
      expect(estado.fatorFacilidade, closeTo(2.9, 0.001));
    });

    test('errar zera a sequência, volta para 1 dia e mantém o fator', () {
      var estado = Sm2.calcular(qualidade: 5, hoje: hoje);
      estado = Sm2.calcular(
        atual: estado,
        qualidade: 5,
        hoje: estado.proximaRevisao,
      );
      final antes = estado.fatorFacilidade;

      final depois = Sm2.calcular(
        atual: estado,
        qualidade: 1,
        hoje: estado.proximaRevisao,
      );
      expect(depois.repeticoes, 0);
      expect(depois.intervaloDias, 1);
      expect(depois.fatorFacilidade, antes);

      // Depois de errar, a sequência recomeça em 3 dias.
      final recomeco = Sm2.calcular(
        atual: depois,
        qualidade: 5,
        hoje: depois.proximaRevisao,
      );
      expect(recomeco.intervaloDias, 3);
    });

    test('o fator de facilidade nunca fica abaixo de 1.3', () {
      EstadoRevisao? estado;
      for (var i = 0; i < 30; i++) {
        estado = Sm2.calcular(atual: estado, qualidade: 3, hoje: hoje);
      }
      expect(estado!.fatorFacilidade, Sm2.fatorMinimo);
    });

    test('a data de revisão atravessa o fim do mês', () {
      final estado = Sm2.calcular(
        qualidade: 5,
        hoje: DateTime(2026, 10, 30, 23, 59),
      );
      expect(estado.proximaRevisao, DateTime(2026, 11, 2));
    });
  });
}