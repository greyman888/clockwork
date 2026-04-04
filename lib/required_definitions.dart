import 'dart:convert';
import 'dart:io';

const requiredDefinitionsAssetPath = 'assets/required_definitions.json';

class RequiredDefinitionsManifest {
  RequiredDefinitionsManifest({
    required this.manifestVersion,
    required List<RequiredCompKindDefinition> componentKinds,
    required List<RequiredEntityKindDefinition> entityKinds,
    required this.dayPage,
  }) : componentKinds = List<RequiredCompKindDefinition>.from(componentKinds),
       entityKinds = List<RequiredEntityKindDefinition>.from(entityKinds);

  int manifestVersion;
  final List<RequiredCompKindDefinition> componentKinds;
  final List<RequiredEntityKindDefinition> entityKinds;
  final RequiredDayPageDefinition dayPage;

  factory RequiredDefinitionsManifest.fromJson(Map<String, dynamic> json) {
    final componentKinds = _jsonObjectList(
      json['component_kinds'],
      'component_kinds',
    ).map(RequiredCompKindDefinition.fromJson).toList();
    final entityKinds = _jsonObjectList(
      json['entity_kinds'],
      'entity_kinds',
    ).map(RequiredEntityKindDefinition.fromJson).toList();
    final features = _jsonObject(json['features'], 'features');
    final dayPage = RequiredDayPageDefinition.fromJson(
      _jsonObject(features['day_page'], 'features.day_page'),
    );

    final compKindNames = <String>{};
    for (final definition in componentKinds) {
      if (!compKindNames.add(definition.name)) {
        throw Exception(
          'Duplicate required component kind name "${definition.name}" in '
          'the definitions manifest.',
        );
      }
    }

    final entityKindNames = <String>{};
    for (final definition in entityKinds) {
      if (!entityKindNames.add(definition.name)) {
        throw Exception(
          'Duplicate required entity kind name "${definition.name}" in the '
          'definitions manifest.',
        );
      }

      for (final componentName in definition.componentNames) {
        if (!compKindNames.contains(componentName)) {
          throw Exception(
            'Required entity kind "${definition.name}" references unknown '
            'component kind "$componentName".',
          );
        }
      }
    }

    for (final entityKindName in [
      dayPage.projectKindName,
      dayPage.taskKindName,
      dayPage.timeEntryKindName,
    ]) {
      if (!entityKindNames.contains(entityKindName)) {
        throw Exception(
          'Day page references unknown required entity kind '
          '"$entityKindName".',
        );
      }
    }

    for (final compKindName in [
      dayPage.nameCompKindName,
      dayPage.parentCompKindName,
      dayPage.durationCompKindName,
      dayPage.dateCompKindName,
      dayPage.noteCompKindName,
      dayPage.startTimeCompKindName,
      dayPage.endTimeCompKindName,
    ]) {
      if (!compKindNames.contains(compKindName)) {
        throw Exception(
          'Day page references unknown required component kind '
          '"$compKindName".',
        );
      }
    }

    return RequiredDefinitionsManifest(
      manifestVersion: _jsonInt(json, 'manifest_version', defaultValue: 1),
      componentKinds: componentKinds,
      entityKinds: entityKinds,
      dayPage: dayPage,
    );
  }

  static Future<RequiredDefinitionsManifest> loadFromFile(
    String filePath,
  ) async {
    final file = File(filePath);
    final rawManifest = await file.readAsString();
    final decodedManifest = jsonDecode(rawManifest);

    if (decodedManifest is! Map<String, dynamic>) {
      throw Exception(
        'The required definitions manifest must be a top-level JSON object.',
      );
    }

    return RequiredDefinitionsManifest.fromJson(decodedManifest);
  }

  Map<String, dynamic> toJson() {
    return {
      'manifest_version': manifestVersion,
      'component_kinds': componentKinds
          .map((definition) => definition.toJson())
          .toList(),
      'entity_kinds': entityKinds
          .map((definition) => definition.toJson())
          .toList(),
      'features': {'day_page': dayPage.toJson()},
    };
  }

