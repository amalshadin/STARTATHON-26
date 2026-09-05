import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/design_tokens.dart';
import 'providers/ble_telemetry_provider.dart';
import 'providers/calibration_provider.dart';
import 'providers/game_session_provider.dart';
import 'providers/navigation_provider.dart';
import 'views/root_scaffold.dart';

import 'views/auth/login_screen.dart';

void main() {
  runApp(const HapticSyncApp());
}

class HapticSyncApp extends StatelessWidget {
  const HapticSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => BleTelemetryProvider()),
        ChangeNotifierProvider(create: (_) => CalibrationProvider()),
        ChangeNotifierProvider(create: (_) => GameSessionProvider()),
      ],
      child: MaterialApp(
        title: 'The HapticSync',
        theme: DesignTokens.lightTheme,
        home: const LoginScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
