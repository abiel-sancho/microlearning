import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/disciplinas.dart';
import 'package:testeapp/login.dart';
import 'package:testeapp/painel_revisoes.dart';
import 'package:testeapp/resumo.dart';
import 'package:testeapp/revisoes_pendentes.dart';
import 'package:testeapp/topicos.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  final _supabase = Supabase.instance.client;
  late final User? _usuario = _supabase.auth.currentUser;

  // Revisão espaçada (SM-2): questões vencidas hoje, pela função
  // `total_revisoes_de_hoje()`. Nulo enquanto carrega ou se falhar.
  int? _revisoesHoje;

  // Busca por código (CLAUDE.md 5.2): microconteúdo ou tópico.
  final _codigoController = TextEditingController();
  bool _buscando = false;

  // Dados da tabela perfis (fonte oficial do nome e do papel).
  String? _nomePerfil;
  String? _papel;

  // Revisão por pares (professor e admin): quantos aguardam e quantos atrasados.
  // Não confundir com as revisões espaçadas (SM-2) acima.
  int? _aguardandoRevisao;
  int _atrasadas = 0;

  bool get _revisaConteudo => _papel == 'professor' || _papel == 'admin';

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
    _carregarRevisoesHoje();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  /// Ajeita o que foi digitado: maiúsculas, espaço/ponto/sublinhado viram
  /// hífen e unidade/tópico ganham o zero à esquerda ("his 3 4 2" →
  /// "HIS-03-04-2"). Devolve nulo se não tiver o formato de código.
  static String? _normalizarCodigo(String texto) {
    final limpo = texto
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[\s._]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final partes = RegExp(r'^([A-Z]{3})-(\d{1,2})-(\d{1,2})(?:-(\d+))?$').firstMatch(limpo);
    if (partes == null) return null;
    final topico =
        '${partes[1]}-${partes[2]!.padLeft(2, '0')}-${partes[3]!.padLeft(2, '0')}';
    final seq = partes[4];
    return seq == null ? topico : '$topico-${int.parse(seq)}';
  }

  /// Código de microconteúdo (SIGLA-UU-TT-N) abre a leitura; código de tópico
  /// (SIGLA-UU-TT) abre os tópicos da disciplina. O RLS vale normalmente:
  /// o aluno só encontra conteúdo publicado.
  Future<void> _buscarCodigo() async {
    if (_buscando) return;
    final mensageiro = ScaffoldMessenger.of(context);
    final codigo = _normalizarCodigo(_codigoController.text);
    if (codigo == null) {
      mensageiro.showSnackBar(const SnackBar(
        content: Text('O código tem o formato HIS-03-04-2 (conteúdo) ou HIS-03-04 (tópico).'),
      ));
      return;
    }
    _codigoController.text = codigo;
    final ehTopico = codigo.split('-').length == 3;

    setState(() => _buscando = true);
    try {
      if (ehTopico) {
        final topico = await _supabase
            .from('topicos')
            .select('id, unidades(disciplina_id)')
            .eq('codigo', codigo)
            .maybeSingle();
        if (!mounted) return;
        final idDisciplina = (topico?['unidades'] as Map?)?['disciplina_id'];
        if (idDisciplina == null) {
          mensageiro.showSnackBar(SnackBar(
            content: Text('Nenhum tópico com o código $codigo. Confira com seu professor.'),
          ));
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Topicos(idDisciplina: idDisciplina.toString()),
          ),
        );
      } else {
        // Arquivado não conta (o código é único entre os não arquivados).
        final micro = await _supabase
            .from('microconteudos')
            .select('id')
            .eq('codigo', codigo)
            .neq('status', 'arquivado')
            .maybeSingle();
        if (!mounted) return;
        if (micro == null) {
          mensageiro.showSnackBar(SnackBar(
            content: Text('Nenhum conteúdo disponível com o código $codigo. '
                'Confira com seu professor.'),
          ));
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Resumo(idMicroconteudo: micro['id'].toString()),
          ),
        );
      }
      // Ao voltar, o aluno pode ter respondido questões.
      if (mounted) _carregarRevisoesHoje();
    } catch (erro, pilha) {
      debugPrint('Erro na busca por código: $erro\n$pilha');
      if (!mounted) return;
      mensageiro.showSnackBar(const SnackBar(
        content: Text('Não foi possível buscar agora. Verifique a conexão.'),
      ));
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  /// Conta as questões vencidas hoje (revisão espaçada, SM-2).
  Future<void> _carregarRevisoesHoje() async {
    if (_usuario == null) return;
    try {
      final total = await _supabase.rpc('total_revisoes_de_hoje') as int?;
      if (!mounted) return;
      setState(() => _revisoesHoje = total ?? 0);
    } catch (erro, pilha) {
      // Sem a contagem, o cartão aparece sem o número.
      debugPrint('Erro ao contar as revisões de hoje: $erro\n$pilha');
    }
  }

  Future<void> _irParaRevisoesDeHoje() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PainelRevisoes()),
    );
    if (mounted) _carregarRevisoesHoje();
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
      _carregarFilaRevisao();
    } catch (erro, pilha) {
      // Sem o perfil, a tela continua funcionando com o nome do cadastro.
      debugPrint('Erro ao carregar o perfil: $erro\n$pilha');
    }
  }

  /// Conta a fila de revisão por pares (função `revisoes_pendentes()`).
  Future<void> _carregarFilaRevisao() async {
    if (!_revisaConteudo) return;
    try {
      final linhas = await _supabase.rpc('revisoes_pendentes') as List? ?? const [];
      if (!mounted) return;
      setState(() {
        _aguardandoRevisao = linhas.length;
        _atrasadas = linhas.where((l) => (l as Map)['atrasada'] == true).length;
      });
    } catch (erro, pilha) {
      // Sem a contagem, o cartão aparece sem o número.
      debugPrint('Erro ao contar a fila de revisão: $erro\n$pilha');
    }
  }

  Future<void> _irParaRevisoes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RevisoesPendentes()),
    );
    if (mounted) _carregarFilaRevisao();
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
      MaterialPageRoute(
        // Nome usado pelo atalho "Ir para Disciplinas" (questoes_aluno.dart).
        settings: const RouteSettings(name: 'disciplinas'),
        builder: (context) => Disciplinas(),
      ),
    );

    // Ao voltar, o aluno pode ter respondido questões: atualiza as revisões.
    // O professor pode ter revisado pelo menu: atualiza a contagem.
    if (mounted) {
      _carregarRevisoesHoje();
      _carregarFilaRevisao();
    }
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
          _cartaoRevisoesDeHoje(context),
          const SizedBox(height: 24),
          _cartaoBuscaCodigo(context),
          const SizedBox(height: 24),
          if (_revisaConteudo) ...[
            _cartaoRevisaoPorPares(context),
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

  /// Cartão da revisão espaçada (SM-2): quantas questões vencem hoje.
  Widget _cartaoRevisoesDeHoje(BuildContext context) {
    final tema = Theme.of(context);
    final n = _revisoesHoje;
    final texto = n == null
        ? 'Questões que você errou voltam aqui no dia certo.'
        : n == 0
            ? 'Nenhuma revisão para hoje.'
            : n == 1
                ? '1 questão para revisar hoje'
                : '$n questões para revisar hoje';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_repeat, color: tema.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Revisões de hoje', style: tema.textTheme.titleMedium),
                ),
                if (n != null && n > 0) Badge(label: Text('$n')),
              ],
            ),
            const SizedBox(height: 8),
            Text(texto),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: _irParaRevisoesDeHoje,
                child: const Text('Abrir'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cartão "Tem um código?": o professor passa o código e o aluno digita aqui.
  Widget _cartaoBuscaCodigo(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_2, color: tema.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Tem um código?', style: tema.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codigoController,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _buscarCodigo(),
              decoration: InputDecoration(
                hintText: 'Ex.: HIS-03-04-2',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _buscando
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Buscar',
                        icon: const Icon(Icons.search),
                        onPressed: _buscarCodigo,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cartão da revisão por pares, só para professor e admin.
  Widget _cartaoRevisaoPorPares(BuildContext context) {
    final tema = Theme.of(context);
    final n = _aguardandoRevisao;
    final texto = n == null
        ? 'Conteúdos de colegas aguardando a sua avaliação.'
        : n == 0
            ? 'Nenhum conteúdo aguardando revisão.'
            : n == 1
                ? '1 conteúdo aguardando revisão'
                : '$n conteúdos aguardando revisão';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rate_review_outlined, color: tema.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Revisão por pares', style: tema.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(texto),
            if (_atrasadas > 0)
              Text(
                _atrasadas == 1 ? '1 atrasada (mais de 7 dias)' : '$_atrasadas atrasadas (mais de 7 dias)',
                style: TextStyle(color: tema.colorScheme.error),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: _irParaRevisoes,
                child: const Text('Revisar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
