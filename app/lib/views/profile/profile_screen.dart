import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Therapist Summary', style: DesignTokens.headingStyle),
      ),
      body: SafeArea(
        child: Padding(
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
              const Text(
                'Patient: Jane Doe',
                textAlign: TextAlign.center,
                style: DesignTokens.headingStyle,
              ),
              const Text(
                'Right Hemiparesis - 3 Months Post',
                textAlign: TextAlign.center,
                style: DesignTokens.bodyStyle,
              ),
              const SizedBox(height: 32),
              
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.borderRadiusMedium)),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SBAR Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('S: Improving active flexion in digits 2 & 3.'),
                      Text('B: Ischemic stroke, starting baseline ROM was 20%.'),
                      Text('A: Reached 60% normalized ROM; fatigue after 15 min.'),
                      Text('R: Increase session duration to 20 mins.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.share),
                label: const Text('Export SBAR Report'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
