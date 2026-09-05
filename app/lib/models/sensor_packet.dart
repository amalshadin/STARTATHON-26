class SensorPacket {
  final DateTime timestamp;
  final List<double> flexValues; // 5 values for 5 fingers [0.0 - 1.0]
  final double fsrGripPressure; // [0.0 - 1.0]
  final double pitch;
  final double roll;
  final double yaw;

  SensorPacket({
    required this.timestamp,
    required this.flexValues,
    required this.fsrGripPressure,
    required this.pitch,
    required this.roll,
    required this.yaw,
  });

  factory SensorPacket.empty() {
    return SensorPacket(
      timestamp: DateTime.now(),
      flexValues: [0.0, 0.0, 0.0, 0.0, 0.0],
      fsrGripPressure: 0.0,
      pitch: 0.0,
      roll: 0.0,
      yaw: 0.0,
    );
  }
}
