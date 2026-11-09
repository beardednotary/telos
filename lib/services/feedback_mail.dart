import '../models/guild_state.dart';

/// The one way to reach whoever makes Telos.
///
/// Testers come in through a public TestFlight link, so they are anonymous
/// and cannot be written to. An email they start themselves is the channel
/// that works both ways, and it keeps the app free of a network call.
///
/// The draft asks three specific questions rather than "any feedback?",
/// which tends to get a blank page, and carries the build and iOS version
/// so a report can be matched to the binary it came from.
class FeedbackMail {
  static const address = 'telos@dahvio.com';

  static const questions = [
    'Did Telos help you start a piece of work you otherwise would have delayed?',
    'What was confusing or irritating during your last session?',
    'What made you come back, or what stopped you?',
  ];

  /// How the guild has been used, in counts only: no names, notes, places
  /// or times. It goes at the foot of the draft where the player can read
  /// it and delete it, which is the whole consent step. Recalls and cancels
  /// are the numbers the log alone cannot give: a run cut short, or a
  /// dispatch taken straight back, says more about the app than a finished
  /// one does.
  static String usageLine(GuildState g) => [
        '${g.expeditions} ${g.expeditions == 1 ? 'expedition' : 'expeditions'}',
        '${g.recalledRuns} recalled',
        '${g.cancelledRuns} cancelled',
        'opened on ${g.daysActive} ${g.daysActive == 1 ? 'day' : 'days'}',
      ].join(' · ');

  /// [build] is like "0.1.0 (32)"; [os] like "iOS 18.1"; [usage] is
  /// [usageLine], left out when there is no guild to describe.
  ///
  /// Encoded by hand: Uri's own query encoding turns spaces into "+", which
  /// iOS Mail shows literally.
  static Uri draft({required String build, required String os, String? usage}) {
    final body = [
      'Answer any of these, or none and just write.',
      '',
      for (final q in questions) ...[q, '', ''],
      '-',
      'Telos $build · $os',
      if (usage != null) ...[
        usage,
        '',
        'The lines above say which build this is and roughly how Telos has '
            'been used. Delete them if you would rather not send them.',
      ],
    ].join('\n');
    String enc(String s) => Uri.encodeComponent(s);
    return Uri.parse('mailto:$address'
        '?subject=${enc('Telos feedback')}&body=${enc(body)}');
  }
}
