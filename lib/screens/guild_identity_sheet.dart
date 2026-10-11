import 'package:flutter/material.dart';

import '../models/guild_identity.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/camp_controls.dart';
import '../widgets/guild_sigil.dart';

Future<void> showGuildIdentity(
        BuildContext context, GuildController controller) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GuildIdentitySheet(controller: controller),
    );

class GuildIdentitySheet extends StatefulWidget {
  const GuildIdentitySheet({super.key, required this.controller});
  final GuildController controller;

  @override
  State<GuildIdentitySheet> createState() => _GuildIdentitySheetState();
}

class _GuildIdentitySheetState extends State<GuildIdentitySheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.controller.g.guildName);
  late GuildSigil _sigil = widget.controller.g.guildSigil;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.updateGuildIdentity(_name.text, _sigil);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save your guild. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (media.size.height * .9 - media.viewInsets.bottom)
                .clamp(100.0, media.size.height),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Your guild', style: T.display),
                  const SizedBox(height: 8),
                  Text('A name and a mark to carry into the field.',
                      style: T.secondary),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const Key('guild-name'),
                    controller: _name,
                    enabled: !_saving,
                    style: T.body,
                    maxLength: guildNameLimit,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Guild name'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Give your guild a name.'
                        : value.trim().characters.length > guildNameLimit
                            ? 'Use up to $guildNameLimit characters.'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  Text('GUILD SIGIL', style: T.label),
                  const SizedBox(height: 12),
                  LayoutBuilder(builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 330 &&
                            media.textScaler.scale(16) <= 20
                        ? 4
                        : 2;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 8) / columns;
                    return Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final sigil in GuildSigil.values)
                        SizedBox(
                          width: width,
                          child: Semantics(
                            selected: sigil == _sigil,
                            child: OutlinedButton(
                              key: Key('sigil-${sigil.name}'),
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _sigil = sigil),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 4),
                                backgroundColor:
                                    sigil == _sigil ? T.raised : T.card,
                                foregroundColor: T.text,
                                side: BorderSide(
                                    color:
                                        sigil == _sigil ? T.amber : T.boundary),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(3)),
                              ),
                              child: Column(children: [
                                ExcludeSemantics(
                                    child: GuildEmblem(sigil: sigil)),
                                const SizedBox(height: 8),
                                Text(sigil.label,
                                    style: T.secondary.copyWith(color: T.text)),
                                const SizedBox(height: 4),
                                Icon(
                                    sigil == _sigil
                                        ? Icons.check
                                        : Icons.remove,
                                    size: 14,
                                    color: sigil == _sigil ? T.amber : T.dim),
                              ]),
                            ),
                          ),
                        ),
                    ]);
                  }),
                  const SizedBox(height: 12),
                  Text('You can change these whenever you are at camp.',
                      style: T.secondary),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: T.body.copyWith(color: T.bad)),
                  ],
                  const SizedBox(height: 24),
                  CampButton(
                    key: const Key('save-guild'),
                    label: _saving ? 'Saving…' : 'Save guild',
                    primary: true,
                    onPressed: _saving ? null : _save,
                  ),
                  const SizedBox(height: 8),
                  CampButton(
                      label: 'Cancel',
                      onPressed: _saving ? null : () => Navigator.pop(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
