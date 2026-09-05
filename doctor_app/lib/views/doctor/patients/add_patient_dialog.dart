import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/doctor_portal_provider.dart';
import 'package:flutter/services.dart';

class AddPatientDialog extends StatefulWidget {
  const AddPatientDialog({Key? key}) : super(key: key);

  @override
  State<AddPatientDialog> createState() => _AddPatientDialogState();
}

class _AddPatientDialogState extends State<AddPatientDialog> {
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _strokeDateController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _gender = 'Male';
  String _affectedSide = 'left';
  bool _isLoading = false;
  bool _isSubmitted = false;
  String? _generatedPin;

  Future<void> _submit() async {
    if (_nameController.text.isEmpty) return;

    setState(() => _isLoading = true);
    final data = {
      'full_name': _nameController.text,
      'gender': _gender,
      'date_of_birth': _dobController.text.isNotEmpty ? _dobController.text : null,
      'stroke_date': _strokeDateController.text.isNotEmpty ? _strokeDateController.text : null,
      'affected_side': _affectedSide,
      'notes': _notesController.text,
    };

    try {
      final provider = Provider.of<DoctorPortalProvider>(context, listen: false);
      final response = await provider.addPatient(data);
      if (!mounted) return;
      
      if (response != null) {
        setState(() {
          _generatedPin = response['pin']?.toString() ?? 'N/A';
          _isSubmitted = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.errorMessage ?? 'Failed to add patient')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          DropdownButtonFormField<String>(
            value: _gender,
            dropdownColor: const Color(0xFF161F36),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Gender', 
              labelStyle: TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Color(0xFF0A0F1D),
            ),
            items: ['Male', 'Female', 'Other'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (val) => setState(() => _gender = val!),
          ),
          const SizedBox(height: 16),
          _buildTextField('Date of Birth (YYYY-MM-DD)', _dobController),
          const SizedBox(height: 16),
          _buildTextField('Stroke Date (YYYY-MM-DD)', _strokeDateController),
          const SizedBox(height: 16),
          const Text('Affected Hand', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'left', label: Text('Left')),
              ButtonSegment(value: 'right', label: Text('Right')),
            ],
            selected: {_affectedSide},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() => _affectedSide = newSelection.first);
            },
            style: SegmentedButton.styleFrom(
              foregroundColor: Colors.white,
              selectedForegroundColor: const Color(0xFF00E5FF),
              backgroundColor: const Color(0xFF0A0F1D),
              selectedBackgroundColor: const Color(0xFF00E5FF).withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField('Clinical Notes', _notesController),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Text('Generate Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
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
              const Text('Generated Patient PIN / ID:', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 8),
              Text(
                _generatedPin ?? 'N/A',
                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Give this PIN to your patient to log into their home glove app.',
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
                if (_generatedPin != null) {
                  Clipboard.setData(ClipboardData(text: _generatedPin!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Patient PIN copied to clipboard!')),
                  );
                }
                Navigator.pop(context);
              },
              icon: const Icon(Icons.copy, color: Colors.black),
              label: const Text('Copy PIN', style: TextStyle(color: Colors.black)),
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
