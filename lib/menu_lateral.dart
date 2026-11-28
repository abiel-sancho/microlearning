import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/criar_conteudo.dart';
import 'package:testeapp/login.dart';
import 'package:testeapp/meus_resumos.dart';
import 'package:testeapp/questoes_aluno.dart';
import 'package:testeapp/revisoes_pendentes.dart';
import 'package:testeapp/sobre.dart';

/// Menu lateral (endDrawer) do app, o mesmo em Disciplinas e em Tópicos
/// (etapa 33). Antes ficava escrito dentro de `disciplinas.dart`.
///
/// Mostra foto (toque para trocar), nome e papel; as opções de conteúdo para
/// professor e admin; Disciplinas; Sobre o app; e Sair.
class MenuLateral extends StatefulWidget {
  const MenuLateral({super.key, this.naTelaDeDisciplinas = false});

  /// Em Disciplinas, o item "Disciplinas" só fecha o menu.
  final bool naTelaDeDisciplinas;

  @override
  State<MenuLateral> createState() => _MenuLateralState();
}

class _MenuLateralState extends State<MenuLateral> {
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  Uint8List? _arquivoFoto; // prévia local (bytes) enquanto envia
  String? _avatarUrl; // URL salva no perfil do usuário (Auth)
  bool _enviando = false;

  String? _nomePerfil;
  String? _papel;

  @override
  void initState() {
    super.initState();
    // O menu é montado de novo a cada vez que abre: a foto sempre vem atual.
    final url = _supabase.auth.currentUser?.userMetadata?['avatar_url'];
    if (url is String && url.isNotEmpty) _avatarUrl = url;
    _carregarPerfil();
  }

  // ---------------------------------------------------------------------------
  // Dados
  // ---------------------------------------------------------------------------

  /// Nome e papel vêm de `perfis` (fonte oficial; o papel só o admin altera).
  Future<void> _carregarPerfil() async {
    final usuario = _supabase.auth.currentUser;
    if (usuario == null) return;
    try {
      final perfil = await _supabase
          .from('perfis')
          .select('nome, papel')
          .eq('id', usuario.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _nomePerfil = perfil?['nome'] as String?;
        _papel = perfil?['papel'] as String?;
      });
    } catch (erro, pilha) {
      // Sem o perfil, o menu continua: nome do cadastro e papel "Aluno".
      debugPrint('Erro ao carregar o perfil (menu): $erro\n$pilha');
    }
  }

  /// Nome do perfil; se não carregou, o nome enviado no cadastro.
  String get _nome {
    final doPerfil = _nomePerfil?.trim();
    if (doPerfil != null && doPerfil.isNotEmpty) return doPerfil;
    final username = _supabase.auth.currentUser?.userMetadata?['username'];
    return username is String ? username.trim() : '';
  }

  String get _rotuloPapel => switch (_papel) {
        'professor' => 'Professor',
        'admin' => 'Coordenação',
        _ => 'Aluno',
      };

  /// Professor e coordenação veem as opções de conteúdo.
  bool get _podeCriarConteudo => _papel == 'professor' || _papel == 'admin';

  // ---------------------------------------------------------------------------
  // Foto de perfil (mesmo código que estava em disciplinas.dart)
  // ---------------------------------------------------------------------------

  Future<void> _trocarFoto() async {
    final usuario = _supabase.auth.currentUser;
    final XFile? escolhida = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (escolhida == null || usuario == null) return;

    // Funciona na web e no celular (não depende de File/path).
    final bytes = await escolhida.readAsBytes();

    // Mostra a foto na hora, antes do envio terminar.
    setState(() {
      _arquivoFoto = bytes;
      _enviando = true;
    });

    try {
      // Tipo da imagem: primeiro pelo mimeType, depois pelo nome.
      var tipo = escolhida.mimeType ?? '';
      if (!tipo.startsWith('image/')) {
        var ext = escolhida.name.split('.').last.toLowerCase();
        if (ext == 'jpg') ext = 'jpeg';
        const permitidos = ['jpeg', 'png', 'webp', 'gif'];
        tipo = 'image/${permitidos.contains(ext) ? ext : 'jpeg'}';
      }

      // Um arquivo por usuário, dentro da pasta com o id dele (migration 6).
      final caminho = '${usuario.id}/avatar';
      await _supabase.storage.from('avatars').uploadBinary(
            caminho,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: tipo),
          );

      // O "?v=" evita que o Flutter mostre a imagem antiga em cache.
      final url = '${_supabase.storage.from('avatars').getPublicUrl(caminho)}'
          '?v=${DateTime.now().millisecondsSinceEpoch}';
      await _supabase.auth.updateUser(UserAttributes(data: {'avatar_url': url}));

      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
        _arquivoFoto = null; // agora usa a imagem da rede
        _enviando = false;
      });
    } catch (erro) {
      debugPrint('Erro ao enviar foto: $erro');
      if (!mounted) return;
      setState(() {
        _arquivoFoto = null;
        _enviando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível enviar a foto.')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Ações
  // ---------------------------------------------------------------------------

  /// Fecha o menu e abre a tela.
  void _abrir(Widget tela) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
  }

  void _irParaDisciplinas() {
    Navigator.pop(context); // fecha o menu
    if (!widget.naTelaDeDisciplinas) irParaDisciplinas(context);
  }

  /// Mesmo caminho do Sair do Início: encerra a sessão e limpa a pilha.
  /// (O `main.dart` também volta ao Login ao receber `signedOut`.)
  Future<void> _sair() async {
    final navegador = Navigator.of(context);
    try {
      await _supabase.auth.signOut();
    } catch (erro, pilha) {
      debugPrint('Erro ao sair: $erro\n$pilha');
    }
    navegador.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Login()),
      (rota) => false,
    );
  }

  // ---------------------------------------------------------------------------
  // Interface
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final foto = _arquivoFoto != null
        ? MemoryImage(_arquivoFoto!)
        : (_avatarUrl != null ? NetworkImage(_avatarUrl!) : null) as ImageProvider?;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _trocarFoto,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: foto,
                        child: foto == null
                            ? const Icon(Icons.person, size: 40, color: Colors.grey)
                            : null,
                      ),
                      if (_enviando)
                        const SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
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
          if (_podeCriarConteudo) ...[
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('Inserir microconteúdo'),
              onTap: () => _abrir(const CriarConteudoScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Meus conteudos'),
              onTap: () => _abrir(const MeusResumos()),
            ),
            // Revisão por pares: fila dos colegas da disciplina (admin: todos).
            ListTile(
              leading: const Icon(Icons.rate_review_outlined),
              title: const Text('Revisar conteúdos'),
              onTap: () => _abrir(const RevisoesPendentes()),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.school),
            title: const Text('Disciplinas'),
            onTap: _irParaDisciplinas,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Sobre o app'),
            onTap: () => _abrir(Sobre()),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            onTap: _sair,
          ),
        ],
      ),
    );
  }
}
