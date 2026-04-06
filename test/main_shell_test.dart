import 'package:clockwork/main.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ClockworkShell shows developer pages in development mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      const FluentApp(
        home: ClockworkShell(showDeveloperPages: true, showUiPreview: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Setup and Summary'), findsOneWidget);
    expect(find.text('Definitions'), findsOneWidget);
    expect(find.text('Entities'), findsOneWidget);
    expect(find.text('Preview'), findsNothing);
  });

  testWidgets('ClockworkShell hides developer pages in release-style mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      const FluentApp(
        home: ClockworkShell(showDeveloperPages: false, showUiPreview: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Setup and Summary'), findsOneWidget);
    expect(find.text('Definitions'), findsNothing);
    expect(find.text('Entities'), findsNothing);
    expect(find.text('Preview'), findsNothing);
  });
}
