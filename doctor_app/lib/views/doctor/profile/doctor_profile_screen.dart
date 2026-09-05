import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/doctor_portal_provider.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({Key? key}) : super(key: key);

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  bool _fatigueAlerts = true;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorPortalProvider>();
    final doctor = provider.currentDoctor;

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0F1D),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                
                // Profile Info
                Center(
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xFF161F36),
                        child: Icon(Icons.person, size: 50, color: Color(0xFF00E5FF)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        doctor?.fullName?.isNotEmpty == true ? doctor!.fullName : 'Unknown Doctor',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'License No: ${doctor?.licenseNumber?.isNotEmpty == true ? doctor!.licenseNumber : 'N/A'}',
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${doctor?.specialization?.isNotEmpty == true ? doctor!.specialization : 'Specialization'} • ${doctor?.hospitalName?.isNotEmpty == true ? doctor!.hospitalName : 'Hospital'}',
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
  
                // Settings
                const Text(
                  'Settings',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161F36),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Fatigue Alerts', style: TextStyle(color: Colors.white)),
                        subtitle: const Text('Receive immediate alerts for patient fatigue', style: TextStyle(color: Colors.white54)),
                        activeColor: const Color(0xFF00E5FF),
                        value: _fatigueAlerts,
                        onChanged: (val) => setState(() => _fatigueAlerts = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                
                // Log Out
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Optionally clear provider state and navigate back to login
                      provider.authToken = null;
                      provider.currentDoctor = null;
                      Navigator.pushReplacementNamed(context, '/'); // assuming '/' is login
                    },
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    label: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 80), // Padding for bottom nav bar
              ],
            ),
          ),
        ),
      ),
    );
  }
}
