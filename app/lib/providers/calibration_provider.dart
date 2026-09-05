import 'package:flutter/foundation.dart';
import '../models/calibration_data.dart';
import '../services/patient_api_service.dart';

class CalibrationProvider extends ChangeNotifier {
  CalibrationData _calibrationData = CalibrationData.defaultValues();
  final PatientApiService _apiService = PatientApiService();

  CalibrationData get calibrationData => _calibrationData;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> fetchLatestCalibration(String deviceId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _apiService.getLatestCalibration(deviceId);
      if (data.isNotEmpty) {
        _calibrationData = CalibrationData(
          flexMin: List<double>.from((data['flex_min'] as List).map((e) => e.toDouble())),
          flexMax: List<double>.from((data['flex_max'] as List).map((e) => e.toDouble())),
          fsrMin: data['fsr_min']?.toDouble() ?? 0.0,
          fsrMax: data['fsr_max']?.toDouble() ?? 1023.0,
        );
      }
    } catch (e) {
      debugPrint('Error fetching calibration: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveCalibrationToServer(String deviceId, {String? notes}) async {
    try {
      await _apiService.saveCalibration(
        deviceId, 
        _calibrationData.flexMin, 
        _calibrationData.flexMax, 
        notes: notes
      );
    } catch (e) {
      debugPrint('Error saving calibration: $e');
    }
  }

  void updateCalibration(CalibrationData newData) {
    _calibrationData = newData;
    notifyListeners();
  }

  /// Normalizes a raw flex value based on current calibration data.
  /// Returns a value between 0.0 (fully extended) and 1.0 (fully flexed).
  double normalizeFlexValue(int fingerIndex, double rawValue) {
    double min = _calibrationData.flexMin[fingerIndex];
    double max = _calibrationData.flexMax[fingerIndex];
    
    if (max <= min) return 0.0;
    
    double normalized = (rawValue - min) / (max - min);
    return normalized.clamp(0.0, 1.0);
  }
  
  /// Normalizes a raw FSR value.
  double normalizeFsrValue(double rawValue) {
     double min = _calibrationData.fsrMin;
     double max = _calibrationData.fsrMax;
     
     if (max <= min) return 0.0;
     
     double normalized = (rawValue - min) / (max - min);
     return normalized.clamp(0.0, 1.0);
  }
}
