import 'dart:async';

import 'package:flutter/services.dart';
import 'package:fluent_ui/fluent_ui.dart';

import 'app_db.dart';
import 'day_entry_validation.dart';
import 'editor_helpers.dart';
import 'time_entry_formatting.dart';

typedef DayPageDataLoader =
    Future<Map<String, dynamic>> Function(DateTime date);
typedef DayPageSaveHandler = Future<void> Function(DayPageSaveRequest request);
typedef DayPageDeleteHandler = Future<void> Function(int entryId);
typedef DayPageTodayProvider = DateTime Function();

class DayPageSaveRequest {
  const DayPageSaveRequest({
    required this.date,
    required this.projectId,
    required this.taskId,
    required this.billableValue,
    required this.startMinutes,
    required this.endMinutes,
    required this.note,
    this.entryId,
  });

  final DateTime date;
  final int projectId;
  final int taskId;
  final int billableValue;
  final int startMinutes;
  final int endMinutes;
  final String note;
  final int? entryId;
}

class DayPage extends StatefulWidget {
  const DayPage({
    required this.initialDay,
    this.loadDayPageData,
    this.saveDayEntry,
    this.deleteDayEntry,
    this.todayProvider,
    super.key,
  });

  final DateTime initialDay;
  final DayPageDataLoader? loadDayPageData;
  final DayPageSaveHandler? saveDayEntry;
  final DayPageDeleteHandler? deleteDayEntry;
  final DayPageTodayProvider? todayProvider;

  @override
  State<DayPage> createState() => _DayPageState();
}

class _DayPageState extends State<DayPage> {
  static const double _projectColumnWidth = 220;
  static const double _taskColumnWidth = 240;
  static const double _billableColumnWidth = 40;
  static const double _billableHeaderInset = 8;
  static const double _taskToBillableGap = 6;
  static const double _billableToStartGap = 8;
  static const double _timeColumnWidth = 102;
  static const double _durationColumnWidth = 80;
  static const double _noteColumnWidth = 320;
  static const double _saveColumnWidth = 76;
  static const double _standardColumnGap = 12;
  static const double _tightColumnGap = 4;
  static const double _actionButtonSize = 32;
  static const double _entryTableWidth =
      _projectColumnWidth +
      _standardColumnGap +
      _taskColumnWidth +
      _taskToBillableGap +
      _billableColumnWidth +
      _billableToStartGap +
      _timeColumnWidth +
      _tightColumnGap +
      _timeColumnWidth +
      _tightColumnGap +
      _durationColumnWidth +
      _standardColumnGap +
      _noteColumnWidth +
      _standardColumnGap +
      _saveColumnWidth;
  static const Map<int, TableColumnWidth> _entryTableColumnWidths =
      <int, TableColumnWidth>{
        0: FixedColumnWidth(_projectColumnWidth),
        1: FixedColumnWidth(_standardColumnGap),
        2: FixedColumnWidth(_taskColumnWidth),
        3: FixedColumnWidth(_taskToBillableGap),
        4: FixedColumnWidth(_billableColumnWidth),
        5: FixedColumnWidth(_billableToStartGap),
        6: FixedColumnWidth(_timeColumnWidth),
        7: FixedColumnWidth(_tightColumnGap),
        8: FixedColumnWidth(_timeColumnWidth),
        9: FixedColumnWidth(_tightColumnGap),
        10: FixedColumnWidth(_durationColumnWidth),
        11: FixedColumnWidth(_standardColumnGap),
        12: FixedColumnWidth(_noteColumnWidth),
        13: FixedColumnWidth(_standardColumnGap),
        14: FixedColumnWidth(_saveColumnWidth),
      };

