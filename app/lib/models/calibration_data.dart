class CalibrationData {
  // Min values (fully extended)
  List<double> flexMin;
  // Max values (fully flexed)
  List<double> flexMax;
  
  double fsrMin;
  double fsrMax;
  
  // IMU Offsets
  double accXOffset;
  double accYOffset;
  double accZOffset;
  double gyroXOffset;
  double gyroYOffset;
  double gyroZOffset;

  CalibrationData({
    required this.flexMin,
    required this.flexMax,
    required this.fsrMin,
    required this.fsrMax,
    required this.accXOffset,
    required this.accYOffset,
    required this.accZOffset,
    required this.gyroXOffset,
    required this.gyroYOffset,
    required this.gyroZOffset,
  });

  factory CalibrationData.defaultValues() {
    return CalibrationData(
      flexMin: [0.0, 0.0, 0.0, 0.0, 0.0],
      flexMax: [1023.0, 1023.0, 1023.0, 1023.0, 1023.0],
      fsrMin: 0.0,
      fsrMax: 1023.0,
      accXOffset: 0.0,
      accYOffset: 0.0,
      accZOffset: 0.0,
      gyroXOffset: 0.0,
      gyroYOffset: 0.0,
      gyroZOffset: 0.0,
    );
  }
}
