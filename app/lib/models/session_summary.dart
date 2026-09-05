class SessionSummary {
  final String sessionId;
  final DateTime startTime;
  final DateTime endTime;
  final int totalScore;
  final double averageFlexion;
  final double maxGripPressure;
  final String gameType;

  SessionSummary({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.totalScore,
    required this.averageFlexion,
    required this.maxGripPressure,
    required this.gameType,
  });

  Duration get duration => endTime.difference(startTime);
}
