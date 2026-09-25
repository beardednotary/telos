import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';

/// The field manual.
///
/// A new player sees a guild, two members, three currencies and a sector, and
/// nothing tells them the one rule the entire product rests on: opening the
/// app does not advance the game, not opening it does. Miss that and this is
/// a pomodoro timer with nice typography, which is the category it exists to
/// escape. So it is stated, once, in the first thirty seconds.
///
/// Shown on first run, and reachable again from FACILITIES.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.asReview = false});

  /// True when resurfaced from the outpost rather than shown on first run.
  final bool asReview;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;

  static const _panels = <_Panel>[
    _Panel(
      kicker: 'I  //  THE ONE RULE',
      title: 'Not opening this\nis how you play',
      body: [
        'Opening the app does not advance the game. Putting it down does.',
        'You commit a block of time. Your squad goes out for exactly that '
            'long, and you get on with your work.',
        'Nothing accumulates while you watch it. There is nothing to tap, '
            'nothing to collect, nothing to check.',
      ],
    ),
    _Panel(
      kicker: 'II  //  INTEGRITY',
      title: 'The run is\nwatching you back',
      body: [
        'Every expedition starts at 100% integrity.',
        'Time spent looking at the timer costs it. Reopening the app before '
            'the run ends costs more. Locking the phone costs nothing at all '
            '- being away is the point.',
        'Integrity barely touches what they carry home, but it drives rare '
            'finds hard. A clean run is where the good things come from.',
      ],
    ),
    _Panel(
      kicker: 'III  //  WHAT COMES BACK',
      title: 'Each run\nfunds the next',
      body: [
        'Salvage does nothing sitting in the vault. Assign it to a member in '
            'ROSTER - two pieces each - and it raises what that member brings '
            'home from then on.',
        'Resources go into the outpost. Facilities raise every run, recruits '
            'add archetypes, and INTEL opens new sectors and feeds the forge.',
        'So a good session is not just a good session. It is the reason the '
            'next one pays more.',
      ],
    ),
    _Panel(
      kicker: 'IV  //  THE GUILD',
      title: 'Time buys\nthe map',
      body: [
        'Every sector needs a minimum length. Come back short and the squad '
            'brings scraps - which is what makes one long block different '
            'from three short ones.',
        'Members suit different lengths. A scout is wasted on two hours; a '
            'vanguard is wasted on fifteen minutes.',
        'Spend what they bring back on the outpost, and it opens further.',
      ],
    ),
  ];

  /// Only in the reopened manual. On the first run there is nothing to send
  /// again yet, so this would be a page about a feature the player cannot
  /// use, standing between them and the outpost.
  static const _sendAgain = _Panel(
    kicker: 'V  //  SEND AGAIN',
    title: 'Skip the\ndispatch screen',
    body: [
      'Your last three dispatches wait under DISPATCH on the outpost. One tap '
          'sends the squad; there is nothing to choose.',
      'The same three are on the Telos icon: press and hold it.',
      'On iPhone, the Shortcuts app has a Dispatch action. Attach it to a Focus '
          'and turning the Focus on sends them out.',
    ],
  );

  List<_Panel> get _shown =>
      widget.asReview ? const [..._panels, _sendAgain] : _panels;

  @override
  void initState() {
    super.initState();
    if (!widget.asReview) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<GuildController>().noteManualSeen(),
      );
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    if (widget.asReview) {
      Navigator.pop(context);
      return;
    }
    await context.read<GuildController>().completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _shown.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: ScrollFrame(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _shown.length,
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _index = i);
                    },
                    itemBuilder: (_, i) => _PanelView(panel: _shown[i]),
                  ),
                ),

                // Position, drawn as marks rather than dots.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _shown.length; i++)
                      Container(
                        width: i == _index ? 22 : 8,
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        color: i == _index ? T.amber : T.line,
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: last
                        ? _finish
                        : () {
                            HapticFeedback.selectionClick();
                            _pages.nextPage(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                            );
                          },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: T.amber.withValues(alpha: last ? 0.14 : 0.0),
                        border: Border.all(color: T.amber, width: last ? 1.4 : 1),
                      ),
                      child: Text(
                        last
                            ? (widget.asReview ? 'CLOSE' : 'OPEN THE OUTPOST')
                            : 'CONTINUE',
                        style: T.mono.copyWith(
                          color: T.amber,
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel {
  const _Panel({
    required this.kicker,
    required this.title,
    required this.body,
  });
  final String kicker;
  final String title;
  final List<String> body;
}

class _PanelView extends StatelessWidget {
  const _PanelView({required this.panel});
  final _Panel panel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 20),
      children: [
        Text(panel.kicker, style: T.micro.copyWith(color: T.amber)),
        const SizedBox(height: 16),
        Text(panel.title, style: T.title.copyWith(fontSize: 27)),
        const SizedBox(height: 22),
        const Flourish(),
        const SizedBox(height: 22),
        for (final line in panel.body)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              line,
              style: T.mono.copyWith(fontSize: 16, height: 1.7, color: T.text),
            ),
          ),
      ],
    );
  }
}

/// A rule broken by a diamond. Used between the title and the body.
class Flourish extends StatelessWidget {
  const Flourish({super.key, this.color = T.amber});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 9,
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.4))),
          const SizedBox(width: 10),
          Transform.rotate(
            angle: 0.785398,
            child: Container(width: 6, height: 6, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}

/// A double border with cut corners and a diamond at the head and foot.
///
/// Ornate enough to read as a document rather than a dialog, drawn rather
/// than illustrated so it costs nothing and scales anywhere.
class ScrollFrame extends StatelessWidget {
  const ScrollFrame({super.key, required this.child, this.color = T.amber});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScrollFramePainter(color),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _ScrollFramePainter extends CustomPainter {
  _ScrollFramePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const cut = 18.0; // corner chamfer
    const inset = 6.0;

    final outer = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.miter;
    final inner = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    Path frame(double i, double c) => Path()
      ..moveTo(i + c, i)
      ..lineTo(w - i - c, i)
      ..lineTo(w - i, i + c)
      ..lineTo(w - i, h - i - c)
      ..lineTo(w - i - c, h - i)
      ..lineTo(i + c, h - i)
      ..lineTo(i, h - i - c)
      ..lineTo(i, i + c)
      ..close();

    canvas.drawPath(frame(0.7, cut), outer);
    canvas.drawPath(frame(inset, cut - inset), inner);

    // Head and foot diamonds, sitting on the outer rule.
    final fill = Paint()..color = color;
    void diamond(double cx, double cy, double r) {
      canvas.drawPath(
        Path()
          ..moveTo(cx, cy - r)
          ..lineTo(cx + r, cy)
          ..lineTo(cx, cy + r)
          ..lineTo(cx - r, cy)
          ..close(),
        fill,
      );
    }

    // Break the rule behind each diamond so it reads as set into the border.
    final clear = Paint()..color = T.black;
    for (final cy in [0.7, h - 0.7]) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(w / 2, cy), width: 26, height: 3),
        clear,
      );
      diamond(w / 2, cy, 5);
    }
  }

  @override
  bool shouldRepaint(covariant _ScrollFramePainter old) => old.color != color;
}
