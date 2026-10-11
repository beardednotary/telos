import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../models/guild_state.dart';
import '../services/backup.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/camp_controls.dart';
import '../widgets/expedition_widgets.dart';
import '../widgets/guild_sigil.dart';
import '../widgets/management_widgets.dart';
import 'guild_identity_sheet.dart';
import 'onboarding_screen.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, this.files = const BackupFiles()});
  final BackupFiles files;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<_BackupFile> _found = const [];
  String? _open;
  String? _loadError;
  String? _exportError;
  bool _loading = false;

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final files = await widget.files.available();
      final found = await Future.wait(files.map((file) async {
        try {
          final text = await widget.files.read(file);
          return _BackupFile(file, Backup.inspect(text), Backup.decode(text));
        } catch (_) {
          return _BackupFile(file, null, null);
        }
      }));
      if (mounted) setState(() => _found = found);
    } catch (_) {
      if (mounted) {
        setState(() {
          _found = [];
          _loadError = 'Could not read local backups. Try refreshing the list.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _exportError = null);
    try {
      await widget.files.export(context.read<GuildController>().g,
          sharePositionOrigin: origin);
      if (!mounted) return;
      campNotice(
          context, 'Backup written on this phone. Keep a copy outside Telos.');
    } catch (_) {
      if (mounted) {
        setState(() => _exportError =
            'Could not finish exporting. Check the local backups below before trying again.');
      }
    }
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final g = c.g;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & backup')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const Text('Your guild, on this phone.', style: T.display),
            const SizedBox(height: 8),
            Text('Saved locally. No account or cloud sync.',
                style: T.secondary),
            const SizedBox(height: 24),
            ExpeditionPanel(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GuildEmblem(sigil: g.guildSigil, size: 40),
                const SizedBox(height: 12),
                Text(g.guildName, style: T.title),
                const SizedBox(height: 6),
                Text(
                    'Guild level ${g.level} · ${expeditionCount(g.log.length)} in the log',
                    style: T.secondary),
                const SizedBox(height: 16),
                CampButton(
                  key: const Key('settings-identity'),
                  label: 'Edit guild name & sigil',
                  onPressed: () => showGuildIdentity(context, c),
                ),
              ],
            )),
            const SizedBox(height: 12),
            CampDisclosure(
              key: const Key('backup-disclosure'),
              title: 'Save & restore',
              summary: 'Export a copy or review a local backup',
              icon: Icons.save_outlined,
              expanded: _open == 'backup',
              onToggle: () {
                setState(() => _open = _open == 'backup' ? null : 'backup');
                if (_open == 'backup') _refresh();
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                          'Export your guild and focus history. Use the share sheet to keep a copy somewhere outside Telos.',
                          style: T.body),
                      const SizedBox(height: 16),
                      Builder(
                          builder: (buttonContext) => CampAction(
                                key: const Key('export-backup'),
                                label: 'Export a backup',
                                onPressed: () => _export(buttonContext),
                              )),
                      if (_exportError != null) ...[
                        const SizedBox(height: 12),
                        Text(_exportError!, style: T.secondary),
                      ],
                      const Divider(height: 32),
                      Text('LOCAL BACKUPS', style: T.label),
                      const SizedBox(height: 12),
                      Text(
                          'On iPhone, place a Telos backup in the Telos folder in Files, then refresh this list. Exported copies also appear here.',
                          style: T.secondary),
                      const SizedBox(height: 16),
                      if (_loading)
                        Text('Reading backups…', style: T.secondary)
                      else if (_loadError != null)
                        Text(_loadError!, style: T.secondary)
                      else if (_found.isEmpty)
                        Text('No backup files found.', style: T.secondary)
                      else
                        for (final backup in _found) ...[
                          ListTile(
                            key: Key('backup-${backup.name}'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(backup.info?.guild ?? backup.name,
                                style: T.body),
                            subtitle: Text(
                                backup.info == null
                                    ? 'Unreadable or unsupported Telos backup.'
                                    : 'Level ${backup.info!.level} · ${expeditionCount(backup.info!.expeditions)}\n'
                                        '${backup.info!.focusLabel} focus time\n${backup.name}',
                                style: T.secondary),
                            trailing: backup.info == null
                                ? null
                                : const Icon(Icons.chevron_right, color: T.dim),
                            onTap: backup.info == null || backup.state == null
                                ? null
                                : () => showCampSheet(
                                    context, _RestoreReview(backup: backup)),
                          ),
                          const Divider(height: 16),
                        ],
                      const SizedBox(height: 12),
                      CampButton(
                        key: const Key('refresh-backups'),
                        label: 'Refresh backups',
                        onPressed: _loading ? null : _refresh,
                      ),
                    ]),
              ),
            ),
            const SizedBox(height: 12),
            CampDisclosure(
              key: const Key('help-disclosure'),
              title: 'Help & about',
              summary: 'Field manual, privacy & licenses',
              icon: Icons.info_outline,
              expanded: _open == 'help',
              onToggle: () =>
                  setState(() => _open = _open == 'help' ? null : 'help'),
              child: Column(children: [
                CampLink(
                  key: const Key('settings-manual'),
                  title: 'Field manual',
                  detail: 'Focus, Integrity and repeat dispatches',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const OnboardingScreen(asReview: true))),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      'Your task notes and guild stay on this device unless you choose to export or share them. '
                      'Integrity measures time in Telos, not activity in other apps.',
                      style: T.secondary),
                ),
                CampLink(
                  key: const Key('settings-licenses'),
                  title: 'Open-source licenses',
                  detail: 'Fonts and software used in Telos',
                  onTap: () => showLicensePage(
                      context: context, applicationName: 'Telos'),
                ),
                const _BuildInfo(),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupFile {
  const _BackupFile(this.file, this.info, this.state);
  final File file;
  final BackupInfo? info;
  final GuildState? state;

  String get name => file.path.split(RegExp(r'[/\\]')).last;
}

