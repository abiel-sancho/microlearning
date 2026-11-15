import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:testeapp/cores_disciplina.dart';

/// Visual do app (Material 3): roxo vivo com detalhes em amarelo.
///
/// Cores e estilos ficam todos aqui para as telas seguirem o mesmo padrão e o
/// visual poder ser ajustado em um só lugar. As telas só precisam de
/// [AppTema.cartao], [AppTema.markdown] e das cores de acerto; o resto vem do
/// [ThemeData] aplicado no MaterialApp.
///
/// As telas de tópicos e de resumo usam [AppTema.daDisciplina], que troca o
/// roxo pela cor da disciplina (veja cores_disciplina.dart).
class AppTema {
  AppTema._();

  static final ValueNotifier<ThemeMode> modo = ValueNotifier(ThemeMode.system);

  /// Verde usado para indicar resposta correta.
  static const Color acerto = Color(0xFF15803D);
  static const Color acertoSuave = Color(0xFFD8F5E3);

  static const ColorScheme _cores = ColorScheme(
    brightness: Brightness.light,
    // Roxo vivo: barras do topo, botões e destaques.
    primary: Color.fromARGB(255, 78, 24, 166),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFEDE4FF),
    onPrimaryContainer: Color(0xFF2A0A6B),
    // Amarelo: detalhes (botão flutuante, selos e avisos). Texto sobre ele é
    // sempre escuro, porque branco não tem contraste no amarelo.
    secondary: Color(0xFFFFC107),
    onSecondary: Color(0xFF2B2100),
    secondaryContainer: Color(0xFFFFF1BF),
    onSecondaryContainer: Color(0xFF3D2E00),
    // Roxo escuro: títulos, ícones e textos de destaque sobre fundo claro.
    tertiary: Color(0xFF5B21B6),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE4D7FF),
    onTertiaryContainer: Color(0xFF2A0A6B),
    error: Color(0xFFD32F2F),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDADA),
    onErrorContainer: Color(0xFF5C0A0A),
    // Fundos e superfícies: branco com um toque de lavanda.
    surface: Color(0xFFFBF8FF),
    onSurface: Color(0xFF1E1633),
    onSurfaceVariant: Color(0xFF4F4566),
    surfaceDim: Color(0xFFE3D9F5),
    surfaceBright: Color(0xFFFFFFFF),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF8F3FF),
    surfaceContainer: Color(0xFFF3ECFF),
    surfaceContainerHigh: Color(0xFFEDE4FF),
    surfaceContainerHighest: Color(0xFFE6DAFF),
    outline: Color(0xFF7B6F96),
    outlineVariant: Color(0xFFDCD0F5),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2B1B4D),
    onInverseSurface: Color(0xFFF5EEFF),
    inversePrimary: Color(0xFFFFD54F),
    surfaceTint: Color(0xFF6D28D9),
  );

    static const ColorScheme _coresEscuras = ColorScheme(
    brightness: Brightness.dark,
    primary: Color.fromARGB(255, 107, 25, 184),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF3B1C86),
    onPrimaryContainer: Color(0xFFEDE4FF),
    secondary: Color(0xFFFFC107),            // o amarelo continua igual
    onSecondary: Color(0xFF2B2100),
    secondaryContainer: Color(0xFF4D3B00),
    onSecondaryContainer: Color(0xFFFFE9A6),
    tertiary: Color(0xFFCDB8FF),             // texto de destaque: títulos, ícones
    onTertiary: Color(0xFF2A0A6B),
    tertiaryContainer: Color(0xFF3B1C86),
    onTertiaryContainer: Color(0xFFEDE4FF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF5C1A1A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF14101F),
    onSurface: Color(0xFFEDE7FA),
    onSurfaceVariant: Color(0xFFBDB2D6),
    surfaceDim: Color(0xFF14101F),
    surfaceBright: Color(0xFF2F2745),
    surfaceContainerLowest: Color(0xFF0F0B18),
    surfaceContainerLow: Color(0xFF1A1527),
    surfaceContainer: Color(0xFF1F1930),
    surfaceContainerHigh: Color(0xFF2A2340),
    surfaceContainerHighest: Color(0xFF342C4D),
    outline: Color(0xFF8F84AB),
    outlineVariant: Color(0xFF3F3560),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFEDE7FA),
    onInverseSurface: Color(0xFF1E1633),
    inversePrimary: Color(0xFF6D28D9),
    surfaceTint: Color(0xFFA78BFA),
  );

  static ThemeData get escuro => _construir(_coresEscuras);

  /// Tema padrão de todo o app.
  static ThemeData get claro => _construir(_cores);

  /// Mesmo visual do app, mas com a cor da disciplina no lugar do roxo: barra
  /// do topo, botões, títulos do resumo e cartões. Envolva a tela com
  /// `Theme(data: AppTema.daDisciplina(cor), child: ...)`.

    static ThemeData daDisciplina(CorDisciplina cor, {bool escuro = false}) {
    final base = escuro ? _coresEscuras : _cores;
    final fundo = escuro
        ? Color.lerp(const Color(0xFF14101F), cor.principal, 0.10)!
        : Color.lerp(cor.suave, Colors.white, 0.65)!;
    return _construir(
      base.copyWith(
        primary: cor.principal,
        onPrimary: cor.sobrePrincipal,
        primaryContainer:
            escuro ? Color.lerp(fundo, cor.principal, 0.25)! : cor.suave,
        onPrimaryContainer: escuro ? cor.suave : cor.escuro,
        tertiary: escuro ? cor.suave : cor.escuro,
        onTertiary: escuro ? cor.escuro : Colors.white,
        surface: fundo,
        outlineVariant:
            Color.lerp(escuro ? fundo : cor.suave, cor.principal, 0.35)!,
        surfaceTint: cor.principal,
      ),
    );
  }

  static ThemeData _construir(ColorScheme cores) {
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

    // Ícones da barra de status claros sobre barras escuras e vice-versa
    // (o amarelo, por exemplo, pede ícones escuros).
    final barraEscura =
        ThemeData.estimateBrightnessForColor(cores.primary) == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: cores,
      scaffoldBackgroundColor: cores.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: cores.primary,
        foregroundColor: cores.onPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        systemOverlayStyle:
            barraEscura ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: cores.onPrimary,
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
          foregroundColor: cores.tertiary,
          side: BorderSide(color: cores.tertiary),
          minimumSize: const Size(0, 48),
          shape: formaBotao,
          textStyle: textoBotao,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cores.tertiary,
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
        focusedBorder: borda(cores.tertiary, largura: 1.5),
        errorBorder: borda(cores.error),
        focusedErrorBorder: borda(cores.error, largura: 1.5),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: cores.tertiary,
        selectionColor: cores.primary.withValues(alpha: 0.25),
        selectionHandleColor: cores.tertiary,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: cores.tertiary,
        textColor: cores.onSurface,
        
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: cores.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cores.surfaceContainerLowest,
        selectedItemColor: cores.tertiary,
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
        color: cores.tertiary,
        linearTrackColor: cores.primaryContainer,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((estados) {
          if (estados.contains(WidgetState.disabled)) {
            return cores.onSurface.withValues(alpha: 0.38);
          }
          if (estados.contains(WidgetState.selected)) return cores.tertiary;
          return cores.outline;
        }),
      ),
      dividerTheme: DividerThemeData(color: cores.outlineVariant),
    );
  }

  /// Decoração padrão dos cartões de lista (disciplinas, tópicos e resumos) e
  /// da caixa do editor de texto: fundo claro, cantos arredondados e borda fina.
  /// [borda] troca a cor da borda (por padrão, um tom suave do tema).
  static BoxDecoration cartao(
    BuildContext context, {
    Color? cor,
    Color? borda,
    bool sombra = true,
    
  }) {
    final cores = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: cor ?? cores.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: borda ?? cores.outlineVariant),
      boxShadow: sombra
          ? [
              BoxShadow(
                color: cores.shadow.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );
  }

  /// Estilo do texto em Markdown: títulos na cor de destaque do tema (o roxo
  /// escuro, ou o tom escuro da disciplina quando dentro de [daDisciplina]).
  static MarkdownStyleSheet markdown(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    return MarkdownStyleSheet.fromTheme(tema).copyWith(
      h1: tema.textTheme.headlineSmall?.copyWith(
        color: cores.tertiary,
        fontWeight: FontWeight.w700,
      ),
      h2: tema.textTheme.titleLarge?.copyWith(
        color: cores.tertiary,
        fontWeight: FontWeight.w700,
      ),
      h3: tema.textTheme.titleMedium?.copyWith(
        color: cores.tertiary,
        fontWeight: FontWeight.w600,
      ),
      blockquoteDecoration: BoxDecoration(
        color: cores.primaryContainer.withValues(alpha: 0.6),
        border: Border(left: BorderSide(color: cores.primary, width: 4)),
      ),
      codeblockDecoration: BoxDecoration(
        color: cores.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
