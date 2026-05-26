// lib/data/models/student_model.dart
class StudentModel {
  final int? id;
  final String firstName;
  final String lastName;
  final DateTime birthDate;
  final String gender;
  final String? parentPhone;
  final DateTime enrollmentDate;
  final int? hallId;
  final int? groupId;
  final bool isActive;
  final String? photoUrl;

  // معلومات دراسية
  final double? semester1Grade;
  final double? semester2Grade;
  final double? semester3Grade;
  final String? academicNotes;

  // معلومات صحية
  final bool hasChronicDisease;
  final String? diseaseName;
  final String? medications;
  final String? medicalInstructions;
  final String? doctorName;
  final String? emergencyPhone;

  StudentModel({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.gender,
    this.parentPhone,
    required this.enrollmentDate,
    this.hallId,
    this.groupId,
    this.isActive = true,
    this.photoUrl,
    this.semester1Grade,
    this.semester2Grade,
    this.semester3Grade,
    this.academicNotes,
    this.hasChronicDisease = false,
    this.diseaseName,
    this.medications,
    this.medicalInstructions,
    this.doctorName,
    this.emergencyPhone,
  });

  String get fullName => '$firstName $lastName';

  int get age {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'birth_date': birthDate.toIso8601String(),
      'gender': gender,
      'parent_phone': parentPhone,
      'enrollment_date': enrollmentDate.toIso8601String(),
      'hall_id': hallId,
      'group_id': groupId,
      'is_active': isActive ? 1 : 0,
      'photo_url': photoUrl,
      'semester1_grade': semester1Grade,
      'semester2_grade': semester2Grade,
      'semester3_grade': semester3Grade,
      'academic_notes': academicNotes,
      'has_chronic_disease': hasChronicDisease ? 1 : 0,
      'disease_name': diseaseName,
      'medications': medications,
      'medical_instructions': medicalInstructions,
      'doctor_name': doctorName,
      'emergency_phone': emergencyPhone,
    };
  }

  factory StudentModel.fromMap(Map<String, dynamic> map) {
    return StudentModel(
      id: map['id'],
      firstName: map['first_name'],
      lastName: map['last_name'],
      birthDate: DateTime.parse(map['birth_date']),
      gender: map['gender'],
      parentPhone: map['parent_phone'],
      enrollmentDate: DateTime.parse(map['enrollment_date']),
      hallId: map['hall_id'],
      groupId: map['group_id'],
      isActive: map['is_active'] == 1,
      photoUrl: map['photo_url'],
      semester1Grade: map['semester1_grade']?.toDouble(),
      semester2Grade: map['semester2_grade']?.toDouble(),
      semester3Grade: map['semester3_grade']?.toDouble(),
      academicNotes: map['academic_notes'],
      hasChronicDisease: map['has_chronic_disease'] == 1,
      diseaseName: map['disease_name'],
      medications: map['medications'],
      medicalInstructions: map['medical_instructions'],
      doctorName: map['doctor_name'],
      emergencyPhone: map['emergency_phone'],
    );
  }
}
