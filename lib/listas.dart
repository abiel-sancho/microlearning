import 'package:flutter/material.dart';
//import 'package:testeapp/resumo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class Topicos extends StatefulWidget {
  const Topicos ({super.key, required this.idDisciplina});

  final String idDisciplina;

  @override

  State<Topicos> createState() => _TopicosState();
}

class _TopicosState extends State<Topicos> {

  late final _topicoStream = Supabase.instance.client
      .from('topico')
      .stream(primaryKey: ['id'])
      .eq('id_disciplina', widget.idDisciplina);

  @override

    Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _topicoStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final topico = snapshot.data!;
        return CustomScrollView(
          primary: false,
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  mainAxisSpacing: 10.0,
                  crossAxisSpacing: 10.0,
                  childAspectRatio: 4.0,
                ),
                itemCount: topico.length,
                itemBuilder: (context, index) {
                  return 
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.amber, 
                        boxShadow: [BoxShadow(color: Colors.black, blurRadius: 5.0)],
                        borderRadius: BorderRadius.circular(10.0)
                        ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: Text(topico[index]['nome'], textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const Icon(Icons.question_mark, size: 100),
                        ],
                      ),
                    );
                },
              ),
            ),
          ],
        );
        },
      ),
    );
  }
}