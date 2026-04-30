import 'package:flutter/material.dart';
//import 'package:testeapp/registrar.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:testeapp/inicio.dart';
//import 'package:supabase_flutter/supabase_flutter.dart';


class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
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
              localization: SupaEmailAuthLocalization(
                enterEmail: 'Digite seu email:',
                enterPassword: 'Senha:', 
                backToSignIn: 'Voltar para Login',
                confirmPassword: 'Confirme a senha',
                confirmPasswordError: 'As senhas não são iguais',
                dontHaveAccount: 'Não tem uma conta? Criar',
                forgotPassword: 'Esqueceu a senha?',
                haveAccount: 'Já tem uma conta? Entrar',
                passwordLengthError: 'Digite uma senha que tenha no mínimo 6 dígitos',
                passwordResetSent: 'Email de redefinição de senha enviado',
                requiredFieldError: 'Esse campo deve ser preenchido',
                sendPasswordReset: 'Enviar email de redefinição de senha',
                signIn: 'Entrar',
                signUp: 'Criar conta',
                unexpectedError: 'Um erro inesperado aconteceu',
                validEmailError: 'Digite um email válido'
                ),
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