# Launch identity and later cosmetics

## Confirmed

The user selected **Night Watch for launch**. It is now the default in the interactive prototype: IBM Plex Sans Condensed titles, IBM Plex Sans reading/controls, JetBrains Mono figures, charcoal panels and a brass accent. Keep the approved preparation, quiet focus and return loop.

The user also explicitly wants to change their guild's name and sigil. The prototype demonstrates an optional editor behind the guild header at camp: a name, four starter marks, and Save/Cancel. This does not interrupt first dispatch or require a faction choice. As with the rest of this prototype, the changes last only in memory; nothing has been added to the Flutter app yet.

## Recommended launch scope

- Include Night Watch as Telos's launch identity. Keep the other two treatments in reserve rather than presenting three competing visual identities in onboarding.
- Include free guild naming/renaming and a small free sigil set. The example offers Lantern, Compass, Branch and Anvil. These are identity, with no effect on yield, Integrity, class windows or expedition access.
- Let someone keep the starting name and sigil and get straight to work. Editing remains available at camp, without a rename currency, cooldown or repeated setup requirement.
- Keep ordinary readability preferences separate from collectible cosmetics. If a light treatment is added for comfort/accessibility, make that a free Night Watch variant. A paid cosmetic pack should offer a distinct aesthetic rather than be the sole way to obtain a usable contrast or lightness setting.

Night Watch is the confirmed choice. The free/premium split here is a recommendation, not an approved sales plan.

## Hold the other two for later

The root README already puts cosmetic terminal themes and IAP outside V1, after retention is proven. Its monetization rule is that purchases can expand or customize the game, while focus generates progression. Retaining Survey Office and Woodcut for later fits that boundary.

Develop them into coherent cosmetic packs if players show interest. A pack could contain its typography/palette treatment, matching banner and sigil designs, a camp illustration variant, and report/share-card decoration. A purchase preview should show the exact contents. Let players combine an owned UI treatment with their own guild name and emblem. A pure recolor may be a small optional purchase, but these directions could offer a stronger sense of value as complete art treatments.

Prefer a one-time permanent unlock for each pack over a recurring subscription for a fixed visual treatment. Apple's non-consumable category is designed for a product bought once that does not expire or diminish with use: [Apple's IAP type reference](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-types/). StoreKit setup, restoration, prices and product definitions are outside this design prototype; no store or products have been created.

Keep cosmetic packs free of resource multipliers, paid Integrity protection, session skips or exclusive stronger guilds. This follows the existing README. Future production packs also need complete coverage of dialogs, empty/error states, settings, contrast and text scaling; the four-screen study is not a finished paid skin.

## Guilds, houses and belonging

There is a promising emotional idea in the user's house analogy: a symbol, a tradition and a shared identity. Telos already gives the player their own guild. A later affiliation could therefore be an expedition **order** or **tradition** that a custom-named guild follows, instead of replacing the player's guild with a preset house.

For an early cosmetic version, an affiliation could suggest a crest, livery, a short passage of lore and a camp banner. Let the player choose it, edit their guild identity and change the visual treatment independently. Do not bind duration preference, progression bonuses or paid advantages to the affiliation. This keeps someone from needing to research the "best house" before their first focus session.

A few authored traditions are more meaningful than attaching house labels to the three color themes. World lore, social affiliation, unique quests or faction mechanics would be separate additions requiring their own design. No traditions, house names or faction mechanics are committed for launch.

## Existing repo support and implementation boundary

- `GuildState.guildName` already persists the name and participates in backups. `GuildController.renameGuild` already trims, uppercases, saves and notifies. The current `lib/` search found no screen calling that method. The missing piece is an accessible editing surface; the case-preserving prototype also proposes a different display convention.
- Current sigil geometry identifies sectors and adventurer classes. It is not a persisted user-selectable guild sigil system. Production guild marks should have their own stable IDs, fallback for old saves, serialization/backup coverage, and appropriate display in guild headers and shared reports.
- The prototype's 32-character limit and four starter marks are concrete review choices, not production schema changes. Blank names cannot be saved; Cancel/Escape discards the draft; changing a name or sigil never generates earnings or changes a forecast.
- The new editor is available at camp only. The active session still has no management entry or live rewards.
- The Flutter app and root README are untouched. The selected art direction and identity editor are reviewable in [the prototype](expedition-prototype/index.html) and [the identity screenshot](expedition-prototype/guild-identity.png).
