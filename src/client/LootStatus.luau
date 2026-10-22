--!nonstrict
local LootStatus={}
function LootStatus.new()
	local entries={}; local claims={}; local connections={}
	local function refresh(model)
		if not model.Parent then entries[model]=nil; return end
		local id=model:GetAttribute("ZoLootId"); local kind=model:GetAttribute("ZoLootKind") or "SURPRISE CHEST"
		local claimed=(claims[id] or -1)>=math.floor(workspace:GetServerTimeNow()/86400)
		local prompt=model:FindFirstChildWhichIsA("ProximityPrompt",true)
		if prompt then prompt.Enabled=not claimed end
		local billboard=model:FindFirstChildWhichIsA("BillboardGui",true)
		local label=billboard and billboard:FindFirstChildWhichIsA("TextLabel")
		if label then label.Text=kind.."\n"..(if claimed then "OPENED TODAY" else "Rewards or traps • once daily") end
	end
	local function watch(instance)
		if instance:IsA("Model") and type(instance:GetAttribute("ZoLootId"))=="string" then entries[instance]=true; refresh(instance) end
	end
	for _,instance in workspace:GetDescendants() do watch(instance) end
	table.insert(connections,workspace.DescendantAdded:Connect(function(instance) if instance:IsA("Model") then task.defer(watch,instance) end end))
	table.insert(connections,workspace.DescendantRemoving:Connect(function(instance) entries[instance]=nil end))
	return {
		update=function(profile)
			claims=profile.exploration.chests
			for model in entries do refresh(model) end
		end,
		destroy=function() for _,connection in connections do connection:Disconnect() end; table.clear(entries) end,
	}
end
return LootStatus
