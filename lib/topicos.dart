import 'package:flutter/material.dart';
import 'package:testeapp/resumo.dart';
//mport 'package:testeapp/disciplinas.dart';


class Topicos extends StatelessWidget {
  const Topicos ({super.key});

  @override

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {Navigator.pop(context);}, 
          icon: Icon(Icons.arrow_back)),
          title: Text('História'),
          ),
      
      body: Center(
        child: ListView(
          children: [
            ListTile(title: Text('Império Romano'),
            subtitle: Text('algo sobre o império romano e tal'), 
            leading: Icon(Icons.sunny),
            onTap:() {Navigator.push(context, MaterialPageRoute(builder: (context) => Resumo()));},
            ),

            ListTile(title: Text('Idade Média'),
            subtitle: Text('conceitos básicos sobre a era medieval'), 
            leading: Icon(Icons.castle),
            ),

            ListTile(title: Text('América Colonial'), 
            subtitle: Text('a era das navegações e colonização da América'), 
            leading: Icon(Icons.south_america_sharp),
            ),

            //quando implementar o bd, trocar isso por um listview.build
          ],
        ),
      ),
          //quando eu criar um builder na tela de disciplinas vou mudar isso aqui pra exibir o nome da disciplina no appbar
    );
  }
}