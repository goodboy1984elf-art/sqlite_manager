// test/unit/db_connection_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3/open.dart';
import 'package:uuid/uuid.dart';

import 'package:sqlite_manager/core/database/db_connection.dart';
import 'package:sqlite_manager/core/models/database_model.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sqlite_test_');
    dbPath = p.join(tempDir.path, 'test.db');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  DatabaseModel _makeModel({bool encrypted = false}) => DatabaseModel(
        id: const Uuid().v4(),
        name: 'test',
        path: dbPath,
        isEncrypted: encrypted,
        addedAt: DateTime.now(),
      );

  group('DbConnection - Basic Operations', () {
    test('opens and closes a database', () {
      final conn = DbConnection(_makeModel());
      conn.open();
      expect(conn.isOpen, true);
      conn.close();
      expect(conn.isOpen, false);
    });

    test('creates and retrieves tables', () {
      final conn = DbConnection(_makeModel());
      conn.open();

      conn.createTable('users', [
        ColumnDefinition(
            name: 'id',
            type: 'INTEGER',
            primaryKey: true,
            autoIncrement: true),
        ColumnDefinition(name: 'name', type: 'TEXT', notNull: true),
        ColumnDefinition(name: 'email', type: 'TEXT', unique: true),
      ]);

      final tables = conn.getTables();
      expect(tables, contains('users'));
      conn.close();
    });

    test('inserts and selects rows', () {
      final conn = DbConnection(_makeModel());
      conn.open();

      conn.createTable('products', [
        ColumnDefinition(
            name: 'id',
            type: 'INTEGER',
            primaryKey: true,
            autoIncrement: true),
        ColumnDefinition(name: 'name', type: 'TEXT'),
        ColumnDefinition(name: 'price', type: 'REAL'),
      ]);

      conn.insertRow('products', {'name': 'Apple', 'price': 1.5});
      conn.insertRow('products', {'name': 'Banana', 'price': 0.5});

      final result = conn.selectRows('products');
      expect(result.isSuccess, true);
      expect(result.rows.length, 2);
      expect(result.rows.first['name'], 'Apple');
      conn.close();
    });

    test('updates a row', () {
      final conn = DbConnection(_makeModel());
      conn.open();

      conn.createTable('items', [
        ColumnDefinition(
            name: 'id',
            type: 'INTEGER',
            primaryKey: true,
            autoIncrement: true),
        ColumnDefinition(name: 'value', type: 'TEXT'),
      ]);

      conn.insertRow('items', {'value': 'original'});
      conn.updateRow('items', {'value': 'updated'}, 'id', 1);

      final result = conn.selectRows('items');
      expect(result.rows.first['value'], 'updated');
      conn.close();
    });

    test('deletes a row', () {
      final conn = DbConnection(_makeModel());
      conn.open();

      conn.createTable('logs', [
        ColumnDefinition(
            name: 'id',
            type: 'INTEGER',
            primaryKey: true,
            autoIncrement: true),
        ColumnDefinition(name: 'msg', type: 'TEXT'),
      ]);

      conn.insertRow('logs', {'msg': 'hello'});
      conn.insertRow('logs', {'msg': 'world'});
      conn.deleteRow('logs', 'id', 1);

      expect(conn.getRowCount('logs'), 1);
      conn.close();
    });

    test('drops a table', () {
      final conn = DbConnection(_makeModel());
      conn.open();

      conn.createTable('temp_table', [
        ColumnDefinition(name: 'id', type: 'INTEGER'),
      ]);
      expect(conn.getTables(), contains('temp_table'));

      conn.dropTable('temp_table');
      expect(conn.getTables(), isNot(contains('temp_table')));
      conn.close();
    });

    test('executes raw SELECT query', () {
      final conn = DbConnection(_makeModel());
      conn.open();

      conn.createTable('nums', [
        ColumnDefinition(name: 'n', type: 'INTEGER'),
      ]);
      for (var i = 1; i <= 5; i++) {
        conn.insertRow('nums', {'n': i});
      }

      final result = conn.executeRaw('SELECT SUM(n) as total FROM nums;');
      expect(result.isSuccess, true);
      expect(result.rows.first['total'], 15);
      conn.close();
    });

    test('returns error result for invalid SQL', () {
      final conn = DbConnection(_makeModel());
      conn.open();

      final result = conn.executeRaw('SELECT * FROM nonexistent_table;');
      expect(result.isSuccess, false);
      expect(result.error, isNotNull);
      conn.close();
    });
  });

  group('DbConnection - Pagination', () {
    test('paginates rows correctly', () {
      final conn = DbConnection(_makeModel());
      conn.open();

      conn.createTable('data', [
        ColumnDefinition(
            name: 'id',
            type: 'INTEGER',
            primaryKey: true,
            autoIncrement: true),
      ]);

      for (var i = 0; i < 50; i++) {
        conn.insertRow('data', {});
      }

      final page1 = conn.selectRows('data', limit: 10, offset: 0);
      final page2 = conn.selectRows('data', limit: 10, offset: 10);

      expect(page1.rows.length, 10);
      expect(page2.rows.length, 10);
      expect(page1.rows.first['id'], isNot(equals(page2.rows.first['id'])));
      conn.close();
    });
  });
}
