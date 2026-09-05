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
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _strokeDateController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _gender = 'Male';
  String _affectedSide = 'left';
  bool _isLoading = false;
  bool _isSubmitted = false;
  String? _generatedPin;
  String? _patientId;

  Future<void> _submit() async {
    if (_nameController.text.isEmpty) return;

    setState(() => _isLoading = true);
    final data = {
      'full_name': _nameController.text,
      if (_emailController.text.isNotEmpty) 'email': _emailController.text,
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
          
          if (response['patient'] != null && response['patient']['id'] != null) {
            _patientId = response['patient']['id'].toString();
          } else {
            _patientId = 'N/A';
          }
          
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
          _buildTextField('Email Address (Optional)', _emailController),
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
          _buildDatePicker('Date of Birth', _dobController),
          const SizedBox(height: 16),
          _buildDatePicker('Stroke Date', _strokeDateController),
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

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00E5FF),
              onPrimary: Colors.black,
              surface: Color(0xFF161F36),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        controller.text = "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Widget _buildDatePicker(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () => _selectDate(context, controller),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF0A0F1D),
        suffixIcon: const Icon(Icons.calendar_today, color: Colors.white54),
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
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F1D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('Patient ID:', style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 4),
              SelectableText(
                _patientId ?? 'N/A',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text('Generated PIN:', style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 4),
              SelectableText(
                _generatedPin ?? 'N/A',
                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Give this ID and PIN to your patient to log into their home glove app.',
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
