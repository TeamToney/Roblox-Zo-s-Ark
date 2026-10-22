--!nonstrict
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("ZoShared")
local Catalog=require(Shared.Catalog)
local AnimalShapes=require(Shared.AnimalShapes)
local ItemShapes=require(Shared.ItemShapes)
local Plans=require(Shared.ChestSceneRules)
local Cutscene={}; Cutscene.__index=Cutscene
local RewardAudio=require(script.Parent.RewardAudio)
local colors={Color3.fromRGB(48,244,190),Color3.fromRGB(255,210,49),Color3.fromRGB(97,174,255),Color3.fromRGB(216,113,255)}
local function make(class,properties,parent)
	local item=Instance.new(class); for key,value in properties do item[key]=value end; item.Parent=parent; return item
end
local function part(parent,name,size,cf,color,shape)
	return make("Part",{Name=name,Size=size,CFrame=cf,Color=color,Shape=shape or Enum.PartType.Block,Material=Enum.Material.SmoothPlastic,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false},parent)
end
local function text(parent,content,size,position,dimensions,color)
	return make("TextLabel",{Text=content,Font=Enum.Font.GothamBold,TextSize=size,TextColor3=color or Color3.fromRGB(255,249,224),BackgroundTransparency=1,Position=position,Size=dimensions,TextWrapped=true,ZIndex=4},parent)
end
local function tween(scene,item,duration,properties)
	local animation=TweenService:Create(item,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties)
	table.insert(scene.tweens,animation); animation:Play(); return animation
end
local function buildReward(scene,data)
	local model=make("Model",{Name="ChestPrize"},scene.world)
	local root=part(model,"PrizePivot",Vector3.one*0.1,CFrame.identity,Color3.new()); root.Transparency=1; model.PrimaryPart=root
	local specifications
	if data.animal and Catalog.Species[data.animal] then
		specifications=AnimalShapes.build(Catalog.Species[data.animal]).parts
		for _,spec in specifications do
			local cf=CFrame.new(unpack(spec.offset))*CFrame.Angles(math.rad(spec.rotation[1]),math.rad(spec.rotation[2]),math.rad(spec.rotation[3]))
			local object
			if spec.shape=="wedge" then
				object=make("WedgePart",{Size=Vector3.new(unpack(spec.size)),CFrame=cf,Color=Color3.fromRGB(unpack(spec.color)),Anchored=true,CanCollide=false,CanQuery=false},model)
			else object=part(model,spec.name,Vector3.new(unpack(spec.size)),cf,Color3.fromRGB(unpack(spec.color)),if spec.shape=="block" then Enum.PartType.Block else Enum.PartType.Ball) end
		end
	elseif data.equipment and Catalog.Items[data.equipment] then
		for _,spec in ItemShapes.build(data.equipment,Catalog.Items[data.equipment].kind) do
			part(model,"PrizeGear",Vector3.new(unpack(spec.size)),CFrame.new(unpack(spec.at)),Color3.fromRGB(unpack(spec.color)),if spec.shape=="ball" then Enum.PartType.Ball else nil)
		end
	elseif data.trap then
		for _,x in {-1.6,1.6} do part(model,"TrapJaw",Vector3.new(0.5,2.8,2.5),CFrame.new(x,0,0)*CFrame.Angles(0,0,x*0.15),Color3.fromRGB(212,82,110)) end
		part(model,"TrapTrigger",Vector3.new(2.5,0.3,2.5),CFrame.new(0,-1.4,0),Color3.fromRGB(255,120,93))
	else
		for i=1,7 do
			local coin=part(model,"TreasureCoin",Vector3.new(0.3,2.2,2.2),CFrame.new((i%3-1)*1.2,math.floor(i/3)*0.4,0)*CFrame.Angles(0,0,math.pi/2),colors[2],Enum.PartType.Cylinder)
			coin.Material=Enum.Material.Metal
		end
	end
	local _,size=model:GetBoundingBox(); model:ScaleTo(5/math.max(size.X,size.Y,size.Z,1))
	local visibility={}
	for _,object in model:GetDescendants() do if object:IsA("BasePart") then visibility[object]=object.Transparency; object.Transparency=1 end end
	scene.reward=model; scene.rewardVisibility=visibility
