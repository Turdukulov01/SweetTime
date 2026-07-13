import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Дизайн-токены SweetTime из docs/design/DESIGN_SYSTEM.md (эталон — веб-прототип sweettimetwo).
abstract final class AppColors {
  // candy — акцент
  static const candy50 = Color(0xFFFFF1F7);
  static const candy100 = Color(0xFFFFE3EF);
  static const candy300 = Color(0xFFFF9EC6);
  static const candy500 = Color(0xFFFF5C9A);
  static const candy700 = Color(0xFFC91F63);

  // mint — успех/вторичный
  static const mint50 = Color(0xFFEFFDF6);
  static const mint100 = Color(0xFFD8F8EA);
  static const mint300 = Color(0xFF8FE5C7);
  static const mint500 = Color(0xFF34C99A);

  // coffee — текст
  static const coffee500 = Color(0xFF7B4B35);
  static const coffee700 = Color(0xFF4B2D22);
  static const coffee900 = Color(0xFF251713);

  // cream — фоны
  static const cream50 = Color(0xFFFFFAF0);
  static const cream100 = Color(0xFFFFF1D8);
  static const cream200 = Color(0xFFFFE2AD);

  // тёмная тема
  static const darkBackground = Color(0xFF161215);
  static const darkSurface = Color(0xFF231D21);
  static const darkForeground = Color(0xFFFFF7EE);
}

class AppTheme {
  static final Map<Color, ThemeData> _lightThemes = <Color, ThemeData>{};
  static final Map<Color, ThemeData> _darkThemes = <Color, ThemeData>{};

  /// Светлая пастельная подложка акцента (аналог candy50 для candy500).
  static Color _accentContainerLight(Color accent) =>
      Color.alphaBlend(accent.withValues(alpha: 0.08), Colors.white);

  /// Тёмный вариант акцента для текста на светлой подложке (аналог candy700).
  static Color _accentDark(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    return hsl.withLightness((hsl.lightness * 0.55).clamp(0.0, 1.0)).toColor();
  }

  /// Светлый вариант акцента для тёмной темы (аналог candy100).
  static Color _accentLight(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    return hsl.withLightness(0.92).toColor();
  }

  /// Светлая тема; [accent] — акцент бренда из API (candy500 по умолчанию).
  static ThemeData light([Color accent = AppColors.candy500]) =>
      _lightThemes.putIfAbsent(accent, () => _buildLight(accent));

  static ThemeData _buildLight(Color accent) {
    final colors = ColorScheme(
      brightness: Brightness.light,
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: _accentContainerLight(accent),
      onPrimaryContainer: _accentDark(accent),
      secondary: AppColors.mint500,
      onSecondary: AppColors.coffee900,
      secondaryContainer: AppColors.mint100,
      onSecondaryContainer: AppColors.coffee900,
      tertiary: AppColors.coffee500,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.cream100,
      onTertiaryContainer: AppColors.coffee700,
      error: const Color(0xFFBA1A1A),
      onError: Colors.white,
      surface: AppColors.cream50,
      onSurface: AppColors.coffee900,
      onSurfaceVariant: AppColors.coffee500,
      outline: const Color(0xFFE5D7C6),
      outlineVariant: const Color(0xFFF0E6D8),
      surfaceContainerHighest: Colors.white,
      surfaceContainerHigh: const Color(0xFFFFFDF8),
      inverseSurface: AppColors.coffee900,
      onInverseSurface: AppColors.cream50,
      shadow: const Color(0x1F7B4B35),
      scrim: Colors.black54,
    );
    return _buildTheme(colors);
  }

  /// Тёмная тема; [accent] — акцент бренда из API (candy500 по умолчанию).
  static ThemeData dark([Color accent = AppColors.candy500]) =>
      _darkThemes.putIfAbsent(accent, () => _buildDark(accent));

  static ThemeData _buildDark(Color accent) {
    final colors = ColorScheme(
      brightness: Brightness.dark,
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: accent.withValues(alpha: 0.2),
      onPrimaryContainer: _accentLight(accent),
      secondary: AppColors.mint300,
      onSecondary: AppColors.coffee900,
      secondaryContainer: const Color(0x3334C99A),
      onSecondaryContainer: AppColors.mint100,
      tertiary: AppColors.cream100,
      onTertiary: AppColors.coffee900,
      tertiaryContainer: const Color(0x33FFE2AD),
      onTertiaryContainer: AppColors.cream100,
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      surface: AppColors.darkBackground,
      onSurface: AppColors.darkForeground,
      onSurfaceVariant: const Color(0xFFE7CABC),
      outline: const Color(0xFF4A4046),
      outlineVariant: const Color(0xFF352E33),
      surfaceContainerHighest: AppColors.darkSurface,
      surfaceContainerHigh: const Color(0xFF1D181C),
      inverseSurface: AppColors.cream50,
      onInverseSurface: AppColors.coffee900,
      shadow: Colors.black45,
      scrim: Colors.black54,
    );
    return _buildTheme(colors);
  }

  static ThemeData _buildTheme(ColorScheme colors) {
    final textTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: colors.brightness).textTheme,
    ).apply(bodyColor: colors.onSurface, displayColor: colors.onSurface);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainerHighest,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          backgroundColor: colors.secondaryContainer,
          foregroundColor: colors.onSecondaryContainer,
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          shape: const StadiumBorder(),
          side: BorderSide(color: colors.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: const StadiumBorder(),
          foregroundColor: colors.onPrimaryContainer,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: colors.outlineVariant),
        backgroundColor: colors.surfaceContainerHighest,
        selectedColor: colors.primaryContainer,
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: colors.outlineVariant),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: colors.onSurface),
      ),
    );
  }
}
