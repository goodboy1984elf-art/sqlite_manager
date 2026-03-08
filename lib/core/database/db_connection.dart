// lib/core/database/db_connection.dart
import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/database_model.dart';

/// Manages raw SQLite connections.
/// Supports both plain SQLite and SQLCipher (encrypted) databases.
class DbConnection {
  Database? _db;
  final DatabaseModel model;
  String? _currentPassword;

  DbConnection(this.model);

  bool get isOpen => _db != null;

  // ── Open ─────────────────────────────────────────────────────

  /// Opens a plain (unencrypted) database.
  void open() {
    _assertClosed();
    _configureNativeLibrary();
    _db = sqlite3.open(model.path);
    _applyPragmas();
  }

  /// Opens an encrypted database with SQLCipher.
  void openEncrypted(String password) {
    _assertClosed();
    _configureSqlCipher();
    _db = sqlite3.open(model.path);
    _db!.execute("PRAGMA key = '${_escape(password)}';");
    // Verify key is correct by running a simple query
    try {
      _db!.execute('SELECT count(*) FROM sqlite_master;');
    } catch (_) {
      _db!.dispose();
      _db = null;
      throw const DbException('Invalid password or database is not encrypted.');
    }
    _currentPassword = password;
    _applyPragmas();
  }

  // ── Encryption management ─────────────────────────────────────

  /// Encrypts a plain database (adds SQLCipher encryption).
  void encrypt(String password) {
    _assertOpen();
    _db!.execute("PRAGMA rekey = '${_escape(password)}';");
    _currentPassword = password;
  }

  /// Removes encryption from a database (makes it plain).
  void decrypt() {
    _assertOpen();
    _db!.execute("PRAGMA rekey = '';");
    _currentPassword = null;
  }

  /// Changes the encryption password.
  void changePassword(String newPassword) {
    _assertOpen();
    _db!.execute("PRAGMA rekey = '${_escape(newPassword)}';");
    _currentPassword = newPassword;
  }

  // ── Schema queries ────────────────────────────────────────────

  List<String> getTables() {
    _assertOpen();
    final result = _db!.select(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;",
    );
    return result.map((r) => r['name'] as String).toList();
  }

  List<ColumnModel> getColumns(String table) {
    _assertOpen();
    final result = _db!.select('PRAGMA table_info("$table");');
    return result.map(ColumnModel.fromPragma).toList();
  }

  int getRowCount(String table) {
    _assertOpen();
    final result = _db!.select('SELECT COUNT(*) as c FROM "$table";');
    return result.first['c'] as int;
  }

  // ── Data queries ──────────────────────────────────────────────

  QueryResult selectRows(
    String table, {
    int limit = 100,
    int offset = 0,
    String? orderBy,
  }) {
    _assertOpen();
    final sw = Stopwatch()..start();
    try {
      final order = orderBy != null ? ' ORDER BY $orderBy' : '';
      final sql =
          'SELECT * FROM "$table"$order LIMIT $limit OFFSET $offset;';
      final result = _db!.select(sql);
      sw.stop();
      return QueryResult(
        columns: result.isEmpty ? [] : result.first.keys.toList(),
        rows: result.map((r) => Map<String, dynamic>.from(r)).toList(),
        executionTime: sw.elapsed,
      );
    } catch (e) {
      sw.stop();
      return QueryResult.error(e.toString(), sw.elapsed);
    }
  }

  QueryResult executeRaw(String sql) {
    _assertOpen();
    final sw = Stopwatch()..start();
    try {
      final upperSql = sql.trim().toUpperCase();
      if (upperSql.startsWith('SELECT') ||
          upperSql.startsWith('PRAGMA') ||
          upperSql.startsWith('WITH')) {
        final result = _db!.select(sql);
        sw.stop();
        return QueryResult(
          columns: result.isEmpty ? [] : result.first.keys.toList(),
          rows: result.map((r) => Map<String, dynamic>.from(r)).toList(),
          executionTime: sw.elapsed,
        );
      } else {
        _db!.execute(sql);
        sw.stop();
        return QueryResult(
          columns: [],
          rows: [],
          affectedRows: _db!.updatedRows,
          executionTime: sw.elapsed,
        );
      }
    } catch (e) {
      sw.stop();
      return QueryResult.error(e.toString(), sw.elapsed);
    }
  }

  // ── CRUD ──────────────────────────────────────────────────────

