import 'package:flutter/material.dart';

import 'palette.dart';

/// The app theme built on [AppColors].
ThemeData appTheme() {
  final scheme = ColorScheme(
    brightness: AppColors.isLight ? Brightness.light : Brightness.dark,
    primary: AppColors.lilac,
    onPrimary: AppColors.onAccent,
    primaryContainer: AppColors.accentSoft,
    onPrimaryContainer: AppColors.text,
    secondary: AppColors.pink,
    onSecondary: Color(0xFF34121F),
    secondaryContainer: Color(0xFF4A2A38),
    onSecondaryContainer: AppColors.text,
    tertiary: AppColors.mint,
    onTertiary: Color(0xFF0E2E20),
    error: AppColors.coral,
    onError: AppColors.onAccent,
    surface: AppColors.bg,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textMuted,
    surfaceContainerLowest: AppColors.bg,
    surfaceContainerLow: AppColors.surfaceLow,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surfaceHigh,
    surfaceContainerHighest: AppColors.surfaceHighest,
    outline: AppColors.textFaint,
    outlineVariant: AppColors.line,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: AppFonts.ui,
    scaffoldBackgroundColor: AppColors.bg,
  );
  final t = base.textTheme;
  final shape20 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppShape.r(20)));
  return base.copyWith(
    textTheme: t.copyWith(
      headlineLarge: t.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
      headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      // Headings bold, item titles semi-bold, body regular (E8).
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      bodySmall: t.bodySmall?.copyWith(color: AppColors.textMuted),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: shape20,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      // Titles set like a paper's section heads (docs K88).
      titleTextStyle: TextStyle(
          fontFamily: AppFonts.condensed,
          fontSize: 25,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: AppColors.text),
    ),
    dividerTheme: DividerThemeData(color: AppColors.line, space: 1),
    listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: _pill(),
        textStyle: const TextStyle(
            fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: _pill(),
        side: BorderSide(color: AppColors.line, width: 1.4),
        foregroundColor: AppColors.text,
        textStyle: const TextStyle(
            fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(
            fontFamily: AppFonts.ui, fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surfaceHigh,
      selectedColor: AppColors.accentSoft,
      side: BorderSide.none,
      shape: _pill(),
      labelStyle: TextStyle(
          fontFamily: AppFonts.ui,
          fontWeight: FontWeight.w600,
          color: AppColors.text),
      checkmarkColor: AppColors.lilac,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surfaceHigh,
        selectedBackgroundColor: AppColors.accentSoft,
        selectedForegroundColor: AppColors.text,
        foregroundColor: AppColors.textMuted,
        side: BorderSide.none,
        shape: _pill(),
        textStyle: const TextStyle(
            fontFamily: AppFonts.ui, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShape.r(14)),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShape.r(14)),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShape.r(14)),
          borderSide: BorderSide(color: AppColors.lilac, width: 1.5)),
      labelStyle: TextStyle(color: AppColors.textMuted),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: AppColors.lilac,
      inactiveTrackColor: AppColors.surfaceHigh,
      thumbColor: AppColors.text,
      trackHeight: 6,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.bg
              : AppColors.textMuted),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.mint
              : AppColors.surfaceHigh),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceLow,
      indicatorColor: AppColors.accentSoft,
      indicatorShape: _pill(),
      height: 60,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: s.contains(WidgetState.selected)
                ? AppColors.text
                : AppColors.textMuted,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? AppColors.lilac
                : AppColors.textMuted,
          )),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppShape.r(28)))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShape.r(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: TextStyle(
          fontFamily: AppFonts.ui,
          color: AppColors.text,
          fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShape.r(16))),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.lilac,
      linearTrackColor: AppColors.surfaceHigh,
    ),
  );
}

/// Pill-shaped in the soft style, squared off in the sharp one (docs F1).
OutlinedBorder _pill() => AppShape.sharp
    ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
    : const StadiumBorder();
