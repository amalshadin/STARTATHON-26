import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/design_tokens.dart';
import '../root_scaffold.dart';
import '../../services/patient_api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _apiService = PatientApiService(); // In a real app this would be injected via Provider
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.verifyPin(_emailController.text, _pinController.text);
      // Extract access_token or token from verify-pin response
      String token = response['access_token'] ?? response['token'] ?? response['magic_link'] ?? 'dummy_token';
      String patientId = response['patient_id'] ?? '00000000-0000-0000-0000-000000000000';
      
      _apiService.setAuthData(token, patientId);
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RootScaffold()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: DesignTokens.defaultPadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo or Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: DesignTokens.primaryColor.withOpacity(0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.health_and_safety_rounded,
                    size: 80,
                    color: DesignTokens.primaryColor,
                  ),
                ).animate().scale(delay: 200.ms, duration: 500.ms, curve: Curves.easeOutBack),
                
                const SizedBox(height: 32),
                
                // Welcome Text
                Text(
                  'Welcome Back',
                  textAlign: TextAlign.center,
                  style: DesignTokens.headingStyle.copyWith(
                    fontSize: 32,
                    color: DesignTokens.textPrimaryLight,
                  ),
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
                
                const SizedBox(height: 8),
                
                Text(
                  'Sign in to continue your rehabilitation journey.',
                  textAlign: TextAlign.center,
                  style: DesignTokens.bodyStyle.copyWith(
                    color: Colors.grey[600],
                  ),
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),
                
                const SizedBox(height: 48),
                
                // Form Card
                Card(
                  elevation: 8,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.borderRadiusLarge),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(DesignTokens.borderRadiusMedium),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.email_outlined, color: DesignTokens.primaryColor),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _pinController,
                          decoration: InputDecoration(
                            labelText: '6-Digit PIN',
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(DesignTokens.borderRadiusMedium),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.password, color: DesignTokens.primaryColor),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          obscureText: true,
                        ),
                        const SizedBox(height: 32),
                        
                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DesignTokens.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(DesignTokens.borderRadiusMedium),
                              ),
                              elevation: 4,
                            ),
                            child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0),
                
                const SizedBox(height: 24),
                
                // Removed Signup link
              ],
            ),
          ),
        ),
      ),
    );
  }
}
