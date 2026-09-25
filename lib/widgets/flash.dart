import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/telos_theme.dart';
import 'sigil.dart';

/// An acknowledgement.
///
/// Spending resources and crossing thresholds are the moments the whole loop
/// builds to, and they were happening silently - a number changed and nothing
/// else. This is the smallest honest fix: say what just happened, say what it
/// gave you, and get out of the way.
void showFlash(
  BuildContext context, {
  required String kicker,
  required String title,
  List<String> lines = const [],
  Color color = T.amber,
  bool heavy = false,
  String? sigilSectorId,
}) {
  // On a phone this is most of the feeling.
  if (heavy) {
    HapticFeedback.heavyImpact();
  } else {
    HapticFeedback.mediumImpact();
  }

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: Duration(milliseconds: heavy ? 3600 : 2600),
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: Container(
          decoration: BoxDecoration(
            color: T.card,
            border: Border.all(color: color, width: 1.4),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: color),
                if (sigilSectorId != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
                    child: Sigil(
                        sectorId: sigilSectorId,
                        color: color,
                        size: 34,
                        animate: true),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(kicker, style: T.micro.copyWith(color: color)),
                        const SizedBox(height: 5),
                        Text(title, style: T.title.copyWith(fontSize: 18)),
                        for (final l in lines) ...[
                          const SizedBox(height: 5),
                          Text(l,
                              style: T.mono.copyWith(
                                  fontSize: 13, color: T.good, height: 1.4)),
                        ],
                      ],
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
