import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'db_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // === Support Desktop Setup setup ===
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Trigger database open early (fast and guarantees it's ready)
  await dbHelper.db;

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
        return MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Database Demo')),
            body: Center(child: Text('CompKind ID')),
            floatingActionButton: FloatingActionButton(
              onPressed: () async {
                // await dbHelper.createEntityKind(
                //   name: 'project',
                //   displayName: 'Project',
                //   compKinds: [1],
                // );
                final compKinds = await dbHelper.getAllCompKinds();
                print('compKinds in DB: $compKinds');
              },
              child: const Icon(Icons.pets),
            ),
          ),
        );
  }
}