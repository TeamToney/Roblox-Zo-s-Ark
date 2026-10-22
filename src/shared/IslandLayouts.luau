--!strict
-- Approximate, north-up traces of the two additional inline floor plans.
-- Source 1: long upper/bottom galleries and a western complex.
-- Source 2: northwest court, east gallery loop and southwest pointed hall.
local Islands = {}
local function room(id: string, name: string, rect: {number}, kind: string, doors: {any}): any
	return {id = id, name = name, rect = rect, kind = kind, doors = doors}
end
local function door(side: string, center: number, width: number?): any
	return {side = side, center = center, width = width or 32}
end
local canopy: any = {
	Id = "canopy", Name = "Canopy Reach", Reference = "First additional floor-plan image",
	Source = {width = 1426, height = 1104, pivotX = 743, pivotY = 550, scale = 0.55, offsetX = 1150, offsetZ = -650},
	Bounds = {90, 78, 1405, 1015}, FloorY = 10, WaterY = 2, SeabedY = -58, WaterCuts = {},
	LandRects = {{490, 78, 1225, 220}, {95, 205, 1225, 310}, {95, 310, 1025, 640}, {95, 640, 790, 718}, {90, 718, 1405, 940}, {585, 940, 790, 1015}},
	WallHeight = 14, WallThickness = 1,
	Corridors = {{95, 401, 700, 435}, {295, 220, 326, 812}, {674, 210, 700, 846}, {630, 185, 1225, 224}, {98, 812, 1395, 846}, {326, 516, 594, 582}, {700, 634, 790, 655}},
	Courtyards = {},
	Rooms = {
		room("northHall", "Canopy Assembly Hall", {505, 92, 630, 210}, "jungle", {door("south", 570, 40)}),
		room("northStudy", "Canopy Archives", {640, 98, 735, 181}, "room", {door("south", 686)}),
		room("westStudy", "Ranger Study", {239, 226, 281, 300}, "room", {door("east", 260, 26)}),
		room("westFoyer", "Western Foyer", {157, 307, 281, 400}, "meadow", {door("south", 220, 38)}),
		room("palmCourt", "Palm Court", {332, 226, 393, 400}, "jungle", {door("south", 363, 34)}),
		room("greatHall", "Living Canopy Hall", {402, 226, 592, 400}, "jungle", {door("south", 500, 44)}),
		room("eastGallery", "East Field Gallery", {600, 254, 672, 400}, "room", {door("south", 638)}),
		room("westHabitat", "Woodland Hall", {157, 440, 292, 574}, "meadow", {door("east", 507, 38)}),
		room("westLibrary", "Old Ranger Library", {157, 584, 291, 696}, "room", {door("east", 640, 38)}),
		room("hiddenMeadow", "Forgotten Field Room", {157, 704, 291, 808}, "meadow", {door("east", 754, 38)}),
		room("fieldStation", "Field Station", {332, 584, 405, 696}, "jungle", {door("west", 640, 36)}),
		room("oldConservatory", "Old Conservatory", {414, 524, 590, 724}, "jungle", {door("north", 502, 44), door("south", 502, 44)}),
		room("longGallery", "Long Discovery Room", {600, 514, 672, 724}, "room", {door("east", 618, 38)}),
		room("greatMeadow", "Eastern Meadow Hall", {706, 308, 874, 542}, "meadow", {door("north", 790, 44), door("south", 790, 40), door("east", 420, 40)}),
		room("sideMeadow", "Fern Annex", {886, 308, 1012, 555}, "meadow", {door("west", 420, 40)}),
		room("careGallery", "Care Gallery", {706, 552, 874, 631}, "room", {door("north", 790, 40), door("south", 744, 34)}),
		room("lowerLink", "Lower Passage", {706, 662, 777, 724}, "room", {door("south", 742, 36), door("north", 742, 36)}),
		room("southEntry", "Canopy Arrival Hall", {622, 852, 777, 994}, "entry", {door("north", 700, 44)}),
	},
	Zones = {
		{id = "canopyHall", name = "Canopy Hall", habitat = "jungle", rect = {418, 242, 578, 386}, count = 4},
		{id = "canopyMeadow", name = "Woodland Hall", habitat = "meadow", rect = {170, 454, 279, 560}, count = 3},
		{id = "canopyEast", name = "Eastern Meadow", habitat = "meadow", rect = {722, 324, 858, 526}, count = 3},
		{id = "canopySecret", name = "Old Conservatory", habitat = "jungle", rect = {428, 540, 576, 708}, count = 3, obscure = true},
		{id = "canopyBurrow", name = "Forgotten Field Room", habitat = "meadow", rect = {170, 718, 278, 794}, count = 2, obscure = true},
		{id = "canopyCove", name = "Duskwater Cove", habitat = "ocean", rect = {1070, 345, 1190, 510}, count = 2, obscure = true},
	},
	Dock = {x = 90, y = 828, dx = -1, dy = 0},
	ShoreExits = {{x = 90, y = 828, dx = -1, dy = 0}, {x = 1225, y = 205, dx = 1, dy = 0}, {x = 1394, y = 940, dx = 0, dy = 1}},
	Checkpoints = {{id = "canopyDock", x = 125, y = 828}, {id = "canopyGallery", x = 686, y = 420}, {id = "canopyVault", x = 502, y = 620}},
	Chests = {{id = "canopyEntry", x = 700, y = 930}, {id = "canopyArchive", x = 686, y = 140}, {id = "canopyThicket", x = 546, y = 680}, {id = "canopyBurrow", x = 220, y = 772}},
}
for index = 0, 4 do
	local x = 762 + index * 89
	table.insert(canopy.Rooms, room("northRoom" .. index, "Northern Field Room", {x, 98, x + 83, 181}, "room", {door("south", x + 42)}))
