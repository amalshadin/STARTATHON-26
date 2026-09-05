import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/doctor_state_provider.dart';
import 'views/doctor/doctor_root_scaffold.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DoctorStateProvider()),
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
      home: const DoctorRootScaffold(),
    );
  }
}
