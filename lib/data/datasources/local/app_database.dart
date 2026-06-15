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
      version: 5,
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

    await db.execute('''
  CREATE TABLE payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL,
    amount REAL NOT NULL,
    payment_date TEXT NOT NULL,
    payment_type TEXT NOT NULL,
    month INTEGER,
    year INTEGER,
    is_extra INTEGER DEFAULT 0,
    extra_reason TEXT,
    is_gifted INTEGER DEFAULT 0,
    notes TEXT,
    is_partial INTEGER DEFAULT 0,
    parent_payment_id INTEGER,
    discount_months INTEGER,
    discount_percentage REAL,
    is_fully_paid INTEGER DEFAULT 0,
    target_month INTEGER,
    target_year INTEGER,
    remaining_amount REAL,
    prepaid_months INTEGER,
    prepaid_start_month INTEGER,
    prepaid_end_month INTEGER,
    FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
  )
''');

    // أضف في دالة _createTables:
    await db.execute('''
  CREATE TABLE specialties (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL
  )
''');

    // في دالة _createTables، أضف:
    await db.execute('''
  CREATE TABLE competitions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    location TEXT,
    specialty_ids TEXT,
    age_categories TEXT,
    notes TEXT
  )
''');

    await db.execute('''
  CREATE TABLE participations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    competition_id INTEGER NOT NULL,
    student_id INTEGER NOT NULL,
    specialty_id INTEGER NOT NULL,
    age_category TEXT NOT NULL,
    weight_category REAL NOT NULL,
    result TEXT NOT NULL,
    rank INTEGER,
    medal_type TEXT,
    notes TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (competition_id) REFERENCES competitions (id) ON DELETE CASCADE,
    FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
  )
''');

    await db.execute('''
  CREATE TABLE belts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL,
    belt_color TEXT NOT NULL,
    date_achieved TEXT NOT NULL,
    coach_name TEXT,
    notes TEXT,
    order_index INTEGER NOT NULL,
    FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
  )
''');

    // جدول القاعات
    await db.execute('''
  CREATE TABLE halls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    address TEXT,
    phone TEXT
  )
''');

    // جدول الأفواج
    await db.execute('''
  CREATE TABLE groups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hall_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    student_count INTEGER DEFAULT 0,
    FOREIGN KEY (hall_id) REFERENCES halls (id) ON DELETE CASCADE
  )
''');

    // جدول الحصص
    await db.execute('''
  CREATE TABLE sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id INTEGER NOT NULL,
    day_of_week INTEGER NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL,
    FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
  )
''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 ترقية قاعدة البيانات من الإصدار $oldVersion إلى $newVersion');

    if (oldVersion < 2) {
      // إضافة جدول attendances (كان في الإصدار 2)
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
    }

    if (oldVersion < 3) {
      // إضافة الأعمدة الجديدة لجدول payments (الإصدار 3)
      try {
        // قائمة الأعمدة المطلوب إضافتها
        final columnsToAdd = [
          'is_partial INTEGER DEFAULT 0',
          'parent_payment_id INTEGER',
          'discount_months INTEGER',
          'discount_percentage REAL',
          'is_fully_paid INTEGER DEFAULT 0',
          'target_month INTEGER',
          'target_year INTEGER',
          'remaining_amount REAL',
        ];

        for (var column in columnsToAdd) {
          try {
            await db.execute('ALTER TABLE payments ADD COLUMN $column');
            print('✅ تم إضافة العمود: $column');
          } catch (e) {
            print('⚠️ العمود موجود مسبقاً أو خطأ: $column - $e');
          }
        }
      } catch (e) {
        print('⚠️ جدول payments غير موجود: $e');
      }
    }

    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE payments ADD COLUMN notes TEXT');
      } catch (e) {
        print('⚠️ عمود notes موجود مسبقاً');
      }
    }

    if (oldVersion < 3) {
      try {
        await db.execute(
          'ALTER TABLE payments ADD COLUMN prepaid_months INTEGER',
        );
        await db.execute(
          'ALTER TABLE payments ADD COLUMN prepaid_start_month INTEGER',
        );
        await db.execute(
          'ALTER TABLE payments ADD COLUMN prepaid_end_month INTEGER',
        );
      } catch (e) {
        print('⚠️ الأعمدة موجودة مسبقاً');
      }
    }

    if (oldVersion < 4) {
      try {
        await db.execute('''
      CREATE TABLE IF NOT EXISTS belts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        belt_color TEXT NOT NULL,
        date_achieved TEXT NOT NULL,
        coach_name TEXT,
        notes TEXT,
        order_index INTEGER NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');
      } catch (e) {
        print('⚠️ جدول belts موجود مسبقاً');
      }
    }

    if (oldVersion < 5) {
      try {
        await db.execute('''
      CREATE TABLE IF NOT EXISTS halls (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        phone TEXT
      )
    ''');

        await db.execute('''
      CREATE TABLE IF NOT EXISTS groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hall_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        student_count INTEGER DEFAULT 0,
        FOREIGN KEY (hall_id) REFERENCES halls (id) ON DELETE CASCADE
      )
    ''');

        await db.execute('''
      CREATE TABLE IF NOT EXISTS sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id INTEGER NOT NULL,
        day_of_week INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
      )
    ''');

        print('✅ تم إنشاء جداول القاعات والأفواج والحصص');
      } catch (e) {
        print('⚠️ خطأ في إنشاء الجداول: $e');
      }
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