class _RestoreReview extends StatelessWidget {
  const _RestoreReview({required this.backup});
  final _BackupFile backup;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final info = backup.info!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CampSheetHeader(title: 'Review restore'),
      const Text('Replace this guild?', style: T.display),
      const SizedBox(height: 12),
      const Text(
          'Restoring replaces the save on this phone. Export your current guild first if you want to keep it.',
          style: T.body),
      const SizedBox(height: 24),
      Text('ON THIS PHONE', style: T.label),
      const SizedBox(height: 8),
      Text(c.g.guildName, style: T.title),
      Text(
          'Level ${c.g.level} · ${expeditionCount(c.g.log.length)} · '
          '${c.g.totalFocusMinutes ~/ 60}h ${c.g.totalFocusMinutes % 60}m',
          style: T.secondary),
      const Divider(height: 32),
      Text('FROM THIS BACKUP', style: T.label),
      const SizedBox(height: 8),
      Text(info.guild, style: T.title),
      Text(
          'Level ${info.level} · ${expeditionCount(info.expeditions)} · ${info.focusLabel}',
          style: T.secondary),
      const SizedBox(height: 12),
      Text(backup.name, style: T.secondary),
      if (backup.state!.active != null ||
          backup.state!.pendingDebrief != null) ...[
        const SizedBox(height: 12),
        Text(
            'An in-progress session or pending return in this file will not reopen. Already-banked results are kept.',
            style: T.secondary),
      ],
      const SizedBox(height: 24),
      CampButton(
        label: 'Keep current guild',
        onPressed: () => Navigator.pop(context),
      ),
      const SizedBox(height: 12),
      CampAction(
        key: const Key('confirm-restore'),
        label: 'Replace guild with this backup',
        onPressed: () async {
          await c.restore(backup.state!);
          if (!context.mounted) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
          campNotice(context, '${info.guild} restored.');
        },
      ),
    ]);
  }
}

class _BuildInfo extends StatelessWidget {
  const _BuildInfo();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snap) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
              snap.hasData
                  ? 'Telos ${snap.data!.version} (${snap.data!.buildNumber})'
                  : 'Telos',
              style: T.secondary),
        ),
      );
}
