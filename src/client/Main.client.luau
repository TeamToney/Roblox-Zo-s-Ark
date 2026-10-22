--!nonstrict
local ChestCutscene = require(script.Parent.ChestCutscene)
local MusicPlayer = require(script.Parent.MusicPlayer)
local MusicView = require(script.Parent.MusicView)
local RewardAudio=require(script.Parent.RewardAudio)
local NightGear=require(script.Parent.NightGear)
local lootStatus=require(script.Parent.LootStatus).new()
local AnimalPortrait=require(script.Parent.AnimalPortrait)
local GuiService = game:GetService("GuiService")
local CurrencyHUD = require(script.Parent.CurrencyHUD)
local TravelView = require(script.Parent.TravelView)
local ShopView = require(script.Parent.ShopView)
local ChestEffects = require(script.Parent.ChestEffects)
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("ZoShared")
local Catalog = require(Shared.Catalog)
local NightRules=require(Shared.NightRules)
local Config = require(Shared.Config)
local Layout = require(Shared.MapLayout)
local Islands = require(Shared.IslandLayouts)
local Geometry = require(Shared.MapGeometry)
local notebook = require(Shared.NotebookState).new()
local state, currentPage, pendingTrade, requestBusy = nil, "guide", nil, false
local render, send, open, closeNotebook
local music

local palette = {}
for key, color in require(Shared.Colors) do palette[key]=Color3.fromRGB(unpack(color)) end

local function make(class, properties, parent)
	local instance = Instance.new(class)
	for key, value in properties do instance[key] = value end
	instance.Parent = parent
	return instance
end
local function corner(parent, radius)
	make("UICorner", {CornerRadius = UDim.new(0, radius or 12)}, parent)
end
local function text(parent, content, size, color, position, dimensions, bold)
	return make("TextLabel", {
		Text = content, TextSize = size or 14, TextColor3 = color or palette.cream,
		Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham,
		BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = true,
		Position = position or UDim2.new(), Size = dimensions or UDim2.fromScale(1, 1),
	}, parent)
end
local function button(parent, content, position, dimensions, callback, subdued)
	local b = make("TextButton", {
		Text = content, Position = position, Size = dimensions,
		BackgroundColor3 = if subdued then palette.soft else palette.mint,
		TextColor3 = if subdued then palette.cream else palette.ink,
		Font = Enum.Font.GothamBold, TextSize = 13, BorderSizePixel = 0,
		AutoButtonColor = true, Selectable = true, TextWrapped = true,
	}, parent)
	corner(b, 9); b.Activated:Connect(callback)
	return b
end
local function number(value)
	local result = tostring(math.floor(value or 0))
	return result:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end
local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local gui = make("ScreenGui", {Name = "ZosArk", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
local header = make("Frame", {ZIndex=40, Active=true,BackgroundColor3 = palette.ink, BackgroundTransparency = 0.04, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 58)}, gui)
corner(header)
local brand = text(header, "ZO'S ARK", 23, palette.cream, UDim2.fromOffset(16, 5), UDim2.fromOffset(200, 29), true)
local subtitle = text(header, "EXPLORE  /  RESCUE  /  RESTORE", 10, palette.mint, UDim2.fromOffset(16, 32), UDim2.fromOffset(240, 18), true)
local wallet = CurrencyHUD.new(header, make)

local tide = make("Frame", {ZIndex=40,Active=true,BackgroundColor3 = palette.card, BackgroundTransparency = 0.08, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 73), Size = UDim2.new(1, -24, 0, 39)}, gui)
corner(tide, 9)
local tideText = text(tide, "A whole world of wildlife is waiting.", 12, palette.mint, UDim2.fromOffset(12, 0), UDim2.new(1, -126, 1, 0), true)
local musicToggle=button(tide,"♫ ON",UDim2.new(1,-103,0,4),UDim2.fromOffset(95,31),function() if music then music:toggle() end end,true)

