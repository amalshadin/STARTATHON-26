import 'package:flutter/foundation.dart';
import '../models/calibration_data.dart';
import '../models/sensor_packet.dart';
import '../services/patient_api_service.dart';

class CalibrationProvider extends ChangeNotifier {
  CalibrationData _calibrationData = CalibrationData.defaultValues();
  final PatientApiService _apiService = PatientApiService();

  CalibrationData get calibrationData => _calibrationData;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isCalibrated = false;
  bool get isCalibrated => _isCalibrated;

  void setCalibrated(bool val) {
    _isCalibrated = val;
    notifyListeners();
  }

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
          fsrMax: data['fsr_max']?.toDouble() ?? 4095.0,
          accXOffset: 0.0,
          accYOffset: 0.0,
          accZOffset: 0.0,
          gyroXOffset: 0.0,
          gyroYOffset: 0.0,
          gyroZOffset: 0.0,
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

  void recordNeutralBaseline(List<SensorPacket> samples) {
    if (samples.isEmpty) return;
    
    List<double> avgFlex = [0.0, 0.0, 0.0, 0.0, 0.0];
    double avgAccX = 0, avgAccY = 0, avgGyroZ = 0;
    
    for (var s in samples) {
      for (int i = 0; i < 5; i++) {
        avgFlex[i] += s.flexValues[i];
      }
      avgAccX += s.pitch; // Raw accX is in pitch
      avgAccY += s.roll;  // Raw accY is in roll
      avgGyroZ += s.yaw;  // Raw gyroZ is in yaw
    }
    
    for (int i = 0; i < 5; i++) {
      avgFlex[i] /= samples.length;
    }
    
    _calibrationData.flexMin = avgFlex;
    _calibrationData.accXOffset = avgAccX / samples.length;
    _calibrationData.accYOffset = avgAccY / samples.length;
    _calibrationData.gyroZOffset = avgGyroZ / samples.length;
    notifyListeners();
  }

  void recordMaxFlexion(List<SensorPacket> samples) {
    if (samples.isEmpty) return;
    
    List<double> maxFlex = [0.0, 0.0, 0.0, 0.0, 0.0];
    
    for (int i = 0; i < 5; i++) {
      List<double> sensorVals = samples.map((s) => s.flexValues[i]).toList();
      sensorVals.sort((a, b) => b.compareTo(a)); // Descending
      // Average the peak 10%
      int takeCount = (sensorVals.length * 0.1).ceil().clamp(1, 10);
      double peakAvg = sensorVals.take(takeCount).reduce((a, b) => a + b) / takeCount;
      maxFlex[i] = peakAvg;
    }
    
    _calibrationData.flexMax = maxFlex;
    notifyListeners();
  }

  double getCorrectedPitch(double rawAccX) {
    double corrected = rawAccX - _calibrationData.accXOffset;
    // Deadband threshold approx 3 degrees for MPU6050 (1g = 16384) -> 3 deg = 550
    if (corrected.abs() < 550) return 0.0;
    return corrected;
  }

  double getCorrectedRoll(double rawAccY) {
    double corrected = rawAccY - _calibrationData.accYOffset;
    if (corrected.abs() < 550) return 0.0;
    return corrected;
  }

  Future<void> saveAndUploadCalibration() async {
    _isCalibrated = true;
    notifyListeners();
    // Skipping API upload as backend does not have devices endpoint yet.
  }

  /// Normalizes a raw flex value based on current calibration data.
  /// Returns a value between 0.0 (fully extended) and 1.0 (fully flexed).
  double normalizeFlexValue(int fingerIndex, double rawValue) {
    double min = _calibrationData.flexMin[fingerIndex];
    double max = _calibrationData.flexMax[fingerIndex];
    
    if ((max - min).abs() < 10) return 0.0;
    
    double normalized = (rawValue - min) / (max - min);
    return normalized.clamp(0.0, 1.0);
  }
  
  /// Normalizes a raw FSR value.
  double normalizeFsrValue(double rawValue) {
     double min = _calibrationData.fsrMin;
     double max = _calibrationData.fsrMax;
     
     if ((max - min).abs() < 10) return 0.0;
     
     double normalized = (rawValue - min) / (max - min);
     return normalized.clamp(0.0, 1.0);
  }
}
