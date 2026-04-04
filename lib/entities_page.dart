import 'package:fluent_ui/fluent_ui.dart';

import 'app_db.dart';
import 'editor_helpers.dart';
import 'editor_widgets.dart';

class EntitiesPage extends StatefulWidget {
  const EntitiesPage({super.key});

  @override
  State<EntitiesPage> createState() => _EntitiesPageState();
}

class _EntitiesPageState extends State<EntitiesPage> {
  final Map<int, TextEditingController> _textControllers = {};
  final Map<int, int?> _booleanValues = {};
  final Map<int, String?> _enumValues = {};
  final Map<int, int?> _entityReferenceValues = {};

  List<Map<String, dynamic>> _entityKinds = const [];
  List<Map<String, dynamic>> _allEntities = const [];
  List<Map<String, dynamic>> _existingEntities = const [];
  List<Map<String, dynamic>> _components = const [];
  int? _selectedEntityId;
  int? _selectedEntityKindId;
  int? _existingEntitiesKindId;
  bool _isLoading = true;
  bool _isExistingEntitiesLoading = false;
  bool _isSaving = false;

  bool get _isEditing => _selectedEntityId != null;

  bool get _hasEntityKinds => _entityKinds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadPage(forceCreateMode: true);
  }

  @override
  void dispose() {
    _disposeComponentInputs();
    super.dispose();
  }

  Future<void> _loadPage({
    int? selectEntityId,
    bool forceCreateMode = false,
  }) async {
    setState(() => _isLoading = true);

    try {
      final entityKinds = await dbHelper.getAllEntityKinds();
      final allEntities = await dbHelper.getAllEntities();

      if (!mounted) {
        return;
      }

      setState(() {
        _entityKinds = entityKinds;
        _allEntities = allEntities;
      });

      await _loadExistingEntities(kindId: _existingEntitiesKindId);

      if (forceCreateMode) {
        await _prepareNewEntity(preferredKindId: _selectedEntityKindId);
      } else {
        final nextSelectedId = resolveSelectedId(
          items: allEntities,
          explicitSelection: selectEntityId,
          currentSelection: _selectedEntityId,
        );

        if (nextSelectedId != null) {
          await _loadEntityDetail(nextSelectedId);
        } else {
          await _prepareNewEntity(preferredKindId: _selectedEntityKindId);
        }
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      await showNoticeDialog(
        context,
        title: 'Unable to load entities',
        message: error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _prepareNewEntity({int? preferredKindId}) async {
    final nextKindId = _resolveEntityKindId(preferredKindId);

    _selectedEntityId = null;
    _selectedEntityKindId = nextKindId;

    if (nextKindId == null) {
      _replaceComponents(const []);
      if (mounted) {
        setState(() {});
      }
      return;
    }

    await _loadComponentsForKind(nextKindId);
  }

  Future<void> _loadEntityDetail(int entityId) async {
    final entity = await dbHelper.getEntity(entityId);

    if (!mounted) {
      return;
    }

    if (entity == null) {
      await _prepareNewEntity();
      return;
    }

    _selectedEntityId = entityId;
    _selectedEntityKindId = entity['kind_id'] as int;

    final components = List<Map<String, dynamic>>.from(
      entity['components'] as List<dynamic>? ?? const [],
    );
    _replaceComponents(components);

    setState(() {});
  }

  Future<void> _loadComponentsForKind(int entityKindId) async {
    final components = await dbHelper.getEntityKindComponents(entityKindId);

    if (!mounted) {
      return;
    }

    _selectedEntityKindId = entityKindId;
    _replaceComponents(components);
    setState(() {});
  }

  Future<void> _loadExistingEntities({required int? kindId}) async {
    if (kindId == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _existingEntitiesKindId = null;
        _existingEntities = const [];
        _isExistingEntitiesLoading = false;
      });
      return;
    }

    setState(() {
      _existingEntitiesKindId = kindId;
      _isExistingEntitiesLoading = true;
    });

    try {
      final detailedEntities = await dbHelper.getEntitiesWithComponents(
        kindId: kindId,
      );

      if (!mounted) {
        return;
      }

      final existingEntities = detailedEntities.map((entity) {
        final detailedEntity = Map<String, dynamic>.from(entity);
        detailedEntity['component_summary'] = _existingEntitySummary(
          detailedEntity,
        );
        return detailedEntity;
      }).toList();

      setState(() {
        _existingEntities = existingEntities;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      await showNoticeDialog(
        context,
        title: 'Unable to load filtered entities',
        message: error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isExistingEntitiesLoading = false);
      }
    }
  }

  void _replaceComponents(List<Map<String, dynamic>> components) {
    _disposeComponentInputs();
    _components = components.map(Map<String, dynamic>.from).toList();

    for (final component in _components) {
      final componentId = component['id'] as int;
      final storageType = component['storage_type'] as String;
      final semanticType =
          (component['semantic_type'] as String?) ?? DbHelper.semanticPlain;
      final value = component['value'];

      if (_usesTextEditor(storageType, semanticType)) {
        _textControllers[componentId] = TextEditingController(
          text: _textValueForComponent(component),
        );
      } else if (semanticType == DbHelper.semanticBoolean) {
        _booleanValues[componentId] = value as int?;
      } else if (semanticType == DbHelper.semanticEnum) {
        _enumValues[componentId] = value as String?;
      } else if (storageType == DbHelper.storageEntity) {
        _entityReferenceValues[componentId] = value as int?;
      }
    }
  }

  void _disposeComponentInputs() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }

    _textControllers.clear();
    _booleanValues.clear();
    _enumValues.clear();
    _entityReferenceValues.clear();
  }

  int? _resolveEntityKindId(int? preferredKindId) {
    final availableIds = _entityKinds.map((kind) => kind['id'] as int).toSet();

    if (preferredKindId != null && availableIds.contains(preferredKindId)) {
      return preferredKindId;
    }

    if (_entityKinds.isEmpty) {
      return null;
    }

    return _entityKinds.first['id'] as int;
  }

  String _textValueForComponent(Map<String, dynamic> component) {
    final storageType = component['storage_type'] as String;
    final semanticType =
        (component['semantic_type'] as String?) ?? DbHelper.semanticPlain;
    final value = component['value'];

    if (value == null) {
      return '';
    }

    if (storageType == DbHelper.storageInteger &&
        semanticType == DbHelper.semanticDate) {
      final milliseconds = value as int;
      final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '${date.year}-$month-$day';
    }

    return value.toString();
  }

  Future<void> _beginNewEntity() async {
    await _prepareNewEntity(preferredKindId: _selectedEntityKindId);
  }

  Future<void> _handleEntityKindChanged(int? entityKindId) async {
    if (entityKindId == null || entityKindId == _selectedEntityKindId) {
      return;
    }

    if (_hasAnyEnteredComponentValue()) {
      final confirmed = await showConfirmationDialog(
        context,
        title: 'Switch entity kind?',
        message:
            'Changing the entity kind will replace the current component form '
            'on screen. Unsaved values for fields that do not exist on the new '
            'kind will be discarded.',
        confirmLabel: 'Switch kind',
      );

      if (!confirmed) {
        return;
      }
    }

    await _loadComponentsForKind(entityKindId);
  }

  Future<void> _handleExistingEntitiesKindChanged(int? entityKindId) async {
    if (entityKindId == _existingEntitiesKindId) {
      return;
    }

    await _loadExistingEntities(kindId: entityKindId);
  }

  bool _hasAnyEnteredComponentValue() {
    for (final component in _components) {
      final componentId = component['id'] as int;
      final storageType = component['storage_type'] as String;
      final semanticType =
          (component['semantic_type'] as String?) ?? DbHelper.semanticPlain;

      if (_usesTextEditor(storageType, semanticType)) {
        final text = _textControllers[componentId]?.text ?? '';
        if (text.trim().isNotEmpty) {
          return true;
        }
      } else if (semanticType == DbHelper.semanticBoolean) {
        if (_booleanValues[componentId] != null) {
          return true;
        }
      } else if (semanticType == DbHelper.semanticEnum) {
        if ((_enumValues[componentId] ?? '').isNotEmpty) {
          return true;
        }
      } else if (storageType == DbHelper.storageEntity) {
        if (_entityReferenceValues[componentId] != null) {
          return true;
        }
      }
    }

    return false;
  }

  Future<void> _saveEntity() async {
    final entityKindId = _selectedEntityKindId;

    if (entityKindId == null) {
      await showNoticeDialog(
        context,
        title: 'Create an entity kind first',
        message: 'Create an entity kind first, then select it here.',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final componentValues = _collectComponentValues();
      if (_isEditing) {
        await dbHelper.updateEntity(
          entityId: _selectedEntityId!,
          kindId: entityKindId,
          componentValues: componentValues,
        );
      } else {
        await dbHelper.createEntity(
          kindId: entityKindId,
          componentValues: componentValues,
        );
      }

      await _loadPage(forceCreateMode: true);

      if (!mounted) {
        return;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      await showNoticeDialog(
        context,
        title: 'Unable to save entity',
        message: error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Map<int, Object?> _collectComponentValues() {
    final values = <int, Object?>{};

    for (final component in _components) {
      final componentId = component['id'] as int;
      values[componentId] = _componentInputValue(component);
    }

    return values;
  }

  Object? _componentInputValue(Map<String, dynamic> component) {
    final componentId = component['id'] as int;
    final storageType = component['storage_type'] as String;
    final semanticType =
        (component['semantic_type'] as String?) ?? DbHelper.semanticPlain;

    switch (storageType) {
      case DbHelper.storageInteger:
        if (semanticType == DbHelper.semanticBoolean) {
          return _booleanValues[componentId];
        }

        final rawText = _textControllers[componentId]?.text ?? '';
        if (rawText.trim().isEmpty) {
          return null;
        }

        if (semanticType == DbHelper.semanticDate) {
          final parsedInt = int.tryParse(rawText.trim());
          if (parsedInt != null) {
            return parsedInt;
          }

          final parsedDate = DateTime.tryParse(rawText.trim());
          if (parsedDate != null) {
            return DateTime(
              parsedDate.year,
              parsedDate.month,
              parsedDate.day,
            ).millisecondsSinceEpoch;
          }

          throw Exception(
            'Date fields must use YYYY-MM-DD or an integer timestamp.',
          );
        }

        final parsedInt = int.tryParse(rawText.trim());
        if (parsedInt == null) {
          throw Exception('Integer fields must use whole numbers.');
        }

        return parsedInt;

      case DbHelper.storageReal:
        final rawText = _textControllers[componentId]?.text ?? '';
        if (rawText.trim().isEmpty) {
          return null;
        }

        final parsedDouble = double.tryParse(rawText.trim());
        if (parsedDouble == null) {
          throw Exception('Real fields must use numeric values.');
        }

        return parsedDouble;

      case DbHelper.storageText:
        if (semanticType == DbHelper.semanticEnum) {
          return _enumValues[componentId];
        }

        final rawText = _textControllers[componentId]?.text ?? '';
        if (rawText.trim().isEmpty) {
          return null;
        }

        return rawText;

      case DbHelper.storageEntity:
        return _entityReferenceValues[componentId];
    }

    throw Exception('Unsupported component storage type "$storageType".');
  }

  Future<void> _deleteCurrentEntity() async {
    if (_selectedEntityId == null) {
      return;
    }

    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete entity?',
      message:
          'This permanently deletes the entity and all of its component values. '
          'The delete will be blocked if another entity still references it.',
      confirmLabel: 'Delete entity',
    );

    if (!confirmed) {
      return;
    }

    try {
      await dbHelper.deleteEntity(_selectedEntityId!);
      await _loadPage(forceCreateMode: true);

      if (!mounted) {
        return;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      await showNoticeDialog(
        context,
        title: 'Unable to delete entity',
        message: error.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorStatusLabel = _isEditing
        ? 'Entity #$_selectedEntityId'
        : (_hasEntityKinds ? 'Draft' : 'No kinds available');

    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('Entities')),
      children: [
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                title: 'Entities',
                description:
                    'Create, edit, and delete entities while managing all of '
                    'their component values on one screen.',
                primaryActionLabel: 'New entity',
                onPrimaryAction: _beginNewEntity,
                onRefresh: _loadPage,
              ),
              const SizedBox(height: 16),
              EditorHeading(
                title: _isEditing ? 'Edit entity' : 'New entity',
                statusLabel: editorStatusLabel,
                isActive: _hasEntityKinds,
              ),
              const SizedBox(height: 12),
              if (_hasEntityKinds)
                _isEditing
                    ? InfoLabel(
                        label: 'Entity kind',
                        child: Text(
                          _entityKindLabel(_selectedEntityKindId),
                          style: FluentTheme.of(context).typography.body,
                        ),
                      )
                    : LabeledComboBox<int>(
                        label: 'Entity kind',
                        value: _selectedEntityKindId,
                        width: 320,
                        items: _entityKinds
                            .map(
                              (entityKind) => ComboBoxItem<int>(
                                value: entityKind['id'] as int,
                                child: Text(
                                  entityKind['display_name'] as String,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _handleEntityKindChanged,
                      )
              else
                Text(
                  'No active entity kinds are available yet. Create them in '
                  'Definitions first.',
                  style: FluentTheme.of(context).typography.body,
                ),
              const SizedBox(height: 18),
              Text(
                'Component values',
                style: FluentTheme.of(context).typography.bodyStrong,
              ),
              const SizedBox(height: 8),
              Text(
                'Only component kinds linked to the selected entity kind are '
                'shown here. Leave a field blank or unset to omit that value.',
                style: FluentTheme.of(context).typography.caption,
              ),
              const SizedBox(height: 12),
              _buildComponentEditorPanel(context),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: _isSaving || !_hasEntityKinds
                        ? null
                        : _saveEntity,
                    child: Text(_isEditing ? 'Save changes' : 'Create entity'),
                  ),
                  if (_isEditing)
                    Button(
                      onPressed: _isSaving ? null : _deleteCurrentEntity,
                      child: const Text('Delete entity'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _buildExistingEntitiesList(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComponentEditorPanel(BuildContext context) {
    if (_isLoading && _components.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: ProgressRing()),
      );
    }

    if (!_hasEntityKinds || _selectedEntityKindId == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: FluentTheme.of(context).inactiveColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Select an entity kind to begin editing values.'),
      );
    }

    if (_components.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: FluentTheme.of(context).inactiveColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'This entity kind does not have any active component kinds linked yet.',
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: FluentTheme.of(context).inactiveColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _components
            .map(
              (component) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildComponentField(context, component),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildComponentField(
    BuildContext context,
    Map<String, dynamic> component,
  ) {
    final componentId = component['id'] as int;
    final displayName = component['display_name'] as String;
    final storageType = component['storage_type'] as String;
    final semanticType =
        (component['semantic_type'] as String?) ?? DbHelper.semanticPlain;
    final helperText = _componentHelperText(storageType, semanticType);

    if (semanticType == DbHelper.semanticBoolean) {
      return LabeledComboBox<int?>(
        label: displayName,
        value: _booleanValues[componentId],
        width: 320,
        items: const [
          ComboBoxItem<int?>(value: null, child: Text('Not set')),
          ComboBoxItem<int?>(value: 1, child: Text('True')),
          ComboBoxItem<int?>(value: 0, child: Text('False')),
        ],
        onChanged: (value) {
          setState(() => _booleanValues[componentId] = value);
        },
      );
    }

    if (semanticType == DbHelper.semanticEnum) {
      final enumOptions = List<Map<String, dynamic>>.from(
        component['enum_options'] as List<dynamic>? ?? const [],
      );

      return LabeledComboBox<String?>(
        label: displayName,
        value: _enumValues[componentId],
        width: 320,
        items: [
          const ComboBoxItem<String?>(value: null, child: Text('Not set')),
          ...enumOptions.map(
            (option) => ComboBoxItem<String?>(
              value: option['value'] as String,
              child: Text(option['display_label'] as String),
            ),
          ),
        ],
        onChanged: (value) {
          setState(() => _enumValues[componentId] = value);
        },
      );
    }

    if (storageType == DbHelper.storageEntity) {
      return LabeledComboBox<int?>(
        label: displayName,
        value: _entityReferenceValues[componentId],
        width: 360,
        items: [
          const ComboBoxItem<int?>(value: null, child: Text('Not set')),
          ..._allEntities.map(
            (entity) => ComboBoxItem<int?>(
              value: entity['id'] as int,
              child: Text(_entityLabel(entity)),
            ),
          ),
        ],
        onChanged: (value) {
          setState(() => _entityReferenceValues[componentId] = value);
        },
      );
    }

    final controller = _textControllers[componentId]!;
    final placeholder = switch (storageType) {
      DbHelper.storageInteger when semanticType == DbHelper.semanticDate =>
        'YYYY-MM-DD or timestamp',
      DbHelper.storageInteger => 'Whole number',
      DbHelper.storageReal => 'Decimal number',
      _ => 'Enter a value',
    };

    return LabeledTextBox(
      label: displayName,
      controller: controller,
      placeholder: placeholder,
      header: Text(
        helperText,
        style: FluentTheme.of(context).typography.caption,
      ),
    );
  }

  Widget _buildExistingEntitiesList(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Existing entities', style: theme.typography.bodyStrong),
        const SizedBox(height: 12),
        if (_hasEntityKinds)
          LabeledComboBox<int?>(
            label: 'Entity kind',
            value: _existingEntitiesKindId,
            width: 320,
            items: [
              const ComboBoxItem<int?>(
                value: null,
                child: Text('Select an entity kind'),
              ),
              ..._entityKinds.map(
                (entityKind) => ComboBoxItem<int?>(
                  value: entityKind['id'] as int,
                  child: Text(entityKind['display_name'] as String),
                ),
              ),
            ],
            onChanged: _handleExistingEntitiesKindChanged,
          )
        else
          Text(
            'No active entity kinds are available yet. Create them in '
            'Definitions first.',
            style: theme.typography.body,
          ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.inactiveColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _isExistingEntitiesLoading
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: ProgressRing()),
                )
              : !_hasEntityKinds
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Create an entity kind to begin managing entities.',
                  ),
                )
              : _existingEntitiesKindId == null
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Select an entity kind to view existing entities.',
                  ),
                )
              : _existingEntities.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No entities have been created for this entity kind yet.',
                  ),
                )
              : Column(
                  children: _existingEntities.map((entity) {
                    final entityId = entity['id'] as int;

                    return ListTile.selectable(
                      selected: entityId == _selectedEntityId,
                      title: Text('Entity #$entityId'),
                      subtitle: Text(
                        entity['component_summary'] as String? ??
                            'No component values set.',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => _loadEntityFromExistingEntity(entity),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  void _loadEntityFromExistingEntity(Map<String, dynamic> entity) {
    _selectedEntityId = entity['id'] as int;
    _selectedEntityKindId = entity['kind_id'] as int;

    final components = List<Map<String, dynamic>>.from(
      entity['components'] as List<dynamic>? ?? const [],
    );
    _replaceComponents(components);

    setState(() {});
  }

  String _existingEntitySummary(Map<String, dynamic> entity) {
    final components = List<Map<String, dynamic>>.from(
      entity['components'] as List<dynamic>? ?? const [],
    );
    final parts = components
        .where((component) => component['value'] != null)
        .map((component) {
          final label = component['display_name'] as String? ?? 'Value';
          final formattedValue = _formattedComponentValue(component);
          return formattedValue == null ? null : '$label: $formattedValue';
        })
        .whereType<String>()
        .toList();

    if (parts.isEmpty) {
      return 'No component values set.';
    }

    return parts.join(' | ');
  }

  String _entityKindLabel(int? entityKindId) {
    if (entityKindId == null) {
      return 'No entity kind selected';
    }

    for (final entityKind in _entityKinds) {
      if (entityKind['id'] == entityKindId) {
        return entityKind['display_name'] as String? ??
            entityKind['name'] as String? ??
            'Entity kind #$entityKindId';
      }
    }

    return 'Entity kind #$entityKindId';
  }

  String? _formattedComponentValue(Map<String, dynamic> component) {
    final value = component['value'];
    if (value == null) {
      return null;
    }

    final storageType = component['storage_type'] as String;
    final semanticType =
        (component['semantic_type'] as String?) ?? DbHelper.semanticPlain;

    if (semanticType == DbHelper.semanticBoolean) {
      return (value as int) == 1 ? 'True' : 'False';
    }

    if (storageType == DbHelper.storageInteger &&
        semanticType == DbHelper.semanticDate) {
      final date = DateTime.fromMillisecondsSinceEpoch(value as int);
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '${date.year}-$month-$day';
    }

    if (semanticType == DbHelper.semanticEnum) {
      final options = List<Map<String, dynamic>>.from(
        component['enum_options'] as List<dynamic>? ?? const [],
      );
      for (final option in options) {
        if (option['value'] == value) {
          return option['display_label'] as String? ?? value.toString();
        }
      }
      return value.toString();
    }

    if (storageType == DbHelper.storageEntity) {
      final referencedId = value as int;
      for (final entity in _allEntities) {
        if (entity['id'] == referencedId) {
          return _entityLabel(entity);
        }
      }
      return 'Entity #$referencedId';
    }

    return value.toString();
  }
}

bool _usesTextEditor(String storageType, String semanticType) {
  if (semanticType == DbHelper.semanticBoolean ||
      semanticType == DbHelper.semanticEnum) {
    return false;
  }

  return storageType != DbHelper.storageEntity;
}

String _componentHelperText(String storageType, String semanticType) {
  if (storageType == DbHelper.storageInteger &&
      semanticType == DbHelper.semanticDate) {
    return 'Stored as an integer timestamp.';
  }

  if (storageType == DbHelper.storageInteger) {
    return 'Stored as an integer value.';
  }

  if (storageType == DbHelper.storageReal) {
    return 'Stored as a real number.';
  }

  if (storageType == DbHelper.storageText &&
      semanticType == DbHelper.semanticPlain) {
    return 'Stored as text.';
  }

  if (storageType == DbHelper.storageText &&
      semanticType == DbHelper.semanticEnum) {
    return 'Pick from the allowed enum options.';
  }

  if (storageType == DbHelper.storageEntity) {
    return 'Reference any existing entity.';
  }

  return 'Enter a value for this component.';
}

String _entityLabel(Map<String, dynamic> entity) {
  final entityId = entity['id'] as int;
  final kindDisplayName =
      entity['kind_display_name'] as String? ??
      (entity['kind_name'] as String? ?? 'Entity');
  return '$kindDisplayName #$entityId';
}
