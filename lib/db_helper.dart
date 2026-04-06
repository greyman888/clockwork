import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'required_definitions.dart';

class DbHelper {
  DbHelper({
    this.dbName = 'clockwork.db',
    this.databaseDirectory,
    Future<String> Function()? requiredDefinitionsLoader,
  }) : _requiredDefinitionsLoader =
           requiredDefinitionsLoader ??
           (() => File(requiredDefinitionsAssetPath).readAsString());

  factory DbHelper.forFilePath({
    required String dbPath,
    Future<String> Function()? requiredDefinitionsLoader,
  }) {
    final normalizedPath = path.normalize(dbPath);
    return DbHelper(
      dbName: path.basename(normalizedPath),
      databaseDirectory: path.dirname(normalizedPath),
      requiredDefinitionsLoader: requiredDefinitionsLoader,
    );
  }

  static const int _schemaVersion = 2;

  Database? _db;
  final Future<String> Function() _requiredDefinitionsLoader;
  RequiredDefinitionsManifest? _requiredDefinitionsManifest;

  static const int activeStatus = 1;
  static const int deletedStatus = 0;
  static const String productName = 'Clockwork';
  static const String publisherName = 'Clockwork Software';
  static const String applicationId = 'software.clockwork.clockwork';

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

    final supportDirPath = defaultDatabaseDirectoryPath();
    await Directory(supportDirPath).create(recursive: true);
    return supportDirPath;
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

  Future<void> ensureRequiredDefinitions() async {
    final manifest = await _getRequiredDefinitionsManifest();
    final database = await db;

    await database.transaction((txn) async {
      await _ensureRequiredDefinitionsInTransaction(txn, manifest);
    });
  }

  Future<Map<String, dynamic>> getDayPageData(DateTime date) async {
    final day = _normalizeDayDate(date);
    final sourceData = await _loadClockworkTimeEntrySourceData();

    final entries =
        sourceData.entries
            .where((entry) => entry['date'] == day.millisecondsSinceEpoch)
            .map(
              (entry) => <String, dynamic>{
                'id': entry['id'],
                'project_id': entry['project_id'],
                'project_name': entry['project_name'],
                'task_id': entry['task_id'],
                'task_name': entry['task_name'],
                'start_minutes': entry['start_minutes'],
                'end_minutes': entry['end_minutes'],
                'duration_hours': entry['duration_hours'],
                'billable_value': entry['billable_value'],
                'note': entry['note'],
              },
            )
            .toList()
          ..sort(_compareDayEntries);

    return {
      'date': day.millisecondsSinceEpoch,
      'projects': sourceData.projects,
      'tasks': sourceData.tasks,
      'entries': entries,
    };
  }

  Future<Map<String, dynamic>> getWeekPageData(DateTime date) async {
    final anchorDay = _normalizeDayDate(date);
    final weekStart = _weekStartForDate(anchorDay);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekStartValue = weekStart.millisecondsSinceEpoch;
    final weekEndValue = weekEnd.millisecondsSinceEpoch;
    final sourceData = await _loadClockworkTimeEntrySourceData();
    final sortedEntries = List<Map<String, dynamic>>.from(sourceData.entries)
      ..sort(_compareWeekEntriesForAggregation);
    final rowsByKey = <_ClockworkWeekRowKey, _ClockworkWeekRowAccumulator>{};

    for (final entry in sortedEntries) {
      final entryDateValue = entry['date'] as int?;
      final durationMinutes = entry['duration_minutes'] as int?;
      final projectId = entry['project_id'] as int?;
      final taskId = entry['task_id'] as int?;

      if (entryDateValue == null ||
          durationMinutes == null ||
          durationMinutes <= 0 ||
          projectId == null ||
          taskId == null) {
        continue;
      }

      if (entryDateValue < weekStartValue || entryDateValue > weekEndValue) {
        continue;
      }

      final entryDay = DateTime.fromMillisecondsSinceEpoch(entryDateValue);
      final dayIndex = entryDay.weekday - DateTime.monday;
      if (dayIndex < 0 || dayIndex >= 7) {
        continue;
      }

      final billableValue = entry['billable_value'] as int? ?? 0;
      final rowKey = _ClockworkWeekRowKey(
        projectId: projectId,
        taskId: taskId,
        billableValue: billableValue,
      );
      final row = rowsByKey.putIfAbsent(
        rowKey,
        () => _ClockworkWeekRowAccumulator(
          projectId: projectId,
          projectName:
              entry['project_name'] as String? ?? 'Project #$projectId',
          taskId: taskId,
          taskName: entry['task_name'] as String? ?? 'Task #$taskId',
          billableValue: billableValue,
        ),
      );

      row.addMinutes(dayIndex, durationMinutes);
      row.addNoteLine(dayIndex, entry['note'] as String?);
    }

    final rows = rowsByKey.values.map((row) => row.toMap()).toList()
      ..sort(_compareWeekRows);
    final weekTotalMinutes = rows.fold<int>(
      0,
      (total, row) => total + (row['total_minutes'] as int? ?? 0),
    );

    return {
      'week_start': weekStartValue,
      'week_end': weekEndValue,
      'week_total_minutes': weekTotalMinutes,
      'projects': sourceData.projects,
      'rows': rows,
    };
  }

