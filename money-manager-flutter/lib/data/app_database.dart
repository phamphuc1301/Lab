import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// Registers the native sqflite factory used on Android/iOS.
// ignore: unnecessary_import
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/budget.dart';
import '../models/transaction.dart';

/// Local SQLite storage. On Windows/Linux/macOS it uses the FFI implementation of sqflite.
class AppDatabase {
  AppDatabase._(this._db, this.directory);

  final Database _db;

  /// App data folder; receipt images are copied into `<directory>/receipts`.
  final String directory;

  /// [directory] overrides the app data folder (used by tests).
  static Future<AppDatabase> open({String? directory}) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = directory ?? (await getApplicationSupportDirectory()).path;
    final db = await openDatabase(
      p.join(dir, 'money_manager.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount_minor INTEGER NOT NULL,
            kind TEXT NOT NULL,
            category TEXT NOT NULL,
            merchant TEXT NOT NULL DEFAULT '',
            note TEXT NOT NULL DEFAULT '',
            date INTEGER NOT NULL,
            receipt_path TEXT
          )''');
        await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
        await db.execute('''
          CREATE TABLE budgets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            scope_key TEXT NOT NULL UNIQUE,
            limit_minor INTEGER NOT NULL,
            warn_threshold REAL NOT NULL
          )''');
        await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      },
    );
    return AppDatabase._(db, dir);
  }

  Future<List<MoneyTransaction>> transactions() async =>
      (await _db.query('transactions', orderBy: 'date DESC')).map(MoneyTransaction.fromMap).toList();

  Future<void> saveTransaction(MoneyTransaction t) async {
    final map = t.toMap()..remove('id');
    if (t.id == null) {
      await _db.insert('transactions', map);
    } else {
      await _db.update('transactions', map, where: 'id = ?', whereArgs: [t.id]);
    }
  }

  Future<void> deleteTransaction(int id) => _db.delete('transactions', where: 'id = ?', whereArgs: [id]);

  Future<List<Budget>> budgets() async => (await _db.query('budgets')).map(Budget.fromMap).toList();

  Future<void> saveBudget(Budget b) async {
    final map = b.toMap()..remove('id');
    if (b.id == null) {
      await _db.insert('budgets', map, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await _db.update('budgets', map, where: 'id = ?', whereArgs: [b.id]);
    }
  }

  Future<void> deleteBudget(int id) => _db.delete('budgets', where: 'id = ?', whereArgs: [id]);

  Future<String?> setting(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) =>
      _db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
}
