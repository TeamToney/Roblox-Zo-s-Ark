--!strict
local Layout = require("../src/shared/MapLayout")
local Geometry = require("../src/shared/MapGeometry")
local Config = require("../src/shared/Config")
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
print(encode({layout = Layout, walls = walls, floorTiles = Geometry.floorTiles(Layout), travelRadius = Config.MaxWorldRadius}))
