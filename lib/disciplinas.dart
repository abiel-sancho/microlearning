import 'package:flutter/material.dart';
import 'package:testeapp/configuracoes.dart';
import 'package:testeapp/criar_conteudo.dart';
import 'package:testeapp/meus_resumos.dart';
import 'package:testeapp/revisoes_pendentes.dart';
import 'package:testeapp/sobre.dart';
import 'package:testeapp/topicos.dart';
import 'package:testeapp/tema.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/icones_disciplina.dart';

import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class Disciplinas extends StatefulWidget {
  const Disciplinas({super.key});

  @override
  State<Disciplinas> createState() => _DisciplinasState();
}

/// Uma área do ENEM com as suas disciplinas (para desenhar a grade por área).
class _GrupoArea {
  _GrupoArea(this.nome);
  final String nome;
  final List<Map<String, dynamic>> disciplinas = [];
}

/// Grade de Disciplinas por faixa de largura (Material 3, window size
/// classes): no celular fica como antes (2 colunas, ícone 100); em tela
/// maior, mais colunas, ícone menor e cartão mais baixo que largo.
class _Grade {
  const _Grade(this.colunas, this.icone, this.proporcao);
  final int colunas;
  final double icone;
  final double proporcao; // largura ÷ altura do cartão

  static _Grade paraLargura(double largura) {
    if (largura < 600) return const _Grade(2, 100, 1.0); // compacta: celular
    if (largura < 840) return const _Grade(3, 72, 1.1); // média: tablet, janela pequena
    return const _Grade(4, 64, 1.3); // expandida: web e desktop
  }
}

class _DisciplinasState extends State<Disciplinas> {
  final _supabase = Supabase.instance.client;
  final user = Supabase.instance.client.auth.currentUser;

  Uint8List? _arquivoFoto; // prévia local (bytes) enquanto envia
  String? _avatarUrl; // URL salva no Supabase
  bool _enviando = false;
  final ImagePicker _picker = ImagePicker();

  // Dados de `perfis` e `professor_disciplinas`.
  String? _nomePerfil;
  String? _papel;
  Set<int> _minhasDisciplinas = {};

  // Disciplinas agrupadas por área.
  late Future<List<_GrupoArea>> _futuroAreas = _carregarDisciplinas();

  @override
  void initState() {
    super.initState();
    final url = user?.userMetadata?['avatar_url'];
    if (url is String && url.isNotEmpty) {
      _avatarUrl = url;
    }
    _carregarPerfil();
  }

  // ---------------------------------------------------------------------------
  // Dados
  // ---------------------------------------------------------------------------

  /// Busca as disciplinas com o nome da área, já na ordem do mapa de conteúdos,
  /// e agrupa por área.
  Future<List<_GrupoArea>> _carregarDisciplinas() async {
    final linhas = await _supabase
        .from('disciplinas')
        .select('id, sigla, nome, area_id, areas(nome)')
        // ascending: true é obrigatório: no supabase_flutter o padrão do
        // .order() é decrescente (as áreas vinham de trás para frente).
        .order('area_id', ascending: true)
        .order('id', ascending: true);

    final grupos = <int, _GrupoArea>{};
    for (final disciplina in linhas) {
      final areaId = disciplina['area_id'] as int;
      final area = disciplina['areas'] as Map<String, dynamic>?;
      grupos
          .putIfAbsent(areaId, () => _GrupoArea(area?['nome'] as String? ?? 'Outras'))
          .disciplinas
          .add(disciplina);
    }
    return grupos.values.toList();
  }

  /// Nome e papel vêm de `perfis`; para professor, também as disciplinas dele.
  Future<void> _carregarPerfil() async {
    final usuario = user;
    if (usuario == null) return;
    try {
      final perfil = await _supabase
          .from('perfis')
          .select('nome, papel')
          .eq('id', usuario.id)
          .maybeSingle();

      var minhas = <int>{};
      if (perfil?['papel'] == 'professor') {
        final vinculos = await _supabase
            .from('professor_disciplinas')
            .select('disciplina_id')
            .eq('professor_id', usuario.id);
        minhas = {for (final v in vinculos) v['disciplina_id'] as int};
      }

      if (!mounted) return;
      setState(() {
        _nomePerfil = perfil?['nome'] as String?;
        _papel = perfil?['papel'] as String?;
        _minhasDisciplinas = minhas;
      });
    } catch (erro, pilha) {
      // Sem o perfil, a tela continua: mostra o nome do cadastro e o papel "Aluno".
      debugPrint('Erro ao carregar o perfil: $erro\n$pilha');
    }
  }

