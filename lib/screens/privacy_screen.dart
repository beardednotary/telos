import 'package:flutter/material.dart';

import '../services/privacy_policy.dart';
import '../theme/telos_theme.dart';

/// The whole privacy policy, read from the bundle so it is there offline -
/// the same text as the hosted page App Store Connect links to.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Privacy policy')),
        body: SafeArea(
          top: false,
          child: FutureBuilder<String>(
            future: DefaultAssetBundle.of(context)
                .loadString(PrivacyPolicy.asset),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final policy = PrivacyPolicy.parse(snap.data!);
              return ListView(
                key: const Key('privacy-policy'),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Text(policy.title, style: T.display),
                  const SizedBox(height: 6),
                  Text(policy.effective, style: T.secondary),
                  for (final b in policy.blocks) _block(b),
                  const SizedBox(height: 24),
                  Text('Also at ${PrivacyPolicy.url.replaceFirst('https://', '')}',
                      style: T.secondary),
                ],
              );
            },
          ),
        ),
      );

  Widget _block(PolicyBlock b) => switch (b.kind) {
        PolicyBlockKind.heading => Padding(
            padding: const EdgeInsets.only(top: 28, bottom: 4),
            child: Text(b.lines.single, style: T.title),
          ),
        PolicyBlockKind.paragraph => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(b.lines.single, style: T.body),
          ),
        PolicyBlockKind.list => Column(children: [
            for (final item in b.lines)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: T.body.copyWith(color: T.amber)),
                      Expanded(child: Text(item, style: T.body)),
                    ]),
              ),
          ]),
      };
}
