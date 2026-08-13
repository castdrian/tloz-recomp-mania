# TLoZ: Recomp Mania

TLoZ: Recomp Mania replaces the Gen 1 player with Link and adds a full Zelda action layer to gen1recomp.

Controls:

- Press B to cycle through four sword attacks; hold B after a swing to charge and release a spin attack.
- Select cycles the equipment set from shield through bow, boomerang, hookshot, hammer, shovel, powder, rods, lamp, cane, and bomb.
- Hold A away from an interaction target to use the selected equipment; shield is the default.
- Sword strikes damage ordinary overworld NPCs. The third strike defeats the NPC with a red damage glow and red particle burst.
- Completed movement, pickups, field interactions, boulder pushes, warps, blackouts, and sword swings use the matching supplied Link action or voice audio.

Install the folder as `mods/tloz-recomp-mania`, enable it from the MODS screen, and start an overworld save. The manifest targets both `gen1` and `gen2`.

The Link sprite source is [The Spriters Resource Minish Cap asset 6369](https://www.spriters-resource.com/game_boy_advance/thelegendofzeldatheminishcap/asset/6369/). The Link and NPC action audio is from the [Minish Cap sound set](https://noproblo.dayjo.org/zeldasounds/mc/).

The package uses the API-2 engine seams shared by the Gen 1 and Gen 2 branches. `modkit gen2check` passes for the package. The checkout used for simulator verification exposes Gen 1 Red, Blue, and Yellow only; a literal Gen 2 Gold, Silver, or Crystal run requires installing this package into the corresponding gen2recomp branch.
