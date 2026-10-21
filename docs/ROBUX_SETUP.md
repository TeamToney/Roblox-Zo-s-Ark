# Enable the prepared Robux shop

The build contains guaranteed products and server receipt handling. Developer Product IDs are currently **0**, so these offers say **Coming soon**. Coin/Ark Point purchases work without this setup. No Robux price is invented, and no Roblox experience or product has been published from the cloud.

## Create products in Creator Hub

1. Publish your place to the intended Zo's Ark experience from Studio when you are ready. Use a separate staging experience for purchase/persistence testing.
2. In [Creator Hub](https://create.roblox.com/dashboard/creations), open the experience and find **Monetization → Developer Products**. Create these seven products, enter the guaranteed contents in their descriptions, choose your prices, and copy their **Developer Product IDs**. These are product IDs, not place IDs, universe IDs, image IDs or game passes.

| Key | Product name | Guaranteed grant |
| --- | --- | --- |
| `sprintPack` | 3 Expedition Sprints | 3 speed-boost charges |
| `trapPack` | 3 Gentle Animal Snares | 3 snare charges |
| `explorerStyle` | Explorer Style Bundle | Safari Hat + Aurora Footsteps; 400 coins if both are already owned |
| `rangerKit` | Ranger Expedition Kit | Ranger Net, Pack, Scanner, Snorkel, Life Jacket + Camouflage; 1,200 coins if all six are already owned |
| `canopyAccess` | Canopy Reach Access | Permanent Canopy entry; 900 coins if already unlocked |
| `moonstoneAccess` | Moonstone Isle Access | Permanent Moonstone entry; 1,800 coins if already unlocked |
| `teleportPack` | 5 Teleport Passes | Five one-way teleports to owned islands; entry rights sold separately |

Bundles grant missing permanent items. Coin compensation applies only when the entire bundle is already owned. Boost/snare/teleport packs always add the listed charges. Map unlocks are permanent and never consumed by travel. A Robux teleport pack delivers five passes; the player then selects an owned destination in Travel. It does not automatically move a seated/dead player or unlock a destination. There are no paid chest openings or randomized paid rewards.

3. Put the IDs into `src/shared/Monetization.luau`, keeping the keys above. Each ID must be a distinct positive integer belonging to that experience. In a source-synced Studio project, the module appears at **ReplicatedStorage → ZoShared → Monetization**. Sending the seven IDs back to Codex is enough to update/rebuild the source package.
4. Rebuild the place (`bash scripts/check.sh`, then `python3 scripts/package_studio.py`), open the updated place in Studio, and publish to the intended staging experience. Configuration changes in an already-open old `.rbxl` do not update Git source; keep these in sync.

## Verify before live sales

- Use staging products and Roblox's currently supported Developer Product testing workflow. Default local Studio journals are deliberately temporary and do **not** acknowledge Robux receipts. Do not enable production DataStore access for a local test.
- The server reads each configured product's sale availability and current Robux price from Roblox. Unavailable/invalid offers remain Coming soon. Roblox's own confirmation prompt shows the final price. Check regional/personalized prices in the real client before launch; the cached storefront price may vary from that final prompt.
- Verify map ownership is permanent across saves/rejoins, repeated map products give only their advertised compensation, locked destinations reject pass use, and map/pass Robux prompts can be opened from Travel away from Outfitters.
- Purchase each guaranteed bundle, leave/rejoin, and verify exactly the listed contents. Repeat a style/equipment bundle to verify the advertised all-owned compensation. Verify that partial ownership grants missing items without compensation.
- The receipt callback waits for journal loading/in-flight saves and retries transient writes. Roblox does not periodically retry NotProcessedYet receipts: after an extended outage, rejoining or another purchase triggers Roblox to deliver the pending receipt again.
- Cancel a purchase: no grant. Retry a receipt or disconnect during a save: no double grant, and an unsaved receipt remains pending until recovery. See the injected-service tests in `tests/ProfileStore.spec.luau`; those are not a real Marketplace/DataStore test.
- Keep `MarketplaceService.ProcessReceipt` owned by `Commerce.luau`. Adding another script that assigns it would replace the handler. Keep old configured product IDs supported while any receipts may still be pending.
- Retain a working published place version before enabling live products. Publishing and pricing are creator actions, separate from the cloud source build.

Current limitation: actual product ownership, regional prices, purchase prompts, paid receipts, Roblox persistence and publication have not been tested by this cloud session. IDs are intentionally left unconfigured until the owner supplies them.
