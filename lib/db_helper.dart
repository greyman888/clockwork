import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DbHelper {
  static Database? _db;
  final String dbName;
  final int dbVersion;

  DbHelper({this.dbName = 'clockwork.db', this.dbVersion = 1 });

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<String> _resolveDbDir() async {
    // Preferred: app support dir
    try {
      final supportDir = await getApplicationSupportDirectory();
      final dbDir = supportDir.path;
      // final dbDir = path.join(supportDir.path, 'databases');
      await Directory(dbDir).create(recursive: true);
      return dbDir;
    } catch (_) {
      // Fallback: whatever sqflite considers the DB directory
      final dbDir = await getDatabasesPath();
      await Directory(dbDir).create(recursive: true);
      return dbDir;
    }
  }

  Future<Database> _initDb() async {
    final dbDir = await _resolveDbDir();
    final dbPath = path.join(dbDir, dbName);

    print('DB dir:   $dbDir');
    print('DB path:  $dbPath');

    return openDatabase(
      dbPath,
      version: dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // the entity_kinds table stores the entity meta properties
    // the entities table stores the entity instances
    // the comp_kinds table stores the types of components
    // the {sqltype}_comps tables store the component values by sql type
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS entity_kinds (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          name          TEXT NOT NULL UNIQUE,
          display_name  TEXT NOT NULL,
          status        INTEGER DEFAULT 1,
          comp_kinds    TEXT  -- comma-separated comp_kinds.id values
        )
      ''');

      await txn.execute('''
        CREATE TABLE IF NOT EXISTS entities (
          id       INTEGER PRIMARY KEY AUTOINCREMENT,
          kind_id  INTEGER NOT NULL REFERENCES entity_kinds(id),
          status   INTEGER DEFAULT 1
        )
      ''');

      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_entity_kind_id ON entities (kind_id)
      ''');

      await txn.execute('''
        CREATE TABLE IF NOT EXISTS comp_kinds (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          name          TEXT NOT NULL UNIQUE,
          display_name  TEXT NOT NULL,
          storage_type  TEXT NOT NULL, -- 'integer', 'real', 'text', 'entity'
          status        INTEGER DEFAULT 1
        )
      ''');

      const columnTypes = [
        ('integer', 'INTEGER'),
        ('real',    'REAL'),
        ('text',    'TEXT'),
        ('entity',  'INTEGER')
      ];
      for (final (typeName, sqlType) in columnTypes) {
        final table = '${typeName}_comps';

        await txn.execute('''
          CREATE TABLE IF NOT EXISTS $table (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_id INTEGER NOT NULL REFERENCES entities(id),
            kind_id   INTEGER NOT NULL REFERENCES comp_kinds(id),
            value     $sqlType NOT NULL,

            UNIQUE (entity_id, kind_id)
          )
        ''');

        await txn.execute('''
          CREATE INDEX IF NOT EXISTS idx_${typeName}_kind_id ON $table (kind_id)
        ''');

        await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_${typeName}_entity_id ON $table (entity_id)
        ''');

        // 3. Optional: Add a covering index for the most common pattern
        //    (entity + specific component type) — only if you do this query very often
        // await txn.execute('''
        //   CREATE INDEX IF NOT EXISTS idx_${typeName}_entity_kind ON $table (entity_id, kind_id)
        // ''');
      }
    });
  }

// === CRUD ===

  Future<int> createCompKind({
    required String name, 
    required String displayName, 
    required String storageType, 
    int status = 1
  }) async {
    final database = await db;

    try {
      return await database.insert(
        'comp_kinds',
        {
          'name': name, 
          'display_name': displayName, 
          'storage_type': storageType, 
          'status': status
        },
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()){
        throw Exception('Component kind with name "$name" already exists');
      }
      rethrow;
    }
  }

  Future<int> createEntityKind({
    required String name, 
    required String displayName, 
    required List<int> compKinds, 
    int status = 1
  }) async {
    final database = await db;

    try {
      final compKindsString = compKinds.join(',');

      return await database.insert(
        'entity_kinds',
        {
          'name': name, 
          'display_name': displayName, 
          'comp_kinds': compKindsString, 
          'status': status
        },
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()){
        throw Exception('Entity kind with name "$name" already exists');
      }
      rethrow;
    }
  }

  // Temp getAll
  Future<List<Map<String, dynamic>>> getAllEntities({bool includeInactive = false}) async {
    final database = await db;
    
    final result = await database.rawQuery('''
      SELECT 
        e.id          AS entity_id,
        e.kind_id     AS kind_id,
        ek.name       AS kind_name,
        ek.display_name AS kind_display_name,
        e.status      AS status
      FROM entities e
      INNER JOIN entity_kinds ek ON e.kind_id = ek.id
      ORDER BY e.id ASC
    ''');

    return result;
  }

  /// Returns all component kinds (optionally only active ones)
  /// Very fast: uses high-level query(), minimal columns, index-friendly
  Future<List<Map<String, dynamic>>> getAllCompKinds({
    bool includeInactive = false,
  }) async {
    final database = await db;

    return await database.query(
      'comp_kinds',
      columns: ['id', 'name', 'display_name', 'storage_type', 'status'],
      where: includeInactive ? null : 'status = ?',
      whereArgs: includeInactive ? null : [1],
      orderBy: 'name ASC',           // nice default sorting
    );
  }


  Future<void> close() async {
    final database = await db;
    await database.close();
    _db = null;
  }
}

// Global instance for easy access throughout the app
final dbHelper = DbHelper();