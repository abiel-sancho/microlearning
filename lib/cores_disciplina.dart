import 'package:flutter/material.dart';

/// Uma das 8 cores usadas nas telas de disciplinas, tópicos e resumos.
///
/// Cada disciplina tem sempre a mesma cor (veja [corDaDisciplina]), então o
/// cartão na tela de disciplinas, a lista de tópicos e o resumo combinam.
class CorDisciplina {
  const CorDisciplina({
    required this.nome,
    required this.principal,
    required this.sobrePrincipal,
    required this.suave,
    required this.escuro,
  });

  final String nome;

  /// Cor viva: cartão da disciplina, barra do topo e botões.
  final Color principal;

  /// Cor de texto e ícones sobre [principal] (branco ou quase preto, o que
  /// tiver melhor contraste).
  final Color sobrePrincipal;

  /// Tom bem claro da mesma cor: fundo dos cartões de tópico e citações.
  final Color suave;

  /// Tom escuro da mesma cor, para títulos e textos sobre fundo claro.
  final Color escuro;
}

/// As 8 cores, na ordem em que são usadas. Todas as combinações de texto e
/// fundo têm contraste de pelo menos 4,5:1.
const List<CorDisciplina> coresDisciplina = [
  CorDisciplina(
    nome: 'azul',
    principal: Color.fromARGB(255, 29, 80, 189),
    sobrePrincipal: Color(0xFFFFFFFF),
    suave: Color(0xFFDBE7FF),
    escuro: Color(0xFF1E3A8A),
  ),
  CorDisciplina(
    nome: 'ciano',
    principal: Color.fromARGB(255, 9, 162, 189),
    sobrePrincipal: Color(0xFFFFFFFF),
    suave: Color(0xFFD2F4FA),
    escuro: Color(0xFF0E5A6B),
  ),
  CorDisciplina(
    nome: 'amarelo',
    principal: Color(0xFFFFC107),
    sobrePrincipal: Color(0xFFFFFFFF),
    suave: Color(0xFFFFF1BF),
    escuro: Color(0xFF7A5800),
  ),
  CorDisciplina(
    nome: 'verde',
    principal: Color.fromARGB(255, 25, 165, 77),
    sobrePrincipal: Color(0xFFFFFFFF),
    suave: Color(0xFFD8F5E1),
    escuro: Color(0xFF14532D),
  ),
  CorDisciplina(
    nome: 'rosa',
    principal: Color(0xFFDB2777),
    sobrePrincipal: Color(0xFFFFFFFF),
    suave: Color(0xFFFFD9EA),
    escuro: Color(0xFF831843),
  ),
  CorDisciplina(
    nome: 'vermelho',
    principal: Color.fromARGB(255, 199, 21, 21),
    sobrePrincipal: Color(0xFFFFFFFF),
    suave: Color(0xFFFFD9D9),
    escuro: Color(0xFF7F1D1D),
  ),
  CorDisciplina(
    nome: 'laranja',
    principal: Color.fromARGB(255, 207, 93, 11),
    sobrePrincipal: Color(0xFFFFFFFF),
    suave: Color(0xFFFFE3CC),
    escuro: Color(0xFF8A3A00),
  ),
  CorDisciplina(
    nome: 'cinza',
    principal: Color(0xFF64748B),
    sobrePrincipal: Color(0xFFFFFFFF),
    suave: Color(0xFFE2E8F0),
    escuro: Color(0xFF334155),
  ),
];

/// Escolhe a cor da disciplina a partir do id dela. Usar o id (e não a posição
/// na lista) mantém a cor da disciplina fixa, mesmo que a ordem da lista mude
/// ou que novas disciplinas sejam criadas. Disciplinas com ids seguidos ficam
/// com cores diferentes; a partir da nona, as cores se repetem.
CorDisciplina corDaDisciplina(Object? id) {
  final texto = (id ?? '').toString();
  final numero = int.tryParse(texto) ??
      texto.codeUnits.fold<int>(0, (soma, c) => soma + c); // ids não numéricos
  return coresDisciplina[(numero - 1) % coresDisciplina.length];
}