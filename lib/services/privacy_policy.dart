/// The privacy policy, from `assets/legal/privacy_policy.txt`.
///
/// One text, two places: the Settings screen reads it from the bundle, and
/// `tool/privacy_page.py` turns it into the page hosted at
/// dahvio.com/telos/privacy. A test fails if the two drift apart.
///
/// The format is deliberately small: a title line, an effective-date line,
/// then blocks separated by blank lines. A block starting `## ` is a heading;
/// a block of `- ` lines is a list; anything else is a paragraph.
class PrivacyPolicy {
  const PrivacyPolicy(this.title, this.effective, this.blocks);
  final String title;
  final String effective;
  final List<PolicyBlock> blocks;

  static const asset = 'assets/legal/privacy_policy.txt';
  static const url = 'https://dahvio.com/telos/privacy';

  factory PrivacyPolicy.parse(String text) {
    final chunks = text
        .replaceAll('\r\n', '\n')
        .trim()
        .split(RegExp(r'\n\s*\n'))
        .map((c) => c.trim())
        .toList();
    final head = chunks.first.split('\n');
    return PrivacyPolicy(head[0].trim(), head[1].trim(), [
      for (final c in chunks.skip(1))
        if (c.startsWith('## '))
          PolicyBlock.heading(c.substring(3).trim())
        else if (c.startsWith('- '))
          PolicyBlock.list([
            for (final line in c.split('\n')) line.trim().substring(2).trim(),
          ])
        else
          PolicyBlock.paragraph(c.replaceAll('\n', ' ')),
    ]);
  }
}

enum PolicyBlockKind { heading, paragraph, list }

class PolicyBlock {
  const PolicyBlock._(this.kind, this.lines);
  PolicyBlock.heading(String text) : this._(PolicyBlockKind.heading, [text]);
  PolicyBlock.paragraph(String text)
      : this._(PolicyBlockKind.paragraph, [text]);
  PolicyBlock.list(List<String> items) : this._(PolicyBlockKind.list, items);

  final PolicyBlockKind kind;
  final List<String> lines;
}
