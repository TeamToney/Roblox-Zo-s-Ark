--!nonstrict
local SoundService=game:GetService("SoundService")
local Debris=game:GetService("Debris")
local RewardAudio={}
local group=Instance.new("SoundGroup"); group.Name="ZoRewardChimes"; group.Volume=0.7; group.Parent=SoundService
-- Roblox's bundled bell avoids a private Creator Store audio dependency.
local template=Instance.new("Sound"); template.Name="RewardBell"; template.SoundId="rbxasset://sounds/electronicpingshort.wav"; template.SoundGroup=group
local nextAt=0
function RewardAudio.play()
	local now=os.clock()
	local start=math.max(now,nextAt); nextAt=start+0.22
	for index,pitch in {1.15,1.65} do
		task.delay(start-now+(index-1)*0.13,function()
			local sound=template:Clone(); sound.PlaybackSpeed=pitch; sound.Volume=if index==1 then 0.55 else 0.65; sound.Parent=SoundService
			sound:Play(); Debris:AddItem(sound,3)
		end)
	end
end
return RewardAudio
