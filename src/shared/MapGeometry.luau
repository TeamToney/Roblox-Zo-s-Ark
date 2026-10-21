--!strict
-- Image-space geometry shared by the builder, chart, export and layout tests.
export type Segment = {number}
local Geometry = {}
function Geometry.world(source: any, x: number, y: number): (number, number)
	return (x - source.pivotX) * source.scale + (source.offsetX or 0), (y - source.pivotY) * source.scale + (source.offsetZ or 0)
end
function Geometry.contains(rect: {number}, x: number, y: number, inset: number?): boolean
	local margin = inset or 0
	return x >= rect[1] + margin and x <= rect[3] - margin and y >= rect[2] + margin and y <= rect[4] - margin
end
function Geometry.center(rect: {number}): (number, number)
	return (rect[1] + rect[3]) / 2, (rect[2] + rect[4]) / 2
end
function Geometry.vertices(room: any): {{number}}
	if room.polygon then return room.polygon end
	local r = room.rect
	return {{r[1], r[2]}, {r[3], r[2]}, {r[3], r[4]}, {r[1], r[4]}}
end
function Geometry.walls(room: any): {Segment}
	local vertices = Geometry.vertices(room)
	local result = {}
	for index, a in vertices do
		local b = vertices[index % #vertices + 1]
		local horizontal = a[2] == b[2]
		local vertical = a[1] == b[1]
		local side = if horizontal then (if index == 1 then "north" else "south") else (if vertical then (if b[2] > a[2] then "east" else "west") else "diagonal")
		local gap = nil
		for _, opening in room.doors do if opening.side == side then gap = opening; break end end
		if not gap then
			table.insert(result, {a[1], a[2], b[1], b[2]})
		else
			local low, high = gap.center - gap.width / 2, gap.center + gap.width / 2
			if horizontal then
				local left, right = math.min(a[1], b[1]), math.max(a[1], b[1])
				assert(low > left and high < right, "Door extends past wall: " .. room.id)
				table.insert(result, {left, a[2], low, a[2]}); table.insert(result, {high, a[2], right, a[2]})
			else
				local top, bottom = math.min(a[2], b[2]), math.max(a[2], b[2])
				assert(low > top and high < bottom, "Door extends past wall: " .. room.id)
				table.insert(result, {a[1], top, a[1], low}); table.insert(result, {a[1], high, a[1], bottom})
			end
		end
	end
	return result
end
function Geometry.inWater(layout: any, x: number, y: number): boolean
	if not Geometry.contains(layout.Bounds, x, y) then return true end
	if layout.LandRects then
		local land = false
		for _, rect in layout.LandRects do if Geometry.contains(rect, x, y) then land = true; break end end
		if not land then return true end
	end
	for _, rect in layout.WaterCuts do if Geometry.contains(rect, x, y) then return true end end
	return false
end
function Geometry.floorTiles(layout: any): {{number}}
	local b = layout.Bounds
	local xs, ys = {b[1], b[3]}, {b[2], b[4]}
	for _, rect in layout.LandRects or {} do
		for _, x in {rect[1], rect[3]} do if x > b[1] and x < b[3] then table.insert(xs, x) end end
		for _, y in {rect[2], rect[4]} do if y > b[2] and y < b[4] then table.insert(ys, y) end end
	end
	for _, cut in layout.WaterCuts do
		for _, x in {cut[1], cut[3]} do if x > b[1] and x < b[3] then table.insert(xs, x) end end
		for _, y in {cut[2], cut[4]} do if y > b[2] and y < b[4] then table.insert(ys, y) end end
	end
	table.sort(xs); table.sort(ys)
	local tiles = {}
	for j = 1, #ys - 1 do
		for i = 1, #xs - 1 do
			if xs[i + 1] > xs[i] and ys[j + 1] > ys[j] and not Geometry.inWater(layout, (xs[i] + xs[i + 1]) / 2, (ys[j] + ys[j + 1]) / 2) then
				table.insert(tiles, {xs[i], ys[j], xs[i + 1], ys[j + 1]})
			end
		end
	end
	return tiles
end
function Geometry.distanceToSegment(x: number, y: number, segment: Segment): number
	local dx, dy = segment[3] - segment[1], segment[4] - segment[2]
	local t = math.clamp(((x - segment[1]) * dx + (y - segment[2]) * dy) / (dx * dx + dy * dy), 0, 1)
	return math.sqrt((x - segment[1] - dx * t) ^ 2 + (y - segment[2] - dy * t) ^ 2)
end
function Geometry.foundationColumns(layout: any): {{rect: {number}, top: number, bottom: number}}
	assert(layout.SeabedY < layout.WaterY and layout.WaterY < layout.FloorY, "Invalid island water/ground heights")
	local columns = {}
	for _, rect in Geometry.floorTiles(layout) do
		table.insert(columns, {rect = rect, top = layout.FloorY, bottom = layout.SeabedY - 4})
	end
	return columns
end
function Geometry.scanline(polygon: {{number}}, y: number): {number}
	local intersections = {}
	for index, a in polygon do
		local b = polygon[index % #polygon + 1]
		if (a[2] <= y and b[2] > y) or (b[2] <= y and a[2] > y) then
			table.insert(intersections, a[1] + (y - a[2]) / (b[2] - a[2]) * (b[1] - a[1]))
		end
	end
	table.sort(intersections)
	return intersections
end
return Geometry
