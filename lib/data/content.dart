import '../models/models.dart';

/// All game content lives here as plain data. Adding a sector, a class or a
/// piece of gear is a data edit, not a code change - that is the whole point
/// of the "zero art pipeline" approach.

// ---------------------------------------------------------------------------
// CLASSES
// Each class is tuned to a different session length. A 20-minute block and a
// 2-hour block should genuinely call for different squads.
// ---------------------------------------------------------------------------
const Map<String, ClassDef> kClasses = {
  'recon': ClassDef(
    id: 'recon',
    name: 'RECON',
    blurb: 'Fast, light, in and out. Built for short bursts of work.',
    base: Bonus(credits: 0.15, rare: 0.03, alloy: -0.05),
    windowMin: 10,
    windowMax: 30,
    windowBonus: Bonus(credits: 0.25, rare: 0.05),
    windowText: 'Excels on runs of 10-30 min',
    recruitCost: 0,
  ),
  'vanguard': ClassDef(
    id: 'vanguard',
    name: 'VANGUARD',
    blurb: 'Heavy, patient, hard to stop. Built for long hauls.',
    base: Bonus(alloy: 0.15, credits: 0.05, rare: -0.01),
    windowMin: 60,
    windowMax: 240,
    windowBonus: Bonus(alloy: 0.30, credits: 0.10),
    windowText: 'Excels on runs of 60 min and up',
    recruitCost: 0,
  ),
  'archivist': ClassDef(
    id: 'archivist',
    name: 'ARCHIVIST',
    blurb: 'Reads the ruins instead of looting them. Produces INTEL.',
    base: Bonus(intel: 0.20, credits: -0.10),
    windowMin: 45,
    windowMax: 180,
    windowBonus: Bonus(intel: 0.30, rare: 0.04),
    windowText: 'Excels on runs of 45 min and up',
    recruitCost: 650,
    unlockGuildLevel: 2,
  ),
  'artificer': ClassDef(
    id: 'artificer',
    name: 'ARTIFICER',
    blurb: 'Strips salvage for parts. Finds gear others walk past.',
    base: Bonus(alloy: 0.10, rare: 0.05),
    windowMin: 25,
    windowMax: 75,
    windowBonus: Bonus(alloy: 0.20, rare: 0.06),
    windowText: 'Excels on runs of 25-75 min',
    recruitCost: 1400,
    unlockGuildLevel: 4,
  ),
  'quartermaster': ClassDef(
    id: 'quartermaster',
    name: 'QUARTERMASTER',
    blurb: 'No specialism, no bad days. Steady on any length of run.',
    base: Bonus(credits: 0.08, alloy: 0.08, intel: 0.08, xp: 0.10),
    windowMin: 10,
    windowMax: 240,
    windowBonus: Bonus(xp: 0.10),
    windowText: 'Steady on any run length',
    recruitCost: 3200,
    unlockGuildLevel: 7,
  ),
};

