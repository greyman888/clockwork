import 'package:clockwork/setup_and_summary_page.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'renders the setup managers and all-time summary rows without overflow',
    (tester) async {
      final store = _FakeSetupAndSummaryStore(
        projects: const [
          {'id': 1, 'name': 'Project Atlas'},
          {'id': 2, 'name': 'Project Bravo'},
          {'id': 3, 'name': 'Project Zero'},
        ],
        tasks: const [
          {'id': 11, 'project_id': 1, 'name': 'Analysis'},
          {'id': 12, 'project_id': 1, 'name': 'Reporting'},
          {'id': 21, 'project_id': 2, 'name': 'Returns'},
          {'id': 31, 'project_id': 3, 'name': 'Planning'},
        ],
        timeEntries: const [
          {'task_id': 11, 'duration_minutes': 90},
          {'task_id': 12, 'duration_minutes': 60},
          {'task_id': 21, 'duration_minutes': 75},
        ],
        billabilitySummary: const {
          'month_labels': ['Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr'],
          'rows': [
            {
              'key': 'billable_hours',
              'label': 'Billable Hours',
              'display': 'hours',
              'monthly_values': [0.0, 1.5, 2.0, 0.0, 1.0, 2.5],
              'average_value': 1.17,
            },
            {
              'key': 'non_billable_hours',
              'label': 'Non Billable Hours',
              'display': 'hours',
              'monthly_values': [0.0, 0.5, 0.0, 1.5, 1.0, 1.0],
              'average_value': 0.67,
            },
            {
              'key': 'total_hours_worked',
              'label': 'Total Hours Worked',
              'display': 'hours',
              'monthly_values': [0.0, 2.0, 2.0, 1.5, 2.0, 3.5],
              'average_value': 1.83,
            },
            {
              'key': 'billability_percentage',
              'label': 'Billability %',
              'display': 'percentage',
              'monthly_values': [0.0, 75.0, 100.0, 0.0, 50.0, 71.4],
              'average_value': 63.6,
            },
          ],
        },
      );

      await tester.binding.setSurfaceSize(const Size(1400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        FluentApp(
          home: SetupAndSummaryPage(
            loadPageData: store.load,
            saveProject: store.saveProject,
            saveTask: store.saveTask,
            deleteEntity: store.delete,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Setup and Summary'), findsOneWidget);
      expect(find.byKey(const Key('setupSummaryProjectList')), findsOneWidget);
      expect(find.byKey(const Key('setupSummaryTaskList')), findsOneWidget);
      expect(find.byKey(const Key('setupSummaryTable')), findsOneWidget);
      expect(
        find.byKey(const Key('setupBillabilitySummaryTable')),
        findsOneWidget,
      );
      expect(find.text('Billability Summary'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('setupSummaryTaskList')),
          matching: find.text('Project Atlas / Analysis'),
        ),
        findsOneWidget,
      );
      expect(find.text('Planning'), findsOneWidget);
      expect(find.text('2h 30m'), findsOneWidget);
      expect(find.text('1h 15m'), findsNWidgets(2));
      expect(find.text('Nov'), findsOneWidget);
      expect(find.text('Apr'), findsOneWidget);
      expect(find.text('1.17'), findsOneWidget);
      expect(find.text('63.6%'), findsOneWidget);
      expect(find.text('0m'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selecting a project filters the visible task list', (
    tester,
  ) async {
    final store = _FakeSetupAndSummaryStore(
      projects: const [
        {'id': 1, 'name': 'Project Atlas'},
        {'id': 2, 'name': 'Project Bravo'},
      ],
      tasks: const [
        {'id': 11, 'project_id': 1, 'name': 'Analysis'},
        {'id': 12, 'project_id': 1, 'name': 'Reporting'},
        {'id': 21, 'project_id': 2, 'name': 'Returns'},
      ],
      timeEntries: const [],
    );

    await tester.binding.setSurfaceSize(const Size(1400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      FluentApp(
        home: SetupAndSummaryPage(
          loadPageData: store.load,
          saveProject: store.saveProject,
          saveTask: store.saveTask,
          deleteEntity: store.delete,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('setupSummaryTaskList')),
        matching: find.text('Project Atlas / Analysis'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('setupSummaryTaskList')),
        matching: find.text('Project Bravo / Returns'),
      ),
      findsNothing,
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('setupSummaryProjectList')),
        matching: find.text('Project Bravo'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('setupSummaryTaskList')),
        matching: find.text('Project Bravo / Returns'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('setupSummaryTaskList')),
        matching: find.text('Project Atlas / Analysis'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'creating a project and task updates both setup lists and summary',
    (tester) async {
      final store = _FakeSetupAndSummaryStore(
        projects: const [],
        tasks: const [],
        timeEntries: const [],
      );

      await tester.binding.setSurfaceSize(const Size(1400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        FluentApp(
          home: SetupAndSummaryPage(
            loadPageData: store.load,
            saveProject: store.saveProject,
            saveTask: store.saveTask,
            deleteEntity: store.delete,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('setupSummaryProjectNameField')),
        'Project Atlas',
      );
      await tester.tap(find.byKey(const Key('setupSummarySaveProjectButton')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('setupSummaryProjectList')),
          matching: find.text('Project Atlas'),
        ),
        findsOneWidget,
      );
      expect(find.text('Project Atlas'), findsWidgets);

      await tester.ensureVisible(
        find.byKey(const Key('setupSummaryTaskNameField')),
      );
      await tester.enterText(
        find.byKey(const Key('setupSummaryTaskNameField')),
        'Analysis',
      );
      await tester.ensureVisible(
        find.byKey(const Key('setupSummarySaveTaskButton')),
      );
      await tester.tap(find.byKey(const Key('setupSummarySaveTaskButton')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('setupSummaryTaskList')),
          matching: find.text('Project Atlas / Analysis'),
        ),
        findsOneWidget,
      );
      expect(find.text('Analysis'), findsWidgets);
      expect(find.text('0m'), findsWidgets);
    },
  );
}

class _FakeSetupAndSummaryStore {
  _FakeSetupAndSummaryStore({
    required List<Map<String, dynamic>> projects,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> timeEntries,
    Map<String, dynamic>? billabilitySummary,
  }) : _projects = _cloneMapList(projects),
       _tasks = _cloneMapList(tasks),
       _timeEntries = _cloneMapList(timeEntries),
       _billabilitySummary = _cloneBillabilitySummary(
         billabilitySummary ?? _emptyBillabilitySummary(),
       ),
       _nextProjectId = _nextId(projects),
       _nextTaskId = _nextId(tasks);

  final List<Map<String, dynamic>> _projects;
  final List<Map<String, dynamic>> _tasks;
  final List<Map<String, dynamic>> _timeEntries;
  final Map<String, dynamic> _billabilitySummary;
  int _nextProjectId;
  int _nextTaskId;

  Future<Map<String, dynamic>> load() async => _buildPageData();

  Future<int> saveProject(SetupAndSummaryProjectSaveRequest request) async {
    final normalizedName = request.name.trim();
    if (normalizedName.isEmpty) {
      throw Exception('Project name is required.');
    }

    if (request.projectId == null) {
      final projectId = _nextProjectId++;
      _projects.add({'id': projectId, 'name': normalizedName});
      return projectId;
    }

    final existingProject = _projects.singleWhere(
      (project) => project['id'] == request.projectId,
    );
    existingProject['name'] = normalizedName;
    return request.projectId!;
  }

  Future<int> saveTask(SetupAndSummaryTaskSaveRequest request) async {
    final normalizedName = request.name.trim();
    if (normalizedName.isEmpty) {
      throw Exception('Task name is required.');
    }

    final project = _projects.singleWhere(
      (candidate) => candidate['id'] == request.projectId,
    );
    if (request.taskId == null) {
      final taskId = _nextTaskId++;
      _tasks.add({
        'id': taskId,
        'project_id': request.projectId,
        'name': normalizedName,
        'project_name': project['name'],
      });
      return taskId;
    }

    final existingTask = _tasks.singleWhere(
      (task) => task['id'] == request.taskId,
    );
    existingTask['name'] = normalizedName;
    existingTask['project_id'] = request.projectId;
    existingTask['project_name'] = project['name'];
    return request.taskId!;
  }

  Future<void> delete(int entityId) async {
    final projectIndex = _projects.indexWhere(
      (project) => project['id'] == entityId,
    );
    if (projectIndex >= 0) {
      final hasTasks = _tasks.any((task) => task['project_id'] == entityId);
      if (hasTasks) {
        throw Exception(
          'Cannot delete entity $entityId because another entity references it.',
        );
      }
      _projects.removeAt(projectIndex);
      return;
    }

    final taskIndex = _tasks.indexWhere((task) => task['id'] == entityId);
    if (taskIndex >= 0) {
      final hasTimeEntries = _timeEntries.any(
        (entry) => entry['task_id'] == entityId,
      );
      if (hasTimeEntries) {
        throw Exception(
          'Cannot delete entity $entityId because another entity references it.',
        );
      }
      _tasks.removeAt(taskIndex);
      return;
    }

    throw Exception('Entity $entityId was not found.');
  }

  Map<String, dynamic> _buildPageData() {
    final sortedProjects = _cloneMapList(_projects)
      ..sort(
        (left, right) =>
            (left['name'] as String).compareTo(right['name'] as String),
      );
    final projectNameById = {
      for (final project in sortedProjects)
        project['id'] as int: project['name'] as String,
    };
    final sortedTasks = _cloneMapList(_tasks)
      ..sort((left, right) {
        final leftProjectName =
            projectNameById[left['project_id'] as int?] ?? '';
        final rightProjectName =
            projectNameById[right['project_id'] as int?] ?? '';
        final projectComparison = leftProjectName.compareTo(rightProjectName);
        if (projectComparison != 0) {
          return projectComparison;
        }

        return (left['name'] as String).compareTo(right['name'] as String);
      });
    final decoratedTasks = sortedTasks
        .map((task) {
          return {
            ...task,
            'project_name': projectNameById[task['project_id'] as int?],
          };
        })
        .toList(growable: false);

    final taskTotals = <int, int>{};
    for (final entry in _timeEntries) {
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
    for (final task in decoratedTasks) {
      final projectId = task['project_id'] as int?;
      tasksByProjectId.putIfAbsent(projectId, () => <Map<String, dynamic>>[]);
      tasksByProjectId[projectId]!.add(task);
    }

    final summaryRows = <Map<String, dynamic>>[];
    for (final project in sortedProjects) {
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

    return {
      'projects': sortedProjects,
      'tasks': decoratedTasks,
      'summary_rows': summaryRows,
      'billability_summary': _cloneBillabilitySummary(_billabilitySummary),
    };
  }

  static int _nextId(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return 1;
    }

    return rows
            .map((row) => row['id'] as int? ?? 0)
            .reduce((current, next) => current > next ? current : next) +
        1;
  }
}

List<Map<String, dynamic>> _cloneMapList(List<Map<String, dynamic>> value) {
  return value.map((entry) => Map<String, dynamic>.from(entry)).toList();
}

Map<String, dynamic> _cloneBillabilitySummary(Map<String, dynamic> value) {
  return {
    'month_labels': List<String>.from(
      value['month_labels'] as List<dynamic>? ?? const [],
    ),
    'rows': List<Map<String, dynamic>>.from(
      (value['rows'] as List<dynamic>? ?? const []).map(
        (row) => {
          ...(row as Map<String, dynamic>),
          'monthly_values': List<double>.from(
            row['monthly_values'] as List<dynamic>? ?? const [],
          ),
        },
      ),
    ),
  };
}

Map<String, dynamic> _emptyBillabilitySummary() {
  return const {
    'month_labels': ['Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr'],
    'rows': [
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
    ],
  };
}
