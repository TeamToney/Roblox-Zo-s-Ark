--!nonstrict
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("ZoShared")
local Catalog=require(Shared.Catalog)
local Shapes=require(Shared.ItemShapes)
local ShopView={category="All"}
local function preview(frame,id,kind,make)
	local view=make("ViewportFrame",{Size=UDim2.fromOffset(86,100),Position=UDim2.fromOffset(10,10),BackgroundColor3=Color3.fromRGB(42,70,75),BorderSizePixel=0,Ambient=Color3.fromRGB(200,210,205),LightColor=Color3.fromRGB(255,239,207),LightDirection=Vector3.new(-1,-1,-1)},frame)
	make("UICorner",{CornerRadius=UDim.new(0,10)},view)
	local world=make("WorldModel",{},view)
	for _, spec in Shapes.build(id,kind) do
		make("Part",{Size=Vector3.new(unpack(spec.size)),CFrame=CFrame.new(unpack(spec.at)),Color=Color3.fromRGB(unpack(spec.color)),Anchored=true,CanCollide=false,Shape=if spec.shape=="ball" then Enum.PartType.Ball else Enum.PartType.Block,Material=Enum.Material.SmoothPlastic},world)
	end
	local camera=make("Camera",{CFrame=CFrame.lookAt(Vector3.new(5,3.5,-8),Vector3.new(0,0.4,0)),FieldOfView=38},view); view.CurrentCamera=camera
end
function ShopView.render(ctx)
	local s,p,card,text,button,make=ctx.state,ctx.palette,ctx.card,ctx.text,ctx.button,ctx.make
	local summary=card(64)
	text(summary,"YOUR EXPEDITION KIT",12,p.mint,UDim2.fromOffset(14,6),UDim2.new(1,-28,0,24),true)
	text(summary,"Tier "..s.tier.." rescue gear • "..s.capacity.." pack slots • "..s.profile.bait.." calming bait",12,p.cream,UDim2.fromOffset(14,30),UDim2.new(1,-28,0,28))
	local filters=card(84)
	for i,category in Catalog.Categories do
		button(filters,category,UDim2.new(((i-1)%3)/3,5,0,5+math.floor((i-1)/3)*38),UDim2.new(1/3,-10,0,32),function() ShopView.category=category; ctx.refresh() end,ShopView.category~=category)
	end
	for _, id in Catalog.ItemOrder do
		local item=Catalog.Items[id]
		if ShopView.category~="All" and item.category~=ShopView.category then continue end
		local owned=s.profile.owned[id]==true and item.kind~="consumable" and item.kind~="supply"
		local f=card(218); preview(f,id,item.kind,make)
		text(f,item.category:upper(),10,p.mint,UDim2.fromOffset(108,8),UDim2.new(1,-120,0,20),true)
		text(f,item.name,16,p.cream,UDim2.fromOffset(108,29),UDim2.new(1,-120,0,44),true)
		text(f,item.description,12,p.muted,UDim2.fromOffset(108,76),UDim2.new(1,-120,0,74))
		text(f,if owned then "OWNED" elseif item.stock then "IN KIT: "..(s.profile.stock[item.stock] or 0) else "EXPEDITION ESSENTIAL",10,p.gold,UDim2.fromOffset(12,119),UDim2.fromOffset(94,34),true)
		if owned then
			local style=item.kind=="cosmetic"; local equipped=style and s.profile.wardrobe[item.slot]==id
			button(f,if style then (if equipped then "Remove cosmetic" else "Equip cosmetic") else "Active in your kit",UDim2.new(0,12,1,-50),UDim2.new(1,-24,0,36),function() if style then ctx.send("equip",id) end end,not style)
		else
			local coins=button(f,item.price.." coins",UDim2.new(0,12,1,-50),UDim2.new(0.5,-18,0,36),function() if s.atShop and s.profile.coins>=item.price then ctx.send("buy",id,nil,"coins") end end,not s.atShop or s.profile.coins<item.price)
			local pts=button(f,item.pointsPrice.." pts",UDim2.new(0.5,6,1,-50),UDim2.new(0.5,-18,0,36),function() if s.atShop and s.profile.points>=item.pointsPrice then ctx.send("buy",id,nil,"points") end end,not s.atShop or s.profile.points<item.pointsPrice)
			coins.TextSize=12; pts.TextSize=12
		end
	end
	if ShopView.category=="All" or ShopView.category=="Boosts" or ShopView.category=="Style" then
		local heading=card(78); text(heading,"ROBUX COLLECTION",16,p.gold,UDim2.fromOffset(14,8),UDim2.new(1,-28,0,28),true)
		text(heading,"Guaranteed bundles. Roblox shows the final price before purchase.",12,p.muted,UDim2.fromOffset(14,36),UDim2.new(1,-28,0,34))
		for _, id in Catalog.ProductOrder do
			local product,offer=Catalog.Products[id],s.offers[id]
			local display=product.display or product.stock or "safariHat"
			local f=card(210); preview(f,display,Catalog.Items[display].kind,make)
			text(f,product.name,16,p.cream,UDim2.fromOffset(108,9),UDim2.new(1,-120,0,43),true)
			text(f,product.description,12,p.muted,UDim2.fromOffset(108,54),UDim2.new(1,-120,0,100))
			local enabled=offer and s.atShop and not s.temporary
			button(f,if offer then "R$ "..offer.price else "Coming soon",UDim2.new(0,12,1,-50),UDim2.new(1,-24,0,36),function() if enabled then ctx.send("robux",id) end end,not enabled)
		end
	end
end
function ShopView.kit(ctx)
	local s,p=ctx.state,ctx.palette
	for _, id in {"speedBoost","animalTrap","tracker"} do
		local item=Catalog.Items[id]; local f=ctx.card(174); preview(f,id,item.kind,ctx.make)
		local count=if item.stock then s.profile.stock[id] or 0 else (if s.profile.owned[id] then 1 else 0)
		ctx.text(f,item.name,16,p.cream,UDim2.fromOffset(108,9),UDim2.new(1,-120,0,42),true)
		ctx.text(f,item.description,12,p.muted,UDim2.fromOffset(108,50),UDim2.new(1,-120,0,70))
		ctx.button(f,(if id=="animalTrap" then "Place" elseif id=="tracker" then "Scan" else "Activate").."  •  "..count,UDim2.new(0,12,1,-46),UDim2.new(1,-24,0,34),function() if count>0 then ctx.send("use",id) end end,count<=0)
	end
	for _, id in {"safariHat","mintTrail"} do
		local item=Catalog.Items[id]; local f=ctx.card(128); preview(f,id,item.kind,ctx.make)
		ctx.text(f,item.name,16,p.cream,UDim2.fromOffset(108,9),UDim2.new(1,-120,0,42),true)
		local owned=s.profile.owned[id]; local equipped=s.profile.wardrobe[item.slot]==id
		ctx.button(f,if not owned then "Visit Outfitters" elseif equipped then "Remove" else "Equip",UDim2.new(0,108,1,-58),UDim2.new(1,-120,0,42),function() if owned then ctx.send("equip",id) end end,not owned)
	end
end
return ShopView
