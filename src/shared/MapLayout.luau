--!strict
-- Hand-traced from the MAP 1.jpeg attachment. Coordinates refer to the image,
-- not measured architectural dimensions. North = image top = world -Z.
export type Rect = {number}
export type Door = {side: string, center: number, width: number}
export type Room = {id: string, name: string, rect: Rect?, polygon: {{number}}?, kind: string, doors: {Door}, height: number?}
export type Zone = {id: string, name: string, habitat: string, rect: Rect, count: number, extension: boolean?}
local Layout = {}
Layout.Name = "Zo Sanctuary / Map 1"
Layout.Source = {name = "MAP 1.jpeg", width = 1530, height = 1632, pivotX = 765, pivotY = 835, scale = 0.6}
Layout.Bounds = {55, 60, 1490, 1610} :: Rect
Layout.FloorY = 10
Layout.WaterY = 2
Layout.WallHeight = 8
Layout.WallThickness = 1.2
Layout.Hub = {814, 700}
Layout.Spawn = {814, 1550}
Layout.WaterCuts = {
	{1133, 214, 1380, 552}, -- Interior of the large eastern hall.
	{1380, 362, 1500, 412}, -- Gameplay sea gate; extends the eastern opening.
} :: {Rect}

local function room(id: string, name: string, rect: Rect, kind: string, doors: {Door}, height: number?): Room
	return {id = id, name = name, rect = rect, kind = kind, doors = doors, height = height}
end
local function door(side: string, center: number, width: number?): Door
	return {side = side, center = center, width = width or 30}