end
local function buildStage(scene,data)
	local gui=make("ScreenGui",{Name="ZoChestCutscene",IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=100,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},scene.player:WaitForChild("PlayerGui"))
	scene.gui=gui
	local backdrop=make("Frame",{Active=true,BackgroundColor3=Color3.fromRGB(5,12,29),BorderSizePixel=0,Size=UDim2.fromScale(1,1)},gui)
	local view=make("ViewportFrame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(9,19,43),BorderSizePixel=0,Ambient=Color3.fromRGB(185,193,217),LightColor=Color3.fromRGB(255,228,181),LightDirection=Vector3.new(-0.7,-1,-0.4)},backdrop)
	scene.view=view
	scene.world=make("WorldModel",{},view)
	scene.camera=make("Camera",{FieldOfView=43},view); view.CurrentCamera=scene.camera
	local floor=part(scene.world,"CinematicStage",Vector3.new(70,1,70),CFrame.new(0,-0.6,0),Color3.fromRGB(15,33,57)); floor.Material=Enum.Material.Marble
	local accent=if data.trap then Color3.fromRGB(245,91,117) else colors[math.clamp(scene.plan.rank,1,4)]
	for i=1,40 do
		local angle=i*math.pi/20
		local glow=part(scene.world,"StageRing",Vector3.new(0.65,0.12,1.2),CFrame.new(math.cos(angle)*7,0.05,math.sin(angle)*7)*CFrame.Angles(0,-angle,0),accent)
		glow.Material=Enum.Material.Neon
	end
	scene.chest=make("Model",{Name="CinematicChest"},scene.world)
	local wood=Color3.fromRGB(167,94,43); local gold=colors[2]
	local body=part(scene.chest,"ChestBody",Vector3.new(8,4.8,6),CFrame.new(0,2.4,0),wood); body.Material=Enum.Material.WoodPlanks; scene.chest.PrimaryPart=body
	for _,x in {-2.6,2.6} do part(scene.chest,"GoldBand",Vector3.new(0.4,4.9,6.1),CFrame.new(x,2.4,0),gold).Material=Enum.Material.Metal end
	part(scene.chest,"ChestLock",Vector3.new(1.1,1.3,0.45),CFrame.new(0,4,-3.2),gold)
	scene.lid=make("Model",{Name="OpeningLid"},scene.chest)
	local hinge=part(scene.lid,"LidHinge",Vector3.one*0.1,CFrame.new(0,4.8,3),wood); hinge.Transparency=1; scene.lid.PrimaryPart=hinge
	part(scene.lid,"Lid",Vector3.new(8.3,0.9,6.3),CFrame.new(0,5.25,0),wood).Material=Enum.Material.WoodPlanks
	for _,x in {-2.6,2.6} do part(scene.lid,"LidBand",Vector3.new(0.4,1,6.4),CFrame.new(x,5.25,0),gold).Material=Enum.Material.Metal end
	buildReward(scene,data)
	make("Frame",{BackgroundColor3=Color3.new(),BorderSizePixel=0,Size=UDim2.new(1,0,0.105,0),ZIndex=3},backdrop)
	make("Frame",{BackgroundColor3=Color3.new(),BorderSizePixel=0,Position=UDim2.fromScale(0,0.77),Size=UDim2.fromScale(1,0.23),ZIndex=3},backdrop)
	scene.title=text(backdrop,"A MYSTERY AWAITS…",28,UDim2.fromScale(0.1,0.015),UDim2.fromScale(0.8,0.075),accent)
	scene.caption=text(backdrop,"Opening your surprise chest",18,UDim2.fromScale(0.08,0.79),UDim2.fromScale(0.84,0.07))
	scene.message=text(backdrop,"",14,UDim2.fromScale(0.08,0.86),UDim2.fromScale(0.84,0.075))
	scene.message.TextScaled=true; make("UITextSizeConstraint",{MinTextSize=10,MaxTextSize=14},scene.message)
	local skip=make("TextButton",{Name="SkipChestScene",Text="SKIP  •  Space / Esc",Font=Enum.Font.GothamBold,TextSize=13,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(28,52,77),BorderSizePixel=0,AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-18,1,-10),Size=UDim2.fromOffset(185,32),ZIndex=6,Modal=true,Selectable=true},backdrop)
	make("UICorner",{CornerRadius=UDim.new(0,9)},skip)
	scene.skip=skip
	local track=make("Frame",{BackgroundColor3=Color3.fromRGB(33,54,78),BorderSizePixel=0,Size=UDim2.new(1,0,0,3),Position=UDim2.new(0,0,1,-3),ZIndex=6},backdrop)
	scene.progress=make("Frame",{BackgroundColor3=accent,BorderSizePixel=0,Size=UDim2.fromScale(0,1)},track)
	scene.accent=accent
