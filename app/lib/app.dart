import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/game_controller.dart';
import 'core/images.dart';
import 'core/scope.dart';
import 'core/settings.dart';
import 'l10n/gen/app_localizations.dart';
import 'ui/palette.dart';
import 'ui/theme.dart';
import 'screens/slots_screen.dart';

class MusicCareerApp extends StatefulWidget {
  const MusicCareerApp(
      {super.key,
      required this.controller,
      required this.settings,
      required this.images});

  final GameController controller;
  final AppSettings settings;
  final ImageStore images;

  @override
  State<MusicCareerApp> createState() => _MusicCareerAppState();
}

class _MusicCareerAppState extends State<MusicCareerApp> {
  late Palette _palette = AppColors.palette;
  late bool _sharp = AppShape.sharp;

  /// Widgets read [AppColors] directly, so a theme change rebuilds every
  /// element (screens and their state stay as they are).
  void _rebuildAll() {
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final settings = widget.settings;
    return ControllerScope(
      controller: controller,
      child: Scope<ImageStore>(
        value: widget.images,
        child: Scope<AppSettings>(
          value: settings,
          child: ListenableBuilder(
            listenable: settings,
            builder: (context, _) {
              if (!identical(_palette, AppColors.palette) ||
                  _sharp != AppShape.sharp) {
                _palette = AppColors.palette;
                _sharp = AppShape.sharp;
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => mounted ? _rebuildAll() : null);
              }
              return MaterialApp(
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
                builder: (context, child) =>
                    AnnotatedRegion<SystemUiOverlayStyle>(
                  value: AppColors.isLight
                      ? SystemUiOverlayStyle.dark
                      : SystemUiOverlayStyle.light,
                  child: DismissKeyboard(child: child!),
                ),
                home: const SlotsScreen(),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Puts the keyboard away when the player is done typing (feedback): a
/// drag that scrolls the page, or a tap anywhere outside the field being
/// typed in (a tap on that field, or on another one, keeps it up).
class DismissKeyboard extends StatelessWidget {
  const DismissKeyboard({super.key, required this.child});
  final Widget child;

  static void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollStartNotification>(
      onNotification: (n) {
        if (n.dragDetails != null) _unfocus();
        return false;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: (e) {
          final focus = FocusManager.instance.primaryFocus;
          final ctx = focus?.context;
          if (ctx == null) return;
          // Only text fields hold the keyboard up; measure the whole field
          // (label and padding included), not just its text.
          final field = ctx.findAncestorStateOfType<State<TextField>>();
          final editable = ctx.widget is EditableText ||
              ctx.findAncestorWidgetOfExactType<EditableText>() != null;
          if (field == null && !editable) return;
          final box = (field?.context ?? ctx).findRenderObject();
          if (box is! RenderBox || !box.attached) return;
          final rect = box.localToGlobal(Offset.zero) & box.size;
          if (!rect.contains(e.position)) _unfocus();
        },
        child: child,
      ),
    );
  }
}
