class Patient {
  final String id;
  final String name;
  final int age;
  final String affectedHand; // 'Left', 'Right'
  final String strokeSubtype; // 'Ischemic', 'Hemorrhagic'
  final int complianceStreak;
  final double latestSessionScore;
  final Map<String, double> baselineCalibration; // e.g., {'Thumb': 45.0, 'Index': 50.0, 'Middle': 48.0}
  final List<SBARReport> reports;
  final List<TelemetryData> telemetry;
  final bool needsAttention;
  final String? alertMessage;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.affectedHand,
    required this.strokeSubtype,
    required this.complianceStreak,
    required this.latestSessionScore,
    required this.baselineCalibration,
    required this.reports,
    required this.telemetry,
    this.needsAttention = false,
    this.alertMessage,
  });
}

class SBARReport {
  final DateTime date;
  final String situation;
  final String background;
  final String assessment;
  final String recommendation;

  SBARReport({
    required this.date,
    required this.situation,
    required this.background,
    required this.assessment,
    required this.recommendation,
  });
}

class TelemetryData {
  final DateTime date;
  final double arom; // Active Range of Motion

  TelemetryData({
    required this.date,
    required this.arom,
  });
}
