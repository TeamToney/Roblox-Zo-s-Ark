--!nonstrict
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("ZoShared")
local Catalog=require(Shared.Catalog)
local Access=require(Shared.TravelRules).new(Catalog)
local Preview=require(script.Parent.ShopView).preview
local TravelView={}
function TravelView.render(ctx)
	local s,p=ctx.state,ctx.palette
	local intro=ctx.card(116)
	ctx.text(intro,"YOUR ISLAND PASSPORT",17,p.mint,UDim2.fromOffset(14,8),UDim2.new(1,-28,0,27),true)
	ctx.text(intro,"Island entry is a permanent unlock. Sail freely after unlocking, or pay for an optional teleport. Passes never unlock islands. Spending points can lower your level.",12,p.cream,UDim2.fromOffset(14,38),UDim2.new(1,-28,0,68))
	for _,id in Catalog.MapOrder do
		local map=Catalog.Maps[id]; local owned=Access.canAccess(s.profile,id)
		local f=ctx.card(290); Preview(f,"mapPass","access",ctx.make)
		ctx.text(f,if owned then "UNLOCKED" else "LOCKED • PERMANENT ENTRY",10,if owned then p.mint else p.gold,UDim2.fromOffset(108,8),UDim2.new(1,-120,0,24),true)
		ctx.text(f,map.name,18,p.cream,UDim2.fromOffset(108,33),UDim2.new(1,-120,0,48),true)
		ctx.text(f,map.description,12,p.muted,UDim2.fromOffset(108,83),UDim2.new(1,-120,0,77))
		ctx.text(f,"Base sightings: Rare "..(map.rare*100).."% • Epic "..(map.epic*100).."% • Legendary "..(map.legendary*100).."%\nPer new habitat spawn; matching species only. Hidden habitats improve odds.",11,p.gold,UDim2.fromOffset(14,166),UDim2.new(1,-28,0,56))
		if not owned then
			ctx.button(f,"Unlock • "..map.price.." coins",UDim2.new(0,12,1,-64),UDim2.new(0.5,-18,0,30),function() ctx.send("unlock",id,nil,"coins") end,s.profile.coins<map.price)
			ctx.button(f,map.pointsPrice.." pts",UDim2.new(0.5,6,1,-64),UDim2.new(0.5,-18,0,30),function() ctx.send("unlock",id,nil,"points") end,s.profile.points<map.pointsPrice)
			local offer=s.offers[map.product]
			ctx.button(f,if offer then "Unlock • R$ "..offer.price else "Robux • Coming soon",UDim2.new(0,12,1,-29),UDim2.new(1,-24,0,24),function() if offer and not s.temporary then ctx.send("robux",map.product) end end,not offer or s.temporary)
		else
			ctx.text(f,"TELEPORT TO LANDING • ONE WAY",10,p.mint,UDim2.fromOffset(14,222),UDim2.new(1,-28,0,18),true)
			for i,currency in {"coins","points","pass"} do
				local count=if currency=="coins" then map.teleportCoins elseif currency=="points" then map.teleportPoints else 1
				local caption=if currency=="pass" then "1 pass" else count..(if currency=="coins" then " coins" else " pts")
				local available=if currency=="pass" then s.profile.stock.teleportPass>=1 else s.profile[currency]>=count
				ctx.button(f,caption,UDim2.new((i-1)/3,8,1,-43),UDim2.new(1/3,-16,0,34),function() if available then ctx.send("teleport",id,nil,currency) end end,not available)
			end
		end
	end
	local f=ctx.card(143); local offer=s.offers.teleportPack
	ctx.text(f,"TELEPORT PASSES • "..s.profile.stock.teleportPass.." IN YOUR KIT",15,p.mint,UDim2.fromOffset(14,8),UDim2.new(1,-28,0,26),true)
	ctx.text(f,"Buy 5 passes with Robux, then choose an unlocked island above. Individual passes are also sold in Outfitters for 80 coins or 50 points.",12,p.muted,UDim2.fromOffset(14,38),UDim2.new(1,-28,0,53))
	ctx.button(f,if offer then "5 passes • R$ "..offer.price else "Robux passes • Coming soon",UDim2.fromOffset(14,102),UDim2.new(1,-28,0,30),function() if offer and not s.temporary then ctx.send("robux","teleportPack") end end,not offer or s.temporary)
end
return TravelView