  void insertRow(String table, Map<String, dynamic> values) {
    _assertOpen();
    final cols = values.keys.map((c) => '"$c"').join(', ');
    final placeholders = List.filled(values.length, '?').join(', ');
    final stmt = _db!.prepare(
      'INSERT INTO "$table" ($cols) VALUES ($placeholders);',
    );
    stmt.execute(values.values.toList());
    stmt.dispose();
  }

  void updateRow(
    String table,
    Map<String, dynamic> values,
    String pkColumn,
    dynamic pkValue,
  ) {
    _assertOpen();
    final sets = values.keys.map((c) => '"$c" = ?').join(', ');
    final stmt = _db!.prepare(
      'UPDATE "$table" SET $sets WHERE "$pkColumn" = ?;',
    );
    stmt.execute([...values.values, pkValue]);
    stmt.dispose();
  }

  void deleteRow(String table, String pkColumn, dynamic pkValue) {
    _assertOpen();
    final stmt =
        _db!.prepare('DELETE FROM "$table" WHERE "$pkColumn" = ?;');
    stmt.execute([pkValue]);
    stmt.dispose();
  }

  // ── Table management ──────────────────────────────────────────

  void createTable(String table, List<ColumnDefinition> columns) {
    _assertOpen();
    final colDefs = columns.map((c) => c.toSql()).join(', ');
    _db!.execute('CREATE TABLE IF NOT EXISTS "$table" ($colDefs);');
  }

  void dropTable(String table) {
    _assertOpen();
    _db!.execute('DROP TABLE IF EXISTS "$table";');
  }

  void renameTable(String oldName, String newName) {
    _assertOpen();
    _db!.execute('ALTER TABLE "$oldName" RENAME TO "$newName";');
  }

  // ── Lifecycle ─────────────────────────────────────────────────

  void close() {
    _db?.dispose();
    _db = null;
    _currentPassword = null;
  }

  // ── Private helpers ───────────────────────────────────────────

  void _assertOpen() {
    if (_db == null) throw const DbException('Database is not open.');
  }

  void _assertClosed() {
    if (_db != null) throw const DbException('Database is already open.');
  }

  void _applyPragmas() {
    _db!.execute('PRAGMA journal_mode=WAL;');
    _db!.execute('PRAGMA foreign_keys=ON;');
  }

  String _escape(String s) => s.replaceAll("'", "''");

  void _configureNativeLibrary() {
    if (Platform.isAndroid) {
      open.overrideFor(OperatingSystem.android, () {
        return DynamicLibrary.open('libsqlite3.so');
      });
    }
  }

  void _configureSqlCipher() {
    if (Platform.isAndroid) {
      open.overrideFor(OperatingSystem.android, () {
        return DynamicLibrary.open('libsqlcipher.so');
      });
    } else if (Platform.isIOS) {
      open.overrideFor(OperatingSystem.iOS, DynamicLibrary.process);
    } else if (Platform.isMacOS) {
      open.overrideFor(OperatingSystem.macOS, DynamicLibrary.process);
    } else if (Platform.isWindows) {
      open.overrideFor(OperatingSystem.windows, () {
        return DynamicLibrary.open('sqlcipher.dll');
      });
    }
  }
}

// ── Column definition helper ──────────────────────────────────────

class ColumnDefinition {
  final String name;
  final String type;
  final bool primaryKey;
  final bool autoIncrement;
  final bool notNull;
  final bool unique;
  final dynamic defaultValue;

  const ColumnDefinition({
    required this.name,
    required this.type,
    this.primaryKey = false,
    this.autoIncrement = false,
    this.notNull = false,
    this.unique = false,
    this.defaultValue,
  });

  String toSql() {
    final sb = StringBuffer('"$name" $type');
    if (primaryKey) sb.write(' PRIMARY KEY');
    if (autoIncrement) sb.write(' AUTOINCREMENT');
    if (notNull) sb.write(' NOT NULL');
    if (unique) sb.write(' UNIQUE');
    if (defaultValue != null) {
      final val = defaultValue is String ? "'$defaultValue'" : '$defaultValue';
      sb.write(' DEFAULT $val');
    }
    return sb.toString();
  }
}

// ── Exception ──────────────────────────────────────────────────────

class DbException implements Exception {
  final String message;
  const DbException(this.message);

  @override
  String toString() => 'DbException: $message';
}
