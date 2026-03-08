// lib/core/models/database_model.dart

/// Represents a managed SQLite database connection
class DatabaseModel {
  final String id;
  final String name;
  final String path;
  final bool isEncrypted;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;

  const DatabaseModel({
    required this.id,
    required this.name,
    required this.path,
    this.isEncrypted = false,
    required this.addedAt,
    this.lastOpenedAt,
  });

  DatabaseModel copyWith({
    String? name,
    bool? isEncrypted,
    DateTime? lastOpenedAt,
  }) {
    return DatabaseModel(
      id: id,
      name: name ?? this.name,
      path: path,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      addedAt: addedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'isEncrypted': isEncrypted,
        'addedAt': addedAt.toIso8601String(),
        'lastOpenedAt': lastOpenedAt?.toIso8601String(),
      };

  factory DatabaseModel.fromJson(Map<String, dynamic> json) => DatabaseModel(
        id: json['id'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
        isEncrypted: json['isEncrypted'] as bool? ?? false,
        addedAt: DateTime.parse(json['addedAt'] as String),
        lastOpenedAt: json['lastOpenedAt'] != null
            ? DateTime.parse(json['lastOpenedAt'] as String)
            : null,
      );
}

/// Represents a table inside a SQLite database
class TableModel {
  final String name;
  final List<ColumnModel> columns;
  final int rowCount;

  const TableModel({
    required this.name,
    required this.columns,
    this.rowCount = 0,
  });
}

/// Represents a column definition
class ColumnModel {
  final int cid;
  final String name;
  final String type;
  final bool notNull;
  final dynamic defaultValue;
  final bool isPrimaryKey;

  const ColumnModel({
    required this.cid,
    required this.name,
    required this.type,
    this.notNull = false,
    this.defaultValue,
    this.isPrimaryKey = false,
  });

  factory ColumnModel.fromPragma(Map<String, dynamic> row) => ColumnModel(
        cid: row['cid'] as int,
        name: row['name'] as String,
        type: row['type'] as String,
        notNull: (row['notnull'] as int) == 1,
        defaultValue: row['dflt_value'],
        isPrimaryKey: (row['pk'] as int) > 0,
      );
}

/// Result of a query operation
class QueryResult {
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final int? affectedRows;
  final String? error;
  final Duration executionTime;

  const QueryResult({
    required this.columns,
    required this.rows,
    this.affectedRows,
    this.error,
    required this.executionTime,
  });

  bool get isSuccess => error == null;

  factory QueryResult.error(String message, Duration elapsed) => QueryResult(
        columns: [],
        rows: [],
        error: message,
        executionTime: elapsed,
      );
}
