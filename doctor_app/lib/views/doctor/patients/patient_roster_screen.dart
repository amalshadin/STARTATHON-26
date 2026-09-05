import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/doctor_portal_provider.dart';
import '../../../models/doctor/patient_record.dart';
import 'add_patient_dialog.dart';
import 'patient_detail_screen.dart';

class PatientRosterScreen extends StatefulWidget {
  const PatientRosterScreen({Key? key}) : super(key: key);

  @override
  State<PatientRosterScreen> createState() => _PatientRosterScreenState();
}

class _PatientRosterScreenState extends State<PatientRosterScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorPortalProvider>();
    List<PatientRecord> filteredPatients = provider.patients.where((p) {
      return p.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) || 
             p.id.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0F1D),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Patients',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const AddPatientDialog(),
                      );
                    },
                    icon: const Icon(Icons.add, color: Colors.black),
                    label: const Text(
                      'Add',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Search Bar
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by name or ID...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF161F36),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Roster List
              Expanded(
                child: provider.isLoadingPatients
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
                    : filteredPatients.isEmpty
                        ? const Center(child: Text('No patients found.', style: TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            itemCount: filteredPatients.length,
                            itemBuilder: (context, index) {
                              return _buildPatientCard(context, filteredPatients[index], provider);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientCard(BuildContext context, PatientRecord patient, DoctorPortalProvider provider) {
    return GestureDetector(
      onTap: () {
        provider.selectPatient(patient);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PatientDetailScreen(patientId: patient.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161F36),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF0A0F1D),
                      child: Text(
                        patient.fullName.isNotEmpty ? patient.fullName.substring(0, 1).toUpperCase() : '?',
                        style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0F1D),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            patient.id.length > 8 ? patient.id.substring(0, 8) : patient.id,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStat('Gender', patient.gender),
                _buildStat('Affected', patient.affectedSide.toUpperCase()),
                _buildStat('Has PIN', patient.invitationPin != null ? 'Yes' : 'No'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
