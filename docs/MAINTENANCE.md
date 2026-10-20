# Maintaining the Ark

## Change workflow

Keep authored source in `src/`. Never edit generated place files as a substitute for changing scripts. Make changes in the existing task checkout; cloud tasks are already isolated and do not need extra Git worktrees. Keep map/asset imports in backed-up Studio place versions until an asset pipeline is established.

The default map is the hybrid Map 1 campus. Edit the image-space trace in `MapLayout.luau`, geometry helpers in `MapGeometry.luau`, and world decoration in `PlanWorld.luau`. Keep the principal source features described in `MAP1_DESIGN.md`. Run the layout checks and regenerate the diagram through `scripts/check.sh`; do not hand-edit the generated SVG. Keep extra encounter content outside the trace clearly identified as a gameplay extension.

Run `bash scripts/check.sh` after changing rules or scripts. Perform the relevant Studio checklist for changes to world geometry, boats, prompts, saving, remotes, or UI. Use CI build artifacts for staging. Tag a tested source revision and retain the previous working place version before publishing a live update. Commit/push and publication remain explicit project actions; a passing local build does not perform either.

## Add an animal

1. Add a stable species ID and its definition in `Catalog.Species`; append it to `SpeciesOrder`. IDs are stored in player journals: do not rename them without a migration.
2. Choose habitat, rarity, required tier, access gear, value, points, spawn weight, procedural form, scale, and color. Non-event weights are relative within each habitat.
3. Add matching habitat zones in the final map. Do not put early progression behind gear players cannot afford to earn from available starter species.
4. Add tests for new rules or access requirements and playtest captures, trading, capacity, and display. Supply a custom art pipeline before replacing generated models wholesale.

## Tune progression and events

`Config.luau` holds economy limits and event cadence. `Catalog.luau` holds prices and species/challenge definitions. Capture stipend is 20% of listed sanctuary value; capture probability is `clamp(0.93 - difficulty + 0.08 × (tier - 1) + baitBonus, 0.12, 0.96)`, with a 0.15 bait bonus. Rarity and apex hierarchy are expressed through the species definition rather than a client-supplied score.

Aurora Tide shares a wall-clock schedule across servers. Each player may rescue at most three event mantas per tide, and may claim the tide prize once. Keep event IDs stable when extending the schedule so replayed saves cannot claim the same reward twice. Studio previews are deliberately temporary and must not be used against production save data.

No analytics backend or alerting is configured. Before tuning a live economy, collect appropriate aggregate measures such as first-catch time, progression bottlenecks, coins earned/spent, rarity encounter rates, and challenge completion in a privacy-conscious analytics workflow. Do not change production balances based only on synthetic tests.

## Save schema and incidents

Profiles store currencies, species counts, discoveries, permanent gear, statistics, UTC daily progress, and one tide's event progress. The store wraps them with a schema version and session lease. Never change `DataStoreName` to work around a save bug; doing so would strand existing journals. Implement and test a migration before changing record shape or IDs. Unknown schemas intentionally block load.

The water-survival update keeps schema v1 and every existing ID. Its additive `stats.walkDistance`/`stats.swimDistance` fields default to zero when absent and retain fractional progress when present; sanitizer/reconnect tests cover older records. `owned.lifeJacket` follows the existing item ownership map. Swim fatigue and temporary flotation are character-session state, not saved progression. Tune endurance, recovery, damage and movement rewards in `Config.luau`; keep catalog descriptions and in-game guide text consistent with any balance changes. Never accept client step counts or pickup rewards as authority.

On repeated save failures, inspect Roblox service status and server warnings. The server removes players before its lease can expire; this reduces concurrent writers but does not guarantee zero loss since the previous save. Preserve evidence and the last known good source/place version, test a fix in staging, and never blindly clear a player's record. Test shutdown and release behavior before changing retry or lease timings.

Player-to-player trading needs a separate transaction design with escrow, two-party confirmation, disconnect handling, idempotency, durable records, and recovery. Sanctuary trading is not a safe foundation for simply subtracting from one live player table and adding to another.

## Asset and map maintenance

Keep provenance and licenses for imported maps, models, audio, and thumbnails. Generated placeholders have no third-party asset dependencies. Prefer known geometry and inspect imported scripts. Maintain the marker contract in `MAP_IMPORT.md` and run a full traversal pass after terrain, scale, collision, or streaming changes.
