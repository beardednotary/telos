import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/guild_state.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import 'sigil.dart';
import 'camp_controls.dart';
import 'expedition_widgets.dart';
import 'management_widgets.dart';

/// How a contract reads. Written as an order given to a guild, not as a
/// checklist item - "Bring back 180 alloy from Blackstone Hollow in a single
/// run" rather than "Alloy: 0/180".
String contractTitle(Contract c, GuildState g) {
  final sector = c.sectorId == null ? null : sectorById(c.sectorId!);
  final cls = c.classId == null ? null : kClasses[c.classId!];
  String name(String? id) =>
      (id == null ? null : g.memberById(id)?.name) ?? 'the newest hand';
  String times(String order) =>
      c.target == 1 ? order : '$order ${c.target} times';

  switch (c.kind) {
    case ContractKind.sectorRuns:
      return 'Run ${fieldName(sector!.name)} ${c.target} times';
    case ContractKind.haul:
      return 'Bring back ${c.target} ${c.res!.label.toLowerCase()} from ${fieldName(sector!.name)} '
          'in a single run';
    case ContractKind.cleanRuns:
      return 'Finish ${c.target} runs at full Integrity';
    case ContractKind.longRun:
      return 'Protect a single block of ${c.target} minutes';
    case ContractKind.minutes:
      return 'Protect ${c.target} minutes in total';
    case ContractKind.classRuns:
      return 'Send the ${fieldName(cls!.name)} out ${c.target} times';
    case ContractKind.fullDepth:
      return c.target == 1
          ? 'Reach the far end of ${fieldName(sector!.name)}'
          : 'Reach the far end of ${fieldName(sector!.name)} ${c.target} times';
    case ContractKind.sectorReturn:
      return 'Go back into ${fieldName(sector!.name)}';
    case ContractKind.memberLevel:
      return 'Bring ${name(c.memberId)} up to level ${c.target}';
    case ContractKind.carryGear:
      return times(
          'Take the ${fieldName(gearById(c.gearDefId!).name)} back into '
          '${fieldName(sector!.name)}');
    case ContractKind.fullKit:
      return times('Send a squad out with every kit slot filled');
    case ContractKind.pairRun:
      return times('Send ${name(c.memberId)} out with ${name(c.partnerId)}');
    case ContractKind.intentRuns:
      return 'Set an intent on ${c.target} runs';
  }
}

/// The unit under the meter, so progress reads without doing arithmetic.
String contractProgress(Contract c) => switch (c.kind) {
      ContractKind.haul =>
        '${c.progress} / ${c.target} ${c.res!.label.toLowerCase()}',
      ContractKind.longRun => '${c.progress} / ${c.target} min · best run',
      ContractKind.minutes => '${c.progress} / ${c.target} min',
      ContractKind.memberLevel => 'Level ${c.progress} / ${c.target}',
      _ => '${c.progress} / ${c.target}',
    };

/// Optional orders use the same bounded hierarchy as the rest of camp.
class ContractBoardPanel extends StatefulWidget {
  const ContractBoardPanel({super.key});

  @override
  State<ContractBoardPanel> createState() => _ContractBoardPanelState();
}

class _ContractBoardPanelState extends State<ContractBoardPanel> {
  String? _open;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Standing orders.', style: T.display),
        const SizedBox(height: 8),
        Text('Optional goals. No deadlines.', style: T.secondary),
        const SizedBox(height: 24),
        if (c.contracts.isEmpty)
          Text(
              'Nothing on the board yet. Orders get posted once the guild '
              'has people and places to send them.',
              style: T.secondary),
        for (final contract in c.contracts) ...[
          CampDisclosure(
            key: Key('contract-${contract.id}'),
            title: contractTitle(contract, c.g),
            summary: contract.done
                ? 'Complete · Ready to claim'
                : contractProgress(contract),
            icon: contract.done
                ? Icons.check_circle_outline
                : Icons.assignment_outlined,
            leading: contract.done
                ? null
                : contract.sectorId != null
                    ? Sigil(
                        sectorId: contract.sectorId!, color: T.amber, size: 26)
                    : contract.classId != null
                        ? ClassEmblem(
                            classId: contract.classId!,
                            color: T.amber,
                            size: 26)
                        : null,
            expanded: _open == contract.id,
            onToggle: () => setState(
                () => _open = _open == contract.id ? null : contract.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REWARD', style: T.label),
                    const SizedBox(height: 12),
                    ResourceAmounts(
                        credits: contract.rewardCredits,
                        alloy: contract.rewardAlloy,
                        intel: contract.rewardIntel,
                        gains: true),
                    const SizedBox(height: 8),
                    Text('+${contract.rewardXp} guild XP', style: T.secondary),
                    const SizedBox(height: 20),
                    if (contract.done)
                      CampAction(
                        key: Key('claim-${contract.id}'),
                        label: 'Claim rewards',
                        onPressed: () async {
                          final paid = await c.claimContract(contract.id);
                          if (paid == null || !context.mounted) return;
                          setState(() => _open = null);
                          campPayout(
                            context,
                            kicker: 'CONTRACT PAID',
                            credits: paid.rewardCredits,
                            alloy: paid.rewardAlloy,
                            intel: paid.rewardIntel,
                            footnote: '+${paid.rewardXp} guild XP',
                          );
                        },
                      )
                    else
                      Text('Progress is recorded when an expedition returns.',
                          style: T.secondary),
                  ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