  void _tentarDeNovo() {
    setState(() => _futuroAreas = _carregarDisciplinas());
  }

  /// Nome do perfil; se não carregou, o nome enviado no cadastro.
  String get _nome {
    final doPerfil = _nomePerfil?.trim();
    if (doPerfil != null && doPerfil.isNotEmpty) return doPerfil;
    final username = user?.userMetadata?['username'];
    return username is String ? username.trim() : '';
  }

  String get _rotuloPapel => switch (_papel) {
        'professor' => 'Professor',
        'admin' => 'Coordenação',
        _ => 'Aluno',
      };

  /// Professor e coordenação veem as opções de conteúdo no menu.
  bool get _podeCriarConteudo => _papel == 'professor' || _papel == 'admin';

  // ---------------------------------------------------------------------------
  // Foto de perfil (sem mudanças nesta etapa)
  // ---------------------------------------------------------------------------

  // Recebe o setState do Drawer para que ele seja redesenhado
  Future<void> _pickImage(StateSetter setDrawerState) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery, // Use ImageSource.camera para tirar foto na hora
      imageQuality: 80,
    );

    if (pickedFile == null || user == null) return;

    // Funciona na web e no celular (não depende de File/path)
    final bytes = await pickedFile.readAsBytes();

    // Mostra a foto na hora, antes do upload terminar
    setDrawerState(() {
      _arquivoFoto = bytes;
      _enviando = true;
    });

    try {
      final supabase = Supabase.instance.client;

      // Descobre o tipo da imagem: primeiro pelo mimeType, depois pelo nome
      var contentType = pickedFile.mimeType ?? '';
      if (!contentType.startsWith('image/')) {
        var ext = pickedFile.name.split('.').last.toLowerCase();
        if (ext == 'jpg') ext = 'jpeg';
        const permitidos = ['jpeg', 'png', 'webp', 'gif'];
        contentType = 'image/${permitidos.contains(ext) ? ext : 'jpeg'}';
      }

      // Um arquivo por usuário, dentro de uma pasta com o id dele
      final caminho = '${user!.id}/avatar';

      await supabase.storage.from('avatars').uploadBinary(
            caminho,
            bytes,
            fileOptions: FileOptions(
              upsert: true, // sobrescreve a foto anterior
              contentType: contentType,
            ),
          );

      // O "?v=" evita que o Flutter mostre a imagem antiga em cache
      final url = '${supabase.storage.from('avatars').getPublicUrl(caminho)}?v=${DateTime.now().millisecondsSinceEpoch}';

      // Guarda a URL no perfil do usuário
      await supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': url}),
      );

      setDrawerState(() {
        _avatarUrl = url;
        _arquivoFoto = null; // agora usa a imagem da rede
        _enviando = false;
      });
    } catch (e) {
      debugPrint('Erro ao enviar foto: $e');
      setDrawerState(() {
        _arquivoFoto = null;
        _enviando = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível enviar a foto.')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Interface
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: Drawer(
        child: StatefulBuilder(
          builder: (context, setDrawerState) {
            return ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _pickImage(setDrawerState),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: _arquivoFoto != null ? MemoryImage(_arquivoFoto!) : (_avatarUrl != null ? NetworkImage(_avatarUrl!) : null) as ImageProvider?,
                              child: (_arquivoFoto == null && _avatarUrl == null) ? const Icon(Icons.person, size: 40, color: Colors.grey,)
                                  : null,
                            ),
                            if (_enviando)
                              const SizedBox(
                                width: 80,
                                height: 80,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 25),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nome.isEmpty ? '???' : _nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _rotuloPapel,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Visibility(
                  visible: _podeCriarConteudo,
                  child: ListTile(
                    leading: const Icon(Icons.message),
                    title: const Text('Inserir microconteúdo'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CriarConteudoScreen(),
                        ),
                      );
                    },
                  ),
                ),
                Visibility(
                  visible: _podeCriarConteudo,
                  child: ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: const Text('Meus conteudos'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MeusResumos(),
                        ),
                      );
                    },
                  ),
                ),
                // Revisão por pares: fila dos colegas da disciplina (admin: todos).
                Visibility(
                  visible: _podeCriarConteudo,
                  child: ListTile(
                    leading: const Icon(Icons.rate_review_outlined),
                    title: const Text('Revisar conteúdos'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RevisoesPendentes(),
                        ),
                      );
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.school),
                  title: const Text('Disciplinas'),
                  // Já estamos em Disciplinas: só fecha o menu.
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Sobre o app'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Sobre()),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: (index) async {
          if (index == 0) {
            // Home: volta para a tela Início (que está logo abaixo na pilha).
            Navigator.pop(context);
          } else if (index == 1) {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => Configuracoes()),
            );
            // Ao voltar, relê a foto salva no perfil do usuário.
            final url = Supabase.instance.client.auth.currentUser?.userMetadata?['avatar_url'];
            if (!mounted) return;
            if (url is String && url.isNotEmpty) {
              setState(() => _avatarUrl = url);
            }
          }
          // index 2 (Favoritos): ainda sem ação. Pendente de decisão.
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Configurações"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Favoritos"),
        ],
      ),
      body: FutureBuilder<List<_GrupoArea>>(
        future: _futuroAreas,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('Erro ao carregar disciplinas: ${snapshot.error}');
            return _erroAoCarregar(context);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final areas = snapshot.data!;
          // Largura real da coluna do app (até 1000 px, ver main.dart).
          return LayoutBuilder(builder: (context, limites) {
            final grade = _Grade.paraLargura(limites.maxWidth);
            return CustomScrollView(
              primary: false,
              slivers: <Widget>[
                for (final area in areas) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        area.nome,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: grade.colunas,
                        mainAxisSpacing: 10.0,
                        crossAxisSpacing: 10.0,
                        childAspectRatio: grade.proporcao,
                      ),
                      itemCount: area.disciplinas.length,
                      itemBuilder: (context, index) =>
                          _cartaoDisciplina(context, area.disciplinas[index], grade.icone),
                    ),
                  ),
                ],
                const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
              ],
            );
          });
        },
      ),
    );
  }

  /// Card de uma disciplina: mesmo visual de antes (nome + ícone grande),
  /// com o selo "Minha disciplina" para o professor vinculado a ela.
  /// No computador, o cartão sobe um pouco com o mouse em cima e o cursor
  /// vira a mãozinha (`_RespostaAoMouse`); no toque, nada muda.
  Widget _cartaoDisciplina(
      BuildContext context, Map<String, dynamic> disciplina, double tamanhoIcone) {
    final cores = Theme.of(context).colorScheme;
    final minha = _minhasDisciplinas.contains(disciplina['id']);

    return _RespostaAoMouse(
      child: GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Topicos(
              idDisciplina: disciplina['id'].toString(),
            ),
          ),
        );
      },
      child: Container(
        decoration: AppTema.cartao(
          context,
          cor: cores.secondaryContainer,
        ),
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      disciplina['nome'],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: cores.onSecondaryContainer,
                          ),
                    ),
                  ),
                  Icon(
                    iconeDaDisciplina(disciplina),
                    size: tamanhoIcone,
                    color: cores.secondary.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
            if (minha)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cores.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Minha disciplina',
                    style: TextStyle(fontSize: 10, color: cores.onPrimary),
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _erroAoCarregar(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Não foi possível carregar as disciplinas.\nVerifique sua internet e tente de novo.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _tentarDeNovo,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resposta ao mouse (web e desktop): cursor de clique e o cartão sobe
/// um pouco (1,5% da altura) e cresce 3% enquanto o mouse está em cima.
class _RespostaAoMouse extends StatefulWidget {
  const _RespostaAoMouse({required this.child});
  final Widget child;

  @override
  State<_RespostaAoMouse> createState() => _RespostaAoMouseState();
}

class _RespostaAoMouseState extends State<_RespostaAoMouse> {
  bool _emCima = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _emCima = true),
      onExit: (_) => setState(() => _emCima = false),
      child: AnimatedSlide(
        offset: _emCima ? const Offset(0, -0.015) : Offset.zero,
        duration: const Duration(milliseconds: 150),
        child: AnimatedScale(
          scale: _emCima ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: widget.child,
        ),
      ),
    );
  }
}
