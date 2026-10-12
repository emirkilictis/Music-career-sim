# Music Career Simulator — app

Flutter app (iOS + Android). It talks only to `packages/game`; the game runs
in a background isolate (`lib/core/game_controller.dart`), and every command
sent there is built in `lib/core/commands.dart`.

```
flutter pub get          # from the repo root (workspace)
flutter run              # iPhone / simulator / Android
flutter test             # widget + isolate tests
SCREENSHOTS=1 flutter test test/screenshots_test.dart   # → build/screenshots/
```

Texts live in `lib/l10n/app_en.arb` (main) and `app_tr.arb`.
See `../docs/mac-setup.md` for running it on an iPhone.
