--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("ZoShared")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Rules = require(Shared.Rules).new(Catalog, Config)
local World = require(script.Parent.World)
local Wildlife = require(script.Parent.Wildlife)
local WaterSafety = require(script.Parent.WaterSafety)
local ExpeditionWorld = require(script.Parent.ExpeditionWorld)
local Store = require(script.Parent.ProfileStore).new(Rules, Config, {
	openStore = function(name) return game:GetService("DataStoreService"):GetDataStore(name) end,
	temporary = RunService:IsStudio() and workspace:GetAttribute("ZoUseLiveDataInStudio") ~= true,
	newToken = function() return game:GetService("HttpService"):GenerateGUID(false) end,
	now = os.time, clock = os.clock, sleep = task.wait, warn = warn,
})

local remotes = Instance.new("Folder"); remotes.Name = "ZoRemotes"; remotes.Parent = ReplicatedStorage
local action = Instance.new("RemoteFunction"); action.Name = "Action"; action.Parent = remotes
local changed = Instance.new("RemoteEvent"); changed.Name = "Changed"; changed.Parent = remotes
local boatInput = Instance.new("RemoteEvent"); boatInput.Name = "BoatInput"; boatInput.Parent = remotes
local world = World.build(Config)
local sessions, positions, buckets, captureTimes, loading = {}, {}, {}, {}, {}
local waterSafety
local closing = false
local preview = RunService:IsStudio() and workspace:GetAttribute("ZoPreviewEvent") ~= false

local function healthyRoot(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if root and humanoid and humanoid.Health > 0 then root else nil
end

local function atShop(player)
	local root = healthyRoot(player)
	return root ~= nil and (root.Position - world.shopPosition).Magnitude <= Config.ShopDistance
end

local function snapshot(player)
	local session = sessions[player]
	if not session or session.closed or session.lost then return nil end
	Rules.refresh(session.data, os.time())
	local expeditions = {}
	for _, id in Catalog.ExpeditionOrder do
		local value, goal = Rules.expeditionProgress(session.data, id)
		expeditions[id] = {value = value, goal = goal, claimed = session.data.exploration.claimed[id] == true}
	end
	return {profile = session.data, expeditions = expeditions, capacity = Rules.capacity(session.data), tier = Rules.tier(session.data), level = Rules.level(session.data.points), atShop = atShop(player), event = Rules.eventWindow(os.time(), preview), temporary = session.temporary, safety = if waterSafety then waterSafety:snapshot(player) else nil, serverTime = os.time()}
end

local function push(player, message, kind)
	if player.Parent == Players then changed:FireClient(player, {state = snapshot(player), message = message, kind = kind}) end
end

waterSafety = WaterSafety.new(world, Config, function(player)
	local session = sessions[player]
	return if session and not session.lost and not session.closed then session.data.owned else nil
end, function(player, mode, distance, elapsed)
	local session = sessions[player]
	if not session or session.lost or session.closed or closing then return end
	local awards = Rules.movement(session.data, mode, distance, elapsed)
	local character = player.Character
	if character then
		character:SetAttribute("ZoSteps", math.floor(session.data.stats.walkDistance / Config.StepStuds))
		character:SetAttribute("ZoStrokes", math.floor(session.data.stats.swimDistance / Config.StrokeStuds))
	end
	if awards > 0 then
		local swimming = mode == "swim"
		local coins = awards * (if swimming then Config.SwimBonusCoins else Config.WalkBonusCoins)
		local points = awards * (if swimming then Config.SwimBonusPoints else Config.WalkBonusPoints)
		push(player, (if swimming then "Swimming" else "Walking") .. " bonus! +" .. coins .. " coins • +" .. points .. " Ark Points", "success")
	end
end, push)

ExpeditionWorld.build(world, Catalog, Rules, function(player)
	local session = sessions[player]
	return if session and not session.closed and not session.lost and not closing then session.data else nil
end, push)

local function allow(player)
	local now = os.clock()
	local bucket = buckets[player] or {tokens = 6, updated = now}
	bucket.tokens = math.min(6, bucket.tokens + (now - bucket.updated) * 2)
	bucket.updated = now; buckets[player] = bucket
	if bucket.tokens < 1 then return false end
	bucket.tokens -= 1; return true
end

action.OnServerInvoke = function(player, request)
	if not allow(player) then return {ok = false, message = "Please wait a moment."} end
	if closing then return {ok = false, message = "The Ark is saving. Please rejoin shortly."} end
	local session = sessions[player]
	if not session or session.lost then return {ok = false, message = "Your journal is still loading."} end
	if type(request) ~= "table" or type(request.action) ~= "string" then return {ok = false, message = "Invalid request."} end
	if request.action == "snapshot" then return {ok = true, state = snapshot(player)} end
	if type(request.id) ~= "string" or #request.id > 64 then return {ok = false, message = "Invalid item."} end
	local ok, message
	if request.action == "buy" or request.action == "sell" then
		if not atShop(player) then return {ok = false, message = "Return to Ark Outfitters to buy gear or trade animals.", state = snapshot(player)} end
		if request.action == "buy" then ok, message = Rules.buy(session.data, request.id)
		else ok, message = Rules.sell(session.data, request.id, request.amount) end
	elseif request.action == "claim" then
		ok, message = Rules.claim(session.data, request.id, os.time(), preview)
	else
		return {ok = false, message = "Unknown action."}
	end
	return {ok = ok, message = message, state = snapshot(player)}
end

local function capture(player, animal)
	local session = sessions[player]; local root = healthyRoot(player)
	if not session or session.lost or closing or not root then return false end
	if not animal.alive or not animal.model.Parent or (root.Position - animal.root.Position).Magnitude > Config.CaptureDistance then return false end
	local now = os.clock()
	if now - (captureTimes[player] or -math.huge) < Config.CaptureCooldown then return false end
	captureTimes[player] = now
	local visibility = RaycastParams.new(); visibility.FilterType = Enum.RaycastFilterType.Exclude; visibility.IgnoreWater = true
	local excluded = {world.actors, world.boats}
	for _, other in Players:GetPlayers() do if other.Character then table.insert(excluded, other.Character) end end
	visibility.FilterDescendantsInstances = excluded
	if workspace:Raycast(root.Position, animal.root.Position - root.Position, visibility) then
		push(player, "Move through the habitat entrance for a clear view of the animal.", "info")
		return false
	end
	local captured, message = Rules.attempt(session.data, animal.id, Random.new():NextNumber(), os.time(), preview, animal.zone.mapId)
	push(player, message, if captured then "success" else "info")
	return captured
end

world.shopPrompt.Triggered:Connect(function(player) if atShop(player) then push(player, nil, "shop") end end)
world.challengePrompt.Triggered:Connect(function(player)
	local root = healthyRoot(player)
	if root and (root.Position - world.hub).Magnitude < 42 then push(player, nil, "challenges") end
end)

local function join(player)
	if loading[player] or sessions[player] then return end
	loading[player] = true
	player.RespawnLocation = world.spawnLocation
	local session, reason = Store:load(player.UserId)
	loading[player] = nil
	if not session then player:Kick(reason); return end
	if player.Parent ~= Players or closing then Store:save(session, true); return end
	sessions[player] = session
	player.RespawnLocation = world.checkpoints[session.data.exploration.activeCheckpoint] or world.spawnLocation
	local stats = Instance.new("Folder"); stats.Name = "leaderstats"; stats.Parent = player
	local points = Instance.new("IntValue"); points.Name = "Ark Points"; points.Value = session.data.points; points.Parent = stats
	local function characterAdded(character)
		positions[player] = nil
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root or player.Character ~= character or player.Parent ~= Players then return end
		-- Initial characters may exist before the procedural spawn is created.
		-- Move them to the authored entrance and discard the teleport for travel.
		local checkpoint = world.checkpoints[session.data.exploration.activeCheckpoint]
		character:PivotTo(if checkpoint then checkpoint.CFrame * CFrame.new(0, 4, 0) else world.spawn * CFrame.new(0, 2, 0))
		positions[player] = nil
		push(player)
	end
	player.CharacterAdded:Connect(characterAdded)
	if player.Character then task.spawn(characterAdded, player.Character) end
	push(player, "Welcome aboard Zo's Ark! Rescue wildlife, trade at the sanctuary, and explore.", "success")
end

Players.PlayerAdded:Connect(join)
for _, player in Players:GetPlayers() do task.spawn(join, player) end
Players.PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	sessions[player] = nil; positions[player] = nil; buckets[player] = nil; captureTimes[player] = nil
	waterSafety:remove(player)
	if session then Store:save(session, true) end
end)

