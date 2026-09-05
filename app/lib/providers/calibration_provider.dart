import 'package:flutter/foundation.dart';
import '../models/calibration_data.dart';
import '../models/sensor_packet.dart';

class CalibrationProvider extends ChangeNotifier {
  CalibrationData _calibrationData = CalibrationData.defaultValues();

  CalibrationData get calibrationData => _calibrationData;

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
