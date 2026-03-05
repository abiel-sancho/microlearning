import 'package:flutter/material.dart';

class Resumo extends StatelessWidget {
  
  const Resumo({super.key});
  //o que isso faz????


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: IconButton(onPressed: () {Navigator.pop(context);}, icon: Icon(Icons.arrow_back)),),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('aqui vai ter o resumo de cada conteúdo e talvez questões pra responder?'),
            Icon(Icons.my_library_books_sharp, size: 200),
          ],
        ),
      ),
    );
  }
}