import 'package:flutter/material.dart';
import 'package:testeapp/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 38, 172, 107)),
      ),
      home: const Login(),
    );
  }
}