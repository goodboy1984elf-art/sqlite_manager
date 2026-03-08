// lib/features/query_editor/query_editor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/db_repository.dart';
import '../../core/models/database_model.dart';

class QueryEditorScreen extends ConsumerStatefulWidget {
  final String dbId;
  const QueryEditorScreen({super.key, required this.dbId});

  @override
  ConsumerState<QueryEditorScreen> createState() =>
      _QueryEditorScreenState();
}

class _QueryEditorScreenState extends ConsumerState<QueryEditorScreen> {
  final _controller = TextEditingController();
  QueryResult? _result;
  bool _running = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Query Editor'),
        actions: [
          FilledButton.icon(
            onPressed: _running ? null : _runQuery,
            icon: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow),
            label: const Text('Run'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Editor
          SizedBox(
            height: 180,
            child: Container(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity(0.3),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                  hintText: 'SELECT * FROM table_name LIMIT 100;',
                ),
              ),
            ),
          ),
          // Quick templates
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _chip('SELECT *', 'SELECT * FROM table_name LIMIT 100;'),
                _chip('INSERT', "INSERT INTO table_name (col) VALUES ('value');"),
                _chip('UPDATE', "UPDATE table_name SET col = 'value' WHERE id = 1;"),
                _chip('DELETE', 'DELETE FROM table_name WHERE id = 1;'),
                _chip('Table Info', 'PRAGMA table_info(table_name);'),
                _chip('Indexes', 'PRAGMA index_list(table_name);'),
              ],
            ),
          ),
          const Divider(height: 1),
          // Results
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _chip(String label, String sql) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: () {
          _controller.text = sql;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: sql.length),
          );
        },
      ),
    );
  }

  Widget _buildResults() {
    if (_result == null) {
      return const Center(
        child: Text(
          'Run a query to see results',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (_result!.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _result!.error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_result!.rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 48, color: Colors.green),
            const SizedBox(height: 8),
            Text(
              _result!.affectedRows != null
                  ? '${_result!.affectedRows} row(s) affected'
                  : 'Query executed successfully',
            ),
            Text(
              'Completed in ${_result!.executionTime.inMilliseconds}ms',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            '${_result!.rows.length} rows · ${_result!.executionTime.inMilliseconds}ms',
            style:
                const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 16,
                columns: _result!.columns
                    .map((c) => DataColumn(
                          label: Text(c,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ))
                    .toList(),
                rows: _result!.rows
                    .map(
                      (row) => DataRow(
                        cells: _result!.columns
                            .map((c) => DataCell(
                                  Text('${row[c] ?? 'NULL'}',
                                      style: row[c] == null
                                          ? const TextStyle(
                                              color: Colors.grey,
                                              fontStyle: FontStyle.italic)
                                          : null),
                                ))
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _runQuery() {
    final sql = _controller.text.trim();
    if (sql.isEmpty) return;
    setState(() => _running = true);

    final conn =
        ref.read(dbRepositoryProvider).getConnection(widget.dbId);
    if (conn == null) {
      setState(() => _running = false);
      return;
    }

    final result = conn.executeRaw(sql);
    setState(() {
      _result = result;
      _running = false;
    });
  }
}
