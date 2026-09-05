class PatientRecord {
  final String id;
  final String fullName;
  final DateTime? dateOfBirth;
  final String gender;
  final DateTime? strokeDate;
  final String affectedSide; // 'left' / 'right'
  final String notes;
  final String? invitationPin; // from patient_invitations
  
  PatientRecord({
    required this.id,
    required this.fullName,
    this.dateOfBirth,
    required this.gender,
    this.strokeDate,
    required this.affectedSide,
    required this.notes,
    this.invitationPin,
  });

  factory PatientRecord.fromJson(Map<String, dynamic> json) {
    return PatientRecord(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? '',
      dateOfBirth: json['date_of_birth'] != null ? DateTime.tryParse(json['date_of_birth']) : null,
      gender: json['gender'] ?? '',
      strokeDate: json['stroke_date'] != null ? DateTime.tryParse(json['stroke_date']) : null,
      affectedSide: json['affected_side'] ?? '',
      notes: json['notes'] ?? '',
      invitationPin: json['invitation_pin'], // optional
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'stroke_date': strokeDate?.toIso8601String(),
      'affected_side': affectedSide,
      'notes': notes,
      if (invitationPin != null) 'invitation_pin': invitationPin,
    };
  }
}