  Future<Map<String, dynamic>> getSetupAndSummaryPageData({
    DateTime? referenceDate,
  }) async {
    final sourceData = await _loadClockworkTimeEntrySourceData();
    final taskTotals = <int, int>{};

    for (final entry in sourceData.entries) {
      final taskId = entry['task_id'] as int?;
      final durationMinutes = entry['duration_minutes'] as int?;
      if (taskId == null || durationMinutes == null || durationMinutes <= 0) {
        continue;
      }

      taskTotals.update(
        taskId,
        (currentValue) => currentValue + durationMinutes,
        ifAbsent: () => durationMinutes,
      );
    }

    final tasksByProjectId = <int?, List<Map<String, dynamic>>>{};
    for (final task in sourceData.tasks) {
      final projectId = task['project_id'] as int?;
      tasksByProjectId.putIfAbsent(projectId, () => <Map<String, dynamic>>[]);
      tasksByProjectId[projectId]!.add(task);
    }

    final summaryRows = <Map<String, dynamic>>[];
    for (final project in sourceData.projects) {
      final projectId = project['id'] as int;
      final projectName = project['name'] as String;
      final projectTasks = tasksByProjectId[projectId] ?? const [];
      final projectTotalMinutes = projectTasks.fold<int>(0, (total, task) {
        final taskId = task['id'] as int;
        return total + (taskTotals[taskId] ?? 0);
      });

      summaryRows.add({
        'kind': 'project',
        'entity_id': projectId,
        'project_id': projectId,
        'project_name': projectName,
        'task_id': null,
        'task_name': null,
        'name': projectName,
        'total_minutes': projectTotalMinutes,
      });

      for (final task in projectTasks) {
        final taskId = task['id'] as int;
        final taskName = task['name'] as String;
        summaryRows.add({
          'kind': 'task',
          'entity_id': taskId,
          'project_id': projectId,
          'project_name': projectName,
          'task_id': taskId,
          'task_name': taskName,
          'name': taskName,
          'total_minutes': taskTotals[taskId] ?? 0,
        });
      }
    }

    for (final task
        in tasksByProjectId[null] ?? const <Map<String, dynamic>>[]) {
      final taskId = task['id'] as int;
      final taskName = task['name'] as String;
      summaryRows.add({
        'kind': 'task',
        'entity_id': taskId,
        'project_id': null,
        'project_name': null,
        'task_id': taskId,
        'task_name': taskName,
        'name': taskName,
        'total_minutes': taskTotals[taskId] ?? 0,
      });
    }

    return {
      'projects': sourceData.projects,
      'tasks': sourceData.tasks,
      'summary_rows': summaryRows,
      'billability_summary': _buildBillabilitySummary(
        sourceData.entries,
        referenceDate: referenceDate ?? DateTime.now(),
      ),
    };
  }

  Map<String, dynamic> _buildBillabilitySummary(
    List<Map<String, dynamic>> entries, {
    required DateTime referenceDate,
  }) {
    final monthStarts = _setupSummaryMonthStarts(referenceDate);
    final monthIndexByKey = <int, int>{
      for (var index = 0; index < monthStarts.length; index += 1)
        _setupSummaryMonthKey(monthStarts[index]): index,
    };
    final billableMinutes = List<int>.filled(monthStarts.length, 0);
    final nonBillableMinutes = List<int>.filled(monthStarts.length, 0);
    final totalMinutes = List<int>.filled(monthStarts.length, 0);

    for (final entry in entries) {
      final dateValue = entry['date'] as int?;
      final durationMinutes = entry['duration_minutes'] as int?;
      if (dateValue == null ||
          durationMinutes == null ||
          durationMinutes <= 0) {
        continue;
      }

      final entryDate = DateTime.fromMillisecondsSinceEpoch(dateValue);
      final monthIndex =
          monthIndexByKey[_setupSummaryMonthKey(
            DateTime(entryDate.year, entryDate.month),
          )];
      if (monthIndex == null) {
        continue;
      }

      final billableValue = entry['billable_value'] as int? ?? 0;
      if (billableValue == 1) {
        billableMinutes[monthIndex] += durationMinutes;
      } else {
        nonBillableMinutes[monthIndex] += durationMinutes;
      }
      totalMinutes[monthIndex] += durationMinutes;
    }

    List<double> toHours(List<int> minutes) {
      return minutes.map((value) => value / 60.0).toList(growable: false);
    }

    final billableHours = toHours(billableMinutes);
    final nonBillableHours = toHours(nonBillableMinutes);
    final totalHours = toHours(totalMinutes);
    final billabilityPercentages = List<double>.generate(monthStarts.length, (
      index,
    ) {
      final monthlyTotalMinutes = totalMinutes[index];
      if (monthlyTotalMinutes <= 0) {
        return 0;
      }

      return (billableMinutes[index] / monthlyTotalMinutes) * 100;
    }, growable: false);

    double averageHours(List<int> minutes) {
      if (minutes.isEmpty) {
        return 0;
      }

      return (minutes.fold<int>(0, (sum, value) => sum + value) / 60.0) /
          minutes.length;
    }

    final totalBillableMinutes = billableMinutes.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final totalWorkedMinutes = totalMinutes.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final runningBillabilityPercentage = totalWorkedMinutes == 0
        ? 0.0
        : (totalBillableMinutes / totalWorkedMinutes) * 100;

    return {
      'month_labels': monthStarts
          .map(_setupSummaryMonthLabel)
          .toList(growable: false),
      'rows': [
        {
          'key': 'billable_hours',
          'label': 'Billable Hours',
          'display': 'hours',
          'monthly_values': billableHours,
          'average_value': averageHours(billableMinutes),
        },
        {
          'key': 'non_billable_hours',
          'label': 'Non Billable Hours',
          'display': 'hours',
          'monthly_values': nonBillableHours,
          'average_value': averageHours(nonBillableMinutes),
        },
        {
          'key': 'total_hours_worked',
          'label': 'Total Hours Worked',
          'display': 'hours',
          'monthly_values': totalHours,
          'average_value': averageHours(totalMinutes),
        },
        {
          'key': 'billability_percentage',
          'label': 'Billability %',
          'display': 'percentage',
          'monthly_values': billabilityPercentages,
          'average_value': runningBillabilityPercentage,
        },
      ],
    };
  }

