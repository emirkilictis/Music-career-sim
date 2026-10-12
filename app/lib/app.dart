import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/game_controller.dart';
import 'core/scope.dart';
import 'core/settings.dart';
import 'l10n/gen/app_localizations.dart';
import 'ui/theme.dart';
import 'screens/slots_screen.dart';

class MusicCareerApp extends StatelessWidget {
  const MusicCareerApp(
      {super.key, required this.controller, required this.settings});

  final GameController controller;
  final AppSettings settings;

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
            theme: appTheme(),
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
