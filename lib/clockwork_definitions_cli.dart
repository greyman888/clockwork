import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'db_helper.dart';
import 'required_definitions.dart';

class ClockworkDefinitionsCli {
  static bool _sqfliteFactoryInitialized = false;

  ClockworkDefinitionsCli({
    required this.defaultManifestPath,
    String? defaultDbPath,
    StringSink? out,
    StringSink? err,
  }) : defaultDbPath = defaultDbPath ?? _defaultLiveDbPath(),
       _out = out ?? stdout,
       _err = err ?? stderr;

  final String defaultManifestPath;
  final String defaultDbPath;
  final StringSink _out;
  final StringSink _err;

  Future<int> run(List<String> args) async {
    try {
      final tokens = _CommandTokens(List<String>.from(args));
      final helpRequested = tokens.takeFlag('--help') || tokens.takeFlag('-h');
      final manifestPath = path.normalize(
        tokens.takeOption('--manifest') ?? defaultManifestPath,
      );

      if (tokens.isEmpty) {
        _writeUsage();
        return helpRequested ? 0 : 64;
      }

      final command = tokens.takeCommand();

      if (helpRequested || command == 'help') {
        _writeUsage();
        return 0;
      }

      switch (command) {
        case 'show':
          return _handleShow(tokens, manifestPath: manifestPath);
        case 'component-kind':
          return _handleComponentKind(tokens, manifestPath: manifestPath);
        case 'entity-kind':
          return _handleEntityKind(tokens, manifestPath: manifestPath);
        case 'apply-required':
          return _handleApplyRequired(tokens, manifestPath: manifestPath);
        default:
          throw _CliUsageException('Unknown command "$command".');
      }
    } on _CliUsageException catch (error) {
      _err.writeln(error.message);
      _err.writeln('');
      _writeUsage(to: _err);
      return 64;
    } on Exception catch (error) {
      _err.writeln(error);
      return 1;
    }
  }

  Future<int> _handleShow(
    _CommandTokens tokens, {
    required String manifestPath,
  }) async {
    final showDb = tokens.takeFlag('--show-db');
    final dbPath = tokens.takeOption('--db');

    tokens.expectNoArguments();

    final manifest = await RequiredDefinitionsManifest.loadFromFile(
      manifestPath,
    );
    _out.writeln('Manifest: $manifestPath');
    _out.writeln('manifest_version: ${manifest.manifestVersion}');
    _out.writeln('component_kinds: ${manifest.componentKinds.length}');
    for (final definition in manifest.componentKinds) {
      _out.writeln(
        '  - ${definition.name} '
        '(${definition.storageType}${definition.semanticType == null ? '' : ', ${definition.semanticType}'})',
      );
    }
    _out.writeln('entity_kinds: ${manifest.entityKinds.length}');
    for (final definition in manifest.entityKinds) {
      _out.writeln(
        '  - ${definition.name}: ${definition.componentNames.join(', ')}',
      );
    }
    _out.writeln(
      'day_page: '
      '${manifest.dayPage.projectKindName}, '
      '${manifest.dayPage.taskKindName}, '
      '${manifest.dayPage.timeEntryKindName}',
    );

    if (showDb || dbPath != null) {
      final resolvedDbPath = path.normalize(dbPath ?? defaultDbPath);
      final helper = _createDbHelper(
        dbPath: resolvedDbPath,
        manifestPath: manifestPath,
      );

      try {
        await helper.ensureRequiredDefinitions();
        final compKinds = await helper.getAllCompKinds(includeInactive: true);
        final entityKinds = await helper.getAllEntityKinds(
          includeInactive: true,
        );
        _out.writeln('');
        _out.writeln('Database: $resolvedDbPath');
        _out.writeln('component_kinds: ${compKinds.length}');
        for (final definition in compKinds) {
          _out.writeln(
            '  - ${definition['name']} '
            '(status: ${definition['status']}, id: ${definition['id']})',
          );
        }
        _out.writeln('entity_kinds: ${entityKinds.length}');
        for (final definition in entityKinds) {
          _out.writeln(
            '  - ${definition['name']} '
            '(status: ${definition['status']}, id: ${definition['id']})',
          );
        }
      } finally {
        await helper.close();
      }
    }

    return 0;
  }

