// test/integration/sqlite_file_test.dart
//
// Run with: flutter test test/integration/ -d linux
//
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:sqlite_manager/core/database/db_connection.dart';
import 'package:sqlite_manager/core/models/database_model.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sqlite_integration_');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  DatabaseModel _model(String name) => DatabaseModel(
        id: const Uuid().v4(),
        name: name,
        path: p.join(tempDir.path, '$name.db'),
        addedAt: DateTime.now(),
      );

  group('File persistence', () {
    test('database file is created on disk', () {
      final model = _model('persistence_test');
      final conn = DbConnection(model);
      conn.open();
      conn.createTable('t', [ColumnDefinition(name: 'id', type: 'INTEGER')]);
      conn.close();

      expect(File(model.path).existsSync(), true);
    });

    test('data persists across open/close cycles', () {
      final model = _model('data_persist');
      var conn = DbConnection(model);
      conn.open();
      conn.createTable('kv', [
        ColumnDefinition(name: 'k', type: 'TEXT'),
        ColumnDefinition(name: 'v', type: 'TEXT'),
      ]);
      conn.insertRow('kv', {'k': 'hello', 'v': 'world'});
      conn.close();

      // Re-open
      conn = DbConnection(model);
      conn.open();
      final result = conn.selectRows('kv');
      expect(result.rows.length, 1);
      expect(result.rows.first['v'], 'world');
      conn.close();
    });

    test('multiple databases can be open simultaneously', () {
      final m1 = _model('multi_1');
      final m2 = _model('multi_2');

      final c1 = DbConnection(m1)..open();
      final c2 = DbConnection(m2)..open();

      c1.createTable('t', [ColumnDefinition(name: 'n', type: 'INTEGER')]);
      c2.createTable('t', [ColumnDefinition(name: 'n', type: 'INTEGER')]);

      c1.insertRow('t', {'n': 100});
      c2.insertRow('t', {'n': 200});

      expect(c1.selectRows('t').rows.first['n'], 100);
      expect(c2.selectRows('t').rows.first['n'], 200);

      c1.close();
      c2.close();
    });
  });

  group('Large data', () {
    test('handles 10,000 row inserts', () {
      final model = _model('large_data');
      final conn = DbConnection(model);
      conn.open();
      conn.createTable('big', [
        ColumnDefinition(
            name: 'id',
            type: 'INTEGER',
            primaryKey: true,
            autoIncrement: true),
        ColumnDefinition(name: 'val', type: 'TEXT'),
      ]);

      conn.executeRaw('BEGIN TRANSACTION;');
      for (var i = 0; i < 10000; i++) {
        conn.insertRow('big', {'val': 'item_$i'});
      }
      conn.executeRaw('COMMIT;');

      expect(conn.getRowCount('big'), 10000);

      final page = conn.selectRows('big', limit: 50, offset: 100);
      expect(page.rows.length, 50);
      conn.close();
    });
  });

  group('Schema operations', () {
    test('column metadata is accurate', () {
      final model = _model('schema_test');
      final conn = DbConnection(model);
      conn.open();

      conn.createTable('schema_table', [
        ColumnDefinition(
            name: 'id',
            type: 'INTEGER',
            primaryKey: true,
            autoIncrement: true),
        ColumnDefinition(name: 'title', type: 'TEXT', notNull: true),
        ColumnDefinition(name: 'score', type: 'REAL'),
      ]);

      final cols = conn.getColumns('schema_table');
      expect(cols.length, 3);
      expect(cols.first.name, 'id');
      expect(cols.first.isPrimaryKey, true);
      expect(cols[1].notNull, true);
      conn.close();
    });

    test('rename table works', () {
      final model = _model('rename_test');
      final conn = DbConnection(model);
      conn.open();

      conn.createTable('old_name', [
        ColumnDefinition(name: 'id', type: 'INTEGER'),
      ]);
      conn.renameTable('old_name', 'new_name');

      final tables = conn.getTables();
      expect(tables, contains('new_name'));
      expect(tables, isNot(contains('old_name')));
      conn.close();
    });
  });
}
