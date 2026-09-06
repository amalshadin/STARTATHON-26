import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';
import '../../services/patient_api_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Therapist Summary',
          style: DesignTokens.headingStyle,
        ),
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

                  // Extract patient name with high tolerance
                  final firstName =
                      data['first_name'] ??
                      data['firstName'] ??
                      data['given_name'];
                  final lastName =
                      data['last_name'] ??
                      data['lastName'] ??
                      data['family_name'];
                  String name = data['full_name'] ?? '';
                  if (name.isEmpty && firstName != null) {
                    name = '$firstName ${lastName ?? ''}'.trim();
                  }
                  if (name.isEmpty) {
                    name = 'Raw: $data'; // Debug fallback
                  }

                  // Extract doctor name with high tolerance
                  dynamic docData =
                      data['doctor'] ??
                      data['assigned_doctor'] ??
                      data['therapist'];
                  String doctorName =
                      data['doctor_name'] ?? data['doctorName'] ?? '';

                  if (doctorName.isEmpty && docData is Map) {
                    final docFirst =
                        docData['first_name'] ?? docData['firstName'];
                    final docLast = docData['last_name'] ?? docData['lastName'];
                    doctorName =
                        docData['name'] ??
                        (docFirst != null ? '$docFirst $docLast' : '');
                  }

                  if (doctorName.isEmpty) {
                    doctorName = docData is String ? docData : 'Unknown';
                  }

                  return Column(
                    children: [
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: DesignTokens.headingStyle.copyWith(
                          fontSize: name.startsWith('Raw:')
                              ? 14
                              : 24, // Smaller font if it's raw JSON
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Dr. $doctorName',
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
                child: Text(
                  'No summary data available.',
                  style: DesignTokens.bodyStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
