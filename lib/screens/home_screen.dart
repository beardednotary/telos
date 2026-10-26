import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/models.dart';
import '../services/redeploy.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/camp_controls.dart';
import '../widgets/contract_board.dart';
import '../widgets/expedition_widgets.dart';
import '../widgets/guild_sigil.dart';
import 'backup_screen.dart';
import 'caravan_screen.dart';
import 'dispatch_screen.dart';
import 'forge_screen.dart';
import 'guild_identity_sheet.dart';
import 'log_screen.dart';
import 'outpost_screen.dart';
import 'roster_screen.dart';
import 'spire_screen.dart';

String _facilityName(Facility f) => switch (f) {
      Facility.forge => 'Forge',
      Facility.archive => 'Archive',
      Facility.barracks => 'Barracks',
    };

String _facilityBenefit(Facility f) => switch (f) {
      Facility.forge => '+6% alloy · +2% gear-find modifier per level',
      Facility.archive => '+8% intel per level',
      Facility.barracks => '+1 roster space · +5% squad XP per level',
    };

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _open;
  bool _sending = false;

  void _toggle(String section) =>
      setState(() => _open = _open == section ? null : section);

  void _visit(Widget screen) => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => screen),
      );

  Future<void> _repeat(Redeploy dispatch) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      // The same weight as Deploy on the dispatch screen.
      HapticFeedback.heavyImpact();
      await context.read<GuildController>().redeploy(dispatch);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _chooseProject() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          final c = context.watch<GuildController>();
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Choose a project', style: T.display),
                  const SizedBox(height: 8),
                  Text(
                      'Every expedition can contribute. Picking a project does not spend supplies.',
                      style: T.secondary),
                  const SizedBox(height: 20),
                  for (final facility in Facility.values)
                    ListTile(
                      key: Key('project-${facility.name}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          '${_facilityName(facility)} · Level ${c.g.facilities[facility]! + 1}',
                          style: T.title),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 12),
                        child: Text(
                          '${_facilityBenefit(facility)}\n'
                          '${facility.costAt(c.g.facilities[facility]!).$1} credits · '
                          '${facility.costAt(c.g.facilities[facility]!).$2} alloy',
                          style: T.secondary,
                        ),
                      ),
                      trailing: Icon(
                          c.g.campProject == facility
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: c.g.campProject == facility ? T.amber : T.dim),
                      onTap: () async {
                        await c.selectCampProject(facility);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  CampButton(
                      label: 'Cancel', onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final g = c.g;
    final repeats = recentDispatches(g);
    final project = g.campProject;
    final level = g.facilities[project]!;
    final (costCredits, costAlloy) = project.costAt(level);
    final progress =
        min(g.credits / costCredits, g.alloy / costAlloy).clamp(0.0, 1.0);
    final contracts = c.claimableContracts;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Expanded(
            child: ListView(
              key: const Key('camp-scroll'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                Row(children: [
                  Expanded(child: Text('Outpost', style: T.secondary)),
                  Text('Guild ${g.level}', style: T.label),
                ]),
                const SizedBox(height: 8),
                Semantics(
                  button: true,
                  label: 'Edit guild name and sigil',
                  child: InkWell(
                    key: const Key('edit-guild'),
                    onTap: () => showGuildIdentity(context, c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        ExcludeSemantics(
                            child: GuildEmblem(sigil: g.guildSigil)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(g.guildName, style: T.display)),
                        const SizedBox(width: 8),
                        const Icon(Icons.edit_outlined, size: 18, color: T.dim),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration:
                      BoxDecoration(border: Border.all(color: T.boundary)),
                  child: Column(children: [
                    // A mood illustration of camp, not the selected squad.
                    Image.asset(
                      'assets/art/camp.webp',
                      height:
                          MediaQuery.sizeOf(context).width <= 340 ? 150 : 184,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, .15),
                      excludeFromSemantics: true,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(children: [
                        Expanded(
                            child: Text('${g.roster.length} at camp.',
                                style: T.secondary)),
                        const SizedBox(width: 8),
                        Flexible(
                            child: Text('Ready when you are.',
                                style: T.secondary, textAlign: TextAlign.end)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                if (c.offerMusic) const _MusicOffer(),
                CaravanCard(onDispatch: () => _visit(const DispatchScreen())),
                Material(
                  color: T.card,
                  shape: const RoundedRectangleBorder(
                      side: BorderSide(color: T.boundary)),
                  child: InkWell(
                    key: const Key('review-project'),
                    onTap: () => _visit(const OutpostScreen()),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    c.canUpgrade(project)
                                        ? 'READY TO UPGRADE'
                                        : 'YOUR NEXT PROJECT',
                                    style: T.label),
                                const SizedBox(height: 5),
                                Text(
                                    '${_facilityName(project)} · Level ${level + 1}',
                                    style: T.title),
                              ],
                            )),
                            TextButton(
                              key: const Key('change-project'),
                              onPressed: _chooseProject,
                              style: TextButton.styleFrom(
                                foregroundColor: T.text,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                minimumSize: const Size(48, 48),
                                textStyle: T.secondary,
                              ),
                              child: const Text('Change'),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Text(_facilityBenefit(project), style: T.secondary),
                          const SizedBox(height: 12),
                          Wrap(spacing: 16, runSpacing: 4, children: [
                            Text('${g.credits} / $costCredits credits',
                                style: T.mono.copyWith(fontSize: 12)),
                            Text('${g.alloy} / $costAlloy alloy',
                                style: T.mono.copyWith(fontSize: 12)),
                          ]),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: T.line,
                            color: T.amber,
                            semanticsLabel:
                                'Supplies for the next ${_facilityName(project)} upgrade',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                CampDisclosure(
                  key: const Key('squad-disclosure'),
                  title: 'Squad & equipment',
                  summary:
                      '${g.roster.length} members · ${g.squadSlots} squad ${g.squadSlots == 1 ? 'slot' : 'slots'}',
                  icon: Icons.people_outline,
                  expanded: _open == 'squad',
                  onToggle: () => _toggle('squad'),
                  child: Column(children: [
                    CampLink(
                      title: 'Roster & equipment',
                      detail: 'Choose gear and review each member.',
                      onTap: () => _visit(const RosterScreen()),
                    ),
                    if (repeats.isNotEmpty) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('RECENT EXPEDITIONS', style: T.label),
                        ),
                      ),
                      for (final dispatch in repeats)
                        CampLink(
                          title:
                              '${dispatch.minutes} min · ${sectorById(dispatch.sectorId).name}',
                          detail:
                              '${dispatch.squad.map((id) => g.memberById(id)!.name).join(' & ')} · Send again',
                          onTap: () => _repeat(dispatch),
                        ),
                    ],
                  ]),
                ),
                const SizedBox(height: 8),
                CampDisclosure(
                  key: const Key('stores-disclosure'),
                  title: 'Stores & facilities',
                  summary:
                      '${g.credits} credits · ${g.alloy} alloy · ${g.intel} intel'
                      '${contracts > 0 ? '\n$contracts ${contracts == 1 ? 'contract' : 'contracts'} ready to claim' : ''}',
                  icon: Icons.inventory_2_outlined,
                  expanded: _open == 'stores',
                  onToggle: () => _toggle('stores'),
                  child: Column(children: [
                    CampLink(
                      title: 'Facilities & recruiting',
                      detail: 'Upgrade camp, recruit members, open sectors.',
                      onTap: () => _visit(const OutpostScreen()),
                    ),
                    CampLink(
                      title: 'Forge',
                      detail:
                          'Craft equipment from the places you have charted.',
                      onTap: () => _visit(const ForgeScreen()),
                    ),
                    CampLink(
                      title: 'Contracts',
                      detail: contracts > 0
                          ? '$contracts ready to claim'
                          : '${c.contracts.length} on the board',
                      onTap: () => _visit(const _ContractsScreen()),
                    ),
                    CampLink(
                      key: const Key('caravan-link'),
                      title: 'Caravan',
                      detail: g.caravan == null
                          ? 'Set a time to start, and be rewarded for keeping it.'
                          : caravanSummary(context, g.caravan!),
                      onTap: () => _visit(const CaravanScreen()),
                    ),
                    CampLink(
                      title: 'Field log',
                      detail:
                          '${g.totalFocusMinutes} protected minutes · ${g.daysWorked} days worked',
                      onTap: () => _visit(const LogScreen()),
                    ),
                    if (g.spireComplete)
                      CampLink(
                        title: 'The Spire',
                        detail:
                            '${g.spireFloors} floors raised since your arrival',
                        onTap: () => _visit(const SpireScreen()),
                      ),
                    CampLink(
                      title: 'Settings & backup',
                      detail: 'Export, restore, and save tools.',
                      onTap: () => _visit(const BackupScreen()),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          'Guild ${g.level} · ${g.xp} / ${g.xpToNext} XP\n'
                          '${g.cleanRuns} expeditions at full Integrity',
                          style: T.secondary),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: T.line))),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CampButton(
                    key: const Key('camp-dispatch'),
                    label: 'Plan an expedition',
                    primary: true,
                    onPressed: () => _visit(const DispatchScreen()),
                  ),
                  if (repeats.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    CampButton(
                      key: const Key('camp-repeat'),
                      label:
                          'Repeat ${repeats.first.minutes} min · ${sectorById(repeats.first.sectorId).name}',
                      onPressed: _sending ? null : () => _repeat(repeats.first),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Music is off by default and its switch lives in Settings, where most
/// players would never find it. Camp asks once instead.
class _MusicOffer extends StatelessWidget {
  const _MusicOffer();

  @override
  Widget build(BuildContext context) {
    final c = context.read<GuildController>();
    return Padding(
      key: const Key('music-offer'),
      padding: const EdgeInsets.only(bottom: 16),
      child: ExpeditionPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('CAMP MUSIC', style: T.label),
            const SizedBox(height: 6),
            Text('Music while you are at camp?', style: T.title),
            const SizedBox(height: 6),
            Text(
                'A quiet track at camp and on reports, and a chime when a '
                'squad comes home. Never during a run. You can change this '
                'in Settings.',
                style: T.secondary),
            const SizedBox(height: 12),
            // Primary buttons stand taller; side by side, they match.
            IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Expanded(
                    child: CampButton(
                      key: const Key('music-offer-no'),
                      label: 'No thanks',
                      onPressed: c.declineMusic,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CampButton(
                      key: const Key('music-offer-yes'),
                      label: 'Play it',
                      primary: true,
                      onPressed: () => c.setMusic(true),
                    ),
                  ),
                ])),
          ],
        ),
      ),
    );
  }
}

class _ContractsScreen extends StatelessWidget {
  const _ContractsScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Contracts')),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: const [ContractBoardPanel()],
          ),
        ),
      );
}
