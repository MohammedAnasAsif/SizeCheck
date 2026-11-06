import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:size_engine/size_engine.dart';

import '../app_state.dart';

/// Switch between people, add one, rename, export or import.
class ProfileMenuButton extends StatelessWidget {
  const ProfileMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final active = state.active;
    return PopupMenuButton<String>(
      tooltip: 'Profiles',
      onSelected: (v) => _handle(context, v),
      itemBuilder: (context) => [
        for (final p in state.profiles)
          CheckedPopupMenuItem(
            value: 'switch:${p.id}',
            checked: p.id == active.id,
            child: Text(p.name),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'add', child: Text('Add a person')),
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(value: 'export', child: Text('Copy profile code')),
        const PopupMenuItem(value: 'import', child: Text('Import profile code')),
        if (state.profiles.length > 1)
          const PopupMenuItem(value: 'delete', child: Text('Delete this profile')),
      ],
      child: Chip(
        avatar: const Icon(Icons.person_outline, size: 18),
        label: Text(active.name),
      ),
    );
  }

  Future<void> _handle(BuildContext context, String v) async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    if (v.startsWith('switch:')) {
      final id = v.substring(7);
      state.setActive(state.profiles.firstWhere((p) => p.id == id));
    } else if (v == 'add') {
      final name = await _ask(context, 'Add a person', 'Name', '');
      if (name != null && name.isNotEmpty) state.addProfile(name);
    } else if (v == 'rename') {
      final name =
          await _ask(context, 'Rename profile', 'Name', state.active.name);
      if (name != null && name.isNotEmpty) {
        state.active.name = name;
        state.changed();
      }
    } else if (v == 'export') {
      await Clipboard.setData(ClipboardData(text: state.active.toExportCode()));
      messenger.showSnackBar(const SnackBar(
          content: Text('Profile code copied. Paste it into SizeCheck on '
              'another device with "Import profile code".')));
    } else if (v == 'import') {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      if (!context.mounted) return;
      final code = await _ask(
          context, 'Import profile code', 'Paste the code', clip?.text ?? '',
          multiline: true);
      if (code == null) return;
      final p = BodyProfile.fromExportCode(code, newId: AppState.newId());
      if (p == null) {
        messenger.showSnackBar(
            const SnackBar(content: Text('That is not a SizeCheck profile code.')));
      } else {
        state.importProfile(p);
        messenger.showSnackBar(SnackBar(content: Text('Imported ${p.name}.')));
      }
    } else if (v == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete ${state.active.name}?'),
          content: const Text('Their measurements and fit history will be '
              'removed from this device.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete')),
          ],
        ),
      );
      if (ok == true) state.deleteProfile(state.active);
    }
  }

  static Future<String?> _ask(
      BuildContext context, String title, String label, String initial,
      {bool multiline = false}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: multiline ? 4 : 1,
          decoration: InputDecoration(labelText: label),
          onSubmitted: multiline
              ? null
              : (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
  }
}
