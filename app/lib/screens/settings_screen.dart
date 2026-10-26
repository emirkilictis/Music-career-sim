import 'package:flutter/material.dart';

import '../core/scope.dart';

/// Language and the Premium test switch.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings = context.settings;
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(children: [
        ListTile(title: Text(l.language)),
        RadioGroup<String?>(
          groupValue: settings.languageCode,
          onChanged: settings.setLanguage,
          child: Column(children: [
            RadioListTile<String?>(value: null, title: Text(l.languageSystem)),
            const RadioListTile<String?>(value: 'en', title: Text('English')),
            const RadioListTile<String?>(value: 'tr', title: Text('Türkçe')),
          ]),
        ),
        const Divider(),
        ListTile(title: Text(l.themeTitle)),
        RadioGroup<bool>(
          groupValue: settings.lightTheme,
          onChanged: (v) => settings.setLightTheme(v ?? false),
          child: Column(children: [
            RadioListTile<bool>(value: false, title: Text(l.themeNavy)),
            RadioListTile<bool>(value: true, title: Text(l.themeLight)),
          ]),
        ),
        ListTile(title: Text(l.cornersTitle)),
        RadioGroup<bool>(
          groupValue: settings.sharpCorners,
          onChanged: (v) => settings.setSharpCorners(v ?? false),
          child: Column(children: [
            RadioListTile<bool>(value: false, title: Text(l.cornersSoft)),
            RadioListTile<bool>(value: true, title: Text(l.cornersSharp)),
          ]),
        ),
        SwitchListTile(
          title: Text(l.avatarFaces),
          subtitle: Text(l.avatarFacesHint),
          value: settings.avatarFaces,
          onChanged: settings.setAvatarFaces,
        ),
        const Divider(),
        SwitchListTile(
          title: Text(l.weekTransition),
          subtitle: Text(l.weekTransitionHint),
          value: settings.weekTransition,
          onChanged: settings.setWeekTransition,
        ),
        SwitchListTile(
          title: Text(l.premiumTest),
          subtitle: Text(l.premiumTestHint),
          value: settings.premium,
          onChanged: settings.setPremium,
        ),
      ]),
    );
  }
}
