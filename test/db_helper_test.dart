import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:clockwork/db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late DbHelper helper;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    tempDirectory = await Directory.systemTemp.createTemp('clockwork_test_');
    helper = DbHelper(
      dbName: 'clockwork_test.db',
      databaseDirectory: tempDirectory.path,
    );

    await helper.db;
  });

  tearDown(() async {
    await helper.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'component kinds and entity kinds soft delete and restore cleanly',
    () async {
      final compKindId = await helper.createCompKind(
        name: 'name',
        displayName: 'Name',
        storageType: DbHelper.storageText,
      );
      final entityKindId = await helper.createEntityKind(
        name: 'customer',
        displayName: 'Customer',
        compKindIds: [compKindId],
      );

      expect(await helper.getAllCompKinds(), hasLength(1));
      expect(await helper.getAllEntityKinds(), hasLength(1));

      await helper.softDeleteCompKind(compKindId);
      await helper.softDeleteEntityKind(entityKindId);

      expect(await helper.getAllCompKinds(), isEmpty);
      expect(await helper.getAllEntityKinds(), isEmpty);

      final allCompKinds = await helper.getAllCompKinds(includeInactive: true);
      final allEntityKinds = await helper.getAllEntityKinds(
        includeInactive: true,
      );

      expect(allCompKinds.single['status'], DbHelper.deletedStatus);
      expect(allEntityKinds.single['status'], DbHelper.deletedStatus);

      await helper.restoreCompKind(compKindId);
      await helper.restoreEntityKind(entityKindId);

      expect(await helper.getAllCompKinds(), hasLength(1));
      expect(await helper.getAllEntityKinds(), hasLength(1));
    },
  );

  test('entity CRUD stores and updates typed component values', () async {
    final nameKindId = await helper.createCompKind(
      name: 'name',
      displayName: 'Name',
      storageType: DbHelper.storageText,
    );
    final activeKindId = await helper.createCompKind(
      name: 'active',
      displayName: 'Active',
      storageType: DbHelper.storageInteger,
      semanticType: DbHelper.semanticBoolean,
    );
    final dateKindId = await helper.createCompKind(
      name: 'due_date',
      displayName: 'Due Date',
      storageType: DbHelper.storageInteger,
      semanticType: DbHelper.semanticDate,
    );
    final statusKindId = await helper.createCompKind(
      name: 'status',
      displayName: 'Status',
      storageType: DbHelper.storageText,
      semanticType: DbHelper.semanticEnum,
    );
    final parentKindId = await helper.createCompKind(
      name: 'parent',
      displayName: 'Parent',
      storageType: DbHelper.storageEntity,
    );

    await helper.createEnumOption(
      compKindId: statusKindId,
      value: 'open',
      displayLabel: 'Open',
    );
    await helper.createEnumOption(
      compKindId: statusKindId,
      value: 'closed',
      displayLabel: 'Closed',
    );

    final taskKindId = await helper.createEntityKind(
      name: 'task',
      displayName: 'Task',
      compKindIds: [
        nameKindId,
        activeKindId,
        dateKindId,
        statusKindId,
        parentKindId,
      ],
    );

    final parentEntityId = await helper.createEntity(
      kindId: taskKindId,
      componentValues: {nameKindId: 'Parent Task'},
    );
    final dueDate = DateTime(2026, 4, 3).millisecondsSinceEpoch;

    final childEntityId = await helper.createEntity(
      kindId: taskKindId,
      componentValues: {
        nameKindId: 'Child Task',
        activeKindId: 1,
        dateKindId: dueDate,
        statusKindId: 'open',
        parentKindId: parentEntityId,
      },
    );

    var entity = await helper.getEntity(childEntityId);
    expect(entity, isNotNull);
    expect(_valueForComponent(entity!, 'name'), 'Child Task');
    expect(_valueForComponent(entity, 'active'), 1);
    expect(_valueForComponent(entity, 'due_date'), dueDate);
    expect(_valueForComponent(entity, 'status'), 'open');
    expect(_valueForComponent(entity, 'parent'), parentEntityId);

    await helper.updateEntity(
      entityId: childEntityId,
      kindId: taskKindId,
      componentValues: {
        nameKindId: 'Child Task Updated',
        activeKindId: 0,
        statusKindId: null,
      },
    );

    entity = await helper.getEntity(childEntityId);
    expect(entity, isNotNull);
    expect(_valueForComponent(entity!, 'name'), 'Child Task Updated');
    expect(_valueForComponent(entity, 'active'), 0);
    expect(_valueForComponent(entity, 'due_date'), dueDate);
    expect(_valueForComponent(entity, 'status'), isNull);

    await helper.deleteEntity(childEntityId);
    expect(await helper.getEntity(childEntityId), isNull);
  });

  test(
    'removing linked component kinds deletes stored values for that field',
    () async {
      final notesKindId = await helper.createCompKind(
        name: 'notes',
        displayName: 'Notes',
        storageType: DbHelper.storageText,
      );
      final scoreKindId = await helper.createCompKind(
        name: 'score',
        displayName: 'Score',
        storageType: DbHelper.storageInteger,
      );

      final entityKindId = await helper.createEntityKind(
        name: 'record',
        displayName: 'Record',
        compKindIds: [notesKindId, scoreKindId],
      );

      final entityId = await helper.createEntity(
        kindId: entityKindId,
        componentValues: {notesKindId: 'Hello', scoreKindId: 12},
      );

      final database = await helper.db;
      expect(
        await _countRows(
          database,
          'SELECT COUNT(*) FROM integer_comps WHERE entity_id = ? AND kind_id = ?',
          [entityId, scoreKindId],
        ),
        1,
      );

      await helper.updateEntityKind(
        id: entityKindId,
        name: 'record',
        displayName: 'Record',
        compKindIds: [notesKindId],
      );

      expect(
        await _countRows(
          database,
          'SELECT COUNT(*) FROM integer_comps WHERE entity_id = ? AND kind_id = ?',
          [entityId, scoreKindId],
        ),
        0,
      );
    },
  );

  test(
    'validation rejects invalid enum values and referenced entity delete',
    () async {
      final statusKindId = await helper.createCompKind(
        name: 'status',
        displayName: 'Status',
        storageType: DbHelper.storageText,
        semanticType: DbHelper.semanticEnum,
      );
      final parentKindId = await helper.createCompKind(
        name: 'parent',
        displayName: 'Parent',
        storageType: DbHelper.storageEntity,
      );

      await helper.createEnumOption(
        compKindId: statusKindId,
        value: 'open',
        displayLabel: 'Open',
      );

      final entityKindId = await helper.createEntityKind(
        name: 'item',
        displayName: 'Item',
        compKindIds: [statusKindId, parentKindId],
      );

      await expectLater(
        () => helper.createEntity(
          kindId: entityKindId,
          componentValues: {statusKindId: 'invalid'},
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('not a valid enum option'),
          ),
        ),
      );

      final parentEntityId = await helper.createEntity(kindId: entityKindId);
      await helper.createEntity(
        kindId: entityKindId,
        componentValues: {parentKindId: parentEntityId},
      );

      await expectLater(
        () => helper.deleteEntity(parentEntityId),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('references it'),
          ),
        ),
      );
    },
  );

  test(
    'ensureRequiredDefinitions imports bundled definitions idempotently',
    () async {
      await helper.ensureRequiredDefinitions();
      await helper.ensureRequiredDefinitions();

      final allCompKinds = await helper.getAllCompKinds();
      final allEntityKinds = await helper.getAllEntityKinds();
      final timeEntryKindId = _entityKindIdByName(allEntityKinds, 'time_entry');
      final timeEntryCompKinds = await helper.getCompKindsForEntityKind(
        timeEntryKindId,
      );
      final timeEntryCompKindNames = timeEntryCompKinds
          .map((componentKind) => componentKind['name'] as String)
          .toList();

      expect(
        allCompKinds.map((componentKind) => componentKind['name'] as String),
        containsAll([
          'name',
          'parent',
          'duration',
          'date',
          'note',
          'start_time',
          'end_time',
        ]),
      );
      expect(
        allEntityKinds.map((entityKind) => entityKind['name'] as String),
        containsAll(['project', 'task', 'time_entry']),
      );
      expect(
        timeEntryCompKindNames,
        containsAll([
          'parent',
          'duration',
          'date',
          'note',
          'start_time',
          'end_time',
        ]),
      );
    },
  );

  test(
    'ensureRequiredDefinitions restores soft-deleted required definitions',
    () async {
      await helper.ensureRequiredDefinitions();

      final allCompKinds = await helper.getAllCompKinds();
      final allEntityKinds = await helper.getAllEntityKinds();
      final startTimeCompKindId = _compKindIdByName(allCompKinds, 'start_time');
      final timeEntryKindId = _entityKindIdByName(allEntityKinds, 'time_entry');

      await helper.softDeleteCompKind(startTimeCompKindId);
      await helper.softDeleteEntityKind(timeEntryKindId);

      await helper.ensureRequiredDefinitions();

      final restoredCompKinds = await helper.getAllCompKinds();
      final restoredEntityKinds = await helper.getAllEntityKinds();

      expect(
        restoredCompKinds.map(
          (componentKind) => componentKind['name'] as String,
        ),
        contains('start_time'),
      );
      expect(
        restoredEntityKinds.map((entityKind) => entityKind['name'] as String),
        contains('time_entry'),
      );
    },
  );

  test(
    'ensureRequiredDefinitions preserves extra links on required entity kinds',
    () async {
      final definitions = await _loadRequiredDayDefinitions(helper);
      final extraCompKindId = await helper.createCompKind(
        name: 'billable_code',
        displayName: 'Billable Code',
        storageType: DbHelper.storageText,
      );
      final timeEntryKind = await helper.getEntityKind(
        definitions.timeEntryKindId,
      );

      await helper.updateEntityKind(
        id: definitions.timeEntryKindId,
        name: 'time_entry',
        displayName: 'Time Entry',
        compKindIds: [
          ...(timeEntryKind?['comp_kind_ids'] as List<dynamic>).cast<int>(),
          extraCompKindId,
        ],
      );

      await helper.ensureRequiredDefinitions();

      final timeEntryCompKinds = await helper.getCompKindsForEntityKind(
        definitions.timeEntryKindId,
      );

      expect(
        timeEntryCompKinds.map(
          (componentKind) => componentKind['name'] as String,
        ),
        contains('billable_code'),
      );
    },
  );

  test('saveDayEntry stores and updates project task time rows', () async {
    final definitions = await _loadRequiredDayDefinitions(helper);

    final projectId = await helper.createEntity(
      kindId: definitions.projectKindId,
      componentValues: {definitions.nameCompKindId: 'Project Atlas'},
    );
    final taskId = await helper.createEntity(
      kindId: definitions.taskKindId,
      componentValues: {
        definitions.nameCompKindId: 'Client Workshop',
        definitions.parentCompKindId: projectId,
      },
    );

    final entryId = await helper.saveDayEntry(
      date: DateTime(2026, 4, 3),
      projectId: projectId,
      taskId: taskId,
      startMinutes: 9 * 60,
      endMinutes: 10 * 60 + 30,
      note: 'Discovery session',
    );

    var entity = await helper.getEntity(entryId);
    expect(entity, isNotNull);
    expect(_valueForComponent(entity!, 'parent'), taskId);
    expect(
      _valueForComponent(entity, 'date'),
      DateTime(2026, 4, 3).millisecondsSinceEpoch,
    );
    expect(_valueForComponent(entity, 'duration'), 1.5);
    expect(_valueForComponent(entity, 'start_time'), 540);
    expect(_valueForComponent(entity, 'end_time'), 630);
    expect(_valueForComponent(entity, 'note'), 'Discovery session');

    await helper.saveDayEntry(
      entryId: entryId,
      date: DateTime(2026, 4, 3),
      projectId: projectId,
      taskId: taskId,
      startMinutes: 9 * 60,
      endMinutes: 11 * 60,
      note: 'Workshop extended',
    );

    final dayData = await helper.getDayPageData(DateTime(2026, 4, 3));
    final entries = List<Map<String, dynamic>>.from(
      dayData['entries'] as List<dynamic>? ?? const [],
    );

    expect(entries, hasLength(1));
    expect(entries.single['project_id'], projectId);
    expect(entries.single['task_id'], taskId);
    expect(entries.single['start_minutes'], 540);
    expect(entries.single['end_minutes'], 660);
    expect(entries.single['duration_hours'], 2.0);
    expect(entries.single['note'], 'Workshop extended');

    entity = await helper.getEntity(entryId);
    expect(entity, isNotNull);
    expect(_valueForComponent(entity!, 'duration'), 2.0);
    expect(_valueForComponent(entity, 'end_time'), 660);
    expect(_valueForComponent(entity, 'note'), 'Workshop extended');
  });
}