  Future<int> _handleComponentKind(
    _CommandTokens tokens, {
    required String manifestPath,
  }) async {
    final name = _normalizeRequiredInput(
      tokens.takeRequiredOption('--name'),
      '--name',
    );
    final displayName = _normalizeRequiredInput(
      tokens.takeRequiredOption('--display-name'),
      '--display-name',
    );
    final storageType = _normalizeRequiredInput(
      tokens.takeRequiredOption('--storage-type'),
      '--storage-type',
    ).toLowerCase();
    final semanticType = tokens.takeOption('--semantic-type')?.trim();
    final enumOptions = tokens
        .takeMultiOption('--enum-option')
        .map(_parseEnumOption)
        .toList();
    final applyDb = tokens.takeFlag('--apply-db');
    final dbPath = tokens.takeOption('--db');

    tokens.expectNoArguments();

    _validateComponentKindInput(
      storageType: storageType,
      semanticType: semanticType,
      enumOptions: enumOptions,
    );

    final manifest = await RequiredDefinitionsManifest.loadFromFile(
      manifestPath,
    );
    final changed = manifest.upsertComponentKind(
      RequiredCompKindDefinition(
        name: name,
        displayName: displayName,
        storageType: storageType,
        semanticType: semanticType == null || semanticType.isEmpty
            ? null
            : semanticType,
        enumOptions: enumOptions,
      ),
    );

    if (!changed) {
      _out.writeln('No manifest changes required for component kind "$name".');
    } else {
      manifest.bumpVersion();
      await manifest.writeToFile(manifestPath);
      _out.writeln('Updated manifest component kind "$name" at $manifestPath.');
    }

    if (applyDb) {
      final resolvedDbPath = path.normalize(dbPath ?? defaultDbPath);
      await _applyManifestToDb(
        manifestPath: manifestPath,
        dbPath: resolvedDbPath,
      );
      _out.writeln('Applied required definitions to $resolvedDbPath.');
    }

    return 0;
  }

  Future<int> _handleEntityKind(
    _CommandTokens tokens, {
    required String manifestPath,
  }) async {
    final name = _normalizeRequiredInput(
      tokens.takeRequiredOption('--name'),
      '--name',
    );
    final displayName = _normalizeRequiredInput(
      tokens.takeRequiredOption('--display-name'),
      '--display-name',
    );
    final componentNames = tokens.takeMultiOption('--component').map((
      componentName,
    ) {
      return _normalizeRequiredInput(componentName, '--component');
    }).toList();
    final replaceComponents = tokens.takeFlag('--replace-components');
    final applyDb = tokens.takeFlag('--apply-db');
    final dbPath = tokens.takeOption('--db');

    if (componentNames.isEmpty) {
      throw _CliUsageException(
        'The entity-kind command requires at least one --component.',
      );
    }

    tokens.expectNoArguments();

    final uniqueComponentNames = _uniqueStrings(componentNames);

    final manifest = await RequiredDefinitionsManifest.loadFromFile(
      manifestPath,
    );

    for (final componentName in uniqueComponentNames) {
      if (!manifest.hasComponentKind(componentName)) {
        throw Exception(
          'Component kind "$componentName" is not present in $manifestPath. '
          'Add it first with the component-kind command.',
        );
      }
    }

    final changed = manifest.upsertEntityKind(
      RequiredEntityKindDefinition(
        name: name,
        displayName: displayName,
        componentNames: uniqueComponentNames,
      ),
      replaceComponents: replaceComponents,
    );

    if (!changed) {
      _out.writeln('No manifest changes required for entity kind "$name".');
    } else {
      manifest.bumpVersion();
      await manifest.writeToFile(manifestPath);
      _out.writeln('Updated manifest entity kind "$name" at $manifestPath.');
    }

    if (applyDb) {
      final resolvedDbPath = path.normalize(dbPath ?? defaultDbPath);
      await _applyManifestToDb(
        manifestPath: manifestPath,
        dbPath: resolvedDbPath,
      );
      _out.writeln('Applied required definitions to $resolvedDbPath.');
    }

    return 0;
  }

  Future<int> _handleApplyRequired(
    _CommandTokens tokens, {
    required String manifestPath,
  }) async {
    final dbPath = path.normalize(tokens.takeOption('--db') ?? defaultDbPath);
    tokens.expectNoArguments();

    await _applyManifestToDb(manifestPath: manifestPath, dbPath: dbPath);
    _out.writeln('Applied $manifestPath to $dbPath.');
    return 0;
  }

  Future<void> _applyManifestToDb({
    required String manifestPath,
    required String dbPath,
  }) async {
    final helper = _createDbHelper(dbPath: dbPath, manifestPath: manifestPath);

    try {
      await helper.ensureRequiredDefinitions();
    } finally {
      await helper.close();
    }
  }

  DbHelper _createDbHelper({
    required String dbPath,
    required String manifestPath,
  }) {
    _ensureSqfliteFactory();

    return DbHelper.forFilePath(
      dbPath: dbPath,
      requiredDefinitionsLoader: () => File(manifestPath).readAsString(),
    );
  }

  static void _ensureSqfliteFactory() {
    if (_sqfliteFactoryInitialized) {
      return;
    }

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _sqfliteFactoryInitialized = true;
  }

