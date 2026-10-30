import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Visual do app (Material 3): roxo e azul em tons suaves, puxados para o cinza.
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

  static const ColorScheme _cores = ColorScheme(
    brightness: Brightness.light,
    // Roxo acinzentado: botões, destaques e títulos.
    primary: Color(0xFF6E659B),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE6E2F2),
    onPrimaryContainer: Color(0xFF2E2950),
    // Azul acinzentado: ação flutuante, selos e cartões de disciplina.
    secondary: Color(0xFF56738F),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFDDE6F0),
    onSecondaryContainer: Color(0xFF22344A),
    tertiary: Color(0xFF6A74A3),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE3E5F3),
    onTertiaryContainer: Color(0xFF2A2F52),
    // Vermelho queimado e suave, para erros.
    error: Color(0xFFA4515F),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF3DDE1),
    onErrorContainer: Color(0xFF4A1D27),
    // Fundos e superfícies em cinza-lavanda bem claro.
    surface: Color(0xFFF6F5FA),
    onSurface: Color(0xFF2C2B36),
    onSurfaceVariant: Color(0xFF5E5B6E),
    surfaceDim: Color(0xFFDEDCE6),
    surfaceBright: Color(0xFFFAF9FD),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFAF9FD),
    surfaceContainer: Color(0xFFF0EEF6),
    surfaceContainerHigh: Color(0xFFEAE8F2),
    surfaceContainerHighest: Color(0xFFE4E1EE),
    outline: Color(0xFF8B889C),
    outlineVariant: Color(0xFFD3D0DF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF3A3750),
    onInverseSurface: Color(0xFFF1EFF7),
    inversePrimary: Color(0xFFCBC4EC),
    surfaceTint: Color(0xFF6E659B),
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
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cores.secondary,
        foregroundColor: cores.onSecondary,
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
      drawerTheme: const DrawerThemeData(
        backgroundColor: Color(0xFFF6F5FA),
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
        backgroundColor: cores.secondary,
        textColor: cores.onSecondary,
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

  /// Estilo do texto em Markdown dos resumos: títulos em roxo/azul suaves.
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
