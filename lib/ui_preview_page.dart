import 'package:fluent_ui/fluent_ui.dart';

import 'day_page.dart';
import 'setup_and_summary_page.dart';
import 'time_entry_formatting.dart';
import 'week_page.dart';

class UiPreviewPage extends StatefulWidget {
  const UiPreviewPage({super.key});

  @override
  State<UiPreviewPage> createState() => _UiPreviewPageState();
}

enum _PreviewViewportId { primaryDesktop, compactDesktop }

enum _PreviewScenarioId {
  dayEmpty,
  dayPopulated,
  dayOverlap,
  dayLongContent,
  dayBoundaryEndOfDay,
  dayWeekDrillIn,
  weekEmpty,
  weekMixedBillable,
  weekLongLabels,
  weekNotesPopup,
  weekWeekdayLinks,
  setupSummaryEmpty,
  setupSummaryPopulated,
  setupSummaryLongNames,
}

class _PreviewViewportSpec {
  const _PreviewViewportSpec({
    required this.label,
    required this.width,
    required this.height,
  });

  final String label;
  final double width;
  final double height;
}

class _PreviewScenarioDefinition {
  const _PreviewScenarioDefinition({
    required this.id,
    required this.group,
    required this.title,
    required this.description,
  });

  final _PreviewScenarioId id;
  final String group;
  final String title;
  final String description;
}

class _UiPreviewPageState extends State<UiPreviewPage> {
  static final DateTime _previewToday = dateOnly(DateTime(2026, 4, 8));
  static final Map<_PreviewViewportId, _PreviewViewportSpec> _viewportSpecs = {
    _PreviewViewportId.primaryDesktop: const _PreviewViewportSpec(
      label: 'Primary desktop (1400 x 900)',
      width: 1400,
      height: 900,
    ),
    _PreviewViewportId.compactDesktop: const _PreviewViewportSpec(
      label: 'Compact desktop (1100 x 900)',
      width: 1100,
      height: 900,
    ),
  };
  static const List<_PreviewScenarioDefinition> _scenarioDefinitions = [
    _PreviewScenarioDefinition(
      id: _PreviewScenarioId.dayEmpty,
      group: 'Day',
      title: 'Day / Empty State',
      description:
          'Blank new-row state with no saved entries for the selected day.',
    ),
    _PreviewScenarioDefinition(
      id: _PreviewScenarioId.dayPopulated,
      group: 'Day',
      title: 'Day / Populated',
      description:
          'Happy-path data entry view with multiple saved rows and a running total.',
    ),
    _PreviewScenarioDefinition(
      id: _PreviewScenarioId.dayOverlap,
      group: 'Day',
      title: 'Day / Overlap Warnings',
      description:
          'Overlapping time ranges with warnings visible for visual validation.',
    ),
    _PreviewScenarioDefinition(
      id: _PreviewScenarioId.dayLongContent,
      group: 'Day',
      title: 'Day / Long Content',
      description:
          'Long project, task, and note values to inspect truncation and column stability.',
    ),
    _PreviewScenarioDefinition(
      id: _PreviewScenarioId.dayBoundaryEndOfDay,
      group: 'Day',
      title: 'Day / 24:00 Boundary',
      description:
          'Entries that run through the end of day to validate 24:00 handling.',
    ),
    _PreviewScenarioDefinition(
      id: _PreviewScenarioId.dayWeekDrillIn,
      group: 'Day',
      title: 'Day / From Week Navigation',
      description:
          'Destination preview used when a week header link opens a specific day.',
    ),
    _PreviewScenarioDefinition(
      id: _PreviewScenarioId.weekEmpty,
      group: 'Week',
      title: 'Week / Empty Week',
      description:
          'No rows for the selected week while projects still exist in the system.',
    ),
    _PreviewScenarioDefinition(
      id: _PreviewScenarioId.weekMixedBillable,
      group: 'Week',
      title: 'Week / Mixed Billable',
      description:
          'Separate billable and non-billable rows for the same project and task.',
    ),
    _PreviewScenarioDefinition(
      id: _PreviewScenarioId.weekLongLabels,
      group: 'Week',
      title: 'Week / Long Labels',
      description:
          'Long project and task labels to inspect clipping and interactive targets.',
    ),
    _PreviewScenarioDefinition(
      id: _PreviewScenarioId.weekNotesPopup,
      group: 'Week',
      title: 'Week / Notes Popup',
      description:
          'Preview with the notes dialog opened automatically for width and copy affordance checks.',
    ),
    _PreviewScenarioDefinition(
      id: _PreviewScenarioId.weekWeekdayLinks,
      group: 'Week',
      title: 'Week / Weekday Links',
      description:
          'Interactive week preview that can drill into the linked day preview.',
    ),
    _PreviewScenarioDefinition(
      id: _PreviewScenarioId.setupSummaryEmpty,
      group: 'Setup and Summary',
      title: 'Setup and Summary / Empty',
      description: 'First-run state with no projects or tasks created yet.',
    ),
    _PreviewScenarioDefinition(
      id: _PreviewScenarioId.setupSummaryPopulated,
      group: 'Setup and Summary',
      title: 'Setup and Summary / Populated',
      description:
          'Typical project and task setup flow with mixed all-time totals and zero-total rows.',
    ),
    _PreviewScenarioDefinition(
      id: _PreviewScenarioId.setupSummaryLongNames,
      group: 'Setup and Summary',
      title: 'Setup and Summary / Long Names',
      description:
          'Long project and task names to inspect truncation and two-column balance.',
    ),
  ];

