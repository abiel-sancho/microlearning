import 'package:flutter/material.dart';
import 'package:testeapp/configuracoes.dart';
import 'package:testeapp/criar_conteudo.dart';
import 'package:testeapp/meus_resumos.dart';
import 'package:testeapp/sobre.dart';
import 'package:testeapp/topicos.dart';
import 'package:testeapp/tema.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/icones_disciplina.dart';

import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class Disciplinas extends StatefulWidget {
  Disciplinas({super.key});

  final user = Supabase.instance.client.auth.currentUser;
  late final String emailUser = user!.email ?? '';

  @override
  State<Disciplinas> createState() => _DisciplinasState();
}

class _DisciplinasState extends State<Disciplinas> {
  final user = Supabase.instance.client.auth.currentUser;

  Uint8List? _arquivoFoto; // prévia local (bytes) enquanto envia
  String? _avatarUrl; // URL salva no Supabase
  bool _enviando = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final url = user?.userMetadata?['avatar_url'];
    if (url is String && url.isNotEmpty) {
      _avatarUrl = url;
    }
  }

  String get _nome {
    final username = user?.userMetadata?['username'];
    return username is String ? username.trim() : '';
  }

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

  final _disciplinaStream = Supabase.instance.client
      .from('disciplina')
      .stream(primaryKey: ['id']);

  late final _isProfessor = Supabase.instance.client
      .from('user_professor')
      .stream(primaryKey: ['id'])
      .eq('email', widget.emailUser)
      .limit(1);

  String selectedPage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: Drawer(

        child: StatefulBuilder(
          builder: (context, setDrawerState) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _isProfessor,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                final acesso = snapshot.data![0]['is_professor'] as bool;

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
                                  acesso ? 'Professor' : 'Aluno',
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
                      visible: acesso,
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
                      visible: acesso,
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
                    ListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text('Disciplinas'),
                      onTap: () {
                        setState(() {
                          selectedPage = 'Settings';
                        });
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.settings),
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
            if (index == 1) {
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
          },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Configurações"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Favoritos"),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _disciplinaStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final disciplina = snapshot.data!;
          return CustomScrollView(
            primary: false,
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10.0,
                    crossAxisSpacing: 10.0,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: disciplina.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Topicos(
                              idDisciplina: disciplina[index]['id'].toString(),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: AppTema.cartao(
                          context,
                          cor: Theme.of(context).colorScheme.secondaryContainer,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                disciplina[index]['nome'],
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                              ),
                            ),
                            Icon(
                              iconeDaDisciplina(disciplina[index]),
                              size: 100,
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}