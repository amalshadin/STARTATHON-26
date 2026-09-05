import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/doctor_state_provider.dart';
import '../../../models/patient.dart';
import 'dart:math';
import 'package:flutter/services.dart';

class AddPatientDialog extends StatefulWidget {
  const AddPatientDialog({Key? key}) : super(key: key);

  @override
  State<AddPatientDialog> createState() => _AddPatientDialogState();
}

class _AddPatientDialogState extends State<AddPatientDialog> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _affectedHand = 'Right';
  String _strokeSubtype = 'Ischemic';
  
  bool _isSubmitted = false;
  String? _generatedId;

  void _submit() {
    if (_nameController.text.isEmpty || _ageController.text.isEmpty) return;

    final random = Random();
    final newId = 'HS-${random.nextInt(9000) + 1000}';
    
    final newPatient = Patient(
      id: newId,
      name: _nameController.text,
      age: int.tryParse(_ageController.text) ?? 60,
      affectedHand: _affectedHand,
      strokeSubtype: _strokeSubtype,
      complianceStreak: 0,
      latestSessionScore: 0.0,
      baselineCalibration: {'Thumb': 0.0, 'Index': 0.0, 'Middle': 0.0},
      reports: [],
      telemetry: [],
      needsAttention: false,
    );

    context.read<DoctorStateProvider>().addPatient(newPatient);

    setState(() {
      _generatedId = newId;
      _isSubmitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161F36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _isSubmitted ? _buildConfirmation() : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add New Patient',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        
        _buildTextField('Full Name', _nameController),
        const SizedBox(height: 16),
        _buildTextField('Age', _ageController, isNumber: true),
        const SizedBox(height: 16),
        
        const Text('Affected Hand', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Left', label: Text('Left')),
            ButtonSegment(value: 'Right', label: Text('Right')),
          ],
          selected: {_affectedHand},
          onSelectionChanged: (Set<String> newSelection) {
            setState(() => _affectedHand = newSelection.first);
          },
          style: SegmentedButton.styleFrom(
            foregroundColor: Colors.white,
            selectedForegroundColor: const Color(0xFF00E5FF),
            backgroundColor: const Color(0xFF0A0F1D),
            selectedBackgroundColor: const Color(0xFF00E5FF).withOpacity(0.2),
          ),
        ),
        const SizedBox(height: 16),

        const Text('Stroke Subtype', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Ischemic', label: Text('Ischemic')),
            ButtonSegment(value: 'Hemorrhagic', label: Text('Hemorrhagic')),
          ],
          selected: {_strokeSubtype},
          onSelectionChanged: (Set<String> newSelection) {
            setState(() => _strokeSubtype = newSelection.first);
          },
          style: SegmentedButton.styleFrom(
            foregroundColor: Colors.white,
            selectedForegroundColor: const Color(0xFF00E5FF),
            backgroundColor: const Color(0xFF0A0F1D),
            selectedBackgroundColor: const Color(0xFF00E5FF).withOpacity(0.2),
          ),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Generate Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ));
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF0A0F1D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildConfirmation() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 64),
        const SizedBox(height: 16),
        const Text(
          'Patient Added',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F1D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text('Generated Patient ID:', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 8),
              Text(
                _generatedId!,
                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Give this ID to your patient to log into their home glove app.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _generatedId!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Patient ID copied to clipboard!')),
                );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.copy, color: Colors.black),
              label: const Text('Copy ID', style: TextStyle(color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
              ),
            ),
          ],
        )
      ],
    );
  }
}
