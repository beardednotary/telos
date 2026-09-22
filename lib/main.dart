import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/debrief_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/session_screen.dart';
import 'services/alerts.dart';
import 'services/persistence.dart';
import 'state/guild_controller.dart';
import 'theme/telos_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // JetBrains Mono is SIL OFL 1.1. The licence has to travel with the font,
  // which the bundled asset already does; this puts it in Flutter's standard
  // licence registry too, rather than in a screen of the game.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['JetBrains Mono'],
      await rootBundle.loadString('assets/fonts/OFL.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      const ['Syne'],
      await rootBundle.loadString('assets/fonts/OFL-Syne.txt'),
    );
  });
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: T.black,
  ));

  final controller = GuildController(Persistence(), alerts: LocalAlerts());
  await controller.boot();

  runApp(
    ChangeNotifierProvider.value(value: controller, child: const TelosApp()),
  );
}

class TelosApp extends StatelessWidget {
  const TelosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telos',
      debugShowCheckedModeBanner: false,
      theme: T.theme(),
      home: const Root(),
    );
  }
}

/// Decides what the player sees on open. A live run always wins - you cannot
/// wander off into the roster while the squad is out.
class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    if (!c.ready) {
      return const Scaffold(body: SizedBox.shrink());
    }
    if (!c.g.onboarded) {
      return const OnboardingScreen();
    }
    if (c.pendingDebrief != null) {
      return DebriefScreen(record: c.pendingDebrief!);
    }
    if (c.hasActiveRun) {
      return const SessionScreen();
    }
    return const HomeScreen();
  }
}
