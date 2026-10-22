--!nonstrict
local RunService=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("ZoShared")
local Rules=require(Shared.NightRules)
local Config=require(Shared.Config)
local Gear={}
function Gear.start(player)
	local lamp=Instance.new("Part"); lamp.Name="ZoPersonalNightLamp"; lamp.Size=Vector3.one*0.1; lamp.Transparency=1
	lamp.Anchored=true; lamp.CanCollide=false; lamp.CanTouch=false; lamp.CanQuery=false; lamp.CastShadow=false; lamp.Parent=workspace
	local beam=Instance.new("SpotLight"); beam.Face=Enum.NormalId.Front; beam.Range=55; beam.Angle=80; beam.Brightness=3; beam.Shadows=true; beam.Color=Color3.fromRGB(255,240,195); beam.Enabled=false; beam.Parent=lamp
	local visionLight=Instance.new("PointLight"); visionLight.Range=60; visionLight.Brightness=1.4; visionLight.Color=Color3.fromRGB(166,255,193); visionLight.Enabled=false; visionLight.Parent=lamp
	local grade=Instance.new("ColorCorrectionEffect"); grade.Name="ZoPersonalNightVision"; grade.Brightness=0.18; grade.Contrast=-0.08; grade.Saturation=-0.2; grade.TintColor=Color3.fromRGB(198,255,212); grade.Enabled=false; grade.Parent=Lighting
	local connection=RunService.RenderStepped:Connect(function()
		local c=player.Character; local h=c and c:FindFirstChildOfClass("Humanoid"); local camera=workspace.CurrentCamera
		local alive=h and h.Health>0 and camera
		local epoch=workspace:GetAttribute("ZoDayEpoch")
		local night=epoch and Rules.cycle(workspace:GetServerTimeNow()-epoch,Config).night
		beam.Enabled=alive and c:GetAttribute("ZoFlashlightOn")==true or false
		grade.Enabled=alive and night and c:GetAttribute("ZoNightVisionOn")==true or false; visionLight.Enabled=grade.Enabled
		if alive and (beam.Enabled or grade.Enabled) then lamp.CFrame=camera.CFrame*CFrame.new(0.65,-0.45,-0.8) end
	end)
	return function() connection:Disconnect(); lamp:Destroy(); grade:Destroy() end
end
return Gear
