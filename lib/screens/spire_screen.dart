import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/guild_state.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/camp_controls.dart';
import '../widgets/expedition_widgets.dart';
import '../widgets/spire_drawing.dart';

/// A record of contributions, with no deadline or next-floor countdown.
class SpireScreen extends StatefulWidget {
  const SpireScreen({super.key});

  @override
  State<SpireScreen> createState() => _SpireScreenState();
}

class _SpireScreenState extends State<SpireScreen> {
  bool _charterOpen = false;

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GuildController>().g;
    final mine = g.spireFloors;
    final hours = g.minutesSinceSpire ~/ 60;
    return Scaffold(
      appBar: AppBar(title: const Text('The Spire')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text('SECTOR 05', style: T.label),
            const SizedBox(height: 12),
            const Text('The unfinished tower.', style: T.display),
            const SizedBox(height: 12),
            const Text(
                'The top course was never finished. Cut stone stacked ready, mortar never mixed.',
                style: T.body),
            const SizedBox(height: 24),
            ExpeditionPanel(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RAISED BY YOU', style: T.label),
                const SizedBox(height: 12),
                Text('$mine ${mine == 1 ? 'floor' : 'floors'}',
                    style: T.numeric.copyWith(color: T.amber)),
                const SizedBox(height: 8),
                Text('$hours hours on this charter', style: T.secondary),
                const SizedBox(height: 24),
                LayoutBuilder(
                    builder: (context, box) => SizedBox(
                          height: 260,
                          child: Center(
                              child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: box.maxWidth,
                              child: SpireDrawing(
                                  historical: GuildState.kHistoricalFloors,
                                  mine: mine),
                            ),
                          )),
                        )),
                if (mine > SpireDrawing.maxShown) ...[
                  const SizedBox(height: 12),
                  Text(
                      '+${mine - SpireDrawing.maxShown} more floors above the drawing.',
                      style: T.secondary),
                ],
                const SizedBox(height: 16),
                Text(
                    'Stone marks the old structure. Brass marks your contribution.',
                    style: T.secondary),
              ],
            )),
            const SizedBox(height: 12),
            CampDisclosure(
              key: const Key('spire-charter'),
              title: 'The Last Charter',
              summary: g.spireCharterName ?? 'No charter signed yet',
              icon: Icons.history_edu_outlined,
              expanded: _charterOpen,
              onToggle: () => setState(() => _charterOpen = !_charterOpen),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'Everyone who worked on it stopped, which is why nobody knows what it is for.',
                          style: T.body),
                      const SizedBox(height: 20),
                      Text(
                          '${GuildState.kHistoricalFloors} floors standing before you.',
                          style: T.data),
                      const SizedBox(height: 8),
                      Text(
                          '${GuildState.kCharterHours} hours on the earlier charter.',
                          style: T.secondary),
                      const SizedBox(height: 20),
                      const Text(
                          'One floor for every ${GuildState.kFloorHours} hours of expeditions after signing. '
                          'It does not decay and it cannot be bought.',
                          style: T.body),
                    ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
