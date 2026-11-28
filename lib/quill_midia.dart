import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Imagens e links no editor Quill (M2.5), usados pelo formulário do
/// professor (`criar_conteudo.dart`) e pela leitura (`resumo.dart`).
///
/// As imagens vão para o bucket `microconteudos` do Storage (migration 11),
/// na pasta com o id de quem envia; o Delta guarda só a URL pública.

const _bucket = 'microconteudos';

/// Lado maior da imagem depois de reduzida (o bucket aceita até 2 MB).
const _ladoMaximo = 1600.0;

/// Desenho das imagens no editor e na leitura. Remover a imagem do texto não
/// apaga o arquivo (o callback padrão tenta apagar arquivo local).
List<EmbedBuilder> embedsDeImagem() => FlutterQuillEmbeds.editorBuilders(
      videoEmbedConfig: null,
      imageEmbedConfig: QuillEditorImageEmbedConfig(
        onImageRemovedCallback: (_) async {},
      ),
    );

/// Botão de imagem da barra do editor (sem vídeo e sem câmera).
List<EmbedButtonBuilder> botoesDeImagem() => FlutterQuillEmbeds.toolbarButtons(
      videoButtonOptions: null,
      cameraButtonOptions: null,
      imageButtonOptions: const QuillToolbarImageButtonOptions(
        tooltip: 'Inserir imagem',
        imageButtonConfig: QuillToolbarImageConfig(
          onRequestPickImage: escolherEEnviarImagem,
        ),
      ),
    );

/// Abre a galeria, reduz a imagem, envia ao Storage e devolve a URL pública
/// (que o Quill insere no texto). Nulo se a pessoa desistir ou der erro.
Future<String?> escolherEEnviarImagem(BuildContext context) async {
  final mensageiro = ScaffoldMessenger.of(context);
  final supabase = Supabase.instance.client;
  final usuario = supabase.auth.currentUser;
  if (usuario == null) return null;

  final XFile? arquivo;
  try {
    arquivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: _ladoMaximo,
      maxHeight: _ladoMaximo,
      imageQuality: 80,
    );
  } catch (erro) {
    debugPrint('Erro ao escolher a imagem: $erro');
    mensageiro.showSnackBar(const SnackBar(content: Text('Não foi possível abrir as imagens.')));
    return null;
  }
  if (arquivo == null) return null;

  final extensao = _extensao(arquivo);
  final tipo = switch (extensao) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/jpeg',
  };
  final aleatorio = Random.secure().nextInt(1 << 32).toRadixString(16);
  final caminho = '${usuario.id}/${DateTime.now().millisecondsSinceEpoch}_$aleatorio.$extensao';

  mensageiro.showSnackBar(const SnackBar(
    content: Text('Enviando a imagem...'),
    duration: Duration(seconds: 2),
  ));
  try {
    final bytes = await arquivo.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      mensageiro.showSnackBar(const SnackBar(
        content: Text('A imagem passou de 2 MB mesmo reduzida. Escolha outra.'),
      ));
      return null;
    }
    await supabase.storage.from(_bucket).uploadBinary(
          caminho,
          bytes,
          fileOptions: FileOptions(contentType: tipo),
        );
    return supabase.storage.from(_bucket).getPublicUrl(caminho);
  } catch (erro, pilha) {
    debugPrint('Erro ao enviar a imagem: $erro\n$pilha');
    mensageiro.showSnackBar(const SnackBar(
      content: Text('Não foi possível enviar a imagem. Verifique a conexão.'),
    ));
    return null;
  }
}

String _extensao(XFile arquivo) {
  final nome = (arquivo.name.isNotEmpty ? arquivo.name : arquivo.path).toLowerCase();
  final ponto = nome.lastIndexOf('.');
  final ext = ponto >= 0 ? nome.substring(ponto + 1) : '';
  return switch (ext) {
    'png' || 'webp' || 'gif' => ext,
    _ => 'jpg', // jpeg, heic convertida pelo picker etc.
  };
}

/// Abrir link na leitura: completa o "https://" se faltar, só aceita http e
/// https e pergunta antes de sair do app.
Future<void> abrirLinkComConfirmacao(BuildContext context, String link) async {
  var texto = link.trim();
  if (!texto.contains('://')) texto = 'https://$texto';
  final uri = Uri.tryParse(texto);
  final mensageiro = ScaffoldMessenger.of(context);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
    mensageiro.showSnackBar(const SnackBar(content: Text('Este link não é válido.')));
    return;
  }

  final abrir = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: const Text('Abrir link externo?'),
      content: Text('Você vai sair do app para abrir:\n${uri.host}'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(contexto, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(contexto, true),
          child: const Text('Abrir'),
        ),
      ],
    ),
  );
  if (abrir != true) return;

  var abriu = false;
  try {
    abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (erro) {
    debugPrint('Erro ao abrir o link: $erro');
  }
  if (!abriu) {
    mensageiro.showSnackBar(const SnackBar(content: Text('Não foi possível abrir o link.')));
  }
}
