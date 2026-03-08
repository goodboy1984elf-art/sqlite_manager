// lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/db_manager/db_manager_screen.dart';
import 'features/table_browser/table_browser_screen.dart';
import 'features/table_browser/table_list_screen.dart';
import 'features/table_manager/create_table_screen.dart';
import 'features/query_editor/query_editor_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const DbManagerScreen(),
    ),
    GoRoute(
      path: '/db/:dbId/tables',
      builder: (_, state) => TableListScreen(
        dbId: state.pathParameters['dbId']!,
      ),
    ),
    GoRoute(
      path: '/db/:dbId/table/:tableName',
      builder: (_, state) => TableBrowserScreen(
        dbId: state.pathParameters['dbId']!,
        tableName: state.pathParameters['tableName']!,
      ),
    ),
    GoRoute(
      path: '/db/:dbId/create-table',
      builder: (_, state) => CreateTableScreen(
        dbId: state.pathParameters['dbId']!,
      ),
    ),
    GoRoute(
      path: '/db/:dbId/query',
      builder: (_, state) => QueryEditorScreen(
        dbId: state.pathParameters['dbId']!,
      ),
    ),
  ],
  errorBuilder: (_, state) => Scaffold(
    body: Center(child: Text('Page not found: ${state.error}')),
  ),
);
