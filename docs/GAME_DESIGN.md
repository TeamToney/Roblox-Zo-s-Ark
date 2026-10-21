# Zo's Ark

An exploration adventure about discovering wildlife and building a living animal journal. Walk through an Ark sanctuary campus and outdoor habitats, sail into the surrounding sea, rescue animals with nonlethal gear, and trade them into the sanctuary to fund the next expedition.

## First playable

The hybrid world adapts all three user-supplied floor plans. The original Ark retains its southern lobby, central avenue, courtyards, habitat halls, pointed Atrium and eastern marine hall. Two additional islands, Canopy Reach and Moonstone Isle, surround the eastern sea, with west-facing landings and free boats. Twenty-six species span six rarity tiers. Rarity, rescue difficulty, habitat equipment, and place in the food chain determine their value and required gear.

The player starts with 100 coins, Tier 1 rescue gear, and 24 inventory spaces. Catching an animal earns Ark Points and a small coin stipend. Sanctuary trading pays its full listed value and frees a slot. Discoveries remain in the journal after trading. Gear upgrades are permanent and apply automatically; calming bait is consumed on each eligible attempt, including failures. Animal capture is nonlethal; there is no player combat.

Coins are spendable currency. Ark Points determine level `1 + floor(sqrt(points / 120))`; surprise chest traps can reduce points but never below zero. Distance rewards arrive every 500 plausible horizontal studs. Daily challenges reset at midnight UTC and require an explicit reward claim. Aurora Tide runs for eight minutes every thirty minutes, introduces the Aurora Manta in a secluded coral alcove, and awards coins, points, and a permanent title for three event catches. Each player may rescue three mantas per tide. Studio previews the event by default.

Capture prompts take 0.25 seconds, with a server cooldown of 0.8 seconds. Common/Uncommon animals can choose rooms on their own island and follow Roblox PathfindingService routes, with no jumping and water excluded. Every movement segment is swept against walls. Only two path computations run concurrently; failed routes leave animals in place until a later attempt. Secluded habitats and marine animals retain local roaming. Rare+ species are excluded from visible habitat pools and stay in their obscure spawn area.

Seven checkpoints save the active respawn; each pays 15 coins/10 points on first activation only. The four expedition goals cover Canopy's three checkpoints and four rescues, Moonstone's three checkpoints plus three rescues including a Rare+, three-island travel, and opening three distinct chests. Expedition rewards are claimed once and persist independently of daily challenges.

Twelve free surprise chests roll on the server. Each player can open each chest once per UTC day; the opening is reserved before applying its result, including traps. Default outcomes are coins (35%), an animal (30%), permanent unowned equipment (20%), a point penalty (10%), or character death (5%). Obscure chests may contain Rare+ animals; ordinary chests may not. Event animals never appear in chests. Full-pack animal prizes convert to their value in coins plus discovery points; chest animals do not count as expedition rescues. Point penalties remove 12% of current points, at least 10 when possible. Death traps respawn at the active checkpoint and retain inventory and equipment. Chest prompts disclose the trap risk.

Walking pays 2 coins and 1 point every ten estimated steps (30 studs); swimming pays 3 coins and 2 points every ten estimated strokes (40 studs). The server samples physical displacement, Terrain water, grounding and seat state. Boats, airtime, stationary jitter and implausible speed do not qualify. Walking and swimming have separate cumulative distances, so fractional progress survives reconnects without repeating a paid boundary. These are plausibility checks, not comprehensive movement anti-cheat.

Water exploration uses a session-only fatigue reserve: 30 seconds without gear, 60 with a snorkel, or 180 with the diving kit. A life jacket adds 60 seconds. Swimming drains the reserve even while idle; exhaustion deals 10 health per second after the reserve reaches zero. Land and boat rest recover 8 seconds per second. Life-ring pickups restore 15 seconds and suspend fatigue for 20 seconds; first-aid floats restore 25 health and 20 seconds of endurance. Server-validated shared pickups respawn after 90 seconds at a randomized nearby water position. Reserves reset on character respawn, while permanent equipment and earned progression remain in the journal.

## Map integration

MAP 1.jpeg was supplied as an inline floor-plan image. Per the user's preference, the default world mixes architectural circulation with outdoor biomes and waterways. The layout is a hand-traced gameplay interpretation: main shapes and room groups are retained, smaller partitions consolidated, roofs omitted, and an open-sea area added. See [MAP1_DESIGN.md](MAP1_DESIGN.md) and the generated diagram. A Studio `ZoMap` can still override the generated campus; see [MAP_IMPORT.md](MAP_IMPORT.md).

Dry foundation tiles extend below the seabed, preventing an underwater route beneath the campus. The pools and sea gate remain cut out. Four outer shore stairs provide water exits without changing the main plan. Animal blueprints use original ellipsoids, blocks and wedges for species-specific anatomy and markings; server animation supplies walking, flipper, wing and tail motion. They remain stylized Roblox models, with lighting and performance still requiring Studio review.

## Trust and saving

Only the server picks species, rolls captures, moves wildlife, checks distance, prices trades, buys equipment, and awards challenges. The client asks for named actions and renders server snapshots. Capture prompts are rechecked for proximity and cooldown. Purchases and trades require the Ark station. Profiles use a versioned DataStore record with a renewable session lease; load failures never overwrite existing player data. Studio uses temporary session data unless explicitly configured otherwise.

This is a playable foundation with procedural placeholder art. It is not a launch certification. Real-client playtests, multiplayer exploit testing, persistence/reconnect checks, imported-map traversal, mobile/controller usability, and performance must pass before publication.

## Follow-up releases

1. Refine Map 1 geometry and traversal through Studio playtests, replace blockout animals with licensed original models, and tune habitat density and capture rates.
2. Add individual animal traits, sanctuary displays, quests from Zo, boats with upgrades, and more handcrafted challenges.
3. Add player-to-player trading with a separate escrow, dual confirmations, cancellation, disconnect recovery, and durable transaction IDs. The first version trades with the sanctuary only; do not imply players can trade with each other yet.
4. Add seasonal content through the catalog and event schedule. Ship content updates through source control and a staging place before the live experience.
5. Consider cosmetic monetization only after retention and economy balance are measured. No Robux purchasing or paid random rewards are implemented.
