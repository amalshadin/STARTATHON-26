import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';

class PatientApiService {
  static final PatientApiService _instance = PatientApiService._internal();
  factory PatientApiService() => _instance;
  PatientApiService._internal();


  String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';
  final _uuid = const Uuid();
  
  String? _authToken;
  String? _patientId;

  String? get currentPatientId => _patientId;

  void setAuthData(String token, String patientId) {
    _authToken = token;
    _patientId = patientId;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  // 1. Auth
  Future<Map<String, dynamic>> verifyPin(String email, String pin) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-pin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'pin': pin}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Failed to verify PIN: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // 2. Games
  Future<List<dynamic>> getGames() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/games'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
         return jsonDecode(response.body) as List<dynamic>;
      } else {
         throw Exception('Failed to fetch games');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // 2.5 Profile
  Future<Map<String, dynamic>> getPatientProfile() async {
    if (_patientId == null) throw Exception('Patient ID is required');
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patients/$_patientId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        // Fallback gracefully if not implemented on backend yet
        return {'name': 'Patient (Backend Pending)', 'doctor_name': 'Pending Doctor'};
      }
    } catch (e) {
      return {'name': 'Demo Patient (Offline)', 'doctor_name': 'Dr. Offline'};
    }
  }

  // 3. Calibrations
  Future<Map<String, dynamic>> getLatestCalibration(String deviceId) async {
    if (_patientId == null) throw Exception('Patient ID is required');
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/devices/$deviceId/calibrations/latest?patient_id=$_patientId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        return {}; // No calibration found
      } else {
        throw Exception('Failed to fetch calibration');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> saveCalibration(String deviceId, List<double> flexMin, List<double> flexMax, {String? notes}) async {
    if (_patientId == null) throw Exception('Patient ID is required');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/devices/$deviceId/calibrations'),
        headers: _headers,
        body: jsonEncode({
          'patient_id': _patientId,
          'flex_min': flexMin,
          'flex_max': flexMax,
          if (notes != null) 'notes': notes,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to save calibration');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // 4. Sessions
  Future<void> startTherapySession(String sessionId, String? deviceId) async {
    if (_patientId == null) throw Exception('Patient ID is required');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/therapy-sessions'),
        headers: _headers,
        body: jsonEncode({
          'id': sessionId,
          'patient_id': _patientId,
          if (deviceId != null) 'device_id': deviceId,
          'started_at': DateTime.now().toIso8601String(),
          'status': 'completed', // Typically updated at end, but requirements say POST status completed
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create therapy session');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> createGameSession({
    required String gameSessionId,
    required String therapySessionId,
    required String gameId,
    String? deviceId,
    String? calibrationId,
    required DateTime startedAt,
    required int durationMs,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/game-sessions'),
        headers: _headers,
        body: jsonEncode({
          'id': gameSessionId,
          'therapy_session_id': therapySessionId,
          'game_id': gameId,
          if (deviceId != null) 'device_id': deviceId,
          if (calibrationId != null) 'calibration_id': calibrationId,
          'started_at': startedAt.toIso8601String(),
          'ended_at': DateTime.now().toIso8601String(),
          'duration_ms': durationMs,
          'status': 'completed',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create game session');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> saveGameResults(String gameSessionId, int score, double accuracy, double completionRate, int repetitions, Map<String, dynamic> metrics) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/game-sessions/$gameSessionId/results'),
        headers: _headers,
        body: jsonEncode({
          'score': score,
          'accuracy': accuracy,
          'completion_rate': completionRate,
          'repetitions': repetitions,
          'metrics': metrics,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to save game results');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> saveGameMetrics(String gameSessionId, Map<String, dynamic> calculatedMetrics) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/game-sessions/$gameSessionId/metrics'),
        headers: _headers,
        body: jsonEncode({
          'algorithm_version': 'v0.1',
          'metrics': calculatedMetrics,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to save game metrics');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> submitGameData({
    required String gameId,
    String? deviceId,
    String? calibrationId,
    required DateTime startedAt,
    required int durationMs,
    required int score,
    required double accuracy,
    required double completionRate,
    required int repetitions,
    required Map<String, dynamic> resultsMetrics,
    required Map<String, dynamic> calculatedMetrics,
  }) async {
    final String therapySessionId = _uuid.v4();
    final String gameSessionId = _uuid.v4();

    // 1. Therapy Session
    await startTherapySession(therapySessionId, deviceId);
    
    // 2. Game Session
    await createGameSession(
      gameSessionId: gameSessionId, 
      therapySessionId: therapySessionId, 
      gameId: gameId, 
      deviceId: deviceId,
      calibrationId: calibrationId,
      startedAt: startedAt, 
      durationMs: durationMs
    );

    // 3. Results
    await saveGameResults(
      gameSessionId, 
      score, 
      accuracy, 
      completionRate, 
      repetitions, 
      resultsMetrics
    );

    // 4. Metrics
    await saveGameMetrics(
      gameSessionId, 
      calculatedMetrics
    );
  }
}
