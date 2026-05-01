import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Neo-Brutalist Design System
/// Raw, bold, structural — thick borders, hard shadows, monospace type.
class BrutalistTheme {
  // ─── COLORS ──────────────────────────────────────────────
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color concrete = Color(0xFFE8E4E0);
  static const Color darkConcrete = Color(0xFF2A2A2A);
  static const Color accent = Color(0xFFFF5722); // raw orange
  static const Color warning = Color(0xFFFFEB3B); // caution yellow
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFD32F2F);
  static const Color portOpen = Color(0xFF00E676);
  static const Color folderColor = Color(0xFF424242);
  static const Color videoColor = Color(0xFFFF6D00);

  // ─── BORDERS ─────────────────────────────────────────────
  static const double borderWidth = 3.0;
  static const double thickBorderWidth = 4.0;

  static Border get hardBorder => Border.all(color: black, width: borderWidth);
  static Border get thickBorder =>
      Border.all(color: black, width: thickBorderWidth);
  static Border get accentBorder =>
      Border.all(color: accent, width: borderWidth);

  // ─── SHADOWS ─────────────────────────────────────────────
  static List<BoxShadow> get hardShadow => [
        const BoxShadow(
          color: black,
          offset: Offset(4, 4),
          blurRadius: 0,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get smallShadow => [
        const BoxShadow(
          color: black,
          offset: Offset(2, 2),
          blurRadius: 0,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get accentShadow => [
        BoxShadow(
          color: accent.withValues(alpha: 0.7),
          offset: const Offset(4, 4),
          blurRadius: 0,
          spreadRadius: 0,
        ),
      ];

  // ─── TYPOGRAPHY ──────────────────────────────────────────
  static TextStyle get displayLarge => GoogleFonts.spaceMono(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: black,
        letterSpacing: -1.5,
        height: 1.1,
      );

  static TextStyle get displayMedium => GoogleFonts.spaceMono(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: black,
        letterSpacing: -1,
      );

  static TextStyle get headlineLarge => GoogleFonts.spaceMono(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: black,
      );

  static TextStyle get headlineMedium => GoogleFonts.spaceMono(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: black,
      );

  static TextStyle get bodyLarge => GoogleFonts.spaceMono(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: black,
      );

  static TextStyle get bodyMedium => GoogleFonts.spaceMono(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: black,
      );

  static TextStyle get bodySmall => GoogleFonts.spaceMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: darkConcrete,
      );

  static TextStyle get labelLarge => GoogleFonts.spaceMono(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: black,
        letterSpacing: 2,
      );

  static TextStyle get mono => GoogleFonts.spaceMono(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: black,
      );

  // ─── THEME DATA ──────────────────────────────────────────
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: concrete,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: black,
          onPrimary: white,
          secondary: accent,
          onSecondary: white,
          error: error,
          onError: white,
          surface: white,
          onSurface: black,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: black,
          foregroundColor: white,
          elevation: 0,
          titleTextStyle: GoogleFonts.spaceMono(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: white,
            letterSpacing: 2,
          ),
        ),
        textTheme: TextTheme(
          displayLarge: displayLarge,
          displayMedium: displayMedium,
          headlineLarge: headlineLarge,
          headlineMedium: headlineMedium,
          bodyLarge: bodyLarge,
          bodyMedium: bodyMedium,
          bodySmall: bodySmall,
          labelLarge: labelLarge,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: const BorderSide(color: black, width: 3),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: const BorderSide(color: black, width: 3),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: const BorderSide(color: accent, width: 3),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: const BorderSide(color: error, width: 3),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          labelStyle: mono,
          hintStyle: mono.copyWith(color: darkConcrete.withValues(alpha: 0.5)),
        ),
      );

  // ─── DECORATIONS ─────────────────────────────────────────
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: white,
        border: hardBorder,
        boxShadow: hardShadow,
      );

  static BoxDecoration get accentCardDecoration => BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        border: accentBorder,
        boxShadow: accentShadow,
      );

  static BoxDecoration get darkCardDecoration => BoxDecoration(
        color: darkConcrete,
        border: hardBorder,
        boxShadow: hardShadow,
      );
}
