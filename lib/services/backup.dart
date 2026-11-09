import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/content.dart';
import '../models/guild_state.dart';
import '../models/models.dart';

/// Getting a save out of the app, and back in.
///
/// The whole save is one SharedPreferences blob. iOS includes it in device
/// backups, so a restored phone keeps its guild - but deleting the app, or
/// moving to a phone without a backup, takes months of protected time with it.
/// This is the escape hatch.
///
/// Export goes through the share sheet, so it can land in Files, iCloud, a
/// message, anywhere. Import lists what is in the app's own Documents folder
/// (On My iPhone > Telos in the Files app, subfolders included), and the
/// system file picker reaches everywhere else. The list alone was not
/// enough: a tester saved a backup to a "Telos" folder of their own and the
/// app could not see it.
///
/// Files are recognised by what is in them, not what they are called, so a
/// renamed or duplicated backup ("... 2.json") still turns up.
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
        'expeditions': g.expeditions,
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
      if (j['telos'] != 1) return null;
      final save = j['save'];
      if (save is! Map<String, dynamic>) return null;
      if (save['v'] != 1) return null;
      final state = GuildState.fromJson(save);
      // A save with no roster is not a save worth restoring over a live one.
      if (state.roster.isEmpty) return null;
      if (!_holdsTogether(state)) return null;
      return state;
    } catch (_) {
      return null;
    }
  }

  /// Whether every name in [s] is one this build knows, and every piece of
  /// it points at something that exists.
  ///
  /// A backup is plain JSON. It can be hand-edited, or written by a later
  /// version with gear this one has never heard of, and the screens look
  /// content up directly: an unknown gear id restores without complaint and
  /// then crashes the first screen that draws it. Refusing the file leaves
  /// the working guild alone, which is the whole job of a restore check.
  ///
  /// A live or pending run is not checked, because `GuildController.restore`
  /// throws both away.
  static bool _holdsTogether(GuildState s) {
    if (s.level < 1 || s.xp < 0) return false;
    if (s.credits < 0 || s.alloy < 0 || s.intel < 0) return false;
    if (s.facilities.values.any((l) => l < 1)) return false;

    final sectors = {for (final sector in kSectors) sector.id};
    if (!s.unlockedSectors.every(sectors.contains)) return false;

    final gear = <String>{};
    for (final g in s.vault) {
      if (!kGear.containsKey(g.defId) || !gear.add(g.uid)) return false;
    }

    final members = <String>{};
    final worn = <String>{};
    for (final m in s.roster) {
      if (!members.add(m.id) || !kClasses.containsKey(m.classId)) return false;
      if (m.level < 1 || m.xp < 0) return false;
      if (m.equipped.length > kGearSlots) return false;
      for (final uid in m.equipped) {
        // Equipped gear has to be in the vault, and on one member at a time.
        if (!gear.contains(uid) || !worn.add(uid)) return false;
      }
    }

    if (!s.log.every((r) => sectors.contains(r.sectorId))) return false;

    for (final c in s.contracts) {
      if (c.sectorId != null && !sectors.contains(c.sectorId)) return false;
      if (c.classId != null && !kClasses.containsKey(c.classId)) return false;
      if (c.gearDefId != null && !kGear.containsKey(c.gearDefId)) return false;
      // The board's wording needs these for the kinds that name them.
      final ok = switch (c.kind) {
        ContractKind.sectorRuns ||
        ContractKind.fullDepth ||
        ContractKind.sectorReturn =>
          c.sectorId != null,
        ContractKind.haul => c.sectorId != null && c.res != null,
        ContractKind.carryGear => c.sectorId != null && c.gearDefId != null,
        ContractKind.classRuns => c.classId != null,
        _ => true,
      };
      if (!ok) return false;
    }
    return true;
  }

  /// Reads the headline numbers without committing to a restore.
  static BackupInfo? inspect(String text) {
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      final state = decode(text);
      if (state == null) return null;
      // The review must describe what will actually be restored, not a
      // separately editable or stale summary from the file wrapper.
      return BackupInfo(
        guild: state.guildName,
        level: state.level,
        expeditions: state.expeditions,
        focusMinutes: state.totalFocusMinutes,
        exportedAt: DateTime.tryParse(j['exportedAt'] as String? ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Directory> documents() => getApplicationDocumentsDirectory();

  /// Writes a backup into Documents and offers it to the share sheet.
  static Future<String> export(GuildState g,
      {Rect? sharePositionOrigin}) async {
    final dir = await documents();
    final file = File('${dir.path}/${fileNameFor(DateTime.now())}');
    await file.writeAsString(encode(g));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Telos backup',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    return file.path;
  }

  /// Offers a save Telos could not read to the share sheet, byte for byte as
  /// it was found, so it can be kept somewhere safe or sent off for repair.
  static Future<String> exportUnreadable(String raw,
      {Rect? sharePositionOrigin}) async {
    final dir = await documents();
    final name = fileNameFor(DateTime.now())
        .replaceFirst(_prefix, 'telos-unreadable-save-');
    final file = File('${dir.path}/$name');
    await file.writeAsString(raw);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Telos save that could not be opened',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    return file.path;
  }

  /// JSON files anywhere in the app's Documents folder, newest first. The
  /// screen reads each one and shows the ones that are not Telos backups as
  /// unreadable, rather than this guessing from the name.
  static Future<List<File>> available() async {
    final dir = await documents();
    if (!await dir.exists()) return [];
    final files = <File>[];
    await for (final entry in dir.list(recursive: true, followLinks: false)) {
      if (entry is File && entry.path.toLowerCase().endsWith('.json')) {
        files.add(entry);
      }
    }
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// Opens the system file picker. Null when the player cancels.
  static Future<PickedBackup?> pick() async {
    final picked = await FilePicker.pickFiles(type: FileType.any);
    if (picked.isEmpty) return null;
    final file = picked.first;
    return PickedBackup(file.name, await file.xFile.readAsString());
  }
}

/// Native file/share access kept separate from the review UI. Tests can supply
/// an in-memory catalogue without invoking a platform share sheet.
class BackupFiles {
  const BackupFiles();

  Future<List<File>> available() => Backup.available();
  Future<String> read(File file) => file.readAsString();
  Future<String> export(GuildState state, {Rect? sharePositionOrigin}) =>
      Backup.export(state, sharePositionOrigin: sharePositionOrigin);
  Future<String> exportUnreadable(String raw, {Rect? sharePositionOrigin}) =>
      Backup.exportUnreadable(raw, sharePositionOrigin: sharePositionOrigin);
  Future<PickedBackup?> pick() => Backup.pick();
}

/// A file the player chose from outside the app: its name and contents.
class PickedBackup {
  const PickedBackup(this.name, this.text);
  final String name;
  final String text;
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
