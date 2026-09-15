import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

final Uri _url = Uri.parse('https://github.com/abiel-sancho');

Future<void> _abrirLink() async {
  if (!await launchUrl(_url)) {
    throw Exception('Não foi possível lançar $_url');
  }
}

class Sobre extends StatelessWidget{
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Título do app?", style: TextStyle(fontSize: 40), textAlign: TextAlign.center,),
            SizedBox(height: 10),
            Text("Esta aplicação tem como objetivo principal auxiliar no aprendizado de novos conceitos, assim como na manutenção de conhecimentos prévios, especialmente de alunos do ensino médio, com um foco no auxílio do estudos desses alunos para o ENEM.\nUtilizando da tecnologia de revisão espaçada, o app complementa métodos tradicionais de ensino."),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Github:"),
                SizedBox( width: 3),
                TextButton(onPressed: _abrirLink, child: Text("github.com/abiel-sancho"))
              ],
            )
          ],
        ),
      ),
    );
  }
}