--!nonstrict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ExpeditionWorld = {}
function ExpeditionWorld.build(world, catalog, rules, getProfile, notify, effects, canAccess)
	local lastInteraction = {}
	local random = Random.new()
	local locations=require(script.Parent.LootLocations).new(world,catalog)
	local function nearby(player, position, distance)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 or not getProfile(player) or (root.Position - position).Magnitude > distance then return nil end
		local now = os.clock()
		if now - (lastInteraction[player] or -math.huge) < 0.35 then return nil end
		local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.IgnoreWater = true; params.RespectCanCollide = true
		local excluded = {world.actors, world.boats}
		for _, other in Players:GetPlayers() do if other.Character then table.insert(excluded, other.Character) end end
		params.FilterDescendantsInstances = excluded
		if workspace:Raycast(root.Position, position - root.Position, params) then return nil end
		lastInteraction[player] = now
		return humanoid
	end
	for _, spot in world.checkpointSpots do
		local definition = assert(catalog.Checkpoints[spot.id], "Unknown checkpoint marker")
		local spawn = Instance.new("SpawnLocation"); spawn.Name = "Checkpoint_" .. spot.id
		spawn.Size = Vector3.new(8, 0.5, 8); spawn.CFrame = CFrame.new(spot.position + Vector3.new(0, 0.25, 0))
		spawn.Anchored = true; spawn.CanCollide = false; spawn.CanQuery = false; spawn.Neutral = true; spawn.Duration = 0
		spawn.Color = Color3.fromRGB(140, 228, 185); spawn.Material = Enum.Material.Neon; spawn.Transparency = 0.25; spawn.Parent = world.runtime
		world.checkpoints[spot.id] = spawn
		world.label(spawn, "CHECKPOINT\n" .. definition.name, 6, 260)
		local prompt = Instance.new("ProximityPrompt"); prompt.ActionText = "Save checkpoint"; prompt.ObjectText = definition.name
		prompt.MaxActivationDistance = 12; prompt.HoldDuration = 0.25; prompt.RequiresLineOfSight = false; prompt.Parent = spawn
		prompt.Triggered:Connect(function(player)
			if not nearby(player, spot.position + Vector3.new(0, 1, 0), 14) then return end
			if not canAccess(player,definition.mapId) then notify(player,"Unlock this island in Travel first.","travel"); return end
			local ok, message = rules.checkpoint(getProfile(player), spot.id)
			if ok then player.RespawnLocation = spawn end
			notify(player, message, if ok then "success" else "info")
		end)
	end
	for index, spot in world.chestSpots do
		assert(catalog.Chests[spot.id], "Unknown chest marker")
		local gift=index%3==0
		local model = Instance.new("Model"); model.Name = (if gift then "SurpriseGift_" else "SurpriseChest_") .. spot.id; model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		model:SetAttribute("ZoLootId",spot.id); model:SetAttribute("ZoLootKind",if gift then "SURPRISE GIFT" else "SURPRISE CHEST")
		local position,region=locations:position(spot)
		local cf = CFrame.new((position or spot.position) + Vector3.new(0, 1.6, 0))
		local box = world.part(model, "TreasureChest", Vector3.new(5, 3, 3.5), cf, if gift then Color3.fromRGB(159,86,232) else Color3.fromRGB(139, 88, 49), if gift then Enum.Material.SmoothPlastic else Enum.Material.WoodPlanks)
		box.CanCollide = false; box.CanQuery = false; model.PrimaryPart = box
		local lid = world.part(model, "ChestLid", Vector3.new(5.2, 0.7, 3.7), cf * CFrame.new(0, 1.8, 0), if gift then Color3.fromRGB(189,115,255) else Color3.fromRGB(175, 118, 60), if gift then Enum.Material.SmoothPlastic else Enum.Material.WoodPlanks)
		lid.CanCollide = false; lid.CanQuery = false
		for _, x in {-1.6, 1.6} do
			local band = world.part(model, "ChestBand", Vector3.new(0.35, 3.1, 3.6), cf * CFrame.new(x, 0, 0), Color3.fromRGB(223, 187, 90), Enum.Material.Metal)
			band.CanCollide = false; band.CanQuery = false
		end
		if gift then
			for _,x in {-0.7,0.7} do
				local bow=world.part(model,"GiftBow",Vector3.new(1.6,0.7,1.1),cf*CFrame.new(x,2.3,0),Color3.fromRGB(255,210,72),Enum.Material.SmoothPlastic,Enum.PartType.Ball)
				bow.CanCollide=false; bow.CanQuery=false
			end
		end
		local text = world.label(box, (if gift then "SURPRISE GIFT" else "SURPRISE CHEST").."\nRewards or traps • once daily", 4, 250); text.Parent.MaxDistance = 65
		local prompt = Instance.new("ProximityPrompt"); prompt.ActionText = if gift then "Open surprise gift" else "Open surprise chest"; prompt.ObjectText = "Free • may contain a lethal trap"
		prompt.HoldDuration = 0.25; prompt.MaxActivationDistance = 10; prompt.RequiresLineOfSight = false; prompt.Parent = box
		local entry={spot=spot,model=model,box=box,region=region,animating=false}
		locations:add(entry); model.Parent=world.runtime
		prompt.Triggered:Connect(function(player)
			local humanoid = nearby(player, box.Position, 12)
			if not humanoid then return end
			if not canAccess(player,spot.mapId or "ark") then notify(player,"Unlock this island in Travel first.","travel"); return end
			local ok, result = rules.openChest(getProfile(player), spot.id, random:NextNumber(), random:NextNumber(), os.time())
			notify(player, result.message, if ok and result.kind ~= "pointsTrap" and result.kind ~= "deathTrap" then "success" else "info")
			if not ok then return end
			effects:FireClient(player,{kind="chest",gift=gift,position=box.Position,rank=result.celebration,trap=result.kind=="deathTrap" or result.kind=="pointsTrap",animal=result.animal,equipment=result.equipment,title=result.title,message=result.message})
			entry.nextMove=math.min(entry.nextMove,os.clock()+12)
			if not gift and not entry.animating then
				entry.animating = true; local closed = lid.CFrame
				TweenService:Create(lid, TweenInfo.new(0.25), {CFrame = closed * CFrame.new(0, 1.1, 0.7) * CFrame.Angles(math.rad(-50), 0, 0)}):Play()
				task.delay(2, function() if lid.Parent then lid.CFrame = closed end; entry.animating = false end)
			end
			if result.kill then humanoid.Health = 0 end
		end)
	end
	locations:start()
	Players.PlayerRemoving:Connect(function(player) lastInteraction[player] = nil end)
end
return ExpeditionWorld
