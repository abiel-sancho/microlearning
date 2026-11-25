import 'package:flutter/material.dart';

/// Ícone de cada disciplina pela SIGLA (as 15 do mapa de conteúdos).
/// A sigla é fixa no banco (não muda), então é uma chave mais segura que o nome.
const Map<String, IconData> _iconesPorSigla = {
  'MAT': Icons.calculate, // Matemática
  'FIS': Icons.bolt, // Física
  'QUI': Icons.science, // Química
  'BIO': Icons.biotech, // Biologia
  'HIS': Icons.account_balance, // História
  'GEO': Icons.public, // Geografia
  'FIL': Icons.psychology, // Filosofia
  'SOC': Icons.groups, // Sociologia
  'POR': Icons.menu_book, // Língua Portuguesa
  'LIT': Icons.auto_stories, // Literatura
  'RED': Icons.edit_note, // Redação
  'ING': Icons.translate, // Língua Inglesa
  'ESP': Icons.language, // Língua Espanhola
  'ART': Icons.palette, // Arte
  'EDF': Icons.sports_soccer, // Educação Física
};

/// Reserva: palavras do nome (sem acento, minúsculas), para dados sem sigla.
const Map<String, IconData> _iconesPorNome = {
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
  // 1º: pela sigla (tabela nova `disciplinas`).
  final sigla = (disciplina['sigla'] ?? '').toString().toUpperCase().trim();
  final porSigla = _iconesPorSigla[sigla];
  if (porSigla != null) return porSigla;

  // 2º: pelo nome, como era antes.
  final chave = _semAcento((disciplina['icone'] ?? disciplina['nome'] ?? '').toString());
  for (final entrada in _iconesPorNome.entries) {
    if (chave.contains(entrada.key)) return entrada.value;
  }
  return Icons.school; // disciplina sem ícone definido
}