  Future<void> writeToFile(String filePath) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(toJson())}\n');
  }

  bool upsertComponentKind(RequiredCompKindDefinition definition) {
    final index = componentKinds.indexWhere(
      (existingDefinition) => existingDefinition.name == definition.name,
    );

    if (index == -1) {
      componentKinds.add(definition);
      return true;
    }

    final existingDefinition = componentKinds[index];
    if (!existingDefinition.isEquivalentTo(definition)) {
      componentKinds[index] = definition;
      return true;
    }

    return false;
  }

  bool upsertEntityKind(
    RequiredEntityKindDefinition definition, {
    bool replaceComponents = false,
  }) {
    final index = entityKinds.indexWhere(
      (existingDefinition) => existingDefinition.name == definition.name,
    );

    if (index == -1) {
      entityKinds.add(definition);
      return true;
    }

    final existingDefinition = entityKinds[index];
    final nextComponentNames = replaceComponents
        ? List<String>.from(definition.componentNames)
        : _mergeStringLists(
            existingDefinition.componentNames,
            definition.componentNames,
          );
    final nextDefinition = RequiredEntityKindDefinition(
      name: definition.name,
      displayName: definition.displayName,
      componentNames: nextComponentNames,
    );

    if (!existingDefinition.isEquivalentTo(nextDefinition)) {
      entityKinds[index] = nextDefinition;
      return true;
    }

    return false;
  }

  bool hasComponentKind(String name) {
    return componentKinds.any((definition) => definition.name == name);
  }

  void bumpVersion() {
    manifestVersion += 1;
  }
}

class RequiredCompKindDefinition {
  RequiredCompKindDefinition({
    required this.name,
    required this.displayName,
    required this.storageType,
    required this.semanticType,
    required List<RequiredEnumOptionDefinition> enumOptions,
  }) : enumOptions = List<RequiredEnumOptionDefinition>.from(enumOptions);

  final String name;
  final String displayName;
  final String storageType;
  final String? semanticType;
  final List<RequiredEnumOptionDefinition> enumOptions;

  factory RequiredCompKindDefinition.fromJson(Map<String, dynamic> json) {
    final semanticType = _jsonOptionalString(json, 'semantic_type');
    final enumOptions = _jsonObjectList(
      json['enum_options'] ?? const [],
      'enum_options',
    ).map(RequiredEnumOptionDefinition.fromJson).toList();

    if (enumOptions.isNotEmpty && semanticType != 'enum') {
      throw Exception(
        'Component kind "${_jsonString(json, 'name')}" defines enum options '
        'but is not marked as semantic type "enum".',
      );
    }

    return RequiredCompKindDefinition(
      name: _jsonString(json, 'name'),
      displayName: _jsonString(json, 'display_name'),
      storageType: _jsonString(json, 'storage_type'),
      semanticType: semanticType,
      enumOptions: enumOptions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'display_name': displayName,
      'storage_type': storageType,
      if (semanticType != null) 'semantic_type': semanticType,
      if (enumOptions.isNotEmpty)
        'enum_options': enumOptions.map((option) => option.toJson()).toList(),
    };
  }

  bool isEquivalentTo(RequiredCompKindDefinition other) {
    return name == other.name &&
        displayName == other.displayName &&
        storageType == other.storageType &&
        semanticType == other.semanticType &&
        _enumOptionListsEqual(enumOptions, other.enumOptions);
  }
}

class RequiredEntityKindDefinition {
  RequiredEntityKindDefinition({
    required this.name,
    required this.displayName,
    required List<String> componentNames,
  }) : componentNames = List<String>.from(componentNames);

  final String name;
  final String displayName;
  final List<String> componentNames;

  factory RequiredEntityKindDefinition.fromJson(Map<String, dynamic> json) {
    return RequiredEntityKindDefinition(
      name: _jsonString(json, 'name'),
      displayName: _jsonString(json, 'display_name'),
      componentNames: _jsonStringList(json['components'], 'components'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'display_name': displayName,
      'components': componentNames,
    };
  }

  bool isEquivalentTo(RequiredEntityKindDefinition other) {
    return name == other.name &&
        displayName == other.displayName &&
        _stringListsEqual(componentNames, other.componentNames);
  }
}

class RequiredEnumOptionDefinition {
  const RequiredEnumOptionDefinition({
    required this.value,
    required this.displayLabel,
    required this.sortOrder,
  });

  final String value;
  final String displayLabel;
  final int sortOrder;

  factory RequiredEnumOptionDefinition.fromJson(Map<String, dynamic> json) {
    return RequiredEnumOptionDefinition(
      value: _jsonString(json, 'value'),
      displayLabel: _jsonString(json, 'display_label'),
      sortOrder: _jsonInt(json, 'sort_order', defaultValue: 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'display_label': displayLabel,
      'sort_order': sortOrder,
    };
  }

  bool isEquivalentTo(RequiredEnumOptionDefinition other) {
    return value == other.value &&
        displayLabel == other.displayLabel &&
        sortOrder == other.sortOrder;
  }
}

class RequiredDayPageDefinition {
  const RequiredDayPageDefinition({
    required this.projectKindName,
    required this.taskKindName,
    required this.timeEntryKindName,
    required this.nameCompKindName,
    required this.parentCompKindName,
    required this.durationCompKindName,
    required this.dateCompKindName,
    required this.noteCompKindName,
    required this.startTimeCompKindName,
    required this.endTimeCompKindName,
  });

