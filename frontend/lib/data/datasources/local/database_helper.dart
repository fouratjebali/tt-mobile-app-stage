import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();

    return openDatabase(
      join(dbPath, 'tt_mail.db'),
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE emails(
      id TEXT PRIMARY KEY,
      threadId TEXT,
      subject TEXT,
      sender TEXT,
      senderEmail TEXT,
      recipients TEXT,
      body TEXT,
      date TEXT,
      status TEXT,
      attachments TEXT,
      analysis TEXT,
      jury TEXT,
      isRead INTEGER DEFAULT 0
    )
  ''');
  }
}