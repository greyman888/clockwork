import 'package:clockwork/day_page.dart';
import 'package:clockwork/setup_and_summary_page.dart';
import 'package:clockwork/time_entry_formatting.dart';
import 'package:clockwork/ui_preview_page.dart';
import 'package:clockwork/week_page.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('layout invariants', () {
    testWidgets(
      'day page top controls align to the entry grid at both desktop sizes',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));

        for (final size in const [Size(1400, 900), Size(1100, 900)]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            FluentApp(
              home: DayPage(
                initialDay: DateTime(2026, 4, 8),
                loadDayPageData: (_) async => _buildDayLayoutData(),
                saveDayEntry: (_) async {},
                deleteDayEntry: (_) async {},
                todayProvider: () => DateTime(2026, 4, 8),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          _expectAlignedColumns(
            tester,
            topControlKey: 'dayDateControl',
            headerCellKey: 'dayProjectHeaderCell',
          );
          _expectAlignedColumns(
            tester,
            topControlKey: 'dayNavigationControls',
            headerCellKey: 'dayTaskHeaderCell',
          );
          _expectAlignedColumns(
            tester,
            topControlKey: 'dayTotalControl',
            headerCellKey: 'dayDurationHeaderCell',
          );
          _expectMatchingLabelSpacing(
            tester,
            firstLabelKey: 'dayDateLabel',
            firstControlKey: 'dayDatePicker',
            secondLabelKey: 'dayTotalLabel',
            secondControlKey: 'dayTotalField',
          );
        }
      },
    );

    testWidgets(
      'week page top controls align to the summary grid at both desktop sizes',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));

        for (final size in const [Size(1400, 900), Size(1100, 900)]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            FluentApp(
              home: WeekPage(
                initialSelectedDate: DateTime(2026, 4, 8),
                todayProvider: () => DateTime(2026, 4, 8),
                onOpenDay: (_) {},
                loadWeekPageData: (_) async => _buildWeekLayoutData(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          _expectAlignedColumns(
            tester,
            topControlKey: 'weekDateControl',
            headerCellKey: 'weekProjectHeaderCell',
          );
          _expectAlignedColumns(
            tester,
            topControlKey: 'weekNavigationControls',
            headerCellKey: 'weekTaskHeaderCell',
          );
          _expectAlignedColumns(
            tester,
            topControlKey: 'weekTotalControl',
            headerCellKey: 'weekTotalHeaderCell',
          );
          _expectMatchingLabelSpacing(
            tester,
            firstLabelKey: 'weekDateLabel',
            firstControlKey: 'weekDatePicker',
            secondLabelKey: 'weekTotalLabel',
            secondControlKey: 'weekTotalField',
          );
        }
      },
    );

    testWidgets(
      'setup and summary page keeps the desktop columns aligned at both review sizes',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));

        for (final size in const [Size(1400, 900), Size(1100, 900)]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            FluentApp(
              home: SetupAndSummaryPage(
                loadPageData: () async => _buildSetupSummaryLayoutData(),
                saveProject: (_) async => 1,
                saveTask: (_) async => 1,
                deleteEntity: (_) async {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);

          final setupColumnRect = tester.getRect(
            find.byKey(const Key('setupAndSummarySetupColumn')),
          );
          final summaryColumnRect = tester.getRect(
            find.byKey(const Key('setupAndSummarySummaryColumn')),
          );

          expect(
            summaryColumnRect.left - setupColumnRect.right,
            moreOrLessEquals(16, epsilon: 0.1),
          );
          expect(setupColumnRect.width, moreOrLessEquals(400, epsilon: 0.1));
        }
      },
    );
  });

  group('preview workflow', () {
    testWidgets(
      'preview page drills from the week scenario into the linked day scenario',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1600, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(const FluentApp(home: UiPreviewPage()));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Week / Weekday Links'),
          240,
          scrollable: find.descendant(
            of: find.byKey(const Key('uiPreviewScenarioList')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(find.text('Week / Weekday Links').first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Fri').first);
        await tester.pumpAndSettle();

        final scenarioTitle = tester.widget<Text>(
          find.byKey(const Key('uiPreviewScenarioTitle')),
        );
        expect(scenarioTitle.data, 'Day / From Week Navigation');
        expect(
          find.text(formatDayHeading(DateTime(2026, 4, 10))),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('preview notes scenario opens the popup deterministically', (
      tester,
    ) async {
      final clipboardWrites = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            methodCall,
          ) async {
            if (methodCall.method == 'Clipboard.setData') {
              final arguments =
                  methodCall.arguments as Map<Object?, Object?>? ?? const {};
              clipboardWrites.add(arguments['text'] as String? ?? '');
            }

            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.binding.setSurfaceSize(const Size(1600, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const FluentApp(home: UiPreviewPage()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Week / Notes Popup'),
        240,
        scrollable: find.descendant(
          of: find.byKey(const Key('uiPreviewScenarioList')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('Week / Notes Popup').first);
      await tester.pumpAndSettle();

      expect(find.byType(ContentDialog), findsOneWidget);
      expect(find.byKey(const Key('weekNotesCopyButton')), findsOneWidget);
      expect(clipboardWrites, isNotEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}

void _expectAlignedColumns(
  WidgetTester tester, {
  required String topControlKey,
  required String headerCellKey,
}) {
  final controlRect = tester.getRect(find.byKey(Key(topControlKey)));
  final headerRect = tester.getRect(find.byKey(Key(headerCellKey)));

  expect(controlRect.left, moreOrLessEquals(headerRect.left, epsilon: 0.1));
  expect(controlRect.width, moreOrLessEquals(headerRect.width, epsilon: 0.1));
}

void _expectMatchingLabelSpacing(
  WidgetTester tester, {
  required String firstLabelKey,
  required String firstControlKey,
  required String secondLabelKey,
  required String secondControlKey,
}) {
  final firstLabelRect = tester.getRect(find.byKey(Key(firstLabelKey)));
  final firstControlRect = tester.getRect(find.byKey(Key(firstControlKey)));
  final secondLabelRect = tester.getRect(find.byKey(Key(secondLabelKey)));
  final secondControlRect = tester.getRect(find.byKey(Key(secondControlKey)));

  final firstSpacing = firstControlRect.top - firstLabelRect.bottom;
  final secondSpacing = secondControlRect.top - secondLabelRect.bottom;

  expect(firstSpacing, greaterThan(0));
  expect(secondSpacing, greaterThan(0));
}

Map<String, dynamic> _buildDayLayoutData() {
  return {
    'projects': const [
      {'id': 1, 'name': 'Adore'},
      {'id': 2, 'name': 'Koorong'},
      {'id': 3, 'name': 'Internal Delivery Improvements'},
    ],
    'tasks': const [
      {'id': 11, 'project_id': 1, 'name': 'UAT Support'},
      {'id': 12, 'project_id': 1, 'name': 'Error Proofing'},
      {'id': 21, 'project_id': 2, 'name': 'Returns'},
      {
        'id': 31,
        'project_id': 3,
        'name': 'Quarterly workflow resilience and release readiness review',
      },
    ],
    'entries': const [
      {
        'id': 1,
        'project_id': 1,
        'task_id': 11,
        'billable_value': 1,
        'start_minutes': 540,
        'end_minutes': 615,
        'note': 'UAT integration error investigation',
      },
      {
        'id': 2,
        'project_id': 2,
        'task_id': 21,
        'billable_value': 0,
        'start_minutes': 630,
        'end_minutes': 675,
        'note': 'Unverified returns review',
      },
      {
        'id': 3,
        'project_id': 3,
        'task_id': 31,
        'billable_value': 0,
        'start_minutes': 720,
        'end_minutes': 810,
        'note':
            'Captured follow-up notes for release readiness, stakeholder communication, and training updates.',
      },
    ],
  };
}

Map<String, dynamic> _buildWeekLayoutData() {
  return {
    'projects': const [
      {'id': 1, 'name': 'Project Atlas'},
    ],
    'rows': const [
      {
        'project_id': 1,
        'project_name': 'Project Atlas',
        'task_id': 2,
        'task_name': 'Client Workshop',
        'billable_value': 1,
        'day_minutes': [60, 30, 90, 0, 45, 0, 0],
        'day_note_lines': [
          ['Discovery'],
          ['Follow up'],
          ['Workshop'],
          <String>[],
          ['Friday wrap up'],
          <String>[],
          <String>[],
        ],
        'total_minutes': 225,
      },
      {
        'project_id': 1,
        'project_name': 'Project Atlas',
        'task_id': 3,
        'task_name':
            'Quarterly workflow resilience and release readiness review',
        'billable_value': 0,
        'day_minutes': [0, 0, 45, 60, 0, 0, 0],
        'day_note_lines': [
          <String>[],
          <String>[],
          ['Internal review'],
          ['Training prep'],
          <String>[],
          <String>[],
          <String>[],
        ],
        'total_minutes': 105,
      },
    ],
    'week_total_minutes': 330,
  };
}

Map<String, dynamic> _buildSetupSummaryLayoutData() {
  return {
    'projects': const [
      {'id': 1, 'name': 'Project Atlas'},
      {'id': 2, 'name': 'Project Bravo'},
      {'id': 3, 'name': 'Project Zero'},
    ],
    'tasks': const [
      {
        'id': 11,
        'project_id': 1,
        'project_name': 'Project Atlas',
        'name': 'Analysis',
      },
      {
        'id': 12,
        'project_id': 1,
        'project_name': 'Project Atlas',
        'name': 'Reporting',
      },
      {
        'id': 21,
        'project_id': 2,
        'project_name': 'Project Bravo',
        'name': 'Returns',
      },
      {
        'id': 31,
        'project_id': 3,
        'project_name': 'Project Zero',
        'name': 'Planning',
      },
    ],
    'summary_rows': const [
      {
        'kind': 'project',
        'entity_id': 1,
        'project_id': 1,
        'project_name': 'Project Atlas',
        'task_id': null,
        'task_name': null,
        'name': 'Project Atlas',
        'total_minutes': 150,
      },
      {
        'kind': 'task',
        'entity_id': 11,
        'project_id': 1,
        'project_name': 'Project Atlas',
        'task_id': 11,
        'task_name': 'Analysis',
        'name': 'Analysis',
        'total_minutes': 90,
      },
      {
        'kind': 'task',
        'entity_id': 12,
        'project_id': 1,
        'project_name': 'Project Atlas',
        'task_id': 12,
        'task_name': 'Reporting',
        'name': 'Reporting',
        'total_minutes': 60,
      },
      {
        'kind': 'project',
        'entity_id': 2,
        'project_id': 2,
        'project_name': 'Project Bravo',
        'task_id': null,
        'task_name': null,
        'name': 'Project Bravo',
        'total_minutes': 75,
      },
      {
        'kind': 'task',
        'entity_id': 21,
        'project_id': 2,
        'project_name': 'Project Bravo',
        'task_id': 21,
        'task_name': 'Returns',
        'name': 'Returns',
        'total_minutes': 75,
      },
      {
        'kind': 'project',
        'entity_id': 3,
        'project_id': 3,
        'project_name': 'Project Zero',
        'task_id': null,
        'task_name': null,
        'name': 'Project Zero',
        'total_minutes': 0,
      },
      {
        'kind': 'task',
        'entity_id': 31,
        'project_id': 3,
        'project_name': 'Project Zero',
        'task_id': 31,
        'task_name': 'Planning',
        'name': 'Planning',
        'total_minutes': 0,
      },
    ],
  };
}
