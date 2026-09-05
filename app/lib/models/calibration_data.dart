class CalibrationData {
  // Min values (fully extended)
  List<double> flexMin;
  // Max values (fully flexed)
  List<double> flexMax;
  
  double fsrMin;
  double fsrMax;

  CalibrationData({
    required this.flexMin,
    required this.flexMax,
    required this.fsrMin,
    required this.fsrMax,
  });

  factory CalibrationData.defaultValues() {
    return CalibrationData(
      flexMin: [0.0, 0.0, 0.0, 0.0, 0.0],
      flexMax: [1023.0, 1023.0, 1023.0, 1023.0, 1023.0],
      fsrMin: 0.0,
      fsrMax: 1023.0,
    );
  }
}
