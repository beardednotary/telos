import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/guild_state.dart';

/// Single-blob JSON save. Small enough for SharedPreferences for a long while;
/// swap for a file under path_provider if the log ever gets big.
class Persistence {
  static const _key = 'telos.save.v1';

  /// A save that could not be read is copied here, under the time it was
  /// found, before anything can write over it. The app never deletes these:
  /// one may be the only copy of months of work, and a later version may be
  /// able to read what this one cannot.
  static const _unreadablePrefix = 'telos.save.v1.unreadable.';

  /// The kept save the player has not been told about yet.
  static const _unreadableNotice = 'telos.save.v1.unreadableNotice';

  Future<GuildState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return GuildState.fresh();
    try {
      return GuildState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A corrupt save should never brick the app, and it must not be lost
      // either: boot saves the fresh guild over [_key] straight away, so the
      // original goes somewhere nothing writes first.
      final kept = '$_unreadablePrefix${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(kept, raw);
      await prefs.setString(_unreadableNotice, kept);
      return GuildState.fresh();
    }
  }

  /// The kept save the player has not been told about, exactly as it was
  /// found. Null when there is nothing to tell.
  Future<String?> unreadableSave() async {
    final prefs = await SharedPreferences.getInstance();
    final kept = prefs.getString(_unreadableNotice);
    return kept == null ? null : prefs.getString(kept);
  }

  /// The player has been told. The save itself stays where it was put.
  Future<void> dismissUnreadableSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_unreadableNotice);
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
