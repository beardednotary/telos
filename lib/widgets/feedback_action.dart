import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/guild_state.dart';
import '../services/feedback_mail.dart';
import 'management_widgets.dart';

/// Opens a feedback draft in Mail, from Settings or from camp's one-time
/// invitation. With no mail account set up there is nothing to open, so the
/// address goes on the clipboard instead.
///
/// [openMail] is `launchUrl` in the app; tests pass their own.
Future<void> sendFeedback(
  BuildContext context,
  GuildState g, {
  Future<bool> Function(Uri) openMail = launchUrl,
}) async {
  var build = '';
  try {
    final info = await PackageInfo.fromPlatform();
    build = '${info.version} (${info.buildNumber})';
  } catch (_) {}
  final os = Platform.isIOS
      ? 'iOS ${Platform.operatingSystemVersion}'
      : Platform.operatingSystem;
  var opened = false;
  try {
    opened = await openMail(FeedbackMail.draft(
        build: build, os: os, usage: FeedbackMail.usageLine(g)));
  } catch (_) {}
  if (opened || !context.mounted) return;
  await Clipboard.setData(const ClipboardData(text: FeedbackMail.address));
  if (context.mounted) {
    campNotice(context,
        'No mail account is set up. ${FeedbackMail.address} is copied.');
  }
}
