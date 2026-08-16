# TLoZ: Recomp Mania

TLoZ: Recomp Mania replaces the Gen 1 player with Link and adds a full Zelda action layer to gen1recomp.

Controls:

- Press B to cycle through four sword attacks; hold B after a swing to charge and release a spin attack.
- Select cycles the equipment set from shield through bow, boomerang, hookshot, hammer, shovel, powder, rods, lamp, cane, and bomb.
- Hold A away from an interaction target to use the selected equipment; shield is the default.
- Face a clay pot and press A to pick it up; press A again to throw and break it.
- Sword strikes damage ordinary overworld NPCs and Wilds of Kanto overworld spawns. The third strike defeats either target with a red damage glow and red particle burst; Wilds play their species cry instead of villager hit audio.
- Sword strikes cut tall grass and break the mod's clay pots. Both can drop green, blue, red, purple, silver, or gold rupees that collect into the real in-game wallet at ten times their rupee value in Pokédollars.
- Completed movement, pickups, field interactions, boulder pushes, warps, blackouts, and sword swings use the matching supplied Link action or voice audio.

Install the folder as `mods/tloz-recomp-mania` and enable it from the MODS screen. If `overworld-spawn-mod` is installed, enable it too to make its overworld spawns sword-attackable. The manifest targets both `gen1` and `gen2`.

The voxel renderer uses the user-supplied rigged Link model with authored idle, walk, sword, shield, pickup, throw, and tool clips. The six rupee sprites use the purchased [Pixel Art Zelda rupee badge pack](https://www.etsy.com/listing/1183848915/legend-of-zelda-rupee-twitch-badges). The clay pot and break frames come from the [ALttP pot sprite](https://zelda.fandom.com/wiki/File:ALttP_Pot_Sprite.gif) and [Bush & Pot SFX sheet](https://www.spriters-resource.com/snes/legendofzeldaalinktothepast/asset/67259/). Grass art remains from the [Minish Cap miscellaneous objects asset](https://www.spriters-resource.com/game_boy_advance/thelegendofzeldatheminishcap/asset/6562/). Link action, grass, and rupee audio is from the [Minish Cap sound set](https://noproblo.dayjo.org/zeldasounds/mc/), pot destruction uses the supplied OOT pot-shatter WAV, and NPC hit/death audio uses the supplied Minecraft villager sounds.

The package uses the API-2 engine seams shared by the Gen 1 and Gen 2 branches. `modkit gen2check` passes for the package. The checkout used for simulator verification exposes Gen 1 Red, Blue, and Yellow only; a literal Gen 2 Gold, Silver, or Crystal run requires installing this package into the corresponding gen2recomp branch.