local backdrop = make("TextButton", {Name="NotebookBackdrop",Text="",AutoButtonColor=false,Selectable=false,Active=true,BackgroundColor3=Color3.fromRGB(3,12,24),BackgroundTransparency=0.45,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=20}, gui)
backdrop.Activated:Connect(function() if closeNotebook then closeNotebook() end end)
local panel = make("Frame", {Name = "Notebook", Active=true, ZIndex=30, BackgroundColor3 = palette.ink, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 122), Size = UDim2.fromOffset(690, 480)}, gui)
corner(panel, 16)
local title = text(panel, "Welcome aboard", 23, palette.cream, UDim2.fromOffset(18, 9), UDim2.new(1, -76, 0, 31), true)
local description = text(panel, "Preparing your expedition…", 12, palette.muted, UDim2.fromOffset(18, 39), UDim2.new(1, -36, 0, 35))
local close = button(panel, "×", UDim2.new(1, -49, 0, 12), UDim2.fromOffset(34, 32), function() if closeNotebook then closeNotebook() end end, true)
close.TextSize = 24; close.ZIndex=10; close.Modal=true
local scroll = make("ScrollingFrame", {
	ClipsDescendants=true, Active=true, ZIndex=2, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(14, 82),
	Size = UDim2.new(1, -28, 1, -96), ScrollBarThickness = 4, ScrollBarImageColor3 = palette.mint,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, panel)
make("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)
make("UIPadding", {PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8)}, scroll)

local nav = make("Frame", {ZIndex=31,Active=true,BackgroundColor3 = palette.ink, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(650, 48)}, gui)
corner(nav, 14)
local tabs = {{"journal", "Journal"}, {"store", "Store"}, {"challenges", "Quests"}, {"map", "Chart"}, {"travel", "Travel"}, {"kit", "Field Kit"}, {"music", "Music"}, {"guide", "Guide"}}
local navButtons = {}
local survival = make("Frame", {BackgroundColor3 = palette.ink, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -98), Size = UDim2.fromOffset(650, 48)}, gui)
corner(survival, 10)
local survivalText = text(survival, "SWIM ENDURANCE", 12, palette.mint, UDim2.fromOffset(12, 1), UDim2.new(1, -24, 0, 23), true)
local movementText = text(survival, "Every 10 steps or strokes earns a bonus", 10, palette.muted, UDim2.fromOffset(12, 23), UDim2.new(1, -24, 0, 17))
local enduranceTrack = make("Frame", {BackgroundColor3 = palette.soft, BorderSizePixel = 0, Position = UDim2.new(0, 12, 1, -6), Size = UDim2.new(1, -24, 0, 3)}, survival)
local enduranceFill = make("Frame", {BackgroundColor3 = palette.mint, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1)}, enduranceTrack)
local location = text(gui, "", 12, palette.cream, UDim2.new(0.5, -220, 1, -88), UDim2.fromOffset(440, 20), true)
location.TextXAlignment = Enum.TextXAlignment.Center
location.TextStrokeTransparency = 0.4
local toast = make("Frame", {Visible = false, BackgroundColor3 = palette.ink, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -166), Size = UDim2.fromOffset(580, 56), ZIndex = 50}, gui)
corner(toast, 12)
local toastText = text(toast, "", 14, palette.cream, UDim2.fromOffset(14, 0), UDim2.new(1, -28, 1, 0), true)
toastText.ZIndex = 2
local toastSerial = 0
local function notify(message, success)
	if not message then return end
	toastSerial += 1; local serial = toastSerial
	toastText.Text = message; toastText.TextColor3 = if success then palette.mint else palette.cream
	toast.Visible = true
	task.delay(5, function() if toastSerial == serial then toast.Visible = false end end)
end

local markers = {}
local function card(height)
	local frame = make("Frame", {BackgroundColor3 = palette.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, height)}, scroll)
	corner(frame, 12)
	return frame
end
local function section(heading, body, height)
	local frame = card(height or 100)
	text(frame, heading, 17, palette.mint, UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 25), true)
	text(frame, body, 14, palette.cream, UDim2.fromOffset(14, 40), UDim2.new(1, -28, 1, -49)).TextYAlignment = Enum.TextYAlignment.Top
	return frame
end

local function journal()
	title.Text = "Your field journal"
	local discovered, carried = 0, 0
	for _ in state.profile.discovered do discovered += 1 end
	for _, count in state.profile.inventory do carried += count end
	description.Text = discovered .. "/" .. #Catalog.SpeciesOrder .. " discovered • Pack " .. carried .. "/" .. state.capacity .. " • Sanctuary trades keep your discoveries."
	for _, id in Catalog.SpeciesOrder do
		local species = Catalog.Species[id]
		local count = state.profile.inventory[id] or 0
		local found = state.profile.discovered[id]
		local rarity = Color3.fromRGB(unpack(Catalog.Rarities[species.rarity].color))
		local frame = card(156)
		AnimalPortrait.draw(frame,species,make)
		local stripe = make("Frame", {BackgroundColor3 = rarity, BorderSizePixel = 0, Size = UDim2.new(0, 4, 1, -20), Position = UDim2.fromOffset(0, 10)}, frame); corner(stripe, 3)
		text(frame, species.name, 16, if found then palette.cream else palette.muted, UDim2.fromOffset(104, 7), UDim2.new(1, -116, 0, 42), true)
		text(frame, species.rarity .. " • " .. string.upper(species.habitat) .. " • Tier " .. species.tier, 11, rarity, UDim2.fromOffset(104, 49), UDim2.new(1, -116, 0, 36), true)
		text(frame, number(species.points) .. " pts / catch  ·  " .. number(species.value) .. " coins / trade", 12, palette.muted, UDim2.fromOffset(104, 87), UDim2.new(1, -116, 0, 32))
		text(frame, if count > 0 then "CARRYING " .. count else (if found then "DISCOVERED" else "UNDISCOVERED"), 10, if count > 0 then palette.mint else palette.muted, UDim2.fromOffset(14,126), UDim2.new(1,-152,0,22), true)
		if count > 0 then
			button(frame, if pendingTrade == id then "Confirm trade" else "Trade 1", UDim2.new(1, -129, 0, 122), UDim2.fromOffset(116, 28), function()
				if not state.atShop then notify("Visit Ark Outfitters to transfer animals to the sanctuary."); return end
				if Catalog.Rarities[species.rarity].rank >= 3 and pendingTrade ~= id then
					pendingTrade = id; notify("This transfers one " .. species.name .. " permanently. Its journal discovery stays."); render(); return
				end
				pendingTrade = nil; send("sell", id, 1)
			end, not state.atShop)
		end
	end
