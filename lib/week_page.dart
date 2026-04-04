import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import 'app_db.dart';
import 'time_entry_formatting.dart';

class WeekPage extends StatefulWidget {
  const WeekPage({
    required this.onOpenDay,
    this.initialSelectedDate,
    this.loadWeekPageData,
    super.key,
  });

  final ValueChanged<DateTime> onOpenDay;
  final DateTime? initialSelectedDate;
  final Future<Map<String, dynamic>> Function(DateTime date)? loadWeekPageData;

  @override
  State<WeekPage> createState() => _WeekPageState();
}

class _WeekPageState extends State<WeekPage> {
  static const List<String> _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const double _projectColumnWidth = 220;
  static const double _projectToTaskGap = 12;
  static const double _taskColumnWidth = 240;
  static const double _taskToBillableGap = 12;
  static const double _billableColumnWidth = 56;
  static const double _dayColumnWidth = 76;
  static const double _totalColumnWidth = 92;
  static const double _standardColumnGap = 12;
  static const double _actionButtonSize = 32;
  static const double _notesDialogWidth = 520;
  static const BoxConstraints _notesDialogConstraints = BoxConstraints(
    maxWidth: 560,
    maxHeight: 756,
  );
  static const double _summaryTableWidth =
      _projectColumnWidth +
      _projectToTaskGap +
      _taskColumnWidth +
      _taskToBillableGap +
      _billableColumnWidth +
      (_dayColumnWidth * 7) +
      _totalColumnWidth;
  static const EdgeInsets _weekLinkPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 6,
  );
  static const ButtonStyle _weekLinkButtonStyle = ButtonStyle(
    padding: WidgetStatePropertyAll(_weekLinkPadding),
  );
  static const Map<int, TableColumnWidth> _summaryTableColumnWidths =
      <int, TableColumnWidth>{
        0: FixedColumnWidth(_projectColumnWidth),
        1: FixedColumnWidth(_projectToTaskGap),
        2: FixedColumnWidth(_taskColumnWidth),
        3: FixedColumnWidth(_taskToBillableGap),
        4: FixedColumnWidth(_billableColumnWidth),
        5: FixedColumnWidth(_dayColumnWidth),
        6: FixedColumnWidth(_dayColumnWidth),
        7: FixedColumnWidth(_dayColumnWidth),
        8: FixedColumnWidth(_dayColumnWidth),
        9: FixedColumnWidth(_dayColumnWidth),
        10: FixedColumnWidth(_dayColumnWidth),
        11: FixedColumnWidth(_dayColumnWidth),
        12: FixedColumnWidth(_totalColumnWidth),
      };

  static const List<String> _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thur',
    'Fri',
    'Sat',
    'Sun',
  ];
  late DateTime _selectedDate;
  List<Map<String, dynamic>> _projects = const [];
  List<Map<String, dynamic>> _rows = const [];
  int _weekTotalMinutes = 0;
  bool _isLoading = true;
  String? _loadError;

  DateTime get _selectedWeekStart => startOfWeekMonday(_selectedDate);

  @override
  void initState() {
    super.initState();
    _selectedDate = dateOnly(widget.initialSelectedDate ?? DateTime.now());
    _loadWeek();
  }

  Future<void> _loadWeek() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final loadWeekPageData =
          widget.loadWeekPageData ?? dbHelper.getWeekPageData;
      final weekData = await loadWeekPageData(_selectedDate);
      final projects = List<Map<String, dynamic>>.from(
        weekData['projects'] as List<dynamic>? ?? const [],
      );
      final rows = List<Map<String, dynamic>>.from(
        weekData['rows'] as List<dynamic>? ?? const [],
      );
      final weekTotalMinutes = weekData['week_total_minutes'] as int? ?? 0;

      if (!mounted) {
        return;
      }

      setState(() {
        _projects = projects;
        _rows = rows;
        _weekTotalMinutes = weekTotalMinutes;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _projects = const [];
        _rows = const [];
        _weekTotalMinutes = 0;
        _loadError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _jumpToCurrentWeek() async {
    final today = dateOnly(DateTime.now());
    if (_selectedDate == today) {
      await _loadWeek();
      return;
    }

    setState(() => _selectedDate = today);
    await _loadWeek();
  }

  Future<void> _shiftSelectedWeek(int weekOffset) async {
    if (weekOffset == 0) {
      return;
    }

    setState(
      () => _selectedDate = dateOnly(
        _selectedDate.add(Duration(days: weekOffset * 7)),
      ),
    );
    await _loadWeek();
  }

  Future<void> _handleDateChanged(DateTime value) async {
    final nextDate = dateOnly(value);
    if (_selectedDate == nextDate) {
      return;
    }

    setState(() => _selectedDate = nextDate);
    await _loadWeek();
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    const buttonStyle = ButtonStyle(
      padding: WidgetStatePropertyAll(EdgeInsets.zero),
    );

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: _actionButtonSize,
        height: _actionButtonSize,
        child: Button(
          style: buttonStyle,
          onPressed: onPressed,
          child: Icon(icon, size: 16),
        ),
      ),
    );
  }

  Widget _buildWeekNavigationControls() {
    return Row(
      children: [
        _buildActionButton(
          icon: FluentIcons.chevron_left,
          tooltip: 'Previous week',
          onPressed: () => _shiftSelectedWeek(-1),
        ),
        const SizedBox(width: _standardColumnGap),
        Expanded(
          child: FilledButton(
            onPressed: _jumpToCurrentWeek,
            child: const Text('Current Week'),
          ),
        ),
        const SizedBox(width: _standardColumnGap),
        _buildActionButton(
          icon: FluentIcons.chevron_right,
          tooltip: 'Next week',
          onPressed: () => _shiftSelectedWeek(1),
        ),
      ],
    );
  }

  Widget _buildTopControls(BuildContext context, String weekTotalLabel) {
    final theme = FluentTheme.of(context);

    return Table(
      columnWidths: _summaryTableColumnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.bottom,
      children: [
        TableRow(
          children: [
            _tableCell(
              bottomPadding: 0,
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date', style: theme.typography.bodyStrong),
                    const SizedBox(height: 8),
                    DatePicker(
                      selected: _selectedDate,
                      showMonth: true,
                      showDay: true,
                      showYear: true,
                      onChanged: _handleDateChanged,
                    ),
                  ],
                ),
              ),
            ),
            _tableGapCell(),
            _tableCell(
              bottomPadding: 0,
              child: SizedBox(
                width: double.infinity,
                child: _buildWeekNavigationControls(),
              ),
            ),
            _tableGapCell(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            _tableCell(
              bottomPadding: 0,
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Week Total', style: theme.typography.bodyStrong),
                    const SizedBox(height: 8),
                    Container(
                      height: 32,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.inactiveColor),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(weekTotalLabel, style: theme.typography.body),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekTotalLabel = formatDurationMinutes(_weekTotalMinutes);

    return ScaffoldPage.scrollable(
      header: PageHeader(title: Text(formatWeekHeading(_selectedWeekStart))),
      children: [
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _summaryTableWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopControls(context, weekTotalLabel),
                  const SizedBox(height: 12),
                  _buildContent(context),
                ],
              ),
            ),
          ),
        ),
      ],
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
          'No project entities are available yet. Create projects and tasks before using the Day or Week page.',
        ),
      );
    }

    if (_rows.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.inactiveColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'No time entries were recorded for the selected week.',
        ),
      );
    }

    return Table(
      columnWidths: _summaryTableColumnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.bottom,
      children: [
        _buildSummaryHeaderRow(context),
        ..._rows.map(_buildSummaryRow),
      ],
    );
  }

  TableRow _buildSummaryHeaderRow(BuildContext context) {
    final theme = FluentTheme.of(context);

    return TableRow(
      children: [
        _tableCell(
          child: _summaryHeaderCell(
            Text('Project', style: theme.typography.bodyStrong),
          ),
          bottomPadding: 10,
        ),
        _tableGapCell(),
        _tableCell(
          child: _summaryHeaderCell(
            Text('Task', style: theme.typography.bodyStrong),
          ),
          bottomPadding: 10,
        ),
        _tableGapCell(),
        _tableCell(
          child: _summaryHeaderCell(
            SizedBox(
              width: double.infinity,
              child: Text('Bill', style: theme.typography.bodyStrong),
            ),
          ),
          bottomPadding: 10,
        ),
        for (var index = 0; index < 7; index += 1)
          _tableCell(
            child: _summaryHeaderCell(_buildDayHeaderLink(context, index)),
            bottomPadding: 10,
          ),
        _tableCell(
          child: _summaryHeaderCell(
            SizedBox(
              width: double.infinity,
              child: Text('Total', style: theme.typography.bodyStrong),
            ),
          ),
          bottomPadding: 10,
        ),
      ],
    );
  }

  Widget _buildDayHeaderLink(BuildContext context, int dayIndex) {
    final day = _selectedWeekStart.add(Duration(days: dayIndex));

    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: 'Open ${formatDayHeading(day)}',
        child: _hoverableWeekLink(
          child: HyperlinkButton(
            style: _weekLinkButtonStyle,
            onPressed: () => widget.onOpenDay(day),
            child: Text(
              _weekdayLabels[dayIndex],
              style: FluentTheme.of(context).typography.bodyStrong,
              textAlign: TextAlign.left,
            ),
          ),
        ),
      ),
    );
  }

  TableRow _buildSummaryRow(Map<String, dynamic> row) {
    final dayMinutes = List<int>.from(
      row['day_minutes'] as List<dynamic>? ?? const <int>[],
    );
    final dayNoteLines = _dayNoteLinesForRow(row);

    return TableRow(
      children: [
        _tableCell(child: _textCell(row['project_name'] as String)),
        _tableGapCell(),
        _tableCell(child: _textCell(row['task_name'] as String)),
        _tableGapCell(),
        _tableCell(
          child: SizedBox(
            height: 32,
            child: Align(
              alignment: Alignment.centerLeft,
              child: IgnorePointer(
                child: Checkbox(
                  checked: (row['billable_value'] as int? ?? 0) == 1,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
        for (var index = 0; index < 7; index += 1)
          _tableCell(
            child: _buildDayCellLink(
              row: row,
              dayIndex: index,
              minutes: index < dayMinutes.length ? dayMinutes[index] : 0,
              noteLines: index < dayNoteLines.length
                  ? dayNoteLines[index]
                  : const <String>[],
            ),
          ),
        _tableCell(
          child: _durationCell(
            row['total_minutes'] as int? ?? 0,
            showZero: true,
          ),
        ),
      ],
    );
  }

  Widget _textCell(String value) {
    return SizedBox(
      width: double.infinity,
      child: Text(value, overflow: TextOverflow.ellipsis),
    );
  }

  List<List<String>> _dayNoteLinesForRow(Map<String, dynamic> row) {
    final rawDayNoteLines =
        row['day_note_lines'] as List<dynamic>? ?? const <dynamic>[];

    return rawDayNoteLines.map((dayNotes) {
      if (dayNotes is List) {
        return List<String>.from(dayNotes);
      }

      return const <String>[];
    }).toList();
  }

  Widget _buildDayCellLink({
    required Map<String, dynamic> row,
    required int dayIndex,
    required int minutes,
    required List<String> noteLines,
  }) {
    if (minutes == 0) {
      return _durationCell(minutes);
    }

    return SizedBox(
      width: double.infinity,
      child: Align(
        alignment: Alignment.centerLeft,
        child: _hoverableWeekLink(
          child: HyperlinkButton(
            style: _weekLinkButtonStyle,
            onPressed: () => _showDayNotesDialog(
              row: row,
              dayIndex: dayIndex,
              noteLines: noteLines,
            ),
            child: Text(
              formatDurationMinutes(minutes),
              textAlign: TextAlign.left,
            ),
          ),
        ),
      ),
    );
  }

  Widget _hoverableWeekLink({required Widget child}) {
    return MouseRegion(cursor: SystemMouseCursors.click, child: child);
  }

  Future<void> _showDayNotesDialog({
    required Map<String, dynamic> row,
    required int dayIndex,
    required List<String> noteLines,
  }) async {
    final billableLabel = (row['billable_value'] as int? ?? 0) == 1
        ? 'Billable'
        : 'Non-billable';
    final projectName = row['project_name'] as String? ?? 'Project';
    final taskName = row['task_name'] as String? ?? 'Task';
    final notesText = noteLines.isEmpty ? 'No notes recorded.' : noteLines.join('\n');

    await Clipboard.setData(ClipboardData(text: notesText));
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = FluentTheme.of(dialogContext);

        return ContentDialog(
          constraints: _notesDialogConstraints,
          title: Text(
            '${_weekdayNames[dayIndex]} notes for '
            '$projectName / $taskName ($billableLabel)',
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: _notesDialogWidth),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notesText),
                  const SizedBox(height: 12),
                  Opacity(
                    opacity: 0.8,
                    child: Text(
                      '(notes added to clipboard)',
                      style: theme.typography.body,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Button(
              key: const Key('weekNotesCopyButton'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: notesText));
              },
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _durationCell(int minutes, {bool showZero = false}) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        minutes == 0 && !showZero ? '' : formatDurationMinutes(minutes),
        textAlign: TextAlign.left,
      ),
    );
  }
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

Widget _summaryHeaderCell(Widget child) {
  return SizedBox(
    height: 32,
    width: double.infinity,
    child: Align(alignment: Alignment.centerLeft, child: child),
  );
}
