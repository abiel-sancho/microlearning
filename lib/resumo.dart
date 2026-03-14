import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
//import 'package:markdown/markdown.dart' as md;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';


class Resumo extends StatefulWidget {

  const Resumo ({super.key, required this.idTopico});

  final String idTopico;

  @override
  State<Resumo> createState() => _ResumoState();
}


class _ResumoState extends State<Resumo> {
  
  late final _resumoStream = Supabase.instance.client
      .from('resumo')
      .stream(primaryKey: ['id'])
      .eq('id_topico', widget.idTopico);

  @override
  Widget build(BuildContext context) {
    return Scaffold (
      appBar: AppBar(leading: IconButton(onPressed:() {Navigator.pop(context);}, icon: Icon(Icons.arrow_back)),
      title: Text('alguma coisa???????'),),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _resumoStream,
        builder: (context, snapshot) {
          if (!snapshot. hasData) {
            return const Center(child: CircularProgressIndicator());
          }else{
            if(snapshot.data == null || snapshot.data!.isEmpty){
 return const Center(child: Markdown(data: '# Ainda não tem nenhum resumo aqui! \n\n testando o **markdown**\n *deu certoooo*'),);
            }
            else{
final resumo = snapshot.data!;

          return Center(
            child: Markdown(data: resumo[0]['texto'])
          );
            }
          }
        },
      ),
    );
  }
}