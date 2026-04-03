import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DbHelper {
  DbHelper({this.dbName = 'clockwork.db', this.databaseDirectory});

  static const int _schemaVersion = 2;

  Database? _db;

  static const int activeStatus = 1;
  static const int deletedStatus = 0;

  static const String storageInteger = 'integer';
  static const String storageReal = 'real';
  static const String storageText = 'text';
  static const String storageEntity = 'entity';

  static const String semanticPlain = 'plain';
  static const String semanticDate = 'date';
  static const String semanticBoolean = 'boolean';
  static const String semanticEnum = 'enum';
  static const String semanticCurrency = 'currency';
  static const String semanticEntityReference = 'entity_reference';

  static const Set<String> _storageTypes = {
    storageInteger,
    storageReal,
    storageText,
    storageEntity,
  };

  static const Map<String, String> _componentTables = {
    storageInteger: 'integer_comps',
    storageReal: 'real_comps',
    storageText: 'text_comps',
    storageEntity: 'entity_comps',
  };

  final String dbName;
  final String? databaseDirectory;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<String> _resolveDbDir() async {
    if (databaseDirectory != null) {
      await Directory(databaseDirectory!).create(recursive: true);
      return databaseDirectory!;
    }

    try {
      final supportDir = await getApplicationSupportDirectory();
      await Directory(supportDir.path).create(recursive: true);
      return supportDir.path;
    } catch (_) {
      final dbDir = await getDatabasesPath();
      await Directory(dbDir).create(recursive: true);
      return dbDir;
    }
  }

  Future<Database> _initDb() async {
    final dbDir = await _resolveDbDir();
    final dbPath = path.join(dbDir, dbName);

    developer.log('DB dir: $dbDir', name: 'DbHelper');
    developer.log('DB path: $dbPath', name: 'DbHelper');

    return openDatabase(
      dbPath,
      version: _schemaVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      await _createDefinitionTables(txn);
      await _createEntityTables(txn);
      await _createComponentTables(txn);
    });
  }

  Future<void> _createDefinitionTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS entity_kinds (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT NOT NULL UNIQUE,
        display_name  TEXT NOT NULL,
        status        INTEGER NOT NULL DEFAULT 1 CHECK(status IN (0, 1))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS comp_kinds (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        name           TEXT NOT NULL UNIQUE,
        display_name   TEXT NOT NULL,
        storage_type   TEXT NOT NULL
                       CHECK(storage_type IN ('integer', 'real', 'text', 'entity')),
        semantic_type  TEXT NOT NULL DEFAULT 'plain',
        status         INTEGER NOT NULL DEFAULT 1 CHECK(status IN (0, 1))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS entity_kind_comp_kinds (
        entity_kind_id  INTEGER NOT NULL
                        REFERENCES entity_kinds(id) ON DELETE CASCADE,
        comp_kind_id    INTEGER NOT NULL
                        REFERENCES comp_kinds(id) ON DELETE CASCADE,
        PRIMARY KEY (entity_kind_id, comp_kind_id)
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entity_kind_comp_kind_id
      ON entity_kind_comp_kinds (comp_kind_id)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS comp_kind_enum_options (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        comp_kind_id   INTEGER NOT NULL
                       REFERENCES comp_kinds(id) ON DELETE CASCADE,
        value          TEXT NOT NULL,
        display_label  TEXT NOT NULL,
        sort_order     INTEGER NOT NULL DEFAULT 0,
        UNIQUE (comp_kind_id, value)
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_enum_options_kind_sort
      ON comp_kind_enum_options (comp_kind_id, sort_order, id)
    ''');
  }

  Future<void> _createEntityTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS entities (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        kind_id  INTEGER NOT NULL
                 REFERENCES entity_kinds(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entities_kind_id
      ON entities (kind_id)
    ''');
  }

  Future<void> _createComponentTables(DatabaseExecutor db) async {
    for (final entry in _componentTables.entries) {
      final storageType = entry.key;
      final tableName = entry.value;

      final valueColumn = switch (storageType) {
        storageInteger => 'value INTEGER NOT NULL',
        storageReal => 'value REAL NOT NULL',
        storageText => 'value TEXT NOT NULL',
        storageEntity =>
          'value INTEGER NOT NULL REFERENCES entities(id) ON DELETE RESTRICT',
        _ => throw StateError('Unsupported storage type: $storageType'),
      };

      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableName (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_id  INTEGER NOT NULL
                     REFERENCES entities(id) ON DELETE CASCADE,
          kind_id    INTEGER NOT NULL
                     REFERENCES comp_kinds(id) ON DELETE RESTRICT,
          $valueColumn,
          UNIQUE (entity_id, kind_id)
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_${tableName}_kind_id
        ON $tableName (kind_id)
      ''');
    }

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entity_comps_value
      ON entity_comps (value)
    ''');
  }

  Future<int> createCompKind({
    required String name,
    required String displayName,
    required String storageType,
    String? semanticType,
    int status = activeStatus,
  }) async {
    final database = await db;
    final normalizedName = _normalizeRequiredText(name, 'Component kind name');
    final normalizedDisplayName = _normalizeRequiredText(
      displayName,
      'Component kind display name',
    );
    final normalizedStorageType = _normalizeStorageType(storageType);
    final resolvedSemanticType = _resolveSemanticType(
      normalizedStorageType,
      semanticType,
    );
    final normalizedStatus = _normalizeStatus(status);

    _ensureSemanticTypeIsCompatible(
      normalizedStorageType,
      resolvedSemanticType,
    );

    try {
      return await database.insert('comp_kinds', {
        'name': normalizedName,
        'display_name': normalizedDisplayName,
        'storage_type': normalizedStorageType,
        'semantic_type': resolvedSemanticType,
        'status': normalizedStatus,
      }, conflictAlgorithm: ConflictAlgorithm.fail);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw Exception(
          'Component kind with name "$normalizedName" already exists.',
        );
      }
      rethrow;
    }
  }

  Future<void> updateCompKind({
    required int id,
    required String name,
    required String displayName,
    required String storageType,
    String? semanticType,
    int status = activeStatus,
  }) async {
    final database = await db;
    final normalizedName = _normalizeRequiredText(name, 'Component kind name');
    final normalizedDisplayName = _normalizeRequiredText(
      displayName,
      'Component kind display name',
    );
    final normalizedStorageType = _normalizeStorageType(storageType);
    final resolvedSemanticType = _resolveSemanticType(
      normalizedStorageType,
      semanticType,
    );
    final normalizedStatus = _normalizeStatus(status);

    _ensureSemanticTypeIsCompatible(
      normalizedStorageType,
      resolvedSemanticType,
    );

    try {
      await database.transaction((txn) async {
        final existing = await _requireCompKind(txn, id);
        final previousStorageType = existing['storage_type'] as String;

        if (previousStorageType != normalizedStorageType) {
          final hasStoredValues = await _compKindHasStoredValues(txn, id);
          if (hasStoredValues) {
            throw Exception(
              'Cannot change the storage type of a component kind that '
              'already has stored values.',
            );
          }
        }

        final updatedRows = await txn.update(
          'comp_kinds',
          {
            'name': normalizedName,
            'display_name': normalizedDisplayName,
            'storage_type': normalizedStorageType,
            'semantic_type': resolvedSemanticType,
            'status': normalizedStatus,
          },
          where: 'id = ?',
          whereArgs: [id],
        );

        if (updatedRows == 0) {
          throw Exception('Component kind $id could not be updated.');
        }

        if (resolvedSemanticType != semanticEnum) {
          await txn.delete(
            'comp_kind_enum_options',
            where: 'comp_kind_id = ?',
            whereArgs: [id],
          );
        }
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw Exception(
          'Component kind with name "$normalizedName" already exists.',
        );
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllCompKinds({
    bool includeInactive = false,
  }) async {
    final database = await db;

    final rows = await database.rawQuery('''
      SELECT
        ck.id,
        ck.name,
        ck.display_name,
        ck.storage_type,
        ck.semantic_type,
        ck.status,
        COUNT(eo.id) AS enum_option_count
      FROM comp_kinds ck
      LEFT JOIN comp_kind_enum_options eo ON eo.comp_kind_id = ck.id
      ${includeInactive ? '' : 'WHERE ck.status = 1'}
      GROUP BY ck.id
      ORDER BY ck.id ASC
    ''');

    return rows.map(Map<String, dynamic>.from).toList();
  }

  Future<Map<String, dynamic>?> getCompKind(int id) async {
    final database = await db;
    final rows = await database.query(
      'comp_kinds',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    final compKind = Map<String, dynamic>.from(rows.first);
    compKind['enum_options'] = await getEnumOptions(id);
    return compKind;
  }

  Future<void> softDeleteCompKind(int id) async {
    await _setDefinitionStatus(
      tableName: 'comp_kinds',
      definitionId: id,
      status: deletedStatus,
      label: 'Component kind',
    );
  }

  Future<void> restoreCompKind(int id) async {
    await _setDefinitionStatus(
      tableName: 'comp_kinds',
      definitionId: id,
      status: activeStatus,
      label: 'Component kind',
    );
  }

  Future<int> createEntityKind({
    required String name,
    required String displayName,
    List<int> compKindIds = const [],
    int status = activeStatus,
  }) async {
    final database = await db;
    final normalizedName = _normalizeRequiredText(name, 'Entity kind name');
    final normalizedDisplayName = _normalizeRequiredText(
      displayName,
      'Entity kind display name',
    );
    final normalizedStatus = _normalizeStatus(status);
    final normalizedCompKindIds = _normalizeIdList(
      compKindIds,
      'Component kind id',
    );

    try {
      return await database.transaction((txn) async {
        await _ensureCompKindsExist(txn, normalizedCompKindIds);

        final entityKindId = await txn.insert('entity_kinds', {
          'name': normalizedName,
          'display_name': normalizedDisplayName,
          'status': normalizedStatus,
        }, conflictAlgorithm: ConflictAlgorithm.fail);

        await _syncEntityKindCompKinds(
          txn,
          entityKindId: entityKindId,
          desiredCompKindIds: normalizedCompKindIds,
        );

        return entityKindId;
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw Exception(
          'Entity kind with name "$normalizedName" already exists.',
        );
      }
      rethrow;
    }
  }

  Future<void> updateEntityKind({
    required int id,
    required String name,
    required String displayName,
    List<int> compKindIds = const [],
    int status = activeStatus,
  }) async {
    final database = await db;
    final normalizedName = _normalizeRequiredText(name, 'Entity kind name');
    final normalizedDisplayName = _normalizeRequiredText(
      displayName,
      'Entity kind display name',
    );
    final normalizedStatus = _normalizeStatus(status);
    final normalizedCompKindIds = _normalizeIdList(
      compKindIds,
      'Component kind id',
    );

    try {
      await database.transaction((txn) async {
        await _requireEntityKind(txn, id);
        final currentCompKindIds = await _getLinkedCompKindIds(txn, id);
        final currentCompKindIdSet = currentCompKindIds.toSet();
        final requestedCompKindIdSet = normalizedCompKindIds.toSet();
        final addedCompKindIds =
            requestedCompKindIdSet.difference(currentCompKindIdSet).toList()
              ..sort();
        final preservedCompKindIds =
            requestedCompKindIdSet.intersection(currentCompKindIdSet).toList()
              ..sort();

        await _ensureCompKindsExist(
          txn,
          preservedCompKindIds,
          activeOnly: false,
        );
        await _ensureCompKindsExist(txn, addedCompKindIds);

        final updatedRows = await txn.update(
          'entity_kinds',
          {
            'name': normalizedName,
            'display_name': normalizedDisplayName,
            'status': normalizedStatus,
          },
          where: 'id = ?',
          whereArgs: [id],
        );

        if (updatedRows == 0) {
          throw Exception('Entity kind $id could not be updated.');
        }

        await _syncEntityKindCompKinds(
          txn,
          entityKindId: id,
          desiredCompKindIds: normalizedCompKindIds,
        );
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw Exception(
          'Entity kind with name "$normalizedName" already exists.',
        );
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllEntityKinds({
    bool includeInactive = false,
  }) async {
    final database = await db;
    final componentStatusFilter = includeInactive ? '' : 'AND ck.status = 1';

    final rows = await database.rawQuery('''
      SELECT
        ek.id,
        ek.name,
        ek.display_name,
        ek.status,
        COUNT(ck.id) AS comp_kind_count
      FROM entity_kinds ek
      LEFT JOIN entity_kind_comp_kinds ekck ON ekck.entity_kind_id = ek.id
      LEFT JOIN comp_kinds ck
        ON ck.id = ekck.comp_kind_id
       $componentStatusFilter
      ${includeInactive ? '' : 'WHERE ek.status = 1'}
      GROUP BY ek.id
      ORDER BY ek.id ASC
    ''');

    return rows.map(Map<String, dynamic>.from).toList();
  }

  Future<Map<String, dynamic>?> getEntityKind(
    int id, {
    bool includeInactiveCompKinds = false,
  }) async {
    final database = await db;
    final rows = await database.query(
      'entity_kinds',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    final entityKind = Map<String, dynamic>.from(rows.first);
    final compKinds = await getCompKindsForEntityKind(
      id,
      includeInactive: includeInactiveCompKinds,
    );

    entityKind['component_kinds'] = compKinds;
    entityKind['comp_kind_ids'] = compKinds
        .map((compKind) => compKind['id'] as int)
        .toList();

    return entityKind;
  }

  Future<List<Map<String, dynamic>>> getCompKindsForEntityKind(
    int entityKindId, {
    bool includeInactive = false,
  }) async {
    final database = await db;
    final statusFilter = includeInactive ? '' : 'AND ck.status = 1';

    final rows = await database.rawQuery(
      '''
      SELECT
        ck.id,
        ck.name,
        ck.display_name,
        ck.storage_type,
        ck.semantic_type,
        ck.status
      FROM entity_kind_comp_kinds ekck
      INNER JOIN comp_kinds ck ON ck.id = ekck.comp_kind_id
      WHERE ekck.entity_kind_id = ?
      $statusFilter
      ORDER BY ck.id ASC
    ''',
      [entityKindId],
    );

    return rows.map(Map<String, dynamic>.from).toList();
  }

  Future<void> softDeleteEntityKind(int id) async {
    await _setDefinitionStatus(
      tableName: 'entity_kinds',
      definitionId: id,
      status: deletedStatus,
      label: 'Entity kind',
    );
  }

  Future<void> restoreEntityKind(int id) async {
    await _setDefinitionStatus(
      tableName: 'entity_kinds',
      definitionId: id,
      status: activeStatus,
      label: 'Entity kind',
    );
  }

  Future<void> _setDefinitionStatus({
    required String tableName,
    required int definitionId,
    required int status,
    required String label,
  }) async {
    final database = await db;
    final normalizedStatus = _normalizeStatus(status);

    final updatedRows = await database.update(
      tableName,
      {'status': normalizedStatus},
      where: 'id = ?',
      whereArgs: [definitionId],
    );

    if (updatedRows == 0) {
      throw Exception('$label $definitionId was not found.');
    }
  }

  Future<int> createEnumOption({
    required int compKindId,
    required String value,
    required String displayLabel,
    int sortOrder = 0,
  }) async {
    final database = await db;
    final normalizedValue = _normalizeRequiredText(value, 'Enum option value');
    final normalizedDisplayLabel = _normalizeRequiredText(
      displayLabel,
      'Enum option display label',
    );
    final normalizedSortOrder = _normalizeSortOrder(sortOrder);

    try {
      return await database.transaction((txn) async {
        await _requireEnumCompKind(txn, compKindId);

        return txn.insert('comp_kind_enum_options', {
          'comp_kind_id': compKindId,
          'value': normalizedValue,
          'display_label': normalizedDisplayLabel,
          'sort_order': normalizedSortOrder,
        }, conflictAlgorithm: ConflictAlgorithm.fail);
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw Exception(
          'Enum option "$normalizedValue" already exists for component kind '
          '$compKindId.',
        );
      }
      rethrow;
    }
  }

  Future<void> updateEnumOption({
    required int optionId,
    required String value,
    required String displayLabel,
    required int sortOrder,
  }) async {
    final database = await db;
    final normalizedValue = _normalizeRequiredText(value, 'Enum option value');
    final normalizedDisplayLabel = _normalizeRequiredText(
      displayLabel,
      'Enum option display label',
    );
    final normalizedSortOrder = _normalizeSortOrder(sortOrder);

    try {
      await database.transaction((txn) async {
        final option = await _requireEnumOption(txn, optionId);
        final compKindId = option['comp_kind_id'] as int;
        final oldValue = option['value'] as String;

        await _requireEnumCompKind(txn, compKindId);

        final updatedRows = await txn.update(
          'comp_kind_enum_options',
          {
            'value': normalizedValue,
            'display_label': normalizedDisplayLabel,
            'sort_order': normalizedSortOrder,
          },
          where: 'id = ?',
          whereArgs: [optionId],
        );

        if (updatedRows == 0) {
          throw Exception('Enum option $optionId could not be updated.');
        }

        if (oldValue != normalizedValue) {
          await txn.update(
            'text_comps',
            {'value': normalizedValue},
            where: 'kind_id = ? AND value = ?',
            whereArgs: [compKindId, oldValue],
          );
        }
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw Exception(
          'Enum option "$normalizedValue" already exists for this component '
          'kind.',
        );
      }
      rethrow;
    }
  }

  Future<void> deleteEnumOption(int optionId) async {
    final database = await db;

    await database.transaction((txn) async {
      final option = await _requireEnumOption(txn, optionId);
      final compKindId = option['comp_kind_id'] as int;
      final value = option['value'] as String;

      final usageCount = await _countRows(
        txn,
        '''
        SELECT COUNT(*)
        FROM text_comps
        WHERE kind_id = ? AND value = ?
        ''',
        [compKindId, value],
      );

      if (usageCount > 0) {
        throw Exception(
          'Cannot delete enum option "$value" because it is currently in use.',
        );
      }

      await txn.delete(
        'comp_kind_enum_options',
        where: 'id = ?',
        whereArgs: [optionId],
      );
    });
  }

  Future<List<Map<String, dynamic>>> getEnumOptions(int compKindId) async {
    final database = await db;

    final rows = await database.query(
      'comp_kind_enum_options',
      where: 'comp_kind_id = ?',
      whereArgs: [compKindId],
      orderBy: 'sort_order ASC, id ASC',
    );

    return rows.map(Map<String, dynamic>.from).toList();
  }

  Future<int> createEntity({
    required int kindId,
    Map<int, Object?> componentValues = const {},
  }) async {
    final database = await db;

    return database.transaction((txn) async {
      await _requireActiveEntityKind(txn, kindId);

      final entityId = await txn.insert('entities', {'kind_id': kindId});

      await _applyComponentValues(
        txn,
        entityKindId: kindId,
        entityId: entityId,
        componentValues: componentValues,
      );

      return entityId;
    });
  }

  Future<void> updateEntity({
    required int entityId,
    required int kindId,
    Map<int, Object?> componentValues = const {},
  }) async {
    final database = await db;

    await database.transaction((txn) async {
      final entity = await _requireEntity(txn, entityId);
      final previousKindId = entity['kind_id'] as int;

      await _requireActiveEntityKind(txn, kindId);

      if (previousKindId != kindId) {
        for (final tableName in _componentTables.values) {
          await txn.delete(
            tableName,
            where: 'entity_id = ?',
            whereArgs: [entityId],
          );
        }

        final updatedRows = await txn.update(
          'entities',
          {'kind_id': kindId},
          where: 'id = ?',
          whereArgs: [entityId],
        );

        if (updatedRows == 0) {
          throw Exception('Entity $entityId could not be updated.');
        }
      }

      await _applyComponentValues(
        txn,
        entityKindId: kindId,
        entityId: entityId,
        componentValues: componentValues,
      );
    });
  }

  Future<void> updateEntityComponents({
    required int entityId,
    required Map<int, Object?> componentValues,
  }) async {
    final database = await db;

    await database.transaction((txn) async {
      final entity = await _requireEntity(txn, entityId);
      final entityKindId = entity['kind_id'] as int;

      await _applyComponentValues(
        txn,
        entityKindId: entityKindId,
        entityId: entityId,
        componentValues: componentValues,
      );
    });
  }

  Future<List<Map<String, dynamic>>> getAllEntities({
    int? kindId,
    bool includeInactiveKinds = false,
  }) async {
    final database = await db;
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (!includeInactiveKinds) {
      whereClauses.add('ek.status = 1');
    }

    if (kindId != null) {
      whereClauses.add('e.kind_id = ?');
      whereArgs.add(kindId);
    }

    final whereSql = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';

    final rows = await database.rawQuery('''
      SELECT
        e.id,
        e.kind_id,
        ek.name AS kind_name,
        ek.display_name AS kind_display_name,
        ek.status AS kind_status
      FROM entities e
      INNER JOIN entity_kinds ek ON ek.id = e.kind_id
      $whereSql
      ORDER BY e.id ASC
    ''', whereArgs);

    return rows.map(Map<String, dynamic>.from).toList();
  }

  Future<List<Map<String, dynamic>>> getEntitiesWithComponents({
    required int kindId,
    bool includeInactiveDefinitions = false,
  }) async {
    final database = await db;
    await _requireActiveEntityKind(database, kindId);

    final entities = await getAllEntities(kindId: kindId);
    if (entities.isEmpty) {
      return const [];
    }

    final definitions = await _getLinkedComponentDefinitions(
      database,
      entityKindId: kindId,
      includeInactive: includeInactiveDefinitions,
    );
    final entityIds = entities.map((entity) => entity['id'] as int).toList();
    final valuesByEntityId = await _loadStoredComponentValuesByEntity(
      database,
      entityIds: entityIds,
      definitions: definitions,
    );
    final enumOptionsByKindId = await _loadEnumOptionsForDefinitions(
      database,
      definitions,
    );

    return entities.map((entity) {
      final entityId = entity['id'] as int;
      final componentValues = valuesByEntityId[entityId] ?? const {};
      final components = <Map<String, dynamic>>[];

      for (final definition in definitions) {
        final component = Map<String, dynamic>.from(definition);
        final compKindId = component['id'] as int;
        component['value'] = componentValues[compKindId];
        component['enum_options'] = enumOptionsByKindId[compKindId] ?? const [];
        components.add(component);
      }

      final detailedEntity = Map<String, dynamic>.from(entity);
      detailedEntity['components'] = components;
      return detailedEntity;
    }).toList();
  }

  Future<Map<String, dynamic>?> getEntity(
    int entityId, {
    bool includeInactiveDefinitions = false,
  }) async {
    final database = await db;

    final rows = await database.rawQuery(
      '''
      SELECT
        e.id,
        e.kind_id,
        ek.name AS kind_name,
        ek.display_name AS kind_display_name,
        ek.status AS kind_status
      FROM entities e
      INNER JOIN entity_kinds ek ON ek.id = e.kind_id
      WHERE e.id = ?
      LIMIT 1
    ''',
      [entityId],
    );

    if (rows.isEmpty) {
      return null;
    }

    final entity = Map<String, dynamic>.from(rows.first);
    entity['components'] = await _getEntityComponents(
      database,
      entityId: entityId,
      entityKindId: entity['kind_id'] as int,
      includeInactiveDefinitions: includeInactiveDefinitions,
    );

    return entity;
  }

  Future<List<Map<String, dynamic>>> getEntityKindComponents(
    int entityKindId, {
    bool includeInactiveDefinitions = false,
  }) async {
    final database = await db;

    final components = await _getEntityComponents(
      database,
      entityId: -1,
      entityKindId: entityKindId,
      includeInactiveDefinitions: includeInactiveDefinitions,
    );

    for (final component in components) {
      component['value'] = null;
    }

    return components;
  }

  Future<void> deleteEntity(int entityId) async {
    final database = await db;

    await database.transaction((txn) async {
      await _requireEntity(txn, entityId);

      final isReferenced = await _entityHasIncomingReferences(txn, entityId);
      if (isReferenced) {
        throw Exception(
          'Cannot delete entity $entityId because another entity references it.',
        );
      }

      for (final tableName in _componentTables.values) {
        await txn.delete(
          tableName,
          where: 'entity_id = ?',
          whereArgs: [entityId],
        );
      }

      final deletedRows = await txn.delete(
        'entities',
        where: 'id = ?',
        whereArgs: [entityId],
      );

      if (deletedRows == 0) {
        throw Exception('Entity $entityId could not be deleted.');
      }
    });
  }

  Future<List<Map<String, dynamic>>> _getEntityComponents(
    DatabaseExecutor db, {
    required int entityId,
    required int entityKindId,
    required bool includeInactiveDefinitions,
  }) async {
    final definitions = await _getLinkedComponentDefinitions(
      db,
      entityKindId: entityKindId,
      includeInactive: includeInactiveDefinitions,
    );

    final valuesByKindId = await _loadStoredComponentValues(
      db,
      entityId: entityId,
      definitions: definitions,
    );

    final enumOptionsByKindId = await _loadEnumOptionsForDefinitions(
      db,
      definitions,
    );

    final components = <Map<String, dynamic>>[];
    for (final definition in definitions) {
      final component = Map<String, dynamic>.from(definition);
      final compKindId = component['id'] as int;
      component['value'] = valuesByKindId[compKindId];
      component['enum_options'] = enumOptionsByKindId[compKindId] ?? const [];
      components.add(component);
    }

    return components;
  }

  Future<List<Map<String, dynamic>>> _getLinkedComponentDefinitions(
    DatabaseExecutor db, {
    required int entityKindId,
    required bool includeInactive,
  }) async {
    final statusFilter = includeInactive ? '' : 'AND ck.status = 1';

    final rows = await db.rawQuery(
      '''
      SELECT
        ck.id,
        ck.name,
        ck.display_name,
        ck.storage_type,
        ck.semantic_type,
        ck.status
      FROM entity_kind_comp_kinds ekck
      INNER JOIN comp_kinds ck ON ck.id = ekck.comp_kind_id
      WHERE ekck.entity_kind_id = ?
      $statusFilter
      ORDER BY ck.id ASC
    ''',
      [entityKindId],
    );

    return rows.map(Map<String, dynamic>.from).toList();
  }

  Future<Map<int, Object?>> _loadStoredComponentValues(
    DatabaseExecutor db, {
    required int entityId,
    required List<Map<String, dynamic>> definitions,
  }) async {
    final valuesByKindId = <int, Object?>{};

    for (final entry in _componentTables.entries) {
      final storageType = entry.key;
      final tableName = entry.value;
      final kindIds = definitions
          .where((definition) => definition['storage_type'] == storageType)
          .map((definition) => definition['id'] as int)
          .toList();

      if (kindIds.isEmpty) {
        continue;
      }

      final rows = await db.rawQuery(
        '''
        SELECT kind_id, value
        FROM $tableName
        WHERE entity_id = ?
          AND kind_id IN (${_placeholders(kindIds.length)})
      ''',
        [entityId, ...kindIds],
      );

      for (final row in rows) {
        valuesByKindId[row['kind_id'] as int] = row['value'];
      }
    }

    return valuesByKindId;
  }

  Future<Map<int, Map<int, Object?>>> _loadStoredComponentValuesByEntity(
    DatabaseExecutor db, {
    required List<int> entityIds,
    required List<Map<String, dynamic>> definitions,
  }) async {
    if (entityIds.isEmpty || definitions.isEmpty) {
      return const {};
    }

    final valuesByEntityId = <int, Map<int, Object?>>{};

    for (final entry in _componentTables.entries) {
      final storageType = entry.key;
      final tableName = entry.value;
      final kindIds = definitions
          .where((definition) => definition['storage_type'] == storageType)
          .map((definition) => definition['id'] as int)
          .toList();

      if (kindIds.isEmpty) {
        continue;
      }

      final rows = await db.rawQuery(
        '''
        SELECT entity_id, kind_id, value
        FROM $tableName
        WHERE entity_id IN (${_placeholders(entityIds.length)})
          AND kind_id IN (${_placeholders(kindIds.length)})
      ''',
        [...entityIds, ...kindIds],
      );

      for (final row in rows) {
        final entityId = row['entity_id'] as int;
        final kindId = row['kind_id'] as int;
        valuesByEntityId.putIfAbsent(entityId, () => <int, Object?>{});
        valuesByEntityId[entityId]![kindId] = row['value'];
      }
    }

    return valuesByEntityId;
  }

  Future<Map<int, List<Map<String, dynamic>>>> _loadEnumOptionsForDefinitions(
    DatabaseExecutor db,
    List<Map<String, dynamic>> definitions,
  ) async {
    final enumKindIds = definitions
        .where((definition) => definition['semantic_type'] == semanticEnum)
        .map((definition) => definition['id'] as int)
        .toList();

    if (enumKindIds.isEmpty) {
      return const {};
    }

    final rows = await db.rawQuery('''
      SELECT id, comp_kind_id, value, display_label, sort_order
      FROM comp_kind_enum_options
      WHERE comp_kind_id IN (${_placeholders(enumKindIds.length)})
      ORDER BY comp_kind_id ASC, sort_order ASC, id ASC
    ''', enumKindIds);

    final optionsByKindId = <int, List<Map<String, dynamic>>>{};

    for (final row in rows) {
      final compKindId = row['comp_kind_id'] as int;
      optionsByKindId.putIfAbsent(compKindId, () => <Map<String, dynamic>>[]);
      optionsByKindId[compKindId]!.add(Map<String, dynamic>.from(row));
    }

    return optionsByKindId;
  }

  Future<void> _applyComponentValues(
    DatabaseExecutor db, {
    required int entityKindId,
    required int entityId,
    required Map<int, Object?> componentValues,
  }) async {
    if (componentValues.isEmpty) {
      return;
    }

    final allowedDefinitions = await _getAllowedComponentDefinitions(
      db,
      entityKindId: entityKindId,
      compKindIds: componentValues.keys,
    );

    for (final entry in componentValues.entries) {
      final compKindId = entry.key;
      final definition = allowedDefinitions[compKindId];

      if (definition == null) {
        throw Exception(
          'Component kind $compKindId is not linked to entity kind '
          '$entityKindId.',
        );
      }

      final storageType = definition['storage_type'] as String;
      final tableName = _componentTables[storageType]!;
      final normalizedValue = await _normalizeComponentValue(
        db,
        definition: definition,
        rawValue: entry.value,
      );

      if (normalizedValue == null) {
        await db.delete(
          tableName,
          where: 'entity_id = ? AND kind_id = ?',
          whereArgs: [entityId, compKindId],
        );
        continue;
      }

      await db.insert(tableName, {
        'entity_id': entityId,
        'kind_id': compKindId,
        'value': normalizedValue,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<Map<int, Map<String, dynamic>>> _getAllowedComponentDefinitions(
    DatabaseExecutor db, {
    required int entityKindId,
    required Iterable<int> compKindIds,
  }) async {
    final normalizedIds = _normalizeIdList(compKindIds, 'Component kind id');
    if (normalizedIds.isEmpty) {
      return const {};
    }

    final rows = await db.rawQuery(
      '''
      SELECT
        ck.id,
        ck.name,
        ck.display_name,
        ck.storage_type,
        ck.semantic_type,
        ck.status
      FROM entity_kind_comp_kinds ekck
      INNER JOIN comp_kinds ck ON ck.id = ekck.comp_kind_id
      WHERE ekck.entity_kind_id = ?
        AND ekck.comp_kind_id IN (${_placeholders(normalizedIds.length)})
        AND ck.status = 1
    ''',
      [entityKindId, ...normalizedIds],
    );

    final definitions = <int, Map<String, dynamic>>{};
    for (final row in rows) {
      final definition = Map<String, dynamic>.from(row);
      definitions[definition['id'] as int] = definition;
    }

    return definitions;
  }

  Future<Object?> _normalizeComponentValue(
    DatabaseExecutor db, {
    required Map<String, dynamic> definition,
    required Object? rawValue,
  }) async {
    if (rawValue == null) {
      return null;
    }

    final storageType = definition['storage_type'] as String;
    final semanticType =
        (definition['semantic_type'] as String?) ?? semanticPlain;
    final compKindId = definition['id'] as int;

    switch (storageType) {
      case storageInteger:
        if (semanticType == semanticBoolean) {
          return _normalizeBooleanValue(rawValue);
        }

        if (semanticType == semanticDate) {
          return _normalizeDateValue(rawValue);
        }

        if (rawValue is int) {
          return rawValue;
        }

        throw Exception('Component kind $compKindId expects an integer value.');

      case storageReal:
        if (rawValue is num) {
          return rawValue.toDouble();
        }

        throw Exception('Component kind $compKindId expects a real value.');

      case storageText:
        if (rawValue is! String) {
          throw Exception('Component kind $compKindId expects a text value.');
        }

        if (semanticType == semanticEnum) {
          await _ensureEnumValueAllowed(db, compKindId, rawValue);
        }

        return rawValue;

      case storageEntity:
        if (rawValue is! int) {
          throw Exception(
            'Component kind $compKindId expects an entity id reference.',
          );
        }

        final referencedEntity = await _requireEntity(db, rawValue);
        return referencedEntity['id'];
    }

    throw Exception('Unsupported storage type "$storageType".');
  }

  int _normalizeBooleanValue(Object rawValue) {
    if (rawValue is bool) {
      return rawValue ? 1 : 0;
    }

    if (rawValue is int && (rawValue == 0 || rawValue == 1)) {
      return rawValue;
    }

    throw Exception('Boolean component values must be true/false or 0/1.');
  }

  int _normalizeDateValue(Object rawValue) {
    if (rawValue is DateTime) {
      return rawValue.millisecondsSinceEpoch;
    }

    if (rawValue is int) {
      return rawValue;
    }

    throw Exception(
      'Date component values must be an integer or a DateTime instance.',
    );
  }

  Future<void> _ensureEnumValueAllowed(
    DatabaseExecutor db,
    int compKindId,
    String value,
  ) async {
    final matchingOptions = await _countRows(
      db,
      '''
      SELECT COUNT(*)
      FROM comp_kind_enum_options
      WHERE comp_kind_id = ? AND value = ?
      ''',
      [compKindId, value],
    );

    if (matchingOptions == 0) {
      throw Exception(
        'Value "$value" is not a valid enum option for component kind '
        '$compKindId.',
      );
    }
  }

  Future<Map<String, dynamic>> _requireCompKind(
    DatabaseExecutor db,
    int compKindId,
  ) async {
    final rows = await db.query(
      'comp_kinds',
      where: 'id = ?',
      whereArgs: [compKindId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Component kind $compKindId was not found.');
    }

    return Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>> _requireEntityKind(
    DatabaseExecutor db,
    int entityKindId,
  ) async {
    final rows = await db.query(
      'entity_kinds',
      where: 'id = ?',
      whereArgs: [entityKindId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Entity kind $entityKindId was not found.');
    }

    return Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>> _requireActiveEntityKind(
    DatabaseExecutor db,
    int entityKindId,
  ) async {
    final entityKind = await _requireEntityKind(db, entityKindId);
    if (entityKind['status'] != activeStatus) {
      throw Exception(
        'Entity kind $entityKindId is soft-deleted and cannot be used.',
      );
    }
    return entityKind;
  }

  Future<Map<String, dynamic>> _requireEntity(
    DatabaseExecutor db,
    int entityId,
  ) async {
    final rows = await db.query(
      'entities',
      where: 'id = ?',
      whereArgs: [entityId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Entity $entityId was not found.');
    }

    return Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>> _requireEnumOption(
    DatabaseExecutor db,
    int optionId,
  ) async {
    final rows = await db.query(
      'comp_kind_enum_options',
      where: 'id = ?',
      whereArgs: [optionId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Enum option $optionId was not found.');
    }

    return Map<String, dynamic>.from(rows.first);
  }

  Future<void> _requireEnumCompKind(DatabaseExecutor db, int compKindId) async {
    final compKind = await _requireCompKind(db, compKindId);
    final storageType = compKind['storage_type'] as String;
    final semanticType = compKind['semantic_type'] as String;

    if (storageType != storageText || semanticType != semanticEnum) {
      throw Exception(
        'Component kind $compKindId is not a text enum component kind.',
      );
    }
  }

  Future<List<int>> _getLinkedCompKindIds(
    DatabaseExecutor db,
    int entityKindId,
  ) async {
    final rows = await db.query(
      'entity_kind_comp_kinds',
      columns: ['comp_kind_id'],
      where: 'entity_kind_id = ?',
      whereArgs: [entityKindId],
    );

    return rows.map((row) => row['comp_kind_id'] as int).toList()..sort();
  }

  Future<void> _ensureCompKindsExist(
    DatabaseExecutor db,
    List<int> compKindIds, {
    bool activeOnly = true,
  }) async {
    if (compKindIds.isEmpty) {
      return;
    }

    final rows = await db.rawQuery('''
      SELECT id
      FROM comp_kinds
      WHERE id IN (${_placeholders(compKindIds.length)})
        ${activeOnly ? 'AND status = 1' : ''}
    ''', compKindIds);

    final foundIds = rows.map((row) => row['id'] as int).toSet();
    final missingIds = compKindIds
        .where((id) => !foundIds.contains(id))
        .toList();

    if (missingIds.isNotEmpty) {
      if (activeOnly) {
        throw Exception(
          'Component kinds must exist and be active before they can be linked. '
          'Missing ids: ${missingIds.join(', ')}.',
        );
      }

      throw Exception(
        'Component kinds must exist before they can be linked. '
        'Missing ids: ${missingIds.join(', ')}.',
      );
    }
  }

  Future<void> _syncEntityKindCompKinds(
    DatabaseExecutor db, {
    required int entityKindId,
    required List<int> desiredCompKindIds,
  }) async {
    final currentRows = await db.query(
      'entity_kind_comp_kinds',
      columns: ['comp_kind_id'],
      where: 'entity_kind_id = ?',
      whereArgs: [entityKindId],
    );

    final currentIds = currentRows
        .map((row) => row['comp_kind_id'] as int)
        .toSet();
    final desiredIds = desiredCompKindIds.toSet();

    final idsToRemove = currentIds.difference(desiredIds).toList();
    final idsToAdd = desiredIds.difference(currentIds).toList();

    if (idsToRemove.isNotEmpty) {
      await db.delete(
        'entity_kind_comp_kinds',
        where:
            'entity_kind_id = ? AND comp_kind_id IN '
            '(${_placeholders(idsToRemove.length)})',
        whereArgs: [entityKindId, ...idsToRemove],
      );

      await _deleteComponentValuesForRemovedLinks(
        db,
        entityKindId: entityKindId,
        compKindIds: idsToRemove,
      );
    }

    for (final compKindId in idsToAdd) {
      await db.insert('entity_kind_comp_kinds', {
        'entity_kind_id': entityKindId,
        'comp_kind_id': compKindId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _deleteComponentValuesForRemovedLinks(
    DatabaseExecutor db, {
    required int entityKindId,
    required List<int> compKindIds,
  }) async {
    if (compKindIds.isEmpty) {
      return;
    }

    final rows = await db.rawQuery('''
      SELECT id, storage_type
      FROM comp_kinds
      WHERE id IN (${_placeholders(compKindIds.length)})
    ''', compKindIds);

    final idsByTable = <String, List<int>>{};
    for (final row in rows) {
      final storageType = row['storage_type'] as String;
      final tableName = _componentTables[storageType];
      if (tableName == null) {
        continue;
      }

      idsByTable.putIfAbsent(tableName, () => <int>[]);
      idsByTable[tableName]!.add(row['id'] as int);
    }

    for (final entry in idsByTable.entries) {
      final tableName = entry.key;
      final tableCompKindIds = entry.value;

      await db.rawDelete(
        '''
        DELETE FROM $tableName
        WHERE kind_id IN (${_placeholders(tableCompKindIds.length)})
          AND entity_id IN (
            SELECT id
            FROM entities
            WHERE kind_id = ?
          )
      ''',
        [...tableCompKindIds, entityKindId],
      );
    }
  }

  Future<bool> _compKindHasStoredValues(
    DatabaseExecutor db,
    int compKindId,
  ) async {
    for (final tableName in _componentTables.values) {
      final rowCount = await _countRows(
        db,
        'SELECT COUNT(*) FROM $tableName WHERE kind_id = ?',
        [compKindId],
      );

      if (rowCount > 0) {
        return true;
      }
    }

    return false;
  }

  Future<bool> _entityHasIncomingReferences(
    DatabaseExecutor db,
    int entityId,
  ) async {
    final rowCount = await _countRows(
      db,
      'SELECT COUNT(*) FROM entity_comps WHERE value = ?',
      [entityId],
    );

    return rowCount > 0;
  }

  Future<int> _countRows(
    DatabaseExecutor db,
    String sql,
    List<Object?> arguments,
  ) async {
    final rows = await db.rawQuery(sql, arguments);
    if (rows.isEmpty || rows.first.isEmpty) {
      return 0;
    }

    final value = rows.first.values.first;
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  String _normalizeRequiredText(String value, String label) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw Exception('$label cannot be blank.');
    }
    return normalized;
  }

  String _normalizeStorageType(String storageType) {
    final normalized = storageType.trim().toLowerCase();
    if (!_storageTypes.contains(normalized)) {
      throw Exception(
        'Unsupported storage type "$storageType". '
        'Expected one of: ${_storageTypes.join(', ')}.',
      );
    }
    return normalized;
  }

  String _resolveSemanticType(String storageType, String? semanticType) {
    final normalizedSemanticType = semanticType?.trim();

    if (normalizedSemanticType != null && normalizedSemanticType.isNotEmpty) {
      return normalizedSemanticType;
    }

    if (storageType == storageEntity) {
      return semanticEntityReference;
    }

    return semanticPlain;
  }

  void _ensureSemanticTypeIsCompatible(
    String storageType,
    String semanticType,
  ) {
    if (semanticType == semanticBoolean && storageType != storageInteger) {
      throw Exception('Boolean component kinds must use integer storage.');
    }

    if (semanticType == semanticDate && storageType != storageInteger) {
      throw Exception('Date component kinds must use integer storage.');
    }

    if (semanticType == semanticEnum && storageType != storageText) {
      throw Exception('Enum component kinds must use text storage.');
    }

    if (semanticType == semanticEntityReference &&
        storageType != storageEntity) {
      throw Exception(
        'Entity reference component kinds must use entity storage.',
      );
    }
  }

  int _normalizeStatus(int status) {
    if (status != activeStatus && status != deletedStatus) {
      throw Exception('Status must be 0 or 1.');
    }
    return status;
  }

  int _normalizeSortOrder(int sortOrder) {
    if (sortOrder < 0) {
      throw Exception('Sort order must be zero or greater.');
    }
    return sortOrder;
  }

  List<int> _normalizeIdList(Iterable<int> ids, String label) {
    final uniqueIds = <int>{};

    for (final id in ids) {
      if (id <= 0) {
        throw Exception('$label values must be positive integers.');
      }
      uniqueIds.add(id);
    }

    return uniqueIds.toList()..sort();
  }

  String _placeholders(int count) {
    return List.filled(count, '?').join(', ');
  }

  Future<void> close() async {
    final database = _db;
    if (database == null) {
      return;
    }

    await database.close();
    _db = null;
  }
}

final dbHelper = DbHelper();