end
function Cutscene.new(player,onActive)
	return setmetatable({player=player,onActive=onActive,active=nil,serial=0},Cutscene)
end
function Cutscene:finish(scene)
	if self.active~=scene then return end
	if not scene.data.trap and not scene.chimed then scene.chimed=true; RewardAudio.play() end
	self.active=nil
	RunService:UnbindFromRenderStep(scene.binding)
	for _,connection in scene.connections do connection:Disconnect() end
	for _,animation in scene.tweens do animation:Cancel() end
	if scene.controls and scene.restoreControls then pcall(function() scene.controls:Enable() end) end
	if scene.gui then scene.gui:Destroy() end
	self.onActive(false,scene.data)
end
function Cutscene:celebrate(scene)
	local plan=scene.plan; local random=Random.new()
	for i=1,plan.confetti do
		local p=part(scene.world,"CinematicConfetti",Vector3.new(0.18,0.5,0.16),CFrame.new(0,5,0),if plan.trap then scene.accent else colors[(i-1)%4+1]); p.Material=Enum.Material.Neon
		tween(scene,p,2.3,{Position=Vector3.new(random:NextNumber(-8,8),random:NextNumber(6,14),random:NextNumber(-5,5)),Transparency=1,Orientation=Vector3.new(120,i*29,90)})
	end
	for i=1,plan.balloons do
		local home=Vector3.new((i-(plan.balloons+1)/2)*2,2,3)
		local balloon=part(scene.world,"PrizeBalloon",Vector3.new(1.3,1.7,1.3),CFrame.new(home),colors[(i-1)%4+1],Enum.PartType.Ball)
		local string=part(scene.world,"BalloonString",Vector3.new(0.04,2.4,0.04),CFrame.new(home-Vector3.new(0,2,0)),Color3.new(1,1,1))
		for _,p in {balloon,string} do tween(scene,p,3.3,{Position=p.Position+Vector3.new(0,12,0),Transparency=1}) end
	end
	for burst=1,plan.fireworks do
		task.delay(burst*0.35,function()
			if self.active~=scene then return end
			local center=Vector3.new((burst-2)*4,9+burst,5)
			for ray=1,20 do
				local angle=ray*math.pi/10; local direction=Vector3.new(math.cos(angle),math.sin(angle),0.1).Unit
				local spark=part(scene.world,"PrizeFirework",Vector3.new(0.12,0.12,1.1),CFrame.lookAt(center,center+direction),colors[(ray-1)%4+1]); spark.Material=Enum.Material.Neon
				tween(scene,spark,1.3,{CFrame=spark.CFrame+direction*(4+plan.rank*0.45),Transparency=1})
			end
		end)
	end