  void _writeUsage({StringSink? to}) {
    final sink = to ?? _out;
    sink.writeln('Clockwork definitions CLI');
    sink.writeln('');
    sink.writeln('Commands:');
    sink.writeln('  show [--manifest <path>] [--show-db] [--db <path>]');
    sink.writeln(
      '  component-kind --name <name> --display-name <label> --storage-type <type>'
      ' [--semantic-type <type>] [--enum-option value|label|sort]'
      ' [--manifest <path>] [--apply-db] [--db <path>]',
    );
    sink.writeln(
      '  entity-kind --name <name> --display-name <label> --component <name>'
      ' [--component <name> ...] [--replace-components]'
      ' [--manifest <path>] [--apply-db] [--db <path>]',
    );
    sink.writeln('  apply-required [--manifest <path>] [--db <path>]');
    sink.writeln('');
    sink.writeln('Notes:');
    sink.writeln(
      '  The manifest is updated first. Use --apply-db to sync the live database immediately.',
    );
    sink.writeln(
      '  Enum options use the format value|display label|sortOrder. The sort order defaults to 0.',
    );
  }

  static String _defaultLiveDbPath() {
    return path.normalize(DbHelper.defaultDatabasePath());
  }
}

class _CommandTokens {
  _CommandTokens(this._tokens);

  final List<String> _tokens;

  bool get isEmpty => _tokens.isEmpty;

  String takeCommand() {
    if (_tokens.isEmpty) {
      throw _CliUsageException('A command is required.');
    }

    return _tokens.removeAt(0);
  }

  bool takeFlag(String flag) {
    final index = _tokens.indexOf(flag);
    if (index == -1) {
      return false;
    }

    _tokens.removeAt(index);
    return true;
  }

  String? takeOption(String option) {
    final index = _tokens.indexOf(option);
    if (index == -1) {
      return null;
    }

    if (index == _tokens.length - 1) {
      throw _CliUsageException('Missing value for $option.');
    }

    final value = _tokens[index + 1];
    _tokens.removeAt(index + 1);
    _tokens.removeAt(index);
    return value;
  }

  String takeRequiredOption(String option) {
    final value = takeOption(option);
    if (value == null) {
      throw _CliUsageException('Missing required option $option.');
    }
    return value;
  }

  List<String> takeMultiOption(String option) {
    final values = <String>[];

    while (true) {
      final value = takeOption(option);
      if (value == null) {
        break;
      }
      values.add(value);
    }

    return values;
  }

  void expectNoArguments() {
    if (_tokens.isEmpty) {
      return;
    }

    throw _CliUsageException('Unexpected arguments: ${_tokens.join(' ')}');
  }
}

class _CliUsageException implements Exception {
  const _CliUsageException(this.message);

  final String message;

  @override
  String toString() => message;
}

RequiredEnumOptionDefinition _parseEnumOption(String value) {
  final parts = value.split('|');
  if (parts.length < 2 || parts.length > 3) {
    throw Exception(
      'Enum options must use the format value|display label|sortOrder.',
    );
  }

  final optionValue = _normalizeRequiredInput(parts[0], 'enum option value');
  final displayLabel = _normalizeRequiredInput(
    parts[1],
    'enum option display label',
  );
  final sortOrder = parts.length == 3 ? int.tryParse(parts[2].trim()) : 0;

  if (sortOrder == null || sortOrder < 0) {
    throw Exception('Enum option sort order must be a non-negative integer.');
  }

  return RequiredEnumOptionDefinition(
    value: optionValue,
    displayLabel: displayLabel,
    sortOrder: sortOrder,
  );
}

String _normalizeRequiredInput(String value, String label) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw Exception('$label cannot be blank.');
  }
  return normalized;
}

void _validateComponentKindInput({
  required String storageType,
  required String? semanticType,
  required List<RequiredEnumOptionDefinition> enumOptions,
}) {
  const storageTypes = <String>{
    DbHelper.storageInteger,
    DbHelper.storageReal,
    DbHelper.storageText,
    DbHelper.storageEntity,
  };
  const semanticTypes = <String>{
    DbHelper.semanticPlain,
    DbHelper.semanticDate,
    DbHelper.semanticBoolean,
    DbHelper.semanticEnum,
    DbHelper.semanticCurrency,
    DbHelper.semanticEntityReference,
  };

  if (!storageTypes.contains(storageType)) {
    throw Exception(
      'Unsupported storage type "$storageType". '
      'Expected one of: ${storageTypes.join(', ')}.',
    );
  }

  if (semanticType != null &&
      semanticType.isNotEmpty &&
      !semanticTypes.contains(semanticType)) {
    throw Exception(
      'Unsupported semantic type "$semanticType". '
      'Expected one of: ${semanticTypes.join(', ')}.',
    );
  }

  if (enumOptions.isNotEmpty && semanticType != DbHelper.semanticEnum) {
    throw Exception(
      'Enum options require --semantic-type ${DbHelper.semanticEnum}.',
    );
  }
}

List<String> _uniqueStrings(List<String> values) {
  final uniqueValues = <String>[];
  final seenValues = <String>{};

  for (final value in values) {
    if (seenValues.add(value)) {
      uniqueValues.add(value);
    }
  }

  return uniqueValues;
}