task.spawn(function()
	while not closing do
		task.wait(1)
		if closing then break end
		local now = os.clock()
		for player, session in sessions do
			local root = healthyRoot(player)
			local last = positions[player]
			if root then
				if last then
					local delta = root.Position - last.position
					local elapsed = now - last.time
					local milestone = Rules.travel(session.data, Vector2.new(delta.X, delta.Z).Magnitude, elapsed, os.time())
					if milestone then push(player, "Exploration milestone! +25 coins • +15 Ark Points", "success") end
				end
				positions[player] = {position = root.Position, time = now}
			else positions[player] = nil end
			local points = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Ark Points")
			if points then points.Value = session.data.points end
			if session.lost or (not session.temporary and os.time() - session.lastSaved > Config.LeaseSeconds - 35) then
				player:Kick("Your journal's save connection was interrupted. Please rejoin so your progress stays safe.")
			end
		end
	end
end)

task.spawn(function()
	while not closing do
		task.wait(5)
		if closing then break end
		for player in sessions do push(player) end
	end
end)
task.spawn(function()
	while not closing do
		task.wait(Config.AutosaveSeconds)
		if closing then break end
		for _, session in sessions do task.spawn(function() Store:save(session, false) end) end
	end
end)

game:BindToClose(function()
	closing = true
	local remaining = 0
	for _, session in sessions do
		remaining += 1
		task.spawn(function() Store:save(session, true); remaining -= 1 end)
	end
	local deadline = os.clock() + 25
	while remaining > 0 and os.clock() < deadline do task.wait(0.1) end
end)

World.startBoats(world, boatInput)
waterSafety:start()
Wildlife.new(world, Catalog, Rules, capture, preview):start()
workspace:SetAttribute("ZoReady", true)
print("[Zo's Ark] World ready. " .. (if Store.temporary then "Studio session data only." else "Live profile saving enabled."))
