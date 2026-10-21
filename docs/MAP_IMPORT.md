# Override or refine the Zo's Ark map

The default world now follows the uploaded MAP 1.jpeg approximately, with the user's requested mix of architecture and outdoor biomes. Refine that version in `MapLayout.luau` and `PlanWorld.luau`, following [MAP1_DESIGN.md](MAP1_DESIGN.md). The marker contract below is for supplying a separate Studio map that overrides the generated campus entirely.

## Marker contract

Import world geometry into a Workspace **Folder or Model named `ZoMap`**. Keep it in the place file; `Workspace` is configured to preserve Studio objects that are outside Rojo's source tree. When the server detects `ZoMap`, it does **not** generate the Map 1 campus or fill the ocean. Terrain is global and cannot live in a Folder; import any terrain separately. Save a backup of the place before imports or Rojo syncs.

Create these anchored, invisible marker Parts inside `ZoMap`. Set `CanCollide`, `CanTouch`, and `CanQuery` to `false`:

| Marker | Configuration |
| --- | --- |
| `ZoHub` | Position where the Ark station area begins. A 38×24-stud storefront is generated at world offset (+17, +15 on X/Z), facing north; reserve this footprint, its 13.5-stud height and a clear approach from the north. |
| `ZoSpawn` | Spawn CFrame just above a safe ground surface near the hub. The runtime creates a neutral invisible SpawnLocation here. Remove or disable other spawn locations in the imported place. |
| Animal zones | Apply the CollectionService tag **`ZoAnimalZone`** in Studio's Tags editor. Add string attribute **`Habitat`**, one of `meadow`, `jungle`, `summit`, `reef`, `ocean`. Add numeric **`Radius`** (12–180, default 60) and **`Population`** (1–12, default 6). |
| Boat docks | Apply tag **`ZoBoatSpawn`** to each marker. Its CFrame is the boat hull center; its forward / LookVector direction should point away from the dock. Leave space for a 10×16 stud boat. |

For land zones, set the marker on a broad, clear ground surface above Y=3, near the center of a habitat. Spawn placement casts down onto surfaces with an upward normal and within 12 studs of the marker's elevation. Keep markers away from roofs, trees, buildings, cliffs, and deep gaps. Multiple small zones work better than one zone spanning disconnected ground.

For sea zones, set marker Y to the intended water surface. Fish and marine animals roam around that elevation. Supply actual Terrain water if swimming is required. Set boat marker Y so the hull floats just above that surface. The boat system keeps each hull at its dock's original Y; it does not simulate waves or sloped water.

All first-version boat routes must stay within 820 horizontal studs of world origin. Configure `MaxWorldRadius` in `Config.luau` if the final map needs a larger playable radius; update boundary and travel tests and verify streaming/performance at that scale. Keep islands on reachable routes and provide piers at a height players can board from. Chart markers and the Ark distance indicator are derived from imported marker positions.

## Verify the replacement

1. Stop play, import the geometry/terrain, add the markers, and save a separate version of the place.
2. Start Play. The server should report `World ready`. Missing required markers stop initialization with an actionable server error.
3. Confirm that no generated campus appears and that the imported terrain has not changed.
4. Verify every zone has the intended species and that animals sit on reachable ground or at the waterline. Wildlife uses simple short roaming motions; it is not pathfinding AI and should be kept away from obstacles.
5. Walk from spawn to the shop, trade and buy, then visit every land and sea habitat and return. Check boarding, shore collisions, walls, swim access, and map boundaries on desktop and mobile.
6. Custom maps use a marker-based chart and general guide directions. For custom names or richer floor outlines, extend the map metadata and chart without reusing the Map 1 trace for unrelated geometry.

Custom animal meshes can replace the generated body parts later. Preserve the Model's primary root, `SpeciesId`, ProximityPrompt, and server-owned capture path; do not move reward authority into imported asset scripts. Audit any third-party models before use and keep a record of asset rights.
