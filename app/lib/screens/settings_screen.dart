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
