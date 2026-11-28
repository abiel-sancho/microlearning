import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Visual do app (Material 3): violeta vivo (esquema de referência do
/// Material 3, etapa 39). Antes: roxo e azul suaves, puxados para o cinza.
///
/// Cores e estilos ficam todos aqui para as telas seguirem o mesmo padrão e o
/// visual poder ser ajustado em um só lugar. As telas só precisam de
/// [AppTema.cartao], [AppTema.markdown] e das cores de acerto/erro; o resto
/// vem do [ThemeData] aplicado no MaterialApp.
class AppTema {
  AppTema._();

  /// Verde acinzentado usado para indicar resposta correta.
  static const Color acerto = Color(0xFF4F7D68);
  static const Color acertoSuave = Color(0xFFDDEBE3);

  /// Esquema claro de referência do Material 3 (semente violeta #6750A4,
  /// etapa 39), no lugar do roxo acinzentado anterior (#6E659B). São os
  /// valores oficiais do Material 3, com contraste validado em cada par
  /// fundo/texto. O vermelho de erro continua o do app.
  static const ColorScheme _cores = ColorScheme(
    brightness: Brightness.light,
    // Violeta vivo: botões, destaques e títulos.
    primary: Color(0xFF6750A4),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFEADDFF),
    onPrimaryContainer: Color(0xFF21005D),
    // Lilás acinzentado: apoio (cartões de questão, títulos menores).
    secondary: Color(0xFF625B71),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE8DEF8),
    onSecondaryContainer: Color(0xFF1D192B),
    // Rosado: terceira cor do Material 3.
    tertiary: Color(0xFF7D5260),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFD8E4),
    onTertiaryContainer: Color(0xFF31111D),
    // Vermelho queimado e suave, para erros (igual a antes).
    error: Color(0xFFA4515F),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF3DDE1),
    onErrorContainer: Color(0xFF4A1D27),
    // Fundos e superfícies: branco levemente tingido de violeta.
    surface: Color(0xFFFEF7FF),
    onSurface: Color(0xFF1D1B20),
    onSurfaceVariant: Color(0xFF49454F),
    surfaceDim: Color(0xFFDED8E1),
    surfaceBright: Color(0xFFFEF7FF),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF7F2FA),
    surfaceContainer: Color(0xFFF3EDF7),
    surfaceContainerHigh: Color(0xFFECE6F0),
    surfaceContainerHighest: Color(0xFFE6E0E9),
    outline: Color(0xFF79747E),
    outlineVariant: Color(0xFFCAC4D0),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF322F35),
    onInverseSurface: Color(0xFFF5EFF7),
    inversePrimary: Color(0xFFD0BCFF),
    surfaceTint: Color(0xFF6750A4),
  );

  static ThemeData get claro {
    const cores = _cores;
    final formaBotao = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    const textoBotao = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);

    OutlineInputBorder borda(Color cor, {double largura = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cor, width: largura),
      );
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: cores,
      scaffoldBackgroundColor: cores.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: cores.primaryContainer,
        foregroundColor: cores.onPrimaryContainer,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: cores.onPrimaryContainer,
        ),
      ),
      cardTheme: CardThemeData(
        color: cores.surfaceContainerLowest,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cores.outlineVariant),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cores.primary,
          foregroundColor: cores.onPrimary,
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: formaBotao,
          textStyle: textoBotao,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cores.primary,
          foregroundColor: cores.onPrimary,
          minimumSize: const Size(0, 48),
          shape: formaBotao,
          textStyle: textoBotao,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cores.primary,
          side: BorderSide(color: cores.outline),
          minimumSize: const Size(0, 48),
          shape: formaBotao,
          textStyle: textoBotao,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cores.primary,
          shape: formaBotao,
        ),
      ),
      // Botão flutuante (salvar) no violeta principal: com o lilás
      // acinzentado do "secondary" ele ficava apagado.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cores.primary,
        foregroundColor: cores.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cores.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(color: cores.onSurfaceVariant),
        border: borda(cores.outlineVariant),
        enabledBorder: borda(cores.outlineVariant),
        focusedBorder: borda(cores.primary, largura: 1.5),
        errorBorder: borda(cores.error),
        focusedErrorBorder: borda(cores.error, largura: 1.5),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: cores.primary,
        selectionColor: cores.primary.withValues(alpha: 0.25),
        selectionHandleColor: cores.primary,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: cores.primary,
        textColor: cores.onSurface,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: cores.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cores.surfaceContainerLowest,
        selectedItemColor: cores.primary,
        unselectedItemColor: cores.onSurfaceVariant,
        elevation: 8,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cores.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: cores.onSurface,
        ),
        contentTextStyle: TextStyle(fontSize: 14, color: cores.onSurfaceVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cores.inverseSurface,
        contentTextStyle: TextStyle(color: cores.onInverseSurface),
        actionTextColor: cores.inversePrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: cores.primary,
        textColor: cores.onPrimary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cores.primary,
        linearTrackColor: cores.primaryContainer,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((estados) {
          if (estados.contains(WidgetState.disabled)) {
            return cores.onSurface.withValues(alpha: 0.38);
          }
          if (estados.contains(WidgetState.selected)) return cores.primary;
          return cores.outline;
        }),
      ),
      dividerTheme: DividerThemeData(color: cores.outlineVariant),
    );
  }

  /// Decoração padrão dos cartões de lista (disciplinas, tópicos e resumos) e
  /// da caixa do editor de texto: fundo claro, cantos arredondados e borda fina.
  static BoxDecoration cartao(
    BuildContext context, {
    Color? cor,
    bool sombra = true,
  }) {
    final cores = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: cor ?? cores.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: cores.outlineVariant),
      boxShadow: sombra
          ? [
              BoxShadow(
                color: cores.shadow.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );
  }

  /// Estilo do texto em Markdown
  static MarkdownStyleSheet markdown(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    return MarkdownStyleSheet.fromTheme(tema).copyWith(
      h1: tema.textTheme.headlineSmall?.copyWith(
        color: cores.primary,
        fontWeight: FontWeight.w600,
      ),
      h2: tema.textTheme.titleLarge?.copyWith(
        color: cores.primary,
        fontWeight: FontWeight.w600,
      ),
      h3: tema.textTheme.titleMedium?.copyWith(
        color: cores.secondary,
        fontWeight: FontWeight.w600,
      ),
      blockquoteDecoration: BoxDecoration(
        color: cores.primaryContainer.withValues(alpha: 0.5),
        border: Border(left: BorderSide(color: cores.primary, width: 4)),
      ),
      codeblockDecoration: BoxDecoration(
        color: cores.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
