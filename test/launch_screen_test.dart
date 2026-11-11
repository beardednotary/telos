import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/screens/launch_screen.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(WidgetTester t) async {
    final c = GuildController(Persistence(), launchScreen: true);
    addTearDown(c.dispose);
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(
          theme: T.theme(),
          home: const LaunchScreen(child: SizedBox.shrink())),
    ));
  }

  double lanternOpacity(WidgetTester t) => t
      .widget<FadeTransition>(find
          .ancestor(of: find.byType(Image), matching: find.byType(FadeTransition))
          .first)
      .opacity
      .value;

  testWidgets('on iOS the lantern is already showing, like the native screen',
      (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await open(t);
      expect(lanternOpacity(t), 1);
      // Held until the lantern decodes, or the grace runs out.
      expect(t.binding.sendFramesToEngine, isFalse);
      await t.pump(LaunchScreen.decodeGrace);
      expect(t.binding.sendFramesToEngine, isTrue);
      expect(lanternOpacity(t), 1);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('on Android the lantern fades in from the flat window',
      (t) async {
    await open(t);
    expect(lanternOpacity(t), 0);
    expect(t.binding.sendFramesToEngine, isTrue);
  });
}
