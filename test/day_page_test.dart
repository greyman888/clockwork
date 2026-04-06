import 'package:clockwork/day_page.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'new day-row project field auto-completes the first matching prefix',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        FluentApp(
          home: DayPage(
            initialDay: DateTime(2026, 4, 8),
            loadDayPageData: (_) async => _buildDayPageData(),
            saveDayEntry: (_) async {},
            deleteDayEntry: (_) async {},
            todayProvider: () => DateTime(2026, 4, 8),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final projectTextBoxFinder = find.descendant(
        of: find.byKey(const Key('dayNewRowProjectField')),
        matching: find.byType(TextBox),
      );

      await tester.tap(projectTextBoxFinder);
      await tester.pump();
      await tester.enterText(projectTextBoxFinder, 'a');
      await tester.pump();

      final projectTextBox = tester.widget<TextBox>(projectTextBoxFinder);
      final controller = projectTextBox.controller!;

      expect(controller.text, 'Adore');
      expect(controller.selection.start, 1);
      expect(controller.selection.end, 5);
    },
  );

  testWidgets(
    'new day-row project field keeps the suggested remainder selected as the prefix grows',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        FluentApp(
          home: DayPage(
            initialDay: DateTime(2026, 4, 8),
            loadDayPageData: (_) async => _buildDayPageData(),
            saveDayEntry: (_) async {},
            deleteDayEntry: (_) async {},
            todayProvider: () => DateTime(2026, 4, 8),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final projectTextBoxFinder = find.descendant(
        of: find.byKey(const Key('dayNewRowProjectField')),
        matching: find.byType(TextBox),
      );

      await tester.tap(projectTextBoxFinder);
      await tester.pump();
      await tester.enterText(projectTextBoxFinder, 'ad');
      await tester.pump();

      final projectTextBox = tester.widget<TextBox>(projectTextBoxFinder);
      final controller = projectTextBox.controller!;

      expect(controller.text, 'Adore');
      expect(controller.selection.start, 2);
      expect(controller.selection.end, 5);
    },
  );

  testWidgets(
    'new day-row task field auto-completes the first matching prefix for the selected project',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        FluentApp(
          home: DayPage(
            initialDay: DateTime(2026, 4, 8),
            loadDayPageData: (_) async => _buildDayPageData(),
            saveDayEntry: (_) async {},
            deleteDayEntry: (_) async {},
            todayProvider: () => DateTime(2026, 4, 8),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final projectTextBoxFinder = find.descendant(
        of: find.byKey(const Key('dayNewRowProjectField')),
        matching: find.byType(TextBox),
      );
      await tester.tap(projectTextBoxFinder);
      await tester.pump();
      await tester.enterText(projectTextBoxFinder, 'a');
      await tester.pump();

      final taskTextBoxFinder = find.descendant(
        of: find.byKey(const Key('dayNewRowTaskField')),
        matching: find.byType(TextBox),
      );
      await tester.tap(taskTextBoxFinder);
      await tester.pump();
      await tester.enterText(taskTextBoxFinder, 'e');
      await tester.pump();

      final taskTextBox = tester.widget<TextBox>(taskTextBoxFinder);
      final controller = taskTextBox.controller!;

      expect(controller.text, 'Error Proofing');
      expect(controller.selection.start, 1);
      expect(controller.selection.end, 14);
    },
  );

  testWidgets('new day-row requires a note before save is enabled', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      FluentApp(
        home: DayPage(
          initialDay: DateTime(2026, 4, 8),
          loadDayPageData: (_) async => _buildDayPageData(),
          saveDayEntry: (_) async {},
          deleteDayEntry: (_) async {},
          todayProvider: () => DateTime(2026, 4, 8),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _populateNewRowRequiredFields(tester);

    var saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('dayNewRowSaveButton')),
    );
    expect(saveButton.onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('dayNewRowNoteField')),
      'UAT integration investigation',
    );
    await tester.pump();

    saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('dayNewRowSaveButton')),
    );
    expect(saveButton.onPressed, isNotNull);
  });

  testWidgets('pressing enter in the note field saves the new row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final savedRequests = <DayPageSaveRequest>[];

    await tester.pumpWidget(
      FluentApp(
        home: DayPage(
          initialDay: DateTime(2026, 4, 8),
          loadDayPageData: (_) async => _buildDayPageData(),
          saveDayEntry: (request) async => savedRequests.add(request),
          deleteDayEntry: (_) async {},
          todayProvider: () => DateTime(2026, 4, 8),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _populateNewRowRequiredFields(tester);
    await tester.tap(find.byKey(const Key('dayNewRowNoteField')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('dayNewRowNoteField')),
      'UAT integration investigation',
    );
    await tester.pump();

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(savedRequests, hasLength(1));
    expect(savedRequests.single.projectId, 1);
    expect(savedRequests.single.taskId, 11);
    expect(savedRequests.single.startMinutes, 9 * 60);
    expect(savedRequests.single.endMinutes, 10 * 60 + 15);
    expect(savedRequests.single.note, 'UAT integration investigation');
  });
}

Future<void> _populateNewRowRequiredFields(WidgetTester tester) async {
  final projectTextBoxFinder = find.descendant(
    of: find.byKey(const Key('dayNewRowProjectField')),
    matching: find.byType(TextBox),
  );

  await tester.tap(projectTextBoxFinder);
  await tester.pump();
  await tester.enterText(projectTextBoxFinder, 'a');
  await tester.pump();

  await tester.enterText(
    find.byKey(const Key('dayNewRowStartHourField')),
    '09',
  );
  await tester.pump();
  await tester.enterText(
    find.byKey(const Key('dayNewRowStartMinuteField')),
    '00',
  );
  await tester.pump();
  await tester.enterText(find.byKey(const Key('dayNewRowEndHourField')), '10');
  await tester.pump();
  await tester.enterText(
    find.byKey(const Key('dayNewRowEndMinuteField')),
    '15',
  );
  await tester.pump();
}

Map<String, dynamic> _buildDayPageData() {
  return {
    'projects': const [
      {'id': 1, 'name': 'Adore'},
      {'id': 2, 'name': 'Koorong'},
    ],
    'tasks': const [
      {'id': 11, 'project_id': 1, 'name': 'UAT Support'},
      {'id': 12, 'project_id': 1, 'name': 'Error Proofing'},
      {'id': 21, 'project_id': 2, 'name': 'Returns'},
    ],
    'entries': const <Map<String, dynamic>>[],
  };
}
