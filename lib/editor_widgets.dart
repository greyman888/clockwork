import 'package:fluent_ui/fluent_ui.dart';

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    required this.title,
    required this.description,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    required this.onRefresh,
    super.key,
  });

  final String title;
  final String description;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.typography.subtitle),
              const SizedBox(height: 6),
              Text(description, style: theme.typography.body),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Button(onPressed: onRefresh, child: const Text('Refresh')),
            FilledButton(
              onPressed: onPrimaryAction,
              child: Text(primaryActionLabel),
            ),
          ],
        ),
      ],
    );
  }
}

class EditorHeading extends StatelessWidget {
  const EditorHeading({
    required this.title,
    required this.statusLabel,
    required this.isActive,
    super.key,
  });

  final String title;
  final String statusLabel;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      children: [
        Expanded(child: Text(title, style: theme.typography.bodyStrong)),
        StatusPill(label: statusLabel, isActive: isActive),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.label, required this.isActive, super.key});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isActive
        ? Colors.successPrimaryColor.withAlpha(35)
        : Colors.warningPrimaryColor.withAlpha(40);
    final foregroundColor = isActive
        ? Colors.successPrimaryColor
        : Colors.warningPrimaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: foregroundColor, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class LabeledTextBox extends StatelessWidget {
  const LabeledTextBox({
    required this.label,
    required this.controller,
    required this.placeholder,
    this.header,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String placeholder;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return InfoLabel(
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[header!, const SizedBox(height: 6)],
          TextBox(controller: controller, placeholder: placeholder),
        ],
      ),
    );
  }
}

class LabeledComboBox<T> extends StatelessWidget {
  const LabeledComboBox({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 260,
    super.key,
  });

  final String label;
  final T? value;
  final List<ComboBoxItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return InfoLabel(
      label: label,
      child: SizedBox(
        width: width,
        child: ComboBox<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
        ),
      ),
    );
  }
}
