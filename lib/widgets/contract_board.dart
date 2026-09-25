import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import 'flash.dart';
import 'sigil.dart';
import 'terminal.dart';

/// How a contract reads. Written as an order given to a guild, not as a
/// checklist item - "Bring back 180 alloy from Blackstone Hollow in a single
/// run" rather than "Alloy: 0/180".
String contractTitle(Contract c) {
  final sector = c.sectorId == null ? null : sectorById(c.sectorId!);
  final cls = c.classId == null ? null : kClasses[c.classId!];

  switch (c.kind) {
    case ContractKind.sectorRuns:
      return 'Run ${sector!.name} ${c.target} times';
    case ContractKind.haul:
      return 'Bring back ${c.target} ${c.res!.label} from ${sector!.name} '
          'in a single run';
    case ContractKind.cleanRuns:
      return 'Finish ${c.target} runs at full integrity';
    case ContractKind.longRun:
      return 'Protect a single block of ${c.target} minutes';
    case ContractKind.minutes:
      return 'Protect ${c.target} minutes in total';
    case ContractKind.classRuns:
      return 'Send the ${cls!.name} out ${c.target} times';
    case ContractKind.fullDepth:
      return c.target == 1
          ? 'Reach the far end of ${sector!.name}'
          : 'Reach the far end of ${sector!.name} ${c.target} times';
  }
}

/// The unit under the meter, so progress reads without doing arithmetic.
String contractProgress(Contract c) => switch (c.kind) {
      ContractKind.haul => '${c.progress} / ${c.target} ${c.res!.label}',
      ContractKind.longRun => '${c.progress} / ${c.target} MIN, BEST RUN',
      ContractKind.minutes => '${c.progress} / ${c.target} MIN',
      _ => '${c.progress} / ${c.target}',
    };

/// The board. Lives on the home screen because that is where the question
/// "what should I do next" is actually asked.
class ContractBoardPanel extends StatelessWidget {
  const ContractBoardPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    if (c.contracts.isEmpty) return const SizedBox.shrink();
    final ready = c.claimableContracts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(
            children: [
              Text('CONTRACTS', style: T.micro.copyWith(color: T.steel)),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 1, color: T.line)),
              if (ready > 0) ...[
                const SizedBox(width: 12),
                Text('$ready READY', style: T.micro.copyWith(color: T.good)),
              ],
            ],
          ),
        ),
        for (final k in c.contracts) _ContractBand(contract: k),
      ],
    );
  }
}

class _ContractBand extends StatelessWidget {
  const _ContractBand({required this.contract});
  final Contract contract;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<GuildController>();
    final k = contract;
    final done = k.done;
    final sector = k.sectorId == null ? null : sectorById(k.sectorId!);
    final accent =
        done ? T.good : (sector != null ? Color(sector.accent) : T.steel);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: done ? T.good.withValues(alpha: 0.10) : T.band,
      ),
      padding: const EdgeInsets.fromLTRB(0, 14, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 4, height: 44, color: accent),
          const SizedBox(width: 14),
          if (sector != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: Sigil(sectorId: sector.id, color: accent, size: 22),
            ),
          ] else if (k.classId != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: ClassEmblem(classId: k.classId!, color: accent, size: 22),
            ),
          ] else
            const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contractTitle(k),
                    style: T.mono.copyWith(fontSize: 15, height: 1.5)),
                const SizedBox(height: 10),
                if (done)
                  Row(
                    children: [
                      Text('COMPLETE', style: T.micro.copyWith(color: T.good)),
                      const Spacer(),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          final claimed = await ctrl.claimContract(k.id);
                          if (claimed == null || !context.mounted) return;
                          showFlash(
                            context,
                            kicker: 'CONTRACT PAID',
                            title: contractTitle(claimed),
                            lines: [
                              '+${claimed.rewardCredits} CR   '
                                  '+${claimed.rewardAlloy} AL   '
                                  '+${claimed.rewardIntel} IN',
                              '+${claimed.rewardXp} GUILD XP',
                            ],
                            color: T.good,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: T.good.withValues(alpha: 0.15),
                            border: Border.all(color: T.good),
                          ),
                          child: Text('CLAIM',
                              style: T.mono.copyWith(
                                  fontSize: 12,
                                  letterSpacing: 2,
                                  color: T.good)),
                        ),
                      ),
                    ],
                  )
                else ...[
                  Meter(
                    value: k.target == 0 ? 0 : k.progress / k.target,
                    segments: 20,
                    height: 4,
                    color: accent,
                  ),
                  const SizedBox(height: 7),
                  // Spread apart when both fit; the reward drops to its own
                  // line when a long progress label or large text would
                  // otherwise run them together.
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(contractProgress(k), style: T.micro),
                        Text(
                          '${k.rewardCredits} CR  ${k.rewardAlloy} AL  '
                          '${k.rewardIntel} IN',
                          style: T.micro.copyWith(color: T.dim),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
