import 'package:flutter/material.dart';
//import 'package:testeapp/registrar.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:testeapp/inicio.dart';
//import 'package:supabase_flutter/supabase_flutter.dart';


class LoginDois extends StatefulWidget {
  const LoginDois({super.key});

  @override
  State<LoginDois> createState() => _LoginDoisState();
}

class _LoginDoisState extends State<LoginDois> {
  String? emailUser;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(left: 60, right: 60),
        child: Column(
          children: [
            SizedBox(height: 100),
            SupaEmailAuth(
              localization: SupaEmailAuthLocalization(enterEmail: 'entre com email',enterPassword: 'senha:'),
              onSignInComplete: (response) {
                // Navegar para a Home após o login bem-sucedido
                //TODO: verificação se é professor


                  Navigator.push(
                    this.context,
                    MaterialPageRoute(builder: (context) => InicioScreen()),
                  );
              },
              onSignUpComplete: (response) {
                SnackBar(
                  content: const Text(
                    'Conta criada com sucesso!\nFaça login.',
                    textAlign: TextAlign.center,
                  ),
                  duration: const Duration(seconds: 5),
                  width: 280,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              },
              onError: (error) {
            
              },
            ),
          ],
        ),
      ),
    );
  }
}