import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';

/// The first second and a half: the lantern lights, the name comes up, and
/// camp fades in from under it. It covers loading the save, so the app never
/// opens on a blank frame, and it holds the camp music until it lifts, so the
/// track fades in over camp rather than starting cold.
///
/// The native launch window on both platforms is the same flat [T.black], so
/// the hand-off from the OS is invisible.
class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key, required this.child});

  final Widget child;

  static const intro = Duration(milliseconds: 1600);
  static const lift = Duration(milliseconds: 600);

  /// The intro waits for the lantern to decode, but no longer than this.
  static const decodeGrace = Duration(milliseconds: 250);

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen>
    with SingleTickerProviderStateMixin {
  late final _intro =
      AnimationController(vsync: this, duration: LaunchScreen.intro);
  late final GuildController _c;
  Timer? _grace;
  bool _lifting = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _c = context.read<GuildController>()..addListener(_maybeLift);
    _intro.addStatusListener((_) => _maybeLift());
    _grace = Timer(LaunchScreen.decodeGrace, _start);
  }

  void _start() {
    _grace?.cancel();
    if (!mounted || _intro.isAnimating || _intro.value > 0) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  /// Once the lantern is lit and the save is loaded, whichever is later.
  void _maybeLift() {
    if (_lifting || !_intro.isCompleted || !_c.ready) return;
    _c.removeListener(_maybeLift);
    setState(() => _lifting = true);
    _c.launchScreenLifted();
  }

  @override
  void dispose() {
    _grace?.cancel();
    _c.removeListener(_maybeLift);
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_gone)
          IgnorePointer(
            ignoring: _lifting,
            child: AnimatedOpacity(
              opacity: _lifting ? 0 : 1,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : LaunchScreen.lift,
              curve: Curves.easeOut,
              onEnd: () => setState(() => _gone = true),
              child: _Lantern(intro: _intro, onDecoded: _start),
            ),
          ),
      ],
    );
  }
}

class _Lantern extends StatelessWidget {
  const _Lantern({required this.intro, required this.onDecoded});

  final Animation<double> intro;
  final VoidCallback onDecoded;

  Animation<double> _part(double begin, double end, [Curve c = Curves.easeOut]) =>
      CurvedAnimation(parent: intro, curve: Interval(begin, end, curve: c));

  @override
  Widget build(BuildContext context) {
    final lantern = _part(0, .6, Curves.easeInOut);
    final glow = _part(.25, .9);
    final name = _part(.5, 1);
    // A Material, not a bare colour: above the Navigator there is no default
    // text style, and the wordmark would draw with the debug underline.
    return Material(
      key: const Key('launch-screen'),
      color: T.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 260,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // The flame catching: light pooling behind the glass.
                  FadeTransition(
                    opacity: glow,
                    // Square and wider than its slot, so the light runs out
                    // to nothing rather than to the edge of a box.
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, .08),
                          radius: .45,
                          colors: [
                            T.amber.withValues(alpha: .22),
                            T.amber.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: lantern,
                    child: Image.asset(
                      'assets/art/lantern.webp',
                      height: 120,
                      excludeFromSemantics: true,
                      frameBuilder: (context, child, frame, sync) {
                        if (frame != null || sync) {
                          WidgetsBinding.instance
                              .addPostFrameCallback((_) => onDecoded());
                        }
                        return child;
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FadeTransition(
              opacity: name,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, .3), end: Offset.zero)
                    .animate(name),
                child: Text(
                  'TELOS',
                  style: T.display.copyWith(letterSpacing: 10),
                  semanticsLabel: 'Telos',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