end

local function shopContext()
	return {state=state,palette=palette,card=card,text=text,button=button,make=make,send=send,refresh=function() render() end}
end
local function store()
	title.Text = "Ark Outfitters"
	description.Text = if state.atShop then "Choose coins or Ark Points. Spending points can lower your level." else "Tap an item model or shelf price tag to select it. Visit Outfitters to buy or trade."
	ShopView.render(shopContext())
end
local function kit()
	title.Text="Your field kit"
	description.Text="Desktop: 1 Sprint • 2 Snare • 3 Scanner • 6 Trail Leap. Cosmetics stay equipped after respawn."
	ShopView.kit(shopContext())
end

local function progressBar(parent, value, goal, y)
	local background = make("Frame", {BackgroundColor3 = palette.soft, BorderSizePixel = 0, Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -144, 0, 6)}, parent); corner(background, 3)
	local fill = make("Frame", {BackgroundColor3 = palette.mint, BorderSizePixel = 0, Size = UDim2.fromScale(math.clamp(value / goal, 0, 1), 1)}, background); corner(fill, 3)
end
local function challenges()
	title.Text = "Expedition board"
	description.Text = "Daily challenges reset at midnight UTC. Claim completed rewards here."
	for _, id in Catalog.ChallengeOrder do
		local challenge = Catalog.Challenges[id]
		local value = state.profile.daily[id]
		local claimed = state.profile.daily.claimed[id]
		local ready = value >= challenge.goal and not claimed
		local frame = card(126)
		text(frame, challenge.name, 17, palette.cream, UDim2.fromOffset(14, 9), UDim2.new(1, -28, 0, 28), true)
		text(frame, challenge.description .. " • " .. number(math.min(value, challenge.goal)) .. "/" .. number(challenge.goal), 13, palette.muted, UDim2.fromOffset(14, 42), UDim2.new(1, -28, 0, 22))
		progressBar(frame, value, challenge.goal, 78)
		text(frame, "+" .. challenge.coins .. " coins / +" .. challenge.points .. " pts", 11, palette.gold, UDim2.fromOffset(14, 93), UDim2.new(1, -144, 0, 20), true)
		button(frame, if claimed then "Claimed" else (if ready then "Claim prize" else "In progress"), UDim2.new(1, -120, 0, 78), UDim2.fromOffset(106, 33), function() send("claim", id) end, not ready)
	end
	section("Island expeditions", "Checkpoints save your respawn. Explore both new islands and claim each expedition prize once.", 100)
	for _, id in Catalog.ExpeditionOrder do
		local definition, progress = Catalog.Expeditions[id], state.expeditions[id]
		local ready = progress.value >= progress.goal and not progress.claimed
		local frame = card(150)
		text(frame, definition.name, 17, palette.cream, UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 28), true)
		text(frame, definition.description, 12, palette.muted, UDim2.fromOffset(14, 38), UDim2.new(1, -28, 0, 42))
		progressBar(frame, progress.value, progress.goal, 90)
		text(frame, progress.value .. "/" .. progress.goal .. " • +" .. definition.coins .. " coins / +" .. definition.points .. " pts", 11, palette.gold, UDim2.fromOffset(14, 112), UDim2.new(1, -144, 0, 25), true)
		button(frame, if progress.claimed then "Claimed" elseif ready then "Claim prize" else "Explore", UDim2.new(1, -120, 0, 107), UDim2.fromOffset(106, 32), function() send("claim", id) end, not ready)
	end
	local captures = if state.profile.event.id == state.event.id then state.profile.event.captures else 0
	local claimed = state.profile.event.id == state.event.id and state.profile.event.claimed
	local frame = section("AURORA TIDE  /  Limited encounter", "Find the secluded coral alcove in Tidewater Hall. Rescue three Aurora Mantas in one tide. Requires Tier 3 gear and a Reef Snorkel.", 188)
	text(frame, number(math.min(captures, Config.EventGoal)) .. "/3 mantas • 350 coins + 250 pts + Aurora Voyager title", 12, palette.gold, UDim2.fromOffset(14, 113), UDim2.new(1, -28, 0, 30), true)
	button(frame, if claimed then "Prize claimed" else "Claim tide prize", UDim2.fromOffset(14, 147), UDim2.fromOffset(180, 30), function() send("claim", "event") end, not state.event.active or captures < Config.EventGoal or claimed)
end

local function mapSignature(count)
	local signature=count..":"..state.respawnCheckpoint
	for _,id in Catalog.MapOrder do signature..=":"..tostring(state.profile.maps[id]==true) end
	return signature
