import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/disciplinas.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  final user = Supabase.instance.client.auth.currentUser;

  String? emailUser;
  
  @override


  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Bem-vindo',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Usuário não logado. Faça login primeiro.')),
                    );
                    return;
                  }
                  
                  emailUser = user!.email;
                  
                  await Supabase.instance.client
                      .from('user_professor')
                      .upsert({
                        'email': emailUser
                      },
                      onConflict: 'email',
                      ignoreDuplicates: true);
                  
                  if (mounted) {
                    Navigator.push(
                      this.context,
                      MaterialPageRoute(builder: (context) => Disciplinas()),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro: $e')),
                  );
                }
              },
              child: const Text('Ir para Disciplinas'),
            ),
          ],
        ),
      ),
    );
  }
}