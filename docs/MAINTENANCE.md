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

`Config.luau` holds economy limits and event cadence. `Catalog.luau` holds prices and species/challenge definitions. Capture stipend is 20% of listed sanctuary value; capture probability is `clamp(0.82 - 0.85 × difficulty + 0.06 × (tier - 1) + baitBonus + encounterAdjustment, 0.20, 0.90)`, with a 0.15 bait bonus. Fleeing applies -0.14; a gentle snare applies +0.22. Server encounter state supplies this adjustment; clients cannot choose it. Rarity and apex hierarchy are expressed through the species definition rather than a client-supplied score.

Aurora Tide shares a wall-clock schedule across servers. Each player may rescue at most three event mantas per tide, and may claim the tide prize once. Keep event IDs stable when extending the schedule so replayed saves cannot claim the same reward twice. Studio previews are deliberately temporary and must not be used against production save data.

No analytics backend or alerting is configured. Before tuning a live economy, collect appropriate aggregate measures such as first-catch time, progression bottlenecks, coins earned/spent, rarity encounter rates, and challenge completion in a privacy-conscious analytics workflow. Do not change production balances based only on synthetic tests.

## Save schema and incidents

Profiles store currencies, species counts, discoveries, permanent gear, statistics, UTC daily progress, and one tide's event progress. The store wraps them with a schema version and session lease. Never change `DataStoreName` to work around a save bug; doing so would strand existing journals. Implement and test a migration before changing record shape or IDs. Unknown schemas intentionally block load.

The water-survival update keeps schema v1 and every existing ID. Its additive `stats.walkDistance`/`stats.swimDistance` fields default to zero when absent and retain fractional progress when present; sanitizer/reconnect tests cover older records. `owned.lifeJacket` follows the existing item ownership map. Swim fatigue and temporary flotation are character-session state, not saved progression. Tune endurance, recovery, damage and movement rewards in `Config.luau`; keep catalog descriptions and in-game guide text consistent with any balance changes. Never accept client step counts or pickup rewards as authority.

The island update also keeps schema v1 and `ZosArk_Profiles_v1`. Its additive `exploration` object holds known visited/active checkpoint IDs, one-time expedition claims, last UTC opening day per known chest ID, and regional rescue totals. Missing fields default safely; unknown IDs are discarded. Regression tests cover old journals and round trips. Keep checkpoint/chest IDs stable when moving their coordinates. Point traps intentionally reduce points, so level calculation must remain valid at zero. Character death must not erase inventory or gear. Free chest outcomes are rolled and reserved on the server; never expose client-selected rolls or reward types. Maintain the visible chest trap warning.

On repeated save failures, inspect Roblox service status and server warnings. The server removes players before its lease can expire; this reduces concurrent writers but does not guarantee zero loss since the previous save. Preserve evidence and the last known good source/place version, test a fix in staging, and never blindly clear a player's record. Test shutdown and release behavior before changing retry or lease timings.

Player-to-player trading needs a separate transaction design with escrow, two-party confirmation, disconnect handling, idempotency, durable records, and recovery. Sanctuary trading is not a safe foundation for simply subtracting from one live player table and adding to another.

## Asset and map maintenance

Keep provenance and licenses for imported maps, models, audio, and thumbnails. Procedural map, animal and merchandise geometry has no third-party asset dependencies; Ark Radio uses Roblox music-library assets and credits. Prefer known geometry and inspect imported scripts. Maintain the marker contract in `MAP_IMPORT.md` and run a full traversal pass after terrain, scale, collision, or streaming changes.

## Outfitters and paid grants

The shop update retains schema v1 and all previous IDs. Additive `stock` counts (`speedBoost`, `animalTrap`), `wardrobe` cosmetic slots, and `receipts` purchase-ID markers default empty/zero. Sanitization preserves known owned equipment and valid slots; migration and reconnect tests cover old journals. Unused supplies persist; active boost/scanner timers do not persist across server sessions. Cosmetic slots are reapplied on respawn. Keep paid receipt IDs indefinitely: removing markers can duplicate a retried purchase. Monitor record size before introducing high-volume monetization.

