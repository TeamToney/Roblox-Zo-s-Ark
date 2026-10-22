# Three islands from the user's floor plans

![Archipelago gameplay layout](archipelago-layout.svg)

The two additional inline floor-plan images are references for new land masses around the sea. They are hand-traced gameplay adaptations, with north at the top and east at the right. Original image binaries are not present in this checkout. No architectural dimensions or construction instructions are inferred from the images. Smaller partitions are consolidated and roofs are omitted, following the original hybrid-campus direction.

| Reference | Island | Retained features | Gameplay |
| --- | --- | --- | --- |
| First additional image | Canopy Reach, northeast | Northern room row, western complex, eastern paired halls, long lower galleries and southern arrival hall | 48 rooms, 6 habitats, 3 checkpoints, 4 chests; meadow/canopy wildlife and a secluded water cove |
| Second additional image | Moonstone Isle, southeast | Northwest court, upper/east gallery loop, central cross-gallery, southwest pointed hall and southeast great hall | 43 rooms, 7 habitats, 3 checkpoints, 4 chests; meadow, canopy, mountain and secluded reef wildlife |

`IslandLayouts.luau` is authoritative. Both traces use a 1426×1104 reference canvas at 0.55 studs per reference pixel. Canopy is offset to world (1150, -650), Moonstone to (1150, 500). These are gameplay positions/scales rather than recovered measurements. `MapGeometry.world` preserves the original Ark transform when no offset is supplied.

Land masses are unions of footprint rectangles, extruded below the seabed. They preserve stepped/C-shaped coastlines and leave water coves open. Gallery and room geometry uses the same door-gap calculations as the original Ark. Each island has a west-facing landing pier, swim steps, two free boats and additional shore exits. The original Ark has its three boats. Terrain water/seabed fills are chunked within `Config.SeaBounds`; the sea route at world X≈650 links all three landings.

The checkpoint and chest anchor coordinates live in the layouts; stable IDs, names, expedition goals and chest outcomes live in `Catalog.luau`. Live chests and wrapped gifts sample suitable rooms or hidden/water habitats at startup and periodically move while players are away. Authored chest coordinates are safe fallback anchors; moving never resets daily claims. The in-game chart draws all three plans but reveals interior checkpoint markers only after activation. Hidden wildlife and treasure have no chart markers. Development diagrams include checkpoint positions to support route review.

The default world targets 96 ordinary animals and two event mantas, including 15 slots in five additional routes from SeawayLayout.luau. Rare/Epic/Legendary species can spawn on every island and sea route in suitable habitats. They are scarce on the Ark, more likely on paid islands, and boosted in hidden habitats. The timed Mythic manta remains event-only. Respawns choose compatible habitats and additional uncovered nature rooms on the same island, preserving biome, concealment and seaway rules. Wild animals retain their original population slot even when their new home changes, so moving cannot create duplicate spawns or extra night predators. Common/Uncommon land animals may pathfind through doorways on their own island; rare and marine wildlife roam within their chosen home habitat. Pathfinding, wall sweeps, streaming and character/boat boarding require actual Studio tests.

`scripts/island_assets.py` exports an overview from real game data and checks every island room, checkpoint, chest and shore approach for structural walking access. It also checks conservative boat clearance between the Ark gate and both landings, correct water/ground habitats, and nonoverlapping footprints. These planar checks exclude props and do not execute Roblox navigation, terrain, collision or physics. Run `bash scripts/check.sh` to regenerate both SVG diagrams and build the place.

## Purchased entry

Canopy Reach and Moonstone Isle require permanent access purchased through Travel, using either coins or Ark Points, or configured Robux products. Shared sea routes stay free; private island territories include a 48-stud approach around their bounds. Server entry/capture/chest/checkpoint/respawn checks prevent bypass by walking, swimming, boat passenger seats or a forged request. The chart labels locked destinations and optional paid teleports require prior ownership. See README for prices and rarity budgets. Future plans must register a paid Catalog.Maps entry and valid landing.

## Woodland

Canopy Reach has 106 tropical broadleaf/palm trees and Moonstone has 155 mixed trees, emphasizing pines and birches. Both have 180 undergrowth props and grass in meadow/jungle habitat rooms. Placement follows ForestryLayout's dry-ground, corridor, room and marker exclusions; the footprints and north-up orientation remain intact. These are decorative, individually streamed models with no collision/query surfaces or ongoing animation task. Inspect actual canopy framing, wildlife visibility and mobile performance in Studio.
