import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/editar_resumo.dart';
import 'package:testeapp/tema.dart';

class MeusResumos extends StatefulWidget {
  const MeusResumos({super.key});

  @override
  State<MeusResumos> createState() => _MinhasState();
}

class _MinhasState extends State<MeusResumos> {
  User? user;

  late final _resumoStream = Supabase.instance.client
      .from('topico')
      .stream(primaryKey: ['id'])
      .eq('uid_professor', user!.id)
      .order('id_disciplina');

  

  final supabase = Supabase.instance.client;

    // deleta o resumo
  Future<void> deletarItem(int idParaDeletar) async {
    try {
      await supabase
          .from('topico')
          .delete()
          .eq('id', idParaDeletar);

      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('Item deletado com sucesso')));

    } catch (e) { // ERRO
      ScaffoldMessenger.of(context).showSnackBar
      (SnackBar(content: Text('Erro ao deletar: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    user = Supabase.instance.client.auth.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: IconButton(onPressed:() {Navigator.pop(context);}, icon: Icon(Icons.arrow_back)),),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _resumoStream,
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
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (context) => EditarResumoScreen(idTopico: topico[index]['id'].toString())
                          )
                        );
                      },
                      child: Container(
                        decoration: AppTema.cartao(context),
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                                Flexible(
                                  child: Text(
                                    topico[index]['nome'],
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                            Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                // mensagem de confirmação
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Excluir resumo?'),
                                      content: const Text('Deseja mesmo excluir esse resumo?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop(); // NÃO
                                          }, 
                                          child: const Text('Não'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            Navigator.of(context).pop(); 
                                            await deletarItem(topico[index]['id']); // SIM
                                          }, 
                                          child: Text('Sim', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                        )
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
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
