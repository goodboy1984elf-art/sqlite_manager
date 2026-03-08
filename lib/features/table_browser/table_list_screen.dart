// lib/features/table_browser/table_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/db_connection.dart';
import '../../core/database/db_repository.dart';
import '../../core/models/database_model.dart';
import '../shared/widgets/confirm_dialog.dart';

class TableListScreen extends ConsumerStatefulWidget {
  final String dbId;
  const TableListScreen({super.key, required this.dbId});

  @override
  ConsumerState<TableListScreen> createState() => _TableListScreenState();
}

class _TableListScreenState extends ConsumerState<TableListScreen> {
  List<_TableInfo> _tables = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  void _loadTables() {
    setState(() => _loading = true);
    final conn = ref.read(dbRepositoryProvider).getConnection(widget.dbId);
    if (conn == null) {
      setState(() => _loading = false);
      return;
    }
    final names = conn.getTables();
    final infos = names.map((name) {
      final count = conn.getRowCount(name);
      final cols = conn.getColumns(name);
      return _TableInfo(name: name, rowCount: count, columnCount: cols.length);
    }).toList();
    setState(() {
      _tables = infos;
      _loading = false;
    });
  }

  DatabaseModel? get _db {
    final dbs = ref.read(openDatabasesProvider);
    return dbs.where((d) => d.id == widget.dbId).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final db = _db;

    return Scaffold(
      appBar: AppBar(
        title: Text(db?.name ?? 'Tables'),
        actions: [
          IconButton(
            icon: const Icon(Icons.terminal),
            tooltip: 'Query Editor',
            onPressed: () => context.push('/db/${widget.dbId}/query'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTables,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tables.isEmpty
              ? _EmptyTables(
                  onCreate: () => _goCreateTable(),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tables.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _TableCard(
                    info: _tables[i],
                    onTap: () => context.push(
                        '/db/${widget.dbId}/table/${_tables[i].name}'),
                    onDrop: () => _dropTable(_tables[i].name),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goCreateTable,
        icon: const Icon(Icons.add),
        label: const Text('New Table'),
      ),
    );
  }

  void _goCreateTable() {
    context.push('/db/${widget.dbId}/create-table').then((_) => _loadTables());
  }

  Future<void> _dropTable(String name) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Drop Table',
      message: 'Drop table "$name"? All data will be lost.',
      destructive: true,
    );
    if (confirmed != true) return;
    final conn = ref.read(dbRepositoryProvider).getConnection(widget.dbId);
    conn?.dropTable(name);
    _loadTables();
  }
}

class _TableInfo {
  final String name;
  final int rowCount;
  final int columnCount;
  _TableInfo(
      {required this.name,
      required this.rowCount,
      required this.columnCount});
}

class _TableCard extends StatelessWidget {
  final _TableInfo info;
  final VoidCallback onTap;
  final VoidCallback onDrop;

  const _TableCard(
      {required this.info, required this.onTap, required this.onDrop});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(Icons.table_chart, color: cs.onSecondaryContainer, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      '${info.rowCount} rows · ${info.columnCount} columns',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'drop') onDrop();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'drop',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Drop Table', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTables extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyTables({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.table_chart_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No tables found',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Create your first table to get started',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create Table'),
          ),
        ],
      ),
    );
  }
}
