import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';



class Resumo extends StatefulWidget {

   const Resumo({super.key});

  @override
  State<Resumo> createState() => _ResumoState();
}

class _ResumoState extends State<Resumo> {
  
  final _dadosStream = Supabase.instance.client
      .from('resumo')
      .stream(primaryKey: ['id']);

  @override
  Widget build(BuildContext context) {
    return Scaffold (
      appBar: AppBar(title: Text('Teste')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _dadosStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final dados = snapshot.data!;

          return ListView.builder(
            itemCount: dados.length,
            itemBuilder: (context, index) {
              return Center(
                child: Text(dados[index]['texto'] + 'aaa')
              );
            },
          );
        },
      ),
    );
  }
}