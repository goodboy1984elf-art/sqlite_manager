// lib/features/db_manager/db_manager_screen.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/db_repository.dart';
import '../../core/models/database_model.dart';
import '../shared/widgets/password_dialog.dart';
import '../shared/widgets/confirm_dialog.dart';

class DbManagerScreen extends ConsumerWidget {
  const DbManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final databases = ref.watch(openDatabasesProvider);
    final repo = ref.watch(dbRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.storage, size: 22),
            SizedBox(width: 8),
            Text('SQLite Manager'),
          ],
        ),
      ),
      body: databases.isEmpty
          ? _EmptyState(onAdd: () => _addDatabase(context, ref))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: databases.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _DbCard(
                db: databases[i],
                isConnected: repo.isConnected(databases[i].id),
                onTap: () => _openDatabase(context, ref, databases[i]),
                onDelete: () => _deleteDatabase(context, ref, databases[i]),
                onEncrypt: () =>
                    _encryptDatabase(context, ref, databases[i]),
                onDecrypt: () =>
                    _decryptDatabase(context, ref, databases[i]),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDatabase(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Open Database'),
      ),
    );
  }

  Future<void> _addDatabase(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    await ref.read(openDatabasesProvider.notifier).addDatabase(path);
  }

  Future<void> _openDatabase(
    BuildContext context,
    WidgetRef ref,
    DatabaseModel db,
  ) async {
    final repo = ref.read(dbRepositoryProvider);

    if (!repo.isConnected(db.id)) {
      if (db.isEncrypted) {
        final password = await showPasswordDialog(context, title: 'Enter Password');
        if (password == null || !context.mounted) return;
        try {
          repo.openConnection(db, password: password);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
          return;
        }
      } else {
        repo.openConnection(db);
      }
    }

    if (context.mounted) {
      context.push('/db/${db.id}/tables');
    }
  }

  Future<void> _deleteDatabase(
    BuildContext context,
    WidgetRef ref,
    DatabaseModel db,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove Database',
      message:
          'Remove "${db.name}" from the list?\n\nThis will NOT delete the file.',
    );
    if (confirmed != true) return;
    await ref.read(openDatabasesProvider.notifier).removeDatabase(db);
  }

  Future<void> _encryptDatabase(
    BuildContext context,
    WidgetRef ref,
    DatabaseModel db,
  ) async {
    final password =
        await showPasswordDialog(context, title: 'Set Encryption Password', confirmPassword: true);
    if (password == null) return;
    try {
      await ref
          .read(openDatabasesProvider.notifier)
          .encryptDatabase(db, password);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database encrypted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Encryption failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _decryptDatabase(
    BuildContext context,
    WidgetRef ref,
    DatabaseModel db,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove Encryption',
      message: 'This will remove encryption from "${db.name}". Continue?',
      destructive: true,
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(openDatabasesProvider.notifier)
          .decryptDatabase(db);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database decrypted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Decryption failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ── Empty state ────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storage_outlined,
              size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No databases yet',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Open a local .db or .sqlite file to get started',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.folder_open),
            label: const Text('Open Database File'),
          ),
        ],
      ),
    );
  }
}

// ── Database card ──────────────────────────────────────────────────

class _DbCard extends StatelessWidget {
  final DatabaseModel db;
  final bool isConnected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEncrypt;
  final VoidCallback onDecrypt;

  const _DbCard({
    required this.db,
    required this.isConnected,
    required this.onTap,
    required this.onDelete,
    required this.onEncrypt,
    required this.onDecrypt,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('yyyy-MM-dd HH:mm');

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.storage, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            db.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (db.isEncrypted) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.lock, size: 14, color: Colors.amber.shade700),
                        ],
                        if (isConnected) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      db.path,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Added ${fmt.format(db.addedAt)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              // Actions menu
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'encrypt') onEncrypt();
                  if (v == 'decrypt') onDecrypt();
                  if (v == 'remove') onDelete();
                },
                itemBuilder: (_) => [
                  if (!db.isEncrypted)
                    const PopupMenuItem(
                      value: 'encrypt',
                      child: Row(children: [
                        Icon(Icons.lock_outline, size: 18),
                        SizedBox(width: 8),
                        Text('Encrypt'),
                      ]),
                    ),
                  if (db.isEncrypted)
                    const PopupMenuItem(
                      value: 'decrypt',
                      child: Row(children: [
                        Icon(Icons.lock_open, size: 18),
                        SizedBox(width: 8),
                        Text('Decrypt'),
                      ]),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(children: [
                      Icon(Icons.remove_circle_outline,
                          size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Remove', style: TextStyle(color: Colors.red)),
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
