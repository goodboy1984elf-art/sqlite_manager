// lib/features/table_browser/table_browser_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/db_connection.dart';
import '../../core/database/db_repository.dart';
import '../../core/models/database_model.dart';

class TableBrowserScreen extends ConsumerStatefulWidget {
  final String dbId;
  final String tableName;

  const TableBrowserScreen({
    super.key,
    required this.dbId,
    required this.tableName,
  });

  @override
  ConsumerState<TableBrowserScreen> createState() =>
      _TableBrowserScreenState();
}

class _TableBrowserScreenState extends ConsumerState<TableBrowserScreen> {
  List<ColumnModel> _columns = [];
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  int _offset = 0;
  int _totalRows = 0;
  static const _pageSize = 100;

  String? get _pkColumn =>
      _columns.where((c) => c.isPrimaryKey).firstOrNull?.name ??
      (_columns.isNotEmpty ? _columns.first.name : null);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _loading = true);
    final conn = _conn;
    if (conn == null) return;
    _columns = conn.getColumns(widget.tableName);
    _totalRows = conn.getRowCount(widget.tableName);
    final result = conn.selectRows(
      widget.tableName,
      limit: _pageSize,
      offset: _offset,
    );
    setState(() {
      _rows = result.rows;
      _loading = false;
    });
  }

  DbConnection? get _conn =>
      ref.read(dbRepositoryProvider).getConnection(widget.dbId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tableName),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Insert Row',
            onPressed: () => _showRowDialog(context, null),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats bar
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.4),
                  child: Row(
                    children: [
                      Text(
                        '$_totalRows rows · ${_columns.length} columns',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        'Showing ${_offset + 1}–${(_offset + _rows.length).clamp(0, _totalRows)} of $_totalRows',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                // Data grid
                Expanded(
                  child: _rows.isEmpty
                      ? const Center(child: Text('No rows in this table'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columnSpacing: 16,
                              headingRowColor: WidgetStateProperty.all(
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withOpacity(0.5),
                              ),
                              columns: [
                                ..._columns.map(
                                  (c) => DataColumn(
                                    label: Row(
                                      children: [
                                        if (c.isPrimaryKey)
                                          const Padding(
                                            padding:
                                                EdgeInsets.only(right: 4),
                                            child: Icon(Icons.key,
                                                size: 12,
                                                color: Colors.amber),
                                          ),
                                        Text(c.name,
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.w600)),
                                        const SizedBox(width: 4),
                                        Text(
                                          c.type.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade500,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const DataColumn(label: Text('Actions')),
                              ],
                              rows: _rows.map((row) {
                                return DataRow(
                                  cells: [
                                    ..._columns.map(
                                      (c) => DataCell(
                                        Text(
                                          '${row[c.name] ?? 'NULL'}',
                                          style: row[c.name] == null
                                              ? const TextStyle(
                                                  color: Colors.grey,
                                                  fontStyle:
                                                      FontStyle.italic)
                                              : null,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onTap: () => _showRowDialog(
                                            context, row),
                                      ),
                                    ),
                                    DataCell(Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              size: 16),
                                          onPressed: () =>
                                              _showRowDialog(context, row),
                                          tooltip: 'Edit',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              size: 16,
                                              color: Colors.red),
                                          onPressed: () =>
                                              _deleteRow(row),
                                          tooltip: 'Delete',
                                        ),
                                      ],
                                    )),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                ),
                // Pagination
                if (_totalRows > _pageSize)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _offset > 0
                              ? () {
                                  _offset =
                                      (_offset - _pageSize).clamp(0, _totalRows);
                                  _load();
                                }
                              : null,
                        ),
                        Text(
                            'Page ${(_offset ~/ _pageSize) + 1} / ${((_totalRows - 1) ~/ _pageSize) + 1}'),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed:
                              _offset + _pageSize < _totalRows
                                  ? () {
                                      _offset += _pageSize;
                                      _load();
                                    }
                                  : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _showRowDialog(
      BuildContext context, Map<String, dynamic>? existingRow) async {
    await showDialog(
      context: context,
      builder: (_) => _RowEditDialog(
        columns: _columns,
        existingRow: existingRow,
        onSave: (values) {
          final conn = _conn;
          if (conn == null) return;
          if (existingRow == null) {
            // Insert
            conn.insertRow(widget.tableName, values);
          } else {
            // Update
            final pk = _pkColumn;
            if (pk != null) {
              conn.updateRow(
                  widget.tableName, values, pk, existingRow[pk]);
            }
          }
          _load();
        },
      ),
    );
  }

  void _deleteRow(Map<String, dynamic> row) {
    final pk = _pkColumn;
    if (pk == null) return;
    final conn = _conn;
    conn?.deleteRow(widget.tableName, pk, row[pk]);
    _load();
  }
}

// ── Row edit dialog ────────────────────────────────────────────────

class _RowEditDialog extends StatefulWidget {
  final List<ColumnModel> columns;
  final Map<String, dynamic>? existingRow;
  final void Function(Map<String, dynamic> values) onSave;

  const _RowEditDialog({
    required this.columns,
    required this.existingRow,
    required this.onSave,
  });

  @override
  State<_RowEditDialog> createState() => _RowEditDialogState();
}

class _RowEditDialogState extends State<_RowEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final col in widget.columns)
        col.name: TextEditingController(
          text: widget.existingRow?[col.name]?.toString() ?? '',
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingRow != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Row' : 'Insert Row'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.columns.map((col) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _controllers[col.name],
                    decoration: InputDecoration(
                      labelText: col.name,
                      helperText:
                          '${col.type}${col.isPrimaryKey ? ' · PK' : ''}${col.notNull ? ' · NOT NULL' : ''}',
                    ),
                    validator: (v) {
                      if (col.notNull &&
                          !col.isPrimaryKey &&
                          (v == null || v.isEmpty)) {
                        return '${col.name} cannot be null';
                      }
                      return null;
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final values = {
              for (final col in widget.columns)
                if (_controllers[col.name]!.text.isNotEmpty ||
                    col.notNull)
                  col.name: _controllers[col.name]!.text,
            };
            widget.onSave(values);
            Navigator.of(context).pop();
          },
          child: Text(isEdit ? 'Save' : 'Insert'),
        ),
      ],
    );
  }
}
