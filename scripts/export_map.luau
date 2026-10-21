--!strict
local Layout = require("../src/shared/MapLayout")
local Geometry = require("../src/shared/MapGeometry")
local Config = require("../src/shared/Config")
local Islands = require("../src/shared/IslandLayouts")
local Forestry = require("../src/shared/ForestryLayout")
local function encode(value: any): string
	local kind = type(value)
	if kind == "string" then
		local escaped = value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
		return '"' .. escaped .. '"'
	elseif kind == "number" or kind == "boolean" then return tostring(value)
	elseif kind == "table" then
		local entries = {}
		if #value > 0 then
			for _, child in value do table.insert(entries, encode(child)) end
			return "[" .. table.concat(entries, ",") .. "]"
		end
		local keys = {}
		for key in value do table.insert(keys, key) end
		table.sort(keys)
		for _, key in keys do table.insert(entries, encode(key) .. ":" .. encode(value[key])) end
		return "{" .. table.concat(entries, ",") .. "}"
	end
	error("Unsupported map data type: " .. kind)
end
local walls = {}
for _, room in Layout.Rooms do
	for _, segment in Geometry.walls(room) do table.insert(walls, segment) end
end
local islands = {}
for _, plan in Islands.Islands do
	local segments = {}
	for _, room in plan.Rooms do for _, line in Geometry.walls(room) do table.insert(segments, line) end end
	table.insert(islands, {layout = plan, walls = segments, floorTiles = Geometry.floorTiles(plan), forestry = Forestry.generate(plan,Geometry)})
end
print(encode({layout = Layout, walls = walls, floorTiles = Geometry.floorTiles(Layout), islands = islands, forestry = Forestry.generate(Layout,Geometry), travelRadius = Config.MaxWorldRadius, seaBounds = Config.SeaBounds}))