end
Layout.Rooms = {
	room("nursery", "Rescue Nursery", {160, 123, 360, 236}, "room", {door("south", 260, 36)}),
	room("meadowHall", "Meadow Hall", {145, 240, 370, 418}, "meadow", {door("south", 260, 38), door("north", 260, 36)}),
	room("canopyHall", "Canopy Hall", {378, 199, 609, 331}, "jungle", {door("east", 275, 40)}),
	room("fieldLab1", "Field Lab", {378, 340, 437, 386}, "room", {door("south", 407, 24)}),
	room("fieldLab2", "Care Room", {468, 340, 524, 386}, "room", {door("south", 496, 24)}),
	room("fieldLab3", "Bird Clinic", {551, 340, 609, 386}, "room", {door("south", 580, 24)}),
	room("westLounge", "Ranger Lounge", {145, 439, 332, 543}, "room", {door("south", 260, 36)}),
	room("westOffice", "Habitat Office", {366, 420, 435, 543}, "room", {door("east", 482, 30)}),
	room("research", "Research Gallery", {468, 420, 609, 472}, "room", {door("south", 535, 32)}),
	room("supply", "Supply Hall", {468, 480, 665, 548}, "room", {door("south", 560, 40)}),
	room("summitHall", "Cloudpeak Conservatory", {675, 223, 958, 455}, "summit", {door("south", 814, 44), door("east", 352, 40)}),
	room("northGallery1", "Discovery Gallery", {742, 66, 886, 154}, "room", {door("south", 814, 32)}),
	room("northGallery2", "Ranger Archives", {890, 66, 1034, 154}, "room", {door("south", 962, 32)}),
	room("northGallery3", "Ocean Archives", {1038, 66, 1205, 154}, "room", {door("south", 1120, 32)}),
	room("northGallery4", "Expedition Studio", {1210, 66, 1384, 154}, "room", {door("south", 1297, 32)}),
	room("eastOffice", "Marine Care", {1019, 197, 1106, 240}, "room", {door("west", 219, 24)}),
	room("eastLab1", "Reef Lab", {1019, 250, 1057, 354}, "room", {door("south", 1038, 22)}),
	room("eastLab2", "Ocean Lab", {1068, 250, 1106, 354}, "room", {door("south", 1087, 22)}),
	room("eastLab3", "Marine Supplies", {1019, 417, 1106, 459}, "room", {door("west", 438, 24)}),
	room("eastLab4", "Dive Prep", {1052, 466, 1106, 546}, "room", {door("south", 1079, 24)}),
	room("marineHall", "Tidewater Hall", {1115, 198, 1384, 568}, "marine", {door("west", 393, 46), door("east", 387, 56)}),
	room("serviceNorth", "Expedition Lockers", {693, 496, 788, 566}, "room", {door("south", 741, 30)}),
	room("serviceEast", "Ranger Dispatch", {843, 496, 932, 566}, "room", {door("south", 887, 30)}),
	room("atriumWest1", "West Expedition Room", {558, 578, 664, 692}, "room", {door("east", 636, 32)}),
	room("atriumWest2", "West Field Room", {558, 707, 664, 810}, "room", {door("east", 757, 32)}),
	room("atriumEast1", "East Expedition Room", {963, 578, 1068, 692}, "room", {door("west", 636, 32)}),
	room("atriumEast2", "East Field Room", {963, 707, 1068, 810}, "room", {door("west", 757, 32)}),
	{id = "arkAtrium", name = "Ark Atrium", kind = "atrium", polygon = {{692, 620}, {934, 620}, {934, 746}, {814, 812}, {692, 746}}, doors = {door("north", 814, 52)}},
	room("galleryNW", "West Discovery Room", {163, 875, 291, 1002}, "room", {door("east", 940, 34)}),
	room("galleryW1", "Woodland Gallery", {340, 899, 524, 1002}, "room", {door("south", 432, 34)}),
	room("galleryW2", "Tracking Workshop", {561, 899, 663, 1002}, "room", {door("south", 612, 30)}),
	room("galleryCW", "Collection Gallery", {693, 875, 792, 1002}, "room", {door("east", 937, 30)}),
	room("galleryCE", "Conservation Gallery", {834, 875, 933, 1002}, "room", {door("west", 937, 30)}),
	room("galleryE1", "Challenge Gallery", {962, 899, 1063, 1002}, "room", {door("south", 1012, 30)}),
	room("galleryE2", "Ocean Discovery", {1100, 899, 1288, 1002}, "room", {door("south", 1194, 34)}),
	room("galleryNE", "East Discovery Room", {1337, 875, 1463, 1002}, "room", {door("west", 940, 34)}),
	room("westLookout", "West Lookout", {340, 1035, 420, 1134}, "room", {door("north", 380, 30)}),
	room("eastLookout", "East Lookout", {1204, 1035, 1280, 1134}, "room", {door("north", 1242, 30)}),
	room("southW1", "Rescue Workshop", {426, 1034, 526, 1134}, "room", {door("north", 476, 30)}),
	room("southW2", "Field Equipment", {544, 1034, 663, 1134}, "room", {door("north", 604, 30)}),
	room("southE1", "Aquatic Workshop", {963, 1034, 1065, 1134}, "room", {door("north", 1014, 30)}),
	room("southE2", "Ocean Equipment", {1083, 1034, 1199, 1134}, "room", {door("north", 1141, 30)}),
	room("westUpper", "West Observation", {182, 1034, 291, 1146}, "room", {door("east", 1090, 32)}),
	room("westMiddle", "Meadow Learning", {182, 1153, 291, 1267}, "room", {door("east", 1210, 32)}),
	room("westInner", "Keeper's Room", {318, 1153, 426, 1267}, "room", {door("east", 1210, 32)}),
	room("westLink", "Meadow Field Station", {334, 1275, 414, 1336}, "room", {door("east", 1306, 28)}),
	room("westFoot1", "West Ranger Post", {182, 1345, 291, 1447}, "room", {door("north", 237, 32)}),
	room("westFoot2", "Meadow Ranger Post", {320, 1345, 428, 1447}, "room", {door("north", 374, 32)}),
	room("eastUpper", "East Observation", {1337, 1034, 1442, 1146}, "room", {door("west", 1090, 32)}),
	room("eastMiddle", "Canopy Learning", {1337, 1153, 1442, 1267}, "room", {door("west", 1210, 32)}),
	room("eastInner", "Keeper's Room East", {1202, 1153, 1307, 1267}, "room", {door("west", 1210, 32)}),
	room("eastLink", "Canopy Field Station", {1212, 1275, 1294, 1336}, "room", {door("west", 1306, 28)}),
	room("eastFoot1", "Canopy Ranger Post", {1202, 1345, 1307, 1447}, "room", {door("north", 1254, 32)}),
	room("eastFoot2", "East Ranger Post", {1337, 1345, 1442, 1447}, "room", {door("north", 1390, 32)}),
	room("centralW1", "Explorer's Library", {693, 1034, 792, 1134}, "room", {door("east", 1084, 30)}),
	room("centralE1", "Explorer's Workshop", {834, 1034, 934, 1134}, "room", {door("west", 1084, 30)}),
	room("centralW2", "Meadow Passage", {693, 1141, 792, 1250}, "room", {door("east", 1196, 30), door("west", 1196, 32)}),
	room("centralE2", "Canopy Passage", {834, 1141, 934, 1250}, "room", {door("west", 1196, 30), door("east", 1196, 32)}),
	room("centralW3", "West Arrival Room", {693, 1258, 792, 1368}, "room", {door("east", 1313, 30)}),
	room("centralE3", "East Arrival Room", {834, 1258, 934, 1368}, "room", {door("west", 1313, 30)}),
	room("arrivalW", "Welcome West", {718, 1385, 786, 1456}, "room", {door("east", 1420, 28)}),
	room("arrivalE", "Welcome East", {839, 1385, 908, 1456}, "room", {door("west", 1420, 28)}),
	room("entry", "Sanctuary Entrance", {691, 1488, 937, 1606}, "entry", {door("north", 814, 48)}),
} :: {Room}

