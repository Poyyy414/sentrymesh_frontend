import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const navy = Color(0xFF0B4778);
  static const deepNavy = Color(0xFF082A45);
  static const signalBlue = Color(0xFF176FC9);
  static const safeGreen = Color(0xFF16A36A);
  static const warningAmber = Color(0xFFE79A21);
  static const dangerRed = Color(0xFFD93A42);
  static const violet = Color(0xFF7256C8);
  static const surface = Color(0xFFF6F8FB);
  static const surfaceRaised = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);
  static const textPrimary = Color(0xFF111827);
  static const textMuted = Color(0xFF64748B);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      primary: navy,
      secondary: signalBlue,
      tertiary: safeGreen,
      error: dangerRed,
      surface: surface,
    );

    final base = ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      useMaterial3: true,
      fontFamily: 'Roboto',
      fontFamilyFallback: const ['Arial', 'sans-serif'],
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceRaised,
        elevation: 1,
        shadowColor: const Color(0x1A0F172A),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: signalBlue,
        selectionColor: signalBlue.withValues(alpha: 0.22),
        selectionHandleColor: signalBlue,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        prefixIconColor: WidgetStateColor.resolveWith((states) {
          return states.contains(WidgetState.focused) ? signalBlue : textMuted;
        }),
        suffixIconColor: textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: signalBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dangerRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dangerRed, width: 1.5),
        ),
        labelStyle: const TextStyle(
          color: textMuted,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        floatingLabelStyle: const TextStyle(
          color: signalBlue,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        hintStyle: const TextStyle(color: textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFBAC7D5),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: borderStrong),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: signalBlue,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: deepNavy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceRaised,
        elevation: 0,
        height: 70,
        indicatorColor: signalBlue.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? signalBlue : textMuted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 0,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? signalBlue : textMuted,
            size: selected ? 24 : 23,
          );
        }),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: textMuted,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        subtitleTextStyle: TextStyle(
          color: textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 25,
          height: 1.12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          height: 1.25,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        titleSmall: TextStyle(
          color: textPrimary,
          fontSize: 14,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        bodyMedium: TextStyle(
          color: textPrimary,
          fontSize: 14,
          height: 1.42,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        bodySmall: TextStyle(
          color: textMuted,
          fontSize: 12,
          height: 1.38,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        labelMedium: TextStyle(
          color: textMuted,
          fontSize: 12,
          height: 1.25,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        labelSmall: TextStyle(
          color: textMuted,
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
