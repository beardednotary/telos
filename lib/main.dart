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
import 'services/launch_actions.dart';
import 'services/lock_screen.dart';
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
      const ['IBM Plex Sans'],
      await rootBundle.loadString('assets/fonts/OFL-IBMPlexSans.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      const ['IBM Plex Sans Condensed'],
      await rootBundle.loadString('assets/fonts/OFL-IBMPlexSansCondensed.txt'),
    );
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

  final controller = GuildController(
    Persistence(),
    alerts: LocalAlerts(),
    lockScreen: SystemLockScreen(),
    launchActions: SystemLaunchActions(),
  );
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

/// Owns focus/return routing, including closing management pages when a
/// platform action starts a run above an existing navigation stack.
class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  String? _foreground;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final foreground = c.pendingDebrief != null
        ? 'return:${c.pendingDebrief!.id}'
        : c.hasActiveRun
            ? 'focus:${c.active!.id}'
            : null;
    if (foreground != _foreground) {
      _foreground = foreground;
      if (foreground != null) {
        // A widget/Shortcut can dispatch while a management route is open.
        // State routing must also close routes sitting above this root.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _foreground == foreground) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
      }
    }
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