Layout.Corridors = {
	{108, 388, 668, 438}, {106, 546, 1114, 576},
	{610, 158, 668, 546}, {963, 158, 1017, 575},
	{667, 575, 691, 818}, {935, 575, 962, 818}, {667, 575, 962, 620},
	{144, 812, 1468, 875}, {795, 812, 832, 1488},
	{162, 1003, 1464, 1033}, {294, 1033, 317, 1449}, {1309, 1033, 1334, 1449},
	{162, 1135, 1464, 1152}, {162, 1337, 1464, 1344}, {645, 1457, 983, 1488},
} :: {Rect}
Layout.Courtyards = {
	{id = "meadowCourt", name = "Meadow Courtyard", habitat = "meadow", rect = {434, 1154, 680, 1443}, count = 5},
	{id = "canopyCourt", name = "Canopy Courtyard", habitat = "jungle", rect = {944, 1154, 1190, 1443}, count = 5},
} :: {Zone}
Layout.Zones = {
	{id = "meadowHall", name = "Meadow Hall", habitat = "meadow", rect = {158, 254, 356, 403}, count = 5},
	{id = "canopyHall", name = "Canopy Hall", habitat = "jungle", rect = {393, 215, 593, 315}, count = 4},
	{id = "summitHall", name = "Cloudpeak Conservatory", habitat = "summit", rect = {695, 244, 940, 433}, count = 6},
	{id = "meadowCourt", name = "Meadow Courtyard", habitat = "meadow", rect = {449, 1170, 665, 1427}, count = 5},
	{id = "canopyCourt", name = "Canopy Courtyard", habitat = "jungle", rect = {960, 1170, 1175, 1427}, count = 5},
	{id = "reefPool", name = "Sunlit Reef Pool", habitat = "reef", rect = {1154, 237, 1358, 360}, count = 5},
	{id = "oceanPool", name = "Bluewater Pool", habitat = "ocean", rect = {1154, 422, 1358, 490}, count = 3},
	{id = "openSea", name = "Open Sea", habitat = "ocean", rect = {1550, 240, 1830, 600}, count = 3, extension = true},
} :: {Zone}
Layout.Boats = {{1180, 507}, {1215, 507}, {1250, 507}}
Layout.Dock = {1140, 534, 1280, 542} :: Rect
Layout.DockRamp = {1140, 542, 1280, 552} :: Rect
Layout.SwimSteps = {1140, 523, 1280, 534} :: Rect
Layout.SeaGate = {1430, 387}
return table.freeze(Layout)
