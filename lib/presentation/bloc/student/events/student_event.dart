// lib/presentation/bloc/student/events/student_event.dart
import 'package:equatable/equatable.dart';
import '../../../../data/models/student_model.dart';

abstract class StudentEvent extends Equatable {
  const StudentEvent();
  @override
  List<Object?> get props => [];
}

class LoadStudentsEvent extends StudentEvent {}

class AddStudentEvent extends StudentEvent {
  final StudentModel student;
  const AddStudentEvent(this.student);
  @override
  List<Object?> get props => [student];
}

class UpdateStudentEvent extends StudentEvent {
  final StudentModel student;
  const UpdateStudentEvent(this.student);
  @override
  List<Object?> get props => [student];
}

class DeleteStudentEvent extends StudentEvent {
  final int studentId;
  const DeleteStudentEvent(this.studentId);
  @override
  List<Object?> get props => [studentId];
}

class SearchStudentsEvent extends StudentEvent {
  final String query;
  const SearchStudentsEvent(this.query);
  @override
  List<Object?> get props => [query];
}
