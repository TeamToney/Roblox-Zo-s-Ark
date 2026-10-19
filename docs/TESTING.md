# Verify Zo's Ark

## Automated checks

Run `bash scripts/bootstrap.sh` once on Linux x86_64, then `bash scripts/check.sh` after a change. The test runner exits unsuccessfully if any check fails. It reports the number of actual domain cases, strictly analyzes shared modules, compiles every game script, builds the place, and verifies embedded script counts and source content.

The economy suite covers exact capture awards, bait use, full packs, gear gates, shop debits, repeated purchases, invalid trade quantities, atomic sanctuary transfers, travel limits and milestone boundaries, daily resets, duplicate reward claims, event boundaries and quotas, saved-profile sanitization, and a 1,000-action mixed session. The profile-store suite injects a fake service to test session conflicts, lease expiry, stale writers, release/reconnect, corrupted records, unsupported schemas, transient and exhausted service errors, failed saves, and temporary Studio data isolation. These are Luau tests, not engine simulations or live service verification.

The map suite checks image orientation, doorway gaps, the atrium polygon, aligned nursery access, disjoint foundation tiling around water, habitat surface types and dock transitions. A structural raster check expands a three-stud-wide player against the builder's wall data and confirms every room center is connected to the entrance. It checks a conservative boat route through the sea gate. These planar checks exclude decorative props and do not replace Roblox collision, streaming or device testing. `docs/map-1-layout.svg` is regenerated from the same Luau data.

## Studio checklist — still requires execution

Open the generated place in Studio and use a fresh Play session. The UI should say `SESSION`; the world is created when the server starts. Check Server and Client Output for errors.

- Spawn and respawn safely in the southern entrance, including the first Play session when characters can load before procedural world creation. Reach Meadow Courtyard, the lower gallery and every habitat. Walk around the pointed Atrium and enter its north doorway to reach Ark Outfitters. Check wall/door collision and camera obstruction.
- Close/reopen every panel, scroll the journal/store, resize the window, test phone and tablet emulation, and verify touch prompts. Check keyboard, controller selection, movement, and UI navigation with an actual controller before claiming controller support.
- Catch a rabbit, observe the stipend and Ark Points, and verify that the journal count increases. Wait for an occasional failure and verify no award. Tier 1 gear must reject deer and rare animals with a helpful message. Wildlife should stay within its habitat and avoid walls; prompts and server checks must prevent captures through walls.
- At the kiosk, trade one animal; its discovery must remain. Buying an upgrade must debit its listed price exactly once. Away from the kiosk, buy and trade requests must fail. Rare sanctuary transfers require a second confirmation click.
- Verify Ranger Net, snorkel, Expedition Net, rescue tranquilizer, Deepwater Kit, pack upgrade, and bait. Gear is automatic; bait should be consumed on an eligible failed attempt too.
- Descend Tidewater Hall's boarding steps. Pilot a boat forward, reverse and turn through the eastern sea gate; jump out, use the swim steps, board again and try all passenger seats. Check lagoon walls, shore/dock collision and its 45-second unoccupied return. An unseated player must not control a boat; disconnecting must not leave one moving.
- Reach fish/turtles in Sunlit Reef Pool and dolphins/whales in Bluewater Pool and the Open Sea extension. Check prompts while swimming and seated. Large animals must fit their zones and bodies should stay near the water surface as streaming loads/unloads them.
- Travel 500 horizontal studs at normal speed. Verify the 25-coin/15-point reward once per boundary; a large teleport or respawn must not count. This is a plausibility filter, not complete movement anti-cheat.
- With Studio's default Aurora preview, catch three mantas with the required gear, claim the prize once, verify the title and personal three-catch quota. Set `ZoPreviewEvent=false` on Workspace to test real timing. Live windows start at each Unix half-hour and last eight minutes. Confirm start/end spawn cleanup, quota reset next tide, and no reward from past-tide progress.
- Complete each daily challenge and claim its reward once. Verify UTC day rollover with a staging test harness; do not alter the production host clock.

## Multiplayer and persistence — required before launch

Use Studio's server + two clients mode for concurrent prompt and UI testing. Two players targeting one animal must produce one successful rescue at most. Spam actions, send unknown IDs, invalid quantities/NaN, and attempt out-of-range purchases/captures from a local test client; currency must remain server-controlled. Validate boat input ownership, rate limiting, multiple passengers, and disconnection.

Use a **separate staging experience** for persistence. Set Workspace `ZoUseLiveDataInStudio=true` and `ZoPreviewEvent=false`, enable Studio API access for staging only, and test initial saves, autosaves, leaving, rejoining, simultaneous login attempts, server shutdown, interrupted saves, and lease expiration after a hard crash. Confirm that unknown schema versions and simulated load errors never write blank profiles. Do not claim this passes from compilation or fake-store unit tests alone.

Inspect server memory, replication traffic, frame time, and streaming behavior on target mobile hardware. The default Map 1 world targets 36 ordinary animals plus two event mantas. Wildlife is anchored placeholder geometry updated several times a second; replace or optimize it only after profiling. The detailed chart should stay proportional after resizing and its static geometry should be reused between server snapshots. Imported maps need their own traversal and performance pass.

Publication is a separate user action. No experience has been uploaded, published, or configured through Roblox services by the cloud build.
