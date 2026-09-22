import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/guild_state.dart';

/// Getting a save out of the app, and back in.
///
/// The whole save is one SharedPreferences blob. iOS includes it in device
/// backups, so a restored phone keeps its guild - but deleting the app, or
/// moving to a phone without a backup, takes months of protected time with it.
/// This is the escape hatch.
///
/// Export goes through the share sheet, so it can land in Files, iCloud, a
/// message, anywhere. Import reads from the app's own Documents folder, which
/// is visible in the Files app under "Telos" - drop a backup there and it
/// appears in the list. That avoids a file-picker plugin, which is native code
/// that cannot be tested from a Windows machine.
class Backup {
  static const _prefix = 'telos-backup-';

  /// A stable, human-readable name so a folder of these is sortable.
  static String fileNameFor(DateTime when) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '$_prefix${when.year}-${two(when.month)}-${two(when.day)}'
        '-${two(when.hour)}${two(when.minute)}.json';
  }

  /// Wraps the save with enough context to recognise it later.
  static String encode(GuildState g, {DateTime? when}) {
    final t = when ?? DateTime.now();
    return const JsonEncoder.withIndent('  ').convert({
      'telos': 1,
      'exportedAt': t.toIso8601String(),
      'summary': {
        'guild': g.guildName,
        'level': g.level,
        'expeditions': g.log.length,
        'focusMinutes': g.totalFocusMinutes,
        'installedAt': g.installedAt?.toIso8601String(),
        'appOpens': g.appOpens,
        'daysActive': g.daysActive,
        'manualSeenAt': g.manualSeenAt?.toIso8601String(),
        'manualDoneAt': g.manualDoneAt?.toIso8601String(),
      },
      'save': g.toJson(),
    });
  }

  /// Returns null when the text is not a Telos backup, rather than throwing -
  /// the caller is a UI action and a bad file should be a message, not a crash.
  static GuildState? decode(String text) {
    try {
      final j = jsonDecode(text);
      if (j is! Map<String, dynamic>) return null;
      final save = j['save'];
      if (save is! Map<String, dynamic>) return null;
      final state = GuildState.fromJson(save);
      // A save with no roster is not a save worth restoring over a live one.
      if (state.roster.isEmpty) return null;
      return state;
    } catch (_) {
      return null;
    }
  }

  /// Reads the headline numbers without committing to a restore.
  static BackupInfo? inspect(String text) {
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      final s = (j['summary'] as Map?) ?? const {};
      return BackupInfo(
        guild: s['guild'] as String? ?? 'UNKNOWN',
        level: s['level'] as int? ?? 0,
        expeditions: s['expeditions'] as int? ?? 0,
        focusMinutes: s['focusMinutes'] as int? ?? 0,
        exportedAt: DateTime.tryParse(j['exportedAt'] as String? ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Directory> documents() => getApplicationDocumentsDirectory();

  /// Writes a backup into Documents and offers it to the share sheet.
  static Future<String> export(GuildState g) async {
    final dir = await documents();
    final file = File('${dir.path}/${fileNameFor(DateTime.now())}');
    await file.writeAsString(encode(g));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Telos backup',
      ),
    );
    return file.path;
  }

  /// Backups sitting in the app's Documents folder, newest first.
  static Future<List<File>> available() async {
    final dir = await documents();
    if (!dir.existsSync()) return [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) =>
            f.path.endsWith('.json') && f.path.contains(_prefix))
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }
}

class BackupInfo {
  const BackupInfo({
    required this.guild,
    required this.level,
    required this.expeditions,
    required this.focusMinutes,
    this.exportedAt,
  });

  final String guild;
  final int level;
  final int expeditions;
  final int focusMinutes;
  final DateTime? exportedAt;

  String get focusLabel => '${focusMinutes ~/ 60}h ${focusMinutes % 60}m';
}
