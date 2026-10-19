# Zo's Ark development

- Read README.md, docs/GAME_DESIGN.md and docs/MAP1_DESIGN.md. The default hybrid campus follows the uploaded MAP 1.jpeg floor plan approximately; do not describe it as a measured architectural reconstruction.
- Preserve the source image orientation and the main entrance, central avenue, pointed atrium and eastern marine wing when refining Map 1. MapLayout.luau is the source of truth; regenerate docs/map-1-layout.svg through scripts/map_assets.py rather than editing its output.
- Edit authored Luau under src/, not generated build/ places. The shared rules are engine-independent and strictly typed; keep them testable with the Luau CLI.
- Keep rewards, purchases, capture rolls, inventory mutations, and boat ownership checks on the server. Never accept client-supplied prices, player IDs, positions, probabilities, or reward totals as authority.
- Run bash scripts/check.sh for gameplay changes. Use bash scripts/bootstrap.sh if pinned tools are missing. Engine-dependent changes also require the relevant Studio checks in docs/TESTING.md; report unexecuted checks accurately.
- Preserve species/item IDs and existing saved records. Save-schema changes need a tested migration; do not reset profiles or change the DataStore name as a shortcut.
- Use the existing checkout. Cloud tasks are already isolated; do not create a Git worktree unless explicitly requested.
- Studio uses temporary journals by default. Never enable live Studio data access against production as part of routine development.
