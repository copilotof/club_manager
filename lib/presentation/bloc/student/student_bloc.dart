// lib/presentation/bloc/student/student_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../screens/students_list_screen.dart';
import 'events/student_event.dart';
import 'states/student_state.dart';
import '../../../domain/repositories/i_student_repository.dart';
import '../../../data/models/student_model.dart';

class StudentBloc extends Bloc<StudentEvent, StudentState> {
  final IStudentRepository _repository;

  StudentBloc(this._repository) : super(StudentInitial()) {
    on<LoadStudentsEvent>(_onLoadStudents);
    on<AddStudentEvent>(_onAddStudent);
    on<UpdateStudentEvent>(_onUpdateStudent);
    on<DeleteStudentEvent>(_onDeleteStudent);
    on<SearchStudentsEvent>(_onSearchStudents);

    on<FilterStudentsByGroupEvent>((event, emit) async {
      emit(StudentLoading());
      try {
        final students = await _repository.getStudentsByGroup(event.groupId);
        emit(StudentsLoaded(students));
      } catch (e) {
        emit(StudentError(e.toString()));
      }
    });
  }

  Future<void> _onLoadStudents(
    LoadStudentsEvent event,
    Emitter<StudentState> emit,
  ) async {
    emit(StudentLoading());
    try {
      final students = await _repository.getAllStudents();
      emit(StudentsLoaded(students));
    } catch (e) {
      emit(StudentError(e.toString()));
    }
  }

  Future<void> _onAddStudent(
    AddStudentEvent event,
    Emitter<StudentState> emit,
  ) async {
    emit(StudentLoading());
    try {
      await _repository.addStudent(event.student);
      emit(const StudentOperationSuccess('تم إضافة الطالب بنجاح'));
      add(LoadStudentsEvent());
    } catch (e) {
      emit(StudentError(e.toString()));
    }
  }

  Future<void> _onUpdateStudent(
    UpdateStudentEvent event,
    Emitter<StudentState> emit,
  ) async {
    emit(StudentLoading());
    try {
      await _repository.updateStudent(event.student);
      emit(const StudentOperationSuccess('تم تحديث بيانات الطالب بنجاح'));
      add(LoadStudentsEvent());
    } catch (e) {
      emit(StudentError(e.toString()));
    }
  }

  Future<void> _onDeleteStudent(
    DeleteStudentEvent event,
    Emitter<StudentState> emit,
  ) async {
    emit(StudentLoading());
    try {
      await _repository.deleteStudent(event.studentId);
      emit(const StudentOperationSuccess('تم حذف الطالب بنجاح'));
      add(LoadStudentsEvent());
    } catch (e) {
      emit(StudentError(e.toString()));
    }
  }

  Future<void> _onSearchStudents(
    SearchStudentsEvent event,
    Emitter<StudentState> emit,
  ) async {
    emit(StudentLoading());
    try {
      final students = await _repository.searchStudents(event.query);
      emit(StudentsLoaded(students));
    } catch (e) {
      emit(StudentError(e.toString()));
    }
  }
}