end
for index = 0, 2 do
	local x = 332 + index * 87
	table.insert(canopy.Rooms, room("workshop" .. index, "Canopy Workshop", {x, 442, x + 79, 514}, "room", {door("north", x + 40)}))
end
for _, row in {{155, 5, 86}, {786, 7, 86}} do
	for index = 0, row[2] - 1 do
		local x = row[1] + index * row[3]
		if x >= 327 then table.insert(canopy.Rooms, room("galleryN" .. x, "North Gallery Room", {x, 734, x + 78, 808}, "room", {door("south", x + 39)})) end
		table.insert(canopy.Rooms, room("galleryS" .. x, "South Gallery Room", {x, 852, x + 78, 930}, "room", {door("north", x + 39)}))
	end
end

local moonstone: any = {
	Id = "moonstone", Name = "Moonstone Isle", Reference = "Second additional floor-plan image",
	Source = {width = 1426, height = 1104, pivotX = 700, pivotY = 540, scale = 0.55, offsetX = 1150, offsetZ = 500},
	Bounds = {75, 55, 1325, 1010}, FloorY = 10, WaterY = 2, SeabedY = -58, WaterCuts = {},
	LandRects = {{75, 80, 600, 390}, {360, 55, 630, 230}, {600, 145, 1325, 280}, {615, 260, 1135, 445}, {595, 205, 650, 510}, {1120, 140, 1325, 555}, {80, 440, 1320, 574}, {470, 500, 970, 1010}, {970, 615, 1325, 840}, {320, 750, 560, 940}, {945, 840, 1270, 940}},
	WallHeight = 14, WallThickness = 1,
	Corridors = {{350, 95, 374, 390}, {600, 207, 1320, 224}, {600, 224, 650, 510}, {1200, 224, 1230, 510}, {80, 486, 1320, 510}, {555, 510, 577, 820}, {620, 510, 650, 840}, {470, 640, 970, 668}, {555, 820, 970, 850}, {970, 615, 1030, 940}},
	Courtyards = {},
	Rooms = {
		room("orchidHall", "Orchid Hall", {100, 100, 350, 300}, "jungle", {door("east", 250, 40), door("south", 228, 40)}),
		room("orchidAnnex", "Overgrown Orchid Annex", {81, 306, 365, 380}, "jungle", {door("north", 228, 40), door("east", 343, 36)}),
		room("northCourt", "Northern Field Court", {380, 145, 597, 270}, "meadow", {door("west", 220, 36), door("east", 220, 40), door("south", 500, 40)}),
		room("middleStudy", "Moonstone Study", {484, 285, 597, 380}, "room", {door("east", 330, 34)}),
		room("innerMeadow", "Great Meadow Court", {700, 285, 1120, 438}, "meadow", {door("north", 920, 40), door("south", 920, 44), door("east", 360, 40)}),
		room("southStudyW", "Western Study", {480, 516, 555, 632}, "room", {door("north", 518), door("south", 518)}),
		room("southStudyE", "Eastern Study", {584, 516, 618, 632}, "room", {door("south", 601, 24)}),
		room("southMeadow", "Southern Field Hall", {656, 516, 865, 638}, "meadow", {door("north", 750, 40), door("south", 750, 40)}),
		room("summitLink", "Mountain Passage", {876, 516, 944, 630}, "room", {door("south", 910, 34)}),
		room("eastGreat", "Moonstone Conservatory", {1036, 635, 1318, 835}, "summit", {door("west", 720, 44)}),
		room("hiddenSummit", "Forgotten Moonstone Room", {830, 854, 967, 990}, "summit", {door("north", 900, 36)}),
		room("bottomLodge", "Expedition Lodge", {670, 858, 780, 995}, "room", {door("north", 725, 36)}),
		room("southEast", "Lower Ranger Gallery", {1040, 852, 1260, 932}, "room", {door("west", 890, 36)}),
		{id = "pointedHall", name = "Pointed Woodland Hall", kind = "jungle", polygon = {{430, 755}, {555, 755}, {555, 800}, {537, 817}, {537, 852}, {555, 870}, {555, 935}, {430, 935}, {430, 920}, {325, 920}, {325, 770}, {430, 770}}, doors = {door("north", 500, 36)}},
	},
	Zones = {
		{id = "moonstoneOrchid", name = "Orchid Hall", habitat = "jungle", rect = {116, 116, 332, 282}, count = 3},
		{id = "moonstoneMeadow", name = "Great Meadow", habitat = "meadow", rect = {716, 302, 1102, 420}, count = 4},
		{id = "moonstoneSummit", name = "Moonstone Conservatory", habitat = "summit", rect = {1054, 653, 1300, 816}, count = 4},
		{id = "moonstoneOrchidSecret", name = "Orchid Annex", habitat = "jungle", rect = {104, 322, 340, 365}, count = 2, obscure = true},
		{id = "moonstoneMoonSecret", name = "Forgotten Moonstone Room", habitat = "summit", rect = {846, 870, 950, 974}, count = 3, obscure = true},
		{id = "moonstonePointSecret", name = "Pointed Woodland Hall", habitat = "jungle", rect = {448, 778, 520, 914}, count = 2, obscure = true},
		{id = "moonstoneReefSecret", name = "Rosewater Inlet", habitat = "reef", rect = {350, 600, 450, 720}, count = 2, obscure = true},
	},
	Dock = {x = 80, y = 498, dx = -1, dy = 0},
	ShoreExits = {{x = 80, y = 498, dx = -1, dy = 0}, {x = 850, y = 145, dx = 0, dy = -1}, {x = 1000, y = 940, dx = 0, dy = 1}},
	Checkpoints = {{id = "moonstoneDock", x = 108, y = 498}, {id = "moonstoneCourt", x = 750, y = 600}, {id = "moonstoneVault", x = 900, y = 920}},
	Chests = {{id = "moonstoneOrchid", x = 160, y = 344}, {id = "moonstoneEast", x = 1250, y = 750}, {id = "moonstonePoint", x = 470, y = 880}, {id = "moonstoneVault", x = 920, y = 950}},
}
for index = 0, 5 do
	local x = 638 + index * 73
	table.insert(moonstone.Rooms, room("upper" .. index, "Northern Gallery Room", {x, 158, x + 67, 204}, "room", {door("south", x + 34, 28)}))
end
for index = 0, 3 do
	local x = 776 + index * 75
	table.insert(moonstone.Rooms, room("upperInner" .. index, "Inner Gallery Room", {x, 230, x + 68, 275}, "room", {door("north", x + 34, 28)}))
	local y = 230 + index * 65
	table.insert(moonstone.Rooms, room("eastOuter" .. index, "Eastern Gallery Room", {1234, y, 1310, y + 59}, "room", {door("west", y + 29, 28)}))
	table.insert(moonstone.Rooms, room("eastInner" .. index, "Eastern Study Room", {1136, y, 1196, y + 59}, "room", {door("east", y + 29, 28)}))
end
for index = 0, 6 do
	local x = 90 + index * 73
	table.insert(moonstone.Rooms, room("middleN" .. index, "Middle Gallery Room", {x, 448, x + 67, 482}, "room", {door("south", x + 34, 28)}))
end
for index = 0, 3 do
	local x = 90 + index * 72
	table.insert(moonstone.Rooms, room("middleS" .. index, "Lower Gallery Room", {x, 516, x + 65, 565}, "room", {door("north", x + 32, 28)}))
end
Islands.Islands = {canopy, moonstone}
return table.freeze(Islands)
