import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// NC LLC Agents brand seed (matches ajcoreios's NcLlcAgentsBuild.primaryColor).
const Color _seedColor = Color(0xFF1A3C6E);

class AjTheme {
  AjTheme._();

  static ThemeData get light => _build(
        ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.light),
        Brightness.light,
      );

  static ThemeData get dark => _build(
        ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark),
        Brightness.dark,
      );

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textTheme = _textTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: isDark ? scheme.surface : const Color(0xFFF6F7FB),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        backgroundColor: isDark ? scheme.surface : const Color(0xFFF6F7FB),
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? scheme.surfaceContainerHigh : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark
                ? scheme.outlineVariant.withValues(alpha: 0.3)
                : scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        margin: EdgeInsets.zero,
        shadowColor: scheme.shadow.withValues(alpha: 0.08),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainerHighest.withValues(alpha: 0.4) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: isDark ? scheme.surface : Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.shadow.withValues(alpha: 0.1),
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? scheme.primary : scheme.onSurfaceVariant, size: 22);
        }),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), thickness: 1, space: 0),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minVerticalPadding: 10,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDark ? scheme.surfaceContainerHigh : scheme.onSurface,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? scheme.surfaceContainerLow : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    );
  }

  static TextTheme _textTheme() {
    return const TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.0),
      displayMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      displaySmall: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      headlineSmall: TextStyle(fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontWeight: FontWeight.w400),
      bodySmall: TextStyle(fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontWeight: FontWeight.w500),
      labelSmall: TextStyle(fontWeight: FontWeight.w500),
    );
  }
}
