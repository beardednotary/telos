/// Stable save IDs. Guild emblems have no gameplay effects and are separate
/// from the marks that identify classes and sectors.
enum GuildSigil {
  lantern('Lantern'),
  compass('Compass'),
  branch('Branch'),
  anvil('Anvil');

  const GuildSigil(this.label);
  final String label;

  static GuildSigil fromId(Object? id) => values.firstWhere(
        (sigil) => sigil.name == id,
        orElse: () => lantern,
      );
}

const guildNameLimit = 32;
