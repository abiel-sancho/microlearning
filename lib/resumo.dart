import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';



class Resumo extends StatefulWidget {

  const Resumo ({super.key, required this.idTopico});

  final String idTopico;

  @override
  State<Resumo> createState() => _ResumoState();
}

// obs: do jeito que o código tá agora, quando você seleciona uma opção 
// na tela de tópicos que não possui um resumo, o código quebra. 

// eu podia resolver isso adicionando uma opção pra quando não tiver nada no BD pra impedir o erro,
// tipo uma tela de "não há nada sobre esse tópico".

// mas eu acho que uma resolução melhor seria unir as duas tabelas, 'resumo' e 'topico'
// já que todo tópico precisa ter um resumo (relação 1:1), acho que isso seria melhor.

// será que é uma boa ideia?

class _ResumoState extends State<Resumo> {
  
  late final _resumoStream = Supabase.instance.client
      .from('resumo')
      .stream(primaryKey: ['id'])
      .eq('id_topico', widget.idTopico);

  @override
  Widget build(BuildContext context) {
    return Scaffold (
      appBar: AppBar(title: Text('Teste')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _resumoStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final resumo = snapshot.data!;

          return Center(
            child: Column(
              children: [
                Text(resumo[0]['titulo'], style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),),
                SizedBox(height: 30),
            
                Text(resumo[0]['texto'], style: TextStyle(fontSize: 18))
              ],
            ),
          );
        },
      ),
    );
  }
}