end
local function chart()
	title.Text = "Your archipelago chart"
	description.Text = "Ark Sanctuary • Canopy Reach • Moonstone Isle • North is up."
	local side = math.max(220, math.min(panel.AbsoluteSize.X - 56, 480))
	local frame = card(side + 32); frame.ClipsDescendants = true; frame.BackgroundColor3 = Color3.fromRGB(27, 84, 98)
	local plot = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(side, side), BackgroundTransparency = 1, ClipsDescendants = true}, frame)
	for i = 1, 4 do
		make("Frame", {BackgroundColor3 = palette.muted, BackgroundTransparency = 0.87, BorderSizePixel = 0, Position = UDim2.fromScale(i / 5, 0), Size = UDim2.new(0, 1, 1, 0)}, plot)
		make("Frame", {BackgroundColor3 = palette.muted, BackgroundTransparency = 0.87, BorderSizePixel = 0, Position = UDim2.fromScale(0, i / 5), Size = UDim2.new(1, 0, 0, 1)}, plot)
	end
	local info = ReplicatedStorage:FindFirstChild("ZoMapInfo")
	local hybrid = info and info:GetAttribute("MapKind") == "hybrid"
	local extent = if info then info:GetAttribute("Extent") or 2200 else 2200
	local cx, cz = if info then info:GetAttribute("CenterX") or 0 else 0, if info then info:GetAttribute("CenterZ") or 0 else 0
	local function site(caption, x, z, color)
		local px, py = 0.5 + (x - cx) / extent, 0.5 + (z - cz) / extent
		local long = #caption > 5
		local dot = make("TextLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(px, py), Size = UDim2.fromOffset(if #caption > 2 and not long then 34 else 16, 16), BackgroundColor3 = color, BorderSizePixel = 0, Text = if long then "" else caption, Font = Enum.Font.GothamBold, TextSize = 8, TextColor3 = palette.ink, ZIndex = 4}, plot)
		corner(dot, 5)
		if long then
			local name = text(plot, caption, 10, palette.cream, UDim2.new(px, -55, py, 12), UDim2.fromOffset(110, 30), true)
			name.TextXAlignment = Enum.TextXAlignment.Center; name.ZIndex = 4
		end
	end
	if hybrid then
		local plans = {Layout}; for _, plan in Islands.Islands do table.insert(plans, plan) end
		local colors = {room = Color3.fromRGB(185, 202, 185), meadow = Color3.fromRGB(153, 194, 119), jungle = Color3.fromRGB(80, 146, 111), summit = palette.cream, atrium = palette.gold, entry = Color3.fromRGB(232, 200, 144)}
		for _, plan in plans do
			local function rectangle(rect, color)
				local x1, z1 = Geometry.world(plan.Source, rect[1], rect[2])
				local x2, z2 = Geometry.world(plan.Source, rect[3], rect[4])
				make("Frame", {Position = UDim2.fromScale(0.5 + (x1 - cx) / extent, 0.5 + (z1 - cz) / extent), Size = UDim2.fromScale((x2 - x1) / extent, (z2 - z1) / extent), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 1}, plot)
			end
			for _, tile in Geometry.floorTiles(plan) do rectangle(tile, Color3.fromRGB(104, 140, 113)) end
			for _, rect in plan.Corridors do
				for _, tile in Geometry.floorTiles({Bounds = rect, WaterCuts = plan.WaterCuts}) do rectangle(tile, Color3.fromRGB(200, 209, 183)) end
			end
			for _, court in plan.Courtyards do rectangle(court.rect, colors[court.habitat]) end
			for _, room in plan.Rooms do
				if room.rect and room.kind ~= "marine" then rectangle(room.rect, colors[room.kind] or colors.room) end
				if room.polygon then
					local low, high = math.huge, -math.huge
					for _, v in room.polygon do low = math.min(low, v[2]); high = math.max(high, v[2]) end
					for y = low, high - 1, 4 do
						local span = Geometry.scanline(room.polygon, y + 2)
						if #span == 2 then rectangle({span[1], y, span[2], math.min(high, y + 4)}, colors[room.kind] or colors.room) end
					end
				end
				for _, line in Geometry.walls(room) do
					local x1, z1 = Geometry.world(plan.Source, line[1], line[2]); local x2, z2 = Geometry.world(plan.Source, line[3], line[4])
					make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + ((x1 + x2) / 2 - cx) / extent, 0.5 + ((z1 + z2) / 2 - cz) / extent), Size = UDim2.fromOffset(math.sqrt((x2 - x1)^2 + (z2 - z1)^2) / extent * side, 1), Rotation = math.deg(math.atan2(z2 - z1, x2 - x1)), BackgroundColor3 = palette.ink, BorderSizePixel = 0, ZIndex = 2}, plot)
				end
			end
			for _, cp in plan.Checkpoints do
				if state.profile.exploration.checkpoints[cp.id] then
					local x, z = Geometry.world(plan.Source, cp.x, cp.y)
					site("CP", x, z, if state.respawnCheckpoint == cp.id then palette.gold else palette.mint)
				end
			end
			if plan.Dock and plan.Dock.x then
				local x, z = Geometry.world(plan.Source, plan.Dock.x, plan.Dock.y); site((if state.profile.maps[plan.Id] then "" else "LOCKED • ")..plan.Name, x, z, if state.profile.maps[plan.Id] then palette.mint else palette.coral)
			else
				local x, z = Geometry.world(plan.Source, Layout.Hub[1], Layout.Hub[2]); site("ARK", x, z, palette.gold)
			end
			for _, exit in plan.ShoreExits do
				if not plan.Dock.x or exit.x ~= plan.Dock.x or exit.y ~= plan.Dock.y then
					local x, z = Geometry.world(plan.Source, exit.x, exit.y); site("EXIT", x, z, palette.mint)
				end
			end
		end
	else
		description.Text = "Your imported world • Coral dot: you."
		if info then for _, point in info:GetChildren() do if point:IsA("Vector3Value") then site(point.Name, point.Value.X, point.Value.Z, palette.mint) end end end
	end
	local dot = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = palette.coral, BorderSizePixel = 0, ZIndex = 5}, plot); corner(dot, 8)
	local count = 0; for _ in state.profile.exploration.checkpoints do count += 1 end
	markers = {player = dot, extent = extent, centerX = cx, centerZ = cz, signature = mapSignature(count)}
	text(plot, "N ↑", 12, palette.cream, UDim2.fromOffset(2, 2), UDim2.fromOffset(50, 22), true).ZIndex = 4
	section("Sail the three islands", "The Ark is west. Canopy Reach lies northeast; Moonstone Isle lies southeast. Unlock their permanent entry in Travel, then sail for free or buy an optional teleport. CP marks discovered checkpoints; gold is your active respawn. EXIT marks shore stairs.", 145)
	section("Search beyond the main galleries", "Rare, Epic and Legendary animals can appear on all islands and sea routes. Paid islands and secluded habitats improve their odds; hidden habitats and chests are not marked. Activate checkpoints and check the expedition board for island challenges.", 140)
