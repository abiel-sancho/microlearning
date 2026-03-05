import 'package:flutter/material.dart';
import 'package:testeapp/login.dart';

class Registrar extends StatelessWidget {
  
  const Registrar({super.key});
  //o que isso faz????


  @override


  // por enquanto essa tela não faz nada :(
  // pq eu não queria criar todo o sistema de conta e depois ter que refazer quando implementasse um banco de dados
  
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: IconButton(onPressed: () {Navigator.pop(context);}, icon: Icon(Icons.arrow_back)),
      title: Text('Registar'),),
            body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Usuário:'),
            SizedBox(width: 200, child: TextField()),
            SizedBox(height: 30),

            Text('Senha'),
            SizedBox(width: 200, child: TextField(obscureText: true, obscuringCharacter: '*')),
            SizedBox(height: 30),

            Text('Digite a senha novamente'),
            SizedBox(width: 200, child: TextField(obscureText: true, obscuringCharacter: '*',)),
            SizedBox(height: 30,),

            ElevatedButton(onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => Login()));
              },
               child: Text('Login')),
          ],
        ),
      ),
    );
  }
}