`Catalog.Items` supplies both prices, categories and quantities; `Catalog.Products` supplies guaranteed grants and duplicate-owned bundle compensation. `Monetization.luau` maps stable product keys to owner-created Developer Product IDs. Follow [ROBUX_SETUP.md](ROBUX_SETUP.md). Keep the ProcessReceipt handler unique; never grant from client callbacks. Receipt handling reserves the grant and marker without yielding, then saves under the current session lease. A failed save retains the in-memory marker; the callback waits for journal loading or an in-flight save, retries writes within a bounded window, then returns NotProcessedYet if still blocked. Roblox has no periodic receipt retry; rejoining or another purchase triggers delivery again. Retries save again without granting twice. Unknown products, unavailable journals, lost leases and temporary sessions remain pending. Do not remove IDs for products that might still have pending receipts.

`Storefront.luau` owns physical shop geometry; `ItemShapes.luau` supplies both world and UI merchandise props. `FieldKit.luau` owns timed speed, scans, trap placement and wardrobe replication. Update both WaterSafety's sampling ceiling and Rules.movement when changing boosted speeds. Never use a client attribute as proof of a boost. `Catalog.Escape`, `EscapeRules` and `EncounterRules` tune wildlife. Every species needs an escape response after an eligible miss, even without a proximity-alert entry. Keep flight arcs finite, wall and ground/water checks enabled, path calculations bounded and obscure destinations local. Route revisions invalidate old asynchronous paths on escape. Wildlife rays exclude all player characters to prevent body blocking. `ChestCutscene.luau` renders server-authorized outcomes only, using its own viewport camera; never modify Workspace.CurrentCamera or grant rewards from playback. Keep the Skip/respawn/error cleanup and independent deadline. `ChestEffects.luau` retains scanner signals.

## Access, travel and scarcity

Schema v1 gains `maps` (Ark true; other known IDs false/absent by default) and `stock.teleportPass` (zero by default). Old animal, gear, receipt and exploration history remains intact. Never infer ownership from a visited checkpoint. Unowned legacy respawns use the Ark entrance while retaining their stored checkpoint history. Coin/point unlocks and Robux grants both set the same permanent map flag. Teleport charges are separate. Migration, save/reconnect and receipt-retry tests cover this addition.

New maps must be added to Catalog.Maps/MapOrder, with positive purchase prices, a valid checkpoint and an optional configured Robux product. World plans without registration or paid entry fail closed at startup. Travel.luau enforces regions and safe landing transfers; keep capture, chest, checkpoint and scanner gates as well as the periodic entry check. Reset both movement samplers for every authorized or corrective teleport. Never charge for a failed destination, a seated/dead explorer or a cooldown. Preserve the seat-unweld step when ejecting an unowned passenger.

WildlifeRules normalizes separate Rare/Epic/Legendary budgets, then distributes each tier by species weight. Missing tiers return their budget to ordinary species. Map ownership raises encounter opportunity through higher island budgets; it does not guarantee a prize. Hidden habitats multiply budgets by 1.8; seaways by 1.2. Keep event species out of normal pools and test every map/sea route for all three scarce tiers. SeawayLayout uses world coordinates; keep those rectangles outside private regions and within SeaBounds.

CurrencyHUD animates display values only; Rules remains authoritative. Store clicks request inspection of known items with distance/visibility checks and require an explicit currency button to buy. Do not send unsolicited merchandise-open events from the server. NotebookState revisions reject stale inspection replies; close controls must remain independent of the request lock. Keep the panel/backdrop input layers, clipped scrolling area and post-close click guard to prevent clicks reaching a shelf behind the close button. Verify narrow screens and selected-card visibility in Studio whenever item categories or navigation changes.

## Music

See [MUSIC.md](MUSIC.md) for playlist review and optional curated tracks. Keep library terms server-selected, searches cached/rate-limited and the music remote independent of gameplay requests. Do not accept arbitrary asset IDs or searches from clients. SoundGroup volume must affect music only; stale search/load callbacks must never restart music after mute or replace a newer genre. Keep bounded load timeouts, failed-track skipping, a visible Retry path and cleanup on script destruction. Verify exact track access and suitability in a staging experience before release; cloud tests use fake library results and cannot audition audio.