  List<DateTime> _setupSummaryMonthStarts(DateTime referenceDate) {
    final currentMonthStart = DateTime(referenceDate.year, referenceDate.month);
    return List<DateTime>.generate(
      6,
      (index) =>
          DateTime(currentMonthStart.year, currentMonthStart.month - 5 + index),
      growable: false,
    );
  }

  String _setupSummaryMonthLabel(DateTime monthStart) {
    const monthLabels = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return monthLabels[monthStart.month - 1];
  }

  int _setupSummaryMonthKey(DateTime monthStart) {
    return (monthStart.year * 100) + monthStart.month;
  }

  Future<int> saveProject({required String name, int? projectId}) async {
    await ensureRequiredDefinitions();
    final definitions = await _getClockworkDayDefinitions();
    final normalizedName = _normalizeRequiredText(name, 'Project name');
    final componentValues = <int, Object?>{
      definitions.nameCompKindId: normalizedName,
    };

    if (projectId == null) {
      return createEntity(
        kindId: definitions.projectKindId,
        componentValues: componentValues,
      );
    }

    final existingProject = await getEntity(projectId);
    if (existingProject == null ||
        existingProject['kind_id'] != definitions.projectKindId) {
      throw Exception('Entity $projectId is not a project.');
    }

    await updateEntity(
      entityId: projectId,
      kindId: definitions.projectKindId,
      componentValues: componentValues,
    );
    return projectId;
  }

  Future<int> saveTask({
    required String name,
    required int projectId,
    int? taskId,
  }) async {
    await ensureRequiredDefinitions();
    final definitions = await _getClockworkDayDefinitions();
    final normalizedName = _normalizeRequiredText(name, 'Task name');
    final projectEntity = await getEntity(projectId);

    if (projectEntity == null ||
        projectEntity['kind_id'] != definitions.projectKindId) {
      throw Exception('Entity $projectId is not a project.');
    }

    final componentValues = <int, Object?>{
      definitions.nameCompKindId: normalizedName,
      definitions.parentCompKindId: projectId,
    };

    if (taskId == null) {
      return createEntity(
        kindId: definitions.taskKindId,
        componentValues: componentValues,
      );
    }

    final existingTask = await getEntity(taskId);
    if (existingTask == null ||
        existingTask['kind_id'] != definitions.taskKindId) {
      throw Exception('Entity $taskId is not a task.');
    }

    await updateEntity(
      entityId: taskId,
      kindId: definitions.taskKindId,
      componentValues: componentValues,
    );
    return taskId;
  }

