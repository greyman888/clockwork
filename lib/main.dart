import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app_db.dart';
import 'day_page.dart';
import 'definitions_page.dart';
import 'entities_page.dart';
import 'time_entry_formatting.dart';
import 'ui_preview_page.dart';
import 'week_page.dart';

const _lightShellColor = Color(0xFFF3F3F3);
const _darkShellColor = Color(0xFF202020);
const _uiPreviewEnabled =
    !kReleaseMode && bool.fromEnvironment('CLOCKWORK_UI_PREVIEW');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await dbHelper.ensureRequiredDefinitions();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'Clockwork',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      color: Colors.blue,
      theme: FluentThemeData(
        brightness: Brightness.light,
        accentColor: Colors.blue,
        visualDensity: VisualDensity.standard,
        scaffoldBackgroundColor: _lightShellColor,
      ),
      darkTheme: FluentThemeData(
        brightness: Brightness.dark,
        accentColor: Colors.blue,
        visualDensity: VisualDensity.standard,
        scaffoldBackgroundColor: _darkShellColor,
      ),
      home: const ClockworkShell(),
    );
  }
}

class ClockworkShell extends StatefulWidget {
  const ClockworkShell({super.key});

  @override
  State<ClockworkShell> createState() => _ClockworkShellState();
}

class _ClockworkShellState extends State<ClockworkShell> {
  int _selectedIndex = 0;
  DateTime _dayPageInitialDay = dateOnly(DateTime.now());
  int _dayPageNavigationRevision = 0;

  void _changeSection(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() => _selectedIndex = index);
  }

  void _openDay([DateTime? day]) {
    if (day != null) {
      _dayPageInitialDay = dateOnly(day);
      _dayPageNavigationRevision += 1;
    }

    _changeSection(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final shellBackgroundColor = theme.scaffoldBackgroundColor;

    return NavigationPaneTheme(
      data: NavigationPaneThemeData(
        animationDuration: Duration(milliseconds: 240),
        animationCurve: Curves.easeOut,
        backgroundColor: shellBackgroundColor,
      ),
      child: NavigationView(
        transitionBuilder: (child, animation) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          );
          return FadeTransition(opacity: curvedAnimation, child: child);
        },
        contentShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide.none,
        ),
        pane: NavigationPane(
          selected: _selectedIndex,
          onChanged: _changeSection,
          displayMode: PaneDisplayMode.expanded,
          toggleButton: null,
          size: const NavigationPaneSize(openWidth: 280),
          items: [
            PaneItem(
              icon: const Icon(FluentIcons.calendar_day),
              title: const Text('Day'),
              body: DayPage(
                key: ValueKey(_dayPageNavigationRevision),
                initialDay: _dayPageInitialDay,
              ),
            ),
            PaneItem(
              icon: const Icon(FluentIcons.calendar_week),
              title: const Text('Week'),
              body: WeekPage(onOpenDay: _openDay),
            ),
            PaneItem(
              icon: const Icon(FluentIcons.database),
              title: const Text('Definitions'),
              body: const DefinitionsPage(),
            ),
            PaneItem(
              icon: const Icon(FluentIcons.task_manager),
              title: const Text('Entities'),
              body: const EntitiesPage(),
            ),
            if (_uiPreviewEnabled)
              PaneItem(
                icon: const Icon(FluentIcons.design),
                title: const Text('Preview'),
                body: const UiPreviewPage(),
              ),
          ],
        ),
      ),
    );
  }
}
