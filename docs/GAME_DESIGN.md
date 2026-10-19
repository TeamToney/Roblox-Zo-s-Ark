# Zo's Ark

An exploration adventure about discovering wildlife and building a living animal journal. Walk through an Ark sanctuary campus and outdoor habitats, sail into the surrounding sea, rescue animals with nonlethal gear, and trade them into the sanctuary to fund the next expedition.

## First playable

The hybrid world adapts the user's MAP 1.jpeg floor plan. The southern lobby and central avenue connect open meadow/canopy courtyards, northern habitat halls, the pointed Ark Atrium with its gear kiosk and challenge board, and the large eastern marine hall. Free boats leave its pools through an eastern sea gate into the open ocean. Fourteen species span six rarity tiers. Rarity, rescue difficulty, habitat equipment, and place in the food chain determine their value and required gear.

The player starts with 100 coins, Tier 1 rescue gear, and 24 inventory spaces. Catching an animal earns Ark Points and a small coin stipend. Sanctuary trading pays its full listed value and frees a slot. Discoveries remain in the journal after trading. Gear upgrades are permanent and apply automatically; calming bait is consumed on each eligible attempt, including failures. Animal capture is nonlethal; there is no player combat.

Coins are spendable currency. Ark Points are permanent progression, with level `1 + floor(sqrt(points / 120))`. Distance rewards arrive every 500 plausible horizontal studs. Daily challenges reset at midnight UTC and require an explicit reward claim. Aurora Tide runs for eight minutes every thirty minutes, introduces the Aurora Manta, and awards coins, points, and a permanent title for three event catches. Each player may rescue three mantas per tide. Studio previews the event by default.

## Map integration

MAP 1.jpeg was supplied as an inline floor-plan image. Per the user's preference, the default world mixes architectural circulation with outdoor biomes and waterways. The layout is a hand-traced gameplay interpretation: main shapes and room groups are retained, smaller partitions consolidated, roofs omitted, and an open-sea area added. See [MAP1_DESIGN.md](MAP1_DESIGN.md) and the generated diagram. A Studio `ZoMap` can still override the generated campus; see [MAP_IMPORT.md](MAP_IMPORT.md).

## Trust and saving

Only the server picks species, rolls captures, moves wildlife, checks distance, prices trades, buys equipment, and awards challenges. The client asks for named actions and renders server snapshots. Capture prompts are rechecked for proximity and cooldown. Purchases and trades require the Ark station. Profiles use a versioned DataStore record with a renewable session lease; load failures never overwrite existing player data. Studio uses temporary session data unless explicitly configured otherwise.

This is a playable foundation with procedural placeholder art. It is not a launch certification. Real-client playtests, multiplayer exploit testing, persistence/reconnect checks, imported-map traversal, mobile/controller usability, and performance must pass before publication.

## Follow-up releases

1. Refine Map 1 geometry and traversal through Studio playtests, replace blockout animals with licensed original models, and tune habitat density and capture rates.
2. Add individual animal traits, sanctuary displays, quests from Zo, boats with upgrades, and more handcrafted challenges.
3. Add player-to-player trading with a separate escrow, dual confirmations, cancellation, disconnect recovery, and durable transaction IDs. The first version trades with the sanctuary only; do not imply players can trade with each other yet.
4. Add seasonal content through the catalog and event schedule. Ship content updates through source control and a staging place before the live experience.
5. Consider cosmetic monetization only after retention and economy balance are measured. No Robux purchasing or paid random rewards are implemented.