end
function Cutscene:frame(scene)
	local elapsed=os.clock()-scene.started; local plan=scene.plan
	if elapsed>=plan.duration then self:finish(scene); return end
	local push=math.clamp(elapsed/plan.revealAt,0,1); local ease=1-(1-push)^3
	local orbit=math.max(0,elapsed-plan.revealAt)*0.18
	local aspect=scene.view.AbsoluteSize.X/math.max(1,scene.view.AbsoluteSize.Y)
	local distance=(20-ease*7)*math.max(1,1/math.max(0.25,aspect))
	local eye=Vector3.new(math.sin(0.45+orbit)*distance,8-ease*1.2,-math.cos(0.45+orbit)*distance)
	scene.camera.CFrame=CFrame.lookAt(eye,Vector3.new(0,3.8+ease,0))
	local shake=if elapsed<plan.openAt then math.sin(elapsed*45)*0.025*(elapsed/plan.openAt) else 0
	scene.chest:PivotTo(CFrame.new(0,2.4,0)*CFrame.Angles(0,0,shake))
	local opening=math.clamp((elapsed-plan.openAt)/0.6,0,1)
	scene.lid:PivotTo(scene.chest:GetPivot()*CFrame.new(0,2.4,3)*CFrame.Angles(math.rad(108)*(1-(1-opening)^3),0,0))
	scene.reward:PivotTo(CFrame.new(0,6.8+math.sin(elapsed*2)*0.22,0)*CFrame.Angles(0,elapsed*0.55,0))
	scene.progress.Size=UDim2.fromScale(math.clamp(elapsed/plan.duration,0,1),1)
	if elapsed>=plan.revealAt and not scene.revealed then
		scene.revealed=true
		if not scene.data.trap and not scene.chimed then scene.chimed=true; RewardAudio.play() end
		for p,transparency in scene.rewardVisibility do p.Transparency=transparency end
		scene.title.Text=if scene.data.trap then "TRAP REVEALED!" elseif plan.rank>=5 then "LEGENDARY DISCOVERY!" elseif plan.rank>=3 then "SPECIAL DISCOVERY!" else "TREASURE REVEALED!"
		scene.caption.Text=scene.data.title or "Your chest reward"
		scene.message.Text=scene.data.message or "Your journal has been updated."
		self:celebrate(scene)
	end
end
function Cutscene:play(data)
	if self.active then self:finish(self.active) end
	self.serial+=1
	local scene={player=self.player,data=data,plan=Plans.plan(data.rank or 0,data.trap==true),started=os.clock(),connections={},tweens={},binding="ZoChestScene_"..self.serial}
	self.active=scene
	local ok,problem=xpcall(function()
		buildStage(scene,data)
		self.onActive(true,data)
		local module=self.player.PlayerScripts:FindFirstChild("PlayerModule")
		if module then
			local loaded,controls=pcall(function() return require(module):GetControls() end)
			if loaded and controls then scene.controls=controls; scene.restoreControls=controls.controlsEnabled~=false; controls:Disable() end
		end
		table.insert(scene.connections,scene.skip.Activated:Connect(function() self:finish(scene) end))
		table.insert(scene.connections,UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode==Enum.KeyCode.Space or input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB then self:finish(scene) end
		end))
		table.insert(scene.connections,GuiService.MenuOpened:Connect(function() self:finish(scene) end))
		table.insert(scene.connections,self.player.CharacterAdded:Connect(function() self:finish(scene) end))
		local humanoid=self.player.Character and self.player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local health=humanoid.Health
			table.insert(scene.connections,humanoid.HealthChanged:Connect(function(nextHealth) if nextHealth<health and not data.trap then self:finish(scene) end; health=nextHealth end))
		end
		RunService:BindToRenderStep(scene.binding,Enum.RenderPriority.Input.Value+1,function()
			if self.active~=scene then return end
			local activeHumanoid=self.player.Character and self.player.Character:FindFirstChildOfClass("Humanoid")
			if activeHumanoid then activeHumanoid:Move(Vector3.zero,true); activeHumanoid.Jump=false end
			local rendered,renderProblem=pcall(function() self:frame(scene) end)
			if not rendered then warn("[Zo's Ark] Chest scene stopped:",renderProblem); self:finish(scene) end
		end)
		-- A separate deadline also restores input if a render callback stops.
		task.delay(scene.plan.duration+0.5,function() if self.active==scene then self:finish(scene) end end)
	end,debug.traceback)
	if not ok then warn("[Zo's Ark] Chest scene failed:",problem); self:finish(scene) end
end
return Cutscene