end

local function guide()
	title.Text = "Welcome aboard, explorer."
	description.Text = "The Ark base. Outdoor biomes. An open sea."
	local info = ReplicatedStorage:FindFirstChild("ZoMapInfo")
	local hybrid = info and info:GetAttribute("MapKind") == "hybrid"
	section("01  /  Meet the meadow", if hybrid then "From the southern entrance, visit Meadow Courtyard west of the central avenue. Approach a rabbit or fox and hold Rescue. Your starter kit handles Tier 1 animals." else "Follow the chart to a meadow habitat. Approach a rabbit or fox and hold Rescue. Your starter kit handles Tier 1 animals.", 136)
	section("02  /  Bring them home", if hybrid then "Head north to the pointed Ark Atrium and enter from its north side. At Ark Outfitters, trade animals through the journal. Discoveries stay. Surprise chest traps can reduce Ark Points." else "Return to Ark Outfitters using its distance indicator. Trade animals through the journal; discoveries stay.", 140)
	section("03  /  Prepare an expedition", "Buy the Ranger Net for larger animals. A Reef Snorkel opens more sea encounters. Rescue and water gear are automatic. Buy with coins or points; open Field Kit to activate supplies and equip cosmetics.", 126)
	section("04  /  Sail beyond the base", if hybrid then "Tidewater Hall is in the northeast. Descend the boarding steps in its southern pool to reach a free boat, then sail through the eastern sea gate. Swim or sail close to marine animals." else "Find your world's expedition dock and borrow a free boat. Sit to steer and jump to leave. Swim or sail close to marine animals to rescue them.", 148)
	section("05  /  Follow the Aurora Tide", "An eight-minute event returns every thirty minutes. Rescue three Aurora Mantas at the reef, then claim a special title and bonus rewards on the expedition board.", 126)
	section("06  /  After dark", "The sky cycles through 20 minutes of day and 5 minutes of night. Night capture coins/points pay 2×; night predators pay 3×. Watch for boars, panthers and sharks! Buy flashlight cells (F), night vision (V), a tranquilizer (4) or a 3-minute Predator Rescue Snare (5). Sedate or restrain predators before rescuing them. The Ark and checkpoints are safe resting areas.", 204)
	local checkpoint = Catalog.Checkpoints[state.respawnCheckpoint]
	section("Island access & checkpoints", "Open Travel to unlock Canopy Reach or Moonstone Isle with coins, points or configured Robux offers. Then sail there or buy a teleport. Activate checkpoints to save your respawn, then finish island challenges on the expedition board. Current respawn: " .. (if checkpoint then checkpoint.name else "Ark southern entrance") .. ".", 155)
	section("Surprise chests", "Each chest is free to open once per explorer per UTC day. Find coins, hidden animals, gear, sprint boosts or snares; some chests trap you, remove points or kill your character. Death returns you to your checkpoint. Your collected animals and gear stay.", 160)
	section("Spot, identify & rescue", "Look for animal shapes and coat patterns. Journal portraits help you identify them; names appear only within 12 studs in clear view. Predators give a nearby danger warning. Nervous animals run or fly away. Sprint, camouflage, snares and the scanner help you approach. Keys: 1 sprint, 2 snare, 3 scan; Field Kit supports touch too.", 192)
	section("Trees & trail leaps", "Trunks, rocks and fallen logs are solid. Follow the open paths and doorways through the taller walls. Buy Trail Leap at Outfitters for 110 coins or 75 points, then use Field Kit / key 6 for 45 seconds of higher jumps. It ends on respawn and does not unlock paid islands.", 160)
	section("Hidden wildlife", "Hold Rescue for 0.65–1.2 seconds, depending on rarity. Common wildlife can wander through connected rooms. Rare, Epic and Legendary wildlife can appear on every island and sea route. Paid islands and secluded habitats offer better odds.", 138)
	section("Swim safely", "Start with 30 seconds of endurance. A snorkel gives 60s; the diving kit gives 180s. A life jacket adds 60s to either. Rest on land or in a boat to recover. At zero endurance, health drains: look for marked shore steps, orange life rings and green first-aid floats.", 176)
	section("Water recovery pickups", "Life rings restore 15s and pause fatigue for 20s. First-aid floats restore 25 health and 20s of endurance. Hold their nearby prompt while swimming. Used pickups return after 90 seconds.", 144)
	section("Make every journey count", "Every 10 walking steps earns 2 coins + 1 Ark Point. Every 10 swimming strokes earns 3 coins + 2 points. Boats earn distance milestones, not step or stroke bonuses. The 500-stud exploration reward and daily challenges still apply.", 152)
	if state.temporary then section("Studio playtest", "This session uses a temporary journal. Coins and discoveries reset when the test server stops.", 100) end
