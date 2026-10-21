--!nonstrict
local MarketplaceService=game:GetService("MarketplaceService")
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("ZoShared")
local Products=require(Shared.Monetization)
local Receipts=require(Shared.ReceiptRules)
local Commerce={}; Commerce.__index=Commerce
function Commerce.new(catalog,rules,store,getSession,notify)
	local self=setmetatable({offers={},byId={},catalog=catalog},Commerce)
	local invalid={}
	for key,id in Products do
		if type(id)=="number" and id>0 and id%1==0 and catalog.Products[key] then
			if self.byId[id] then invalid[id]=true end; self.byId[id]=key
		end
	end
	for id in invalid do self.byId[id]=nil; warn("[Zo's Ark] Duplicate Developer Product ID disabled:",id) end
	task.spawn(function()
		for id,key in self.byId do
			for attempt=1,3 do
				local ok,info=pcall(function() return MarketplaceService:GetProductInfoAsync(id,Enum.InfoType.Product) end)
				if ok and info.IsForSale~=false and type(info.PriceInRobux)=="number" and info.PriceInRobux>0 then
					self.offers[key]={productId=id,price=info.PriceInRobux}; break
				end
				if attempt<3 then task.wait(3) end
			end
		end
	end)
	MarketplaceService.ProcessReceipt=function(receipt)
		local player=Players:GetPlayerByUserId(receipt.PlayerId)
		if not player or not self.byId[receipt.ProductId] then return Enum.ProductPurchaseDecision.NotProcessedYet end
		-- Roblox can invoke receipts before PlayerAdded finishes loading. It has
		-- no periodic retry, so wait for that load / an in-flight save here.
		local deadline=os.clock()+45
		for attempt=1,3 do
			local session=getSession(player)
			while player.Parent==Players and os.clock()<deadline and (not session or session.saving) do
				task.wait(0.25); session=getSession(player)
			end
			if player.Parent~=Players or not session or session.closed or session.lost or session.temporary or os.clock()>=deadline then break end
			local granted=Receipts.process(session,receipt.PurchaseId,self.byId[receipt.ProductId],rules,function(s) return store:save(s,false) end)
			if granted then
				notify(player,"Robux purchase delivered!","success")
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
			if attempt<3 then task.wait(2) end
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return self
end
return Commerce
