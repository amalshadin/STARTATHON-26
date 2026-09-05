import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/doctor_portal_provider.dart';
import 'views/auth/login_screen.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DoctorPortalProvider()),
      ],
      child: const HapticSyncDoctorApp(),
    ),
  );
}

class HapticSyncDoctorApp extends StatelessWidget {
  const HapticSyncDoctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The HapticSync - Clinician Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter', // Or any modern font you've added
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF161F36),
          background: Color(0xFF0A0F1D),
          error: Color(0xFFF59E0B),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0F1D),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
