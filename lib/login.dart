import 'package:flutter/material.dart';
import 'package:testeapp/disciplinas.dart';
import 'package:testeapp/registrar.dart';


class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}


class _LoginState extends State<Login> {

  final TextEditingController controllerUsuario = TextEditingController();
  final TextEditingController controllerSenha = TextEditingController();

  @override
  Widget build(BuildContext context){

    String usuariocerto = 'abiel';
    String senhacerta = '123';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Login'),
      ),
      body: //StreamBuilder<List<Map<String, Dynamic>>>(stream: _someThing, builder: builder)
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Usuário'),
            SizedBox(width: 200, child: TextField(controller: controllerUsuario,)),
            SizedBox(height: 30),

            Text('Senha'),
            SizedBox(width: 200, child: TextField(obscureText: true,obscuringCharacter: '•', controller: controllerSenha,)),
            SizedBox(height: 30),

            ElevatedButton(onPressed: () {
              if(senhacerta==controllerSenha.text && usuariocerto==controllerUsuario.text) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => Disciplinas()));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Usuário ou senha incorretos!', textAlign: TextAlign.center,),
                      duration: const Duration(seconds: 5),
                      width: 280,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 20,
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
               child: Text('Login')),

            SizedBox(height: 30),

            Row( mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Text('Não tem uma conta?'),
              TextButton(onPressed: () {Navigator.push(context, MaterialPageRoute(builder: (context) => Registrar()));}, child: Text('Criar conta'))
              ],
            )
          ],
        ),
      ),
    );
  }
}