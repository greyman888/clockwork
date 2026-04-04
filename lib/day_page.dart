import 'package:flutter/services.dart';
import 'package:fluent_ui/fluent_ui.dart';

import 'app_db.dart';
import 'editor_helpers.dart';

class DayPage extends StatefulWidget {
  const DayPage({super.key});

  @override
  State<DayPage> createState() => _DayPageState();
}

class _DayPageState extends State<DayPage> {
  static const double _projectColumnWidth = 220;
  static const double _taskColumnWidth = 240;
  static const double _topRowSecondaryWidth =
      (_taskColumnWidth - _standardColumnGap) / 2;
  static const double _timeColumnWidth = 102;
  static const double _durationColumnWidth = 104;
  static const double _noteColumnWidth = 320;
  static const double _saveColumnWidth = 88;
  static const double _standardColumnGap = 12;
  static const double _tightColumnGap = 4;
  static const Map<int, TableColumnWidth> _entryTableColumnWidths =
      <int, TableColumnWidth>{
        0: FixedColumnWidth(_projectColumnWidth),
        1: FixedColumnWidth(_standardColumnGap),
        2: FixedColumnWidth(_taskColumnWidth),
        3: FixedColumnWidth(_standardColumnGap),
        4: FixedColumnWidth(_timeColumnWidth),
        5: FixedColumnWidth(_tightColumnGap),
        6: FixedColumnWidth(_timeColumnWidth),
        7: FixedColumnWidth(_tightColumnGap),
        8: FixedColumnWidth(_durationColumnWidth),
        9: FixedColumnWidth(_standardColumnGap),
        10: FixedColumnWidth(_noteColumnWidth),
        11: FixedColumnWidth(_standardColumnGap),
        12: FixedColumnWidth(_saveColumnWidth),
      };

