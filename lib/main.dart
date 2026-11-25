import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:testeapp/login.dart';
import 'package:testeapp/tema.dart';

void main() async {

  await Supabase.initialize(
    // Projeto Supabase NOVO (modelo de dados novo). A chave publishable pode
    // ficar no app; quem protege os dados é o RLS. Sairá do código depois.
    url: 'https://fzftderhaieoevihggsh.supabase.co',
    anonKey: 'sb_publishable_IF5SCCI8Fk9utBYpPPCscg_MUzkpTxo',
  );
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    FlutterQuillLocalizations.delegate,
  ],
      debugShowCheckedModeBanner: false,
      title: 'MicroLearning App',

      theme: AppTema.claro,
      home: Login(),
    );
  }
}