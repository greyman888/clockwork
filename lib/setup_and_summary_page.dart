import 'package:fluent_ui/fluent_ui.dart';

import 'app_db.dart';
import 'editor_helpers.dart';
import 'time_entry_formatting.dart';

typedef SetupAndSummaryPageDataLoader = Future<Map<String, dynamic>> Function();
typedef SetupAndSummaryProjectSaveHandler =
    Future<int> Function(SetupAndSummaryProjectSaveRequest request);
typedef SetupAndSummaryTaskSaveHandler =
    Future<int> Function(SetupAndSummaryTaskSaveRequest request);
typedef SetupAndSummaryDeleteHandler = Future<void> Function(int entityId);

class SetupAndSummaryProjectSaveRequest {
  const SetupAndSummaryProjectSaveRequest({required this.name, this.projectId});

  final String name;
  final int? projectId;
}

class SetupAndSummaryTaskSaveRequest {
  const SetupAndSummaryTaskSaveRequest({
    required this.name,
    required this.projectId,
    this.taskId,
  });

  final String name;
  final int projectId;
  final int? taskId;
}

class SetupAndSummaryPage extends StatefulWidget {
  const SetupAndSummaryPage({
    this.loadPageData,
    this.saveProject,
    this.saveTask,
    this.deleteEntity,
    super.key,
  });

  final SetupAndSummaryPageDataLoader? loadPageData;
  final SetupAndSummaryProjectSaveHandler? saveProject;
  final SetupAndSummaryTaskSaveHandler? saveTask;
  final SetupAndSummaryDeleteHandler? deleteEntity;

  @override
  State<SetupAndSummaryPage> createState() => _SetupAndSummaryPageState();
}

