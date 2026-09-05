class DoctorProfile {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final String specialization;
  final String licenseNumber;
  final String institution;
  final String hospitalName;

  DoctorProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.specialization,
    required this.licenseNumber,
    required this.institution,
    required this.hospitalName,
  });

  factory DoctorProfile.fromJson(Map<String, dynamic> json) {
    return DoctorProfile(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      specialization: json['specialization'] ?? '',
      licenseNumber: json['license_number'] ?? '',
      institution: json['institution'] ?? '',
      hospitalName: json['hospital_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'specialization': specialization,
      'license_number': licenseNumber,
      'institution': institution,
      'hospital_name': hospitalName,
    };
  }
}
