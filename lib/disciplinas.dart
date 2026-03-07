import 'package:flutter/material.dart';
import 'package:testeapp/topicos.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Disciplinas extends StatefulWidget{

  const Disciplinas({super.key});

  @override

  State<Disciplinas> createState() => _DisciplinasState();
}

class _DisciplinasState extends State<Disciplinas> {

    final _disciplinaStream = Supabase.instance.client
      .from('disciplina')
      .stream(primaryKey: ['id']);

  @override

  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _disciplinaStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final disciplina = snapshot.data!;
        return CustomScrollView(
          primary: false,
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10.0,
                  crossAxisSpacing: 10.0,
                  childAspectRatio: 1.0,
                ),
                itemCount: disciplina.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => Topicos(idDisciplina: disciplina[index]['id'].toString())));
                    },
                    child: Container(
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
                          Flexible(child: Text(disciplina[index]['nome'], textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const Icon(Icons.question_mark, size: 100),
                        ],
                      ),
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