Object? _valueForComponent(Map<String, dynamic> entity, String componentName) {
  final components = List<Map<String, dynamic>>.from(
    entity['components'] as List<dynamic>? ?? const [],
  );

  for (final component in components) {
    if (component['name'] == componentName) {
      return component['value'];
    }
  }

  fail('Expected component "$componentName" to exist.');
}

Future<int> _countRows(
  Database database,
  String sql,
  List<Object?> arguments,
) async {
  final rows = await database.rawQuery(sql, arguments);
  if (rows.isEmpty) {
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

Future<_ClockworkDayTestDefinitions> _loadRequiredDayDefinitions(
  DbHelper helper,
) async {
  await helper.ensureRequiredDefinitions();
  final allCompKinds = await helper.getAllCompKinds();
  final allEntityKinds = await helper.getAllEntityKinds();

  final nameCompKindId = _compKindIdByName(allCompKinds, 'name');
  final parentCompKindId = _compKindIdByName(allCompKinds, 'parent');
  final projectKindId = _entityKindIdByName(allEntityKinds, 'project');
  final taskKindId = _entityKindIdByName(allEntityKinds, 'task');
  final timeEntryKindId = _entityKindIdByName(allEntityKinds, 'time_entry');

  return _ClockworkDayTestDefinitions(
    nameCompKindId: nameCompKindId,
    parentCompKindId: parentCompKindId,
    projectKindId: projectKindId,
    taskKindId: taskKindId,
    timeEntryKindId: timeEntryKindId,
  );
}

class _ClockworkDayTestDefinitions {
  const _ClockworkDayTestDefinitions({
    required this.nameCompKindId,
    required this.parentCompKindId,
    required this.projectKindId,
    required this.taskKindId,
    required this.timeEntryKindId,
  });

  final int nameCompKindId;
  final int parentCompKindId;
  final int projectKindId;
  final int taskKindId;
  final int timeEntryKindId;
}

int _compKindIdByName(List<Map<String, dynamic>> componentKinds, String name) {
  return componentKinds.singleWhere(
        (componentKind) => componentKind['name'] == name,
      )['id']
      as int;
}

int _entityKindIdByName(List<Map<String, dynamic>> entityKinds, String name) {
  return entityKinds.singleWhere(
        (entityKind) => entityKind['name'] == name,
      )['id']
      as int;
}
