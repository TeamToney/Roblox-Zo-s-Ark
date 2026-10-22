--!nonstrict
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("ZoShared")
local Config=require(Shared.Config)
local Catalog=require(Shared.Catalog)
local Rules=require(Shared.EncounterRules)
local Hints={}
function Hints.start(player)
	local entries={}; local connections={}; local elapsed=0
	local function watch(model)
		if model:IsA("Model") and Catalog.Species[model:GetAttribute("SpeciesId")] then entries[model]=true end
	end
	for _,model in workspace:GetDescendants() do watch(model) end
	table.insert(connections,workspace.DescendantAdded:Connect(function(model) if model:IsA("Model") then task.defer(watch,model) end end))
	table.insert(connections,workspace.DescendantRemoving:Connect(function(model) entries[model]=nil end))
	table.insert(connections,RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt; if elapsed<0.2 then return end; elapsed=0
		local character=player.Character; local head=character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		local exclude={}; for _,other in Players:GetPlayers() do if other.Character then table.insert(exclude,other.Character) end end
		local runtime=workspace:FindFirstChild("ZoRuntime"); local actors=runtime and runtime:FindFirstChild("Wildlife")
		if actors then table.insert(exclude,actors) end
		local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances=exclude; params.IgnoreWater=true
		for model in entries do
			if not model.Parent then entries[model]=nil; continue end
			local root=model.PrimaryPart; local gui=root and root:FindFirstChild("AnimalIdentification")
			local label=gui and gui:FindFirstChildWhichIsA("TextLabel")
			if not gui or not label then continue end
			local species=Catalog.Species[model:GetAttribute("SpeciesId")]
			local distance=if head then (root.Position-head.Position).Magnitude else math.huge
			local visible=head and humanoid and humanoid.Health>0 and distance<=Config.PredatorWarningDistance and not workspace:Raycast(head.Position,root.Position-head.Position,params)
			local mode=Rules.identification(distance,visible==true,species.dangerous==true,Config)
			gui.Enabled=mode~="hidden"
			if mode=="identify" then
				label.Text=species.name.."\n"..(if species.dangerous then "DANGER • restrain before rescue" else species.rarity.." • Tier "..species.tier)
				label.TextColor3=if species.dangerous then Color3.fromRGB(255,115,110) else Color3.fromRGB(255,245,219)
			elseif mode=="warning" then label.Text="PREDATOR NEARBY\nPrepare tranquilizer / snare"; label.TextColor3=Color3.fromRGB(255,143,92) end
		end
	end))
	return function() for _,connection in connections do connection:Disconnect() end; table.clear(entries) end
end
return Hints
