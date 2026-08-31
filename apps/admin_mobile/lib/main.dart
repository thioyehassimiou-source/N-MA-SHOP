import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/admin_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/responsive_mobile_frame.dart';
import 'features/auth/pin_auth_screen.dart';
import 'features/dashboard/admin_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Android Status & Navigation Bar Configuration
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const NMaShopAdminApp(),
    ),
  );
}

class NMaShopAdminApp extends StatelessWidget {
  const NMaShopAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'N\'MaShop Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return ResponsiveMobileFrame(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Consumer(
        builder: (context, ref, _) {
          final isAuthenticated = ref.watch(isAuthenticatedProvider);
          return isAuthenticated ? const AdminDashboardScreen() : const PinAuthScreen();
        },
      ),
    );
  }
}
