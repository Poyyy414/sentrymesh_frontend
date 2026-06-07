import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const navy = Color(0xFF08477F);
  static const deepNavy = Color(0xFF062B4B);
  static const signalBlue = Color(0xFF1268D6);
  static const safeGreen = Color(0xFF14A267);
  static const warningAmber = Color(0xFFE89B22);
  static const dangerRed = Color(0xFFE03A3E);
  static const violet = Color(0xFF7256C8);
  static const surface = Color(0xFFF2F6FA);
  static const surfaceRaised = Color(0xFFFFFFFF);
  static const border = Color(0xFFDDE6F0);
  static const borderStrong = Color(0xFFC6D3E1);
  static const textPrimary = Color(0xFF142235);
  static const textMuted = Color(0xFF607086);

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
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceRaised,
        elevation: 0,
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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        labelStyle: const TextStyle(color: textMuted, fontWeight: FontWeight.w500),
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
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: borderStrong),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceRaised,
        elevation: 0,
        height: 68,
        indicatorColor: signalBlue.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? signalBlue : textMuted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
          fontWeight: FontWeight.w800,
        ),
        subtitleTextStyle: TextStyle(
          color: textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 24,
          height: 1.14,
          fontWeight: FontWeight.w900,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          height: 1.2,
          fontWeight: FontWeight.w900,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          height: 1.25,
          fontWeight: FontWeight.w900,
        ),
        titleSmall: TextStyle(
          color: textPrimary,
          fontSize: 14,
          height: 1.25,
          fontWeight: FontWeight.w800,
        ),
        bodyMedium: TextStyle(
          color: textPrimary,
          fontSize: 14,
          height: 1.38,
          fontWeight: FontWeight.w500,
        ),
        bodySmall: TextStyle(
          color: textMuted,
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: TextStyle(
          color: textMuted,
          fontSize: 12,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
        labelSmall: TextStyle(
          color: textMuted,
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
