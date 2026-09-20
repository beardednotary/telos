import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/guild_state.dart';

/// Single-blob JSON save. Small enough for SharedPreferences for a long while;
/// swap for a file under path_provider if the log ever gets big.
class Persistence {
  static const _key = 'telos.save.v1';

  Future<GuildState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return GuildState.fresh();
    try {
      return GuildState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A corrupt save should never brick the app.
      return GuildState.fresh();
    }
  }

  Future<void> save(GuildState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> wipe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
