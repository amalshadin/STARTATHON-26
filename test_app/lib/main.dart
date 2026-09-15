import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:hapticsync/core/design_tokens.dart';
import 'package:hapticsync/providers/ble_telemetry_provider.dart';
import 'package:hapticsync/providers/calibration_provider.dart';
import 'package:hapticsync/providers/game_session_provider.dart';
import 'package:hapticsync/providers/navigation_provider.dart';
import 'package:hapticsync/views/root_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  runApp(const HapticSyncTestApp());
}

class HapticSyncTestApp extends StatelessWidget {
  const HapticSyncTestApp({super.key});

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
        title: 'HapticSync Test App',
        theme: DesignTokens.lightTheme,
        home: const RootScaffold(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
