--!strict
-- Original procedural animal designs. Pure data keeps proportions inspectable
-- without claiming that a CLI test renders or simulates a Roblox model.
export type Piece = {name: string, size: {number}, offset: {number}, color: {number}, shape: string, rotation: {number}, joint: string?}
export type Joint = {pivot: {number}, axis: string, phase: number, amplitude: number}
local Shapes = {}
function Shapes.build(species: any): {parts: {Piece}, joints: {[string]: Joint}}
	local parts: {Piece} = {}
	local joints: {[string]: Joint} = {}
	local fur = species.color
	local cream, dark, pink = {244, 232, 207}, {34, 43, 47}, {212, 146, 136}
	local function piece(name: string, size: {number}, offset: {number}, color: {number}?, shape: string?, rotation: {number}?, joint: string?)
		table.insert(parts, {name = name, size = size, offset = offset, color = color or fur, shape = shape or "ball", rotation = rotation or {0, 0, 0}, joint = joint})
	end
	local function joint(name: string, pivot: {number}, axis: string, phase: number, amplitude: number)
		joints[name] = {pivot = pivot, axis = axis, phase = phase, amplitude = amplitude}
	end
	local function eyes(x: number, y: number, z: number)
		for side = -1, 1, 2 do
			piece("Eye", {0.22, 0.24, 0.18}, {side * x, y, z}, dark)
			piece("EyeHighlight", {0.07, 0.07, 0.06}, {side * x, y + 0.06, z - 0.09}, cream)
		end
	end
	local function coatMark(name: string, side: number, y: number, z: number, tint: {number}, inner: boolean?, stripe: boolean?)
		local x = side * 1.05 * math.sqrt(math.max(0, 1 - (y / 0.825)^2 - (z / 1.6)^2))
		local nx, ny, nz = x / 1.05^2, y / 0.825^2, z / 1.6^2
		local length = math.sqrt(nx^2 + ny^2 + nz^2)
		nx /= length; ny /= length; nz /= length
		local lift = if inner then 0.045 else 0.015
		piece(name, if inner then {0.07, 0.11, 0.14} elseif stripe then {0.07, 0.6, 0.13} else {0.07, 0.3, 0.35}, {x + nx * lift, y + ny * lift, z + nz * lift}, tint, nil, {0, math.deg(math.atan2(-nz, nx)), math.deg(math.asin(ny))})
	end
	local function legs(long: boolean, hoof: boolean, darkFeet: boolean?)
		for side = -1, 1, 2 do
			for _, z in {-0.9, 1} do
				local name = "leg" .. side .. ":" .. z
				joint(name, {side * 0.7, -0.35, z}, "x", if (side == -1) == (z < 0) then 0 else math.pi, 0.35)
				piece("Leg", {if long then 0.36 else 0.5, 1.1, 0.5}, {side * 0.7, -0.85, z}, fur, "block", nil, name)
				piece(if hoof then "Hoof" else "Paw", {0.58, 0.33, 0.8}, {side * 0.7, -1.48, z - 0.12}, if hoof or darkFeet then dark else fur, "block", nil, name)
			end
		end
	end
	local form = species.form
	if form=="boar" then
		piece("BarrelBody",{2.15,1.9,3.4},{0,-0.05,0.1})
		piece("ShoulderHump",{2,2.1,1.9},{0,0.15,-0.7})
		piece("TaperedBoarHead",{1.45,1.35,1.8},{0,0.1,-1.9})
		piece("LongBoarSnout",{1.05,0.78,0.95},{0,-0.18,-2.88})
		piece("SnoutDisk",{0.9,0.62,0.2},{0,-0.14,-3.36},{128,103,86})
		piece("LowerJaw",{1,0.3,1.2},{0,-0.5,-2.55})
		for side=-1,1,2 do
			piece("Nostril",{0.18,0.13,0.09},{side*0.23,-0.05,-3.49},dark)
			piece("BoarEar",{0.62,0.9,0.45},{side*0.63,0.93,-1.7},fur,"wedge",{0,side*10,side*-28})
			piece("EarInside",{0.28,0.45,0.1},{side*0.64,0.96,-1.96},{125,94,83},nil,{0,0,side*-28})
			piece("BoarTusk",{0.24,0.55,0.3},{side*0.55,-0.1,-3.02},cream,"wedge",{-15,0,side*-18})
			piece("TuskTip",{0.13,0.4,0.15},{side*0.6,0.3,-3.16},cream,"wedge",{-25,0,side*-12})
			for _,z in {-0.95,1.1} do
				local name="leg"..side..":"..z; joint(name,{side*0.7,-0.3,z},"x",if (side==-1)==(z<0) then 0 else math.pi,0.32)
				piece("StockyUpperLeg",{0.6,0.85,0.65},{side*0.7,-0.65,z},fur,nil,nil,name)
				piece("BoarLowerLeg",{0.34,0.65,0.38},{side*0.75,-1.12,z+0.12},fur,nil,nil,name)
				for _,toe in {-0.13,0.13} do piece("ClovenHoof",{0.22,0.32,0.7},{side*0.75+toe,-1.47,z-0.03},dark,"block",nil,name) end
			end
		end
		for i=1,6 do piece("BackBristle",{0.28,0.45,0.55},{0,1.03,-1.25+i*0.4},{63,55,47},"wedge",{-15,0,0}) end
		joint("tail",{0,0.1,1.55},"y",0,0.22)
		for i=1,3 do piece("CurledBoarTail",{0.22,0.24,0.45},{math.sin(i*0.9)*0.25,0.12+math.cos(i)*0.15,1.65+i*0.25},fur,nil,{0,i*30,0},"tail") end
		eyes(0.56,0.42,-2.47)
	elseif form=="panther" then
		piece("LongFelineTorso",{1.65,1.5,3.7},{0,0,0.2})
		piece("MuscularShoulders",{1.75,1.7,1.45},{0,0.05,-0.85})
		piece("FelineHaunches",{1.85,1.6,1.6},{0,-0.05,1.1})
		piece("FelineNeck",{1.18,1.2,1.4},{0,0.3,-1.4})
		piece("PantherHead",{1.4,1.18,1.4},{0,0.55,-2.05})
		piece("FelineJaw",{1.1,0.4,0.9},{0,0.22,-2.5})
		piece("PantherNose",{0.38,0.22,0.18},{0,0.49,-2.98},{40,44,46})
		for side=-1,1,2 do
			piece("WhiskerPad",{0.62,0.45,0.6},{side*0.28,0.38,-2.63},{91,97,97})
			piece("RoundFelineEar",{0.5,0.5,0.3},{side*0.55,1.2,-1.8})
			piece("EarInside",{0.25,0.27,0.08},{side*0.55,1.21,-1.97},{104,97,94})
			piece("Eye",{0.19,0.18,0.13},{side*0.54,0.76,-2.55},{174,174,99})
			piece("FelinePupil",{0.07,0.14,0.14},{side*0.54,0.76,-2.59},dark)
			piece("EyeBrow",{0.35,0.12,0.2},{side*0.51,0.9,-2.49},fur,nil,{0,0,side*-12})
			for _,z in {-0.95,1.2} do
				local name="leg"..side..":"..z; joint(name,{side*0.65,-0.3,z},"x",if (side==-1)==(z<0) then 0 else math.pi,0.4)
				piece("FelineUpperLeg",{0.58,0.8,0.68},{side*0.65,-0.6,z},fur,nil,nil,name)
				piece("FelineLowerLeg",{0.35,0.62,0.4},{side*0.66,-1.13,z},fur,nil,nil,name)
				piece("FelinePaw",{0.65,0.34,0.8},{side*0.68,-1.46,z-0.14},{46,52,55},nil,nil,name)
				for toe=-1,1 do piece("PawToe",{0.12,0.12,0.16},{side*0.68+toe*0.16,-1.5,z-0.49},{63,70,72},nil,nil,name) end
			end
			for i=1,4 do
				local z=-0.6+i*0.45; local x=side*0.825*math.sqrt(1-(0.2/0.75)^2-((z-0.2)/1.85)^2)
				piece("GhostRosette",{0.055,0.2,0.26},{x,0.2,z},{49,54,57})
			end
		end
		joint("tail",{0,0.05,1.6},"y",0,0.24)
		for i=1,5 do piece("CurvedFelineTail",{0.32,0.34,0.7},{math.sin(i*0.35)*0.45,0.05+i*0.04,1.6+i*0.34},if i==5 then dark else fur,nil,{0,i*4,0},"tail") end
	elseif form=="reefShark" then
		local pale={212,222,219}
		piece("ReefSharkBody",{1.8,1.5,4.3},{0,0,0})
		piece("TaperedSharkRear",{1.1,1.1,2.3},{0,0,1.6})
		piece("PaleUnderside",{1.45,0.42,3.6},{0,-0.54,-0.15},pale)
		piece("ReefSharkHead",{1.7,1.1,1.7},{0,-0.02,-1.9})
		piece("ReefSharkSnout",{1.25,0.75,1.45},{0,-0.11,-2.65})
		piece("SharkNoseTip",{0.65,0.45,0.65},{0,-0.15,-3.15})
		piece("DorsalFin",{0.2,1.65,1.7},{0,1.12,0.15},fur,"wedge",{0,180,0})
		piece("RearDorsalFin",{0.13,0.55,0.7},{0,0.62,1.8},fur,"wedge",{0,180,0})
		for _,x in {-0.35,0,0.35} do piece("SharkMouth",{0.43,0.055,0.15},{x,-0.42,-2.8},dark,"block",{0,x*35,0}) end
		for i=-3,3 do piece("SmallSharkTooth",{0.1,0.16,0.1},{i*0.16,-0.5,-2.9},pale,"wedge",{0,0,180}) end
		for side=-1,1,2 do
			piece("Eye",{0.16,0.17,0.12},{side*0.73,0.13,-2.36},dark)
			piece("EyeHighlight",{0.05,0.05,0.03},{side*0.73,0.17,-2.43},cream)
			for i=1,5 do piece("SharkGill",{0.035,0.52,0.12},{side*0.85,-0.02,-1.15+i*0.2},{61,80,88},"block") end
			local name="flipper"..side; joint(name,{side*0.65,-0.3,-0.7},"z",side,0.1)
			piece("SweptPectoralFin",{0.18,1.45,2},{side*1.2,-0.45,-0.6},fur,"wedge",{0,side*22,side*-70},name)
			piece("PelvicFin",{0.14,0.75,0.9},{side*0.65,-0.4,1.55},fur,"wedge",{0,0,side*-70})
		end
		joint("tail",{0,0,1.6},"y",0,0.32)
		piece("ReefTailStem",{0.55,0.65,1.4},{0,0,2.48},fur,nil,nil,"tail")
		piece("VerticalSharkTail",{0.2,1.75,1.2},{0,0.55,3.15},fur,"wedge",{-15,180,0},"tail")
		piece("LowerTailLobe",{0.2,1,0.9},{0,-0.6,3.15},fur,"wedge",{0,0,180},"tail")
	elseif form == "fish" then
		piece("StreamlinedBody", {1.35, 1.9, 3.6}, {0, 0, -0.1})
		piece("Face", {1.25, 1.45, 1.5}, {0, 0, -1.65})
		joint("tail", {0, 0, 1.35}, "y", 0, 0.45)
		piece("TailStem", {0.6, 0.75, 1.4}, {0, 0, 1.75}, fur, nil, nil, "tail")
		piece("VerticalTail", {0.2, 2.2, 1.5}, {0, 0, 2.55}, {243, 209, 103}, "wedge", {0, 180, 0}, "tail")
		piece("DorsalFin", {0.18, 0.8, 1.5}, {0, 1.1, 0.1}, {239, 142, 46}, "wedge")
		for _, z in {-0.8, 0.35, 1.05} do
			local radius = math.sqrt(1 - ((z + 0.1) / 1.8)^2)
			for index = 1, 18 do
				local angle = index * math.pi / 9
				local x, y = math.cos(angle) * 0.675 * radius, math.sin(angle) * 0.95 * radius
				local nx, ny, nz = x / 0.675^2, y / 0.95^2, (z + 0.1) / 1.8^2
				local length = math.sqrt(nx^2 + ny^2 + nz^2); nx /= length; ny /= length; nz /= length
				piece("Sunstripe", {0.08, 0.32, 0.18}, {x + nx * 0.015, y + ny * 0.015, z + nz * 0.015}, cream, nil, {0, math.deg(math.atan2(-nz, nx)), math.deg(math.asin(ny))})
			end
		end
		for side = -1, 1, 2 do piece("PectoralFin", {0.9, 0.18, 1.1}, {side * 0.87, -0.25, -0.6}, {248, 202, 85}, "wedge", {0, side * 20, side * 15}) end
		eyes(0.57, 0.3, -2.05)
	elseif form == "dolphin" or form == "whale" or form == "seal" or form == "shark" then
		local whale = form == "whale"
		local seal, shark = form == "seal", form == "shark"
		piece("StreamlinedBody", {if whale then 2.8 else 2.15, 1.9, 4.8}, {0, 0, 0})
		piece("PaleUnderside", {1.8, 0.45, 3.7}, {0, -0.67, -0.2}, cream)
		piece(if shark then "HammerHead" else "MelonHead", {if shark then 3.4 elseif whale then 2.6 else 1.8, if shark then 0.85 else 1.65, if shark then 1.3 else 2.15}, {0, 0.05, if shark then -2.2 else -1.8})
		piece(if whale or shark then "BroadMuzzle" elseif seal then "SealMuzzle" else "DolphinBeak", {if whale or shark then 2.1 elseif seal then 1.1 else 0.7, 0.55, if whale then 1.1 elseif seal or shark then 0.8 else 1.6}, {0, -0.22, if seal then -2.7 else -2.9})
		piece("MouthLine", {if whale or shark then 1.8 else 0.6, 0.06, 0.15}, {0, -0.38, if seal then -3.12 elseif shark then -3.32 elseif whale then -3.43 else -3.66}, dark, "block")
		if not seal then piece("DorsalFin", {0.25, if whale then 0.8 else 1.3, 1.5}, {0, 1.03, 0.6}, fur, "wedge", {0, 180, 0}) end
		if not seal and not shark then piece("Blowhole", {0.35, 0.06, 0.27}, {0, 0.83, -1.8}, dark) end
		joint("tail", {0, 0, 1.7}, if shark then "y" else "x", 0, 0.24)
		piece("TailPeduncle", {1.15, 0.85, 1.5}, {0, 0, 2.25}, fur, nil, nil, "tail")
		for side = -1, 1, 2 do
			if not shark then piece(if seal then "HindFlipper" else "HorizontalFluke", {0.25, if seal then 1.2 else 2, 1.25}, {side * (if seal then 0.6 else 1), 0, 3.05}, fur, "wedge", {0, side * 22, side * -90}, "tail") end
			local name = "flipper" .. side; joint(name, {side * 0.8, -0.2, -0.7}, "z", side, 0.18)
			piece("PectoralFlipper", {1.8, 0.23, 1.25}, {side * 1.45, -0.4, -0.35}, fur, "wedge", {0, side * 30, side * 12}, name)
		end
		if shark then
			piece("VerticalSharkTail", {0.25, 2.8, 1.3}, {0, 0.2, 3.05}, fur, "wedge", {0, 180, 0}, "tail")
			for side = -1, 1, 2 do
				for index = 1, 3 do piece("SharkGill", {0.06, 0.6, 0.1}, {side * 1.02, 0, -0.9 + index * 0.28}, dark, "block") end
			end
		elseif seal then
			piece("SealNose", {0.3, 0.2, 0.17}, {0, -0.08, -3.12}, dark)
			for side = -1, 1, 2 do
				for index = 1, 2 do piece("Whisker", {0.8, 0.06, 0.06}, {side * 0.6, -0.2 + index * 0.13, -3.02}, cream, "block", {0, 0, side * index * 8}) end
			end
		end
		if whale then
			for _, x in {-0.55, 0, 0.55} do piece("ThroatPleat", {0.06, 0.07, 1.75}, {x, -0.91, -1.1}, {153, 180, 187}, "block") end
		end
		eyes(if shark then 1.44 elseif whale then 1.08 else 0.76, if shark then 0.1 else 0.22, if shark then -2.55 else -2.46)
	elseif form == "axolotl" then
		piece("AxolotlBody", {1.5, 1.1, 3}, {0, 0, 0})
		piece("WideAxolotlHead", {2.1, 1.1, 1.6}, {0, 0.1, -1.65})
		joint("tail", {0, 0, 1.1}, "y", 0, 0.3)
		piece("FinnedAxolotlTail", {0.28, 1.25, 2.1}, {0, 0, 2.15}, {219, 139, 164}, nil, nil, "tail")
		for side = -1, 1, 2 do
			for index = 1, 3 do
				piece("ExternalGill", {0.22, 0.85, 0.24}, {side * (0.98 + index * 0.19), 0.5, -1.9 + index * 0.38}, {202, 105, 140}, "block", {0, 0, side * -25})
				piece("GillFeather", {0.55, 0.17, 0.25}, {side * (1.08 + index * 0.19), 0.8, -1.9 + index * 0.38}, {238, 144, 172})
			end
			for _, z in {-0.7, 0.9} do
				piece("AxolotlLeg", {0.7, 0.3, 0.4}, {side * 0.85, -0.4, z}, fur, "block")
				piece("AxolotlFoot", {0.45, 0.2, 0.6}, {side * 1.1, -0.55, z - 0.1}, cream, "block")
			end
		end
		eyes(0.67, 0.35, -2.3)
	elseif form == "turtle" then
		piece("Body", {2.2, 0.85, 3.1}, {0, -0.1, 0})
		piece("DomedShell", {2.95, 1.35, 3.55}, {0, 0.4, 0}, {46, 104, 75})
		piece("ShellRim", {3.08, 0.3, 3.6}, {0, -0.03, 0}, {205, 188, 125})
		for _, z in {-0.95, 0, 0.95} do
			piece("CentralScute", {0.85, 0.17, 0.75}, {0, 1.05 - math.abs(z) * 0.15, z}, {94, 147, 92}, "block")
			for side = -1, 1, 2 do piece("SideScute", {0.65, 0.16, 0.7}, {side * 0.87, 0.83 - math.abs(z) * 0.13, z}, {78, 129, 81}, "block", {0, 0, side * -25}) end
		end
		piece("Neck", {0.7, 0.7, 1.1}, {0, 0, -1.6})
		piece("TurtleHead", {0.95, 0.8, 1.1}, {0, 0.02, -2.15})
		piece("Tail", {0.25, 0.24, 0.8}, {0, -0.1, 1.9}, fur, "wedge")
		for side = -1, 1, 2 do
			for _, z in {-0.9, 1} do
				local name = "flipper" .. side .. z; joint(name, {side * 0.9, -0.2, z}, "z", side + z, 0.28)
				piece("SeaFlipper", {1.7, 0.2, 0.85}, {side * 1.6, -0.35, z}, fur, "wedge", {0, side * 25, 0}, name)
			end
		end
		eyes(0.39, 0.22, -2.54)
	elseif form == "ray" then
		piece("FlatMantaBody", {2.5, 0.65, 3.7}, {0, 0, -0.15})
		piece("PaleUnderside", {2.2, 0.12, 3}, {0, -0.32, -0.2}, {215, 220, 247})
		piece("MantaMouth", {1.1, 0.12, 0.14}, {0, -0.12, -1.98}, dark, "block")
		for side = -1, 1, 2 do
			for index = 1, 5 do piece("GillSlit", {0.6, 0.04, 0.08}, {side * 0.65, -0.4, -0.9 + index * 0.33}, dark, "block") end
			local name = "wing" .. side; joint(name, {side, 0, 0}, "z", side, 0.22)
			piece("DiamondWing", {0.3, 3.4, 3.6}, {side * 2.3, 0, 0.15}, fur, "wedge", {0, side * 12, side * -90}, name)
			piece("AuroraWingTip", {0.7, 0.18, 1.5}, {side * 3.55, 0.04, 0.65}, {137, 227, 221}, "wedge", {0, side * 12, 0}, name)
			piece("CephalicLobe", {0.4, 0.36, 0.9}, {side * 0.7, 0, -2.2})
		end
		joint("tail", {0, 0, 1.3}, "y", 0, 0.12)
		piece("WhipTail", {0.18, 0.16, 2.7}, {0, 0, 2.65}, fur, "block", nil, "tail")
		eyes(0.96, 0.3, -1.5)
	elseif form == "bird" then
		local fan = species.pattern == "fan"
		local parrot = species.habitat == "jungle" and not fan
		local wingColor = if fan then {45, 118, 97} elseif parrot then {51, 122, 181} else {101, 82, 64}
		piece("UprightBody", {1.65, 2.05, 2.1}, {0, 0, 0})
		piece("Breast", {1.2, 1.6, 0.35}, {0, -0.1, -0.9}, if parrot or fan then fur else cream)
		piece("BirdHead", {1.3, 1.25, 1.35}, {0, 1.1, -0.65}, if parrot or fan then fur else cream)
		piece("HookedBeak", {0.57, 0.65, 0.8}, {0, 0.92, -1.43}, if parrot then dark else {236, 185, 69}, "wedge", {0, 180, 0})
		for side = -1, 1, 2 do
			piece("BirdLeg", {0.22, 0.55, 0.25}, {side * 0.45, -1.18, -0.05}, {212, 163, 74}, "block")
			for _, toe in {-1, 0, 1} do piece("Claw", {0.12, 0.18, 0.65}, {side * 0.45 + toe * 0.16, -1.53, -0.24}, dark, "block") end
			local name = "wing" .. side; joint(name, {side * 0.65, 0.6, 0}, "z", side, 0.22)
			piece("FoldedWing", {0.65, 1.65, 1.85}, {side * 0.95, 0.02, 0.25}, wingColor, nil, {side * 5, 0, side * 10}, name)
			for index = 1, 3 do piece("FlightFeather", {0.22, 1.1, 0.35}, {side * (1.12 + index * 0.1), -0.35, 0.1 + index * 0.32}, if parrot and index == 1 then {239, 198, 63} else wingColor, "block", {15, 0, side * 8}, name) end
		end
		piece("TailFeathers", {0.9, 0.3, if parrot then 2.5 else 1.5}, {0, -0.45, 1.7}, wingColor, "wedge", {10, 0, 0})
		if parrot then
			for side = -1, 1, 2 do piece("MacawFacePatch", {0.18, 0.6, 0.6}, {side * 0.62, 1.15, -1.02}, cream) end
		else piece("CrownFeathers", {0.6, 0.5, 0.65}, {0, 1.77, -0.32}, dark, "wedge") end
		if fan then
			for index = -3, 3 do
				local angle = index * 0.23; local x, y = math.sin(angle), math.cos(angle)
				piece("PeacockFan", {0.55, 2.8, 0.2}, {x * 1.2, -0.1 + y * 1.2, 1.15}, {50, 128, 91}, nil, {0, 0, -math.deg(angle)})
				piece("FanEye", {0.32, 0.45, 0.12}, {x * 2.15, -0.1 + y * 2.15, 1.01}, {216, 186, 73})
				piece("FanEyeCenter", {0.16, 0.24, 0.13}, {x * 2.15, -0.1 + y * 2.15, 0.95}, {44, 105, 153})
			end
		end
		eyes(0.58, 1.25, -1.21)
	elseif form == "monkey" then
		piece("UprightTorso", {1.8, 2.05, 1.7}, {0, 0, 0})
		piece("Chest", {1.1, 1.4, 0.25}, {0, -0.1, -0.78}, cream)
		piece("Head", {1.7, 1.55, 1.6}, {0, 1.1, -0.45})
		piece("FaceMask", {1.3, 1.1, 0.6}, {0, 1.05, -1.12}, {207, 172, 130})
		piece("Muzzle", {0.7, 0.5, 0.4}, {0, 0.8, -1.5}, cream)
		for side = -1, 1, 2 do
			piece("RoundEar", {0.7, 0.8, 0.35}, {side * 0.93, 1.18, -0.4})
			piece("EarInside", {0.4, 0.5, 0.14}, {side * 1.01, 1.18, -0.61}, pink)
			local name = "arm" .. side; joint(name, {side * 0.7, 0.65, 0}, "x", side, 0.28)
			piece("LongArm", {0.48, 1.65, 0.55}, {side * 1, -0.15, -0.05}, fur, "block", {0, 0, side * 10}, name)
			piece("Hand", {0.55, 0.45, 0.6}, {side * 1.15, -1, -0.08}, cream, "block", nil, name)
			piece("HindLeg", {0.55, 0.6, 0.65}, {side * 0.5, -1.07, 0.2}, fur, "block")
			piece("Foot", {0.65, 0.35, 1}, {side * 0.5, -1.47, -0.02}, cream, "block")
		end
		for index = 1, 6 do
			local angle = (index - 1) * 0.45
			piece("CurledTail", {0.32, 0.32, 0.65}, {0, 0.2 + math.sin(angle) * 0.95, 1.05 + index * 0.3}, fur, nil, {math.deg(angle), 0, 0})
		end
		eyes(0.41, 1.22, -1.44)
	elseif form == "rabbit" then
		piece("Haunches", {2.05, 1.9, 2.65}, {0, -0.2, 0.3})
		piece("Chest", {1.4, 1.5, 1.3}, {0, -0.05, -1.05})
		piece("Head", {1.6, 1.45, 1.6}, {0, 0.65, -1.65})
		piece("Muzzle", {0.9, 0.55, 0.65}, {0, 0.35, -2.36}, cream)
		piece("Nose", {0.2, 0.16, 0.16}, {0, 0.5, -2.7}, pink)
		for side = -1, 1, 2 do
			piece("LongEar", {0.48, 2.15, 0.44}, {side * 0.46, 2.15, -1.55}, fur, "block", {side * 4, 0, side * -9})
			piece("PinkEarInside", {0.25, 1.65, 0.09}, {side * 0.46, 2.15, -1.79}, pink, "block", {0, 0, side * -9})
			local name = "hind" .. side; joint(name, {side * 0.65, -0.65, 0.7}, "x", 0, 0.25)
			piece("StrongHindLeg", {0.8, 0.95, 1.2}, {side * 0.75, -0.95, 0.8}, fur, nil, nil, name)
			piece("HindPaw", {0.7, 0.3, 1.4}, {side * 0.8, -1.48, 0.5}, cream, "block", nil, name)
			piece("Foreleg", {0.4, 1, 0.45}, {side * 0.5, -0.95, -1.1}, fur, "block")
			piece("FrontPaw", {0.5, 0.28, 0.7}, {side * 0.5, -1.48, -1.25}, cream, "block")
		end
		piece("CottonTail", {0.85, 0.85, 0.85}, {0, 0, 1.75}, cream)
		eyes(0.62, 0.88, -2.17)
	else
		local deer = form == "deer"; local goat = form == "goat"; local fox = form == "fox"
		local rodent = form == "rodent"
		piece("Torso", {if fox then 1.7 elseif rodent then 2.3 else 2.1, if rodent then 1.8 else 1.65, if rodent then 3.5 else 3.2}, {0, if rodent then -0.4 else 0, 0})
		piece("Chest", {1.6, 1.6, 1.3}, {0, 0.1, -0.95}, if fox or goat then cream else fur)
		legs(deer or goat, deer or goat, fox or form == "raccoon" or form == "panda")
		piece("Neck", {0.95, if deer or goat then 1.6 elseif rodent then 0.75 else 0.9, 1.05}, {0, if deer or goat then 0.85 elseif rodent then 0.1 else 0.4, -1.35})
		local headY = if deer or goat then 1.5 elseif rodent then 0.15 else 0.65
		piece("Head", {if fox then 1.3 elseif rodent then 1.7 else 1.5, 1.3, if rodent then 1.9 else 1.6}, {0, headY, if rodent then -1.75 else -1.9})
		piece("Muzzle", {if fox then 0.65 elseif rodent then 1.35 else 1, 0.6, if fox then 1.2 elseif rodent then 0.7 else 0.85}, {0, headY - 0.25, -2.7}, cream)
		piece("Nose", {0.33, 0.23, 0.2}, {0, headY - 0.07, if fox then -3.31 elseif rodent then -3.08 else -3.15}, dark)
		for side = -1, 1, 2 do
			local rounded = form == "rodent" or form == "raccoon" or form == "panda"
			piece(if rounded then "RoundEar" else "PointedEar", {0.55, if fox then 1 elseif rounded then 0.5 else 0.65, 0.5}, {side * 0.63, headY + (if rounded then 0.7 else 0.85), -1.75}, fur, if rounded then "ball" else "wedge", {0, if side == 1 then 180 else 0, 0})
			piece("EarInside", {0.26, if rounded then 0.24 else 0.4, 0.09}, {side * 0.63, headY + (if rounded then 0.7 else 0.83), -2.03}, pink, "block")
		end
		joint("tail", {0, 0.1, 1.3}, "y", 0, 0.18)
		if not rodent then piece(if fox then "BushyTail" else "LongTail", {if fox then 1 else 0.38, if fox then 0.85 else 0.4, if deer or goat then 0.9 else 2.1}, {0, 0.1, if deer or goat then 1.85 else 2.35}, fur, nil, nil, "tail") end
		if fox then piece("WhiteTailTip", {0.77, 0.7, 0.7}, {0, 0.1, 3.35}, cream, nil, nil, "tail") end
		if form == "raccoon" or form == "panda" then
			for side = -1, 1, 2 do piece("FaceMask", {0.45, 0.45, 0.2}, {side * 0.56, headY + 0.1, -2.4}, if form == "panda" then cream else dark) end
			for index = 1, 4 do piece("TailRing", {0.46, 0.45, 0.15}, {0, 0.1, 1.55 + index * 0.37}, if form == "panda" then cream else dark, nil, nil, "tail") end
		elseif form == "boar" then
			for side = -1, 1, 2 do piece("BoarTusk", {0.22, 0.7, 0.3}, {side * 0.55, 0.5, -2.95}, cream, "wedge", {0, 0, side * -20}) end
		end
		if deer then
			for side = -1, 1, 2 do
				piece("AntlerBeam", {0.16, 1.5, 0.18}, {side * 0.55, 2.6, -1.62}, {172, 148, 106}, "block", {-15, 0, side * -15})
				for index = 1, 2 do piece("AntlerTine", {0.15, 0.65, 0.15}, {side * (0.62 + index * 0.15), 2.6 + index * 0.25, -1.72}, cream, "block", {0, 0, side * -35}) end
				for _, z in {-0.6, 0.2, 0.9} do coatMark("WhiteCoatSpot", side, 0.3, z, cream) end
			end
		elseif goat then
			for side = -1, 1, 2 do piece("SweptHorn", {0.24, 1.1, 0.3}, {side * 0.53, 2.48, -1.55}, {135, 128, 112}, "block", {-25, 0, side * -12}) end
			piece("GoatBeard", {0.35, 0.7, 0.45}, {0, 0.65, -2.5}, cream, "wedge")
		elseif form == "cat" then
			for side = -1, 1, 2 do
				for index = 1, 7 do
					local z = (index - 1) % 4 * 0.65 - 0.95
					local y = if index <= 4 then 0.25 else -0.2
					local stripes = species.pattern == "stripes"
					coatMark(if stripes then "TigerStripe" else "Rosette", side, y, z, dark, false, stripes)
					if not stripes then coatMark("RosetteCenter", side, y, z, fur, true) end
				end
			end
		end
		eyes(if fox then 0.5 else 0.59, headY + 0.15, -2.49)
	end
	return {parts = parts, joints = joints}
end
return Shapes