  late DateTime _selectedDay;
  List<Map<String, dynamic>> _projects = const [];
  List<Map<String, dynamic>> _tasks = const [];
  List<_DayEntryDraft> _rows = const [];
  Map<String, List<String>> _noteSuggestions = const {};
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _selectedDay = dateOnly(widget.initialDay);
    _loadDay();
  }

  @override
  void didUpdateWidget(covariant DayPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextDay = dateOnly(widget.initialDay);
    if (_selectedDay == nextDay) {
      return;
    }

    _selectedDay = nextDay;
    _loadDay();
  }

  @override
  void dispose() {
    _disposeRows();
    super.dispose();
  }

  Future<void> _loadDay() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final loadDayPageData = widget.loadDayPageData ?? dbHelper.getDayPageData;
      final dayData = await loadDayPageData(_selectedDay);
      final projects = List<Map<String, dynamic>>.from(
        dayData['projects'] as List<dynamic>? ?? const [],
      );
      final tasks = List<Map<String, dynamic>>.from(
        dayData['tasks'] as List<dynamic>? ?? const [],
      );
      final entries = List<Map<String, dynamic>>.from(
        dayData['entries'] as List<dynamic>? ?? const [],
      );
      final noteSuggestions = _normalizeNoteSuggestions(
        dayData['note_suggestions'],
      );
      final nextRows = _buildRows(entries);

      if (!mounted) {
        _disposeRows(nextRows);
        return;
      }

      _disposeRows();
      setState(() {
        _projects = projects;
        _tasks = tasks;
        _rows = nextRows;
        _noteSuggestions = noteSuggestions;
      });
      _focusNewRowProjectField(nextRows, projects);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _disposeRows();
      setState(() {
        _projects = const [];
        _tasks = const [];
        _rows = const [];
        _noteSuggestions = const {};
        _loadError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<_DayEntryDraft> _buildRows(List<Map<String, dynamic>> entries) {
    final rows = entries
        .map(
          (entry) => _DayEntryDraft(
            entryId: entry['id'] as int?,
            projectId: entry['project_id'] as int?,
            projectName: entry['project_name'] as String? ?? '',
            taskId: entry['task_id'] as int?,
            taskName: entry['task_name'] as String? ?? '',
            billableValue: entry['billable_value'] as int? ?? 0,
            startMinutes: entry['start_minutes'] as int?,
            endMinutes: entry['end_minutes'] as int?,
            note: entry['note'] as String? ?? '',
            showTimeWarnings: entry['show_time_warnings'] as bool? ?? false,
          ),
        )
        .toList();

    rows.add(_DayEntryDraft.empty());
    return rows;
  }

  void _disposeRows([List<_DayEntryDraft>? rows]) {
    for (final row in rows ?? _rows) {
      row.dispose();
    }
  }

  Future<void> _jumpToToday() async {
    final today = dateOnly((widget.todayProvider ?? DateTime.now).call());
    if (_selectedDay == today) {
      await _loadDay();
      return;
    }

    setState(() => _selectedDay = today);
    await _loadDay();
  }

  Future<void> _shiftSelectedDay(int dayOffset) async {
    if (dayOffset == 0) {
      return;
    }

    setState(
      () =>
          _selectedDay = dateOnly(_selectedDay.add(Duration(days: dayOffset))),
    );
    await _loadDay();
  }

  Future<void> _handleDayChanged(DateTime value) async {
    final nextDay = dateOnly(value);
    if (_selectedDay == nextDay) {
      return;
    }

    setState(() => _selectedDay = nextDay);
    await _loadDay();
  }

  List<Map<String, dynamic>> _tasksForProject(int? projectId) {
    if (projectId == null) {
      return const [];
    }

    return _tasks.where((task) => task['project_id'] == projectId).toList();
  }

  Map<String, List<String>> _normalizeNoteSuggestions(dynamic rawSuggestions) {
    if (rawSuggestions is! Map) {
      return const {};
    }

    final normalized = <String, List<String>>{};
    rawSuggestions.forEach((key, value) {
      if (value is List) {
        normalized[key.toString()] = value
            .map((note) => note?.toString() ?? '')
            .where((note) => note.trim().isNotEmpty)
            .toList(growable: false);
      }
    });

    return normalized;
  }

  String _noteSuggestionKey(int? projectId, int? taskId) {
    if (projectId == null || taskId == null) {
      return '';
    }

    return '$projectId:$taskId';
  }

  List<String> _noteSuggestionsForRow(_DayEntryDraft row) {
    return _noteSuggestions[_noteSuggestionKey(row.projectId, row.taskId)] ??
        const [];
  }

  Map<String, dynamic>? _firstTaskPrefixMatch(int? projectId, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty || projectId == null) {
      return null;
    }

    for (final task in _tasksForProject(projectId)) {
      final taskName = (task['name'] as String? ?? '').toLowerCase();
      if (taskName.startsWith(normalizedQuery)) {
        return task;
      }
    }

    return null;
  }

  Map<String, dynamic>? _firstProjectPrefixMatch(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return null;
    }

    for (final project in _projects) {
      final projectName = (project['name'] as String? ?? '').toLowerCase();
      if (projectName.startsWith(normalizedQuery)) {
        return project;
      }
    }

    return null;
  }

  List<AutoSuggestBoxItem<int?>> _projectItems() {
    return _projects
        .map(
          (project) => AutoSuggestBoxItem<int?>(
            value: project['id'] as int,
            label: project['name'] as String,
          ),
        )
        .toList(growable: false);
  }

  List<AutoSuggestBoxItem<int?>> _taskItemsForProject(int? projectId) {
    return _tasksForProject(projectId)
        .map(
          (task) => AutoSuggestBoxItem<int?>(
            value: task['id'] as int,
            label: task['name'] as String,
          ),
        )
        .toList(growable: false);
  }

  List<AutoSuggestBoxItem<String>> _noteItemsForRow(_DayEntryDraft row) {
    return _noteSuggestionsForRow(row)
        .map((note) => AutoSuggestBoxItem<String>(value: note, label: note))
        .toList(growable: false);
  }

  List<AutoSuggestBoxItem<T>> _prefixSorter<T>(
    String text,
    List<AutoSuggestBoxItem<T>> items,
  ) {
    final normalizedText = text.trim().toLowerCase();
    if (normalizedText.isEmpty) {
      return items;
    }

    return items
        .where((item) {
          return item.label.toLowerCase().startsWith(normalizedText);
        })
        .toList(growable: false);
  }

  List<AutoSuggestBoxItem<T>> _substringSorter<T>(
    String text,
    List<AutoSuggestBoxItem<T>> items,
  ) {
    final normalizedText = text.trim().toLowerCase();
    if (normalizedText.isEmpty) {
      return items;
    }

    return items
        .where((item) {
          return item.label.toLowerCase().contains(normalizedText);
        })
        .toList(growable: false);
  }

  void _setTaskControllerValue(
    _DayEntryDraft row,
    String text, {
    TextSelection? selection,
  }) {
    row.isApplyingTaskSuggestion = true;
    row.taskController.value = TextEditingValue(
      text: text,
      selection: selection ?? TextSelection.collapsed(offset: text.length),
    );
    row.isApplyingTaskSuggestion = false;
  }

  void _setNoteControllerValue(
    _DayEntryDraft row,
    String text, {
    TextSelection? selection,
  }) {
    row.isApplyingNoteSuggestion = true;
    row.noteController.value = TextEditingValue(
      text: text,
      selection: selection ?? TextSelection.collapsed(offset: text.length),
    );
    row.isApplyingNoteSuggestion = false;
  }

  void _focusNewRowProjectField(
    List<_DayEntryDraft> rows,
    List<Map<String, dynamic>> projects,
  ) {
    if (rows.isEmpty || projects.isEmpty) {
      return;
    }

    final newRow = rows.last;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      newRow.projectFocusNode.requestFocus();
    });
  }

  void _applyProjectSelection(_DayEntryDraft row, int? projectId) {
    final availableTasks = _tasksForProject(projectId);
    final hasCurrentTask = availableTasks.any(
      (task) => task['id'] == row.taskId,
    );
    final nextTask = hasCurrentTask
        ? availableTasks.firstWhere((task) => task['id'] == row.taskId)
        : availableTasks.isEmpty
        ? null
        : availableTasks.first;
    final nextTaskId = nextTask?['id'] as int?;
    final nextTaskName = nextTask?['name'] as String? ?? '';
    final selectSuggestedTask = nextTaskId != null && nextTaskId != row.taskId;

    setState(() {
      row.projectId = projectId;
      row.taskId = nextTaskId;
    });
    _setTaskControllerValue(
      row,
      nextTaskName,
      selection: selectSuggestedTask && nextTaskName.isNotEmpty
          ? TextSelection(baseOffset: 0, extentOffset: nextTaskName.length)
          : TextSelection.collapsed(offset: nextTaskName.length),
    );
  }

  void _handleProjectSuggestionChanged(
    _DayEntryDraft row,
    String text,
    TextChangedReason reason,
  ) {
    if (row.isApplyingProjectSuggestion ||
        reason != TextChangedReason.userInput) {
      return;
    }

    final normalizedQuery = text.trim();
    if (normalizedQuery.isEmpty) {
      _applyProjectSelection(row, null);
      return;
    }

    final matchingProject = _firstProjectPrefixMatch(normalizedQuery);
    if (matchingProject == null) {
      _applyProjectSelection(row, null);
      return;
    }

    final projectId = matchingProject['id'] as int;
    final projectName = matchingProject['name'] as String;
    _applyProjectSelection(row, projectId);

    if (text == projectName) {
      return;
    }

    row.isApplyingProjectSuggestion = true;
    row.projectController.value = TextEditingValue(
      text: projectName,
      selection: TextSelection(
        baseOffset: normalizedQuery.length.clamp(0, projectName.length),
        extentOffset: projectName.length,
      ),
    );
    row.isApplyingProjectSuggestion = false;
  }

  void _handleProjectSuggestionSelected(
    _DayEntryDraft row,
    AutoSuggestBoxItem<int?> item,
  ) {
    _applyProjectSelection(row, item.value);
  }

  void _handleTaskSuggestionChanged(
    _DayEntryDraft row,
    String text,
    TextChangedReason reason,
  ) {
    if (row.isApplyingTaskSuggestion || reason != TextChangedReason.userInput) {
      return;
    }

    final normalizedQuery = text.trim();
    if (normalizedQuery.isEmpty) {
      setState(() => row.taskId = null);
      return;
    }

    final matchingTask = _firstTaskPrefixMatch(row.projectId, normalizedQuery);
    if (matchingTask == null) {
      setState(() => row.taskId = null);
      return;
    }

    final taskId = matchingTask['id'] as int;
    final taskName = matchingTask['name'] as String;
    setState(() => row.taskId = taskId);

    if (text == taskName) {
      return;
    }

    _setTaskControllerValue(
      row,
      taskName,
      selection: TextSelection(
        baseOffset: normalizedQuery.length.clamp(0, taskName.length),
        extentOffset: taskName.length,
      ),
    );
  }

  void _handleTaskSuggestionSelected(
    _DayEntryDraft row,
    AutoSuggestBoxItem<int?> item,
  ) {
    setState(() => row.taskId = item.value);
    _setTaskControllerValue(row, item.label);
  }

  void _handleNoteSuggestionChanged(
    _DayEntryDraft row,
    String text,
    TextChangedReason reason,
  ) {
    if (row.isApplyingNoteSuggestion || reason != TextChangedReason.userInput) {
      return;
    }

    setState(() {});

    final normalizedQuery = text.trim();
    if (normalizedQuery.isEmpty) {
      return;
    }

    final matchingNote = _noteSuggestionsForRow(row).firstWhere(
      (note) => note.toLowerCase().contains(normalizedQuery.toLowerCase()),
      orElse: () => '',
    );
    if (matchingNote.isEmpty) {
      return;
    }

    final matchIndex = matchingNote.toLowerCase().indexOf(
      normalizedQuery.toLowerCase(),
    );
    if (matchIndex != 0 || text == matchingNote) {
      return;
    }

    _setNoteControllerValue(
      row,
      matchingNote,
      selection: TextSelection(
        baseOffset: normalizedQuery.length.clamp(0, matchingNote.length),
        extentOffset: matchingNote.length,
      ),
    );
  }

  void _handleNoteSuggestionSelected(
    _DayEntryDraft row,
    AutoSuggestBoxItem<String> item,
  ) {
    setState(() {});
    _setNoteControllerValue(row, item.value ?? item.label);
  }

  Future<void> _saveRow(_DayEntryDraft row) async {
    final projectId = row.projectId;
    final taskId = row.taskId;
    final startMinutes = row.startMinutes;
    final endMinutes = row.endMinutes;
    final billableValue = row.billableValue;
    final note = row.noteController.text.trim();

    if (projectId == null ||
        taskId == null ||
        startMinutes == null ||
        endMinutes == null) {
      await showNoticeDialog(
        context,
        title: 'Complete the row first',
        message:
            'Select a project, choose a task, and enter valid hour and minute values for both start and end times before saving.',
      );
      return;
    }

    if (note.isEmpty) {
      await showNoticeDialog(
        context,
        title: 'Enter a note',
        message: 'Type a note before saving the time entry.',
      );
      return;
    }

    setState(() => row.isSaving = true);

    try {
      final saveDayEntry = widget.saveDayEntry;
      if (saveDayEntry != null) {
        await saveDayEntry(
          DayPageSaveRequest(
            date: _selectedDay,
            projectId: projectId,
            taskId: taskId,
            billableValue: billableValue,
            startMinutes: startMinutes,
            endMinutes: endMinutes,
            note: note,
            entryId: row.entryId,
          ),
        );
      } else {
        await dbHelper.saveDayEntry(
          date: _selectedDay,
          projectId: projectId,
          taskId: taskId,
          startMinutes: startMinutes,
          endMinutes: endMinutes,
          billableValue: billableValue,
          note: note,
          entryId: row.entryId,
        );
      }

      if (!mounted) {
        return;
      }

      await _loadDay();
    } catch (error) {
      if (!mounted) {
        return;
      }

      await showNoticeDialog(
        context,
        title: 'Unable to save day entry',
        message: error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => row.isSaving = false);
      }
    }
  }

  Future<void> _deleteRow(_DayEntryDraft row) async {
    final entryId = row.entryId;
    if (entryId == null) {
      return;
    }

    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete day entry?',
      message:
          'This permanently deletes the time entry and all of its component '
          'values. The delete will be blocked if another entity still '
          'references it.',
      confirmLabel: 'Delete entry',
    );

    if (!confirmed) {
      return;
    }

    setState(() => row.isSaving = true);

    try {
      final deleteDayEntry = widget.deleteDayEntry;
      if (deleteDayEntry != null) {
        await deleteDayEntry(entryId);
      } else {
        await dbHelper.deleteEntity(entryId);
      }

      if (!mounted) {
        return;
      }

      await _loadDay();
    } catch (error) {
      if (!mounted) {
        return;
      }

      await showNoticeDialog(
        context,
        title: 'Unable to delete day entry',
        message: error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => row.isSaving = false);
      }
    }
  }

  bool _canSaveRow(_DayEntryDraft row) {
    final startMinutes = row.startMinutes;
    final endMinutes = row.endMinutes;
    final note = row.noteController.text.trim();

    if (row.isSaving ||
        row.projectId == null ||
        row.taskId == null ||
        startMinutes == null ||
        endMinutes == null ||
        note.isEmpty) {
      return false;
    }

    return endMinutes > startMinutes;
  }

  int get _dayDurationMinutes {
    return _rows.fold(0, (total, row) {
      final durationMinutes = _rowDurationMinutes(row);
      return total + (durationMinutes ?? 0);
    });
  }

  int? _rowDurationMinutes(_DayEntryDraft row) {
    if (row.projectId == null || row.taskId == null) {
      return null;
    }

    final startMinutes = row.startMinutes;
    final endMinutes = row.endMinutes;
    if (startMinutes == null ||
        endMinutes == null ||
        endMinutes <= startMinutes) {
      return null;
    }

    return endMinutes - startMinutes;
  }

  Set<_DayEntryDraft> _overlappingRows() {
    final overlappingIndices = findOverlappingDayEntryIndices(
      _rows.map((row) => row.timeRange).toList(growable: false),
    );

    return overlappingIndices.map((index) => _rows[index]).toSet();
  }

  void _handleTimeFieldExited(_DayEntryDraft row) {
    if (row.showTimeWarnings) {
      return;
    }

    setState(() => row.showTimeWarnings = true);
  }

  Widget _buildActionButton({
    Key? key,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool filled = false,
  }) {
    final buttonStyle = const ButtonStyle(
      padding: WidgetStatePropertyAll(EdgeInsets.zero),
    );

    final button = filled
        ? FilledButton(
            key: key,
            style: buttonStyle,
            onPressed: onPressed,
            child: Icon(icon, size: 16),
          )
        : Button(
            key: key,
            style: buttonStyle,
            onPressed: onPressed,
            child: Icon(icon, size: 16),
          );

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: _actionButtonSize,
        height: _actionButtonSize,
        child: button,
      ),
    );
  }

  Widget _buildRowActions(_DayEntryDraft row, {Key? saveButtonKey}) {
    final saveButton = _buildActionButton(
      key: saveButtonKey,
      icon: FluentIcons.save,
      tooltip: row.isSaving ? 'Saving entry' : 'Save entry',
      onPressed: _canSaveRow(row) ? () => _saveRow(row) : null,
      filled: row.entryId == null,
    );

    final buttons = <Widget>[saveButton];
    if (row.entryId != null) {
      buttons.add(const SizedBox(width: _standardColumnGap));
      buttons.add(
        _buildActionButton(
          icon: FluentIcons.delete,
          tooltip: 'Delete entry',
          onPressed: row.isSaving ? null : () => _deleteRow(row),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(mainAxisSize: MainAxisSize.min, children: buttons),
    );
  }

  Widget _buildDayNavigationControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          _buildActionButton(
            icon: FluentIcons.chevron_left,
            tooltip: 'Previous day',
            onPressed: () => _shiftSelectedDay(-1),
          ),
          const SizedBox(width: _standardColumnGap),
          Expanded(
            child: FilledButton(
              onPressed: _jumpToToday,
              child: const Text('Today'),
            ),
          ),
          const SizedBox(width: _standardColumnGap),
          _buildActionButton(
            icon: FluentIcons.chevron_right,
            tooltip: 'Next day',
            onPressed: () => _shiftSelectedDay(1),
          ),
        ],
      ),
    );
  }

  Widget _buildTopControls(BuildContext context, String dayDurationLabel) {
    final theme = FluentTheme.of(context);

    return Table(
      key: const Key('dayTopControlsTable'),
      columnWidths: _entryTableColumnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.bottom,
      children: [
        TableRow(
          children: [
            _tableCell(
              bottomPadding: 0,
              child: SizedBox(
                key: const Key('dayDateControl'),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date',
                      key: const Key('dayDateLabel'),
                      style: theme.typography.bodyStrong,
                    ),
                    const SizedBox(height: 8),
                    DatePicker(
                      key: const Key('dayDatePicker'),
                      selected: _selectedDay,
                      showMonth: true,
                      showDay: true,
                      showYear: true,
                      onChanged: _handleDayChanged,
                    ),
                  ],
                ),
              ),
            ),
            _tableGapCell(),
            _tableCell(
              bottomPadding: 0,
              child: SizedBox(
                key: const Key('dayNavigationControls'),
                width: double.infinity,
                child: _buildDayNavigationControls(),
              ),
            ),
            _tableGapCell(),
            const SizedBox.shrink(),
            _tableGapCell(),
            const SizedBox.shrink(),
            _tableGapCell(),
            const SizedBox.shrink(),
            _tableGapCell(),
            _tableCell(
              bottomPadding: 0,
              child: SizedBox(
                key: const Key('dayTotalControl'),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day Total',
                      key: const Key('dayTotalLabel'),
                      style: theme.typography.bodyStrong,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      key: const Key('dayTotalField'),
                      height: 32,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.inactiveColor),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        dayDurationLabel,
                        style: theme.typography.body,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _tableGapCell(),
            const SizedBox.shrink(),
            _tableGapCell(),
            const SizedBox.shrink(),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayDurationLabel = formatDurationMinutes(_dayDurationMinutes);

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: ScaffoldPage.scrollable(
        header: PageHeader(title: Text(formatDayHeading(_selectedDay))),
        children: [
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _entryTableWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopControls(context, dayDurationLabel),
                        const SizedBox(height: 12),
                        _buildContent(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = FluentTheme.of(context);
    final overlappingRows = _overlappingRows();

    if (_isLoading && _rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: ProgressRing()),
      );
    }

    if (_loadError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.inactiveColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(_loadError!, style: theme.typography.body),
      );
    }

    if (_projects.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.inactiveColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'No project entities are available yet. Create projects and tasks before using the Day page.',
        ),
      );
    }

    return Table(
      key: const Key('dayEntryTable'),
      columnWidths: _entryTableColumnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.bottom,
      children: [
        _buildEntryHeaderRow(context),
        ..._rows.map(
          (row) => _buildEntryTableRow(context, row, overlappingRows),
        ),
      ],
    );
  }

  TableRow _buildEntryHeaderRow(BuildContext context) {
    final theme = FluentTheme.of(context);

    return TableRow(
      children: [
        _tableCell(
          bottomPadding: 10,
          child: SizedBox(
            key: const Key('dayProjectHeaderCell'),
            width: double.infinity,
            child: _headerCell(label: 'Project', style: theme),
          ),
        ),
        _tableGapCell(),
        _tableCell(
          bottomPadding: 10,
          child: SizedBox(
            key: const Key('dayTaskHeaderCell'),
            width: double.infinity,
            child: _headerCell(label: 'Task', style: theme),
          ),
        ),
        _tableGapCell(),
        _tableCell(
          bottomPadding: 10,
          child: Padding(
            padding: const EdgeInsets.only(left: _billableHeaderInset),
            child: _headerCell(label: 'Bill', style: theme),
          ),
        ),
        _tableGapCell(),
        _tableCell(
          bottomPadding: 10,
          child: _headerCell(label: 'Start', style: theme),
        ),
        _tableGapCell(),
        _tableCell(
          bottomPadding: 10,
          child: _headerCell(label: 'End', style: theme),
        ),
        _tableGapCell(),
        _tableCell(
          bottomPadding: 10,
          child: SizedBox(
            key: const Key('dayDurationHeaderCell'),
            width: double.infinity,
            child: _headerCell(label: 'Duration', style: theme),
          ),
        ),
        _tableGapCell(),
        _tableCell(
          bottomPadding: 10,
          child: _headerCell(label: 'Note', style: theme),
        ),
        _tableGapCell(),
        _tableCell(bottomPadding: 10, child: const SizedBox.shrink()),
      ],
    );
  }

  TableRow _buildEntryTableRow(
    BuildContext context,
    _DayEntryDraft row,
    Set<_DayEntryDraft> overlappingRows,
  ) {
    final theme = FluentTheme.of(context);
    final tasksForProject = _tasksForProject(row.projectId);
    final projectItems = _projectItems();
    final taskItems = _taskItemsForProject(row.projectId);
    final noteItems = _noteItemsForRow(row);
    final durationLabel = _formatRowDuration(row);
    final showOverlapWarning =
        row.showTimeWarnings && overlappingRows.contains(row);
    final showEndWarning =
        row.showTimeWarnings && (showOverlapWarning || row.hasInvalidEndTime);

    return TableRow(
      children: [
        _tableCell(
          child: _orderedField(
            order: 1,
            child: SizedBox(
              width: double.infinity,
              child: AutoSuggestBox<int?>(
                key: row.entryId == null
                    ? const Key('dayNewRowProjectField')
                    : null,
                controller: row.projectController,
                focusNode: row.projectFocusNode,
                items: projectItems,
                sorter: _prefixSorter,
                placeholder: 'Select project',
                clearButtonEnabled: false,
                enabled: !row.isSaving,
                onChanged: (text, reason) =>
                    _handleProjectSuggestionChanged(row, text, reason),
                onSelected: (item) =>
                    _handleProjectSuggestionSelected(row, item),
              ),
            ),
          ),
        ),
        _tableGapCell(),
        _tableCell(
          child: _orderedField(
            order: 2,
            child: SizedBox(
              width: double.infinity,
              child: AutoSuggestBox<int?>(
                key: row.entryId == null
                    ? const Key('dayNewRowTaskField')
                    : null,
                controller: row.taskController,
                items: taskItems,
                sorter: _prefixSorter,
                placeholder: row.projectId == null
                    ? 'Select project first'
                    : tasksForProject.isEmpty
                    ? 'No tasks for project'
                    : 'Select task',
                clearButtonEnabled: false,
                enabled: !row.isSaving && row.projectId != null,
                onChanged: (text, reason) =>
                    _handleTaskSuggestionChanged(row, text, reason),
                onSelected: (item) => _handleTaskSuggestionSelected(row, item),
              ),
            ),
          ),
        ),
        _tableGapCell(),
        _tableCell(
          child: _orderedField(
            order: 3,
            child: SizedBox(
              width: double.infinity,
              child: SizedBox(
                height: 32,
                child: Align(
                  alignment: Alignment.center,
                  child: Checkbox(
                    checked: row.billableValue == 1,
                    onChanged: row.isSaving
                        ? null
                        : (value) {
                            setState(
                              () =>
                                  row.billableValue = (value ?? false) ? 1 : 0,
                            );
                          },
                  ),
                ),
              ),
            ),
          ),
        ),
        _tableGapCell(),
        _tableCell(
          child: _orderedField(
            order: 4,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _TimeInput(
                hourFieldKey: row.entryId == null
                    ? const Key('dayNewRowStartHourField')
                    : null,
                minuteFieldKey: row.entryId == null
                    ? const Key('dayNewRowStartMinuteField')
                    : null,
                hourController: row.startHourController,
                minuteController: row.startMinuteController,
                enabled: !row.isSaving,
                onChanged: () => setState(() {}),
                onFocusChange: (hasFocus) {
                  if (!hasFocus) {
                    _handleTimeFieldExited(row);
                  }
                },
                showWarning: showOverlapWarning,
              ),
            ),
          ),
        ),
        _tableGapCell(),
        _tableCell(
          child: _orderedField(
            order: 5,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _TimeInput(
                hourFieldKey: row.entryId == null
                    ? const Key('dayNewRowEndHourField')
                    : null,
                minuteFieldKey: row.entryId == null
                    ? const Key('dayNewRowEndMinuteField')
                    : null,
                hourController: row.endHourController,
                minuteController: row.endMinuteController,
                enabled: !row.isSaving,
                onChanged: () => setState(() {}),
                onFocusChange: (hasFocus) {
                  if (!hasFocus) {
                    _handleTimeFieldExited(row);
                  }
                },
                showWarning: showEndWarning,
              ),
            ),
          ),
        ),
        _tableGapCell(),
        _tableCell(
          child: SizedBox(
            width: double.infinity,
            child: Container(
              height: 32,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: theme.inactiveColor),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(durationLabel, style: theme.typography.body),
            ),
          ),
        ),
        _tableGapCell(),
        _tableCell(
          child: _orderedField(
            order: 6,
            child: Focus(
              onKeyEvent: (node, event) {
                if (!(event is KeyDownEvent || event is KeyRepeatEvent)) {
                  return KeyEventResult.ignored;
                }

                if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                  if (!row.isSaving) {
                    unawaited(_saveRow(row));
                  }
                  return KeyEventResult.handled;
                }

                return KeyEventResult.ignored;
              },
              child: SizedBox(
                width: double.infinity,
                child: AutoSuggestBox<String>(
                  key: row.entryId == null
                      ? const Key('dayNewRowNoteField')
                      : null,
                  controller: row.noteController,
                  items: noteItems,
                  sorter: _substringSorter,
                  placeholder: 'What did you work on?',
                  clearButtonEnabled: false,
                  textInputAction: TextInputAction.done,
                  enabled: !row.isSaving,
                  onChanged: (text, reason) =>
                      _handleNoteSuggestionChanged(row, text, reason),
                  onSelected: (item) =>
                      _handleNoteSuggestionSelected(row, item),
                ),
              ),
            ),
          ),
        ),
        _tableGapCell(),
        _tableCell(
          child: _orderedField(
            order: 7,
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: _buildRowActions(
                  row,
                  saveButtonKey: row.entryId == null
                      ? const Key('dayNewRowSaveButton')
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _orderedField({required double order, required Widget child}) {
  return FocusTraversalOrder(order: NumericFocusOrder(order), child: child);
}

Widget _headerCell({required String label, required FluentThemeData style}) {
  return Text(label, style: style.typography.bodyStrong);
}

Widget _tableCell({required Widget child, double bottomPadding = 14}) {
  return Padding(
    padding: EdgeInsets.only(bottom: bottomPadding),
    child: child,
  );
}

Widget _tableGapCell() {
  return const SizedBox.shrink();
}

String _formatRowDuration(_DayEntryDraft row) {
  if (row.hasInvalidTimeInput) {
    return 'Invalid';
  }

  final startMinutes = row.startMinutes;
  final endMinutes = row.endMinutes;
  if (startMinutes == null || endMinutes == null) {
    return '--';
  }

  final durationMinutes = endMinutes - startMinutes;
  if (durationMinutes <= 0) {
    return 'Invalid';
  }

  return formatDurationMinutes(durationMinutes);
}

class _DayEntryDraft {
  _DayEntryDraft({
    this.entryId,
    this.projectId,
    this.taskId,
    this.billableValue = 0,
    this.showTimeWarnings = false,
    String projectName = '',
    String taskName = '',
    int? startMinutes,
    int? endMinutes,
    String note = '',
  }) : projectController = TextEditingController(text: projectName),
       taskController = TextEditingController(text: taskName),
       noteController = TextEditingController(text: note),
       startHourController = TextEditingController(
         text: _hourTextFromMinutes(startMinutes),
       ),
       startMinuteController = TextEditingController(
         text: _minuteTextFromMinutes(startMinutes),
       ),
       endHourController = TextEditingController(
         text: _hourTextFromMinutes(endMinutes),
       ),
       endMinuteController = TextEditingController(
         text: _minuteTextFromMinutes(endMinutes),
       );

  _DayEntryDraft.empty()
    : entryId = null,
      projectId = null,
      taskId = null,
      billableValue = 1,
      showTimeWarnings = false,
      projectController = TextEditingController(),
      taskController = TextEditingController(),
      noteController = TextEditingController(),
      startHourController = TextEditingController(),
      startMinuteController = TextEditingController(),
      endHourController = TextEditingController(),
      endMinuteController = TextEditingController();

  final int? entryId;
  int? projectId;
  int? taskId;
  int billableValue;
  final FocusNode projectFocusNode = FocusNode();
  final TextEditingController projectController;
  final TextEditingController taskController;
  final TextEditingController noteController;
  final TextEditingController startHourController;
  final TextEditingController startMinuteController;
  final TextEditingController endHourController;
  final TextEditingController endMinuteController;
  bool isSaving = false;
  bool isApplyingProjectSuggestion = false;
  bool isApplyingTaskSuggestion = false;
  bool isApplyingNoteSuggestion = false;
  bool showTimeWarnings;

  int? get startMinutes {
    return _minutesFromParts(
      startHourController.text,
      startMinuteController.text,
    );
  }

  int? get endMinutes {
    return _minutesFromParts(
      endHourController.text,
      endMinuteController.text,
      allowEndOfDay: true,
    );
  }

  bool get hasInvalidEndTime {
    final start = startMinutes;
    final end = endMinutes;

    return start != null && end != null && end <= start;
  }

  bool get hasInvalidStartTimeInput {
    return _hasInvalidTimeInput(
      startHourController.text,
      startMinuteController.text,
    );
  }

  bool get hasInvalidEndTimeInput {
    return _hasInvalidTimeInput(
      endHourController.text,
      endMinuteController.text,
      allowEndOfDay: true,
    );
  }

  bool get hasInvalidTimeInput {
    return hasInvalidStartTimeInput || hasInvalidEndTimeInput;
  }

  DayEntryTimeRange? get timeRange {
    final start = startMinutes;
    final end = endMinutes;
    if (start == null || end == null) {
      return null;
    }

    return DayEntryTimeRange(startMinutes: start, endMinutes: end);
  }

  void dispose() {
    projectFocusNode.dispose();
    projectController.dispose();
    taskController.dispose();
    startHourController.dispose();
    startMinuteController.dispose();
    endHourController.dispose();
    endMinuteController.dispose();
    noteController.dispose();
  }
}

class _TimeInput extends StatelessWidget {
  const _TimeInput({
    this.hourFieldKey,
    this.minuteFieldKey,
    required this.hourController,
    required this.minuteController,
    required this.enabled,
    required this.onChanged,
    required this.onFocusChange,
    required this.showWarning,
  });

  final Key? hourFieldKey;
  final Key? minuteFieldKey;
  final TextEditingController hourController;
  final TextEditingController minuteController;
  final bool enabled;
  final VoidCallback onChanged;
  final ValueChanged<bool> onFocusChange;
  final bool showWarning;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final warningColor = showWarning ? Colors.errorPrimaryColor : null;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: onFocusChange,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 42,
            child: TextBox(
              key: hourFieldKey,
              controller: hourController,
              placeholder: 'HH',
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              enabled: enabled,
              highlightColor: warningColor,
              unfocusedColor: warningColor,
              onChanged: (_) => onChanged(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(':', style: theme.typography.bodyStrong),
          ),
          SizedBox(
            width: 42,
            child: TextBox(
              key: minuteFieldKey,
              controller: minuteController,
              placeholder: 'MM',
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              enabled: enabled,
              highlightColor: warningColor,
              unfocusedColor: warningColor,
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}

bool _hasInvalidTimeInput(
  String hourText,
  String minuteText, {
  bool allowEndOfDay = false,
}) {
  final hourValue = hourText.trim();
  final minuteValue = minuteText.trim();

  if (hourValue.isEmpty && minuteValue.isEmpty) {
    return false;
  }

  final hour = int.tryParse(hourValue);
  final minute = int.tryParse(minuteValue);
  if (hour == null || minute == null) {
    return false;
  }

  if (allowEndOfDay && hour == 24 && minute == 0) {
    return false;
  }

  return hour < 0 || hour > 23 || minute < 0 || minute > 59;
}

int? _minutesFromParts(
  String hourText,
  String minuteText, {
  bool allowEndOfDay = false,
}) {
  final hour = int.tryParse(hourText.trim());
  final minute = int.tryParse(minuteText.trim());

  if (hour == null || minute == null) {
    return null;
  }

  if (allowEndOfDay && hour == 24 && minute == 0) {
    return 24 * 60;
  }

  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }

  return (hour * 60) + minute;
}

String _hourTextFromMinutes(int? minutes) {
  if (minutes == null) {
    return '';
  }

  return (minutes ~/ 60).toString().padLeft(2, '0');
}

String _minuteTextFromMinutes(int? minutes) {
  if (minutes == null) {
    return '';
  }

  return (minutes % 60).toString().padLeft(2, '0');
}