  final String projectKindName;
  final String taskKindName;
  final String timeEntryKindName;
  final String nameCompKindName;
  final String parentCompKindName;
  final String durationCompKindName;
  final String dateCompKindName;
  final String noteCompKindName;
  final String startTimeCompKindName;
  final String endTimeCompKindName;

  factory RequiredDayPageDefinition.fromJson(Map<String, dynamic> json) {
    return RequiredDayPageDefinition(
      projectKindName: _jsonString(json, 'project_kind'),
      taskKindName: _jsonString(json, 'task_kind'),
      timeEntryKindName: _jsonString(json, 'time_entry_kind'),
      nameCompKindName: _jsonString(json, 'name_component'),
      parentCompKindName: _jsonString(json, 'parent_component'),
      durationCompKindName: _jsonString(json, 'duration_component'),
      dateCompKindName: _jsonString(json, 'date_component'),
      noteCompKindName: _jsonString(json, 'note_component'),
      startTimeCompKindName: _jsonString(json, 'start_time_component'),
      endTimeCompKindName: _jsonString(json, 'end_time_component'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_kind': projectKindName,
      'task_kind': taskKindName,
      'time_entry_kind': timeEntryKindName,
      'name_component': nameCompKindName,
      'parent_component': parentCompKindName,
      'duration_component': durationCompKindName,
      'date_component': dateCompKindName,
      'note_component': noteCompKindName,
      'start_time_component': startTimeCompKindName,
      'end_time_component': endTimeCompKindName,
    };
  }
}

Map<String, dynamic> jsonObject(Object? value, String label) {
  return _jsonObject(value, label);
}

List<Map<String, dynamic>> jsonObjectList(Object? value, String label) {
  return _jsonObjectList(value, label);
}

String jsonString(Map<String, dynamic> json, String key) {
  return _jsonString(json, key);
}

String? jsonOptionalString(Map<String, dynamic> json, String key) {
  return _jsonOptionalString(json, key);
}

int jsonInt(
  Map<String, dynamic> json,
  String key, {
  required int defaultValue,
}) {
  return _jsonInt(json, key, defaultValue: defaultValue);
}

List<String> jsonStringList(Object? value, String label) {
  return _jsonStringList(value, label);
}

Map<String, dynamic> _jsonObject(Object? value, String label) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map(
      (key, nestedValue) => MapEntry(key.toString(), nestedValue),
    );
  }

  throw Exception('Expected "$label" to be a JSON object.');
}

List<Map<String, dynamic>> _jsonObjectList(Object? value, String label) {
  if (value is! List) {
    throw Exception('Expected "$label" to be a JSON array.');
  }

  return value
      .map((item) => _jsonObject(item, '$label[]'))
      .toList(growable: false);
}

String _jsonString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw Exception('Expected "$key" to be a string in the manifest.');
  }

  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw Exception('Expected "$key" to be a non-empty string.');
  }

  return normalized;
}

String? _jsonOptionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw Exception('Expected "$key" to be a string in the manifest.');
  }

  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _jsonInt(
  Map<String, dynamic> json,
  String key, {
  required int defaultValue,
}) {
  final value = json[key];
  if (value == null) {
    return defaultValue;
  }
  if (value is int) {
    return value;
  }

  throw Exception('Expected "$key" to be an integer in the manifest.');
}

List<String> _jsonStringList(Object? value, String label) {
  if (value is! List) {
    throw Exception('Expected "$label" to be a JSON array.');
  }

  return value
      .map((item) {
        if (item is! String) {
          throw Exception('Expected "$label" entries to be strings.');
        }

        final normalized = item.trim();
        if (normalized.isEmpty) {
          throw Exception('Expected "$label" entries to be non-empty strings.');
        }

        return normalized;
      })
      .toList(growable: false);
}

bool _enumOptionListsEqual(
  List<RequiredEnumOptionDefinition> left,
  List<RequiredEnumOptionDefinition> right,
) {
  if (left.length != right.length) {
    return false;
  }

  for (var index = 0; index < left.length; index += 1) {
    if (!left[index].isEquivalentTo(right[index])) {
      return false;
    }
  }

  return true;
}

bool _stringListsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }

  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }

  return true;
}

List<String> _mergeStringLists(List<String> existing, List<String> additions) {
  final merged = List<String>.from(existing);
  final seen = merged.toSet();

  for (final value in additions) {
    if (seen.add(value)) {
      merged.add(value);
    }
  }

  return merged;
}
