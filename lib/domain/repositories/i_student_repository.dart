// lib/domain/repositories/i_student_repository.dart
import '../../data/models/student_model.dart';

abstract class IStudentRepository {
  Future<List<StudentModel>> getAllStudents();
  Future<StudentModel?> getStudentById(int id);
  Future<StudentModel?> getStudentByQR(String qrData);
  Future<void> addStudent(StudentModel student);
  Future<void> updateStudent(StudentModel student);
  Future<void> deleteStudent(int id);
  Future<List<StudentModel>> searchStudents(String query);
}
