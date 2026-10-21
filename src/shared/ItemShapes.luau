--!strict
-- Original display props used by both the physical shop and viewport cards.
local Shapes = {}
function Shapes.build(id: string, kind: string): {any}
	local parts: {any} = {}
	local mint, gold, navy, tan = {48,244,190}, {255,210,49}, {23,61,96}, {222,155,79}
	local function add(size: {number}, at: {number}, color: {number}, shape: string?)
		table.insert(parts, {size = size, at = at, color = color, shape = shape or "block"})
	end
	if id == "mapPass" then
		add({2.8,3.2,0.18}, {0,0,0}, tan)
		add({2.3,2.7,0.08}, {0,0,-0.14}, mint)
		add({0.9,0.8,0.12}, {-0.5,0.6,-0.22}, gold)
		add({1.1,0.8,0.12}, {0.45,-0.45,-0.22}, navy)
	elseif id == "teleportPass" then
		add({2.8,1.8,0.3}, {0,0,0}, {182,89,255})
		for i=1,10 do local a=i*math.pi/5; add({0.2,0.2,0.2},{math.cos(a)*0.65,math.sin(a)*0.65,-0.24},mint,"ball") end
	elseif id == "tranquilizer" then
		add({3.8,0.55,0.65}, {0,0.2,0}, navy)
		add({1.3,0.9,0.7}, {-2,0,0}, tan)
		add({0.4,1,0.5}, {-0.7,-0.5,0}, mint)
		add({1.1,0.3,0.3}, {0.2,0.75,0}, gold)
		add({0.35,0.7,0.75}, {1.9,0.2,0}, mint)
	elseif kind == "net" then
		add({0.2,3.8,0.2}, {0,-0.4,0}, tan)
		for i = 1, 12 do local a = i * math.pi / 6; add({0.28,0.28,0.3}, {math.cos(a)*1.2,2+math.sin(a)*1.2,0}, if id == "expeditionNet" then gold else mint, "ball") end
		for i = -2, 2 do add({0.06,2,0.06}, {i*0.35,2,0}, navy); add({2,0.06,0.06}, {0,2+i*0.35,0}, navy) end
	elseif id == "speedBoost" then
		add({1.5,2.2,1.5}, {0,0,0}, mint, "ball"); add({0.8,0.5,0.8}, {0,1.2,0}, gold)
		add({0.25,1.2,0.1}, {0,0,0.76}, gold); add({0.8,0.18,0.1}, {0,0,0.76}, gold)
	elseif id == "animalTrap" then
		add({3.6,0.2,2.5}, {0,-0.9,0}, tan)
		for _, x in {-1.5,1.5} do add({0.2,2.3,0.2}, {x,0,0}, mint) end
		add({3.2,0.2,0.2}, {0,1.1,0}, mint); add({1.2,0.18,1.2}, {0,-0.65,0}, gold)
	elseif id == "tracker" then
		add({2.4,3,0.65}, {0,0,0}, navy); add({1.9,1.9,0.1}, {0,0.3,-0.38}, mint)
		add({0.15,1.2,0.15}, {0.8,2,0}, tan); add({0.3,0.3,0.15}, {0,-0.95,-0.4}, gold, "ball")
	elseif id == "safariHat" then
		add({3.8,0.25,3.5}, {0,-0.4,0}, tan); add({2.3,1.4,2}, {0,0.35,0}, tan)
		add({2.4,0.3,2.1}, {0,-0.1,0}, mint)
	elseif id == "mintTrail" then
		for i = 1, 7 do add({0.45,0.45,0.45}, {math.sin(i)*0.9,(i-4)*0.55,0}, if i%2==0 then mint else gold, "ball") end
	elseif id == "snorkel" then
		add({2.6,1,0.5}, {0,0,0}, navy); add({2.1,0.65,0.1}, {0,0,-0.3}, mint)
		add({0.35,2.8,0.35}, {1.5,0.75,0}, gold)
	elseif id == "bait" then
		add({2,2.4,1.8}, {0,0,0}, tan); add({2.1,0.45,1.9}, {0,1.3,0}, mint)
		add({0.8,0.8,0.2}, {0,0,-1}, gold, "ball")
	else
		local color = if id == "camoCoat" then {96,130,79} elseif id == "lifeJacket" then {244,150,63} else navy
		add({2.4,3,1.2}, {0,0,0}, color)
		for _, x in {-0.75,0.75} do add({0.35,2.6,0.25}, {x,0,-0.73}, mint) end
		add({1.5,0.7,0.3}, {0,-0.5,-0.8}, gold)
		if id == "diving" then for _, x in {-0.65,0.65} do add({0.9,3.5,0.9}, {x,0,1}, tan, "ball") end end
	end
	return parts
end
return Shapes
