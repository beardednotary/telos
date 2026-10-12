Salvage plates go here, named `<gear id>.webp`. The seven epics first:

    ore_sense.webp  quiet_seal.webp  null_core.webp  first_light.webp
    spire_sigil.webp  telos_lens.webp  last_charter.webp

Prompts and the style lock: `docs/design/gear-art/prompts.md`.
Deliver square at 640px, WebP quality 86 — about 40 KB each.

An item with no plate falls back to its GearMark engraving, so these can
land one at a time with no code change. The remaining twelve items are
listed in content.dart.

spire_sigil, telos_lens and last_charter are endgame spoilers. Keep them
out of store listings and previews.
