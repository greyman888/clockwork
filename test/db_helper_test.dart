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
