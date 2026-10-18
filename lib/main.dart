import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:testeapp/criar_questao.dart';
import 'package:testeapp/login.dart';

void main() async {

  await Supabase.initialize(
    url: 'https://auxowibptgdpcldmzrnd.supabase.co',
    anonKey: 'sb_publishable_bMJtUaOnpllVBnulNMI6Sg_XsYxjhkp',
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
      title: 'Microlearning',

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 38, 172, 107)),
      ),
      home: Login(),
    );
  }
}