  late _PreviewScenarioId _selectedScenario;
  late _PreviewViewportId _selectedViewport;
  late DateTime _linkedPreviewDay;
  int _scenarioRevision = 0;

  late _PreviewDayStore _dayEmptyStore;
  late _PreviewDayStore _dayPopulatedStore;
  late _PreviewDayStore _dayOverlapStore;
  late _PreviewDayStore _dayLongContentStore;
  late _PreviewDayStore _dayBoundaryStore;
  late _PreviewDayStore _linkedWeekDayStore;
  late _PreviewSetupAndSummaryStore _setupSummaryEmptyStore;
  late _PreviewSetupAndSummaryStore _setupSummaryPopulatedStore;
  late _PreviewSetupAndSummaryStore _setupSummaryLongNamesStore;

  @override
  void initState() {
    super.initState();
    _selectedScenario = _PreviewScenarioId.dayPopulated;
    _selectedViewport = _PreviewViewportId.primaryDesktop;
    _linkedPreviewDay = dateOnly(DateTime(2026, 4, 10));
    _resetScenarioData();
  }

  void _resetScenarioData() {
    _dayEmptyStore = _buildEmptyDayStore();
    _dayPopulatedStore = _buildPopulatedDayStore();
    _dayOverlapStore = _buildOverlapDayStore();
    _dayLongContentStore = _buildLongContentDayStore();
    _dayBoundaryStore = _buildBoundaryDayStore();
    _linkedWeekDayStore = _buildLinkedWeekDayStore();
    _setupSummaryEmptyStore = _buildEmptySetupAndSummaryStore();
    _setupSummaryPopulatedStore = _buildPopulatedSetupAndSummaryStore();
    _setupSummaryLongNamesStore = _buildLongNameSetupAndSummaryStore();
  }

  _PreviewScenarioDefinition get _selectedDefinition {
    return _scenarioDefinitions.firstWhere(
      (definition) => definition.id == _selectedScenario,
    );
  }

  void _selectScenario(_PreviewScenarioId scenario) {
    if (_selectedScenario == scenario) {
      return;
    }

    setState(() => _selectedScenario = scenario);
  }

  void _selectViewport(_PreviewViewportId viewport) {
    if (_selectedViewport == viewport) {
      return;
    }

    setState(() => _selectedViewport = viewport);
  }

  void _resetSelectedScenario() {
    setState(() {
      _scenarioRevision += 1;
      _resetScenarioData();
    });
  }

  void _openLinkedPreviewDay(DateTime day) {
    setState(() {
      _linkedPreviewDay = dateOnly(day);
      _selectedScenario = _PreviewScenarioId.dayWeekDrillIn;
      _scenarioRevision += 1;
      _linkedWeekDayStore = _buildLinkedWeekDayStore();
    });
  }

