import 'package:flutter/material.dart';
import 'package:testeapp/topicos.dart';


class Disciplinas extends StatelessWidget{

  const Disciplinas({super.key});

  @override

  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CustomScrollView(
          primary: false,
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverGrid.count( //trocar isso aqui por "SliverGrid.build" e construir cada sliver com base no BD
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                crossAxisCount: 2,
                children: <Widget>[

                  // TEM COMO EU FAZER ISSO SEM REPETIR TANTO?
                  
                  GestureDetector(
                    onTap: () {Navigator.push(context, MaterialPageRoute(builder: (context) => Topicos()));},
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.yellow,
                      child: const Column(children: [
                        Text('História'),
                        Icon(size: 150, Icons.book_outlined, color:Colors.white)
                      ],),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.red,child: const Column(children: [
                      Text('Matemática'),
                      Icon(size: 150, Icons.architecture_outlined, color:Colors.white)
                    ],),
                  ),

                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.blue,
                    child: const Column(children: [
                      Text('Inglês'),
                      Icon(size: 150, Icons.question_mark_outlined, color:Colors.white)
                    ],),
                  ),

                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.orange,
                    child: const Column(children: [
                      Text('Português'),
                      Icon(size: 150, Icons.question_mark_outlined, color:Colors.white)
                    ],),
                  ),

                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.brown,
                    child: const Column(children: [
                      Text('Geografia'),
                      Icon(size: 150, Icons.question_mark_outlined, color:Colors.white)
                    ],),
                  ),

                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.purple,
                    child: const Column(children: [
                      Text('Química'),
                      Icon(size: 150, Icons.question_mark_outlined, color:Colors.white)
                    ],),
                  ),

                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.cyan,
                    child: const Column(children: [
                      Text('Biologia'),
                      Icon(size: 150, Icons.question_mark_outlined, color:Colors.white)
                    ],),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