// ---------------------------------------------------------------------------
// SECTORS
// minMinutes is the gate that makes long focus blocks meaningful.
// ---------------------------------------------------------------------------
const List<Sector> kSectors = [
  Sector(
    id: 'mosswood',
    name: 'MOSSWOOD VERGE',
    designation: 'SECTOR 01',
    blurb: 'Overgrown perimeter. Low risk, quick returns.',
    kind: 'RECON',
    minMinutes: 10,
    nominalMinutes: 25,
    creditsPerMin: 5.0,
    alloyPerMin: 0.45,
    intelPerMin: 0.10,
    baseRare: 0.16,
    lootPool: ['scav_cord', 'mossglass', 'field_optic', 'verge_charm'],
    journal: [
      'Perimeter clear. Squad moving on the old service road.',
      'Cut west through the treeline to avoid open ground.',
      'Found a cache under a collapsed relay mast.',
      'Light rain. Visibility poor but the ground is quiet.',
    ],
  ),
  Sector(
    id: 'blackstone',
    name: 'BLACKSTONE HOLLOW',
    designation: 'SECTOR 02',
    blurb: 'Collapsed extraction works. Alloy-rich, slow going.',
    kind: 'EXTRACTION',
    minMinutes: 25,
    nominalMinutes: 45,
    creditsPerMin: 4.2,
    alloyPerMin: 1.6,
    intelPerMin: 0.20,
    baseRare: 0.20,
    lootPool: ['hollow_pick', 'slag_brace', 'deep_lamp', 'ore_sense'],
    intelToUnlock: 60,
    journal: [
      'Descending the old shaft. Air is stale but breathable.',
      'Cross-beam gave way on level two. No injuries.',
      'Ore seam is richer than the survey suggested.',
      'Something moved in the lower gallery. Squad held position.',
    ],
  ),
  Sector(
    id: 'cinder',
    name: 'THE CINDER ARCHIVE',
    designation: 'SECTOR 03',
    blurb: 'A burned library that never finished burning. Dense with INTEL.',
    kind: 'ARCHIVE',
    minMinutes: 45,
    nominalMinutes: 70,
    creditsPerMin: 3.4,
    alloyPerMin: 0.60,
    intelPerMin: 1.30,
    baseRare: 0.24,
    lootPool: ['ash_ledger', 'archivist_optic', 'cinder_key', 'quiet_seal'],
    intelToUnlock: 320,
    guildLevelToUnlock: 3,
    journal: [
      'Stacks still standing. Most of it is legible.',
      'Transcribing the eastern wing. Slow work, good yield.',
      'Found a sealed reading room, untouched.',
      'The fire is still burning somewhere below. It has been years.',
    ],
  ),
  Sector(
    id: 'riftline',
    name: 'RIFTLINE DESCENT',
    designation: 'SECTOR 04',
    blurb: 'Past the last marked map. Only a long run gets anywhere.',
    kind: 'DEEP',
    minMinutes: 75,
    nominalMinutes: 110,
    creditsPerMin: 6.5,
    alloyPerMin: 1.4,
    intelPerMin: 1.10,
    baseRare: 0.34,
    lootPool: ['rift_anchor', 'null_core', 'descent_rig', 'first_light'],
    intelToUnlock: 1100,
    guildLevelToUnlock: 6,
    journal: [
      'Rope descent. Forty minutes before the first ledge.',
      'Instruments disagree with each other down here.',
      'Squad reports no sound at all. Not silence - absence.',
      'Charted two kilometres of new passage.',
    ],
  ),
  Sector(
    id: 'spire',
    name: 'THE SPIRE OF TELOS',
    designation: 'SECTOR 05',
    blurb: 'The reason the guild reopened. Bring everything.',
    kind: 'ASSAULT',
    minMinutes: 100,
    nominalMinutes: 150,
    creditsPerMin: 8.0,
    alloyPerMin: 2.0,
    intelPerMin: 2.0,
    baseRare: 0.45,
    lootPool: ['spire_sigil', 'telos_lens', 'last_charter'],
    intelToUnlock: 4000,
    guildLevelToUnlock: 12,
    journal: [
      'The approach alone takes an hour.',
      'Every floor is a different century.',
      'They are climbing. Nothing to report until they stop.',
    ],
  ),
];

Sector sectorById(String id) => kSectors.firstWhere((s) => s.id == id);