  Future<int> saveDayEntry({
    required DateTime date,
    required int projectId,
    required int taskId,
    required int startMinutes,
    required int endMinutes,
    int? billableValue,
    String? note,
    int? entryId,
  }) async {
    final database = await db;
    final normalizedDate = _normalizeDayDate(date);
    final normalizedStartMinutes = _normalizeDayMinutes(
      startMinutes,
      'Start time',
    );
    final normalizedEndMinutes = _normalizeDayMinutes(
      endMinutes,
      'End time',
      allowEndOfDay: true,
    );

    if (normalizedEndMinutes <= normalizedStartMinutes) {
      throw Exception('End time must be later than start time.');
    }

    final normalizedBillableValue = billableValue == null
        ? 1
        : _normalizeBooleanValue(billableValue);
    final manifest = await _getRequiredDefinitionsManifest();

    return database.transaction((txn) async {
      await _ensureRequiredDefinitionsInTransaction(txn, manifest);
      final definitions = await _loadClockworkDayDefinitions(txn, manifest);

      final projectEntity = await _requireEntity(txn, projectId);
      if (projectEntity['kind_id'] != definitions.projectKindId) {
        throw Exception('Selected project is not a project entity.');
      }

      final taskEntity = await _requireEntity(txn, taskId);
      if (taskEntity['kind_id'] != definitions.taskKindId) {
        throw Exception('Selected task is not a task entity.');
      }

      final taskProjectId = await _getStoredEntityReferenceValue(
        txn,
        entityId: taskId,
        compKindId: definitions.parentCompKindId,
      );

      if (taskProjectId == null) {
        throw Exception('Selected task is not linked to a project.');
      }

      if (taskProjectId != projectId) {
        throw Exception(
          'Selected task does not belong to the selected project.',
        );
      }

      final normalizedNote = note?.trim();
      final durationHours =
          (normalizedEndMinutes - normalizedStartMinutes) / 60.0;
      final componentValues = <int, Object?>{
        definitions.parentCompKindId: taskId,
        definitions.dateCompKindId: normalizedDate.millisecondsSinceEpoch,
        definitions.durationCompKindId: durationHours,
        definitions.startTimeCompKindId: normalizedStartMinutes,
        definitions.endTimeCompKindId: normalizedEndMinutes,
        definitions.billableCompKindId: normalizedBillableValue,
        definitions.noteCompKindId:
            normalizedNote == null || normalizedNote.isEmpty
            ? null
            : normalizedNote,
      };

      if (entryId == null) {
        await _requireActiveEntityKind(txn, definitions.timeEntryKindId);

        final createdEntryId = await txn.insert('entities', {
          'kind_id': definitions.timeEntryKindId,
        });

        await _applyComponentValues(
          txn,
          entityKindId: definitions.timeEntryKindId,
          entityId: createdEntryId,
          componentValues: componentValues,
        );

        return createdEntryId;
      }

      final existingEntry = await _requireEntity(txn, entryId);
      if (existingEntry['kind_id'] != definitions.timeEntryKindId) {
        throw Exception('Entity $entryId is not a time entry.');
      }

      await _applyComponentValues(
        txn,
        entityKindId: definitions.timeEntryKindId,
        entityId: entryId,
        componentValues: componentValues,
      );

      return entryId;
    });
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

  Future<_ClockworkDayDefinitions> _getClockworkDayDefinitions() async {
    final manifest = await _getRequiredDefinitionsManifest();
    final database = await db;
    return _loadClockworkDayDefinitions(database, manifest);
  }

  Future<_ClockworkTimeEntrySourceData>
  _loadClockworkTimeEntrySourceData() async {
    await ensureRequiredDefinitions();

    final definitions = await _getClockworkDayDefinitions();
    final results = await Future.wait<List<Map<String, dynamic>>>([
      getEntitiesWithComponents(kindId: definitions.projectKindId),
      getEntitiesWithComponents(kindId: definitions.taskKindId),
      getEntitiesWithComponents(kindId: definitions.timeEntryKindId),
    ]);

    final rawProjects = results[0];
    final rawTasks = results[1];
    final rawTimeEntries = results[2];

    final projects =
        rawProjects.map((entity) {
          final projectId = entity['id'] as int;
          final name =
              (_componentValueForKindId(entity, definitions.nameCompKindId)
                      as String?)
                  ?.trim();

          return <String, dynamic>{
            'id': projectId,
            'name': (name == null || name.isEmpty)
                ? 'Project #$projectId'
                : name,
          };
        }).toList()..sort((left, right) {
          final nameCompare = (left['name'] as String).toLowerCase().compareTo(
            (right['name'] as String).toLowerCase(),
          );
          if (nameCompare != 0) {
            return nameCompare;
          }
          return (left['id'] as int).compareTo(right['id'] as int);
        });

    final projectNamesById = <int, String>{
      for (final project in projects)
        project['id'] as int: project['name'] as String,
    };

    final tasks =
        rawTasks.map((entity) {
          final taskId = entity['id'] as int;
          final name =
              (_componentValueForKindId(entity, definitions.nameCompKindId)
                      as String?)
                  ?.trim();
          final projectId =
              _componentValueForKindId(entity, definitions.parentCompKindId)
                  as int?;

          return <String, dynamic>{
            'id': taskId,
            'name': (name == null || name.isEmpty) ? 'Task #$taskId' : name,
            'project_id': projectId,
            'project_name': projectId == null
                ? null
                : projectNamesById[projectId] ?? 'Project #$projectId',
          };
        }).toList()..sort((left, right) {
          final projectCompare = ((left['project_name'] as String?) ?? '')
              .toLowerCase()
              .compareTo(
                ((right['project_name'] as String?) ?? '').toLowerCase(),
              );
          if (projectCompare != 0) {
            return projectCompare;
          }

          final nameCompare = (left['name'] as String).toLowerCase().compareTo(
            (right['name'] as String).toLowerCase(),
          );
          if (nameCompare != 0) {
            return nameCompare;
          }

          return (left['id'] as int).compareTo(right['id'] as int);
        });

    final tasksById = <int, Map<String, dynamic>>{
      for (final task in tasks) task['id'] as int: task,
    };

    final entries = rawTimeEntries.map((entity) {
      final entryId = entity['id'] as int;
      final taskId =
          _componentValueForKindId(entity, definitions.parentCompKindId)
              as int?;
      final task = taskId == null ? null : tasksById[taskId];
      final startMinutes =
          _componentValueForKindId(entity, definitions.startTimeCompKindId)
              as int?;
      final endMinutes =
          _componentValueForKindId(entity, definitions.endTimeCompKindId)
              as int?;
      final durationHours =
          _componentValueForKindId(entity, definitions.durationCompKindId)
              as num?;
      final note =
          _componentValueForKindId(entity, definitions.noteCompKindId)
              as String?;
      final billableValue =
          _componentValueForKindId(entity, definitions.billableCompKindId)
              as int?;
      final dateValue =
          _componentValueForKindId(entity, definitions.dateCompKindId) as int?;

      return <String, dynamic>{
        'id': entryId,
        'date': dateValue,
        'project_id': task?['project_id'],
        'project_name': task?['project_name'],
        'task_id': taskId,
        'task_name': task?['name'] ?? (taskId == null ? null : 'Task #$taskId'),
        'start_minutes': startMinutes,
        'end_minutes': endMinutes,
        'duration_hours': durationHours?.toDouble(),
        'duration_minutes': _resolveDayEntryDurationMinutes(
          durationHours: durationHours,
          startMinutes: startMinutes,
          endMinutes: endMinutes,
        ),
        'billable_value': billableValue ?? 0,
        'note': note ?? '',
      };
    }).toList();

    return _ClockworkTimeEntrySourceData(
      projects: projects,
      tasks: tasks,
      entries: entries,
    );
  }

  int _compareDayEntries(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final leftStart = left['start_minutes'] as int?;
    final rightStart = right['start_minutes'] as int?;

    if (leftStart == null && rightStart != null) {
      return 1;
    }
    if (leftStart != null && rightStart == null) {
      return -1;
    }
    if (leftStart != null && rightStart != null) {
      final compare = leftStart.compareTo(rightStart);
      if (compare != 0) {
        return compare;
      }
    }

    final taskCompare = ((left['task_name'] as String?) ?? '')
        .toLowerCase()
        .compareTo(((right['task_name'] as String?) ?? '').toLowerCase());
    if (taskCompare != 0) {
      return taskCompare;
    }

    return (left['id'] as int).compareTo(right['id'] as int);
  }

  int _compareWeekRows(Map<String, dynamic> left, Map<String, dynamic> right) {
    final projectCompare = (left['project_name'] as String)
        .toLowerCase()
        .compareTo((right['project_name'] as String).toLowerCase());
    if (projectCompare != 0) {
      return projectCompare;
    }

    final taskCompare = (left['task_name'] as String).toLowerCase().compareTo(
      (right['task_name'] as String).toLowerCase(),
    );
    if (taskCompare != 0) {
      return taskCompare;
    }

    final billableCompare = (right['billable_value'] as int).compareTo(
      left['billable_value'] as int,
    );
    if (billableCompare != 0) {
      return billableCompare;
    }

    final projectIdCompare = (left['project_id'] as int).compareTo(
      right['project_id'] as int,
    );
    if (projectIdCompare != 0) {
      return projectIdCompare;
    }

    final taskIdCompare = (left['task_id'] as int).compareTo(
      right['task_id'] as int,
    );
    if (taskIdCompare != 0) {
      return taskIdCompare;
    }

    return 0;
  }

  int _compareWeekEntriesForAggregation(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final leftDate = left['date'] as int?;
    final rightDate = right['date'] as int?;

    if (leftDate == null && rightDate != null) {
      return 1;
    }
    if (leftDate != null && rightDate == null) {
      return -1;
    }
    if (leftDate != null && rightDate != null) {
      final dateCompare = leftDate.compareTo(rightDate);
      if (dateCompare != 0) {
        return dateCompare;
      }
    }

    final leftStart = left['start_minutes'] as int?;
    final rightStart = right['start_minutes'] as int?;

    if (leftStart == null && rightStart != null) {
      return 1;
    }
    if (leftStart != null && rightStart == null) {
      return -1;
    }
    if (leftStart != null && rightStart != null) {
      final startCompare = leftStart.compareTo(rightStart);
      if (startCompare != 0) {
        return startCompare;
      }
    }

    final leftId = left['id'] as int? ?? 0;
    final rightId = right['id'] as int? ?? 0;
    return leftId.compareTo(rightId);
  }

  int? _resolveDayEntryDurationMinutes({
    required num? durationHours,
    required int? startMinutes,
    required int? endMinutes,
  }) {
    if (durationHours != null && durationHours > 0) {
      return (durationHours * 60).round();
    }

    if (startMinutes != null &&
        endMinutes != null &&
        endMinutes > startMinutes) {
      return endMinutes - startMinutes;
    }

    return null;
  }

  Future<RequiredDefinitionsManifest> _getRequiredDefinitionsManifest() async {
    final cachedManifest = _requiredDefinitionsManifest;
    if (cachedManifest != null) {
      return cachedManifest;
    }

    final rawManifest = await _requiredDefinitionsLoader();
    final decodedManifest = jsonDecode(rawManifest);

    if (decodedManifest is! Map<String, dynamic>) {
      throw Exception(
        'The required definitions manifest must be a top-level JSON object.',
      );
    }

    final manifest = RequiredDefinitionsManifest.fromJson(decodedManifest);
    _requiredDefinitionsManifest = manifest;
    return manifest;
  }

  Future<_ClockworkDayDefinitions> _loadClockworkDayDefinitions(
    DatabaseExecutor db,
    RequiredDefinitionsManifest manifest,
  ) async {
    final dayPage = manifest.dayPage;
    final projectKind = await _requireActiveEntityKindByName(
      db,
      dayPage.projectKindName,
    );
    final taskKind = await _requireActiveEntityKindByName(
      db,
      dayPage.taskKindName,
    );
    final timeEntryKind = await _requireActiveEntityKindByName(
      db,
      dayPage.timeEntryKindName,
    );
    final nameCompKind = await _requireActiveCompKindByName(
      db,
      dayPage.nameCompKindName,
    );
    final parentCompKind = await _requireActiveCompKindByName(
      db,
      dayPage.parentCompKindName,
    );
    final durationCompKind = await _requireActiveCompKindByName(
      db,
      dayPage.durationCompKindName,
    );
    final dateCompKind = await _requireActiveCompKindByName(
      db,
      dayPage.dateCompKindName,
    );
    final noteCompKind = await _requireActiveCompKindByName(
      db,
      dayPage.noteCompKindName,
    );
    final billableCompKind = await _requireActiveCompKindByName(
      db,
      dayPage.billableCompKindName,
    );
    final startTimeCompKind = await _requireActiveCompKindByName(
      db,
      dayPage.startTimeCompKindName,
    );
    final endTimeCompKind = await _requireActiveCompKindByName(
      db,
      dayPage.endTimeCompKindName,
    );

    return _ClockworkDayDefinitions(
      projectKindId: projectKind['id'] as int,
      taskKindId: taskKind['id'] as int,
      timeEntryKindId: timeEntryKind['id'] as int,
      nameCompKindId: nameCompKind['id'] as int,
      parentCompKindId: parentCompKind['id'] as int,
      durationCompKindId: durationCompKind['id'] as int,
      dateCompKindId: dateCompKind['id'] as int,
      noteCompKindId: noteCompKind['id'] as int,
      billableCompKindId: billableCompKind['id'] as int,
      startTimeCompKindId: startTimeCompKind['id'] as int,
      endTimeCompKindId: endTimeCompKind['id'] as int,
    );
  }

  Future<void> _ensureRequiredDefinitionsInTransaction(
    DatabaseExecutor db,
    RequiredDefinitionsManifest manifest,
  ) async {
    final compKindIdsByName = <String, int>{};

    for (final compKindDefinition in manifest.componentKinds) {
      final compKind = await _upsertRequiredCompKind(db, compKindDefinition);
      final compKindId = compKind['id'] as int;
      compKindIdsByName[compKindDefinition.name] = compKindId;

      await _syncRequiredEnumOptions(
        db,
        compKindId: compKindId,
        definition: compKindDefinition,
      );
    }

    for (final entityKindDefinition in manifest.entityKinds) {
      final requiredCompKindIds = entityKindDefinition.componentNames.map((
        componentName,
      ) {
        final compKindId = compKindIdsByName[componentName];
        if (compKindId == null) {
          throw Exception(
            'Required entity kind "${entityKindDefinition.name}" '
            'references unknown component kind "$componentName".',
          );
        }
        return compKindId;
      }).toList();

      await _upsertRequiredEntityKind(
        db,
        definition: entityKindDefinition,
        requiredCompKindIds: requiredCompKindIds,
      );
    }

    await _loadClockworkDayDefinitions(db, manifest);
  }

  Future<Map<String, dynamic>> _upsertRequiredCompKind(
    DatabaseExecutor db,
    RequiredCompKindDefinition definition,
  ) async {
    final normalizedName = _normalizeRequiredText(
      definition.name,
      'Required component kind name',
    );
    final normalizedDisplayName = _normalizeRequiredText(
      definition.displayName,
      'Required component kind display name',
    );
    final normalizedStorageType = _normalizeStorageType(definition.storageType);
    final resolvedSemanticType = _resolveSemanticType(
      normalizedStorageType,
      definition.semanticType,
    );

    _ensureSemanticTypeIsCompatible(
      normalizedStorageType,
      resolvedSemanticType,
    );

    final existing = await _findCompKindByName(
      db,
      normalizedName,
      activeOnly: false,
    );

    if (existing == null) {
      final compKindId = await db.insert('comp_kinds', {
        'name': normalizedName,
        'display_name': normalizedDisplayName,
        'storage_type': normalizedStorageType,
        'semantic_type': resolvedSemanticType,
        'status': activeStatus,
      });

      return {
        'id': compKindId,
        'name': normalizedName,
        'display_name': normalizedDisplayName,
        'storage_type': normalizedStorageType,
        'semantic_type': resolvedSemanticType,
        'status': activeStatus,
      };
    }

    final existingId = existing['id'] as int;
    final previousStorageType = existing['storage_type'] as String;

    if (previousStorageType != normalizedStorageType) {
      final hasStoredValues = await _compKindHasStoredValues(db, existingId);
      if (hasStoredValues) {
        throw Exception(
          'Required component kind "$normalizedName" cannot change storage '
          'type because stored values already exist.',
        );
      }
    }

    await db.update(
      'comp_kinds',
      {
        'display_name': normalizedDisplayName,
        'storage_type': normalizedStorageType,
        'semantic_type': resolvedSemanticType,
        'status': activeStatus,
      },
      where: 'id = ?',
      whereArgs: [existingId],
    );

    if (resolvedSemanticType != semanticEnum) {
      await db.delete(
        'comp_kind_enum_options',
        where: 'comp_kind_id = ?',
        whereArgs: [existingId],
      );
    }

    return {
      ...existing,
      'display_name': normalizedDisplayName,
      'storage_type': normalizedStorageType,
      'semantic_type': resolvedSemanticType,
      'status': activeStatus,
    };
  }

  Future<void> _syncRequiredEnumOptions(
    DatabaseExecutor db, {
    required int compKindId,
    required RequiredCompKindDefinition definition,
  }) async {
    if (definition.enumOptions.isEmpty) {
      return;
    }

    await _requireEnumCompKind(db, compKindId);
    final existingOptions = await db.query(
      'comp_kind_enum_options',
      where: 'comp_kind_id = ?',
      whereArgs: [compKindId],
    );
    final existingOptionsByValue = <String, Map<String, dynamic>>{
      for (final row in existingOptions)
        row['value'] as String: Map<String, dynamic>.from(row),
    };

    for (final enumOptionDefinition in definition.enumOptions) {
      final normalizedValue = _normalizeRequiredText(
        enumOptionDefinition.value,
        'Required enum option value',
      );
      final normalizedDisplayLabel = _normalizeRequiredText(
        enumOptionDefinition.displayLabel,
        'Required enum option display label',
      );
      final normalizedSortOrder = _normalizeSortOrder(
        enumOptionDefinition.sortOrder,
      );
      final existingOption = existingOptionsByValue[normalizedValue];

      if (existingOption == null) {
        await db.insert('comp_kind_enum_options', {
          'comp_kind_id': compKindId,
          'value': normalizedValue,
          'display_label': normalizedDisplayLabel,
          'sort_order': normalizedSortOrder,
        });
        continue;
      }

      await db.update(
        'comp_kind_enum_options',
        {
          'display_label': normalizedDisplayLabel,
          'sort_order': normalizedSortOrder,
        },
        where: 'id = ?',
        whereArgs: [existingOption['id']],
      );
    }
  }

  Future<void> _upsertRequiredEntityKind(
    DatabaseExecutor db, {
    required RequiredEntityKindDefinition definition,
    required List<int> requiredCompKindIds,
  }) async {
    final normalizedName = _normalizeRequiredText(
      definition.name,
      'Required entity kind name',
    );
    final normalizedDisplayName = _normalizeRequiredText(
      definition.displayName,
      'Required entity kind display name',
    );
    final existing = await _findEntityKindByName(
      db,
      normalizedName,
      activeOnly: false,
    );

    late final int entityKindId;
    if (existing == null) {
      entityKindId = await db.insert('entity_kinds', {
        'name': normalizedName,
        'display_name': normalizedDisplayName,
        'status': activeStatus,
      });
    } else {
      entityKindId = existing['id'] as int;
      await db.update(
        'entity_kinds',
        {'display_name': normalizedDisplayName, 'status': activeStatus},
        where: 'id = ?',
        whereArgs: [entityKindId],
      );
    }

    for (final compKindId in requiredCompKindIds) {
      await _ensureEntityKindLink(
        db,
        entityKindId: entityKindId,
        compKindId: compKindId,
      );
    }
  }

  Future<Map<String, dynamic>> _requireActiveEntityKindByName(
    DatabaseExecutor db,
    String name,
  ) async {
    final entityKind = await _findEntityKindByName(db, name);
    if (entityKind == null) {
      throw Exception('Required entity kind "$name" is missing or inactive.');
    }
    return entityKind;
  }

  Future<Map<String, dynamic>> _requireActiveCompKindByName(
    DatabaseExecutor db,
    String name,
  ) async {
    final compKind = await _findCompKindByName(db, name);
    if (compKind == null) {
      throw Exception(
        'Required component kind "$name" is missing or inactive.',
      );
    }
    return compKind;
  }

  Future<Map<String, dynamic>?> _findEntityKindByName(
    DatabaseExecutor db,
    String name, {
    bool activeOnly = true,
  }) async {
    final rows = await db.query(
      'entity_kinds',
      where: activeOnly ? 'name = ? AND status = ?' : 'name = ?',
      whereArgs: activeOnly ? [name, activeStatus] : [name],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>?> _findCompKindByName(
    DatabaseExecutor db,
    String name, {
    bool activeOnly = true,
  }) async {
    final rows = await db.query(
      'comp_kinds',
      where: activeOnly ? 'name = ? AND status = ?' : 'name = ?',
      whereArgs: activeOnly ? [name, activeStatus] : [name],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Map<String, dynamic>.from(rows.first);
  }

  Future<void> _ensureEntityKindLink(
    DatabaseExecutor db, {
    required int entityKindId,
    required int compKindId,
  }) async {
    await db.insert('entity_kind_comp_kinds', {
      'entity_kind_id': entityKindId,
      'comp_kind_id': compKindId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int?> _getStoredEntityReferenceValue(
    DatabaseExecutor db, {
    required int entityId,
    required int compKindId,
  }) async {
    final rows = await db.query(
      'entity_comps',
      columns: ['value'],
      where: 'entity_id = ? AND kind_id = ?',
      whereArgs: [entityId, compKindId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.first['value'] as int?;
  }

  Object? _componentValueForKindId(
    Map<String, dynamic> entity,
    int compKindId,
  ) {
    final components = List<Map<String, dynamic>>.from(
      entity['components'] as List<dynamic>? ?? const [],
    );

    for (final component in components) {
      if (component['id'] == compKindId) {
        return component['value'];
      }
    }

    return null;
  }

  DateTime _normalizeDayDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _weekStartForDate(DateTime value) {
    final day = _normalizeDayDate(value);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  int _normalizeDayMinutes(
    int value,
    String label, {
    bool allowEndOfDay = false,
  }) {
    final maxValue = allowEndOfDay ? 1440 : 1439;
    if (value < 0 || value > maxValue) {
      final upperBound = allowEndOfDay ? '24:00' : '23:59';
      throw Exception('$label must be between 00:00 and $upperBound.');
    }

    if (allowEndOfDay && value == 1440) {
      return value;
    }

    return value;
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

  static String defaultDatabaseDirectoryPath() {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.trim().isNotEmpty) {
        return path.join(appData, publisherName, productName);
      }
    }

    final homePath = Platform.environment['HOME'];

    if (Platform.isMacOS && homePath != null && homePath.trim().isNotEmpty) {
      return path.join(
        homePath,
        'Library',
        'Application Support',
        applicationId,
      );
    }

    if (Platform.isLinux && homePath != null && homePath.trim().isNotEmpty) {
      final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
      if (xdgDataHome != null && xdgDataHome.trim().isNotEmpty) {
        return path.join(xdgDataHome, applicationId);
      }

      return path.join(homePath, '.local', 'share', applicationId);
    }

    return path.join(Directory.current.path, '.clockwork');
  }

  static String defaultDatabasePath({String dbName = 'clockwork.db'}) {
    return path.join(defaultDatabaseDirectoryPath(), dbName);
  }
}

class _ClockworkDayDefinitions {
  const _ClockworkDayDefinitions({
    required this.projectKindId,
    required this.taskKindId,
    required this.timeEntryKindId,
    required this.nameCompKindId,
    required this.parentCompKindId,
    required this.durationCompKindId,
    required this.dateCompKindId,
    required this.noteCompKindId,
    required this.billableCompKindId,
    required this.startTimeCompKindId,
    required this.endTimeCompKindId,
  });

  final int projectKindId;
  final int taskKindId;
  final int timeEntryKindId;
  final int nameCompKindId;
  final int parentCompKindId;
  final int durationCompKindId;
  final int dateCompKindId;
  final int noteCompKindId;
  final int billableCompKindId;
  final int startTimeCompKindId;
  final int endTimeCompKindId;
}

class _ClockworkTimeEntrySourceData {
  _ClockworkTimeEntrySourceData({
    required List<Map<String, dynamic>> projects,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> entries,
  }) : projects = List<Map<String, dynamic>>.unmodifiable(projects),
       tasks = List<Map<String, dynamic>>.unmodifiable(tasks),
       entries = List<Map<String, dynamic>>.unmodifiable(entries);

  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> entries;
}

class _ClockworkWeekRowKey {
  const _ClockworkWeekRowKey({
    required this.projectId,
    required this.taskId,
    required this.billableValue,
  });

  final int projectId;
  final int taskId;
  final int billableValue;

  @override
  bool operator ==(Object other) {
    return other is _ClockworkWeekRowKey &&
        other.projectId == projectId &&
        other.taskId == taskId &&
        other.billableValue == billableValue;
  }

  @override
  int get hashCode => Object.hash(projectId, taskId, billableValue);
}

class _ClockworkWeekRowAccumulator {
  _ClockworkWeekRowAccumulator({
    required this.projectId,
    required this.projectName,
    required this.taskId,
    required this.taskName,
    required this.billableValue,
  });

  final int projectId;
  final String projectName;
  final int taskId;
  final String taskName;
  final int billableValue;
  final List<int> _dayMinutes = List<int>.filled(7, 0);
  final List<List<String>> _dayNoteLines = List.generate(7, (_) => <String>[]);
  final List<Set<String>> _seenDayNotes = List.generate(7, (_) => <String>{});

  void addMinutes(int dayIndex, int durationMinutes) {
    _dayMinutes[dayIndex] += durationMinutes;
  }

  void addNoteLine(int dayIndex, String? note) {
    final normalizedNote = note?.trim();
    if (normalizedNote == null || normalizedNote.isEmpty) {
      return;
    }

    if (_seenDayNotes[dayIndex].add(normalizedNote)) {
      _dayNoteLines[dayIndex].add(normalizedNote);
    }
  }

  Map<String, dynamic> toMap() {
    final dayMinutes = List<int>.unmodifiable(_dayMinutes);
    final dayNoteLines = List<List<String>>.unmodifiable(
      _dayNoteLines.map(List<String>.unmodifiable),
    );
    final totalMinutes = dayMinutes.fold<int>(
      0,
      (total, value) => total + value,
    );

    return {
      'project_id': projectId,
      'project_name': projectName,
      'task_id': taskId,
      'task_name': taskName,
      'billable_value': billableValue,
      'day_minutes': dayMinutes,
      'day_note_lines': dayNoteLines,
      'total_minutes': totalMinutes,
    };
  }
}
