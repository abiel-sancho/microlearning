import 'package:flutter_quill/flutter_quill.dart';

class Conversao {
  static String deltaToMarkdown(List<dynamic> delta) {
    StringBuffer markdown = StringBuffer();

    for (int i = 0; i < delta.length; i++) {
      var op = delta[i];
      if (op is! Map || !op.containsKey('insert')) continue;

      String text = op['insert'];
      Map<String, dynamic>? attrs = op['attributes'];

      // Lógica para Atributos de Linha (Headers e Listas)
      if (text == '\n' && attrs != null) {
        String currentContent = markdown.toString();
        List<String> lines = currentContent.split('\n');
        String lastLine = lines.isNotEmpty ? lines.removeLast() : "";

        if (attrs.containsKey('header')) {
          int level = attrs['header'];
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

      // Lógica para Atributos de Texto (Bold, Italic)
      if (attrs != null && text.trim().isNotEmpty) {
        if (attrs['bold'] == true) text = "**$text**";
        if (attrs['italic'] == true) text = "*$text*";
      }

      markdown.write(text);
    }
    return markdown.toString();
  }

  /// Converte Markdown de volta para Delta (Document)
  static Document markdownToDeltaDoc(String markdown) {
    if (markdown.trim().isEmpty) {
      return Document()..insert(0, '\n');
    }

    List<Map<String, dynamic>> deltaJson = [];
    List<String> lines = markdown.split('\n');

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      
      // Remove quebras de linhas vazias no final se não houver texto
      if (line.isEmpty) {
        deltaJson.add({"insert": "\n"});
        continue;
      }

      Map<String, dynamic>? lineAttributes;
      String cleanLine = line;

      // Verifica formatações de linha básicas que geramos antes
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

      // Adiciona o texto puro
      deltaJson.add({"insert": cleanLine});
      
      // O Quill precisa que os atributos de linha fiquem no '\n' após o texto
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