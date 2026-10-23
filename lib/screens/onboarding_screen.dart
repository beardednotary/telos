import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/gear_mark.dart';
import '../widgets/camp_controls.dart';
import '../widgets/expedition_widgets.dart';

/// The first-launch briefing, and the full field manual under Settings.
///
/// First launch is deliberately three lines. A tester's first word on the
/// old five-panel briefing was "overwhelming", and nothing in it was needed
/// before the first run: the dispatch arrives pre-filled, Integrity is
/// explained on the timer, and gear goes on by itself. Everything the long
/// manual says is still here, as [asReview], for anyone who wants it.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.asReview = false});
  final bool asReview;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;
  bool _moving = false;

  static const _panels = <_Panel>[
    _Panel(
      label: 'THE ONE RULE',
      title: 'A game you put down.',
      body: [
        'Choose a task, a duration and a squad. They head into the field while you get on with your work.',
        'Put Telos aside during the session. Their discoveries are waiting when you return.',
        'Between expeditions, time alone earns nothing.',
      ],
      image: _campArt,
    ),
    _Panel(
      label: 'INTEGRITY',
      title: 'Keep the time you set.',
      body: [
        'Every expedition starts at 100% Integrity. Time spent in Telos and reopening it during a run reduce that score.',
        'Locking the phone or leaving Telos preserves Integrity.',
        'Telos measures its own screen time. It cannot tell which other apps you use. Your work report is on the honour system.',
      ],
      integrity: true,
    ),
    _Panel(
      label: 'YOUR PACE',
      title: 'Use the time you have.',
      body: [
        'Consistent 25-minute sessions build supplies, equipment and guild experience. Longer blocks can reach deeper sectors.',
        'Choose the duration that works for your work. Then choose a destination your squad can reach in that time.',
        'Members favour different session lengths. Their class and equipment change what comes home; the dispatch screen shows the tradeoffs.',
      ],
      detailTitle: 'Returning early',
      detail:
          'You can cancel a mistaken dispatch during the first 30 seconds. After that, recalling ends the expedition. Return before the sector minimum and the squad brings credits only: no alloy, intel or equipment.',
    ),
    _Panel(
      label: 'BACK AT CAMP',
      title: 'Each run funds the next.',
      body: [
        'Credits pay for recruits, upgrades and crafting. Alloy builds facilities and equipment. Intel opens sectors and feeds the forge.',
        'Assign recovered gear to your members: two pieces each. Equipment only helps when its wearer is deployed.',
        'Plan, equip and spend at camp. When you are ready for another focus session, send them out again.',
      ],
      gear: true,
    ),
  ];

  static const _campArt = 'assets/art/camp.webp';

  /// An hourglass running at the edge of camp with nobody watching it: the
  /// sand falls whether you look or not. Optional - until the file is in
  /// the bundle the page simply has no picture.
  static const _hourglassArt = 'assets/art/onboarding-hourglass.webp';

  /// One line each. Teach the loop, then get out of the way.
  static const _firstRun = <_Panel>[
    _Panel(
      label: 'THE ONE RULE',
      title: 'A game you put down.',
      body: [
        'Send a squad out, then put your phone down and work. They come back '
            'with whatever they found.',
      ],
      image: _campArt,
    ),
    _Panel(
      label: 'INTEGRITY',
      title: 'Leave it alone.',
      image: _hourglassArt,
      body: [
        'Checking on them costs the squad. Locking your phone costs nothing.',
      ],
    ),
    _Panel(
      label: 'BACK AT CAMP',
      title: 'Each run funds the next.',
      body: [
        'Spend what they bring home, then send them out again. The rest '
            'explains itself as you find it.',
      ],
      gear: true,
    ),
  ];

  static const _repeat = _Panel(
    label: 'REPEAT A DISPATCH',
    title: 'A familiar departure.',
    body: [
      'Repeat your latest expedition from the bottom of camp. Your last three plans are under Squad & equipment.',
      'Repeat starts the timer immediately with the saved duration, destination and squad. Use Plan an expedition when you want to change something.',
      'Press and hold the Telos app icon for recent dispatches. On iPhone, the Shortcuts app also has a Dispatch action.',
    ],
    detailTitle: 'Using an iPhone Focus',
    detail:
        'Add the Telos Dispatch action to a personal automation in Shortcuts, triggered when your chosen Focus turns on. Telos must have a completed onboarding and a previous dispatch to repeat.',
  );

  List<_Panel> get _shown =>
      widget.asReview ? const [..._panels, _repeat] : _firstRun;

  @override
  void initState() {
    super.initState();
    if (!widget.asReview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<GuildController>().noteManualSeen();
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _move(int delta) async {
    if (_moving) return;
    setState(() => _moving = true);
    HapticFeedback.selectionClick();
    try {
      await _pages.animateToPage(
        _index + delta,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } finally {
      if (mounted) setState(() => _moving = false);
    }
  }

  Future<void> _finish() async {
    if (_moving) return;
    setState(() => _moving = true);
    HapticFeedback.mediumImpact();
    if (widget.asReview) {
      Navigator.pop(context);
      return;
    }
    await context.read<GuildController>().completeOnboarding();
    if (mounted) setState(() => _moving = false);
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _shown.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Field manual'),
        automaticallyImplyLeading: widget.asReview,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
                child:
                    Text('${_index + 1} / ${_shown.length}', style: T.label)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _shown.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (_, index) =>
                  _PanelView(key: ValueKey(index), panel: _shown[index]),
            ),
          ),
          ExpeditionFooter(
              child: Column(children: [
            CampButton(
              key: const Key('manual-next'),
              label: last
                  ? (widget.asReview ? 'Close manual' : 'Open camp')
                  : 'Continue',
              primary: true,
              onPressed: _moving
                  ? null
                  : last
                      ? _finish
                      : () => _move(1),
            ),
            if (_index > 0) ...[
              const SizedBox(height: 8),
              CampButton(
                label: 'Previous page',
                onPressed: _moving ? null : () => _move(-1),
              ),
            ],
          ])),
        ]),
      ),
    );
  }
}

