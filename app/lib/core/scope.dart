import 'package:flutter/widgets.dart';

import '../l10n/gen/app_localizations.dart';
import 'career_state.dart';
import 'game_controller.dart';
import 'settings.dart';

/// Makes a [Listenable] available below it and rebuilds dependents when it
/// notifies.
class Scope<T extends Listenable> extends InheritedNotifier<T> {
  const Scope({super.key, required T value, required super.child})
      : super(notifier: value);

  static T of<T extends Listenable>(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<Scope<T>>();
    assert(s != null, 'No Scope<$T> above this widget');
    return s!.notifier!;
  }

  /// Reads without subscribing (for callbacks).
  static T read<T extends Listenable>(BuildContext context) {
    final s = context.getInheritedWidgetOfExactType<Scope<T>>();
    assert(s != null, 'No Scope<$T> above this widget');
    return s!.notifier!;
  }
}

/// The controller never changes, so it is a plain inherited value.
class ControllerScope extends InheritedWidget {
  const ControllerScope(
      {super.key, required this.controller, required super.child});
  final GameController controller;

  static GameController of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ControllerScope>()!.controller;

  @override
  bool updateShouldNotify(ControllerScope old) => controller != old.controller;
}

extension ScopeContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  CareerState get career => Scope.of<CareerState>(this);
  CareerState get careerRead => Scope.read<CareerState>(this);
  AppSettings get settings => Scope.of<AppSettings>(this);
  AppSettings get settingsRead => Scope.read<AppSettings>(this);
  GameController get controller => ControllerScope.of(this);
}
