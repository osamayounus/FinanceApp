import 'dart:io';

import 'package:financeapp/models/profile_entry.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const int kMaxProfiles = 3;

/// Manages the list of user profiles stored in a dedicated `profiles.db`.
/// Each profile maps to its own finance database file (`finance_N.db`).
/// Max [kMaxProfiles] profiles per device.
class ProfileManager {
  static final ProfileManager instance = ProfileManager._();
  ProfileManager._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _openDB();
    return _db!;
  }

  Future<Database> _openDB() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'profiles.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE profiles (
            id   INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// The finance DB filename for a given profile ID.
  String dbFileFor(int profileId) => 'finance_$profileId.db';

  // ── Profiles ──────────────────────────────────────────────────────────────

  Future<List<ProfileEntry>> getProfiles() async {
    final db = await _database;
    final rows = await db.query('profiles', orderBy: 'id ASC');
    return rows
        .map((r) =>
            ProfileEntry(id: r['id'] as int, name: r['name'] as String))
        .toList();
  }

  Future<ProfileEntry> createProfile(String name) async {
    if ((await getProfiles()).length >= kMaxProfiles) {
      throw StateError('Profile limit reached ($kMaxProfiles)');
    }
    final db = await _database;
    final id = await db.insert('profiles', {'name': name});
    return ProfileEntry(id: id, name: name);
  }

  /// Deletes the profile entry and its associated database file.
  Future<void> deleteProfile(int id) async {
    final db = await _database;
    await db.delete('profiles', where: 'id = ?', whereArgs: [id]);
    if (await getActiveProfileId() == id) await clearActiveProfile();
    final dbPath = await getDatabasesPath();
    final file = File(join(dbPath, dbFileFor(id)));
    if (await file.exists()) await file.delete();
  }

  // ── Active profile ────────────────────────────────────────────────────────

  Future<int?> getActiveProfileId() async {
    final db = await _database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['active_profile_id'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return int.tryParse(rows.first['value'] as String);
  }

  Future<void> setActiveProfileId(int id) async {
    final db = await _database;
    await db.insert(
      'settings',
      {'key': 'active_profile_id', 'value': id.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearActiveProfile() async {
    final db = await _database;
    await db.delete('settings',
        where: 'key = ?', whereArgs: ['active_profile_id']);
  }

  // ── Device-wide tutorial flags ────────────────────────────────────────────

  /// Returns true if the tutorial with [key] has already been shown on this
  /// device.  Stored in profiles.db so it persists across profile switches.
  Future<bool> hasTutorialSeen(String key) async {
    final db = await _database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['tut_$key'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> markTutorialSeen(String key) async {
    final db = await _database;
    await db.insert(
      'settings',
      {'key': 'tut_$key', 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Migration ─────────────────────────────────────────────────────────────

  /// If a legacy single-user `finance.db` exists but no profiles are registered,
  /// creates a "User 1" profile and renames the file to `finance_1.db`.
  Future<void> migrateIfNeeded() async {
    final dbPath = await getDatabasesPath();
    final legacyFile = File(join(dbPath, 'finance.db'));

    final profiles = await getProfiles();
    if (profiles.isEmpty && await legacyFile.exists()) {
      final profile = await createProfile('User 1');
      await legacyFile.rename(join(dbPath, dbFileFor(profile.id)));
      await setActiveProfileId(profile.id);
    }
  }
}
