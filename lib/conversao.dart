import 'package:flutter_quill/flutter_quill.dart';

class Conversao {
  static String deltaToMarkdown(List<dynamic> delta) {
    StringBuffer markdown = StringBuffer();

    for (int i = 0; i < delta.length; i++) {
      final op = delta[i];
      if (op is! Map || !op.containsKey('insert')) continue;

      final insert = op['insert'];
      final attrs = (op['attributes'] as Map?)?.cast<String, dynamic>();

      // Embed (imagem): o insert é um Map
      if (insert is Map) {
        final image = insert['image'];
        if (image is String) markdown.write('![]($image)');
        continue;
      }
      if (insert is! String) continue;

      String text = insert;

      // Atributos de linha (headers e listas)
      if (text == '\n' && attrs != null) {
        final lines = markdown.toString().split('\n');
        String lastLine = lines.isNotEmpty ? lines.removeLast() : "";

        if (attrs.containsKey('header')) {
          final level = attrs['header'] as int;
          lastLine = "${'#' * level} $lastLine";
        } else if (attrs['list'] == 'ordered') {
          lastLine = "1. $lastLine";
        } else if (attrs['list'] == 'bullet') {
          lastLine = "- $lastLine";
        }

        markdown = StringBuffer(lines.join('\n'));
        if (lines.isNotEmpty) markdown.write('\n');
        markdown.write('$lastLine\n');
        continue;
      }

      // Atributos de texto (negrito, itálico)
      if (attrs != null && text.trim().isNotEmpty) {
        if (attrs['bold'] == true) text = "**$text**";
        if (attrs['italic'] == true) text = "*$text*";
      }

      markdown.write(text);
    }
    return markdown.toString();
  }

  static Document markdownToDeltaDoc(String markdown) {
    if (markdown.trim().isEmpty) {
      return Document()..insert(0, '\n');
    }

    List<Map<String, dynamic>> deltaJson = [];
    List<String> lines = markdown.split('\n');

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      if (line.isEmpty) {
        deltaJson.add({"insert": "\n"});
        continue;
      }

      // Imagem em linha própria: ![](url)
      final imageMatch = RegExp(r'^!\[.*?\]\((.+?)\)$').firstMatch(line.trim());
      if (imageMatch != null) {
        deltaJson.add({"insert": {"image": imageMatch.group(1)}});
        deltaJson.add({"insert": "\n"});
        continue;
      }

      Map<String, dynamic>? lineAttributes;
      String cleanLine = line;

      if (line.startsWith('# ')) {
        cleanLine = line.substring(2);
        lineAttributes = {"header": 1};
      } else if (line.startsWith('## ')) {
        cleanLine = line.substring(3);
        lineAttributes = {"header": 2};
      } else if (line.startsWith('### ')) {
        cleanLine = line.substring(4);
        lineAttributes = {"header": 3};
      } else if (line.startsWith('- ')) {
        cleanLine = line.substring(2);
        lineAttributes = {"list": "bullet"};
      } else if (line.startsWith('1. ')) {
        cleanLine = line.substring(3);
        lineAttributes = {"list": "ordered"};
      }

      deltaJson.add({"insert": cleanLine});

      if (lineAttributes != null) {
        deltaJson.add({"insert": "\n", "attributes": lineAttributes});
      } else {
        deltaJson.add({"insert": "\n"});
      }
    }

    if (deltaJson.isEmpty) {
      deltaJson.add({"insert": "\n"});
    }

    return Document.fromJson(deltaJson);
  }
}