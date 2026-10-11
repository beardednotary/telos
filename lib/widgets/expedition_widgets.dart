import 'package:flutter/material.dart';

import '../models/guild_state.dart';
import '../models/models.dart';
import '../theme/telos_theme.dart';

/// Authored content is stored in capitals. Never apply this to player names.
String fieldName(String name) => name
    .toLowerCase()
    .split(' ')
    .map((word) =>
        word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

String projectTitle(GuildState g) =>
    '${fieldName(g.campProject.name)} · Level ${g.facilities[g.campProject]! + 1}';

String expeditionCount(int count) =>
    '$count ${count == 1 ? 'expedition' : 'expeditions'}';

String describeBonus(Bonus bonus) => bonus.lines
    .map((line) =>
        line.replaceAll('RARE FIND', 'gear-find modifier').toLowerCase())
    .join(' · ');

class ExpeditionPanel extends StatelessWidget {
  const ExpeditionPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: T.card,
          border: Border.all(color: T.boundary),
          borderRadius: BorderRadius.circular(3),
        ),
        child: child,
      );
}

class ExpeditionFooter extends StatelessWidget {
  const ExpeditionFooter({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: T.black,
          border: Border(top: BorderSide(color: T.line)),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: child,
        ),
      );
}

class ResourceAmounts extends StatelessWidget {
  const ResourceAmounts({
    super.key,
    required this.credits,
    required this.alloy,
    required this.intel,
    this.gains = false,
  });
  final int credits;
  final int alloy;
  final int intel;
  final bool gains;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, amount) in [
            ('credits', credits),
            ('alloy', alloy),
            ('intel', intel)
          ])
            Expanded(
                child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${gains ? '+' : ''}$amount',
                        style: T.mono.copyWith(
                            fontSize: 20, fontWeight: FontWeight.w600)),
                    Text(label, style: T.secondary),
                  ]),
            )),
        ],
      );
}
