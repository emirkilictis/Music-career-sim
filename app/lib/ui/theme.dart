import 'package:flutter/material.dart';

import 'palette.dart';

/// The app theme built on [AppColors].
ThemeData appTheme() {
  final scheme = const ColorScheme.dark(
    primary: AppColors.lilac,
    onPrimary: Color(0xFF1B1530),
    primaryContainer: Color(0xFF3A3058),
    onPrimaryContainer: AppColors.text,
    secondary: AppColors.pink,
    onSecondary: Color(0xFF34121F),
    secondaryContainer: Color(0xFF4A2A38),
    onSecondaryContainer: AppColors.text,
    tertiary: AppColors.mint,
    onTertiary: Color(0xFF0E2E20),
    error: AppColors.coral,
    surface: AppColors.bg,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textMuted,
    surfaceContainerLowest: AppColors.bg,
    surfaceContainerLow: Color(0xFF17151F),
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surfaceHigh,
    surfaceContainerHighest: Color(0xFF2E2938),
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
  final shape20 =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
  return base.copyWith(
    textTheme: t.copyWith(
      headlineLarge: t.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
      headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      bodySmall: t.bodySmall?.copyWith(color: AppColors.textMuted),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: shape20,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.text),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
    listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
            fontFamily: AppFonts.ui, fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        side: const BorderSide(color: AppColors.line, width: 1.4),
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
      selectedColor: const Color(0xFF3A3058),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(
          fontFamily: AppFonts.ui,
          fontWeight: FontWeight.w600,
          color: AppColors.text),
      checkmarkColor: AppColors.lilac,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surfaceHigh,
        selectedBackgroundColor: const Color(0xFF3A3058),
        selectedForegroundColor: AppColors.text,
        foregroundColor: AppColors.textMuted,
        side: BorderSide.none,
        textStyle: const TextStyle(
            fontFamily: AppFonts.ui, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lilac, width: 1.5)),
      labelStyle: const TextStyle(color: AppColors.textMuted),
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
      backgroundColor: const Color(0xFF17151F),
      indicatorColor: const Color(0xFF3A3058),
      height: 66,
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
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: const TextStyle(
          fontFamily: AppFonts.ui,
          color: AppColors.text,
          fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.lilac,
      linearTrackColor: AppColors.surfaceHigh,
    ),
  );
}
