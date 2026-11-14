// lib/services/sqlite_service.dart
// Handles local SQLite persistence and offline queue management.

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/doctor.dart';
import '../models/patient.dart';

class SqliteService {
  static final SqliteService _instance = SqliteService._internal();
  factory SqliteService() => _instance;
  SqliteService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'clinic_app.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Doctors table
    await db.execute('''
      CREATE TABLE doctors (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        specialization TEXT NOT NULL,
        phone TEXT,
        isActive INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL
      )
    ''');

    // Patients table
    await db.execute('''
      CREATE TABLE patients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        gender TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        doctorId TEXT NOT NULL,
        doctorName TEXT NOT NULL,
        serialNumber INTEGER NOT NULL,
        visitDate TEXT NOT NULL,
        complaint TEXT,
        diagnosis TEXT,
        addedByStaff TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Serial number counters: tracks last serial per (doctorId, date)
    await db.execute('''
      CREATE TABLE serial_counters (
        doctorId TEXT NOT NULL,
        visitDate TEXT NOT NULL,
        lastSerial INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (doctorId, visitDate)
      )
    ''');
  }

  // ─── Doctor operations ───────────────────────────────────────────────────

  Future<void> upsertDoctor(Doctor doctor) async {
    final db = await database;
    await db.insert(
      'doctors',
      doctor.toSqlite(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteDoctor(String id) async {
    final db = await database;
    await db.delete('doctors', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Doctor>> getAllDoctors() async {
    final db = await database;
    final rows = await db.query('doctors', orderBy: 'name ASC');
    return rows.map(Doctor.fromMap).toList();
  }

  Future<List<Doctor>> getActiveDoctors() async {
    final db = await database;
    final rows = await db.query(
      'doctors',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return rows.map(Doctor.fromMap).toList();
  }

  // ─── Patient operations ──────────────────────────────────────────────────

  Future<void> upsertPatient(Patient patient) async {
    final db = await database;
    await db.insert(
      'patients',
      patient.toSqlite(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePatient(String id) async {
    final db = await database;
    await db.delete('patients', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Patient>> getAllPatients() async {
    final db = await database;
    final rows = await db.query('patients', orderBy: 'createdAt DESC');
    return rows.map(Patient.fromMap).toList();
  }

  Future<List<Patient>> getPatientsByDoctorAndDate(
      String doctorId, String date) async {
    final db = await database;
    final rows = await db.query(
      'patients',
      where: 'doctorId = ? AND visitDate = ?',
      whereArgs: [doctorId, date],
      orderBy: 'serialNumber ASC',
    );
    return rows.map(Patient.fromMap).toList();
  }

  Future<List<Patient>> getUnsyncedPatients() async {
    final db = await database;
    final rows = await db.query(
      'patients',
      where: 'isSynced = ?',
      whereArgs: [0],
    );
    return rows.map(Patient.fromMap).toList();
  }

  Future<void> markPatientSynced(String id) async {
    final db = await database;
    await db.update(
      'patients',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── Serial number management ────────────────────────────────────────────

  /// Returns the next serial number for a given doctor+date combination.
  /// Uses a local counter table so serial numbers stay consistent offline.
  Future<int> getNextSerial(String doctorId, String date) async {
    final db = await database;

    // Try to get existing counter
    final rows = await db.query(
      'serial_counters',
      where: 'doctorId = ? AND visitDate = ?',
      whereArgs: [doctorId, date],
    );

    if (rows.isEmpty) {
      // First patient for this doctor+date combo
      await db.insert('serial_counters', {
        'doctorId': doctorId,
        'visitDate': date,
        'lastSerial': 1,
      });
      return 1;
    } else {
      final last = rows.first['lastSerial'] as int;
      final next = last + 1;
      await db.update(
        'serial_counters',
        {'lastSerial': next},
        where: 'doctorId = ? AND visitDate = ?',
        whereArgs: [doctorId, date],
      );
      return next;
    }
  }

  /// Syncs serial counter from Firestore (call after fetching remote patients).
  Future<void> syncSerialCounter(
      String doctorId, String date, int maxSerial) async {
    final db = await database;
    await db.insert(
      'serial_counters',
      {
        'doctorId': doctorId,
        'visitDate': date,
        'lastSerial': maxSerial,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) await db.close();
  }
}

