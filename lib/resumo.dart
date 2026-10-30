import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:testeapp/questoes_aluno.dart';
import 'package:testeapp/tema.dart';


class Resumo extends StatefulWidget {

  const Resumo ({super.key, required this.idTopico});

  final String idTopico;

  @override
  State<Resumo> createState() => _ResumoState();
}


class _ResumoState extends State<Resumo> {
  
  late final _resumoStream = Supabase.instance.client
      .from('topico')
      .stream(primaryKey: ['id'])
      .eq('id', widget.idTopico);

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
 return Center(child: Markdown(styleSheet: AppTema.markdown(context), data: '# Ainda não tem nenhum resumo aqui! \n\n testando o **markdown**\n *deu certoooo*'),);
            }
            else{
final resumo = snapshot.data!;
          // O campo "texto" pode vir nulo do banco (tópico sem conteúdo).
          final texto = (resumo[0]['texto'] ?? '').toString().trim();

          return Column(
            children: [
              Expanded(
                child: Markdown(
                  styleSheet: AppTema.markdown(context),
                  data: texto.isEmpty ? '*Este tópico ainda não tem texto.*' : texto,
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuestoesAluno(idTopico: widget.idTopico),
                          ),
                        );
                      },
                      icon: const Icon(Icons.quiz),
                      label: const Text('Ir para as questões'),
                    ),
                  ),
                ),
              ),
            ],
          );
            }
          }
        },
      ),
    );
  }
}