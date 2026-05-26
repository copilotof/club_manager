// lib/data/datasources/remote/supabase_client.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClient {
  static final SupabaseClient _instance = SupabaseClient._internal();
  late final Supabase _supabase;

  SupabaseClient._internal();

  factory SupabaseClient() {
    return _instance;
  }

  Future<void> initialize() async {
    await Supabase.initialize(
      url: 'YOUR_SUPABASE_URL', // سنضيفه لاحقاً
      anonKey: 'YOUR_SUPABASE_ANON_KEY', // سنضيفه لاحقاً
    );
    _supabase = Supabase.instance;
  }

  Supabase get client => _supabase;

  // الحصول على مرجع لجدول معين
  SupabaseQueryBuilder getStudents() {
    return _supabase.client.from('students');
  }

  SupabaseQueryBuilder getAttendances() {
    return _supabase.client.from('attendances');
  }
}
