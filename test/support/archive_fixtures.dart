import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:telos/models/guild_state.dart';
import 'package:telos/models/models.dart';
import 'package:telos/services/backup.dart';

List<Contract> standingOrders() => [
      Contract(
          id: 'order-ready',
          kind: ContractKind.cleanRuns,
          target: 3,
          tier: 1,
          progress: 3,
          rewardCredits: 120,
          rewardAlloy: 25,
          rewardIntel: 8,
          rewardXp: 35),
      Contract(
          id: 'order-hollow',
          kind: ContractKind.sectorRuns,
          sectorId: 'blackstone',
          target: 3,
          tier: 1,
          progress: 1,
          rewardCredits: 90,
          rewardAlloy: 40,
          rewardIntel: 4,
          rewardXp: 30),
      Contract(
          id: 'order-intent',
          kind: ContractKind.intentRuns,
          target: 5,
          tier: 1,
          progress: 2,
          rewardCredits: 100,
          rewardAlloy: 20,
          rewardIntel: 10,
          rewardXp: 30),
    ];

RunRecord archiveRecord({
  String id = 'record-1',
  String intent = 'Write the next chapter',
  String sector = 'blackstone',
  bool recalled = false,
  DateTime? startedAt,
  List<String> loot = const ['retained', 'melted'],
}) =>
    RunRecord(
      id: id,
      sectorId: sector,
      intent: intent,
      squad: const ['a1', 'a2'],
      startedAt: startedAt ?? DateTime(2026, 10, 11, 9),
      endedAt: (startedAt ?? DateTime(2026, 10, 11, 9))
          .add(Duration(seconds: recalled ? 45 : 1500)),
      plannedMinutes: 25,
      elapsedSeconds: recalled ? 45 : 1500,
      integrity: recalled ? .96 : 1,
      recalled: recalled,
      scraps: recalled,
      credits: recalled ? 1 : 110,
      alloy: recalled ? 0 : 46,
      intel: recalled ? 0 : 5,
      loot: loot,
      xpGained: const {'a1': 80, 'a2': 80},
      levelUps: const ['a1'],
      guildXp: 63,
      guildLevelUps: 1,
      journal: const [
        'The west road is passable.',
        'The old watch post is empty.'
      ],
      priorSurvey: 'Someone had marked a second route through the stone.',
      progress: 'SOME',
      note: 'Finished the outline. The ending needs another pass.',
    );

/// No disk writes or native sharing in widget tests and visual previews.
class MemoryBackupFiles extends BackupFiles {
  final contents = <String, String>{};
  final unreadable = <String>{};
  bool failList = false;
  bool failExport = false;
  int exports = 0;
  Rect? lastSharePositionOrigin;
  Completer<void>? pendingExport;

  /// What the system picker hands back; null is a cancel.
  PickedBackup? picked;
  int picks = 0;

  @override
  Future<PickedBackup?> pick() async {
    picks++;
    return picked;
  }

  @override
  Future<List<File>> available() async {
    if (failList) throw const FileSystemException('Test directory unavailable');
    return contents.keys.map(File.new).toList();
  }

  @override
  Future<String> read(File file) async {
    if (unreadable.contains(file.path)) {
      throw const FileSystemException('Test file unavailable');
    }
    return contents[file.path]!;
  }

  @override
  Future<String> export(GuildState state, {Rect? sharePositionOrigin}) async {
    lastSharePositionOrigin = sharePositionOrigin;
    exports++;
    final text = Backup.encode(state, when: DateTime(2026, 10, 11, 12));
    if (pendingExport != null) await pendingExport!.future;
    if (failExport) throw const FileSystemException('Test export failed');
    const path = '/memory/telos-backup-2026-10-11-1200.json';
    contents[path] = text;
    return path;
  }
}
