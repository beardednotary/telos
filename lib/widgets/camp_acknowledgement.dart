import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/telos_theme.dart';
import 'camp_controls.dart';
import 'expedition_widgets.dart';

/// What camp says back when something changes standing.
///
/// Recruiting, opening a sector, finishing a project and forging a piece
/// were all acknowledged with a bare SnackBar: a line of system text that
/// times out whether or not anyone read it. These are the moments the loop
/// pays out into - the debrief already gives a find and a guild level a
/// card with a mark, a name and what it changed, and there is no reason the
/// camp side of the same loop should whisper.
///
/// Deliberately the same shape as that card, so the app has one language
/// for "something changed" rather than two. Dismissed by the player, not by
/// a timer.
///
/// Frequent, low-stakes confirmations - claiming a contract, where the
/// board updates in front of you anyway - keep using [campNotice]. A thing
/// that happens constantly stops reading as an occasion if it takes the
/// screen each time.
Future<void> showCampAcknowledgement(
  BuildContext context, {
  required String kicker,
  required String title,
  required Widget mark,
  List<String> lines = const [],
}) {
  HapticFeedback.mediumImpact();
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      // Scrolls as a whole, the way camp reviews do. At the largest text
      // sizes on the smallest phone this content is taller than the screen,
      // and an acknowledgement whose dismiss button cannot be reached is
      // worse than the notice it replaced.
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
        child: SingleChildScrollView(
          child: ExpeditionPanel(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(kicker,
                  textAlign: TextAlign.center,
                  style: T.label.copyWith(color: T.amber)),
              const SizedBox(height: 16),
              Center(child: mark),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: T.display),
              if (lines.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child:
                        Text(line, textAlign: TextAlign.center, style: T.body),
                  ),
              ],
              const SizedBox(height: 18),
              CampButton(
                  label: 'Back to camp',
                  onPressed: () => Navigator.pop(context)),
            ],
          )),
        ),
      ),
    ),
  );
}
