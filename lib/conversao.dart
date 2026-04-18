//import 'package:flutter/material.dart';

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
          lastLine = "${"${'#' * level} "} $lastLine";
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

      // Lógica para Atributos de Texto (Bold, Italic, Strike)
      if (attrs != null && text.trim().isNotEmpty) {
        if (attrs['bold'] == true) text = "**$text**";
        if (attrs['italic'] == true) text = "*$text*";

      }

      markdown.write(text);
    }
    return markdown.toString();
  }

  /// Converte Markdown de volta para Delta (Simples)
  /// Nota: Para uma conversão perfeita, o ideal é usar a ponte HTML 
  /// mencionada antes, mas para textos simples, esta lógica ajuda.
  static String markdownToDelta(String markdown) {
    // Lógica reversa aqui ou integração com pacote markdown
    return ""; 
  }
}