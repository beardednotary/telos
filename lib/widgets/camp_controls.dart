import 'package:flutter/material.dart';

import '../theme/telos_theme.dart';

class CampButton extends StatelessWidget {
  const CampButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: Size(0, primary ? 54 : 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            foregroundColor: primary ? T.onAccent : T.text,
            backgroundColor: primary ? T.amber : Colors.transparent,
            disabledBackgroundColor: primary ? T.raised : Colors.transparent,
            disabledForegroundColor: T.dim,
            textStyle: T.body.copyWith(fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
              side:
                  BorderSide(color: primary ? Colors.transparent : T.boundary),
            ),
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      );
}

/// The parent owns which section is open. Closed sections retain a summary.
class CampDisclosure extends StatelessWidget {
  const CampDisclosure({
    super.key,
    required this.title,
    required this.summary,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.leading,
  });
  final String title;
  final String summary;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Material(
        color: T.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: const BorderSide(color: T.boundary),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              expanded: expanded,
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    leading ?? Icon(icon, size: 23, color: T.text),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style:
                                T.body.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(summary, style: T.secondary),
                      ],
                    )),
                    const SizedBox(width: 8),
                    Icon(expanded ? Icons.expand_less : Icons.expand_more,
                        color: T.dim, size: 20),
                  ]),
                ),
              ),
            ),
            if (expanded) ...[const Divider(height: 1), child],
          ],
        ),
      );
}

class CampLink extends StatelessWidget {
  const CampLink({
    super.key,
    required this.title,
    required this.onTap,
    this.detail,
  });
  final String title;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        title: Text(title, style: T.body),
        subtitle: detail == null ? null : Text(detail!, style: T.secondary),
        trailing: const Icon(Icons.chevron_right, color: T.dim, size: 20),
        onTap: onTap,
      );
}
