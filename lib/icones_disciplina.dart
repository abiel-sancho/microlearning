import 'package:flutter/material.dart';

/// Palavras que aparecem no nome (ou na coluna "icone") da disciplina,
/// já sem acento e em minúsculas, e o ícone de cada uma.
const Map<String, IconData> _icones = {
  'matematica': Icons.calculate,
  'fisica': Icons.bolt,
  'quimica': Icons.science,
  'biologia': Icons.biotech,
  'historia': Icons.account_balance,
  'geografia': Icons.public,
  'portugues': Icons.menu_book,
  'ingl': Icons.translate,
};

String _semAcento(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  var saida = texto.toLowerCase().trim();
  for (var i = 0; i < de.length; i++) {
    saida = saida.replaceAll(de[i], para[i]);
  }
  return saida;
}

IconData iconeDaDisciplina(Map<String, dynamic> disciplina) {
  final chave = _semAcento((disciplina['icone'] ?? disciplina['nome'] ?? '').toString());
  for (final entrada in _icones.entries) {
    if (chave.contains(entrada.key)) return entrada.value;
  }
  return Icons.school; // disciplina sem ícone definido
}