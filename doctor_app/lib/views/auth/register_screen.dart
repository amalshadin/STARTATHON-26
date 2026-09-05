import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/doctor_portal_provider.dart';
import '../doctor/doctor_root_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  Future<void> _register() async {
    final provider = Provider.of<DoctorPortalProvider>(context, listen: false);
    final data = {
      'full_name': _nameController.text,
      'email': _emailController.text,
      'hospital_name': _hospitalController.text,
      'password': _passwordController.text,
    };
    
    final success = await provider.register(data);
    
    if (success && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DoctorRootScaffold()),
        (route) => false,
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'Registration failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorPortalProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign up for the Clinician Portal',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
                const SizedBox(height: 32),
                _buildTextField(
                  'Full Name',
                  _nameController,
                  Icons.person_outline,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Email Address',
                  _emailController,
                  Icons.email_outlined,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Hospital Affiliation',
                  _hospitalController,
                  Icons.local_hospital_outlined,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Password',
                  _passwordController,
                  Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: provider.isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: provider.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : const Text(
                          'Sign Up',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF161F36),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