  Widget _buildScenarioButton(
    BuildContext context,
    _PreviewScenarioDefinition definition,
  ) {
    final isSelected = definition.id == _selectedScenario;
    final theme = FluentTheme.of(context);
    final button = isSelected
        ? FilledButton(
            onPressed: () => _selectScenario(definition.id),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(definition.title),
            ),
          )
        : Button(
            onPressed: () => _selectScenario(definition.id),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(definition.title),
            ),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: double.infinity, child: button),
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Opacity(
              opacity: 0.8,
              child: Text(
                definition.description,
                style: theme.typography.caption,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioList(BuildContext context) {
    final groupedDefinitions = <String, List<_PreviewScenarioDefinition>>{};
    for (final definition in _scenarioDefinitions) {
      groupedDefinitions
          .putIfAbsent(definition.group, () => [])
          .add(definition);
    }

    final theme = FluentTheme.of(context);

    return Card(
      child: SizedBox(
        height: 760,
        child: ListView(
          key: const Key('uiPreviewScenarioList'),
          children: groupedDefinitions.entries
              .expand((entry) {
                final widgets = <Widget>[
                  Text(entry.key, style: theme.typography.subtitle),
                  const SizedBox(height: 12),
                ];

                widgets.addAll(
                  entry.value.map(
                    (definition) => _buildScenarioButton(context, definition),
                  ),
                );
                widgets.add(const SizedBox(height: 8));
                return widgets;
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildViewportSelector(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Viewport', style: theme.typography.subtitle),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _viewportSpecs.entries
                .map((entry) {
                  final isSelected = entry.key == _selectedViewport;
                  final button = isSelected
                      ? FilledButton(
                          onPressed: () => _selectViewport(entry.key),
                          child: Text(entry.value.label),
                        )
                      : Button(
                          onPressed: () => _selectViewport(entry.key),
                          child: Text(entry.value.label),
                        );

                  return button;
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Button(
                onPressed: _resetSelectedScenario,
                child: const Text('Reset Scenario'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Opacity(
                  opacity: 0.8,
                  child: Text(
                    'Run with: flutter run -d windows --dart-define=CLOCKWORK_UI_PREVIEW=true',
                    style: theme.typography.caption,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewViewport(BuildContext context) {
    final theme = FluentTheme.of(context);
    final definition = _selectedDefinition;
    final viewport = _viewportSpecs[_selectedViewport]!;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            definition.title,
            key: const Key('uiPreviewScenarioTitle'),
            style: theme.typography.title,
          ),
          const SizedBox(height: 8),
          Text(definition.description, style: theme.typography.body),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor.withAlpha(
                  theme.brightness == Brightness.dark ? 84 : 205,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.inactiveColor),
              ),
              child: RepaintBoundary(
                key: const Key('uiPreviewViewport'),
                child: ClipRect(
                  child: Container(
                    width: viewport.width,
                    height: viewport.height,
                    color: theme.scaffoldBackgroundColor,
                    child: _buildScenarioViewport(definition.id),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioViewport(_PreviewScenarioId scenario) {
    switch (scenario) {
      case _PreviewScenarioId.dayEmpty:
        return DayPage(
          key: ValueKey('day-empty-$_scenarioRevision'),
          initialDay: _dayEmptyStore.initialDay,
          loadDayPageData: _dayEmptyStore.load,
          saveDayEntry: _dayEmptyStore.save,
          deleteDayEntry: _dayEmptyStore.delete,
          todayProvider: _dayEmptyStore.todayProvider,
        );
      case _PreviewScenarioId.dayPopulated:
        return DayPage(
          key: ValueKey('day-populated-$_scenarioRevision'),
          initialDay: _dayPopulatedStore.initialDay,
          loadDayPageData: _dayPopulatedStore.load,
          saveDayEntry: _dayPopulatedStore.save,
          deleteDayEntry: _dayPopulatedStore.delete,
          todayProvider: _dayPopulatedStore.todayProvider,
        );
      case _PreviewScenarioId.dayOverlap:
        return DayPage(
          key: ValueKey('day-overlap-$_scenarioRevision'),
          initialDay: _dayOverlapStore.initialDay,
          loadDayPageData: _dayOverlapStore.load,
          saveDayEntry: _dayOverlapStore.save,
          deleteDayEntry: _dayOverlapStore.delete,
          todayProvider: _dayOverlapStore.todayProvider,
        );
      case _PreviewScenarioId.dayLongContent:
        return DayPage(
          key: ValueKey('day-long-content-$_scenarioRevision'),
          initialDay: _dayLongContentStore.initialDay,
          loadDayPageData: _dayLongContentStore.load,
          saveDayEntry: _dayLongContentStore.save,
          deleteDayEntry: _dayLongContentStore.delete,
          todayProvider: _dayLongContentStore.todayProvider,
        );
      case _PreviewScenarioId.dayBoundaryEndOfDay:
        return DayPage(
          key: ValueKey('day-boundary-$_scenarioRevision'),
          initialDay: _dayBoundaryStore.initialDay,
          loadDayPageData: _dayBoundaryStore.load,
          saveDayEntry: _dayBoundaryStore.save,
          deleteDayEntry: _dayBoundaryStore.delete,
          todayProvider: _dayBoundaryStore.todayProvider,
        );
      case _PreviewScenarioId.dayWeekDrillIn:
        return DayPage(
          key: ValueKey(
            'day-week-drill-in-${_linkedPreviewDay.toIso8601String()}-$_scenarioRevision',
          ),
          initialDay: _linkedPreviewDay,
          loadDayPageData: _linkedWeekDayStore.load,
          saveDayEntry: _linkedWeekDayStore.save,
          deleteDayEntry: _linkedWeekDayStore.delete,
          todayProvider: _linkedWeekDayStore.todayProvider,
        );
      case _PreviewScenarioId.weekEmpty:
        return WeekPage(
          key: ValueKey('week-empty-$_scenarioRevision'),
          onOpenDay: _openLinkedPreviewDay,
          initialSelectedDate: DateTime(2026, 4, 8),
          loadWeekPageData: (_) async => _cloneMap(_buildEmptyWeekData()),
          todayProvider: () => _previewToday,
        );
      case _PreviewScenarioId.weekMixedBillable:
        return WeekPage(
          key: ValueKey('week-mixed-billable-$_scenarioRevision'),
          onOpenDay: _openLinkedPreviewDay,
          initialSelectedDate: DateTime(2026, 4, 8),
          loadWeekPageData: (_) async =>
              _cloneMap(_buildMixedBillableWeekData()),
          todayProvider: () => _previewToday,
        );
      case _PreviewScenarioId.weekLongLabels:
        return WeekPage(
          key: ValueKey('week-long-labels-$_scenarioRevision'),
          onOpenDay: _openLinkedPreviewDay,
          initialSelectedDate: DateTime(2026, 4, 8),
          loadWeekPageData: (_) async => _cloneMap(_buildLongLabelWeekData()),
          todayProvider: () => _previewToday,
        );
      case _PreviewScenarioId.weekNotesPopup:
        return WeekPage(
          key: ValueKey('week-notes-popup-$_scenarioRevision'),
          onOpenDay: _openLinkedPreviewDay,
          initialSelectedDate: DateTime(2026, 4, 8),
          loadWeekPageData: (_) async => _cloneMap(_buildNotesPopupWeekData()),
          todayProvider: () => _previewToday,
          initialNotesDialogRequest: const WeekPageNotesDialogRequest(
            rowIndex: 0,
            dayIndex: 2,
          ),
        );
      case _PreviewScenarioId.weekWeekdayLinks:
        return WeekPage(
          key: ValueKey('week-weekday-links-$_scenarioRevision'),
          onOpenDay: _openLinkedPreviewDay,
          initialSelectedDate: DateTime(2026, 4, 8),
          loadWeekPageData: (_) async => _cloneMap(_buildWeekdayLinkWeekData()),
          todayProvider: () => _previewToday,
        );
      case _PreviewScenarioId.setupSummaryEmpty:
        return SetupAndSummaryPage(
          key: ValueKey('setup-summary-empty-$_scenarioRevision'),
          loadPageData: _setupSummaryEmptyStore.load,
          saveProject: _setupSummaryEmptyStore.saveProject,
          saveTask: _setupSummaryEmptyStore.saveTask,
          deleteEntity: _setupSummaryEmptyStore.delete,
        );
      case _PreviewScenarioId.setupSummaryPopulated:
        return SetupAndSummaryPage(
          key: ValueKey('setup-summary-populated-$_scenarioRevision'),
          loadPageData: _setupSummaryPopulatedStore.load,
          saveProject: _setupSummaryPopulatedStore.saveProject,
          saveTask: _setupSummaryPopulatedStore.saveTask,
          deleteEntity: _setupSummaryPopulatedStore.delete,
        );
      case _PreviewScenarioId.setupSummaryLongNames:
        return SetupAndSummaryPage(
          key: ValueKey('setup-summary-long-names-$_scenarioRevision'),
          loadPageData: _setupSummaryLongNamesStore.load,
          saveProject: _setupSummaryLongNamesStore.saveProject,
          saveTask: _setupSummaryLongNamesStore.saveTask,
          deleteEntity: _setupSummaryLongNamesStore.delete,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('UI Preview')),
      children: [
        Card(
          child: Text(
            'Use these deterministic scenarios to review layout before doing a live-data smoke pass. '
            'The preview pane never writes to the production database.',
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1320;

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 320, child: _buildScenarioList(context)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildViewportSelector(context),
                        const SizedBox(height: 16),
                        _buildPreviewViewport(context),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildViewportSelector(context),
                const SizedBox(height: 16),
                _buildScenarioList(context),
                const SizedBox(height: 16),
                _buildPreviewViewport(context),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PreviewDayStore {
  _PreviewDayStore({
    required this.initialDay,
    required this.today,
    required List<Map<String, dynamic>> projects,
    required List<Map<String, dynamic>> tasks,
    required Map<DateTime, List<Map<String, dynamic>>> entriesByDay,
  }) : _projects = _cloneMapList(projects),
       _tasks = _cloneMapList(tasks),
       _entriesByDay = entriesByDay.map(
         (date, entries) => MapEntry(dateOnly(date), _cloneMapList(entries)),
       ),
       _nextEntryId = _nextId(entriesByDay);

  final DateTime initialDay;
  final DateTime today;
  final List<Map<String, dynamic>> _projects;
  final List<Map<String, dynamic>> _tasks;
  final Map<DateTime, List<Map<String, dynamic>>> _entriesByDay;
  int _nextEntryId;

  DateTime todayProvider() => today;

  Future<Map<String, dynamic>> load(DateTime date) async {
    final selectedDay = dateOnly(date);
    return {
      'projects': _cloneMapList(_projects),
      'tasks': _cloneMapList(_tasks),
      'entries': _cloneMapList(_entriesByDay[selectedDay] ?? const []),
      'note_suggestions': _buildNoteSuggestions(),
    };
  }

  Future<void> save(DayPageSaveRequest request) async {
    final selectedDay = dateOnly(request.date);
    final entries = _entriesByDay.putIfAbsent(selectedDay, () => []);
    final entryIndex = entries.indexWhere(
      (entry) => entry['id'] == request.entryId && request.entryId != null,
    );
    final nextEntry = <String, dynamic>{
      'id': request.entryId ?? _nextEntryId++,
      'project_id': request.projectId,
      'task_id': request.taskId,
      'billable_value': request.billableValue,
      'start_minutes': request.startMinutes,
      'end_minutes': request.endMinutes,
      'note': request.note,
      'show_time_warnings': false,
    };

    if (entryIndex >= 0) {
      entries[entryIndex] = nextEntry;
    } else {
      entries.add(nextEntry);
    }

    entries.sort((left, right) {
      final leftStart = left['start_minutes'] as int? ?? 0;
      final rightStart = right['start_minutes'] as int? ?? 0;
      final startComparison = leftStart.compareTo(rightStart);
      if (startComparison != 0) {
        return startComparison;
      }

      final leftId = left['id'] as int? ?? 0;
      final rightId = right['id'] as int? ?? 0;
      return leftId.compareTo(rightId);
    });
  }

  Future<void> delete(int entryId) async {
    for (final entries in _entriesByDay.values) {
      entries.removeWhere((entry) => entry['id'] == entryId);
    }
  }

  Map<String, List<String>> _buildNoteSuggestions() {
    final allEntries = <Map<String, dynamic>>[];
    for (final dayEntries in _entriesByDay.entries) {
      final dateValue = dayEntries.key.millisecondsSinceEpoch;
      for (final entry in dayEntries.value) {
        allEntries.add(<String, dynamic>{
          ...Map<String, dynamic>.from(entry),
          'date': dateValue,
        });
      }
    }

    allEntries.sort((left, right) {
      final leftDate = left['date'] as int? ?? 0;
      final rightDate = right['date'] as int? ?? 0;
      final dateComparison = rightDate.compareTo(leftDate);
      if (dateComparison != 0) {
        return dateComparison;
      }

      final leftStart = left['start_minutes'] as int? ?? 0;
      final rightStart = right['start_minutes'] as int? ?? 0;
      final startComparison = rightStart.compareTo(leftStart);
      if (startComparison != 0) {
        return startComparison;
      }

      final leftId = left['id'] as int? ?? 0;
      final rightId = right['id'] as int? ?? 0;
      return rightId.compareTo(leftId);
    });

    final suggestionsByKey = <String, List<String>>{};
    final seenNotesByKey = <String, Set<String>>{};

    for (final entry in allEntries) {
      final projectId = entry['project_id'] as int?;
      final taskId = entry['task_id'] as int?;
      final note = (entry['note'] as String? ?? '').trim();
      if (projectId == null || taskId == null || note.isEmpty) {
        continue;
      }

      final key = '$projectId:$taskId';
      final seenNotes = seenNotesByKey.putIfAbsent(key, () => <String>{});
      if (!seenNotes.add(note)) {
        continue;
      }

      suggestionsByKey.putIfAbsent(key, () => <String>[]).add(note);
    }

    return suggestionsByKey;
  }

  static int _nextId(Map<DateTime, List<Map<String, dynamic>>> entriesByDay) {
    var highestId = 0;
    for (final entries in entriesByDay.values) {
      for (final entry in entries) {
        final entryId = entry['id'] as int? ?? 0;
        if (entryId > highestId) {
          highestId = entryId;
        }
      }
    }

    return highestId + 1;
  }
}

_PreviewDayStore _buildEmptyDayStore() {
  final day = dateOnly(DateTime(2026, 4, 6));
  return _PreviewDayStore(
    initialDay: day,
    today: _UiPreviewPageState._previewToday,
    projects: _basePreviewProjects(),
    tasks: _basePreviewTasks(),
    entriesByDay: {day: const []},
  );
}

_PreviewDayStore _buildPopulatedDayStore() {
  final day = dateOnly(DateTime(2026, 4, 8));
  return _PreviewDayStore(
    initialDay: day,
    today: _UiPreviewPageState._previewToday,
    projects: _basePreviewProjects(),
    tasks: _basePreviewTasks(),
    entriesByDay: {
      day: [
        {
          'id': 101,
          'project_id': 1,
          'task_id': 11,
          'billable_value': 1,
          'start_minutes': 9 * 60,
          'end_minutes': 10 * 60 + 15,
          'note': 'UAT integration error investigation',
        },
        {
          'id': 102,
          'project_id': 2,
          'task_id': 21,
          'billable_value': 0,
          'start_minutes': 10 * 60 + 30,
          'end_minutes': 11 * 60 + 15,
          'note': 'Unverified returns',
        },
        {
          'id': 103,
          'project_id': 1,
          'task_id': 12,
          'billable_value': 1,
          'start_minutes': 13 * 60 + 45,
          'end_minutes': 17 * 60,
          'note': 'UAT error proofing',
        },
      ],
    },
  );
}

_PreviewDayStore _buildOverlapDayStore() {
  final day = dateOnly(DateTime(2026, 4, 9));
  return _PreviewDayStore(
    initialDay: day,
    today: _UiPreviewPageState._previewToday,
    projects: _basePreviewProjects(),
    tasks: _basePreviewTasks(),
    entriesByDay: {
      day: [
        {
          'id': 201,
          'project_id': 1,
          'task_id': 11,
          'billable_value': 1,
          'start_minutes': 9 * 60,
          'end_minutes': 10 * 60,
          'note': 'Client workshop',
          'show_time_warnings': true,
        },
        {
          'id': 202,
          'project_id': 1,
          'task_id': 12,
          'billable_value': 1,
          'start_minutes': 9 * 60 + 30,
          'end_minutes': 10 * 60 + 15,
          'note': 'Regression pass',
          'show_time_warnings': true,
        },
      ],
    },
  );
}

_PreviewDayStore _buildLongContentDayStore() {
  final day = dateOnly(DateTime(2026, 4, 7));
  return _PreviewDayStore(
    initialDay: day,
    today: _UiPreviewPageState._previewToday,
    projects: [
      {'id': 31, 'name': 'Northern Territory Migration and Compliance Program'},
      {'id': 32, 'name': 'Strategic Internal Platform Improvements Initiative'},
    ],
    tasks: [
      {
        'id': 311,
        'project_id': 31,
        'name': 'Cross-team stakeholder alignment and defect triage',
      },
      {
        'id': 321,
        'project_id': 32,
        'name': 'Quarterly workflow resilience and release readiness review',
      },
    ],
    entriesByDay: {
      day: [
        {
          'id': 301,
          'project_id': 31,
          'task_id': 311,
          'billable_value': 1,
          'start_minutes': 8 * 60 + 45,
          'end_minutes': 10 * 60 + 15,
          'note':
              'Validated edge-case handling for integration retries across the multi-step approval workflow.',
        },
        {
          'id': 302,
          'project_id': 32,
          'task_id': 321,
          'billable_value': 0,
          'start_minutes': 11 * 60,
          'end_minutes': 12 * 60 + 15,
          'note':
              'Captured follow-up notes for release readiness, stakeholder communication, and internal training updates.',
        },
      ],
    },
  );
}

_PreviewDayStore _buildBoundaryDayStore() {
  final day = dateOnly(DateTime(2026, 4, 10));
  return _PreviewDayStore(
    initialDay: day,
    today: _UiPreviewPageState._previewToday,
    projects: _basePreviewProjects(),
    tasks: _basePreviewTasks(),
    entriesByDay: {
      day: [
        {
          'id': 401,
          'project_id': 3,
          'task_id': 31,
          'billable_value': 0,
          'start_minutes': 22 * 60,
          'end_minutes': 23 * 60,
          'note': 'Release preparation',
        },
        {
          'id': 402,
          'project_id': 3,
          'task_id': 32,
          'billable_value': 0,
          'start_minutes': 23 * 60,
          'end_minutes': 24 * 60,
          'note': 'Midnight deployment handoff',
        },
      ],
    },
  );
}

_PreviewDayStore _buildLinkedWeekDayStore() {
  return _PreviewDayStore(
    initialDay: dateOnly(DateTime(2026, 4, 10)),
    today: _UiPreviewPageState._previewToday,
    projects: _basePreviewProjects(),
    tasks: _basePreviewTasks(),
    entriesByDay: {
      dateOnly(DateTime(2026, 4, 6)): [
        {
          'id': 501,
          'project_id': 1,
          'task_id': 11,
          'billable_value': 1,
          'start_minutes': 9 * 60,
          'end_minutes': 10 * 60,
          'note': 'Monday discovery session',
        },
      ],
      dateOnly(DateTime(2026, 4, 8)): [
        {
          'id': 502,
          'project_id': 1,
          'task_id': 11,
          'billable_value': 1,
          'start_minutes': 10 * 60,
          'end_minutes': 11 * 60,
          'note': 'Mid-week workshop',
        },
        {
          'id': 503,
          'project_id': 1,
          'task_id': 12,
          'billable_value': 1,
          'start_minutes': 11 * 60 + 15,
          'end_minutes': 12 * 60,
          'note': 'Post-workshop follow up',
        },
      ],
      dateOnly(DateTime(2026, 4, 10)): [
        {
          'id': 504,
          'project_id': 2,
          'task_id': 21,
          'billable_value': 0,
          'start_minutes': 14 * 60,
          'end_minutes': 15 * 60,
          'note': 'Friday returns review',
        },
      ],
    },
  );
}

class _PreviewSetupAndSummaryStore {
  _PreviewSetupAndSummaryStore({
    required List<Map<String, dynamic>> projects,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> timeEntries,
    Map<String, dynamic>? billabilitySummary,
  }) : _projects = _cloneMapList(projects),
       _tasks = _cloneMapList(tasks),
       _timeEntries = _cloneMapList(timeEntries),
       _billabilitySummary = _clonePreviewBillabilitySummary(
         billabilitySummary ?? _emptyPreviewBillabilitySummary(),
       ),
       _nextProjectId = _nextEntityId(projects),
       _nextTaskId = _nextEntityId(tasks);

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

    final project = _projects.singleWhere(
      (candidate) => candidate['id'] == request.projectId,
      orElse: () =>
          throw Exception('Project ${request.projectId} was not found.'),
    );
    project['name'] = normalizedName;
    return request.projectId!;
  }

  Future<int> saveTask(SetupAndSummaryTaskSaveRequest request) async {
    final normalizedName = request.name.trim();
    if (normalizedName.isEmpty) {
      throw Exception('Task name is required.');
    }

    _projects.singleWhere(
      (project) => project['id'] == request.projectId,
      orElse: () =>
          throw Exception('Project ${request.projectId} was not found.'),
    );

    if (request.taskId == null) {
      final taskId = _nextTaskId++;
      _tasks.add({
        'id': taskId,
        'project_id': request.projectId,
        'name': normalizedName,
      });
      return taskId;
    }

    final task = _tasks.singleWhere(
      (candidate) => candidate['id'] == request.taskId,
      orElse: () => throw Exception('Task ${request.taskId} was not found.'),
    );
    task['name'] = normalizedName;
    task['project_id'] = request.projectId;
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
      final hasEntries = _timeEntries.any(
        (entry) => entry['task_id'] == entityId,
      );
      if (hasEntries) {
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
    final projects = _cloneMapList(_projects)
      ..sort(
        (left, right) =>
            (left['name'] as String).compareTo(right['name'] as String),
      );
    final projectNameById = <int, String>{
      for (final project in projects)
        project['id'] as int: project['name'] as String,
    };
    final tasks = _cloneMapList(_tasks)
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
    final decoratedTasks = tasks
        .map(
          (task) => {
            ...task,
            'project_name': projectNameById[task['project_id'] as int?],
          },
        )
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
    for (final project in projects) {
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
      'projects': projects,
      'tasks': decoratedTasks,
      'summary_rows': summaryRows,
      'billability_summary': _clonePreviewBillabilitySummary(
        _billabilitySummary,
      ),
    };
  }

  static int _nextEntityId(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return 1;
    }

    return rows
            .map((row) => row['id'] as int? ?? 0)
            .reduce((current, next) => current > next ? current : next) +
        1;
  }
}

_PreviewSetupAndSummaryStore _buildEmptySetupAndSummaryStore() {
  return _PreviewSetupAndSummaryStore(
    projects: const [],
    tasks: const [],
    timeEntries: const [],
    billabilitySummary: _emptyPreviewBillabilitySummary(),
  );
}

_PreviewSetupAndSummaryStore _buildPopulatedSetupAndSummaryStore() {
  return _PreviewSetupAndSummaryStore(
    projects: const [
      {'id': 1, 'name': 'Adore'},
      {'id': 2, 'name': 'Koorong'},
      {'id': 3, 'name': 'Internal'},
    ],
    tasks: const [
      {'id': 11, 'project_id': 1, 'name': 'UAT Support'},
      {'id': 12, 'project_id': 1, 'name': 'Error Proofing'},
      {'id': 21, 'project_id': 2, 'name': 'Returns'},
      {'id': 31, 'project_id': 3, 'name': 'Release Prep'},
    ],
    timeEntries: const [
      {'task_id': 11, 'duration_minutes': 255},
      {'task_id': 12, 'duration_minutes': 45},
      {'task_id': 21, 'duration_minutes': 105},
    ],
    billabilitySummary: const {
      'month_labels': ['Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr'],
      'rows': [
        {
          'key': 'billable_hours',
          'label': 'Billable Hours',
          'display': 'hours',
          'monthly_values': [0.0, 1.50, 2.00, 0.75, 1.00, 4.25],
          'average_value': 1.58,
        },
        {
          'key': 'non_billable_hours',
          'label': 'Non Billable Hours',
          'display': 'hours',
          'monthly_values': [0.0, 0.50, 0.25, 1.25, 0.75, 1.75],
          'average_value': 0.75,
        },
        {
          'key': 'total_hours_worked',
          'label': 'Total Hours Worked',
          'display': 'hours',
          'monthly_values': [0.0, 2.00, 2.25, 2.00, 1.75, 6.00],
          'average_value': 2.33,
        },
        {
          'key': 'billability_percentage',
          'label': 'Billability %',
          'display': 'percentage',
          'monthly_values': [0.0, 75.0, 88.9, 37.5, 57.1, 70.8],
          'average_value': 67.9,
        },
      ],
    },
  );
}

_PreviewSetupAndSummaryStore _buildLongNameSetupAndSummaryStore() {
  return _PreviewSetupAndSummaryStore(
    projects: const [
      {'id': 41, 'name': 'Northern Territory Migration and Compliance Program'},
      {'id': 42, 'name': 'Strategic Internal Platform Improvements Initiative'},
    ],
    tasks: const [
      {
        'id': 411,
        'project_id': 41,
        'name': 'Cross-team stakeholder alignment and defect triage',
      },
      {
        'id': 421,
        'project_id': 42,
        'name': 'Quarterly workflow resilience and release readiness review',
      },
      {
        'id': 422,
        'project_id': 42,
        'name': 'Release communications and readiness checkpoint',
      },
    ],
    timeEntries: const [
      {'task_id': 411, 'duration_minutes': 195},
      {'task_id': 421, 'duration_minutes': 135},
      {'task_id': 422, 'duration_minutes': 0},
    ],
    billabilitySummary: const {
      'month_labels': ['Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr'],
      'rows': [
        {
          'key': 'billable_hours',
          'label': 'Billable Hours',
          'display': 'hours',
          'monthly_values': [1.25, 0.75, 2.50, 1.50, 0.50, 2.25],
          'average_value': 1.46,
        },
        {
          'key': 'non_billable_hours',
          'label': 'Non Billable Hours',
          'display': 'hours',
          'monthly_values': [0.25, 1.00, 0.75, 1.25, 0.50, 1.00],
          'average_value': 0.79,
        },
        {
          'key': 'total_hours_worked',
          'label': 'Total Hours Worked',
          'display': 'hours',
          'monthly_values': [1.50, 1.75, 3.25, 2.75, 1.00, 3.25],
          'average_value': 2.25,
        },
        {
          'key': 'billability_percentage',
          'label': 'Billability %',
          'display': 'percentage',
          'monthly_values': [83.3, 42.9, 76.9, 54.5, 50.0, 69.2],
          'average_value': 64.8,
        },
      ],
    },
  );
}

List<Map<String, dynamic>> _basePreviewProjects() {
  return const [
    {'id': 1, 'name': 'Adore'},
    {'id': 2, 'name': 'Koorong'},
    {'id': 3, 'name': 'Internal'},
  ];
}

Map<String, dynamic> _emptyPreviewBillabilitySummary() {
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

Map<String, dynamic> _clonePreviewBillabilitySummary(
  Map<String, dynamic> value,
) {
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

List<Map<String, dynamic>> _basePreviewTasks() {
  return const [
    {'id': 11, 'project_id': 1, 'name': 'UAT Support'},
    {'id': 12, 'project_id': 1, 'name': 'Error Proofing'},
    {'id': 21, 'project_id': 2, 'name': 'Returns'},
    {'id': 31, 'project_id': 3, 'name': 'Release Prep'},
    {'id': 32, 'project_id': 3, 'name': 'Deployment Handoff'},
  ];
}

Map<String, dynamic> _buildEmptyWeekData() {
  return {
    'projects': _basePreviewProjects(),
    'rows': const <Map<String, dynamic>>[],
    'week_total_minutes': 0,
  };
}

Map<String, dynamic> _buildMixedBillableWeekData() {
  return {
    'projects': _basePreviewProjects(),
    'rows': [
      {
        'project_id': 1,
        'project_name': 'Adore',
        'task_id': 11,
        'task_name': 'UAT Support',
        'billable_value': 1,
        'day_minutes': [0, 75, 0, 180, 0, 0, 0],
        'day_note_lines': [
          <String>[],
          ['Client workshop'],
          <String>[],
          ['Regression pass'],
          <String>[],
          <String>[],
          <String>[],
        ],
        'total_minutes': 255,
      },
      {
        'project_id': 1,
        'project_name': 'Adore',
        'task_id': 11,
        'task_name': 'UAT Support',
        'billable_value': 0,
        'day_minutes': [0, 30, 0, 0, 0, 0, 0],
        'day_note_lines': [
          <String>[],
          ['Internal review'],
          <String>[],
          <String>[],
          <String>[],
          <String>[],
          <String>[],
        ],
        'total_minutes': 30,
      },
      {
        'project_id': 2,
        'project_name': 'Koorong',
        'task_id': 21,
        'task_name': 'Returns',
        'billable_value': 0,
        'day_minutes': [0, 0, 45, 0, 60, 0, 0],
        'day_note_lines': [
          <String>[],
          <String>[],
          ['Returns review'],
          <String>[],
          ['Friday validation'],
          <String>[],
          <String>[],
        ],
        'total_minutes': 105,
      },
    ],
    'week_total_minutes': 390,
  };
}

Map<String, dynamic> _buildLongLabelWeekData() {
  return {
    'projects': const [
      {'id': 41, 'name': 'Northern Territory Migration and Compliance Program'},
    ],
    'rows': [
      {
        'project_id': 41,
        'project_name': 'Northern Territory Migration and Compliance Program',
        'task_id': 411,
        'task_name': 'Cross-team stakeholder alignment and defect triage',
        'billable_value': 1,
        'day_minutes': [90, 45, 0, 120, 60, 0, 0],
        'day_note_lines': [
          ['Discovery workshop'],
          ['Defect review'],
          <String>[],
          ['Follow-up investigation'],
          ['Reporting'],
          <String>[],
          <String>[],
        ],
        'total_minutes': 315,
      },
    ],
    'week_total_minutes': 315,
  };
}

Map<String, dynamic> _buildNotesPopupWeekData() {
  return {
    'projects': _basePreviewProjects(),
    'rows': [
      {
        'project_id': 1,
        'project_name': 'Adore',
        'task_id': 11,
        'task_name': 'UAT Support',
        'billable_value': 1,
        'day_minutes': [0, 0, 75, 0, 0, 0, 0],
        'day_note_lines': [
          <String>[],
          <String>[],
          ['Discovery session', 'Follow up'],
          <String>[],
          <String>[],
          <String>[],
          <String>[],
        ],
        'total_minutes': 75,
      },
    ],
    'week_total_minutes': 75,
  };
}

Map<String, dynamic> _buildWeekdayLinkWeekData() {
  return {
    'projects': _basePreviewProjects(),
    'rows': [
      {
        'project_id': 1,
        'project_name': 'Adore',
        'task_id': 11,
        'task_name': 'UAT Support',
        'billable_value': 1,
        'day_minutes': [60, 0, 90, 0, 45, 0, 0],
        'day_note_lines': [
          ['Monday discovery session'],
          <String>[],
          ['Mid-week workshop'],
          <String>[],
          ['Friday handoff'],
          <String>[],
          <String>[],
        ],
        'total_minutes': 195,
      },
    ],
    'week_total_minutes': 195,
  };
}

Map<String, dynamic> _cloneMap(Map<String, dynamic> value) {
  return Map<String, dynamic>.fromEntries(
    value.entries.map(
      (entry) => MapEntry(entry.key, _deepCloneValue(entry.value)),
    ),
  );
}

List<Map<String, dynamic>> _cloneMapList(List<Map<String, dynamic>> value) {
  return value.map(_cloneMap).toList(growable: false);
}

dynamic _deepCloneValue(dynamic value) {
  if (value is Map<String, dynamic>) {
    return _cloneMap(value);
  }

  if (value is List) {
    return value.map(_deepCloneValue).toList(growable: false);
  }

  return value;
}
