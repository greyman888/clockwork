import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'db_helper.dart';
import 'definitions_page.dart';
import 'entities_page.dart';

const _lightShellColor = Color(0xFFF3F3F3);
const _darkShellColor = Color(0xFF202020);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await dbHelper.db;

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

  void _changeSection(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() => _selectedIndex = index);
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
              icon: const Icon(FluentIcons.home),
              title: const Text('Welcome'),
              body: ClockworkWelcomePage(
                onOpenDefinitions: () => _changeSection(1),
                onOpenEntities: () => _changeSection(2),
              ),
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
          ],
        ),
      ),
    );
  }
}

class ClockworkWelcomePage extends StatelessWidget {
  const ClockworkWelcomePage({
    required this.onOpenDefinitions,
    required this.onOpenEntities,
    super.key,
  });

  final VoidCallback onOpenDefinitions;
  final VoidCallback onOpenEntities;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('Welcome to Clockwork')),
      children: [
        Card(
          backgroundColor: theme.accentColor.lightest.withAlpha(
            theme.brightness == Brightness.dark ? 22 : 120,
          ),
          borderColor: theme.accentColor.normal.withAlpha(
            theme.brightness == Brightness.dark ? 64 : 120,
          ),
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final intro = _WelcomeIntro(
                onOpenDefinitions: onOpenDefinitions,
                onOpenEntities: onOpenEntities,
              );
              final summary = const _WelcomeSummaryCard();

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: intro),
                    const SizedBox(width: 24),
                    SizedBox(width: 300, child: summary),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [intro, const SizedBox(height: 24), summary],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: const [
            SizedBox(
              width: 320,
              child: _FeatureCard(
                icon: FluentIcons.database,
                title: 'Static Schema, Flexible Data',
                description:
                    'Define new business objects and fields as data, not '
                    'new tables and migrations.',
              ),
            ),
            SizedBox(
              width: 320,
              child: _FeatureCard(
                icon: FluentIcons.page_list,
                title: 'Reusable CRUD Screens',
                description:
                    'The goal is to build once and reuse forms across '
                    'entity kinds and their component values.',
              ),
            ),
            SizedBox(
              width: 320,
              child: _FeatureCard(
                icon: FluentIcons.sync,
                title: 'Fast Local Access',
                description:
                    'Typed component tables keep reads simple and targeted '
                    'for a small, desktop-first SQLite workflow.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What this starter already establishes',
                style: theme.typography.subtitle,
              ),
              const SizedBox(height: 12),
              const _ChecklistLine(
                text: 'Windows-first Fluent UI shell with a navigation pane.',
              ),
              const _ChecklistLine(
                text:
                    'SQLite database opens during startup so the app is ready early.',
              ),
              const _ChecklistLine(
                text:
                    'The welcome screen now frames the project goals and next areas to build.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WelcomeIntro extends StatelessWidget {
  const _WelcomeIntro({
    required this.onOpenDefinitions,
    required this.onOpenEntities,
  });

  final VoidCallback onOpenDefinitions;
  final VoidCallback onOpenEntities;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A Windows-first workspace for schema-stable business data.',
          style: theme.typography.titleLarge,
        ),
        const SizedBox(height: 12),
        Text(
          'Clockwork is set up to manage entity kinds, component kinds, and '
          'entity records without constant schema churn. The starter now has '
          'a Fluent shell and a landing page that can grow into the rest of '
          'the app.',
          style: theme.typography.bodyLarge,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: onOpenDefinitions,
              child: const Text('Open Definitions'),
            ),
            Button(
              onPressed: onOpenEntities,
              child: const Text('Open Entities'),
            ),
          ],
        ),
      ],
    );
  }
}

class _WelcomeSummaryCard extends StatelessWidget {
  const _WelcomeSummaryCard();

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Card(
      backgroundColor: theme.cardColor.withAlpha(
        theme.brightness == Brightness.dark ? 200 : 245,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Starter profile', style: theme.typography.subtitle),
          const SizedBox(height: 12),
          const _SummaryRow(label: 'Platform', value: 'Windows desktop'),
          const _SummaryRow(label: 'Storage', value: 'SQLite via sqflite ffi'),
          const _SummaryRow(
            label: 'UI direction',
            value: 'Fluent Windows theme',
          ),
          const _SummaryRow(
            label: 'Project focus',
            value: 'Simple, local, single-user',
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.typography.caption),
          const SizedBox(height: 2),
          Text(value, style: theme.typography.bodyStrong),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: theme.accentColor.normal),
          const SizedBox(height: 14),
          Text(title, style: theme.typography.subtitle),
          const SizedBox(height: 8),
          Text(description, style: theme.typography.body),
        ],
      ),
    );
  }
}

class _ChecklistLine extends StatelessWidget {
  const _ChecklistLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              FluentIcons.accept,
              size: 14,
              color: theme.accentColor.normal,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.typography.body)),
        ],
      ),
    );
  }
}
