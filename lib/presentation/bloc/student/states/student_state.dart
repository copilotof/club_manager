// lib/presentation/bloc/student/states/student_state.dart
import 'package:equatable/equatable.dart';
import '../../../../data/models/student_model.dart';

abstract class StudentState extends Equatable {
  const StudentState();
  @override
  List<Object?> get props => [];
}

class StudentInitial extends StudentState {}

class StudentLoading extends StudentState {}

class StudentsLoaded extends StudentState {
  final List<StudentModel> students;
  const StudentsLoaded(this.students);
  @override
  List<Object?> get props => [students];
}

class StudentOperationSuccess extends StudentState {
  final String message;
  const StudentOperationSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class StudentError extends StudentState {
  final String message;
  const StudentError(this.message);
  @override
  List<Object?> get props => [message];
}
