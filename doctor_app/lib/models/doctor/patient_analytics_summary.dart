class PatientAnalyticsSummary {
  final double averageAccuracy;
  final double averageScore;
  final double averageCompletionRate;
  final int totalRepetitions;
  final List<SessionMetric> recentSessions;

  PatientAnalyticsSummary({
    required this.averageAccuracy,
    required this.averageScore,
    required this.averageCompletionRate,
    required this.totalRepetitions,
    required this.recentSessions,
  });

  factory PatientAnalyticsSummary.fromJson(Map<String, dynamic> json) {
    var sessionsList = json['recent_sessions'] as List? ?? [];
    return PatientAnalyticsSummary(
      averageAccuracy: (json['average_accuracy'] ?? 0).toDouble(),
      averageScore: (json['average_score'] ?? 0).toDouble(),
      averageCompletionRate: (json['average_completion_rate'] ?? 0).toDouble(),
      totalRepetitions: json['total_repetitions'] ?? 0,
      recentSessions: sessionsList.map((e) => SessionMetric.fromJson(e)).toList(),
    );
  }
}

class SessionMetric {
  final DateTime? date;
  final double accuracy;
  final double score;
  final int repetitions;

  SessionMetric({
    this.date,
    required this.accuracy,
    required this.score,
    required this.repetitions,
  });

  factory SessionMetric.fromJson(Map<String, dynamic> json) {
    return SessionMetric(
      date: json['date'] != null ? DateTime.tryParse(json['date']) : null,
      accuracy: (json['accuracy'] ?? 0).toDouble(),
      score: (json['score'] ?? 0).toDouble(),
      repetitions: json['repetitions'] ?? 0,
    );
  }
}
