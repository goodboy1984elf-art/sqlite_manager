// lib/features/table_manager/create_table_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/db_connection.dart';
import '../../core/database/db_repository.dart';

class CreateTableScreen extends ConsumerStatefulWidget {
  final String dbId;
  const CreateTableScreen({super.key, required this.dbId});

  @override
  ConsumerState<CreateTableScreen> createState() =>
      _CreateTableScreenState();
}

class _CreateTableScreenState extends ConsumerState<CreateTableScreen> {
  final _tableNameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final List<_ColDef> _columns = [
    _ColDef(
        name: 'id',
        type: 'INTEGER',
        primaryKey: true,
        autoIncrement: true),
  ];

  static const _sqlTypes = [
    'INTEGER',
    'TEXT',
    'REAL',
    'BLOB',
    'NUMERIC',
  ];

  @override
  void dispose() {
    _tableNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Table'),
        actions: [
          FilledButton(
            onPressed: _createTable,
            child: const Text('Create'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Table name
            TextFormField(
              controller: _tableNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Table Name',
                hintText: 'e.g. users',
                prefixIcon: Icon(Icons.table_chart),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Table name is required';
                }
                if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(v)) {
                  return 'Only letters, numbers and underscores';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            // Columns header
            Row(
              children: [
                Text('Columns',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addColumn,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Column'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Column list
            ..._columns.asMap().entries.map((entry) {
              final i = entry.key;
              final col = entry.value;
              return _ColumnEditor(
                key: ValueKey(col.id),
                col: col,
                sqlTypes: _sqlTypes,
                canDelete: _columns.length > 1,
                onChanged: (updated) =>
                    setState(() => _columns[i] = updated),
                onDelete: () =>
                    setState(() => _columns.removeAt(i)),
              );
            }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _addColumn() {
    setState(() {
      _columns.add(_ColDef(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '',
        type: 'TEXT',
      ));
    });
  }

  void _createTable() {
    if (!_formKey.currentState!.validate()) return;

    // Validate columns
    for (final col in _columns) {
      if (col.name.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All columns must have a name')),
        );
        return;
      }
    }

    final conn = ref.read(dbRepositoryProvider).getConnection(widget.dbId);
    if (conn == null) return;

    try {
      conn.createTable(
        _tableNameCtrl.text.trim(),
        _columns
            .map((c) => ColumnDefinition(
                  name: c.name.trim(),
                  type: c.type,
                  primaryKey: c.primaryKey,
                  autoIncrement: c.autoIncrement,
                  notNull: c.notNull,
                  unique: c.unique,
                ))
            .toList(),
      );
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Table "${_tableNameCtrl.text}" created successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// ── Column editor row ──────────────────────────────────────────────

class _ColDef {
  final String id;
  String name;
  String type;
  bool primaryKey;
  bool autoIncrement;
  bool notNull;
  bool unique;

  _ColDef({
    String? id,
    required this.name,
    required this.type,
    this.primaryKey = false,
    this.autoIncrement = false,
    this.notNull = false,
    this.unique = false,
  }) : id = id ?? name + DateTime.now().millisecondsSinceEpoch.toString();

  _ColDef copyWith({
    String? name,
    String? type,
    bool? primaryKey,
    bool? autoIncrement,
    bool? notNull,
    bool? unique,
  }) =>
      _ColDef(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        primaryKey: primaryKey ?? this.primaryKey,
        autoIncrement: autoIncrement ?? this.autoIncrement,
        notNull: notNull ?? this.notNull,
        unique: unique ?? this.unique,
      );
}

class _ColumnEditor extends StatelessWidget {
  final _ColDef col;
  final List<String> sqlTypes;
  final bool canDelete;
  final void Function(_ColDef updated) onChanged;
  final VoidCallback onDelete;

  const _ColumnEditor({
    super.key,
    required this.col,
    required this.sqlTypes,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Column name
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: col.name,
                    decoration: const InputDecoration(
                        labelText: 'Column Name', isDense: true),
                    onChanged: (v) => onChanged(col.copyWith(name: v)),
                  ),
                ),
                const SizedBox(width: 8),
                // Type selector
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: col.type,
                    decoration: const InputDecoration(
                        labelText: 'Type', isDense: true),
                    items: sqlTypes
                        .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onChanged(col.copyWith(type: v));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (canDelete)
                  IconButton(
                    icon:
                        const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: onDelete,
                    tooltip: 'Remove column',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [
                FilterChip(
                  label: const Text('PK'),
                  selected: col.primaryKey,
                  onSelected: (v) => onChanged(col.copyWith(primaryKey: v)),
                ),
                FilterChip(
                  label: const Text('Auto Increment'),
                  selected: col.autoIncrement,
                  onSelected: col.primaryKey
                      ? (v) => onChanged(col.copyWith(autoIncrement: v))
                      : null,
                ),
                FilterChip(
                  label: const Text('NOT NULL'),
                  selected: col.notNull,
                  onSelected: (v) => onChanged(col.copyWith(notNull: v)),
                ),
                FilterChip(
                  label: const Text('UNIQUE'),
                  selected: col.unique,
                  onSelected: (v) => onChanged(col.copyWith(unique: v)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
