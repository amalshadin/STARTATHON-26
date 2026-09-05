import 'package:flutter/foundation.dart';
import '../models/doctor/doctor_profile.dart';
import '../models/doctor/patient_record.dart';
import '../services/doctor_api_service.dart';

class DoctorPortalProvider extends ChangeNotifier {
  final DoctorApiService _apiService = DoctorApiService();

  DoctorProfile? currentDoctor;
  String? authToken;
  
  List<PatientRecord> patients = [];
  bool isLoadingPatients = false;

  PatientRecord? selectedPatient;
  List<dynamic> activePatientHistory = [];
  bool isLoadingHistory = false;

  bool isLoading = false;
  String? errorMessage;

  bool get isAuthenticated => currentDoctor != null && authToken != null;

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final data = await _apiService.login(email, password);
      // Assuming endpoint returns token in 'access_token' and profile in 'doctor_profile'
      // Or we can fetch profile right after if not returned
      authToken = data['access_token'];
      _apiService.setToken(authToken!);
      
      if (data.containsKey('doctor_profile')) {
        currentDoctor = DoctorProfile.fromJson(data['doctor_profile']);
      } else {
        currentDoctor = await _apiService.getDoctorMe();
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(Map<String, dynamic> data) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.registerDoctor(data);
      // If endpoint returns token, we can auto-login, otherwise they may need to login manually.
      // Assuming it returns standard auth response or just the profile. We'll try to get token.
      if (response.containsKey('access_token')) {
        authToken = response['access_token'];
        _apiService.setToken(authToken!);
        if (response.containsKey('doctor_profile')) {
          currentDoctor = DoctorProfile.fromJson(response['doctor_profile']);
        } else {
          currentDoctor = await _apiService.getDoctorMe();
        }
      }
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPatients() async {
    if (!isAuthenticated) return;
    isLoadingPatients = true;
    errorMessage = null;
    notifyListeners();

    try {
      patients = await _apiService.fetchPatients();
    } catch (e) {
      errorMessage = e.toString();
      patients = [];
    } finally {
      isLoadingPatients = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> addPatient(Map<String, dynamic> data) async {
    if (!isAuthenticated) return null;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.addPatient(data);
      // The API returns { patient: {...}, pin: "482915", ... }
      if (response.containsKey('patient')) {
        final newPatient = PatientRecord.fromJson(response['patient']);
        patients.add(newPatient);
      }
      return response; // Return the whole response so UI can show the PIN
    } catch (e) {
      errorMessage = e.toString();
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectPatient(PatientRecord patient) async {
    selectedPatient = patient;
    notifyListeners();
    await fetchPatientHistory(patient.id);
  }

  Future<void> fetchPatientHistory(String patientId) async {
    isLoadingHistory = true;
    errorMessage = null;
    notifyListeners();

    try {
      activePatientHistory = await _apiService.getPatientHistory(patientId);
    } catch (e) {
      errorMessage = e.toString();
      activePatientHistory = [];
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }
}