  DateTime _selectedDay = _dateOnly(DateTime.now());
  List<Map<String, dynamic>> _projects = const [];
  List<Map<String, dynamic>> _tasks = const [];
  List<_DayEntryDraft> _rows = const [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
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
      final dayData = await dbHelper.getDayPageData(_selectedDay);
      final projects = List<Map<String, dynamic>>.from(
        dayData['projects'] as List<dynamic>? ?? const [],
      );
      final tasks = List<Map<String, dynamic>>.from(
        dayData['tasks'] as List<dynamic>? ?? const [],
      );
      final entries = List<Map<String, dynamic>>.from(
        dayData['entries'] as List<dynamic>? ?? const [],
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
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _disposeRows();
      setState(() {
        _projects = const [];
        _tasks = const [];
        _rows = const [];
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
            taskId: entry['task_id'] as int?,
            startMinutes: entry['start_minutes'] as int?,
            endMinutes: entry['end_minutes'] as int?,
            note: entry['note'] as String? ?? '',
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
    final today = _dateOnly(DateTime.now());
    if (_selectedDay == today) {
      await _loadDay();
      return;
    }

    setState(() => _selectedDay = today);
    await _loadDay();
  }

  Future<void> _handleDayChanged(DateTime value) async {
    final nextDay = _dateOnly(value);
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

  void _handleProjectChanged(_DayEntryDraft row, int? projectId) {
    final availableTaskIds = _tasksForProject(
      projectId,
    ).map((task) => task['id'] as int).toSet();

    setState(() {
      row.projectId = projectId;
      if (!availableTaskIds.contains(row.taskId)) {
        row.taskId = null;
      }
    });
  }

  void _handleTaskChanged(_DayEntryDraft row, int? taskId) {
    setState(() => row.taskId = taskId);
  }

  Future<void> _saveRow(_DayEntryDraft row) async {
    final projectId = row.projectId;
    final taskId = row.taskId;
    final startMinutes = row.startMinutes;
    final endMinutes = row.endMinutes;

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

    setState(() => row.isSaving = true);

    try {
      await dbHelper.saveDayEntry(
        date: _selectedDay,
        projectId: projectId,
        taskId: taskId,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        note: row.noteController.text,
        entryId: row.entryId,
      );

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

  bool _canSaveRow(_DayEntryDraft row) {
    final startMinutes = row.startMinutes;
    final endMinutes = row.endMinutes;

    if (row.isSaving ||
        row.projectId == null ||
        row.taskId == null ||
        startMinutes == null ||
        endMinutes == null) {
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

  Widget _buildSaveButton(_DayEntryDraft row) {
    final onPressed = _canSaveRow(row) ? () => _saveRow(row) : null;
    final child = Text(row.isSaving ? 'Saving...' : 'Save');

    if (row.entryId == null) {
      return FilledButton(onPressed: onPressed, child: child);
    }

    return Button(onPressed: onPressed, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final dayDurationLabel = _formatDurationMinutes(_dayDurationMinutes);

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: ScaffoldPage.scrollable(
        header: PageHeader(title: Text(_formatDayHeading(_selectedDay))),
        children: [
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: _projectColumnWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Date', style: theme.typography.bodyStrong),
                          const SizedBox(height: 8),
                          DatePicker(
                            selected: _selectedDay,
                            showMonth: true,
                            showDay: true,
                            showYear: true,
                            onChanged: _handleDayChanged,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: _standardColumnGap),
                    SizedBox(
                      width: _topRowSecondaryWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: FilledButton(
                          onPressed: _jumpToToday,
                          child: const Text('Today'),
                        ),
                      ),
                    ),
                    const SizedBox(width: _standardColumnGap),
                    SizedBox(
                      width: _topRowSecondaryWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Duration',
                            style: theme.typography.bodyStrong,
                          ),
                          const SizedBox(height: 8),
                          Container(
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
                  ],
                ),
                const SizedBox(height: 12),
                _buildContent(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = FluentTheme.of(context);

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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        columnWidths: _entryTableColumnWidths,
        defaultVerticalAlignment: TableCellVerticalAlignment.bottom,
        children: [
          _buildEntryHeaderRow(context),
          ..._rows.map((row) => _buildEntryTableRow(context, row)),
        ],
      ),
    );
  }

  TableRow _buildEntryHeaderRow(BuildContext context) {
    final theme = FluentTheme.of(context);

    return TableRow(
      children: [
        _tableCell(
          bottomPadding: 10,
          child: _headerCell(label: 'Project', style: theme),
        ),
        _tableGapCell(),
        _tableCell(
          bottomPadding: 10,
          child: _headerCell(label: 'Task', style: theme),
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
          child: _headerCell(label: 'Duration', style: theme),
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

  TableRow _buildEntryTableRow(BuildContext context, _DayEntryDraft row) {
    final theme = FluentTheme.of(context);
    final tasksForProject = _tasksForProject(row.projectId);
    final durationLabel = _formatDuration(row.startMinutes, row.endMinutes);

    return TableRow(
      children: [
        _tableCell(
          child: _orderedField(
            order: 1,
            child: SizedBox(
              width: double.infinity,
              child: ComboBox<int?>(
                value: row.projectId,
                isExpanded: true,
                items: [
                  const ComboBoxItem<int?>(
                    value: null,
                    child: Text('Select project'),
                  ),
                  ..._projects.map(
                    (project) => ComboBoxItem<int?>(
                      value: project['id'] as int,
                      child: Text(project['name'] as String),
                    ),
                  ),
                ],
                onChanged: row.isSaving
                    ? null
                    : (value) => _handleProjectChanged(row, value),
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
              child: ComboBox<int?>(
                value: row.taskId,
                isExpanded: true,
                items: [
                  ComboBoxItem<int?>(
                    value: null,
                    child: Text(
                      row.projectId == null
                          ? 'Select project first'
                          : tasksForProject.isEmpty
                          ? 'No tasks for project'
                          : 'Select task',
                    ),
                  ),
                  ...tasksForProject.map(
                    (task) => ComboBoxItem<int?>(
                      value: task['id'] as int,
                      child: Text(task['name'] as String),
                    ),
                  ),
                ],
                onChanged: row.isSaving || row.projectId == null
                    ? null
                    : (value) => _handleTaskChanged(row, value),
              ),
            ),
          ),
        ),
        _tableGapCell(),
        _tableCell(
          child: _orderedField(
            order: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _TimeInput(
                hourController: row.startHourController,
                minuteController: row.startMinuteController,
                enabled: !row.isSaving,
                onChanged: () => setState(() {}),
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
                hourController: row.endHourController,
                minuteController: row.endMinuteController,
                enabled: !row.isSaving,
                onChanged: () => setState(() {}),
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
            order: 5,
            child: SizedBox(
              width: double.infinity,
              child: TextBox(
                controller: row.noteController,
                placeholder: 'What did you work on?',
                enabled: !row.isSaving,
              ),
            ),
          ),
        ),
        _tableGapCell(),
        _tableCell(
          child: _orderedField(
            order: 6,
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: _buildSaveButton(row),
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

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _formatDuration(int? startMinutes, int? endMinutes) {
  if (startMinutes == null || endMinutes == null) {
    return '--';
  }

  final durationMinutes = endMinutes - startMinutes;
  if (durationMinutes <= 0) {
    return 'Invalid';
  }

  return _formatDurationMinutes(durationMinutes);
}

String _formatDurationMinutes(int durationMinutes) {
  if (durationMinutes <= 0) {
    return '0m';
  }

  final hours = durationMinutes ~/ 60;
  final minutes = durationMinutes % 60;

  if (hours == 0) {
    return '${minutes}m';
  }

  if (minutes == 0) {
    return '${hours}h';
  }

  return '${hours}h ${minutes}m';
}

String _formatDayHeading(DateTime day) {
  const weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final weekdayName = weekdayNames[day.weekday - 1];
  final monthName = monthNames[day.month - 1];
  return '$weekdayName ${day.day} $monthName ${day.year}';
}

class _DayEntryDraft {
  _DayEntryDraft({
    this.entryId,
    this.projectId,
    this.taskId,
    int? startMinutes,
    int? endMinutes,
    String note = '',
  }) : noteController = TextEditingController(text: note),
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
      noteController = TextEditingController(),
      startHourController = TextEditingController(),
      startMinuteController = TextEditingController(),
      endHourController = TextEditingController(),
      endMinuteController = TextEditingController();

  final int? entryId;
  int? projectId;
  int? taskId;
  final TextEditingController noteController;
  final TextEditingController startHourController;
  final TextEditingController startMinuteController;
  final TextEditingController endHourController;
  final TextEditingController endMinuteController;
  bool isSaving = false;

  int? get startMinutes {
    return _minutesFromParts(
      startHourController.text,
      startMinuteController.text,
    );
  }

  int? get endMinutes {
    return _minutesFromParts(endHourController.text, endMinuteController.text);
  }

  void dispose() {
    startHourController.dispose();
    startMinuteController.dispose();
    endHourController.dispose();
    endMinuteController.dispose();
    noteController.dispose();
  }
}

class _TimeInput extends StatelessWidget {
  const _TimeInput({
    required this.hourController,
    required this.minuteController,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController hourController;
  final TextEditingController minuteController;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 42,
          child: TextBox(
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
            onChanged: (_) => onChanged(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(':', style: theme.typography.bodyStrong),
        ),
        SizedBox(
          width: 42,
          child: TextBox(
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
            onChanged: (_) => onChanged(),
          ),
        ),
      ],
    );
  }
}

int? _minutesFromParts(String hourText, String minuteText) {
  final hour = int.tryParse(hourText.trim());
  final minute = int.tryParse(minuteText.trim());

  if (hour == null || minute == null) {
    return null;
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