class _SetupAndSummaryPageState extends State<SetupAndSummaryPage> {
  static const double _setupColumnWidth = 400;
  static const double _summaryColumnMinWidth = 560;
  static const double _columnGap = 16;
  static const double _minimumPageWidth =
      _setupColumnWidth + _columnGap + _summaryColumnMinWidth;
  static const double _panelGap = 16;
  static const double _listHeight = 220;
  static const double _summaryKindColumnWidth = 88;
  static const double _summaryNameGap = 12;
  static const double _summaryTotalGap = 12;
  static const double _summaryTotalColumnWidth = 92;
  static const double _billabilityTitleColumnWidth = 168;
  static const double _billabilityGapWidth = 12;
  static const double _billabilityMonthColumnWidth = 72;
  static const double _billabilityAverageColumnWidth = 68;
  static const double _billabilityTableWidth =
      _billabilityTitleColumnWidth +
      (_billabilityGapWidth * 7) +
      (_billabilityMonthColumnWidth * 6) +
      _billabilityAverageColumnWidth;
  static const Map<int, TableColumnWidth> _summaryTableColumnWidths =
      <int, TableColumnWidth>{
        0: FixedColumnWidth(_summaryKindColumnWidth),
        1: FixedColumnWidth(_summaryNameGap),
        2: FlexColumnWidth(),
        3: FixedColumnWidth(_summaryTotalGap),
        4: FixedColumnWidth(_summaryTotalColumnWidth),
      };
  static const Map<int, TableColumnWidth> _billabilityTableColumnWidths =
      <int, TableColumnWidth>{
        0: FixedColumnWidth(_billabilityTitleColumnWidth),
        1: FixedColumnWidth(_billabilityGapWidth),
        2: FixedColumnWidth(_billabilityMonthColumnWidth),
        3: FixedColumnWidth(_billabilityGapWidth),
        4: FixedColumnWidth(_billabilityMonthColumnWidth),
        5: FixedColumnWidth(_billabilityGapWidth),
        6: FixedColumnWidth(_billabilityMonthColumnWidth),
        7: FixedColumnWidth(_billabilityGapWidth),
        8: FixedColumnWidth(_billabilityMonthColumnWidth),
        9: FixedColumnWidth(_billabilityGapWidth),
        10: FixedColumnWidth(_billabilityMonthColumnWidth),
        11: FixedColumnWidth(_billabilityGapWidth),
        12: FixedColumnWidth(_billabilityMonthColumnWidth),
        13: FixedColumnWidth(_billabilityGapWidth),
        14: FixedColumnWidth(_billabilityAverageColumnWidth),
      };
  static const List<String> _monthAbbreviations = <String>[
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

  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _taskNameController = TextEditingController();

  List<Map<String, dynamic>> _projects = const [];
  List<Map<String, dynamic>> _tasks = const [];
  List<Map<String, dynamic>> _summaryRows = const [];
  List<String> _billabilityMonthLabels = const [];
  List<Map<String, dynamic>> _billabilityRows = const [];
  int? _selectedProjectId;
  int? _editingProjectId;
  int? _selectedTaskId;
  int? _taskProjectId;
  bool _isLoading = true;
  bool _isProjectSaving = false;
  bool _isTaskSaving = false;
  String? _loadError;

  bool get _hasProjects => _projects.isNotEmpty;

  bool get _isEditingProject => _editingProjectId != null;

  bool get _isEditingTask => _selectedTaskId != null;

  Map<String, dynamic> _normalizeBillabilitySummary(dynamic rawSummary) {
    final summary = rawSummary is Map<String, dynamic>
        ? rawSummary
        : _buildEmptyBillabilitySummary(DateTime.now());
    return {
      'month_labels': List<String>.from(
        summary['month_labels'] as List<dynamic>? ??
            _defaultBillabilityMonthLabels(DateTime.now()),
      ),
      'rows': List<Map<String, dynamic>>.from(
        summary['rows'] as List<dynamic>? ?? _buildEmptyBillabilityRows(),
      ),
    };
  }

  List<String> _defaultBillabilityMonthLabels(DateTime referenceDate) {
    return List<String>.generate(6, (index) {
      final month = DateTime(
        referenceDate.year,
        referenceDate.month - 5 + index,
      );
      return _monthAbbreviations[month.month - 1];
    }, growable: false);
  }

  List<Map<String, dynamic>> _buildEmptyBillabilityRows() {
    return const [
      {
        'key': 'billable_hours',
        'label': 'Billable Hours',
        'display': 'hours',
        'monthly_values': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        'average_value': 0.0,
      },
      {
        'key': 'non_billable_hours',
        'label': 'Non Billable Hours',
        'display': 'hours',
        'monthly_values': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        'average_value': 0.0,
      },
      {
        'key': 'total_hours_worked',
        'label': 'Total Hours Worked',
        'display': 'hours',
        'monthly_values': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        'average_value': 0.0,
      },
      {
        'key': 'billability_percentage',
        'label': 'Billability %',
        'display': 'percentage',
        'monthly_values': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        'average_value': 0.0,
      },
    ];
  }

  Map<String, dynamic> _buildEmptyBillabilitySummary(DateTime referenceDate) {
    return {
      'month_labels': _defaultBillabilityMonthLabels(referenceDate),
      'rows': _buildEmptyBillabilityRows(),
    };
  }

  List<Map<String, dynamic>> get _visibleTasks {
    final projectId = _taskProjectId;
    if (projectId == null) {
      return _tasks;
    }

    return _tasks
        .where((task) => task['project_id'] == projectId)
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _taskNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPage({
    int? selectProjectId,
    int? editProjectId,
    int? editTaskId,
  }) async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final loadPageData =
          widget.loadPageData ?? dbHelper.getSetupAndSummaryPageData;
      final pageData = await loadPageData();
      final projects = List<Map<String, dynamic>>.from(
        pageData['projects'] as List<dynamic>? ?? const [],
      );
      final tasks = List<Map<String, dynamic>>.from(
        pageData['tasks'] as List<dynamic>? ?? const [],
      );
      final summaryRows = List<Map<String, dynamic>>.from(
        pageData['summary_rows'] as List<dynamic>? ?? const [],
      );
      final billabilitySummary = _normalizeBillabilitySummary(
        pageData['billability_summary'],
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _projects = projects;
        _tasks = tasks;
        _summaryRows = summaryRows;
        _billabilityMonthLabels = List<String>.from(
          billabilitySummary['month_labels'] as List<dynamic>? ?? const [],
        );
        _billabilityRows = List<Map<String, dynamic>>.from(
          billabilitySummary['rows'] as List<dynamic>? ?? const [],
        );
        _restoreSelectionState(
          preferredProjectId: selectProjectId,
          editProjectId: editProjectId,
          editTaskId: editTaskId,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _projects = const [];
        _tasks = const [];
        _summaryRows = const [];
        _billabilityMonthLabels = const [];
        _billabilityRows = const [];
        _selectedProjectId = null;
        _editingProjectId = null;
        _selectedTaskId = null;
        _taskProjectId = null;
        _projectNameController.clear();
        _taskNameController.clear();
        _loadError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _restoreSelectionState({
    int? preferredProjectId,
    int? editProjectId,
    int? editTaskId,
  }) {
    final nextEditingProject = _projectById(editProjectId);
    final nextEditingTask = _taskById(editTaskId);
    final nextEditingTaskProjectId = nextEditingTask?['project_id'] as int?;
    final nextProjectId = _resolveProjectId(
      preferredProjectId ??
          nextEditingTaskProjectId ??
          (nextEditingProject?['id'] as int?) ??
          _selectedProjectId ??
          _taskProjectId,
    );

    _selectedProjectId = nextProjectId;
    _editingProjectId = nextEditingProject?['id'] as int?;

    if (nextEditingProject != null) {
      _projectNameController.text = nextEditingProject['name'] as String;
    } else {
      _projectNameController.clear();
    }

    if (nextEditingTask != null) {
      _selectedTaskId = nextEditingTask['id'] as int;
      _taskNameController.text = nextEditingTask['name'] as String;
      _taskProjectId = nextEditingTaskProjectId ?? nextProjectId;
      return;
    }

    _selectedTaskId = null;
    _taskNameController.clear();
    _taskProjectId = _resolveProjectId(
      preferredProjectId ?? _taskProjectId ?? nextProjectId,
    );
  }

  int? _resolveProjectId(int? preferredProjectId) {
    final availableProjectIds = _projects
        .map((project) => project['id'] as int)
        .toSet();
    if (preferredProjectId != null &&
        availableProjectIds.contains(preferredProjectId)) {
      return preferredProjectId;
    }

    if (_projects.isEmpty) {
      return null;
    }

    return _projects.first['id'] as int;
  }

  Map<String, dynamic>? _projectById(int? projectId) {
    if (projectId == null) {
      return null;
    }

    for (final project in _projects) {
      if (project['id'] == projectId) {
        return project;
      }
    }

    return null;
  }

  Map<String, dynamic>? _taskById(int? taskId) {
    if (taskId == null) {
      return null;
    }

    for (final task in _tasks) {
      if (task['id'] == taskId) {
        return task;
      }
    }

    return null;
  }

  void _selectProject(Map<String, dynamic> project) {
    final projectId = project['id'] as int;
    final projectName = project['name'] as String;

    setState(() {
      _selectedProjectId = projectId;
      _editingProjectId = projectId;
      _projectNameController.text = projectName;
      _selectedTaskId = null;
      _taskNameController.clear();
      _taskProjectId = projectId;
    });
  }

  void _selectTask(Map<String, dynamic> task) {
    final taskId = task['id'] as int;
    final taskName = task['name'] as String;
    final taskProjectId = task['project_id'] as int?;

    setState(() {
      _selectedTaskId = taskId;
      _taskNameController.text = taskName;
      _taskProjectId = taskProjectId;
      _editingProjectId = null;
      _projectNameController.clear();
      if (_projectById(taskProjectId) != null) {
        _selectedProjectId = taskProjectId;
      }
    });
  }

  void _startNewProjectDraft() {
    setState(() {
      _editingProjectId = null;
      _projectNameController.clear();
    });
  }

  void _startNewTaskDraft() {
    setState(() {
      _selectedTaskId = null;
      _taskNameController.clear();
      _taskProjectId = _resolveProjectId(_taskProjectId ?? _selectedProjectId);
    });
  }

  Future<void> _saveProject() async {
    final projectName = _projectNameController.text.trim();
    if (projectName.isEmpty) {
      await showNoticeDialog(
        context,
        title: 'Enter a project name',
        message: 'Type a project name before saving.',
      );
      return;
    }

    setState(() => _isProjectSaving = true);

    try {
      final editingProjectId = _editingProjectId;
      final saveProject = widget.saveProject;
      final savedProjectId = saveProject != null
          ? await saveProject(
              SetupAndSummaryProjectSaveRequest(
                name: projectName,
                projectId: editingProjectId,
              ),
            )
          : await dbHelper.saveProject(
              name: projectName,
              projectId: editingProjectId,
            );

      if (!mounted) {
        return;
      }

      await _loadPage(
        selectProjectId: savedProjectId,
        editProjectId: editingProjectId == null ? null : savedProjectId,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      await showNoticeDialog(
        context,
        title: 'Unable to save project',
        message: error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isProjectSaving = false);
      }
    }
  }

  Future<void> _saveTask() async {
    final projectId = _taskProjectId;
    if (projectId == null) {
      await showNoticeDialog(
        context,
        title: 'Select a project first',
        message: 'Select a project for the task before saving.',
      );
      return;
    }

    final taskName = _taskNameController.text.trim();
    if (taskName.isEmpty) {
      await showNoticeDialog(
        context,
        title: 'Enter a task name',
        message: 'Type a task name before saving.',
      );
      return;
    }

    setState(() => _isTaskSaving = true);

    try {
      final editingTaskId = _selectedTaskId;
      final saveTask = widget.saveTask;
      final savedTaskId = saveTask != null
          ? await saveTask(
              SetupAndSummaryTaskSaveRequest(
                name: taskName,
                projectId: projectId,
                taskId: editingTaskId,
              ),
            )
          : await dbHelper.saveTask(
              name: taskName,
              projectId: projectId,
              taskId: editingTaskId,
            );

      if (!mounted) {
        return;
      }

      await _loadPage(
        selectProjectId: projectId,
        editTaskId: editingTaskId == null ? null : savedTaskId,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      await showNoticeDialog(
        context,
        title: 'Unable to save task',
        message: error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isTaskSaving = false);
      }
    }
  }

  Future<void> _deleteProject() async {
    final projectId = _editingProjectId;
    if (projectId == null) {
      return;
    }

    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete project?',
      message:
          'This permanently deletes the project entity and its component '
          'values. The delete will be blocked if any tasks still reference it.',
      confirmLabel: 'Delete project',
    );

    if (!confirmed) {
      return;
    }

    setState(() => _isProjectSaving = true);

    try {
      final deleteEntity = widget.deleteEntity ?? dbHelper.deleteEntity;
      await deleteEntity(projectId);

      if (!mounted) {
        return;
      }

      await _loadPage();
    } catch (error) {
      if (!mounted) {
        return;
      }

      await showNoticeDialog(
        context,
        title: 'Unable to delete project',
        message: error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isProjectSaving = false);
      }
    }
  }

  Future<void> _deleteTask() async {
    final taskId = _selectedTaskId;
    if (taskId == null) {
      return;
    }

    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete task?',
      message:
          'This permanently deletes the task entity and its component values. '
          'The delete will be blocked if any time entries still reference it.',
      confirmLabel: 'Delete task',
    );

    if (!confirmed) {
      return;
    }

    setState(() => _isTaskSaving = true);

    try {
      final deleteEntity = widget.deleteEntity ?? dbHelper.deleteEntity;
      await deleteEntity(taskId);

      if (!mounted) {
        return;
      }

      await _loadPage(selectProjectId: _taskProjectId);
    } catch (error) {
      if (!mounted) {
        return;
      }

      await showNoticeDialog(
        context,
        title: 'Unable to delete task',
        message: error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isTaskSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('Setup and Summary')),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth > _minimumPageWidth
                ? constraints.maxWidth
                : _minimumPageWidth;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                key: const Key('setupAndSummaryPageContent'),
                width: contentWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      key: const Key('setupAndSummarySetupColumn'),
                      width: _setupColumnWidth,
                      child: Column(
                        children: [
                          _buildProjectsCard(context),
                          const SizedBox(height: _panelGap),
                          _buildTasksCard(context),
                        ],
                      ),
                    ),
                    const SizedBox(width: _columnGap),
                    Expanded(
                      child: SizedBox(
                        key: const Key('setupAndSummarySummaryColumn'),
                        width: double.infinity,
                        child: Column(
                          children: [
                            _buildProjectSummaryCard(context),
                            const SizedBox(height: _panelGap),
                            _buildBillabilitySummaryCard(context),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProjectsCard(BuildContext context) {
    final theme = FluentTheme.of(context);
    final projectStatusLabel = _isEditingProject
        ? 'Project #$_editingProjectId'
        : 'Draft';

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Projects', style: theme.typography.subtitle),
          const SizedBox(height: 6),
          Text(
            'Create or rename project entities, then use the selected project as the task setup context.',
            style: theme.typography.body,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _isEditingProject ? 'Edit project' : 'New project',
                  style: theme.typography.bodyStrong,
                ),
              ),
              _statusPill(label: projectStatusLabel),
            ],
          ),
          const SizedBox(height: 12),
          InfoLabel(
            label: 'Project name',
            child: TextBox(
              key: const Key('setupSummaryProjectNameField'),
              controller: _projectNameController,
              placeholder: 'Enter a project name',
              enabled: !_isProjectSaving,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                key: const Key('setupSummarySaveProjectButton'),
                onPressed: _isProjectSaving ? null : _saveProject,
                child: Text(
                  _isEditingProject ? 'Save project' : 'Create project',
                ),
              ),
              Button(
                key: const Key('setupSummaryNewProjectButton'),
                onPressed: _isProjectSaving ? null : _startNewProjectDraft,
                child: const Text('New'),
              ),
              if (_isEditingProject)
                Button(
                  key: const Key('setupSummaryDeleteProjectButton'),
                  onPressed: _isProjectSaving ? null : _deleteProject,
                  child: const Text('Delete'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Existing projects', style: theme.typography.bodyStrong),
          const SizedBox(height: 12),
          _buildSelectionList(
            key: const Key('setupSummaryProjectList'),
            emptyMessage: 'No projects yet. Create the first project.',
            selectedId: _selectedProjectId,
            items: _projects,
            labelBuilder: (project) => project['name'] as String,
            onSelected: _selectProject,
          ),
        ],
      ),
    );
  }

  Widget _buildTasksCard(BuildContext context) {
    final theme = FluentTheme.of(context);
    final taskStatusLabel = _isEditingTask ? 'Task #$_selectedTaskId' : 'Draft';

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tasks', style: theme.typography.subtitle),
          const SizedBox(height: 6),
          Text(
            'Create or manage tasks within the current project context.',
            style: theme.typography.body,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _isEditingTask ? 'Edit task' : 'New task',
                  style: theme.typography.bodyStrong,
                ),
              ),
              _statusPill(label: taskStatusLabel),
            ],
          ),
          const SizedBox(height: 12),
          if (_hasProjects) ...[
            InfoLabel(
              label: 'Project',
              child: ComboBox<int?>(
                key: const Key('setupSummaryTaskProjectField'),
                value: _taskProjectId,
                isExpanded: true,
                items: [
                  const ComboBoxItem<int?>(
                    value: null,
                    child: Text('All projects'),
                  ),
                  ..._projects.map(
                    (project) => ComboBoxItem<int?>(
                      value: project['id'] as int,
                      child: Text(project['name'] as String),
                    ),
                  ),
                ],
                onChanged: _isTaskSaving
                    ? null
                    : (value) => setState(() => _taskProjectId = value),
              ),
            ),
            const SizedBox(height: 12),
            InfoLabel(
              label: 'Task name',
              child: TextBox(
                key: const Key('setupSummaryTaskNameField'),
                controller: _taskNameController,
                placeholder: 'Enter a task name',
                enabled: !_isTaskSaving,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  key: const Key('setupSummarySaveTaskButton'),
                  onPressed: _isTaskSaving ? null : _saveTask,
                  child: Text(_isEditingTask ? 'Save task' : 'Create task'),
                ),
                Button(
                  key: const Key('setupSummaryNewTaskButton'),
                  onPressed: _isTaskSaving ? null : _startNewTaskDraft,
                  child: const Text('New'),
                ),
                if (_isEditingTask)
                  Button(
                    key: const Key('setupSummaryDeleteTaskButton'),
                    onPressed: _isTaskSaving ? null : _deleteTask,
                    child: const Text('Delete'),
                  ),
              ],
            ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: theme.inactiveColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Create a project first before managing tasks.',
              ),
            ),
          const SizedBox(height: 18),
          Text('Existing tasks', style: theme.typography.bodyStrong),
          const SizedBox(height: 12),
          _buildSelectionList(
            key: const Key('setupSummaryTaskList'),
            emptyMessage: _hasProjects
                ? 'No tasks yet for the current project context.'
                : 'Create a project first before adding tasks.',
            selectedId: _selectedTaskId,
            items: _visibleTasks,
            labelBuilder: (task) {
              final taskName = task['name'] as String;
              final projectName = task['project_name'] as String?;
              return projectName == null
                  ? taskName
                  : '$projectName / $taskName';
            },
            onSelected: _selectTask,
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSummaryCard(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Project Summary', style: theme.typography.subtitle),
          const SizedBox(height: 6),
          Text(
            'Readonly all-time totals for current projects and tasks across every recorded day.',
            style: theme.typography.body,
          ),
          const SizedBox(height: 16),
          if (_isLoading && _summaryRows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: ProgressRing()),
            )
          else if (_loadError != null)
            _buildMessagePanel(context, _loadError!)
          else if (_summaryRows.isEmpty)
            _buildMessagePanel(
              context,
              'No projects or tasks are available yet. Use the setup tools to create them.',
            )
          else
            Container(
              key: const Key('setupSummaryPanel'),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: theme.inactiveColor),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: Table(
                key: const Key('setupSummaryTable'),
                columnWidths: _summaryTableColumnWidths,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  _buildSummaryHeaderRow(context),
                  ..._summaryRows.map(
                    (row) => _buildSummaryDataRow(context, row),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBillabilitySummaryCard(BuildContext context) {
    final theme = FluentTheme.of(context);
    final billabilitySummary = _normalizeBillabilitySummary({
      'month_labels': _billabilityMonthLabels,
      'rows': _billabilityRows,
    });
    final monthLabels = List<String>.from(
      billabilitySummary['month_labels'] as List<dynamic>? ?? const [],
    );
    final rows = List<Map<String, dynamic>>.from(
      billabilitySummary['rows'] as List<dynamic>? ?? const [],
    );

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Billability Summary', style: theme.typography.subtitle),
          const SizedBox(height: 6),
          Text(
            'Readonly billable and non billable totals for the last six calendar months, plus running averages.',
            style: theme.typography.body,
          ),
          const SizedBox(height: 16),
          if (_isLoading && _billabilityRows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: ProgressRing()),
            )
          else if (_loadError != null)
            _buildMessagePanel(context, _loadError!)
          else
            Container(
              key: const Key('setupBillabilitySummaryPanel'),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: theme.inactiveColor),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _billabilityTableWidth,
                  child: Table(
                    key: const Key('setupBillabilitySummaryTable'),
                    columnWidths: _billabilityTableColumnWidths,
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      _buildBillabilityHeaderRow(context, monthLabels),
                      ...rows.map(
                        (row) => _buildBillabilityDataRow(context, row),
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

  Widget _buildSelectionList({
    required Key key,
    required String emptyMessage,
    required int? selectedId,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) labelBuilder,
    required ValueChanged<Map<String, dynamic>> onSelected,
  }) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        height: _listHeight,
        decoration: BoxDecoration(
          border: Border.all(color: FluentTheme.of(context).inactiveColor),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(16),
        child: Text(emptyMessage),
      );
    }

    return Container(
      height: _listHeight,
      decoration: BoxDecoration(
        border: Border.all(color: FluentTheme.of(context).inactiveColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView(
        key: key,
        children: items
            .map((item) {
              final itemId = item['id'] as int;
              return ListTile.selectable(
                selected: itemId == selectedId,
                title: Text(
                  labelBuilder(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => onSelected(item),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  TableRow _buildSummaryHeaderRow(BuildContext context) {
    final theme = FluentTheme.of(context);

    return TableRow(
      children: [
        _summaryCell(
          child: Text('Kind', style: theme.typography.bodyStrong),
          bottomPadding: 10,
        ),
        const SizedBox.shrink(),
        _summaryCell(
          child: Text('Name', style: theme.typography.bodyStrong),
          bottomPadding: 10,
        ),
        const SizedBox.shrink(),
        _summaryCell(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Total', style: theme.typography.bodyStrong),
          ),
          bottomPadding: 10,
        ),
      ],
    );
  }

  TableRow _buildSummaryDataRow(
    BuildContext context,
    Map<String, dynamic> row,
  ) {
    final isProjectRow = row['kind'] == 'project';
    final projectId = row['project_id'] as int?;
    final taskName = row['task_name'] as String?;
    final projectName = row['project_name'] as String?;
    final displayName = isProjectRow
        ? (row['name'] as String? ?? projectName ?? 'Project')
        : projectId == null
        ? 'No project / ${taskName ?? row['name'] as String? ?? 'Task'}'
        : (taskName ?? row['name'] as String? ?? 'Task');
    final textStyle = isProjectRow
        ? FluentTheme.of(context).typography.bodyStrong
        : FluentTheme.of(context).typography.body;

    return TableRow(
      children: [
        _summaryCell(
          child: Text(isProjectRow ? 'Project' : 'Task', style: textStyle),
        ),
        const SizedBox.shrink(),
        _summaryCell(
          child: Padding(
            padding: EdgeInsets.only(
              left: isProjectRow || projectId == null ? 0 : 18,
            ),
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ),
        const SizedBox.shrink(),
        _summaryCell(
          child: Text(
            formatDurationMinutes(row['total_minutes'] as int? ?? 0),
            style: textStyle,
          ),
        ),
      ],
    );
  }

  TableRow _buildBillabilityHeaderRow(
    BuildContext context,
    List<String> monthLabels,
  ) {
    final theme = FluentTheme.of(context);
    final effectiveMonthLabels = monthLabels.length == 6
        ? monthLabels
        : _defaultBillabilityMonthLabels(DateTime.now());

    return TableRow(
      children: [
        _summaryCell(
          child: Text('Title', style: theme.typography.bodyStrong),
          bottomPadding: 10,
        ),
        _billabilityGapCell(),
        ..._buildBillabilityHeaderCells(theme, effectiveMonthLabels),
        _summaryCell(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('Average', style: theme.typography.bodyStrong),
          ),
          bottomPadding: 10,
        ),
      ],
    );
  }

  List<Widget> _buildBillabilityHeaderCells(
    FluentThemeData theme,
    List<String> monthLabels,
  ) {
    final cells = <Widget>[];
    for (var index = 0; index < monthLabels.length; index += 1) {
      cells.add(
        _summaryCell(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(monthLabels[index], style: theme.typography.bodyStrong),
          ),
          bottomPadding: 10,
        ),
      );
      cells.add(_billabilityGapCell());
    }
    return cells;
  }

  TableRow _buildBillabilityDataRow(
    BuildContext context,
    Map<String, dynamic> row,
  ) {
    final theme = FluentTheme.of(context);
    final monthlyValues = (row['monthly_values'] as List<dynamic>? ?? const [])
        .map((value) => (value as num?)?.toDouble() ?? 0.0)
        .toList(growable: false);
    final display = row['display'] as String? ?? 'hours';
    final averageValue = (row['average_value'] as num?)?.toDouble() ?? 0.0;

    return TableRow(
      children: [
        _summaryCell(
          child: Text(
            row['label'] as String? ?? '',
            style: theme.typography.bodyStrong,
          ),
        ),
        _billabilityGapCell(),
        ..._buildBillabilityValueCells(theme, monthlyValues, display: display),
        _summaryCell(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              _formatBillabilityValue(averageValue, display: display),
              style: theme.typography.body,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildBillabilityValueCells(
    FluentThemeData theme,
    List<double> monthlyValues, {
    required String display,
  }) {
    final values = List<double>.from(monthlyValues);
    while (values.length < 6) {
      values.add(0.0);
    }

    final cells = <Widget>[];
    for (var index = 0; index < 6; index += 1) {
      cells.add(
        _summaryCell(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              _formatBillabilityValue(values[index], display: display),
              style: theme.typography.body,
            ),
          ),
        ),
      );
      cells.add(_billabilityGapCell());
    }
    return cells;
  }

  String _formatBillabilityValue(double value, {required String display}) {
    if (display == 'percentage') {
      return '${value.toStringAsFixed(1)}%';
    }

    return value.toStringAsFixed(2);
  }

  Widget _buildMessagePanel(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: FluentTheme.of(context).inactiveColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message),
    );
  }

  Widget _statusPill({required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
      ),
    );
  }
}

Widget _summaryCell({required Widget child, double bottomPadding = 12}) {
  return Padding(
    padding: EdgeInsets.only(bottom: bottomPadding),
    child: child,
  );
}

Widget _billabilityGapCell() {
  return const SizedBox.shrink();
}
