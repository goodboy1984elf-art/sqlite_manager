// lib/core/database/db_repository.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/database_model.dart';
import 'db_connection.dart';

// ── Providers ─────────────────────────────────────────────────────

final dbRepositoryProvider = Provider<DbRepository>((ref) {
  return DbRepository();
});

final openDatabasesProvider =
    StateNotifierProvider<OpenDatabasesNotifier, List<DatabaseModel>>(
  (ref) => OpenDatabasesNotifier(ref.watch(dbRepositoryProvider)),
);

final activeDatabaseProvider = StateProvider<DatabaseModel?>((ref) => null);

// ── Repository ────────────────────────────────────────────────────

class DbRepository {
  final Map<String, DbConnection> _connections = {};
  static const _uuid = Uuid();

  // ── Persistence ───────────────────────────────────────────────

  Future<List<DatabaseModel>> loadSavedDatabases() async {
    final file = await _registryFile();
    if (!await file.exists()) return [];
    final json = jsonDecode(await file.readAsString()) as List;
    return json
        .map((e) => DatabaseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveDatabases(List<DatabaseModel> dbs) async {
    final file = await _registryFile();
    await file.writeAsString(
      jsonEncode(dbs.map((d) => d.toJson()).toList()),
    );
  }

  Future<File> _registryFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'sqlite_manager', 'registry.json'));
  }

  // ── Add / Remove ──────────────────────────────────────────────

  Future<DatabaseModel> addDatabase(String filePath) async {
    final dbs = await loadSavedDatabases();
    final existing = dbs.where((d) => d.path == filePath).firstOrNull;
    if (existing != null) return existing;

    final model = DatabaseModel(
      id: _uuid.v4(),
      name: p.basenameWithoutExtension(filePath),
      path: filePath,
      addedAt: DateTime.now(),
    );

    await _saveDatabases([...dbs, model]);
    return model;
  }

  Future<void> removeDatabase(DatabaseModel db) async {
    closeConnection(db.id);
    final dbs = await loadSavedDatabases();
    await _saveDatabases(dbs.where((d) => d.id != db.id).toList());
  }

  // ── Connection management ─────────────────────────────────────

  DbConnection openConnection(DatabaseModel model, {String? password}) {
    if (_connections.containsKey(model.id)) {
      return _connections[model.id]!;
    }

    final conn = DbConnection(model);
    if (password != null) {
      conn.openEncrypted(password);
    } else {
      conn.open();
    }
    _connections[model.id] = conn;
    return conn;
  }

  void closeConnection(String dbId) {
    _connections[dbId]?.close();
    _connections.remove(dbId);
  }

  DbConnection? getConnection(String dbId) => _connections[dbId];

  bool isConnected(String dbId) => _connections.containsKey(dbId);

  // ── Encryption ────────────────────────────────────────────────

  Future<void> encryptDatabase(
    DatabaseModel model,
    String password,
    List<DatabaseModel> allDbs,
  ) async {
    final conn = getConnection(model.id);
    if (conn == null) throw const DbException('Database is not open.');
    conn.encrypt(password);

    final updated = model.copyWith(isEncrypted: true);
    final newList =
        allDbs.map((d) => d.id == model.id ? updated : d).toList();
    await _saveDatabases(newList);
  }

  Future<void> decryptDatabase(
    DatabaseModel model,
    List<DatabaseModel> allDbs,
  ) async {
    final conn = getConnection(model.id);
    if (conn == null) throw const DbException('Database is not open.');
    conn.decrypt();

    final updated = model.copyWith(isEncrypted: false);
    final newList =
        allDbs.map((d) => d.id == model.id ? updated : d).toList();
    await _saveDatabases(newList);
  }

  void dispose() {
    for (final conn in _connections.values) {
      conn.close();
    }
    _connections.clear();
  }
}

// ── StateNotifier ─────────────────────────────────────────────────

class OpenDatabasesNotifier extends StateNotifier<List<DatabaseModel>> {
  final DbRepository _repo;

  OpenDatabasesNotifier(this._repo) : super([]) {
    _load();
  }

  Future<void> _load() async {
    state = await _repo.loadSavedDatabases();
  }

  Future<DatabaseModel> addDatabase(String path) async {
    final model = await _repo.addDatabase(path);
    state = [...state, model];
    return model;
  }

  Future<void> removeDatabase(DatabaseModel db) async {
    await _repo.removeDatabase(db);
    state = state.where((d) => d.id != db.id).toList();
  }

  Future<void> encryptDatabase(DatabaseModel model, String password) async {
    await _repo.encryptDatabase(model, password, state);
    state = state
        .map((d) => d.id == model.id ? model.copyWith(isEncrypted: true) : d)
        .toList();
  }

  Future<void> decryptDatabase(DatabaseModel model) async {
    await _repo.decryptDatabase(model, state);
    state = state
        .map((d) => d.id == model.id ? model.copyWith(isEncrypted: false) : d)
        .toList();
  }
}
