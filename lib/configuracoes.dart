import 'package:flutter/material.dart';
import 'package:testeapp/disciplinas.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class Configuracoes extends StatefulWidget{
  const Configuracoes({super.key});

  @override
  State<Configuracoes> createState() => _ConfiguracoesState();
}

class _ConfiguracoesState extends State<Configuracoes>{

  Uint8List? _arquivoFoto; // prévia local (bytes) enquanto envia
  String? _avatarUrl; // URL salva no Supabase
  bool _enviando = false;
  
  final ImagePicker _picker = ImagePicker();

  final user = Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    final url = user?.userMetadata?['avatar_url'];
    if (url is String && url.isNotEmpty) {
      _avatarUrl = url;
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery, // Use ImageSource.camera para tirar foto na hora
      imageQuality: 80,
    );

    if (pickedFile == null || user == null) return;

    // Funciona na web e no celular (não depende de File/path)
    final bytes = await pickedFile.readAsBytes();

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
      debugPrint('[foto] enviada e salva no perfil: $url');

            if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil atualizada!')),
        );
      }
    }
    catch (e) {
      debugPrint('Erro ao enviar foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível enviar a foto.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:Text('Configurações'),
        leading: IconButton(onPressed: () {Navigator.pop(context);},
        icon: Icon(Icons.arrow_back)),
      ),
      body: Column(
        children: [
          GestureDetector(
            onTap: () => _pickImage(),
            child: Padding(
              padding: EdgeInsetsGeometry.fromLTRB(30, 10, 30, 10),
              child: Row(
                
                children: [
                  Text('Alterar foto de perfil',style: TextStyle(fontSize: 28),),
                  Spacer(),
                  Icon(Icons.camera_alt)
                ],
              ),
            ),
          ),

          Divider(),

          GestureDetector(
            onTap: () => _pickImage(),
            child: Padding(
              padding: EdgeInsetsGeometry.fromLTRB(30, 10, 30, 10),
              child: Row(
                
                children: [
                  Text('Alterar nome de usuário',style: TextStyle(fontSize: 28),),
                  Spacer(),
                  Icon(Icons.person)
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}