class _Panel {
  const _Panel({
    required this.label,
    required this.title,
    required this.body,
    this.image,
    this.integrity = false,
    this.gear = false,
    this.detailTitle,
    this.detail,
  });
  final String label;
  final String title;
  final List<String> body;
  /// A wide illustration, cropped to a strip above the text.
  final String? image;
  final bool integrity;
  final bool gear;
  final String? detailTitle;
  final String? detail;
}

class _PanelView extends StatefulWidget {
  const _PanelView({super.key, required this.panel});
  final _Panel panel;

  @override
  State<_PanelView> createState() => _PanelViewState();
}

class _PanelViewState extends State<_PanelView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.panel;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(p.label, style: T.label.copyWith(color: T.amber)),
        const SizedBox(height: 12),
        Text(p.title, style: T.display.copyWith(fontSize: 34)),
        const SizedBox(height: 24),
        if (p.image case final image?)
          Image.asset(image,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              // A missing picture collapses rather than leaving a gap.
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              frameBuilder: (_, child, frame, wasSync) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: wasSync || frame != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: child)
                        : const SizedBox(height: 160),
                  )),
        if (p.gear) ...[
          const Center(child: GearMark(id: 'deep_lamp', size: 72)),
          const SizedBox(height: 24),
        ],
        for (final line in p.body)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(line, style: T.body),
          ),
        if (p.integrity || p.detail != null) ...[
          const SizedBox(height: 8),
          CampDisclosure(
            key: const Key('manual-detail'),
            title: p.integrity ? 'How Integrity works' : p.detailTitle!,
            summary: p.integrity
                ? 'Grace period, screen time & rewards'
                : 'Optional detail',
            icon: p.integrity ? Icons.shield_outlined : Icons.info_outline,
            expanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: p.integrity
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          for (final line in [
                            '30 seconds of grace after dispatch.',
                            '−1% per 30 seconds spent in Telos after that.',
                            '−4% each time you reopen it before the run ends.',
                            'Integrity never falls below 25%.',
                            'Lower Integrity reduces the resource haul and chance of finding equipment. Equipment rarity is rolled separately.',
                          ])
                            Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(line, style: T.body)),
                        ])
                  : Text(p.detail!, style: T.body),
            ),
          ),
        ],
      ],
    );
  }
}
