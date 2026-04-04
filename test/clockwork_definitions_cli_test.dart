import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:clockwork/clockwork_definitions_cli.dart';
import 'package:clockwork/db_helper.dart';
import 'package:clockwork/required_definitions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late String manifestPath;
  late String dbPath;
  late StringBuffer stdoutBuffer;
  late StringBuffer stderrBuffer;
  late ClockworkDefinitionsCli cli;
  late int initialManifestVersion;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'clockwork_cli_test_',
    );
    manifestPath = path.join(tempDirectory.path, 'required_definitions.json');
    dbPath = path.join(tempDirectory.path, 'clockwork.db');
    stdoutBuffer = StringBuffer();
    stderrBuffer = StringBuffer();

    final sourceManifestPath = path.join(
      Directory.current.path,
      requiredDefinitionsAssetPath,
    );
    await File(sourceManifestPath).copy(manifestPath);
    initialManifestVersion = (await RequiredDefinitionsManifest.loadFromFile(
      manifestPath,
    )).manifestVersion;

    cli = ClockworkDefinitionsCli(
      defaultManifestPath: manifestPath,
      defaultDbPath: dbPath,
      out: stdoutBuffer,
      err: stderrBuffer,
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'component-kind updates manifest and applies definitions to the db',
    () async {
      final exitCode = await cli.run([
        'component-kind',
        '--name',
        'billable_code',
        '--display-name',
        'Billable Code',
        '--storage-type',
        'text',
        '--apply-db',
      ]);

      expect(exitCode, 0);
      expect(stderrBuffer.toString(), isEmpty);

      final manifest = await RequiredDefinitionsManifest.loadFromFile(
        manifestPath,
      );
      final componentKind = manifest.componentKinds.singleWhere(
        (definition) => definition.name == 'billable_code',
      );
      expect(componentKind.displayName, 'Billable Code');
      expect(componentKind.storageType, DbHelper.storageText);
      expect(manifest.manifestVersion, initialManifestVersion + 1);

      final helper = DbHelper.forFilePath(
        dbPath: dbPath,
        requiredDefinitionsLoader: () => File(manifestPath).readAsString(),
      );
      try {
        final allCompKinds = await helper.getAllCompKinds();
        expect(
          allCompKinds.map((definition) => definition['name'] as String),
          contains('billable_code'),
        );
      } finally {
        await helper.close();
      }
    },
  );

  test(
    'entity-kind updates manifest and applies linked components to the db',
    () async {
      final exitCode = await cli.run([
        'entity-kind',
        '--name',
        'project_note',
        '--display-name',
        'Project Note',
        '--component',
        'name',
        '--component',
        'note',
        '--apply-db',
      ]);

      expect(exitCode, 0);
      expect(stderrBuffer.toString(), isEmpty);

      final manifest = await RequiredDefinitionsManifest.loadFromFile(
        manifestPath,
      );
      final entityKind = manifest.entityKinds.singleWhere(
        (definition) => definition.name == 'project_note',
      );
      expect(entityKind.displayName, 'Project Note');
      expect(entityKind.componentNames, ['name', 'note']);

      final helper = DbHelper.forFilePath(
        dbPath: dbPath,
        requiredDefinitionsLoader: () => File(manifestPath).readAsString(),
      );
      try {
        final entityKinds = await helper.getAllEntityKinds();
        final projectNoteKind = entityKinds.singleWhere(
          (definition) => definition['name'] == 'project_note',
        );
        final linkedCompKinds = await helper.getCompKindsForEntityKind(
          projectNoteKind['id'] as int,
        );
        expect(
          linkedCompKinds.map((definition) => definition['name'] as String),
          containsAll(['name', 'note']),
        );
      } finally {
        await helper.close();
      }
    },
  );

  test('apply-required syncs manifest-only changes into the db', () async {
    var exitCode = await cli.run([
      'component-kind',
      '--name',
      'cost_center',
      '--display-name',
      'Cost Center',
      '--storage-type',
      'text',
    ]);

    expect(exitCode, 0);
    expect(await File(dbPath).exists(), isFalse);

    exitCode = await cli.run(['apply-required']);

    expect(exitCode, 0);

    final helper = DbHelper.forFilePath(
      dbPath: dbPath,
      requiredDefinitionsLoader: () => File(manifestPath).readAsString(),
    );
    try {
      final allCompKinds = await helper.getAllCompKinds();
      expect(
        allCompKinds.map((definition) => definition['name'] as String),
        contains('cost_center'),
      );
    } finally {
      await helper.close();
    }
  });
}
