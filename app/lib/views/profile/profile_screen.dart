import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';
import '../../services/patient_api_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Therapist Summary', style: DesignTokens.headingStyle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: DesignTokens.defaultPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: DesignTokens.primaryColor,
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 16),
              FutureBuilder<Map<String, dynamic>>(
                future: PatientApiService().getPatientProfile(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final data = snapshot.data ?? {};
                  final name = data['name'] ?? '${data['first_name'] ?? 'Unknown'} ${data['last_name'] ?? 'Patient'}';
                  final doctor = data['doctor_name'] ?? data['doctor'] ?? 'Unknown Doctor';
                  
                  return Column(
                    children: [
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: DesignTokens.headingStyle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Dr. $doctor',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              const Center(
                child: Text('No summary data available.', style: DesignTokens.bodyStyle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
