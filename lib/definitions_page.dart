import 'package:fluent_ui/fluent_ui.dart';

import 'db_helper.dart';

const _storageTypeLabels = <String, String>{
  DbHelper.storageInteger: 'Integer',
  DbHelper.storageReal: 'Real',
  DbHelper.storageText: 'Text',
  DbHelper.storageEntity: 'Entity',
};

const _semanticTypeLabels = <String, String>{
  DbHelper.semanticPlain: 'Plain value',
  DbHelper.semanticBoolean: 'Boolean',
  DbHelper.semanticDate: 'Date',
  DbHelper.semanticEnum: 'Enum',
  DbHelper.semanticCurrency: 'Currency',
  DbHelper.semanticEntityReference: 'Entity reference',
};

class DefinitionsPage extends StatefulWidget {
  const DefinitionsPage({super.key});

  @override
  State<DefinitionsPage> createState() => _DefinitionsPageState();
}

class _DefinitionsPageState extends State<DefinitionsPage> {
  int _componentKindsVersion = 0;

  void _handleComponentKindsChanged() {
    setState(() => _componentKindsVersion++);
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('Definitions')),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1200;

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ComponentKindsSection(
                      onDefinitionsChanged: _handleComponentKindsChanged,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _EntityKindsSection(
                      componentKindsVersion: _componentKindsVersion,
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _ComponentKindsSection(
                  onDefinitionsChanged: _handleComponentKindsChanged,
                ),
                const SizedBox(height: 20),
                _EntityKindsSection(
                  componentKindsVersion: _componentKindsVersion,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ComponentKindsSection extends StatefulWidget {
  const _ComponentKindsSection({required this.onDefinitionsChanged});

  final VoidCallback onDefinitionsChanged;

  @override
  State<_ComponentKindsSection> createState() => _ComponentKindsSectionState();
}

class _EntityKindsSection extends StatefulWidget {
  const _EntityKindsSection({required this.componentKindsVersion});

  final int componentKindsVersion;

  @override
  State<_EntityKindsSection> createState() => _EntityKindsSectionState();
}

class _ComponentKindsSectionState extends State<_ComponentKindsSection> {
  final _nameController = TextEditingController();
  final _displayNameController = TextEditingController();

  List<Map<String, dynamic>> _componentKinds = const [];
  List<Map<String, dynamic>> _enumOptions = const [];
  int? _selectedComponentKindId;
  String _storageType = DbHelper.storageText;
  String _semanticType = DbHelper.semanticPlain;
  bool _includeInactive = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _message;
  InfoBarSeverity _messageSeverity = InfoBarSeverity.info;

  bool get _isEditing => _selectedComponentKindId != null;

  bool get _selectedIsActive {
    if (!_isEditing) {
      return true;
    }

    final selected = _componentKinds.where(
      (componentKind) => componentKind['id'] == _selectedComponentKindId,
    );

    if (selected.isEmpty) {
      return true;
    }

    return selected.first['status'] == DbHelper.activeStatus;
  }

  @override
  void initState() {
    super.initState();
    _loadComponentKinds();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadComponentKinds({int? selectId}) async {
    setState(() => _isLoading = true);

    try {
      final componentKinds = await dbHelper.getAllCompKinds(
        includeInactive: _includeInactive,
      );

      if (!mounted) {
        return;
      }

      final nextSelectedId = _resolveSelectedId(
        items: componentKinds,
        explicitSelection: selectId,
        currentSelection: _selectedComponentKindId,
      );

      setState(() {
        _componentKinds = componentKinds;
        _selectedComponentKindId = nextSelectedId;
      });

      if (nextSelectedId == null) {
        _resetComponentKindForm();
      } else {
        await _loadComponentKindDetail(nextSelectedId);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _message = error.toString();
        _messageSeverity = InfoBarSeverity.error;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadComponentKindDetail(int componentKindId) async {
    final componentKind = await dbHelper.getCompKind(componentKindId);
    if (!mounted) {
      return;
    }

    if (componentKind == null) {
      _resetComponentKindForm();
      return;
    }

    _nameController.text = componentKind['name'] as String? ?? '';
    _displayNameController.text =
        componentKind['display_name'] as String? ?? '';
    _storageType =
        componentKind['storage_type'] as String? ?? DbHelper.storageText;
    _semanticType =
        componentKind['semantic_type'] as String? ?? DbHelper.semanticPlain;
    _enumOptions = List<Map<String, dynamic>>.from(
      componentKind['enum_options'] as List<dynamic>? ?? const [],
    );

    setState(() {});
  }

  void _resetComponentKindForm() {
    _selectedComponentKindId = null;
    _nameController.clear();
    _displayNameController.clear();
    _storageType = DbHelper.storageText;
    _semanticType = DbHelper.semanticPlain;
    _enumOptions = const [];
    setState(() {});
  }

  Future<void> _saveComponentKind() async {
    final name = _nameController.text;
    final displayName = _displayNameController.text;
    final wasEditing = _isEditing;

    setState(() => _isSaving = true);

    try {
      int selectedId = _selectedComponentKindId ?? 0;

      if (wasEditing) {
        await dbHelper.updateCompKind(
          id: _selectedComponentKindId!,
          name: name,
          displayName: displayName,
          storageType: _storageType,
          semanticType: _semanticType,
          status: _selectedIsActive
              ? DbHelper.activeStatus
              : DbHelper.deletedStatus,
        );
      } else {
        selectedId = await dbHelper.createCompKind(
          name: name,
          displayName: displayName,
          storageType: _storageType,
          semanticType: _semanticType,
        );
      }

      widget.onDefinitionsChanged();
      await _loadComponentKinds(selectId: selectedId);

      if (!mounted) {
        return;
      }

      setState(() {
        _message = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _message = error.toString();
        _messageSeverity = InfoBarSeverity.error;
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _toggleComponentKindStatus() async {
    if (_selectedComponentKindId == null) {
      return;
    }

    final isActive = _selectedIsActive;
    final confirmed = await _showConfirmationDialog(
      context,
      title: isActive
          ? 'Soft delete component kind?'
          : 'Restore component kind?',
      message: isActive
          ? 'This component kind will be hidden from default views. Existing '
                'links and stored values will remain until you restore it or '
                'remove the link from an entity kind.'
          : 'This component kind will become active again and appear in default '
                'views.',
      confirmLabel: isActive ? 'Soft delete' : 'Restore',
    );

    if (!confirmed) {
      return;
    }

    try {
      if (isActive) {
        await dbHelper.softDeleteCompKind(_selectedComponentKindId!);
      } else {
        await dbHelper.restoreCompKind(_selectedComponentKindId!);
      }

      widget.onDefinitionsChanged();
      await _loadComponentKinds(selectId: _selectedComponentKindId);

      if (!mounted) {
        return;
      }

      setState(() {
        _message = isActive
            ? 'Component kind soft-deleted.'
            : 'Component kind restored.';
        _messageSeverity = InfoBarSeverity.success;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _message = error.toString();
        _messageSeverity = InfoBarSeverity.error;
      });
    }
  }

  Future<void> _createEnumOption() async {
    if (_selectedComponentKindId == null) {
      setState(() {
        _message = 'Save the component kind before adding enum options.';
        _messageSeverity = InfoBarSeverity.warning;
      });
      return;
    }

    final result = await _showEnumOptionDialog(context);
    if (result == null) {
      return;
    }

    try {
      await dbHelper.createEnumOption(
        compKindId: _selectedComponentKindId!,
        value: result.value,
        displayLabel: result.displayLabel,
        sortOrder: result.sortOrder,
      );

      await _loadComponentKinds(selectId: _selectedComponentKindId);

      if (!mounted) {
        return;
      }

      setState(() {
        _message = 'Enum option added.';
        _messageSeverity = InfoBarSeverity.success;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _message = error.toString();
        _messageSeverity = InfoBarSeverity.error;
      });
    }
  }

  Future<void> _editEnumOption(Map<String, dynamic> option) async {
    final result = await _showEnumOptionDialog(
      context,
      initialValue: option['value'] as String? ?? '',
      initialDisplayLabel: option['display_label'] as String? ?? '',
      initialSortOrder: option['sort_order'] as int? ?? 0,
    );

    if (result == null) {
      return;
    }

    try {
      await dbHelper.updateEnumOption(
        optionId: option['id'] as int,
        value: result.value,
        displayLabel: result.displayLabel,
        sortOrder: result.sortOrder,
      );

      await _loadComponentKinds(selectId: _selectedComponentKindId);

      if (!mounted) {
        return;
      }

      setState(() {
        _message = 'Enum option updated.';
        _messageSeverity = InfoBarSeverity.success;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _message = error.toString();
        _messageSeverity = InfoBarSeverity.error;
      });
    }
  }

  Future<void> _deleteEnumOption(Map<String, dynamic> option) async {
    final confirmed = await _showConfirmationDialog(
      context,
      title: 'Delete enum option?',
      message:
          'This removes the option definition. The delete will be blocked if it '
          'is still in use by any entity value.',
      confirmLabel: 'Delete option',
    );

    if (!confirmed) {
      return;
    }

    try {
      await dbHelper.deleteEnumOption(option['id'] as int);
      await _loadComponentKinds(selectId: _selectedComponentKindId);

      if (!mounted) {
        return;
      }

      setState(() {
        _message = 'Enum option deleted.';
        _messageSeverity = InfoBarSeverity.success;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _message = error.toString();
        _messageSeverity = InfoBarSeverity.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            title: 'Component Kinds',
            description:
                'Define the reusable fields available to entity kinds.',
            primaryActionLabel: 'New component kind',
            onPrimaryAction: _resetComponentKindForm,
            onRefresh: _loadComponentKinds,
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            _InlineMessageBar(
              text: _message!,
              severity: _messageSeverity,
              onClose: () => setState(() => _message = null),
            ),
          ],
          const SizedBox(height: 16),
          _buildComponentKindEditor(context),
          const SizedBox(height: 20),
          _buildComponentKindList(context),
          const SizedBox(height: 12),
          Checkbox(
            checked: _includeInactive,
            onChanged: (value) {
              setState(() => _includeInactive = value ?? false);
              _loadComponentKinds();
            },
            content: const Text('Show soft-deleted component kinds'),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentKindList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Existing component kinds',
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        const SizedBox(height: 12),
        Container(
          height: 360,
          decoration: BoxDecoration(
            border: Border.all(color: FluentTheme.of(context).inactiveColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _isLoading
              ? const Center(child: ProgressRing())
              : _componentKinds.isEmpty
              ? const Center(
                  child: Text('No component kinds yet. Create the first one.'),
                )
              : ListView.builder(
                  itemCount: _componentKinds.length,
                  itemBuilder: (context, index) {
                    final componentKind = _componentKinds[index];
                    final componentKindId = componentKind['id'] as int;
                    final isActive =
                        componentKind['status'] == DbHelper.activeStatus;
                    final summary =
                        '${_storageLabel(componentKind['storage_type'] as String)}'
                        ' • '
                        '${_semanticLabel(componentKind['semantic_type'] as String)}';

                    return ListTile.selectable(
                      selected: componentKindId == _selectedComponentKindId,
                      title: Text(componentKind['display_name'] as String),
                      subtitle: Text(
                        isActive ? summary : '$summary • soft-deleted',
                      ),
                      trailing: isActive
                          ? null
                          : const Icon(FluentIcons.blocked2, size: 14),
                      onPressed: () {
                        setState(
                          () => _selectedComponentKindId = componentKindId,
                        );
                        _loadComponentKindDetail(componentKindId);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildComponentKindEditor(BuildContext context) {
    final semanticOptions = _semanticOptionsForStorage(_storageType);
    if (!semanticOptions.contains(_semanticType)) {
      _semanticType = semanticOptions.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditorHeading(
          title: _isEditing ? 'Edit component kind' : 'New component kind',
          statusLabel: _isEditing
              ? (_selectedIsActive ? 'Active' : 'Soft-deleted')
              : 'Draft',
          isActive: _selectedIsActive,
        ),
        const SizedBox(height: 12),
        _LabeledTextBox(
          label: 'Internal name',
          controller: _nameController,
          placeholder: 'customer_number',
        ),
        const SizedBox(height: 12),
        _LabeledTextBox(
          label: 'Display name',
          controller: _displayNameController,
          placeholder: 'Customer Number',
        ),
        const SizedBox(height: 12),
        _LabeledComboBox<String>(
          label: 'Storage type',
          value: _storageType,
          items: _storageTypeLabels.entries
              .map(
                (entry) => ComboBoxItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }

            setState(() {
              _storageType = value;
              final options = _semanticOptionsForStorage(value);
              if (!options.contains(_semanticType)) {
                _semanticType = options.first;
              }
            });
          },
        ),
        const SizedBox(height: 12),
        _LabeledComboBox<String>(
          label: 'Semantic type',
          value: _semanticType,
          items: semanticOptions
              .map(
                (value) => ComboBoxItem<String>(
                  value: value,
                  child: Text(_semanticLabel(value)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _semanticType = value);
            }
          },
        ),
        const SizedBox(height: 12),
        Text(
          _componentKindHelpText(_storageType, _semanticType),
          style: FluentTheme.of(context).typography.caption,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: _isSaving ? null : _saveComponentKind,
              child: Text(
                _isEditing ? 'Save changes' : 'Create component kind',
              ),
            ),
            if (_isEditing)
              Button(
                onPressed: _isSaving ? null : _toggleComponentKindStatus,
                child: Text(_selectedIsActive ? 'Soft delete' : 'Restore'),
              ),
          ],
        ),
        if (_semanticType == DbHelper.semanticEnum) ...[
          const SizedBox(height: 24),
          _buildEnumOptionsPanel(context),
        ],
      ],
    );
  }

  Widget _buildEnumOptionsPanel(BuildContext context) {
    final canEditOptions = _selectedComponentKindId != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: FluentTheme.of(context).inactiveColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Enum options',
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
              ),
              Button(
                onPressed: canEditOptions ? _createEnumOption : null,
                child: const Text('Add option'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            canEditOptions
                ? 'Options are stored as text values with separate labels and '
                      'sort order.'
                : 'Save the component kind before managing enum options.',
            style: FluentTheme.of(context).typography.caption,
          ),
          const SizedBox(height: 12),
          if (_enumOptions.isEmpty)
            const Text('No enum options defined yet.')
          else
            ..._enumOptions.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(option['display_label'] as String? ?? ''),
                  subtitle: Text(
                    'Value: ${option['value']} • Sort: ${option['sort_order']}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(FluentIcons.edit),
                        onPressed: canEditOptions
                            ? () => _editEnumOption(option)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(FluentIcons.delete),
                        onPressed: canEditOptions
                            ? () => _deleteEnumOption(option)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EntityKindsSectionState extends State<_EntityKindsSection> {
  final _nameController = TextEditingController();
  final _displayNameController = TextEditingController();

  List<Map<String, dynamic>> _entityKinds = const [];
  List<Map<String, dynamic>> _allComponentKinds = const [];
  Set<int> _linkedComponentKindIds = const {};
  Set<int> _originalLinkedComponentKindIds = const {};
  int? _selectedEntityKindId;
  bool _includeInactive = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _message;
  InfoBarSeverity _messageSeverity = InfoBarSeverity.info;

  bool get _isEditing => _selectedEntityKindId != null;

  bool get _selectedIsActive {
    if (!_isEditing) {
      return true;
    }

    final selected = _entityKinds.where(
      (entityKind) => entityKind['id'] == _selectedEntityKindId,
    );

    if (selected.isEmpty) {
      return true;
    }

    return selected.first['status'] == DbHelper.activeStatus;
  }

  @override
  void initState() {
    super.initState();
    _loadEntityKinds();
  }

  @override
  void didUpdateWidget(covariant _EntityKindsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.componentKindsVersion != widget.componentKindsVersion) {
      _loadEntityKinds(selectId: _selectedEntityKindId);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadEntityKinds({int? selectId}) async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        dbHelper.getAllEntityKinds(includeInactive: _includeInactive),
        dbHelper.getAllCompKinds(includeInactive: true),
      ]);

      if (!mounted) {
        return;
      }

      final entityKinds = results[0];
      final allComponentKinds = results[1];
      final nextSelectedId = _resolveSelectedId(
        items: entityKinds,
        explicitSelection: selectId,
        currentSelection: _selectedEntityKindId,
      );

      setState(() {
        _entityKinds = entityKinds;
        _allComponentKinds = allComponentKinds;
        _selectedEntityKindId = nextSelectedId;
      });

      if (nextSelectedId == null) {
        _resetEntityKindForm();
      } else {
        await _loadEntityKindDetail(nextSelectedId);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _message = error.toString();
        _messageSeverity = InfoBarSeverity.error;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadEntityKindDetail(int entityKindId) async {
    final entityKind = await dbHelper.getEntityKind(
      entityKindId,
      includeInactiveCompKinds: true,
    );

    if (!mounted) {
      return;
    }

    if (entityKind == null) {
      _resetEntityKindForm();
      return;
    }

    final compKindIds = List<int>.from(
      entityKind['comp_kind_ids'] as List<dynamic>? ?? const [],
    );

    _nameController.text = entityKind['name'] as String? ?? '';
    _displayNameController.text = entityKind['display_name'] as String? ?? '';
    _linkedComponentKindIds = compKindIds.toSet();
    _originalLinkedComponentKindIds = compKindIds.toSet();
    setState(() {});
  }

  void _resetEntityKindForm() {
    _selectedEntityKindId = null;
    _nameController.clear();
    _displayNameController.clear();
    _linkedComponentKindIds = <int>{};
    _originalLinkedComponentKindIds = <int>{};
    setState(() {});
  }

  Future<void> _saveEntityKind() async {
    final name = _nameController.text;
    final displayName = _displayNameController.text;
    final wasEditing = _isEditing;
    final linkedCompKindIds = _linkedComponentKindIds.toList()..sort();
    final removedCompKindIds =
        _originalLinkedComponentKindIds
            .difference(_linkedComponentKindIds)
            .toList()
          ..sort();

    if (wasEditing && removedCompKindIds.isNotEmpty) {
      final confirmed = await _showConfirmationDialog(
        context,
        title: 'Remove linked component kinds?',
        message:
            'Removing a linked component kind will delete stored values for that '
            'field across all entities of this kind. Continue with the save?',
        confirmLabel: 'Save changes',
      );

      if (!confirmed) {
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      int selectedId = _selectedEntityKindId ?? 0;

      if (wasEditing) {
        await dbHelper.updateEntityKind(
          id: _selectedEntityKindId!,
          name: name,
          displayName: displayName,
          compKindIds: linkedCompKindIds,
          status: _selectedIsActive
              ? DbHelper.activeStatus
              : DbHelper.deletedStatus,
        );
      } else {
        selectedId = await dbHelper.createEntityKind(
          name: name,
          displayName: displayName,
          compKindIds: linkedCompKindIds,
        );
      }

      await _loadEntityKinds(selectId: selectedId);

      if (!mounted) {
        return;
      }

      setState(() {
        _message = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _message = error.toString();
        _messageSeverity = InfoBarSeverity.error;
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _toggleEntityKindStatus() async {
    if (_selectedEntityKindId == null) {
      return;
    }

    final isActive = _selectedIsActive;
    final confirmed = await _showConfirmationDialog(
      context,
      title: isActive ? 'Soft delete entity kind?' : 'Restore entity kind?',
      message: isActive
          ? 'This entity kind will be hidden from default views, but can be '
                'restored later.'
          : 'This entity kind will become active again and appear in default '
                'views.',
      confirmLabel: isActive ? 'Soft delete' : 'Restore',
    );

    if (!confirmed) {
      return;
    }

    try {
      if (isActive) {
        await dbHelper.softDeleteEntityKind(_selectedEntityKindId!);
      } else {
        await dbHelper.restoreEntityKind(_selectedEntityKindId!);
      }

      await _loadEntityKinds(selectId: _selectedEntityKindId);

      if (!mounted) {
        return;
      }

      setState(() {
        _message = isActive
            ? 'Entity kind soft-deleted.'
            : 'Entity kind restored.';
        _messageSeverity = InfoBarSeverity.success;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _message = error.toString();
        _messageSeverity = InfoBarSeverity.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            title: 'Entity Kinds',
            description:
                'Define object categories and the component kinds they use.',
            primaryActionLabel: 'New entity kind',
            onPrimaryAction: _resetEntityKindForm,
            onRefresh: _loadEntityKinds,
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            _InlineMessageBar(
              text: _message!,
              severity: _messageSeverity,
              onClose: () => setState(() => _message = null),
            ),
          ],
          const SizedBox(height: 16),
          _buildEntityKindEditor(context),
          const SizedBox(height: 20),
          _buildEntityKindList(context),
          const SizedBox(height: 12),
          Checkbox(
            checked: _includeInactive,
            onChanged: (value) {
              setState(() => _includeInactive = value ?? false);
              _loadEntityKinds();
            },
            content: const Text('Show soft-deleted entity kinds'),
          ),
        ],
      ),
    );
  }

  Widget _buildEntityKindList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Existing entity kinds',
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        const SizedBox(height: 12),
        Container(
          height: 360,
          decoration: BoxDecoration(
            border: Border.all(color: FluentTheme.of(context).inactiveColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _isLoading
              ? const Center(child: ProgressRing())
              : _entityKinds.isEmpty
              ? const Center(child: Text('No entity kinds yet.'))
              : ListView.builder(
                  itemCount: _entityKinds.length,
                  itemBuilder: (context, index) {
                    final entityKind = _entityKinds[index];
                    final entityKindId = entityKind['id'] as int;
                    final isActive =
                        entityKind['status'] == DbHelper.activeStatus;
                    final compKindCount = entityKind['comp_kind_count'];

                    return ListTile.selectable(
                      selected: entityKindId == _selectedEntityKindId,
                      title: Text(entityKind['display_name'] as String),
                      subtitle: Text(
                        isActive
                            ? '$compKindCount linked component kinds'
                            : '$compKindCount linked component kinds • soft-deleted',
                      ),
                      trailing: isActive
                          ? null
                          : const Icon(FluentIcons.blocked2, size: 14),
                      onPressed: () {
                        setState(() => _selectedEntityKindId = entityKindId);
                        _loadEntityKindDetail(entityKindId);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEntityKindEditor(BuildContext context) {
    final visibleComponentKinds = _allComponentKinds.where((componentKind) {
      final componentKindId = componentKind['id'] as int;
      final isActive = componentKind['status'] == DbHelper.activeStatus;
      return isActive || _linkedComponentKindIds.contains(componentKindId);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditorHeading(
          title: _isEditing ? 'Edit entity kind' : 'New entity kind',
          statusLabel: _isEditing
              ? (_selectedIsActive ? 'Active' : 'Soft-deleted')
              : 'Draft',
          isActive: _selectedIsActive,
        ),
        const SizedBox(height: 12),
        _LabeledTextBox(
          label: 'Internal name',
          controller: _nameController,
          placeholder: 'customer',
        ),
        const SizedBox(height: 12),
        _LabeledTextBox(
          label: 'Display name',
          controller: _displayNameController,
          placeholder: 'Customer',
        ),
        const SizedBox(height: 18),
        Text(
          'Linked component kinds',
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        const SizedBox(height: 8),
        Text(
          'Links are shown in component kind creation order. Inactive linked '
          'component kinds stay visible here until you remove them or restore '
          'them from the component kinds editor.',
          style: FluentTheme.of(context).typography.caption,
        ),
        const SizedBox(height: 12),
        Container(
          height: 320,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: FluentTheme.of(context).inactiveColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: visibleComponentKinds.isEmpty
              ? const Center(
                  child: Text(
                    'No component kinds are available yet. Create component '
                    'kinds first.',
                  ),
                )
              : ListView(
                  children: visibleComponentKinds.map((componentKind) {
                    final componentKindId = componentKind['id'] as int;
                    final isActive =
                        componentKind['status'] == DbHelper.activeStatus;

                    return Checkbox(
                      checked: _linkedComponentKindIds.contains(
                        componentKindId,
                      ),
                      onChanged: (value) {
                        final isChecked = value ?? false;
                        setState(() {
                          final nextIds = Set<int>.from(
                            _linkedComponentKindIds,
                          );
                          if (isChecked) {
                            nextIds.add(componentKindId);
                          } else {
                            nextIds.remove(componentKindId);
                          }
                          _linkedComponentKindIds = nextIds;
                        });
                      },
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(componentKind['display_name'] as String),
                          Text(
                            isActive
                                ? '${_storageLabel(componentKind['storage_type'] as String)}'
                                      ' • '
                                      '${_semanticLabel(componentKind['semantic_type'] as String)}'
                                : '${_storageLabel(componentKind['storage_type'] as String)}'
                                      ' • '
                                      '${_semanticLabel(componentKind['semantic_type'] as String)}'
                                      ' • soft-deleted',
                            style: FluentTheme.of(context).typography.caption,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: _isSaving ? null : _saveEntityKind,
              child: Text(_isEditing ? 'Save changes' : 'Create entity kind'),
            ),
            if (_isEditing)
              Button(
                onPressed: _isSaving ? null : _toggleEntityKindStatus,
                child: Text(_selectedIsActive ? 'Soft delete' : 'Restore'),
              ),
          ],
        ),
      ],
    );
  }
}

int? _resolveSelectedId({
  required List<Map<String, dynamic>> items,
  required int? explicitSelection,
  required int? currentSelection,
}) {
  final availableIds = items.map((item) => item['id'] as int).toSet();

  if (explicitSelection != null && availableIds.contains(explicitSelection)) {
    return explicitSelection;
  }

  if (currentSelection != null && availableIds.contains(currentSelection)) {
    return currentSelection;
  }

  if (items.isEmpty) {
    return null;
  }

  return items.first['id'] as int;
}

String _storageLabel(String value) {
  return _storageTypeLabels[value] ?? value;
}

String _semanticLabel(String value) {
  return _semanticTypeLabels[value] ?? value;
}

List<String> _semanticOptionsForStorage(String storageType) {
  switch (storageType) {
    case DbHelper.storageInteger:
      return const [
        DbHelper.semanticPlain,
        DbHelper.semanticBoolean,
        DbHelper.semanticDate,
      ];
    case DbHelper.storageReal:
      return const [DbHelper.semanticPlain, DbHelper.semanticCurrency];
    case DbHelper.storageText:
      return const [DbHelper.semanticPlain, DbHelper.semanticEnum];
    case DbHelper.storageEntity:
      return const [DbHelper.semanticEntityReference];
  }

  return const [DbHelper.semanticPlain];
}

String _componentKindHelpText(String storageType, String semanticType) {
  if (storageType == DbHelper.storageInteger &&
      semanticType == DbHelper.semanticBoolean) {
    return 'Boolean values will be stored as 0 or 1 in the integer component table.';
  }

  if (storageType == DbHelper.storageInteger &&
      semanticType == DbHelper.semanticDate) {
    return 'Date values will be stored as integer timestamps in the integer component table.';
  }

  if (storageType == DbHelper.storageText &&
      semanticType == DbHelper.semanticEnum) {
    return 'Enum values will be stored in the text component table and validated against the option list.';
  }

  if (storageType == DbHelper.storageEntity) {
    return 'Entity reference values point to any entity record and are stored in the entity component table.';
  }

  return 'The semantic type controls presentation and validation while storage stays fixed by physical type.';
}

Future<bool> _showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return ContentDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          Button(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  return result ?? false;
}

Future<_EnumOptionDraft?> _showEnumOptionDialog(
  BuildContext context, {
  String initialValue = '',
  String initialDisplayLabel = '',
  int initialSortOrder = 0,
}) async {
  final valueController = TextEditingController(text: initialValue);
  final displayLabelController = TextEditingController(
    text: initialDisplayLabel,
  );
  final sortOrderController = TextEditingController(
    text: initialSortOrder.toString(),
  );

  try {
    return await showDialog<_EnumOptionDraft>(
      context: context,
      builder: (dialogContext) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return ContentDialog(
              title: Text(
                initialValue.isEmpty ? 'Add enum option' : 'Edit enum option',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LabeledTextBox(
                    label: 'Value',
                    controller: valueController,
                    placeholder: 'active',
                  ),
                  const SizedBox(height: 12),
                  _LabeledTextBox(
                    label: 'Display label',
                    controller: displayLabelController,
                    placeholder: 'Active',
                  ),
                  const SizedBox(height: 12),
                  _LabeledTextBox(
                    label: 'Sort order',
                    controller: sortOrderController,
                    placeholder: '0',
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      style: TextStyle(color: Colors.errorPrimaryColor),
                    ),
                  ],
                ],
              ),
              actions: [
                Button(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = valueController.text.trim();
                    final displayLabel = displayLabelController.text.trim();
                    final sortOrder = int.tryParse(
                      sortOrderController.text.trim(),
                    );

                    if (value.isEmpty || displayLabel.isEmpty) {
                      setDialogState(() {
                        errorText = 'Value and display label are required.';
                      });
                      return;
                    }

                    if (sortOrder == null || sortOrder < 0) {
                      setDialogState(() {
                        errorText =
                            'Sort order must be a whole number of 0 or more.';
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(
                      _EnumOptionDraft(
                        value: value,
                        displayLabel: displayLabel,
                        sortOrder: sortOrder,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    valueController.dispose();
    displayLabelController.dispose();
    sortOrderController.dispose();
  }
}

class _EnumOptionDraft {
  const _EnumOptionDraft({
    required this.value,
    required this.displayLabel,
    required this.sortOrder,
  });

  final String value;
  final String displayLabel;
  final int sortOrder;
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.description,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    required this.onRefresh,
  });

  final String title;
  final String description;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.typography.subtitle),
              const SizedBox(height: 6),
              Text(description, style: theme.typography.body),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Button(onPressed: onRefresh, child: const Text('Refresh')),
            FilledButton(
              onPressed: onPrimaryAction,
              child: Text(primaryActionLabel),
            ),
          ],
        ),
      ],
    );
  }
}

class _InlineMessageBar extends StatelessWidget {
  const _InlineMessageBar({
    required this.text,
    required this.severity,
    required this.onClose,
  });

  final String text;
  final InfoBarSeverity severity;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return InfoBar(
      title: const Text('Definitions'),
      content: Text(text),
      severity: severity,
      isLong: true,
      onClose: onClose,
    );
  }
}

class _EditorHeading extends StatelessWidget {
  const _EditorHeading({
    required this.title,
    required this.statusLabel,
    required this.isActive,
  });

  final String title;
  final String statusLabel;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      children: [
        Expanded(child: Text(title, style: theme.typography.bodyStrong)),
        _StatusPill(label: statusLabel, isActive: isActive),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.isActive});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isActive
        ? Colors.successPrimaryColor.withAlpha(35)
        : Colors.warningPrimaryColor.withAlpha(40);
    final foregroundColor = isActive
        ? Colors.successPrimaryColor
        : Colors.warningPrimaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: foregroundColor, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _LabeledTextBox extends StatelessWidget {
  const _LabeledTextBox({
    required this.label,
    required this.controller,
    required this.placeholder,
  });

  final String label;
  final TextEditingController controller;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return InfoLabel(
      label: label,
      child: TextBox(controller: controller, placeholder: placeholder),
    );
  }
}

class _LabeledComboBox<T> extends StatelessWidget {
  const _LabeledComboBox({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<ComboBoxItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InfoLabel(
      label: label,
      child: SizedBox(
        width: 260,
        child: ComboBox<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
        ),
      ),
    );
  }
}
