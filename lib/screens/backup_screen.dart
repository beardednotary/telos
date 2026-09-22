import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/backup.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/flash.dart';
import '../widgets/terminal.dart';

/// Getting the guild out of the phone, and back into it.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<File> _found = const [];
  bool _looked = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final files = await Backup.available();
    if (!mounted) return;
    setState(() {
      _found = files;
      _looked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final g = c.g;
    final mins = g.totalFocusMinutes;

    return TerminalScaffold(
      title: 'SAVE DATA',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Container(
            color: T.band,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('THIS PHONE', style: T.micro),
                const SizedBox(height: 8),
                Text(g.guildName, style: T.title.copyWith(fontSize: 20)),
                const SizedBox(height: 10),
                Text(
                  'LEVEL ${g.level}   //   ${g.log.length} EXPEDITIONS   //   '
                  '${mins ~/ 60}h ${mins % 60}m PROTECTED',
                  style: T.micro.copyWith(letterSpacing: 0.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Everything lives on this phone and nothing is sent anywhere. '
              'That means a backup is the only thing standing between a '
              'deleted app and the whole record of what you have protected.',
              style: T.micro.copyWith(letterSpacing: 0.4, height: 1.7),
            ),
          ),
          const SizedBox(height: 22),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                await Backup.export(c.g);
                await _refresh();
                if (!context.mounted) return;
                showFlash(
                  context,
                  kicker: 'EXPORTED',
                  title: 'Backup written',
                  lines: const ['Keep it somewhere that is not this phone'],
                  color: T.amber,
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: T.amber.withValues(alpha: 0.12),
                  border: Border.all(color: T.amber, width: 1.4),
                ),
                child: Text('EXPORT A BACKUP',
                    style: T.mono.copyWith(
                        color: T.amber,
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 3)),
              ),
            ),
          ),

          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              children: [
                Text('RESTORE', style: T.micro.copyWith(color: T.steel)),
                const SizedBox(width: 12),
                Expanded(child: Container(height: 1, color: T.line)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text(
              'Put a backup file into the Telos folder in the Files app and it '
              'will appear here.',
              style: T.micro.copyWith(letterSpacing: 0.4, height: 1.7),
            ),
          ),

          if (!_looked)
            const SizedBox.shrink()
          else if (_found.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('No backup files found.',
                  style: T.micro.copyWith(letterSpacing: 0.4)),
            )
          else
            for (final f in _found) _RestoreBand(file: f, onDone: _refresh),
        ],
      ),
    );
  }
}

class _RestoreBand extends StatelessWidget {
  const _RestoreBand({required this.file, required this.onDone});
  final File file;
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    final c = context.read<GuildController>();
    final text = file.readAsStringSync();
    final info = Backup.inspect(text);
    final name = file.path.split(RegExp(r'[/\\]')).last;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      color: T.band,
      padding: const EdgeInsets.fromLTRB(0, 14, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 4, height: 40, color: info == null ? T.bad : T.steel),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: T.mono.copyWith(fontSize: 12, letterSpacing: 0.4)),
                const SizedBox(height: 5),
                Text(
                  info == null
                      ? 'NOT A TELOS BACKUP'
                      : '${info.guild}   //   LV ${info.level}   //   '
                          '${info.expeditions} RUNS   //   ${info.focusLabel}',
                  style: T.micro.copyWith(
                      color: info == null ? T.bad : T.dim, letterSpacing: 0.6),
                ),
              ],
            ),
          ),
          if (info != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final restored = Backup.decode(text);
                if (restored == null) return;
                final ok = await _confirm(context, c, info);
                if (ok != true) return;
                await c.restore(restored);
                await onDone();
                if (!context.mounted) return;
                showFlash(
                  context,
                  kicker: 'RESTORED',
                  title: restored.guildName,
                  lines: [
                    'LV ${restored.level}, ${restored.log.length} expeditions'
                  ],
                  color: T.good,
                  heavy: true,
                );
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text('RESTORE',
                    style: T.mono.copyWith(
                        fontSize: 11, letterSpacing: 2, color: T.good)),
              ),
            ),
        ],
      ),
    );
  }

  Future<bool?> _confirm(
    BuildContext context,
    GuildController c,
    BackupInfo info,
  ) {
    final mins = c.g.totalFocusMinutes;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: T.card,
        shape: const Border.fromBorderSide(BorderSide(color: T.line)),
        title: Text('REPLACE THIS GUILD?',
            style: T.mono.copyWith(fontSize: 15, letterSpacing: 1.5)),
        content: Text(
          'Restoring overwrites what is on this phone. You would lose '
          '${c.g.guildName} at level ${c.g.level}, ${c.g.log.length} '
          'expeditions and ${mins ~/ 60}h ${mins % 60}m of protected time, '
          'and take on ${info.guild} at level ${info.level} instead.\n\n'
          'Export first if you are not certain.',
          style: T.mono.copyWith(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('KEEP MINE',
                style: T.mono.copyWith(color: T.amber, fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('RESTORE',
                style: T.mono.copyWith(color: T.bad, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
