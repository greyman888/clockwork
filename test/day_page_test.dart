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
}

Map<String, dynamic> _buildDayPageData() {
  return {
    'projects': const [
      {'id': 1, 'name': 'Adore'},
      {'id': 2, 'name': 'Koorong'},
    ],
    'tasks': const [
      {'id': 11, 'project_id': 1, 'name': 'UAT Support'},
      {'id': 21, 'project_id': 2, 'name': 'Returns'},
    ],
    'entries': const <Map<String, dynamic>>[],
  };
}
