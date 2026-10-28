import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/disciplinas.dart';
import 'package:testeapp/painel_revisoes.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  final user = Supabase.instance.client.auth.currentUser;

  String? emailUser;

  // Mudar este número recria o painel de revisões, que busca os dados de novo.
  int _recarga = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Bem-vindo',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          PainelRevisoes(key: ValueKey(_recarga)),
          const SizedBox(height: 24),
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

                if (!mounted) return;
                await Navigator.push(
                  this.context,
                  MaterialPageRoute(builder: (context) => Disciplinas()),
                );

                // Ao voltar, o aluno pode ter respondido questões: atualiza o painel.
                if (mounted) setState(() => _recarga++);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Erro: $e')),
                );
              }
            },
            child: const Text('Ir para Disciplinas'),
          ),
        ],
      ),
    );
  }
}