// ---------------------------------------------------------------------------
// GEAR
// Found on successful runs. Equipping it raises future yields - this is the
// compounding loop: focus -> gear -> better returns on the next focus.
// ---------------------------------------------------------------------------
const Map<String, GearDef> kGear = {
  // Sector 01
  'scav_cord': GearDef(
    id: 'scav_cord',
    name: 'SCAVENGER CORD',
    rarity: Rarity.common,
    bonus: Bonus(credits: 0.05),
    flavor: 'Frayed, but it holds.',
  ),
  'mossglass': GearDef(
    id: 'mossglass',
    name: 'MOSSGLASS SHARD',
    rarity: Rarity.common,
    bonus: Bonus(alloy: 0.06),
    flavor: 'Green where it should be clear.',
  ),
  'field_optic': GearDef(
    id: 'field_optic',
    name: 'FIELD OPTIC',
    rarity: Rarity.uncommon,
    bonus: Bonus(credits: 0.10, rare: 0.02),
    flavor: 'One cracked lens, still true.',
  ),
  'verge_charm': GearDef(
    id: 'verge_charm',
    name: 'VERGE CHARM',
    rarity: Rarity.rare,
    bonus: Bonus(credits: 0.14, xp: 0.10),
    flavor: 'Nobody remembers who carved it.',
  ),

  // Sector 02
  'hollow_pick': GearDef(
    id: 'hollow_pick',
    name: 'HOLLOW PICK',
    rarity: Rarity.common,
    bonus: Bonus(alloy: 0.08),
    flavor: 'Worn to the shape of a hand.',
  ),
  'slag_brace': GearDef(
    id: 'slag_brace',
    name: 'SLAG BRACE',
    rarity: Rarity.uncommon,
    bonus: Bonus(alloy: 0.14, credits: 0.04),
    flavor: 'Heavy. Worth it.',
  ),
  'deep_lamp': GearDef(
    id: 'deep_lamp',
    name: 'DEEP LAMP',
    rarity: Rarity.rare,
    bonus: Bonus(alloy: 0.16, rare: 0.04),
    flavor: 'Burns on something that is not oil.',
  ),
  'ore_sense': GearDef(
    id: 'ore_sense',
    name: 'ORE-SENSE RIG',
    rarity: Rarity.epic,
    bonus: Bonus(alloy: 0.25, rare: 0.06),
    flavor: 'It hums before you see the seam.',
  ),

  // Sector 03
  'ash_ledger': GearDef(
    id: 'ash_ledger',
    name: 'ASH LEDGER',
    rarity: Rarity.common,
    bonus: Bonus(intel: 0.08),
    flavor: 'Half the pages are still readable.',
  ),
  'archivist_optic': GearDef(
    id: 'archivist_optic',
    name: 'ARCHIVIST OPTIC',
    rarity: Rarity.uncommon,
    bonus: Bonus(intel: 0.14, rare: 0.02),
    flavor: 'Ground for reading, not for seeing.',
  ),
  'cinder_key': GearDef(
    id: 'cinder_key',
    name: 'CINDER KEY',
    rarity: Rarity.rare,
    bonus: Bonus(intel: 0.18, credits: 0.06),
    flavor: 'Warm to the touch, always.',
  ),
  'quiet_seal': GearDef(
    id: 'quiet_seal',
    name: 'QUIET SEAL',
    rarity: Rarity.epic,
    bonus: Bonus(intel: 0.26, xp: 0.12),
    flavor: 'Pressed into wax that never set.',
  ),

  // Sector 04
  'rift_anchor': GearDef(
    id: 'rift_anchor',
    name: 'RIFT ANCHOR',
    rarity: Rarity.uncommon,
    bonus: Bonus(credits: 0.12, alloy: 0.08),
    flavor: 'Holds to nothing and does not move.',
  ),
  'descent_rig': GearDef(
    id: 'descent_rig',
    name: 'DESCENT RIG',
    rarity: Rarity.rare,
    bonus: Bonus(credits: 0.16, xp: 0.14),
    flavor: 'Rated for depths nobody has measured.',
  ),
  'null_core': GearDef(
    id: 'null_core',
    name: 'NULL CORE',
    rarity: Rarity.epic,
    bonus: Bonus(credits: 0.20, intel: 0.20, rare: 0.05),
    flavor: 'Instruments read zero. All of them.',
  ),
  'first_light': GearDef(
    id: 'first_light',
    name: 'FIRST LIGHT',
    rarity: Rarity.epic,
    bonus: Bonus(rare: 0.10, xp: 0.20),
    flavor: 'It was down there before there was a down there.',
  ),

  // Sector 05
  'spire_sigil': GearDef(
    id: 'spire_sigil',
    name: 'SPIRE SIGIL',
    rarity: Rarity.epic,
    bonus: Bonus(credits: 0.25, alloy: 0.25, intel: 0.25),
    flavor: 'Proof of arrival.',
  ),
  'telos_lens': GearDef(
    id: 'telos_lens',
    name: 'TELOS LENS',
    rarity: Rarity.epic,
    bonus: Bonus(intel: 0.40, rare: 0.08),
    flavor: 'Shows the end of the thing you are looking at.',
  ),
  'last_charter': GearDef(
    id: 'last_charter',
    name: 'THE LAST CHARTER',
    rarity: Rarity.epic,
    bonus: Bonus(xp: 0.35, credits: 0.15),
    flavor: 'The guild, in its own hand.',
  ),
};

GearDef gearById(String id) => kGear[id]!;

// ---------------------------------------------------------------------------
// RECRUIT NAMES - flavour only.
// ---------------------------------------------------------------------------
const List<String> kNames = [
  'KAEL', 'MIRA', 'VESS', 'ODRIN', 'SABLE', 'TORREN', 'NYX', 'HALLOW',
  'BRAE', 'CASS', 'DRENN', 'ELIAS', 'FENN', 'GRETA', 'HOLT', 'IVO',
  'JORAH', 'KESTREL', 'LUMEN', 'MARROW', 'NOOR', 'OSK', 'PIKE', 'QUILL',
  'RASK', 'SOREN', 'THANE', 'ULLA', 'VANE', 'WREN', 'YARROW', 'ZEPH',
];

// ---------------------------------------------------------------------------
// DURATION PRESETS - the pre-session choice.
// ---------------------------------------------------------------------------
const List<int> kDurations = [15, 25, 45, 60, 90, 120];

String durationTier(int minutes) {
  if (minutes < 20) return 'SCOUTING';
  if (minutes < 40) return 'SHORT';
  if (minutes < 60) return 'STANDARD';
  if (minutes < 90) return 'DEEP';
  return 'EPIC';
}
