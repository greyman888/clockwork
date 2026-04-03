import 'package:fluent_ui/fluent_ui.dart';

Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return ContentDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          Button(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  return result ?? false;
}

Future<void> showNoticeDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return ContentDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

int? resolveSelectedId({
  required List<Map<String, dynamic>> items,
  required int? explicitSelection,
  required int? currentSelection,
}) {
  final availableIds = items.map((item) => item['id'] as int).toSet();

  if (explicitSelection != null && availableIds.contains(explicitSelection)) {
    return explicitSelection;
  }

  if (currentSelection != null && availableIds.contains(currentSelection)) {
    return currentSelection;
  }

  if (items.isEmpty) {
    return null;
  }

  return items.first['id'] as int;
}
