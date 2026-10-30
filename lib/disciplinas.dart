import 'package:flutter/material.dart';
import 'package:testeapp/criar_conteudo.dart';
import 'package:testeapp/meus_resumos.dart';
import 'package:testeapp/sobre.dart';
import 'package:testeapp/topicos.dart';
import 'package:testeapp/tema.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/icones_disciplina.dart';

class Disciplinas extends StatefulWidget{

  Disciplinas({super.key});

    final user = Supabase.instance.client.auth.currentUser;
    late final String emailUser = user!.email ?? '';
    
  @override


  State<Disciplinas> createState() => _DisciplinasState();
}



class _DisciplinasState extends State<Disciplinas> {



    final _disciplinaStream = Supabase.instance.client
      .from('disciplina')
      .stream(primaryKey: ['id']);

    late final _isProfessor = Supabase.instance.client
      .from('user_professor')
      .stream(primaryKey: ['id'])
      .eq('email', widget.emailUser)
      .limit(1);

  String selectedPage = '';

  @override



  Widget build(BuildContext context) {
    
    return Scaffold(
      endDrawer: Drawer(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _isProfessor,
          builder:(context, snapshot) {
            if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
            
            }
            final isProfessor = snapshot.data!;
            bool access = isProfessor[0]['is_professor'];
            return ListView(
              padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
              child: Text(
                'Drawer Header',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            Visibility(
              visible: access,
              child: ListTile(
                leading: const Icon(Icons.message),
                title: const Text('Inserir microconteúdo'),
                onTap: () {
                  Navigator.push(
                      this.context,
                      MaterialPageRoute(builder: (context) => CriarConteudoScreen()),
                    );
                },
              ),
            ),
            Visibility(
              visible: access,
              child: ListTile(
                leading: const Icon(Icons.account_circle),
                title: const Text('meus conteudos'),
                onTap: () {
                  Navigator.push(
                  this.context,
                  MaterialPageRoute(builder: (context) => MeusResumos())
                  );
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('disciplinas'),
              onTap: () {
                setState(() {
                  selectedPage = 'Settings';
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('sobre o app'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => Sobre()));
              },
            ),
          ],
            );
          },
          
        ),
      ),
      appBar: AppBar(leading: IconButton(onPressed:() {Navigator.pop(context);}, icon: Icon(Icons.arrow_back)),),
      bottomNavigationBar: BottomNavigationBar(items: [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Configurações"),
        BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Favoritos")
      ]),
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
                      decoration: AppTema.cartao(
                        context,
                        cor: Theme.of(context).colorScheme.secondaryContainer,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: Text(disciplina[index]['nome'], 
                          textAlign: TextAlign.center, 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis, 
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSecondaryContainer))),
                          Icon(iconeDaDisciplina(disciplina[index]), size: 100, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6)),
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