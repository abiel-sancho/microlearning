import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/inicio.dart';

/// Tela de login, cadastro e recuperação de senha.
///
/// Antes usava o componente pronto `SupaEmailAuth` (pacote supabase_auth_ui),
/// que não permite mostrar/ocultar a senha nem controlar as mensagens.
/// Agora o formulário é próprio, com o mesmo layout, e chama o Supabase direto.
class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

/// Os três modos que a tela pode mostrar.
enum _Modo { entrar, criarConta, recuperarSenha }

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  final _nomeController = TextEditingController();

  _Modo _modo = _Modo.entrar;
  bool _carregando = false;

  // Cada campo de senha tem o seu próprio "olho".
  bool _ocultarSenha = true;
  bool _ocultarConfirmacao = true;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    _nomeController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Ações
  // ---------------------------------------------------------------------------

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      switch (_modo) {
        case _Modo.entrar:
          await _entrar();
        case _Modo.criarConta:
          await _criarConta();
        case _Modo.recuperarSenha:
          await _recuperarSenha();
      }
    } catch (erro) {
      _mostrarMensagem(_traduzirErro(erro), erro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _entrar() async {
    await _supabase.auth.signInWithPassword(
      email: _emailController.text.trim(),
      password: _senhaController.text,
    );
    _irParaInicio();
  }

  Future<void> _criarConta() async {
    final resposta = await _supabase.auth.signUp(
      email: _emailController.text.trim(),
      password: _senhaController.text,
      data: {'username': _nomeController.text.trim()},
    );

    // Quando a confirmação de e-mail está ligada e o e-mail já tem conta,
    // o Supabase não dá erro: devolve um usuário sem identidades.
    if (resposta.user?.identities?.isEmpty ?? false) {
      _mostrarMensagem(
        'Este email já está cadastrado. Faça login.',
        erro: true,
      );
      _trocarModo(_Modo.entrar);
      return;
    }

    if (resposta.session != null) {
      // Confirmação de e-mail desligada: a pessoa já entra direto.
      _mostrarMensagem('Conta criada com sucesso!');
      _irParaInicio();
    } else {
      // Confirmação de e-mail ligada: precisa clicar no link antes de entrar.
      _mostrarMensagem(
        'Conta criada! Enviamos um link de confirmação para o seu email.\n'
        'Confirme e depois faça login.',
      );
      _trocarModo(_Modo.entrar);
    }
  }

  Future<void> _recuperarSenha() async {
    await _supabase.auth.resetPasswordForEmail(_emailController.text.trim());
    _mostrarMensagem('Email de redefinição de senha enviado.');
    _trocarModo(_Modo.entrar);
  }

  /// Troca a tela de login pela tela inicial. Com `pushReplacement`, o botão
  /// "voltar" não traz a pessoa de volta ao login depois de entrar.
  void _irParaInicio() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => InicioScreen()),
    );
  }

  void _trocarModo(_Modo novo) {
    if (!mounted) return;
    setState(() {
      _modo = novo;
      _ocultarSenha = true;
      _ocultarConfirmacao = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Mensagens
  // ---------------------------------------------------------------------------

  /// Mostra a mensagem no rodapé. Antes o SnackBar era criado mas nunca
  /// exibido, porque faltava o `showSnackBar`.
  void _mostrarMensagem(String texto, {bool erro = false}) {
    if (!mounted) return;
    final cores = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            texto,
            textAlign: TextAlign.center,
            style: erro ? TextStyle(color: cores.onError) : null,
          ),
          backgroundColor: erro ? cores.error : null,
          duration: const Duration(seconds: 5),
          width: 280,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }

  /// Converte os erros do Supabase (em inglês) em mensagens em português.
  /// Lista de códigos: documentação do Supabase Auth, "Error codes".
  String _traduzirErro(Object erro) {
    if (erro is AuthRetryableFetchException) {
      return 'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
    }
    if (erro is AuthException) {
      switch (erro.code) {
        case 'invalid_credentials':
          return 'Email ou senha incorretos.';
        case 'email_not_confirmed':
          return 'Confirme seu email antes de entrar. Verifique sua caixa de entrada.';
        case 'user_already_exists':
        case 'email_exists':
          return 'Este email já está cadastrado. Faça login.';
        case 'weak_password':
          return 'Senha fraca. Escolha uma senha mais forte.';
        case 'over_email_send_rate_limit':
        case 'over_request_rate_limit':
          return 'Muitas tentativas. Aguarde alguns minutos e tente de novo.';
        case 'email_address_invalid':
          return 'Digite um email válido.';
        case 'signup_disabled':
          return 'O cadastro de novas contas está desativado no momento.';
      }
    }
    return 'Um erro inesperado aconteceu. Tente novamente.';
  }

  // ---------------------------------------------------------------------------
  // Validações
  // ---------------------------------------------------------------------------

  static final _formatoEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _validarEmail(String? valor) {
    if (valor == null || !_formatoEmail.hasMatch(valor.trim())) {
      return 'Digite um email válido';
    }
    return null;
  }

  String? _validarSenha(String? valor) {
    if (valor == null || valor.length < 6) {
      return 'Digite uma senha que tenha no mínimo 6 caracteres';
    }
    return null;
  }

  String? _validarConfirmacao(String? valor) {
    if (valor != _senhaController.text) return 'As senhas não são iguais';
    return null;
  }

  String? _validarNome(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Esse campo deve ser preenchido';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Interface
  // ---------------------------------------------------------------------------

  /// Ícone de olho que alterna entre mostrar e ocultar a senha.
  Widget _botaoVisibilidade({
    required bool oculto,
    required VoidCallback aoTocar,
  }) {
    return IconButton(
      icon: Icon(oculto ? Icons.visibility_off : Icons.visibility),
      tooltip: oculto ? 'Mostrar senha' : 'Ocultar senha',
      onPressed: aoTocar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final entrando = _modo == _Modo.entrar;
    final criando = _modo == _Modo.criarConta;
    final recuperando = _modo == _Modo.recuperarSenha;

    return Scaffold(
      // Rola quando o teclado abre, em vez de estourar a tela.
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(60, 100, 60, 24),
        child: Center(
          // Em tablet e na web o formulário não estica além de 400 px.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/icon/logoapp.png',
                          width: 120,
                          height: 120,
                          semanticLabel: 'Logo do Saberes ENEM',
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      textInputAction: recuperando
                          ? TextInputAction.done
                          : TextInputAction.next,
                      validator: _validarEmail,
                      onFieldSubmitted: (_) {
                        if (recuperando) _enviar();
                      },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.email),
                        label: Text('Digite seu email:'),
                      ),
                    ),

                    if (!recuperando) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _senhaController,
                        obscureText: _ocultarSenha,
                        autofillHints: entrando
                            ? const [AutofillHints.password]
                            : const [AutofillHints.newPassword],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        textInputAction: entrando
                            ? TextInputAction.done
                            : TextInputAction.next,
                        validator: _validarSenha,
                        onFieldSubmitted: (_) {
                          if (entrando) _enviar();
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock),
                          label: const Text('Senha:'),
                          suffixIcon: _botaoVisibilidade(
                            oculto: _ocultarSenha,
                            aoTocar: () =>
                                setState(() => _ocultarSenha = !_ocultarSenha),
                          ),
                        ),
                      ),
                    ],

                    if (criando) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmarSenhaController,
                        obscureText: _ocultarConfirmacao,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        textInputAction: TextInputAction.next,
                        validator: _validarConfirmacao,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock),
                          label: const Text('Confirme a senha'),
                          suffixIcon: _botaoVisibilidade(
                            oculto: _ocultarConfirmacao,
                            aoTocar: () => setState(
                              () => _ocultarConfirmacao = !_ocultarConfirmacao,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nomeController,
                        autofillHints: const [AutofillHints.name],
                        textCapitalization: TextCapitalization.words,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        textInputAction: TextInputAction.done,
                        validator: _validarNome,
                        onFieldSubmitted: (_) => _enviar(),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.person),
                          label: Text('Nome'),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    ElevatedButton(
                      // Desligado enquanto espera o Supabase: evita clique duplo.
                      onPressed: _carregando ? null : _enviar,
                      child: _carregando
                          ? SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                color: Theme.of(context).colorScheme.primary,
                                strokeWidth: 1.5,
                              ),
                            )
                          : Text(switch (_modo) {
                              _Modo.entrar => 'Entrar',
                              _Modo.criarConta => 'Criar conta',
                              _Modo.recuperarSenha =>
                                'Enviar email de redefinição de senha',
                            }),
                    ),
                    const SizedBox(height: 16),

                    if (entrando)
                      TextButton(
                        onPressed: () => _trocarModo(_Modo.recuperarSenha),
                        child: const Text('Esqueceu a senha?'),
                      ),
                    if (recuperando)
                      TextButton(
                        onPressed: () => _trocarModo(_Modo.entrar),
                        child: const Text('Voltar para Login'),
                      )
                    else
                      TextButton(
                        onPressed: () => _trocarModo(
                          entrando ? _Modo.criarConta : _Modo.entrar,
                        ),
                        child: Text(
                          entrando
                              ? 'Não tem uma conta? Criar'
                              : 'Já tem uma conta? Entrar',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
