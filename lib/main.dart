import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/debrief_screen.dart';
import 'screens/home_screen.dart';
import 'screens/session_screen.dart';
import 'services/persistence.dart';
import 'state/guild_controller.dart';
import 'theme/telos_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: T.black,
  ));

  final controller = GuildController(Persistence());
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
    if (c.pendingDebrief != null) {
      return DebriefScreen(record: c.pendingDebrief!);
    }
    if (c.hasActiveRun) {
      return const SessionScreen();
    }
    return const HomeScreen();
  }
}
