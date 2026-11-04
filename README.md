# firebulletsfix

Fixes shooting position problem displaced by one tick.

## How it works

The server runs a player command in this order: movement first, then the weapon code (`PostThink`). Bullets therefore start from the eye position after this tick's movement, one tick ahead of where the player aimed from.

The plugin stores the eye position when the command starts (`OnPlayerRunCmd`). Until the command ends (`OnPlayerRunCmdPost`), `Weapon_ShootPosition` returns that stored position for this player. Calls made outside the player's own command, such as a weapon drop from the `drop` command or when another player kills them, keep the real position.
