class SbarClinicalReport {
  final String? id;
  final String patientId;
  final String doctorId;
  final String situation;
  final String background;
  final String assessment;
  final String recommendation;
  final DateTime? createdAt;
  final String generatedBy;

  SbarClinicalReport({
    this.id,
    required this.patientId,
    required this.doctorId,
    required this.situation,
    required this.background,
    required this.assessment,
    required this.recommendation,
    this.createdAt,
    required this.generatedBy,
  });

  factory SbarClinicalReport.fromJson(Map<String, dynamic> json) {
    return SbarClinicalReport(
      id: json['id'],
      patientId: json['patient_id'] ?? '',
      doctorId: json['doctor_id'] ?? '',
      situation: json['situation'] ?? '',
      background: json['background'] ?? '',
      assessment: json['assessment'] ?? '',
      recommendation: json['recommendation'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      generatedBy: json['generated_by'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'situation': situation,
      'background': background,
      'assessment': assessment,
      'recommendation': recommendation,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      'generated_by': generatedBy,
    };
  }
}
