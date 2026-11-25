import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/disciplinas.dart';
import 'package:testeapp/login.dart';
import 'package:testeapp/painel_revisoes.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  final _supabase = Supabase.instance.client;
  late final User? _usuario = _supabase.auth.currentUser;

  // TODO(revisoes): o painel ainda lê a tabela antiga `revisao_topico`, que
  // não existe no banco novo. Fica escondido até a tela de questões/SM-2 ser
  // adaptada para `revisao_espacada`. Para ver o painel, troque para true.
  static const _mostrarPainelRevisoes = false;

  // Mudar este número recria o painel de revisões, que busca os dados de novo.
  int _recarga = 0;

  // Dados da tabela perfis (fonte oficial do nome e do papel).
  String? _nomePerfil;
  String? _papel;

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
  }

  Future<void> _carregarPerfil() async {
    final usuario = _usuario;
    if (usuario == null) return;
    try {
      final perfil = await _supabase
          .from('perfis')
          .select('nome, papel')
          .eq('id', usuario.id)
          .maybeSingle();
      if (!mounted || perfil == null) return;
      setState(() {
        _nomePerfil = perfil['nome'] as String?;
        _papel = perfil['papel'] as String?;
      });
    } catch (erro, pilha) {
      // Sem o perfil, a tela continua funcionando com o nome do cadastro.
      debugPrint('Erro ao carregar o perfil: $erro\n$pilha');
    }
  }

  /// Nome do perfil; se não carregou, o nome enviado no cadastro.
  String get _nome {
    final doPerfil = _nomePerfil?.trim();
    if (doPerfil != null && doPerfil.isNotEmpty) return doPerfil;
    final username = _usuario?.userMetadata?['username'];
    return username is String ? username.trim() : '';
  }

  String? get _rotuloPapel => switch (_papel) {
        'aluno' => 'Aluno',
        'professor' => 'Professor',
        'admin' => 'Coordenação',
        _ => null,
      };

  Future<void> _irParaDisciplinas() async {
    if (_usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não logado. Faça login primeiro.')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Disciplinas()),
    );

    // Ao voltar, o aluno pode ter respondido questões: atualiza o painel.
    if (mounted) setState(() => _recarga++);
  }

  /// Encerra a sessão e volta ao login, limpando a pilha de telas
  /// (o "voltar" não retorna para dentro do app).
  Future<void> _sair() async {
    try {
      await _supabase.auth.signOut();
    } catch (erro, pilha) {
      debugPrint('Erro ao sair: $erro\n$pilha');
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const Login()),
      (rota) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rotuloPapel = _rotuloPapel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _sair,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _nome.isEmpty ? 'Bem-vindo(a)' : 'Bem-vindo(a), $_nome',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (rotuloPapel != null) ...[
            const SizedBox(height: 8),
            Center(child: Chip(label: Text(rotuloPapel))),
          ],
          const SizedBox(height: 24),
          if (_mostrarPainelRevisoes) ...[
            PainelRevisoes(key: ValueKey(_recarga)),
            const SizedBox(height: 24),
          ],
          ElevatedButton(
            onPressed: _irParaDisciplinas,
            child: const Text('Ir para Disciplinas'),
          ),
        ],
      ),
    );
  }
}