end

render = function()
	if not state then return end
	lootStatus.update(state.profile)
	local oldPosition = scroll.CanvasPosition
	wallet:update(state.profile.coins,state.profile.points)
	subtitle.Text = (if state.profile.titles[Config.EventTitle] then "AURORA VOYAGER" else "LEVEL "..state.level)..(if state.temporary then " • SESSION" else " • EXPLORER")
	for key, b in navButtons do b.BackgroundColor3 = if key == currentPage and panel.Visible then palette.soft else palette.ink end
	if not panel.Visible then return end
	-- The floor plan is static. Reuse it while fresh snapshots update the HUD
	-- and the separate player dot, rather than rebuilding hundreds of lines.
	local visited = 0; for _ in state.profile.exploration.checkpoints do visited += 1 end
	if currentPage == "map" and markers.player and markers.player.Parent and markers.signature == mapSignature(visited) then return end
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(scroll) then GuiService.SelectedObject=nil end
	for _, child in scroll:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	markers = {}
	if currentPage == "journal" then journal()
	elseif currentPage == "store" then store()
	elseif currentPage == "travel" then title.Text="Islands & teleports"; description.Text="Unlock new expeditions. Sailing is free after unlocking; teleports are optional."; TravelView.render(shopContext())
	elseif currentPage == "kit" then kit()
	elseif currentPage == "challenges" then challenges()
	elseif currentPage == "map" then chart()
	elseif currentPage == "music" then
		title.Text="Ark Radio"; description.Text="Pick a style, choose a track and set your own volume. Shortcut: N."
		if music then MusicView.render(music,shopContext()) end
	else guide() end
	scroll.CanvasPosition = oldPosition
end

closeNotebook = function()
	notebook.close(os.clock()); panel.Visible=false; backdrop.Visible=false
	pendingTrade=nil; ShopView.selected=nil; ShopView.category="All"
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then GuiService.SelectedObject=nil end
	if render then render() end
end
open = function(page)
	if not notebook.open() then return end
	backdrop.Visible=true
	pendingTrade = nil
	if currentPage ~= page then scroll.CanvasPosition = Vector2.zero end
	currentPage = page; panel.Visible = true; render()
