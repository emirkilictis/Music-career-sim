import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/game_controller.dart';
import 'core/scope.dart';
import 'core/settings.dart';
import 'l10n/gen/app_localizations.dart';
import 'screens/slots_screen.dart';

class MusicCareerApp extends StatelessWidget {
  const MusicCareerApp(
      {super.key, required this.controller, required this.settings});

  final GameController controller;
  final AppSettings settings;

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8E5CFF),
      brightness: Brightness.dark,
    ).copyWith(surface: const Color(0xFF121016));
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ControllerScope(
      controller: controller,
      child: Scope<AppSettings>(
        value: settings,
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => MaterialApp(
            onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
            debugShowCheckedModeBanner: false,
            theme: theme(),
            locale: settings.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SlotsScreen(),
          ),
        ),
      ),
    );
  }
}
