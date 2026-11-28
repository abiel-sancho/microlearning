import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:testeapp/inicio.dart';
import 'package:testeapp/login.dart';
import 'package:testeapp/tema.dart';

void main() async {
  // Necessário antes de qualquer await que use plugins (a sessão salva).
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    // Projeto Supabase NOVO (modelo de dados novo). A chave publishable pode
    // ficar no app; quem protege os dados é o RLS. Sairá do código depois.
    url: 'https://fzftderhaieoevihggsh.supabase.co',
    anonKey: 'sb_publishable_IF5SCCI8Fk9utBYpPPCscg_MUzkpTxo',
  );
  runApp(const MyApp());
}


/// Largura máxima do app em telas largas (professor no computador).
const double larguraMaximaDoApp = 1000;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navegador = GlobalKey<NavigatorState>();
  late final StreamSubscription<AuthState> _sessao;

  @override
  void initState() {
    super.initState();
    // Se a sessão terminar com o app aberto (saiu, foi revogada ou não deu
    // para renovar), volta ao login e limpa a pilha de telas.
    _sessao = Supabase.instance.client.auth.onAuthStateChange.listen((estado) {
      if (estado.event != AuthChangeEvent.signedOut) return;
      _navegador.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Login()),
        (rota) => false,
      );
    });
  }

  @override
  void dispose() {
    _sessao.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // O supabase_flutter guarda a sessão no aparelho e a recupera no
    // initialize: com sessão salva, abre direto no Início.
    final logado = Supabase.instance.client.auth.currentSession != null;

    return MaterialApp(
      navigatorKey: _navegador,
      localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    FlutterQuillLocalizations.delegate,
  ],
      debugShowCheckedModeBanner: false,
      title: 'MicroLearning App',

      theme: AppTema.claro,
      // Telas largas (computador, navegador): o app fica numa coluna
      // centralizada de até 1000 px, com a barra do topo e os diálogos
      // juntos. No celular, a largura é a da tela e nada muda.
      builder: (context, child) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: larguraMaximaDoApp),
            child: child,
          ),
        ),
      ),
      home: logado ? const InicioScreen() : const Login(),
    );
  }
}
