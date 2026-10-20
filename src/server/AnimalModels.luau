--!nonstrict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZoShared")
local Shapes = require(Shared.AnimalShapes)
local AnimalModels = {}
local function vector(values) return Vector3.new(values[1], values[2], values[3]) end
function AnimalModels.build(world, model, root, species)
	local blueprint = Shapes.build(species)
	local scale = species.scale
	local rig = {}
	for name, spec in blueprint.joints do
		rig[name] = {pivot = CFrame.new(vector(spec.pivot) * scale), axis = spec.axis, phase = spec.phase, amplitude = spec.amplitude, parts = {}}
	end
	for _, spec in blueprint.parts do
		local angles = spec.rotation
		local cf = CFrame.new(vector(spec.offset) * scale) * CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3]))
		local shape = if spec.shape == "wedge" then "wedge" elseif spec.shape == "block" then Enum.PartType.Block else Enum.PartType.Ball
		local p = world.part(model, spec.name, vector(spec.size) * scale, root.CFrame * cf, Color3.fromRGB(unpack(spec.color)), Enum.Material.SmoothPlastic, shape)
		p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
		if spec.joint then
			local joint = rig[spec.joint]
			table.insert(joint.parts, {part = p, rest = joint.pivot:ToObjectSpace(cf)})
		end
	end
	return rig
end
function AnimalModels.animate(rig, root, now, moving, marine)
	for _, joint in rig do
		local angle = math.sin(now * (if marine then 3.2 else 6) + joint.phase) * joint.amplitude * (if moving then 1 else 0.12)
		local turn = CFrame.Angles(if joint.axis == "x" then angle else 0, if joint.axis == "y" then angle else 0, if joint.axis == "z" then angle else 0)
		for _, limb in joint.parts do limb.part.CFrame = root * joint.pivot * turn * limb.rest end
	end
end
return AnimalModels
