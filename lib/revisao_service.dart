import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/sm2.dart';

/// Data no formato que o banco usa para colunas `date` (aaaa-mm-dd).
String paraDataBanco(DateTime data) {
  final mes = data.month.toString().padLeft(2, '0');
  final dia = data.day.toString().padLeft(2, '0');
  return '${data.year.toString().padLeft(4, '0')}-$mes-$dia';
}

/// Data curta para mostrar ao aluno (dd/mm).
String dataCurta(DateTime data) {
  final mes = data.month.toString().padLeft(2, '0');
  final dia = data.day.toString().padLeft(2, '0');
  return '$dia/$mes';
}

/// Diferença em dias entre duas datas (já sem horário), à prova de horário de verão.
int _diasEntre(DateTime inicio, DateTime fim) =>
    (fim.difference(inicio).inHours / 24).round();

/// O que aconteceu com o agendamento depois de uma rodada de questões.
class ResultadoRevisao {
  const ResultadoRevisao({
    required this.estado,
    required this.atualizado,
    required this.hoje,
  });

  final EstadoRevisao estado;

  /// false quando o aluno acertou tudo antes do dia marcado: conta só como
  /// prática extra e a sequência de revisões não avança.
  final bool atualizado;

  final DateTime hoje;

  /// Ex.: "amanhã (19/10)" ou "em 3 dias (21/10)".
  String get descricao {
    final dias = _diasEntre(hoje, estado.proximaRevisao);
    final quando = dias <= 1 ? 'amanhã' : 'em $dias dias';
    return '$quando (${dataCurta(estado.proximaRevisao)})';
  }
}

/// Tópico que o aluno precisa revisar hoje (ou que já estava atrasado).
class RevisaoPendente {
  const RevisaoPendente({
    required this.idTopico,
    required this.nomeTopico,
    required this.diasDeAtraso,
  });

  final String idTopico;
  final String nomeTopico;

  /// 0 = a revisão é para hoje.
  final int diasDeAtraso;
}

class RevisaoService {
  RevisaoService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static num _numero(dynamic valor) => num.parse(valor.toString());

  static EstadoRevisao _estadoDaLinha(Map<String, dynamic> linha) {
    return EstadoRevisao(
      repeticoes: _numero(linha['repeticoes']).toInt(),
      fatorFacilidade: _numero(linha['fator_facilidade']).toDouble(),
      intervaloDias: _numero(linha['intervalo_dias']).toInt(),
      proximaRevisao: DateTime.parse(linha['proxima_revisao'].toString()),
    );
  }

  /// Registra o resultado de uma rodada de questões do tópico e agenda a
  /// próxima revisão com o SM-2.
  static Future<ResultadoRevisao> registrarResultado({
    required String idTopico,
    required int acertos,
    required int total,
  }) async {
    final usuario = _client.auth.currentUser;
    if (usuario == null) throw StateError('Usuário não logado.');

    final hoje = Sm2.soData(DateTime.now());
    final qualidade = Sm2.qualidade(acertos: acertos, total: total);

    final linha = await _client
        .from('revisao_topico')
        .select()
        .eq('user_id', usuario.id)
        .eq('id_topico', idTopico)
        .maybeSingle();
    final EstadoRevisao? atual = linha == null ? null : _estadoDaLinha(linha);

    // Acertou tudo antes do dia marcado: é só prática extra e a sequência não
    // avança (senão bastaria clicar em "Refazer" para pular de 3 para 15 dias).
    // Errar antes da hora continua recomeçando a sequência.
    if (atual != null && atual.proximaRevisao.isAfter(hoje) && qualidade >= 3) {
      return ResultadoRevisao(estado: atual, atualizado: false, hoje: hoje);
    }

    final novo = Sm2.calcular(atual: atual, qualidade: qualidade, hoje: hoje);

    await _client.from('revisao_topico').upsert({
      'user_id': usuario.id,
      'id_topico': idTopico,
      'repeticoes': novo.repeticoes,
      'fator_facilidade': novo.fatorFacilidade,
      'intervalo_dias': novo.intervaloDias,
      'proxima_revisao': paraDataBanco(novo.proximaRevisao),
      'ultima_revisao': paraDataBanco(hoje),
      'ultima_qualidade': qualidade,
    }, onConflict: 'user_id,id_topico');

    return ResultadoRevisao(estado: novo, atualizado: true, hoje: hoje);
  }

  /// Tópicos do aluno cuja revisão é para hoje ou está atrasada, os mais
  /// atrasados primeiro.
  static Future<List<RevisaoPendente>> topicosParaRevisarHoje() async {
    final usuario = _client.auth.currentUser;
    if (usuario == null) return [];

    final hoje = Sm2.soData(DateTime.now());
    final dados = await _client
        .from('revisao_topico')
        .select('id_topico, proxima_revisao, topico(nome)')
        .eq('user_id', usuario.id)
        .lte('proxima_revisao', paraDataBanco(hoje))
        .order('proxima_revisao', ascending: true);

    return dados.map<RevisaoPendente>((linha) {
      final topico = linha['topico'];
      final nome = topico is Map ? topico['nome'] : null;
      final prevista = DateTime.parse(linha['proxima_revisao'].toString());
      final atraso = _diasEntre(prevista, hoje);
      return RevisaoPendente(
        idTopico: linha['id_topico'].toString(),
        nomeTopico: (nome ?? 'Tópico').toString(),
        diasDeAtraso: atraso < 0 ? 0 : atraso,
      );
    }).toList();
  }
}