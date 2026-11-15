import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/resumo.dart';
import 'package:testeapp/tema.dart';
import 'package:testeapp/cores_disciplina.dart';


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
    // A tela inteira usa a cor da disciplina (a mesma do cartão dela).
    return Theme(
      data: AppTema.daDisciplina(corDaDisciplina(widget.idDisciplina),
        escuro: Theme.of(context).brightness == Brightness.dark,),
        
      child: Scaffold(
      appBar: AppBar(leading: IconButton(onPressed:() {Navigator.pop(context);}, icon: Icon(Icons.arrow_back)),),
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
                  childAspectRatio: 8.0,
                ),
                itemCount: topico.length,
                itemBuilder: (context, index) {
                  return 
                    GestureDetector(
                      onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => Resumo(idTopico: topico[index]['id'].toString(), idDisciplina: widget.idDisciplina)));
                    },
                      child: Container(
                        decoration: AppTema.cartao(
                          context,
                          cor: Theme.of(context).colorScheme.primaryContainer,
                          borda: Theme.of(context).colorScheme.primary,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: Text(topico[index]['nome'], textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600))),
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
    ),
    );
  }
}
