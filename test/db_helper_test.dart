import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:clockwork/db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late DbHelper helper;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
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
          'billable',
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
          'billable',
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
    expect(_valueForComponent(entity, 'billable'), 1);
    expect(_valueForComponent(entity, 'note'), 'Discovery session');

    await helper.saveDayEntry(
      entryId: entryId,
      date: DateTime(2026, 4, 3),
      projectId: projectId,
      taskId: taskId,
      startMinutes: 9 * 60,
      endMinutes: 11 * 60,
      billableValue: 0,
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
    expect(entries.single['billable_value'], 0);
    expect(entries.single['note'], 'Workshop extended');

    entity = await helper.getEntity(entryId);
    expect(entity, isNotNull);
    expect(_valueForComponent(entity!, 'duration'), 2.0);
    expect(_valueForComponent(entity, 'end_time'), 660);
    expect(_valueForComponent(entity, 'billable'), 0);
    expect(_valueForComponent(entity, 'note'), 'Workshop extended');
  });

  test('saveDayEntry accepts 24:00 as an end time', () async {
    final definitions = await _loadRequiredDayDefinitions(helper);

    final projectId = await helper.createEntity(
      kindId: definitions.projectKindId,
      componentValues: {definitions.nameCompKindId: 'Project Atlas'},
    );
    final taskId = await helper.createEntity(
      kindId: definitions.taskKindId,
      componentValues: {
        definitions.nameCompKindId: 'Late Support',
        definitions.parentCompKindId: projectId,
      },
    );

    final entryId = await helper.saveDayEntry(
      date: DateTime(2026, 4, 5),
      projectId: projectId,
      taskId: taskId,
      startMinutes: 23 * 60,
      endMinutes: 24 * 60,
      note: 'After-hours support',
    );

    final entity = await helper.getEntity(entryId);
    expect(entity, isNotNull);
    expect(_valueForComponent(entity!, 'start_time'), 1380);
    expect(_valueForComponent(entity, 'end_time'), 1440);
    expect(_valueForComponent(entity, 'duration'), 1.0);

    final dayData = await helper.getDayPageData(DateTime(2026, 4, 5));
    final entries = List<Map<String, dynamic>>.from(
      dayData['entries'] as List<dynamic>? ?? const [],
    );

    expect(entries, hasLength(1));
    expect(entries.single['start_minutes'], 1380);
    expect(entries.single['end_minutes'], 1440);
    expect(entries.single['duration_hours'], 1.0);
  });

  test('getDayPageData treats missing billable values as false', () async {
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

    await helper.createEntity(
      kindId: definitions.timeEntryKindId,
      componentValues: {
        definitions.parentCompKindId: taskId,
        definitions.dateCompKindId: DateTime(2026, 4, 4).millisecondsSinceEpoch,
        definitions.durationCompKindId: 1.0,
        definitions.startTimeCompKindId: 9 * 60,
        definitions.endTimeCompKindId: 10 * 60,
        definitions.noteCompKindId: 'Legacy entry',
      },
    );

    final dayData = await helper.getDayPageData(DateTime(2026, 4, 4));
    final entries = List<Map<String, dynamic>>.from(
      dayData['entries'] as List<dynamic>? ?? const [],
    );

    expect(entries, hasLength(1));
    expect(entries.single['billable_value'], 0);
  });

  test('getWeekPageData loads the containing Monday to Sunday week', () async {
    final definitions = await _loadRequiredDayDefinitions(helper);
    final ids = await _createProjectAndTask(
      helper,
      definitions,
      projectName: 'Project Atlas',
      taskName: 'Client Workshop',
    );

    await helper.saveDayEntry(
      date: DateTime(2026, 3, 30),
      projectId: ids.projectId,
      taskId: ids.taskId,
      startMinutes: 9 * 60,
      endMinutes: 10 * 60,
    );
    await helper.saveDayEntry(
      date: DateTime(2026, 4, 1),
      projectId: ids.projectId,
      taskId: ids.taskId,
      startMinutes: 9 * 60,
      endMinutes: 11 * 60,
    );
    await helper.saveDayEntry(
      date: DateTime(2026, 4, 5),
      projectId: ids.projectId,
      taskId: ids.taskId,
      startMinutes: 13 * 60,
      endMinutes: 16 * 60,
    );
    await helper.saveDayEntry(
      date: DateTime(2026, 4, 6),
      projectId: ids.projectId,
      taskId: ids.taskId,
      startMinutes: 8 * 60,
      endMinutes: 9 * 60,
    );

    final weekData = await helper.getWeekPageData(DateTime(2026, 4, 1));
    final rows = List<Map<String, dynamic>>.from(
      weekData['rows'] as List<dynamic>? ?? const [],
    );

    expect(
      weekData['week_start'],
      DateTime(2026, 3, 30).millisecondsSinceEpoch,
    );
    expect(weekData['week_end'], DateTime(2026, 4, 5).millisecondsSinceEpoch);
    expect(weekData['week_total_minutes'], 360);
    expect(rows, hasLength(1));
    expect(rows.single['day_minutes'], equals([60, 0, 120, 0, 0, 0, 180]));
    expect(rows.single['total_minutes'], 360);
  });

  test(
    'getWeekPageData groups repeated project task billable entries',
    () async {
      final definitions = await _loadRequiredDayDefinitions(helper);
      final ids = await _createProjectAndTask(
        helper,
        definitions,
        projectName: 'Project Atlas',
        taskName: 'Design Review',
      );

      await helper.saveDayEntry(
        date: DateTime(2026, 4, 7),
        projectId: ids.projectId,
        taskId: ids.taskId,
        startMinutes: 9 * 60,
        endMinutes: 9 * 60 + 30,
      );
      await helper.saveDayEntry(
        date: DateTime(2026, 4, 7),
        projectId: ids.projectId,
        taskId: ids.taskId,
        startMinutes: 10 * 60,
        endMinutes: 11 * 60,
      );
      await helper.saveDayEntry(
        date: DateTime(2026, 4, 9),
        projectId: ids.projectId,
        taskId: ids.taskId,
        startMinutes: 14 * 60,
        endMinutes: 15 * 60 + 15,
      );

      final weekData = await helper.getWeekPageData(DateTime(2026, 4, 9));
      final rows = List<Map<String, dynamic>>.from(
        weekData['rows'] as List<dynamic>? ?? const [],
      );

      expect(rows, hasLength(1));
      expect(rows.single['day_minutes'], equals([0, 90, 0, 75, 0, 0, 0]));
      expect(rows.single['total_minutes'], 165);
      expect(weekData['week_total_minutes'], 165);
    },
  );

  test(
    'getWeekPageData builds unique day note lines in start time order',
    () async {
      final definitions = await _loadRequiredDayDefinitions(helper);
      final ids = await _createProjectAndTask(
        helper,
        definitions,
        projectName: 'Project Atlas',
        taskName: 'Notes Review',
      );

      await helper.saveDayEntry(
        date: DateTime(2026, 4, 7),
        projectId: ids.projectId,
        taskId: ids.taskId,
        startMinutes: 10 * 60,
        endMinutes: 10 * 60 + 30,
        note: 'Second note',
      );
      await helper.saveDayEntry(
        date: DateTime(2026, 4, 7),
        projectId: ids.projectId,
        taskId: ids.taskId,
        startMinutes: 9 * 60,
        endMinutes: 9 * 60 + 15,
        note: 'First note',
      );
      await helper.saveDayEntry(
        date: DateTime(2026, 4, 7),
        projectId: ids.projectId,
        taskId: ids.taskId,
        startMinutes: 11 * 60,
        endMinutes: 11 * 60 + 20,
        note: 'First note',
      );
      await helper.saveDayEntry(
        date: DateTime(2026, 4, 7),
        projectId: ids.projectId,
        taskId: ids.taskId,
        startMinutes: 12 * 60,
        endMinutes: 12 * 60 + 10,
        note: '   ',
      );
      await helper.saveDayEntry(
        date: DateTime(2026, 4, 9),
        projectId: ids.projectId,
        taskId: ids.taskId,
        startMinutes: 8 * 60,
        endMinutes: 8 * 60 + 20,
        note: 'First note',
      );

      final weekData = await helper.getWeekPageData(DateTime(2026, 4, 9));
      final rows = List<Map<String, dynamic>>.from(
        weekData['rows'] as List<dynamic>? ?? const [],
      );

      expect(rows, hasLength(1));
      expect(rows.single['day_minutes'], equals([0, 75, 0, 20, 0, 0, 0]));
      expect(
        rows.single['day_note_lines'],
        equals([
          <String>[],
          ['First note', 'Second note'],
          <String>[],
          ['First note'],
          <String>[],
          <String>[],
          <String>[],
        ]),
      );
      expect(rows.single['total_minutes'], 95);
    },
  );

  test('getWeekPageData splits billable and non-billable rows', () async {
    final definitions = await _loadRequiredDayDefinitions(helper);
    final ids = await _createProjectAndTask(
      helper,
      definitions,
      projectName: 'Project Atlas',
      taskName: 'Reporting',
    );

    await helper.saveDayEntry(
      date: DateTime(2026, 4, 6),
      projectId: ids.projectId,
      taskId: ids.taskId,
      startMinutes: 9 * 60,
      endMinutes: 10 * 60,
      billableValue: 1,
      note: 'Client delivery',
    );
    await helper.saveDayEntry(
      date: DateTime(2026, 4, 8),
      projectId: ids.projectId,
      taskId: ids.taskId,
      startMinutes: 13 * 60,
      endMinutes: 14 * 60 + 30,
      billableValue: 0,
      note: 'Internal admin',
    );

    final weekData = await helper.getWeekPageData(DateTime(2026, 4, 8));
    final rows = List<Map<String, dynamic>>.from(
      weekData['rows'] as List<dynamic>? ?? const [],
    );

    expect(rows, hasLength(2));

    final billableRow = _weekRowFor(
      rows,
      projectName: 'Project Atlas',
      taskName: 'Reporting',
      billableValue: 1,
    );
    final nonBillableRow = _weekRowFor(
      rows,
      projectName: 'Project Atlas',
      taskName: 'Reporting',
      billableValue: 0,
    );

    expect(billableRow['day_minutes'], equals([60, 0, 0, 0, 0, 0, 0]));
    expect(
      billableRow['day_note_lines'],
      equals([
        ['Client delivery'],
        <String>[],
        <String>[],
        <String>[],
        <String>[],
        <String>[],
        <String>[],
      ]),
    );
    expect(billableRow['total_minutes'], 60);
    expect(nonBillableRow['day_minutes'], equals([0, 0, 90, 0, 0, 0, 0]));
    expect(
      nonBillableRow['day_note_lines'],
      equals([
        <String>[],
        <String>[],
        ['Internal admin'],
        <String>[],
        <String>[],
        <String>[],
        <String>[],
      ]),
    );
    expect(nonBillableRow['total_minutes'], 90);
    expect(weekData['week_total_minutes'], 150);
  });

  test(
    'getWeekPageData sorts rows by project then task then billable',
    () async {
      final definitions = await _loadRequiredDayDefinitions(helper);
      final atlasIds = await _createProjectAndTask(
        helper,
        definitions,
        projectName: 'Project Atlas',
        taskName: 'Analysis',
      );
      final bravoIds = await _createProjectAndTask(
        helper,
        definitions,
        projectName: 'Project Bravo',
        taskName: 'Design',
      );
      final zephyrIds = await _createProjectAndTask(
        helper,
        definitions,
        projectName: 'Project Zephyr',
        taskName: 'Support',
      );

      await helper.saveDayEntry(
        date: DateTime(2026, 4, 6),
        projectId: atlasIds.projectId,
        taskId: atlasIds.taskId,
        startMinutes: 9 * 60,
        endMinutes: 12 * 60,
        billableValue: 1,
      );
      await helper.saveDayEntry(
        date: DateTime(2026, 4, 7),
        projectId: atlasIds.projectId,
        taskId: atlasIds.taskId,
        startMinutes: 9 * 60,
        endMinutes: 12 * 60,
        billableValue: 0,
      );
      await helper.saveDayEntry(
        date: DateTime(2026, 4, 8),
        projectId: bravoIds.projectId,
        taskId: bravoIds.taskId,
        startMinutes: 9 * 60,
        endMinutes: 13 * 60,
        billableValue: 1,
      );
      await helper.saveDayEntry(
        date: DateTime(2026, 4, 9),
        projectId: zephyrIds.projectId,
        taskId: zephyrIds.taskId,
        startMinutes: 9 * 60,
        endMinutes: 11 * 60,
        billableValue: 1,
      );

      final weekData = await helper.getWeekPageData(DateTime(2026, 4, 9));
      final rows = List<Map<String, dynamic>>.from(
        weekData['rows'] as List<dynamic>? ?? const [],
      );

      expect(rows, hasLength(4));
      expect(rows[0]['project_name'], 'Project Atlas');
      expect(rows[0]['task_name'], 'Analysis');
      expect(rows[0]['billable_value'], 1);
      expect(rows[1]['project_name'], 'Project Atlas');
      expect(rows[1]['task_name'], 'Analysis');
      expect(rows[1]['billable_value'], 0);
      expect(rows[2]['project_name'], 'Project Bravo');
      expect(rows[2]['task_name'], 'Design');
      expect(rows[3]['project_name'], 'Project Zephyr');
      expect(rows[3]['task_name'], 'Support');
    },
  );

  test(
    'getWeekPageData falls back to start and end times for legacy rows',
    () async {
      final definitions = await _loadRequiredDayDefinitions(helper);
      final ids = await _createProjectAndTask(
        helper,
        definitions,
        projectName: 'Project Atlas',
        taskName: 'Legacy Support',
      );

      await helper.createEntity(
        kindId: definitions.timeEntryKindId,
        componentValues: {
          definitions.parentCompKindId: ids.taskId,
          definitions.dateCompKindId: DateTime(
            2026,
            4,
            1,
          ).millisecondsSinceEpoch,
          definitions.startTimeCompKindId: 9 * 60,
          definitions.endTimeCompKindId: 10 * 60 + 45,
          definitions.noteCompKindId: 'Legacy entry',
        },
      );

      final weekData = await helper.getWeekPageData(DateTime(2026, 4, 1));
      final rows = List<Map<String, dynamic>>.from(
        weekData['rows'] as List<dynamic>? ?? const [],
      );

      expect(rows, hasLength(1));
      expect(rows.single['billable_value'], 0);
      expect(rows.single['day_minutes'], equals([0, 0, 105, 0, 0, 0, 0]));
      expect(
        rows.single['day_note_lines'],
        equals([
          <String>[],
          <String>[],
          ['Legacy entry'],
          <String>[],
          <String>[],
          <String>[],
          <String>[],
        ]),
      );
      expect(rows.single['total_minutes'], 105);
      expect(weekData['week_total_minutes'], 105);
    },
  );

  test('saveProject creates and updates a project entity', () async {
    final definitions = await _loadRequiredDayDefinitions(helper);

    final projectId = await helper.saveProject(name: 'Project Atlas');
    var project = await helper.getEntity(projectId);

    expect(project, isNotNull);
    expect(project!['kind_id'], definitions.projectKindId);
    expect(_valueForComponent(project, 'name'), 'Project Atlas');

    final updatedProjectId = await helper.saveProject(
      name: 'Project Atlas Updated',
      projectId: projectId,
    );
    project = await helper.getEntity(updatedProjectId);

    expect(updatedProjectId, projectId);
    expect(project, isNotNull);
    expect(_valueForComponent(project!, 'name'), 'Project Atlas Updated');
  });

  test('saveTask creates and updates a task entity under a project', () async {
    final definitions = await _loadRequiredDayDefinitions(helper);
    final projectId = await helper.saveProject(name: 'Project Atlas');

    final taskId = await helper.saveTask(
      name: 'Analysis',
      projectId: projectId,
    );
    var task = await helper.getEntity(taskId);

    expect(task, isNotNull);
    expect(task!['kind_id'], definitions.taskKindId);
    expect(_valueForComponent(task, 'name'), 'Analysis');
    expect(_valueForComponent(task, 'parent'), projectId);

    final updatedTaskId = await helper.saveTask(
      name: 'Design Review',
      projectId: projectId,
      taskId: taskId,
    );
    task = await helper.getEntity(updatedTaskId);

    expect(updatedTaskId, taskId);
    expect(task, isNotNull);
    expect(_valueForComponent(task!, 'name'), 'Design Review');
    expect(_valueForComponent(task, 'parent'), projectId);
  });

  test(
    'getSetupAndSummaryPageData includes zero totals and aggregates task time by project',
    () async {
      await _loadRequiredDayDefinitions(helper);
      final atlasProjectId = await helper.saveProject(name: 'Project Atlas');
      final atlasAnalysisTaskId = await helper.saveTask(
        name: 'Analysis',
        projectId: atlasProjectId,
      );
      final atlasReportingTaskId = await helper.saveTask(
        name: 'Reporting',
        projectId: atlasProjectId,
      );
      final bravoProjectId = await helper.saveProject(name: 'Project Bravo');
      final bravoReturnsTaskId = await helper.saveTask(
        name: 'Returns',
        projectId: bravoProjectId,
      );
      final zeroProjectId = await helper.saveProject(name: 'Project Zero');
      final zeroTaskId = await helper.saveTask(
        name: 'Planning',
        projectId: zeroProjectId,
      );

      await helper.saveDayEntry(
        date: DateTime(2026, 4, 1),
        projectId: atlasProjectId,
        taskId: atlasAnalysisTaskId,
        startMinutes: 9 * 60,
        endMinutes: 10 * 60 + 30,
        billableValue: 1,
      );
      await helper.saveDayEntry(
        date: DateTime(2026, 4, 2),
        projectId: atlasProjectId,
        taskId: atlasReportingTaskId,
        startMinutes: 13 * 60,
        endMinutes: 14 * 60,
        billableValue: 0,
      );
      await helper.saveDayEntry(
        date: DateTime(2026, 4, 3),
        projectId: bravoProjectId,
        taskId: bravoReturnsTaskId,
        startMinutes: 11 * 60,
        endMinutes: 12 * 60 + 15,
        billableValue: 1,
      );

      final pageData = await helper.getSetupAndSummaryPageData();
      final projects = List<Map<String, dynamic>>.from(
        pageData['projects'] as List<dynamic>? ?? const [],
      );
      final tasks = List<Map<String, dynamic>>.from(
        pageData['tasks'] as List<dynamic>? ?? const [],
      );
      final summaryRows = List<Map<String, dynamic>>.from(
        pageData['summary_rows'] as List<dynamic>? ?? const [],
      );

      expect(projects.map((project) => project['name']), [
        'Project Atlas',
        'Project Bravo',
        'Project Zero',
      ]);
      expect(
        tasks
            .map((task) => '${task['project_name']} / ${task['name']}')
            .toList(),
        [
          'Project Atlas / Analysis',
          'Project Atlas / Reporting',
          'Project Bravo / Returns',
          'Project Zero / Planning',
        ],
      );

      final atlasProjectRow = _setupSummaryRowFor(
        summaryRows,
        kind: 'project',
        name: 'Project Atlas',
      );
      final atlasAnalysisTaskRow = _setupSummaryRowFor(
        summaryRows,
        kind: 'task',
        name: 'Analysis',
      );
      final atlasReportingTaskRow = _setupSummaryRowFor(
        summaryRows,
        kind: 'task',
        name: 'Reporting',
      );
      final bravoProjectRow = _setupSummaryRowFor(
        summaryRows,
        kind: 'project',
        name: 'Project Bravo',
      );
      final bravoTaskRow = _setupSummaryRowFor(
        summaryRows,
        kind: 'task',
        name: 'Returns',
      );
      final zeroProjectRow = _setupSummaryRowFor(
        summaryRows,
        kind: 'project',
        name: 'Project Zero',
      );
      final zeroTaskRow = _setupSummaryRowFor(
        summaryRows,
        kind: 'task',
        name: 'Planning',
      );

      expect(atlasProjectRow['entity_id'], atlasProjectId);
      expect(atlasProjectRow['total_minutes'], 150);
      expect(atlasAnalysisTaskRow['entity_id'], atlasAnalysisTaskId);
      expect(atlasAnalysisTaskRow['total_minutes'], 90);
      expect(atlasReportingTaskRow['entity_id'], atlasReportingTaskId);
      expect(atlasReportingTaskRow['total_minutes'], 60);
      expect(bravoProjectRow['entity_id'], bravoProjectId);
      expect(bravoProjectRow['total_minutes'], 75);
      expect(bravoTaskRow['entity_id'], bravoReturnsTaskId);
      expect(bravoTaskRow['total_minutes'], 75);
      expect(zeroProjectRow['entity_id'], zeroProjectId);
      expect(zeroProjectRow['total_minutes'], 0);
      expect(zeroTaskRow['entity_id'], zeroTaskId);
      expect(zeroTaskRow['total_minutes'], 0);

      expect(
        summaryRows.map((row) => '${row['kind']}:${row['name']}').toList(),
        [
          'project:Project Atlas',
          'task:Analysis',
          'task:Reporting',
          'project:Project Bravo',
          'task:Returns',
          'project:Project Zero',
          'task:Planning',
        ],
      );
    },
  );

  test(
    'getSetupAndSummaryPageData builds the six month billability summary with running averages',
    () async {
      final definitions = await _loadRequiredDayDefinitions(helper);
      final ids = await _createProjectAndTask(
        helper,
        definitions,
        projectName: 'Project Atlas',
        taskName: 'Analysis',
      );

      await helper.saveDayEntry(
        date: DateTime(2025, 12, 3),
        projectId: ids.projectId,
        taskId: ids.taskId,
        startMinutes: 9 * 60,
        endMinutes: 11 * 60,
        billableValue: 1,
      );
      await helper.saveDayEntry(
        date: DateTime(2026, 1, 12),
        projectId: ids.projectId,
        taskId: ids.taskId,
        startMinutes: 9 * 60,
        endMinutes: 10 * 60 + 30,
        billableValue: 0,
      );
      await helper.saveDayEntry(
        date: DateTime(2026, 2, 5),
        projectId: ids.projectId,
        taskId: ids.taskId,
        startMinutes: 13 * 60,
        endMinutes: 16 * 60,
        billableValue: 1,
      );
      await helper.saveDayEntry(
        date: DateTime(2026, 3, 10),
        projectId: ids.projectId,
        taskId: ids.taskId,
        startMinutes: 8 * 60,
        endMinutes: 9 * 60,
        billableValue: 0,
      );
      await helper.saveDayEntry(
        date: DateTime(2026, 4, 2),
        projectId: ids.projectId,
        taskId: ids.taskId,
        startMinutes: 9 * 60,
        endMinutes: 11 * 60 + 30,
        billableValue: 1,
      );
      await helper.saveDayEntry(
        date: DateTime(2026, 4, 3),
        projectId: ids.projectId,
        taskId: ids.taskId,
        startMinutes: 15 * 60,
        endMinutes: 15 * 60 + 30,
        billableValue: 0,
      );

      final pageData = await helper.getSetupAndSummaryPageData(
        referenceDate: DateTime(2026, 4, 18),
      );
      final billabilitySummary =
          pageData['billability_summary'] as Map<String, dynamic>? ?? const {};
      final rows = List<Map<String, dynamic>>.from(
        billabilitySummary['rows'] as List<dynamic>? ?? const [],
      );

      expect(billabilitySummary['month_labels'], [
        'Nov',
        'Dec',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
      ]);

      final billableHoursRow = _billabilitySummaryRowFor(
        rows,
        key: 'billable_hours',
      );
      final nonBillableHoursRow = _billabilitySummaryRowFor(
        rows,
        key: 'non_billable_hours',
      );
      final totalHoursRow = _billabilitySummaryRowFor(
        rows,
        key: 'total_hours_worked',
      );
      final billabilityPercentageRow = _billabilitySummaryRowFor(
        rows,
        key: 'billability_percentage',
      );

      expect(billableHoursRow['monthly_values'], [
        0.0,
        2.0,
        0.0,
        3.0,
        0.0,
        2.5,
      ]);
      expect(nonBillableHoursRow['monthly_values'], [
        0.0,
        0.0,
        1.5,
        0.0,
        1.0,
        0.5,
      ]);
      expect(totalHoursRow['monthly_values'], [0.0, 2.0, 1.5, 3.0, 1.0, 3.0]);

      final monthlyPercentages = List<double>.from(
        billabilityPercentageRow['monthly_values'] as List<dynamic>? ??
            const [],
      );
      expect(monthlyPercentages[0], 0.0);
      expect(monthlyPercentages[1], 100.0);
      expect(monthlyPercentages[2], 0.0);
      expect(monthlyPercentages[3], 100.0);
      expect(monthlyPercentages[4], 0.0);
      expect(monthlyPercentages[5], closeTo(83.3333, 0.0001));

      expect(
        (billableHoursRow['average_value'] as num).toDouble(),
        closeTo(1.25, 0.0001),
      );
      expect(
        (nonBillableHoursRow['average_value'] as num).toDouble(),
        closeTo(0.5, 0.0001),
      );
      expect(
        (totalHoursRow['average_value'] as num).toDouble(),
        closeTo(1.75, 0.0001),
      );
      expect(
        (billabilityPercentageRow['average_value'] as num).toDouble(),
        closeTo(71.4286, 0.0001),
      );
    },
  );
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
  final dateCompKindId = _compKindIdByName(allCompKinds, 'date');
  final durationCompKindId = _compKindIdByName(allCompKinds, 'duration');
  final noteCompKindId = _compKindIdByName(allCompKinds, 'note');
  final startTimeCompKindId = _compKindIdByName(allCompKinds, 'start_time');
  final endTimeCompKindId = _compKindIdByName(allCompKinds, 'end_time');
  final projectKindId = _entityKindIdByName(allEntityKinds, 'project');
  final taskKindId = _entityKindIdByName(allEntityKinds, 'task');
  final timeEntryKindId = _entityKindIdByName(allEntityKinds, 'time_entry');

  return _ClockworkDayTestDefinitions(
    nameCompKindId: nameCompKindId,
    parentCompKindId: parentCompKindId,
    dateCompKindId: dateCompKindId,
    durationCompKindId: durationCompKindId,
    noteCompKindId: noteCompKindId,
    startTimeCompKindId: startTimeCompKindId,
    endTimeCompKindId: endTimeCompKindId,
    projectKindId: projectKindId,
    taskKindId: taskKindId,
    timeEntryKindId: timeEntryKindId,
  );
}

