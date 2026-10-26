import 'package:flutter/material.dart';

import '../ui/palette.dart';
import '../widgets/brand.dart';

/// Shown when the game cannot start here (docs K218), most often a browser
/// without WebAssembly garbage collection. Both languages: the app's own
/// translations are not loaded yet.
class StartFailedApp extends StatelessWidget {
  const StartFailedApp({super.key, required this.error});
  final String error;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0E0E0E),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const BrandMark(size: 88),
                const SizedBox(height: 24),
                for (final line in const [
                  'This browser cannot run the game. Please use a recent '
                      'Chrome, Edge, Firefox or Safari (18.2 or later).',
                  'Bu tarayıcı oyunu çalıştıramıyor. Lütfen güncel bir '
                      'Chrome, Edge, Firefox ya da Safari (18.2 veya üstü) '
                      'kullan.',
                ]) ...[
                  Text(line,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: AppFonts.ui,
                          color: Color(0xFFF3F1EC),
                          fontSize: 16,
                          height: 1.4)),
                  const SizedBox(height: 14),
                ],
                Text(error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFF6F6B64), fontSize: 12)),
              ]),
            ),
          ),
        ),
      );
}
