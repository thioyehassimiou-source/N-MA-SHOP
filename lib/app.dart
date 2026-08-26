import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class GescomptaApp extends ConsumerWidget {
  const GescomptaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final palette = ref.watch(paletteProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'N\'MaShop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(palette),
      darkTheme: AppTheme.dark(palette),
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'),
      ],
      locale: const Locale('fr'),
      builder: (context, child) {
        return Focus(
          autofocus: true,
          canRequestFocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              final isCtrl = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlLeft) ||
                  HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlRight);
              final isShift = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
                  HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);
              if (isCtrl && isShift && event.logicalKey == LogicalKeyboardKey.keyA) {
                router.go('/admin/dashboard');
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