class _ClockworkDayTestDefinitions {
  const _ClockworkDayTestDefinitions({
    required this.nameCompKindId,
    required this.parentCompKindId,
    required this.dateCompKindId,
    required this.durationCompKindId,
    required this.noteCompKindId,
    required this.startTimeCompKindId,
    required this.endTimeCompKindId,
    required this.projectKindId,
    required this.taskKindId,
    required this.timeEntryKindId,
  });

  final int nameCompKindId;
  final int parentCompKindId;
  final int dateCompKindId;
  final int durationCompKindId;
  final int noteCompKindId;
  final int startTimeCompKindId;
  final int endTimeCompKindId;
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

Future<_ProjectTaskIds> _createProjectAndTask(
  DbHelper helper,
  _ClockworkDayTestDefinitions definitions, {
  required String projectName,
  required String taskName,
}) async {
  final projectId = await helper.createEntity(
    kindId: definitions.projectKindId,
    componentValues: {definitions.nameCompKindId: projectName},
  );
  final taskId = await helper.createEntity(
    kindId: definitions.taskKindId,
    componentValues: {
      definitions.nameCompKindId: taskName,
      definitions.parentCompKindId: projectId,
    },
  );

  return _ProjectTaskIds(projectId: projectId, taskId: taskId);
}

Map<String, dynamic> _weekRowFor(
  List<Map<String, dynamic>> rows, {
  required String projectName,
  required String taskName,
  required int billableValue,
}) {
  return rows.singleWhere(
    (row) =>
        row['project_name'] == projectName &&
        row['task_name'] == taskName &&
        row['billable_value'] == billableValue,
  );
}

Map<String, dynamic> _setupSummaryRowFor(
  List<Map<String, dynamic>> rows, {
  required String kind,
  required String name,
}) {
  return rows.singleWhere((row) => row['kind'] == kind && row['name'] == name);
}

Map<String, dynamic> _billabilitySummaryRowFor(
  List<Map<String, dynamic>> rows, {
  required String key,
}) {
  return rows.singleWhere((row) => row['key'] == key);
}

class _ProjectTaskIds {
  const _ProjectTaskIds({required this.projectId, required this.taskId});

  final int projectId;
  final int taskId;
}
