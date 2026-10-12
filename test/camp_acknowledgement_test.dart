import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telos/theme/telos_theme.dart';
import 'package:telos/widgets/camp_acknowledgement.dart';

/// The point of these over a SnackBar is that they wait. A notice that
/// times out is a notice the player can miss entirely, which is how these
/// moments came to feel like nothing.
void main() {
  testWidgets('an acknowledgement waits to be dismissed', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: T.theme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showCampAcknowledgement(
                context,
                kicker: 'A NEW HAND',
                title: 'ODRIN',
                mark: const SizedBox(width: 72, height: 72),
                lines: const ['Ready to send out.'],
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));

    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.text('ODRIN'), findsOneWidget);
    expect(find.text('Ready to send out.'), findsOneWidget);

    // Four seconds is longer than any SnackBar lives. It is still there.
    await t.pump(const Duration(seconds: 4));
    expect(find.text('ODRIN'), findsOneWidget,
        reason: 'an acknowledgement must not time out the way a notice does');

    await t.tap(find.text('Back to camp'));
    await t.pumpAndSettle();
    expect(find.text('ODRIN'), findsNothing);
  });
}
