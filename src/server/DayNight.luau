--!nonstrict
local Lighting=game:GetService("Lighting")
local RunService=game:GetService("RunService")
local Rules=require(game:GetService("ReplicatedStorage"):WaitForChild("ZoShared").NightRules)
local DayNight={}; DayNight.__index=DayNight
function DayNight.new(world,config)
	local initial=if RunService:IsStudio() and workspace:GetAttribute("ZoPreviewNight")==true then 600 else config.CycleStartPhase
	local epoch=workspace:GetServerTimeNow()-initial
	workspace:SetAttribute("ZoDayEpoch",epoch)
	return setmetatable({world=world,config=config,epoch=epoch},DayNight)
end
function DayNight:state()
	return Rules.cycle(workspace:GetServerTimeNow()-self.epoch,self.config)
end
function DayNight:start()
	local elapsed=1
	self.connection=RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt; if elapsed<0.5 then return end; elapsed=0
		local state=self:state(); local daylight=math.clamp((math.sin((state.hour-6)/12*math.pi)+0.12)/0.6,0,1)
		Lighting.ClockTime=state.hour
		Lighting.Brightness=0.65+daylight*1.85
		Lighting.Ambient=Color3.fromRGB(29,40,66):Lerp(Color3.fromRGB(92,110,128),daylight)
		Lighting.OutdoorAmbient=Color3.fromRGB(40,59,88):Lerp(Color3.fromRGB(153,168,173),daylight)
		Lighting.ExposureCompensation=-0.2+daylight*0.2
		workspace:SetAttribute("ZoNight",state.night)
		if self.lastNight~=nil and self.lastNight~=state.night and self.onChange then self.onChange(state) end
		self.lastNight=state.night
	end)
end
return DayNight
