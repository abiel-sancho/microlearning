import 'package:flutter/material.dart';
import 'package:testeapp/resumo.dart';
import 'package:testeapp/revisao_service.dart';

/// Painel da tela Início com os tópicos que o aluno deve revisar hoje
/// (repetição espaçada). Tocar em um tópico abre o resumo; de lá o aluno vai
/// para as questões, e o resultado agenda a próxima revisão.
class PainelRevisoes extends StatefulWidget {
  const PainelRevisoes({super.key});

  @override
  State<PainelRevisoes> createState() => _PainelRevisoesState();
}

class _PainelRevisoesState extends State<PainelRevisoes> {
  late Future<List<RevisaoPendente>> _futuro =
      RevisaoService.topicosParaRevisarHoje();

  void _recarregar() {
    setState(() {
      _futuro = RevisaoService.topicosParaRevisarHoje();
    });
  }

  Future<void> _abrir(RevisaoPendente item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Resumo(idTopico: item.idTopico)),
    );
    // Ao voltar, o aluno pode ter concluído a revisão: atualiza a lista.
    if (mounted) _recarregar();
  }

  String _rotulo(int diasDeAtraso) {
    if (diasDeAtraso == 0) return 'Revisar hoje';
    if (diasDeAtraso == 1) return 'Atrasada há 1 dia';
    return 'Atrasada há $diasDeAtraso dias';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<RevisaoPendente>>(
          future: _futuro,
          builder: (context, snapshot) {
            final pendentes = snapshot.data ?? const <RevisaoPendente>[];

            final Widget corpo;
            if (snapshot.connectionState != ConnectionState.done) {
              corpo = const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasError) {
              corpo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Não foi possível carregar as revisões.\n${snapshot.error}'),
                  TextButton(
                    onPressed: _recarregar,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              );
            } else if (pendentes.isEmpty) {
              corpo = const Text(
                'Nenhuma revisão para hoje. Ao responder as questões de um '
                'tópico, as próximas revisões aparecem aqui no dia certo.',
              );
            } else {
              corpo = Column(
                children: [
                  for (final item in pendentes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.nomeTopico),
                      subtitle: Text(
                        _rotulo(item.diasDeAtraso),
                        style: item.diasDeAtraso > 0
                            ? TextStyle(color: tema.colorScheme.error)
                            : null,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _abrir(item),
                    ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_repeat, color: tema.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Revisões de hoje',
                        style: tema.textTheme.titleMedium,
                      ),
                    ),
                    if (pendentes.isNotEmpty)
                      Badge(label: Text('${pendentes.length}')),
                  ],
                ),
                const SizedBox(height: 8),
                corpo,
              ],
            );
          },
        ),
      ),
    );
  }
}