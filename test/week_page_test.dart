import 'package:clockwork/time_entry_formatting.dart';
import 'package:clockwork/week_page.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('clicking a weekday header opens the corresponding day', (
    tester,
  ) async {
    DateTime? openedDay;
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      FluentApp(
        home: WeekPage(
          initialSelectedDate: DateTime(2026, 4, 8),
          onOpenDay: (day) => openedDay = dateOnly(day),
          loadWeekPageData: (_) async => {
            'projects': [
              {'id': 1, 'name': 'Project Atlas'},
            ],
            'rows': [
              {
                'project_id': 1,
                'project_name': 'Project Atlas',
                'task_id': 2,
                'task_name': 'Client Workshop',
                'billable_value': 1,
                'day_minutes': [0, 0, 60, 30, 0, 0, 0],
                'day_note_lines': [
                  <String>[],
                  <String>[],
                  ['Discovery session'],
                  ['Follow up'],
                  <String>[],
                  <String>[],
                  <String>[],
                ],
                'total_minutes': 90,
              },
            ],
            'week_total_minutes': 90,
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Fri'));
    await tester.pumpAndSettle();

    expect(openedDay, dateOnly(DateTime(2026, 4, 10)));
  });

  testWidgets(
    'weekday headers and day total links use a click cursor and padded hover target',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        FluentApp(
          home: WeekPage(
            initialSelectedDate: DateTime(2026, 4, 8),
            onOpenDay: (_) {},
            loadWeekPageData: (_) async => {
              'projects': [
                {'id': 1, 'name': 'Project Atlas'},
              ],
              'rows': [
                {
                  'project_id': 1,
                  'project_name': 'Project Atlas',
                  'task_id': 2,
                  'task_name': 'Client Workshop',
                  'billable_value': 1,
                  'day_minutes': [0, 0, 60, 30, 0, 0, 0],
                  'day_note_lines': [
                    <String>[],
                    <String>[],
                    ['Discovery session'],
                    ['Follow up'],
                    <String>[],
                    <String>[],
                    <String>[],
                  ],
                  'total_minutes': 90,
                },
              ],
              'week_total_minutes': 90,
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      final headerMouseRegions = find
          .ancestor(of: find.text('Fri'), matching: find.byType(MouseRegion))
          .evaluate()
          .map((element) => element.widget as MouseRegion)
          .where((widget) => widget.cursor == SystemMouseCursors.click);
      expect(headerMouseRegions, isNotEmpty);

      final cellMouseRegions = find
          .ancestor(of: find.text('1h'), matching: find.byType(MouseRegion))
          .evaluate()
          .map((element) => element.widget as MouseRegion)
          .where((widget) => widget.cursor == SystemMouseCursors.click);
      expect(cellMouseRegions, isNotEmpty);

      final headerLink = tester.widget<HyperlinkButton>(
        find.ancestor(
          of: find.text('Fri'),
          matching: find.byType(HyperlinkButton),
        ),
      );
      final cellLink = tester.widget<HyperlinkButton>(
        find.ancestor(
          of: find.text('1h'),
          matching: find.byType(HyperlinkButton),
        ),
      );

      expect(
        headerLink.style?.padding?.resolve(<WidgetState>{}),
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      );
      expect(
        cellLink.style?.padding?.resolve(<WidgetState>{}),
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      );
    },
  );

  testWidgets(
    'clicking a day total copies notes, shows a clipboard hint, and copies again from the copy button',
    (tester) async {
      final clipboardWrites = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
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

      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        FluentApp(
          home: WeekPage(
            initialSelectedDate: DateTime(2026, 4, 8),
            onOpenDay: (_) {},
            loadWeekPageData: (_) async => {
              'projects': [
                {'id': 1, 'name': 'Project Atlas'},
              ],
              'rows': [
                {
                  'project_id': 1,
                  'project_name': 'Project Atlas',
                  'task_id': 2,
                  'task_name': 'Client Workshop',
                  'billable_value': 1,
                  'day_minutes': [0, 0, 75, 30, 0, 0, 0],
                  'day_note_lines': [
                    <String>[],
                    <String>[],
                    ['Discovery session', 'Follow up'],
                    ['Wrap up'],
                    <String>[],
                    <String>[],
                    <String>[],
                  ],
                  'total_minutes': 105,
                },
              ],
              'week_total_minutes': 105,
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('1h 15m').first);
      await tester.pumpAndSettle();

      expect(clipboardWrites, ['Discovery session\nFollow up']);
      expect(find.text('(notes added to clipboard)'), findsOneWidget);
      expect(find.byKey(const Key('weekNotesCopyButton')), findsOneWidget);

      final dialog = tester.widget<ContentDialog>(find.byType(ContentDialog));
      expect(dialog.constraints.maxWidth, 560);

      await tester.tap(find.text('Discovery session\nFollow up'));
      await tester.pumpAndSettle();

      expect(clipboardWrites, ['Discovery session\nFollow up']);

      await tester.tap(find.byKey(const Key('weekNotesCopyButton')));
      await tester.pumpAndSettle();

      expect(
        clipboardWrites,
        ['Discovery session\nFollow up', 'Discovery session\nFollow up'],
      );
    },
  );

  testWidgets('clicking outside the notes popup closes it', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            return null;
          }

          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      FluentApp(
        home: WeekPage(
          initialSelectedDate: DateTime(2026, 4, 8),
          onOpenDay: (_) {},
          loadWeekPageData: (_) async => {
            'projects': [
              {'id': 1, 'name': 'Project Atlas'},
            ],
            'rows': [
              {
                'project_id': 1,
                'project_name': 'Project Atlas',
                'task_id': 2,
                'task_name': 'Client Workshop',
                'billable_value': 1,
                'day_minutes': [0, 0, 75, 30, 0, 0, 0],
                'day_note_lines': [
                  <String>[],
                  <String>[],
                  ['Discovery session', 'Follow up'],
                  ['Wrap up'],
                  <String>[],
                  <String>[],
                  <String>[],
                ],
                'total_minutes': 105,
              },
            ],
            'week_total_minutes': 105,
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('1h 15m').first);
    await tester.pumpAndSettle();

    expect(find.byType(ContentDialog), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(ContentDialog), findsNothing);
  });
}
