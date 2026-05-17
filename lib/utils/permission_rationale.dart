import 'package:flutter/material.dart';

/// Pre-prompt the user with an in-app explanation before triggering the
/// OS permission dialog. Returns true if the user agrees to proceed.
///
/// Pass [whyText] explaining what the app does with the permission — not
/// what the permission is (the OS dialog already names it).
Future<bool> askPermissionRationale(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String whyText,
  String continueLabel = 'Continue',
  String cancelLabel = 'Not now',
}) async {
  final scheme = Theme.of(context).colorScheme;
  final go = await showDialog<bool>(
    context: context,
    builder: (dCtx) => AlertDialog(
      icon: Icon(icon, size: 36, color: scheme.primary),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(whyText),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dCtx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dCtx, true),
          child: Text(continueLabel),
        ),
      ],
    ),
  );
  return go ?? false;
}
