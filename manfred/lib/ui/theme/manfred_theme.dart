import 'package:flutter/material.dart';

final class ManfredTheme {
  const ManfredTheme._();

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: ManfredColors.accentBlue,
      secondary: ManfredColors.accentBlueSoft,
      surface: ManfredColors.panelBackground,
      error: Color(0xFFF26D6D),
    );

    final textTheme = Typography.whiteMountainView.copyWith(
      bodyLarge: _textStyle(
        15,
        FontWeight.w500,
        ManfredColors.textPrimary,
        1.5,
      ),
      bodyMedium: _textStyle(
        14,
        FontWeight.w400,
        ManfredColors.textPrimary,
        1.45,
      ),
      bodySmall: _textStyle(
        12,
        FontWeight.w400,
        ManfredColors.textSecondary,
        1.4,
      ),
      titleLarge: _textStyle(
        22,
        FontWeight.w700,
        ManfredColors.textPrimary,
        1.1,
      ),
      titleMedium: _textStyle(
        16,
        FontWeight.w600,
        ManfredColors.textPrimary,
        1.2,
      ),
      titleSmall: _textStyle(
        13,
        FontWeight.w600,
        ManfredColors.textSecondary,
        1.2,
      ),
      labelLarge: _textStyle(
        13,
        FontWeight.w600,
        ManfredColors.textPrimary,
        1.1,
      ),
      labelMedium: _textStyle(
        12,
        FontWeight.w600,
        ManfredColors.textSecondary,
        1.1,
      ),
      labelSmall: _textStyle(11, FontWeight.w500, ManfredColors.textMuted, 1.1),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ManfredColors.appBackground,
      canvasColor: ManfredColors.appBackground,
      splashFactory: NoSplash.splashFactory,
      fontFamily: 'JetBrains Mono',
      textTheme: textTheme,
      dividerColor: ManfredColors.borderSubtle,
      iconTheme: const IconThemeData(
        color: ManfredColors.textSecondary,
        size: 18,
      ),
      cardTheme: const CardThemeData(
        color: ManfredColors.panelAltBackground,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(ManfredShapes.panelRadius),
          ),
          side: BorderSide(color: ManfredColors.borderSubtle),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ManfredColors.panelAltBackground,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: ManfredColors.textMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
          borderSide: const BorderSide(color: ManfredColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
          borderSide: const BorderSide(color: ManfredColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
          borderSide: const BorderSide(color: ManfredColors.accentBlue),
        ),
      ),
    );
  }

  static TextStyle _textStyle(
    double size,
    FontWeight weight,
    Color color,
    double height,
  ) {
    return TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: -0.2,
    );
  }
}

final class ManfredColors {
  const ManfredColors._();

  static const appBackground = Color(0xFF0E0B09);
  static const sessionsBackground = Color(0xFF121214);
  static const panelBackground = sessionsBackground;
  static const panelRaised = Color(0xFF17181B);
  static const panelAltBackground = Color(0xFF1B1D21);
  static const panelOverlay = Color(0xFF24262B);
  static const messageHover = Color(0xFF222327);
  static const borderSubtle = Color(0xFF2B2D33);
  static const borderStrong = Color(0xFF383B43);
  static const textPrimary = Color(0xFFF2F5F8);
  static const textSecondary = Color(0xFFABB8C8);
  static const textMuted = Color(0xFF728094);
  static const accentBlue = Color(0xFF5EA1FF);
  static const accentBlueSoft = Color(0xFF2B3F57);
  static const accentGreen = Color(0xFF76D39B);
  static const accentAmber = Color(0xFFF5C271);
  static const accentRed = Color(0xFFF28A8A);
}

final class ManfredShapes {
  const ManfredShapes._();

  static const panelRadius = 14.0;
  static const tileRadius = 8.0;
  static const buttonRadius = 6.0;
  static const inputRadius = 8.0;
}
