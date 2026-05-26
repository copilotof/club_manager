// lib/data/datasources/local/app_database.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static Database? _database;

  AppDatabase();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fight_club.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // ✅ زيادة رقم الإصدار من 1 إلى 2
      onCreate: _createTables,
      onUpgrade: _onUpgrade, // ✅ إضافة دالة الترقية
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // جدول الطلبة
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        birth_date TEXT NOT NULL,
        gender TEXT NOT NULL,
        parent_phone TEXT,
        enrollment_date TEXT NOT NULL,
        hall_id INTEGER,
        group_id INTEGER,
        is_active INTEGER DEFAULT 1,
        photo_url TEXT,
        semester1_grade REAL,
        semester2_grade REAL,
        semester3_grade REAL,
        academic_notes TEXT,
        has_chronic_disease INTEGER DEFAULT 0,
        disease_name TEXT,
        medications TEXT,
        medical_instructions TEXT,
        doctor_name TEXT,
        emergency_phone TEXT
      )
    ''');

    // جدول الحضور والغياب
    await db.execute('''
      CREATE TABLE attendances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        session_date TEXT NOT NULL,
        is_present INTEGER DEFAULT 0,
        was_auto_generated INTEGER DEFAULT 1,
        marked_at TEXT,
        excuse_reason TEXT,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        UNIQUE(student_id, session_date)
      )
    ''');

    // جدول العمليات المعلقة للمزامنة
    await db.execute('''
      CREATE TABLE pending_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_type TEXT NOT NULL,
        table_name TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        retry_count INTEGER DEFAULT 0,
        synced INTEGER DEFAULT 0
      )
    ''');
  }

  // ✅ دالة الترقية (عند تغيير رقم الإصدار)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // إنشاء جدول attendances إذا لم يكن موجوداً
      await db.execute('''
        CREATE TABLE IF NOT EXISTS attendances (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER NOT NULL,
          session_date TEXT NOT NULL,
          is_present INTEGER DEFAULT 0,
          was_auto_generated INTEGER DEFAULT 1,
          marked_at TEXT,
          excuse_reason TEXT,
          FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
          UNIQUE(student_id, session_date)
        )
      ''');

      // إنشاء جدول pending_operations إذا لم يكن موجوداً
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_operations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          operation_type TEXT NOT NULL,
          table_name TEXT NOT NULL,
          operation TEXT NOT NULL,
          data TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          retry_count INTEGER DEFAULT 0,
          synced INTEGER DEFAULT 0
        )
      ''');
    }
  }

  Future<void> initialize() async {
    await database;
  }

  Future<Database> getDB() async {
    return await database;
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
