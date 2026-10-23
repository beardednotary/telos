import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/models.dart';
import '../services/expedition_engine.dart';
import '../services/plan_suggestion.dart';
import '../services/redeploy.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/sector_header.dart';
import '../widgets/camp_controls.dart';
import '../widgets/expedition_widgets.dart';
import '../widgets/sector_scene.dart';
import '../widgets/sigil.dart';
import 'caravan_screen.dart';
import 'roster_screen.dart';

class DispatchScreen extends StatefulWidget {
  const DispatchScreen({super.key});
  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  final _intent = TextEditingController();
  int _minutes = 25;
  String? _sectorId;
  final _squad = <String>[];
  String? _open = 'focus';
  String? _notice;
  String? _error;
  bool _initialized = false;
  bool _sending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final g = context.read<GuildController>().g;
    final recent = recentDispatches(g);
    if (recent.isNotEmpty) {
      final last = recent.first;
      _minutes = last.minutes;
      _sectorId = last.sectorId;
      _squad.addAll(last.squad);
    } else if (g.roster.isNotEmpty) {
      // A first dispatch is one tap: 25 minutes, the nearest sector, and the
      // first member. The button used to read "Choose a squad" with nobody
      // picked, which was the first decision a new player hit.
      _squad.add(g.roster.first.id);
    }
  }

  @override
  void dispose() {
    _intent.dispose();
    super.dispose();
  }

  void _toggle(String step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _open = _open == step ? null : step);
  }

  void _pickMinutes(int minutes) {
    final c = context.read<GuildController>();
    final available = c.availableSectors(minutes);
    setState(() {
      _minutes = minutes;
      _notice = null;
      if (!available.any((s) => s.id == _sectorId)) {
        final previous = _sectorId;
        _sectorId = available.isEmpty ? null : available.last.id;
        if (previous != null && _sectorId != null) {
          _notice =
              'Destination changed to ${fieldName(sectorById(_sectorId!).name)} to fit this session.';
        }
      }
    });
  }

  Future<void> _send() async {
    final c = context.read<GuildController>();
    if (_sending || _sectorId == null || c.hasActiveRun) return;
    if (_squad.isEmpty) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _open = 'squad');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      HapticFeedback.heavyImpact();
      await c.startRun(
          sectorId: _sectorId!,
          intent: _intent.text,
          squad: List.of(_squad),
          minutes: _minutes);
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not start the expedition. The squad is '
            'still at camp, so nothing is lost. Try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Picks the destination and squad for the chosen time, and says why. The
  /// player can still change either afterwards; this only fills them in.
  void _suggest() {
    FocusManager.instance.primaryFocus?.unfocus();
    final c = context.read<GuildController>();
    final plan = suggestPlan(c.g, _minutes);
    setState(() {
      if (plan == null) {
        _notice = 'Nothing is reachable in $_minutes minutes yet.';
        return;
      }
      _sectorId = plan.sector.id;
      _squad
        ..clear()
        ..addAll(plan.squad.map((m) => m.id));
      _open = null;
      _notice = '${fieldName(plan.sector.name)} with '
          '${plan.squad.map((m) => m.name).join(' & ')}. ${plan.reason}';
    });
  }

  Future<void> _custom() async {
    var value = _minutes.toDouble();
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Your time', style: T.display),
                const SizedBox(height: 16),
                Text('${value.round()} minutes', style: T.title),
                Slider(
                  key: const Key('custom-duration-slider'),
                  value: value,
                  min: 5,
                  max: 180,
                  divisions: 35,
                  label: '${value.round()} minutes',
                  onChanged: (v) => setSheet(() => value = v),
                ),
                Text('5–180 minutes, in five-minute steps.',
                    style: T.secondary),
                const SizedBox(height: 16),
                CampButton(
                    label: 'Use ${value.round()} minutes',
                    primary: true,
                    key: const Key('confirm-duration'),
                    onPressed: () => Navigator.pop(context, value.round())),
              ]),
        )),
      ),
    );
    if (picked != null && mounted) _pickMinutes(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final g = c.g;
    final available = c.availableSectors(_minutes);
    if (!available.any((s) => s.id == _sectorId)) {
      _sectorId = available.isEmpty ? null : available.last.id;
    }
    _squad.removeWhere((id) => g.memberById(id) == null);
    if (_squad.length > g.squadSlots) {
      _squad.removeRange(g.squadSlots, _squad.length);
    }
    final members = _squad.map((id) => g.memberById(id)!).toList();
    final sector = _sectorId == null ? null : sectorById(_sectorId!);
    final forecast = sector == null || members.isEmpty
        ? null
        : ExpeditionEngine.forecast(
            guild: g,
            sector: sector,
            members: members,
            minutes: _minutes.toDouble());
    final ready = forecast != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Dispatch')),
      body: Column(children: [
        Expanded(
            child: ListView(
          key: const Key('dispatch-scroll'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            const Text('Prepare to head out.', style: T.display),
            const SizedBox(height: 20),
            // Where they are going, before anything has to be tapped. It was
            // inside the destination disclosure, which is closed by default,
            // so the best thing on the screen was behind a tap.
            if (sector != null) ...[
              SectorHeader(sector: sector, height: 132),
              const SizedBox(height: 16),
            ],
            CampDisclosure(
              key: const Key('focus-step'),
              title: 'Your focus',
              summary:
                  '$_minutes minutes · ${_intent.text.trim().isEmpty ? 'Set an intention, if you like' : _intent.text.trim()}',
              icon: Icons.schedule_outlined,
              expanded: _open == 'focus',
              onToggle: () => _toggle('focus'),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const Key('focus-intent'),
                        controller: _intent,
                        style: T.body,
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 80,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            labelText: 'What are you working on?',
                            helperText: 'Optional. For your log.'),
                      ),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 4, children: [
                        for (final minutes in kDurations)
                          ChoiceChip(
                            key: Key('duration-$minutes'),
                            label: Text('$minutes min'),
                            selected: _minutes == minutes,
                            onSelected: (_) => _pickMinutes(minutes),
                          ),
                        ActionChip(
                            key: const Key('custom-duration'),
                            label: const Text('Custom'),
                            onPressed: _custom),
                      ]),
                      const SizedBox(height: 12),
                      CampButton(
                          key: const Key('suggest-plan'),
                          label: 'Suggest a plan for $_minutes minutes',
                          onPressed: _suggest),
                      const SizedBox(height: 8),
                      CampButton(
                          label: 'Choose their destination',
                          onPressed: () => _toggle('destination')),
                    ],
                  )),
            ),
            const SizedBox(height: 8),
            CampDisclosure(
              key: const Key('destination-step'),
              title: 'Their destination',
              summary: sector == null
                  ? 'No destination fits $_minutes minutes'
                  : fieldName(sector.name),
              icon: Icons.explore_outlined,
              expanded: _open == 'destination',
              onToggle: () => _toggle('destination'),
              child: Column(children: [
                if (sector != null)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SectorScene(
                        sectorId: sector.id,
                        color: T.dim,
                        height: 88,
                        animate: false),
                  ),
                for (final choice in kSectors)
                  _sectorChoice(c, choice, members),
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: CampButton(
                        label: 'Choose the squad',
                        onPressed: () => _toggle('squad'))),
              ]),
            ),
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_notice!,
                    key: const Key('dispatch-notice'), style: T.secondary),
              ),
            const SizedBox(height: 8),
            CampDisclosure(
              key: const Key('squad-step'),
              title: 'The squad',
              summary: members.isEmpty
                  ? 'Choose up to ${g.squadSlots} · Nobody selected'
                  : '${members.map((m) => m.name).join(' & ')} · ${members.length}/${g.squadSlots}',
              icon: Icons.people_outline,
              expanded: _open == 'squad',
              onToggle: () => _toggle('squad'),
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                        'When the squad is full, selecting someone replaces the first selected member.',
                        style: T.secondary)),
                for (final member in g.roster) _memberChoice(c, member),
                CampLink(
                    title: 'Review equipment',
                    detail: 'Changes to worn gear update this forecast.',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => const RosterScreen()))),
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: CampButton(
                        label: 'Review the plan',
                        onPressed: () => _toggle('squad'))),
              ]),
            ),
            const SizedBox(height: 16),
            if (forecast != null)
              ExpeditionPanel(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Stated as the thing the player does, not as the stat
                  // it is scored on. The forecast is a promise Integrity
                  // keeps, so it should say what keeping it looks like
                  // before the run rather than only grading it after.
                  Text('Expected haul, if you leave it alone',
                      style: T.secondary),
                  const SizedBox(height: 10),
                  ResourceAmounts(
                      credits: forecast.credits,
                      alloy: forecast.alloy,
                      intel: forecast.intel),
                  const SizedBox(height: 12),
                  Text(
                      '${(forecast.depth * 100).round()}% depth · ${forecast.gearAttempts} gear-finding ${forecast.gearAttempts == 1 ? 'attempt' : 'attempts'}',
                      style: T.secondary),
                  TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => SafeArea(
                          child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Behind the forecast', style: T.display),
                            const SizedBox(height: 16),
                            Text(
                                'For a full $_minutes-minute session at 100% Integrity. Returning early or spending time in Telos changes the result.',
                                style: T.body),
                            const SizedBox(height: 16),
                            Text(
                                'Class, duration windows, levels, worn gear, and facilities:\n${describeBonus(forecast.bonus)}',
                                style: T.body),
                            const SizedBox(height: 16),
                            Text(
                                '${(forecast.gearChance * 100).round()}% chance per attempt of finding any gear. '
                                'Rarity is rolled separately. Nothing is guaranteed or revealed in advance.',
                                style: T.body),
                            const SizedBox(height: 16),
                            CampButton(
                                label: 'Back to the plan',
                                onPressed: () => Navigator.pop(context)),
                          ],
                        ),
                      )),
                    ),
                    child: const Text('How this is calculated'),
                  ),
                ],
              ))
            else
              Text(
                  sector == null
                      ? 'The nearest sector needs at least 10 minutes. Your custom duration stays selected.'
                      : 'Choose a squad to see what this plan can bring back.',
                  style: T.secondary),
            const SizedBox(height: 16),
            if (caravanDispatchLine(c.caravanAt(DateTime.now()))
                case final line?) ...[
              Text(line,
                  key: const Key('dispatch-caravan'),
                  textAlign: TextAlign.center,
                  style: T.body.copyWith(color: T.amber)),
              const SizedBox(height: 8),
            ],
            Text('Working toward ${projectTitle(g)}.',
                textAlign: TextAlign.center, style: T.body),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: T.body.copyWith(color: T.bad)),
              ),
          ],
        )),
        ExpeditionFooter(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          CampButton(
            key: const Key('deploy'),
            label: _sending
                ? 'Sending…'
                : sector == null
                    ? 'No destination fits'
                    : ready
                        ? 'Deploy · $_minutes minutes'
                        : 'Choose a squad',
            primary: true,
            onPressed: _sending || sector == null ? null : _send,
          ),
          if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
            const SizedBox(height: 8),
            Text('Then lock your phone and get to work.',
                textAlign: TextAlign.center, style: T.secondary),
          ],
        ])),
      ]),
    );
  }

  Widget _sectorChoice(
      GuildController c, Sector sector, List<Adventurer> members) {
    final unlocked = c.g.sectorUnlocked(sector.id);
    final reachable = unlocked && sector.minMinutes <= _minutes;
    final selected = sector.id == _sectorId;
    final surveyed =
        (c.g.surveyRead[sector.id] ?? 0) >= sector.priorSurvey.length;
    final forecast = reachable && members.isNotEmpty
        ? ExpeditionEngine.forecast(
            guild: c.g,
            sector: sector,
            members: members,
            minutes: _minutes.toDouble(),
          )
        : null;
    return Semantics(
        selected: selected,
        child: ListTile(
          key: Key('sector-${sector.id}'),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Sigil(
              sectorId: sector.id, color: selected ? T.amber : T.dim, size: 24),
          title: Text(fieldName(sector.name), style: T.title),
          subtitle:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Text(
                !unlocked
                    ? 'Locked · ${sector.intelToUnlock} intel · Guild ${sector.guildLevelToUnlock}'
                    : !reachable
                        ? 'Needs ${sector.minMinutes}+ minutes'
                        : sector.blurb,
                style: T.secondary),
            if (unlocked && surveyed)
              Text('All prior records recovered. Resources and gear remain.',
                  style: T.secondary),
            if (forecast != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    '${forecast.credits} credits · ${forecast.alloy} alloy · ${forecast.intel} intel\n'
                    '${forecast.gearAttempts} gear attempts',
                    style: T.secondary),
              ),
          ]),
          trailing: Icon(
              !reachable
                  ? Icons.lock_outline
                  : selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
              color: selected ? T.amber : T.dim,
              size: 20),
          onTap: !reachable
              ? null
              : () => setState(() {
                    _sectorId = sector.id;
                    _notice = null;
                  }),
        ));
  }

  Widget _memberChoice(GuildController c, Adventurer member) {
    final cls = kClasses[member.classId]!;
    final inWindow = _minutes >= cls.windowMin && _minutes <= cls.windowMax;
    final selected = _squad.contains(member.id);
    final gear = member.equipped
        .map(c.g.gearByUid)
        .whereType<Gear>()
        .map((g) => fieldName(gearById(g.defId).name))
        .join(', ');
    return Semantics(
        selected: selected,
        child: ListTile(
          key: Key('member-${member.id}'),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: ClassEmblem(
              classId: member.classId,
              color: selected ? T.amber : T.dim,
              size: 24),
          title: Text(member.name, style: T.title),
          subtitle:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${fieldName(cls.name)} · Level ${member.level}',
                style: T.secondary),
            Text(
                inWindow
                    ? 'Session bonus active: ${describeBonus(cls.windowBonus)}'
                    : cls.windowText,
                style: T.secondary),
            Text(gear.isEmpty ? 'No equipment worn' : 'Kit: $gear',
                style: T.secondary),
          ]),
          trailing: Icon(
              selected
                  ? Icons.check_box_outlined
                  : Icons.check_box_outline_blank,
              color: selected ? T.amber : T.dim,
              size: 20),
          onTap: () => setState(() {
            if (_squad.contains(member.id)) {
              _squad.remove(member.id);
            } else {
              if (_squad.length >= c.g.squadSlots) _squad.removeAt(0);
              _squad.add(member.id);
            }
          }),
        ));
  }
}
