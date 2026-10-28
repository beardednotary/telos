import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/backup.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/camp_controls.dart';

/// Shown once, before anything else, when the saved guild could not be read.
///
/// The app has already started a new guild underneath, because the other
/// choice is not opening at all. What this screen owes the player is the
/// truth: the old save was not thrown away, and they can take a copy of it
/// out of the app before carrying on.
class UnreadableSaveScreen extends StatefulWidget {
  const UnreadableSaveScreen({super.key, this.files = const BackupFiles()});
  final BackupFiles files;

  @override
  State<UnreadableSaveScreen> createState() => _UnreadableSaveScreenState();
}

class _UnreadableSaveScreenState extends State<UnreadableSaveScreen> {
  String? _error;
  bool _saved = false;

  Future<void> _export(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final raw = context.read<GuildController>().unreadableSave;
    if (raw == null) return;
    setState(() => _error = null);
    try {
      await widget.files.exportUnreadable(raw, sharePositionOrigin: origin);
      if (mounted) setState(() => _saved = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save a copy. The old save is '
            'still kept on this phone. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<GuildController>();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text('SAVE KEPT', style: T.label.copyWith(color: T.amber)),
            const SizedBox(height: 12),
            Text('Your guild could not be opened.',
                style: T.display.copyWith(fontSize: 34)),
            const SizedBox(height: 20),
            const Text(
                'Part of the saved guild on this phone was unreadable, so '
                'Telos has started a new one.',
                style: T.body),
            const SizedBox(height: 16),
            const Text(
                'The old save has not been deleted. It is kept on this phone '
                'exactly as it was. Save a copy somewhere safe so it can be '
                'repaired.',
                style: T.body),
            const SizedBox(height: 16),
            Text(
                'If you exported a backup earlier, you can restore it from '
                'Settings.',
                style: T.secondary),
            const SizedBox(height: 28),
            Builder(
              builder: (b) => CampButton(
                key: const Key('unreadable-export'),
                label: _saved ? 'Save another copy' : 'Save a copy',
                primary: !_saved,
                onPressed: () => _export(b),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  key: const Key('unreadable-error'), style: T.secondary),
            ],
            const SizedBox(height: 8),
            CampButton(
              key: const Key('unreadable-continue'),
              label: 'Continue with a new guild',
              primary: _saved,
              onPressed: c.dismissUnreadableSave,
            ),
          ],
        ),
      ),
    );
  }
}
