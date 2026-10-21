--!strict
export type Species = {
	name: string, habitat: string, rarity: string, tier: number,
	difficulty: number, value: number, points: number, weight: number,
	form: string, color: {number}, scale: number, gear: string?, eventOnly: boolean?, pattern: string?,
}
export type Item = {
	name: string, price: number, description: string,
	kind: string, tier: number?, capacity: number?,
}
local Catalog = {}
Catalog.Rarities = {
	Common = {rank = 1, color = {172, 191, 181}},
	Uncommon = {rank = 2, color = {117, 218, 158}},
	Rare = {rank = 3, color = {100, 183, 255}},
	Epic = {rank = 4, color = {196, 149, 255}},
	Legendary = {rank = 5, color = {255, 205, 102}},
	Mythic = {rank = 6, color = {255, 143, 179}},
} :: {[string]: {rank: number, color: {number}}}
Catalog.Species = {
	rabbit = {name = "Meadow Rabbit", habitat = "meadow", rarity = "Common", tier = 1, difficulty = 0.12, value = 20, points = 12, weight = 55, form = "rabbit", color = {223, 201, 169}, scale = 0.8},
	fox = {name = "Red Fox", habitat = "meadow", rarity = "Uncommon", tier = 1, difficulty = 0.25, value = 48, points = 28, weight = 25, form = "fox", color = {221, 125, 69}, scale = 1},
	deer = {name = "Spotted Deer", habitat = "meadow", rarity = "Uncommon", tier = 2, difficulty = 0.3, value = 65, points = 38, weight = 20, form = "deer", color = {182, 137, 85}, scale = 1.25},
	monkey = {name = "Canopy Monkey", habitat = "jungle", rarity = "Common", tier = 1, difficulty = 0.18, value = 30, points = 18, weight = 60, form = "monkey", color = {135, 97, 65}, scale = 1},
	parrot = {name = "Scarlet Macaw", habitat = "jungle", rarity = "Rare", tier = 2, difficulty = 0.4, value = 130, points = 80, weight = 28, form = "bird", color = {233, 99, 90}, scale = 0.85},
	jaguar = {name = "Golden Jaguar", habitat = "jungle", rarity = "Epic", tier = 3, difficulty = 0.57, value = 320, points = 200, weight = 12, form = "cat", color = {227, 177, 70}, scale = 1.35},
	goat = {name = "Mountain Goat", habitat = "summit", rarity = "Uncommon", tier = 2, difficulty = 0.31, value = 75, points = 45, weight = 78, form = "goat", color = {221, 224, 224}, scale = 1.1},
	snowLeopard = {name = "Snow Leopard", habitat = "summit", rarity = "Legendary", tier = 4, difficulty = 0.69, value = 950, points = 650, weight = 5, form = "cat", color = {200, 218, 228}, scale = 1.4},
	eagle = {name = "Crowned Eagle", habitat = "summit", rarity = "Rare", tier = 2, difficulty = 0.42, value = 150, points = 100, weight = 17, form = "bird", color = {131, 108, 85}, scale = 1.25},
	reefFish = {name = "Sunstripe Fish", habitat = "reef", rarity = "Common", tier = 1, difficulty = 0.15, value = 25, points = 15, weight = 72, form = "fish", color = {255, 181, 69}, scale = 0.9},
	seaTurtle = {name = "Emerald Turtle", habitat = "reef", rarity = "Rare", tier = 2, difficulty = 0.4, value = 165, points = 105, weight = 28, form = "turtle", color = {77, 161, 124}, scale = 1.3, gear = "snorkel"},
	dolphin = {name = "Bluewater Dolphin", habitat = "ocean", rarity = "Epic", tier = 3, difficulty = 0.53, value = 380, points = 240, weight = 85, form = "dolphin", color = {105, 178, 205}, scale = 1.8, gear = "snorkel"},
	whale = {name = "Ancient Whale", habitat = "ocean", rarity = "Legendary", tier = 4, difficulty = 0.72, value = 1400, points = 900, weight = 15, form = "whale", color = {74, 120, 157}, scale = 3.2, gear = "diving"},
	auroraRay = {name = "Aurora Manta", habitat = "reef", rarity = "Mythic", tier = 3, difficulty = 0.48, value = 1800, points = 1200, weight = 1, form = "ray", color = {144, 132, 244}, scale = 2, gear = "snorkel", eventOnly = true},
	capybara = {name = "River Capybara", habitat = "meadow", rarity = "Common", tier = 1, difficulty = 0.17, value = 32, points = 19, weight = 35, form = "rodent", color = {155, 116, 75}, scale = 1.05},
	raccoon = {name = "Masked Raccoon", habitat = "meadow", rarity = "Uncommon", tier = 1, difficulty = 0.27, value = 55, points = 32, weight = 22, form = "raccoon", color = {137, 143, 143}, scale = 0.9},
	boar = {name = "Hidden Tusk Boar", habitat = "meadow", rarity = "Rare", tier = 2, difficulty = 0.43, value = 180, points = 115, weight = 18, form = "boar", color = {114, 86, 68}, scale = 1.2},
	redPanda = {name = "Ember Red Panda", habitat = "jungle", rarity = "Rare", tier = 2, difficulty = 0.42, value = 190, points = 125, weight = 22, form = "panda", color = {174, 88, 54}, scale = 0.95},
	peacock = {name = "Jade Peacock", habitat = "jungle", rarity = "Rare", tier = 2, difficulty = 0.45, value = 210, points = 135, weight = 17, form = "bird", color = {55, 143, 150}, scale = 1, pattern = "fan"},
	tiger = {name = "Sun Temple Tiger", habitat = "jungle", rarity = "Legendary", tier = 4, difficulty = 0.71, value = 1200, points = 800, weight = 5, form = "cat", color = {224, 146, 57}, scale = 1.5, pattern = "stripes"},
	ibex = {name = "Moonstone Ibex", habitat = "summit", rarity = "Epic", tier = 3, difficulty = 0.55, value = 410, points = 270, weight = 18, form = "goat", color = {155, 138, 117}, scale = 1.25},
	arcticFox = {name = "Frostlight Fox", habitat = "summit", rarity = "Epic", tier = 3, difficulty = 0.58, value = 450, points = 290, weight = 15, form = "fox", color = {231, 236, 237}, scale = 1},
	mackerel = {name = "Silver Mackerel", habitat = "ocean", rarity = "Common", tier = 1, difficulty = 0.2, value = 36, points = 22, weight = 65, form = "fish", color = {130, 167, 184}, scale = 1.05},
	seal = {name = "Harbor Seal", habitat = "ocean", rarity = "Uncommon", tier = 2, difficulty = 0.31, value = 88, points = 55, weight = 35, form = "seal", color = {145, 154, 158}, scale = 1.25},
	hammerhead = {name = "Dusk Hammerhead", habitat = "ocean", rarity = "Legendary", tier = 4, difficulty = 0.74, value = 1550, points = 1000, weight = 8, form = "shark", color = {106, 132, 142}, scale = 2, gear = "diving"},
	axolotl = {name = "Rosewater Axolotl", habitat = "reef", rarity = "Epic", tier = 3, difficulty = 0.52, value = 390, points = 250, weight = 12, form = "axolotl", color = {235, 176, 185}, scale = 1.1, gear = "snorkel"},
} :: {[string]: Species}
Catalog.SpeciesOrder = {"rabbit", "fox", "deer", "monkey", "parrot", "jaguar", "goat", "eagle", "snowLeopard", "reefFish", "seaTurtle", "dolphin", "whale", "auroraRay", "capybara", "raccoon", "boar", "redPanda", "peacock", "tiger", "ibex", "arcticFox", "mackerel", "seal", "hammerhead", "axolotl"}
Catalog.Items = {
	rangerNet = {name = "Ranger Net", price = 180, description = "Tier 2 • deer, birds, turtles and better odds", kind = "net", tier = 2},
	snorkel = {name = "Reef Snorkel", price = 220, description = "60s swim endurance; handle turtles, dolphins and mantas", kind = "access"},
	lifeJacket = {name = "Expedition Life Jacket", price = 280, description = "+60s swim endurance; combines with your water gear", kind = "access"},
	expeditionNet = {name = "Expedition Net", price = 650, description = "Tier 3 • big cats, dolphins and rare events", kind = "net", tier = 3},
	tranquilizer = {name = "Rescue Tranquilizer", price = 1800, description = "Tier 4 • nonlethal capture of apex wildlife", kind = "net", tier = 4},
	diving = {name = "Deepwater Kit", price = 1100, description = "180s swim endurance; whales and snorkel access", kind = "access"},
	fieldPack = {name = "Expedition Pack", price = 400, description = "Carry 48 animals before returning to the Ark", kind = "capacity", capacity = 48},
	bait = {name = "Calming Bait ×5", price = 70, description = "+15% capture chance; one used per valid attempt", kind = "consumable"},
} :: {[string]: Item}
Catalog.ItemOrder = {"rangerNet", "snorkel", "lifeJacket", "expeditionNet", "fieldPack", "tranquilizer", "diving", "bait"}
Catalog.Challenges = {
	catches = {name = "Wildlife Watch", description = "Catch 8 animals", goal = 8, coins = 150, points = 100},
	distance = {name = "Over the Horizon", description = "Travel 1,200 studs", goal = 1200, coins = 125, points = 90},
	rare = {name = "Rare Encounters", description = "Catch 3 Rare or better animals", goal = 3, coins = 250, points = 175},
}
Catalog.ChallengeOrder = {"catches", "distance", "rare"}
Catalog.Checkpoints = {
	ark = {name = "Ark Sanctuary", mapId = "ark"},
	canopyDock = {name = "Canopy Landing", mapId = "canopy"},
	canopyGallery = {name = "Canopy Gallery", mapId = "canopy"},
	canopyVault = {name = "Old Conservatory", mapId = "canopy"},
	moonstoneDock = {name = "Moonstone Landing", mapId = "moonstone"},
	moonstoneCourt = {name = "Moonstone Court", mapId = "moonstone"},
	moonstoneVault = {name = "Forgotten Moonstone Room", mapId = "moonstone"},
} :: {[string]: {name: string, mapId: string}}
Catalog.Expeditions = {
	canopySurvey = {name = "Canopy Expedition", description = "Find Canopy Reach's 3 checkpoints and catch 4 island animals", checkpoints = {"canopyDock", "canopyGallery", "canopyVault"}, mapId = "canopy", catches = 4, rare = 0, coins = 300, points = 180},
	moonstoneSurvey = {name = "Moonstone Expedition", description = "Find 3 Moonstone checkpoints; catch 3 island animals including 1 Rare+", checkpoints = {"moonstoneDock", "moonstoneCourt", "moonstoneVault"}, mapId = "moonstone", catches = 3, rare = 1, coins = 400, points = 250},
	archipelagoVoyager = {name = "Three-Island Voyager", description = "Activate the Ark, Canopy Landing and Moonstone Landing checkpoints", checkpoints = {"ark", "canopyDock", "moonstoneDock"}, catches = 0, rare = 0, coins = 250, points = 150},
	chestScout = {name = "Curious Explorer", description = "Open 3 different surprise chests; traps count too", checkpoints = {}, catches = 0, rare = 0, chests = 3, coins = 200, points = 120},
} :: {[string]: any}
Catalog.ExpeditionOrder = {"canopySurvey", "moonstoneSurvey", "archipelagoVoyager", "chestScout"}
Catalog.Chests = {
	arkNursery = {obscure = false}, arkCellar = {obscure = true}, arkArchive = {obscure = true}, arkReef = {obscure = true},
	canopyEntry = {obscure = false}, canopyArchive = {obscure = false}, canopyThicket = {obscure = true}, canopyBurrow = {obscure = true},
	moonstoneOrchid = {obscure = true}, moonstoneEast = {obscure = false}, moonstonePoint = {obscure = true}, moonstoneVault = {obscure = true},
} :: {[string]: {obscure: boolean}}
Catalog.Loot = {
	{kind = "coins", weight = 35}, {kind = "animal", weight = 30}, {kind = "equipment", weight = 20},
	{kind = "pointsTrap", weight = 10}, {kind = "deathTrap", weight = 5},
}
Catalog.ChestEquipment = {"rangerNet", "snorkel", "lifeJacket", "fieldPack", "expeditionNet"}
return table.freeze(Catalog)