end
for index, tab in tabs do
	navButtons[tab[1]] = button(nav, tab[2], UDim2.new((index - 1) / #tabs, 5, 0, 5), UDim2.new(1 / #tabs, -10, 1, -10), function()
		if panel.Visible and currentPage == tab[1] then closeNotebook() else open(tab[1]) end
		if tab[1] == "store" and send then send("snapshot") end
	end, true)
	navButtons[tab[1]].TextSize = 12
	navButtons[tab[1]].TextWrapped = true
end

local function resize()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local short = viewport.Y < 500
	local compact = viewport.X < 560
	local extraNav=if compact then 40 else 0
	tide.Visible = not short
	tideText.TextSize=if compact then 10 else 12
	panel.Position = UDim2.new(0.5, 0, 0, if short then 76 else 122)
	panel.Size = UDim2.fromOffset(math.min(690, viewport.X - 24), math.max(110, math.min(530, viewport.Y - (if short then 144 else 288)-extraNav)))
	nav.Size = UDim2.fromOffset(math.min(730, viewport.X - 24), 48+extraNav)
	survival.Size = UDim2.fromOffset(math.min(650, viewport.X - 24), 48)
	survival.Position=UDim2.new(0.5,0,1,-98-extraNav)
	toast.Size = UDim2.fromOffset(math.min(580, viewport.X - 28), 62)
	toast.Position=UDim2.new(0.5,0,1,-166-extraNav)
	location.Size = UDim2.fromOffset(math.min(440, viewport.X - 24), 20)
	location.Position = UDim2.new(0.5, -math.min(440, viewport.X - 24) / 2, 1, -88-extraNav)
	for i,tab in tabs do
		local b=navButtons[tab[1]]; local columns=if compact then 4 else #tabs
		b.Position=UDim2.new(((i-1)%columns)/columns,5,0,5+math.floor((i-1)/columns)*40)
		b.Size=UDim2.new(1/columns,-10,0,38); b.TextSize=if compact then 11 else 12
	end
	survivalText.TextSize = if compact then 10 else 12
	brand.TextSize = if compact then 18 else 23
	subtitle.TextSize = if compact then 8 else 10
	subtitle.Size = UDim2.fromOffset(if compact then 140 else 240, 18)
	wallet:resize(viewport.X)
	brand.Size = UDim2.fromOffset(if compact then 105 else 200,29)
	subtitle.Size = UDim2.fromOffset(if compact then 108 else 240,18)
	if state and currentPage == "map" then markers = {}; render() end
end
resize()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(resize)

local remotes = ReplicatedStorage:WaitForChild("ZoRemotes", 30)
if not remotes then description.Text = "The world could not start. Please rejoin or check the server output in Studio."; return end
local action = remotes:WaitForChild("Action")
local boatInput = remotes:WaitForChild("BoatInput")
music=MusicPlayer.new(remotes:WaitForChild("MusicPlaylist"),function()
	if music then musicToggle.Text=if music.enabled then "♫ ON" else "♫ OFF" end
	if currentPage=="music" then render() end
end)
script.Destroying:Connect(function() music:destroy() end)
local stopNightGear=NightGear.start(player)
script.Destroying:Connect(stopNightGear)
script.Destroying:Connect(require(script.Parent.WildlifeHints).start(player))
script.Destroying:Connect(lootStatus.destroy)
send = function(verb, id, amount, currency)
	if requestBusy then return end
	requestBusy = true
	local uiRevision=notebook.state.revision
	task.spawn(function()
		local ok, result = pcall(function() return action:InvokeServer({action = verb, id = id, amount = amount, currency = currency}) end)
		requestBusy = false
		if not ok then notify("The Ark connection was interrupted. Please try again."); return end
		if result.state then state = result.state; state.receivedAt = os.clock(); render() end
		if result.ok and result.selection and notebook.acceptInspection(uiRevision,os.clock()) then
			ShopView.selected=result.selection; ShopView.category="All"; scroll.CanvasPosition=Vector2.zero; open("store")
		end
		if result.message then notify(result.message, result.ok) end
		if result.ok and result.productId then
			local prompted=pcall(function() MarketplaceService:PromptProductPurchase(player,result.productId) end)
			if not prompted then notify("Roblox could not open the purchase window. Please try again.") end
		end
	end)
end
local cutscene=ChestCutscene.new(player,function(active,data)
	if active then closeNotebook(); notebook.suspend(os.clock()) else notebook.resume(os.clock()) end
	gui.Enabled=not active
	music:setDucked(active)
	if not active and data then notify(data.message,not data.trap) end
end)
local watched=setmetatable({},{__mode="k"})
local function watchMerchandise(instance)
	if not instance:IsA("ClickDetector") or watched[instance] then return end
	local id=instance:GetAttribute("ZoShopItemId")
	if type(id)~="string" then return end
	watched[instance]=true
	instance.MouseClick:Connect(function(who)
		if who~=player or not notebook.canInspect(os.clock()) or GuiService.MenuIsOpen then return end
		local point=UserInputService:GetMouseLocation()
		if UserInputService.MouseEnabled then
			for _,hit in player.PlayerGui:GetGuiObjectsAtPosition(point.X,point.Y) do
				if not hit:IsDescendantOf(gui) then continue end
				local ancestor,visible=hit,true
				while ancestor and ancestor~=gui do
					if ancestor:IsA("GuiObject") and not ancestor.Visible then visible=false; break end
					ancestor=ancestor.Parent
				end
				if visible then return end
			end
		end
		send("inspect",id)
	end)
end
for _,instance in workspace:GetDescendants() do watchMerchandise(instance) end
workspace.DescendantAdded:Connect(function(instance) if instance:IsA("ClickDetector") then task.defer(watchMerchandise,instance) end end)
remotes:WaitForChild("Effects").OnClientEvent:Connect(function(data)
	if data.kind=="chest" then cutscene:play(data) elseif data.kind=="scan" then ChestEffects.scan(data) elseif data.kind=="captureReward" then RewardAudio.play() end
end)
remotes:WaitForChild("Changed").OnClientEvent:Connect(function(update)
	if update.state then state = update.state; state.receivedAt = os.clock() end
	if update.kind=="travel" then open("travel")
	elseif update.kind=="shop" and notebook.canInspect(os.clock()) then ShopView.selected=nil; open("store")
	elseif update.kind=="challenges" and not notebook.state.suspended then open("challenges")
	else render() end
	notify(update.message, update.kind == "success")
end)
task.spawn(function()
	for _ = 1, 15 do
		send("snapshot")
		if state then return end
		task.wait(2)
	end
	if not state then description.Text = "Your expedition is taking longer to load. Please check the server output or rejoin." end
end)

local hotkeys = {[Enum.KeyCode.J] = "journal", [Enum.KeyCode.B] = "store", [Enum.KeyCode.C] = "challenges", [Enum.KeyCode.M] = "map", [Enum.KeyCode.H] = "guide", [Enum.KeyCode.K] = "kit", [Enum.KeyCode.T] = "travel", [Enum.KeyCode.N] = "music"}
UserInputService.InputBegan:Connect(function(input, processed)
	if notebook.state.suspended then return end
	if panel.Visible and (input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB) then closeNotebook(); return end
	if processed then return end
	local kitKeys={[Enum.KeyCode.One]="speedBoost",[Enum.KeyCode.Two]="animalTrap",[Enum.KeyCode.Three]="tracker"}
	kitKeys[Enum.KeyCode.Four]="tranquilizer"; kitKeys[Enum.KeyCode.Five]="predatorTrap"; kitKeys[Enum.KeyCode.F]="flashlight"; kitKeys[Enum.KeyCode.V]="nightVision"
	kitKeys[Enum.KeyCode.Six]="jumpBoost"
	if kitKeys[input.KeyCode] then send("use",kitKeys[input.KeyCode]); return end
	local page = hotkeys[input.KeyCode]
	if page then if panel.Visible and currentPage == page then closeNotebook() else open(page) end end
end)
local elapsed, boatElapsed = 0, 0
RunService.RenderStepped:Connect(function(dt)
	local short=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y<500
	survival.Visible=not short or not panel.Visible
	location.Visible=not short or not panel.Visible
	boatElapsed += dt
	if boatElapsed >= 0.1 then
		boatElapsed = 0
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		if seat and seat:IsA("VehicleSeat") then boatInput:FireServer(if notebook.state.suspended then 0 else seat.ThrottleFloat, if notebook.state.suspended then 0 else seat.SteerFloat) end
	end
	elapsed += dt; if elapsed < 0.2 then return end; elapsed = 0
	if state then
		local remaining = state.event.remaining - (os.clock() - state.receivedAt)
		local epoch=workspace:GetAttribute("ZoDayEpoch")
		local day=NightRules.cycle(if epoch then workspace:GetServerTimeNow()-epoch else Config.CycleStartPhase,Config)
		local hour=math.floor(day.hour); local minute=math.floor((day.hour-hour)*60)
		local compact=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X<560
		local time=string.format("%02d:%02d",hour,minute)
		local bonus=NightRules.multiplier(day.night,false,Config); local dangerousBonus=NightRules.multiplier(day.night,true,Config)
		local caption=if compact then (if day.night then "NIGHT "..time.." • "..bonus.."×/"..dangerousBonus.."×\nDawn "..clock(day.remaining) else "DAY "..time.."\nNight in "..clock(day.remaining)) else (if day.night then "NIGHT "..time.." • "..bonus.."× catches / predators "..dangerousBonus.."× • Dawn "..clock(day.remaining) else "DAY "..time.." • Night in "..clock(day.remaining))
		local character=player.Character
		if character and character:GetAttribute("ZoFlashlightOn") then caption..=" • F "..(character:GetAttribute("ZoFlashlightRemaining") or 0).."s"
		elseif character and character:GetAttribute("ZoNightVisionOn") then caption..=" • NV ON"
		elseif not compact then caption..=if state.event.active then "  |  AURORA TIDE "..clock(remaining) else "  |  Next tide "..clock(remaining) end
		tideText.Text=caption; tideText.TextColor3=if day.night then palette.gold else palette.mint
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and humanoid then
		local maximum = character:GetAttribute("ZoSwimMaximum") or (state and state.safety and state.safety.maximum) or Config.SwimSeconds
		local remaining = character:GetAttribute("ZoSwimRemaining") or maximum
		local floating = character:GetAttribute("ZoSwimFloating") or 0
		local swimming = character:GetAttribute("ZoSwimming") == true
		local warning = swimming and remaining <= 10 and floating <= 0
		local compact = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X < 560
		local boost=character:GetAttribute("ZoBoostRemaining") or 0
		local caption = if boost>0 and not swimming then "SPRINT "..boost.."s" elseif floating > 0 then "FLOATING " .. math.ceil(floating) .. "s" elseif swimming and remaining <= 0 then "EXHAUSTED" elseif swimming then "SWIMMING" else "SWIM ENDURANCE"
		survivalText.Text = caption .. "  •  " .. math.ceil(remaining) .. "/" .. maximum .. "s  •  HP " .. math.ceil(humanoid.Health)
		survivalText.TextColor3 = if warning then palette.coral else palette.mint
		enduranceFill.Size = UDim2.fromScale(math.clamp(remaining / maximum, 0, 1), 1)
		enduranceFill.BackgroundColor3 = if warning then palette.coral else palette.mint
		local steps = character:GetAttribute("ZoSteps") or (state and math.floor(state.profile.stats.walkDistance / Config.StepStuds)) or 0
		local strokes = character:GetAttribute("ZoStrokes") or (state and math.floor(state.profile.stats.swimDistance / Config.StrokeStuds)) or 0
		movementText.Text = if compact then "STEPS " .. steps % 10 .. "/10  •  STROKES " .. strokes % 10 .. "/10" else "STEPS " .. steps % 10 .. "/10 (+2 coins, +1 pt)  •  STROKES " .. strokes % 10 .. "/10 (+3 coins, +2 pts)"
	end
	local station = ReplicatedStorage:FindFirstChild("ZoShopPosition")
	if root and station then
		local distance = (root.Position - station.Value).Magnitude
		location.Text = if distance <= Config.ShopDistance then "ARK OUTFITTERS  /  Trading & gear available" else "ARK OUTFITTERS  /  " .. number(distance) .. " studs away"
	end
	if root and markers.player and markers.player.Parent then
		markers.player.Position = UDim2.fromScale(math.clamp(0.5 + (root.Position.X - markers.centerX) / markers.extent, 0, 1), math.clamp(0.5 + (root.Position.Z - markers.centerZ) / markers.extent, 0, 1))
	end
end)
