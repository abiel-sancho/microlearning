import 'package:flutter/material.dart';

/// Cor de cada disciplina pela SIGLA (etapa 35), por área do ENEM:
/// Matemática em azul; Natureza em verdes; Humanas em tons quentes;
/// Linguagens em violetas, rosas e azuis.
///
/// A cor é só a "semente": o Material 3 gera dela o esquema inteiro
/// (`ColorScheme.fromSeed`), com cada par fundo/texto (`primaryContainer` /
/// `onPrimaryContainer` etc.) calculado para ter contraste. Por isso texto e
/// ícones nunca ficam direto sobre a cor pura.
const Map<String, Color> _sementePorSigla = {
  // Matemática
  'MAT': Color(0xFF1565C0), // azul
  // Ciências da Natureza
  'FIS': Color(0xFF2E7D32), // verde
  'QUI': Color(0xFF00897B), // turquesa
  'BIO': Color(0xFF689F38), // verde-oliva
  // Ciências Humanas
  'HIS': Color(0xFFA0522D), // terracota
  'GEO': Color(0xFFB8860B), // ocre
  'FIL': Color(0xFF8E2C48), // vinho
  'SOC': Color(0xFF8D6E63), // taupe
  // Linguagens
  'POR': Color(0xFF3949AB), // índigo
  'LIT': Color(0xFF7B1FA2), // violeta
  'RED': Color(0xFF455A64), // azul-grafite
  'ING': Color(0xFF0288D1), // azul-céu
  'ESP': Color(0xFFC62828), // vermelho
  'ART': Color(0xFFC2185B), // fúcsia
  'EDF': Color(0xFFEF6C00), // laranja
};

/// Esquemas já calculados (são 15, e o cálculo não precisa se repetir).
final Map<String, ColorScheme> _esquemas = {};

String _sigla(Object? sigla) => (sigla ?? '').toString().toUpperCase().trim();

/// Esquema de cores da disciplina; nulo para sigla desconhecida (a tela usa
/// o tema do app).
///
/// Variante `fidelity`: a cor principal fica fiel à semente (o azul é azul de
/// verdade). Com a variante padrão, que só guarda o matiz, terracota e taupe,
/// ou azul-grafite e azul-céu, ficariam quase iguais.
ColorScheme? esquemaDaDisciplina(Object? sigla) {
  final chave = _sigla(sigla);
  final semente = _sementePorSigla[chave];
  if (semente == null) return null;
  return _esquemas.putIfAbsent(
    chave,
    () => ColorScheme.fromSeed(
      seedColor: semente,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ),
  );
}

/// Tema do app com as cores da disciplina, para as telas dela (Tópicos).
///
/// O `AppTema.claro` fixa a cor de vários componentes (barra do topo, botões,
/// listas, menu); aqui cada um recebe a cor equivalente do esquema da
/// disciplina, sempre em pares que o Material 3 calcula com contraste.
ThemeData temaDaDisciplina(ThemeData base, Object? sigla) {
  final c = esquemaDaDisciplina(sigla);
  if (c == null) return base;

  // Mantém a aparência de "desligado" dos botões padrão do Flutter.
  WidgetStateProperty<Color?> quandoAtivo(Color cor) =>
      WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.disabled) ? null : cor);

  return base.copyWith(
    colorScheme: c,
    scaffoldBackgroundColor: c.surface,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: c.primaryContainer,
      foregroundColor: c.onPrimaryContainer,
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(color: c.onPrimaryContainer),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: base.elevatedButtonTheme.style?.copyWith(
        backgroundColor: quandoAtivo(c.primary),
        foregroundColor: quandoAtivo(c.onPrimary),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(
        backgroundColor: quandoAtivo(c.primary),
        foregroundColor: quandoAtivo(c.onPrimary),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.copyWith(foregroundColor: quandoAtivo(c.primary)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: base.textButtonTheme.style?.copyWith(foregroundColor: quandoAtivo(c.primary)),
    ),
    listTileTheme: base.listTileTheme.copyWith(iconColor: c.primary, textColor: c.onSurface),
    progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
      color: c.primary,
      linearTrackColor: c.primaryContainer,
    ),
    drawerTheme: base.drawerTheme.copyWith(backgroundColor: c.surface),
    dialogTheme: base.dialogTheme.copyWith(backgroundColor: c.surfaceContainerLowest),
    textSelectionTheme: base.textSelectionTheme.copyWith(
      cursorColor: c.primary,
      selectionColor: c.primary.withValues(alpha: 0.25),
      selectionHandleColor: c.primary,
    ),
  );
}
