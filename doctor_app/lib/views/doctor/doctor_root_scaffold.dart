import 'package:flutter/material.dart';
import 'package:crystal_navigation_bar/crystal_navigation_bar.dart';

import 'dashboard/doctor_dashboard_screen.dart';
import 'patients/patient_roster_screen.dart';
import 'profile/doctor_profile_screen.dart';

class DoctorRootScaffold extends StatefulWidget {
  const DoctorRootScaffold({Key? key}) : super(key: key);

  @override
  State<DoctorRootScaffold> createState() => _DoctorRootScaffoldState();
}

class _DoctorRootScaffoldState extends State<DoctorRootScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DoctorDashboardScreen(),
    const PatientRosterScreen(),
    const DoctorProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D), // Dark Theme Background
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      extendBody: true, // required for crystal navigation bar transparent effect
      bottomNavigationBar: CrystalNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          CrystalNavigationBarItem(
            icon: Icons.dashboard_rounded,
            unselectedIcon: Icons.dashboard_outlined,
            selectedColor: const Color(0xFF00E5FF), // Cyan
          ),
          CrystalNavigationBarItem(
            icon: Icons.people_alt_rounded,
            unselectedIcon: Icons.people_outline_rounded,
            selectedColor: const Color(0xFF00E5FF),
          ),
          CrystalNavigationBarItem(
            icon: Icons.person_rounded,
            unselectedIcon: Icons.person_outline_rounded,
            selectedColor: const Color(0xFF00E5FF),
          ),
        ],
        backgroundColor: const Color(0xFF161F36).withOpacity(0.8), // Surface
        outlineBorderColor: Colors.transparent,
        unselectedItemColor: Colors.white54,
        marginR: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
    );
  }
}
