import 'package:flutter/material.dart';
import 'package:testeapp/disciplinas.dart';
//import 'package:testeapp/registrar.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';


class LoginDois extends StatelessWidget {
  const LoginDois({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(left: 60, right: 60),
        child: Column(
          children: [
            SizedBox(height: 100),
            SupaEmailAuth(
              localization: SupaEmailAuthLocalization(),
              onSignInComplete: (response) {
                // Navegar para a Home após o login bem-sucedido
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Disciplinas()),
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