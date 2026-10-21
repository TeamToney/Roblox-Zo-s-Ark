--!nonstrict
local SoundService=game:GetService("SoundService")
local ContentProvider=game:GetService("ContentProvider")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("ZoShared")
local Catalog=require(Shared.MusicCatalog)
local Rules=require(Shared.MusicRules)
local MusicPlayer={}; MusicPlayer.__index=MusicPlayer
local function make(class,name,parent)
	local object=Instance.new(class); object.Name=name; object.Parent=parent; return object
end
function MusicPlayer.new(remote,onChanged)
	local self=setmetatable({remote=remote,onChanged=onChanged,enabled=true,style="lofi",volume=0.25,ducked=false,serial=0,index=0,playlists={},failed={},phase="loading",message="Tuning the radio…"},MusicPlayer)
	self.group=make("SoundGroup","ZoBackgroundMusic",SoundService); self.group.Volume=self.volume
	self.folder=make("Folder","ZoMusicTracks",SoundService)
	local elapsed=0
	self.connection=RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt; if elapsed<0.2 then return end; elapsed=0
		local progress=self.progress
		if not progress or not progress.label.Parent then return end
		local sound=self.sound
		local position=if sound and sound.IsPlaying then sound.TimePosition else 0
		local length=if sound and sound.TimeLength>0 then sound.TimeLength else 0
		local function time(value) return string.format("%d:%02d",math.floor(value/60),math.floor(value)%60) end
		progress.label.Text=if self.phase=="playing" then time(position).." / "..time(length) else self.message
		progress.fill.Size=UDim2.fromScale(if length>0 then math.clamp(position/length,0,1) else 0,1)
	end)
	task.defer(function() self:load() end)
	return self
end
function MusicPlayer:_volume()
	if self.volumeTween then self.volumeTween:Cancel() end
	local volume=if self.enabled then self.volume*(if self.ducked then 0.25 else 1) else 0
	self.volumeTween=TweenService:Create(self.group,TweenInfo.new(0.25),{Volume=volume}); self.volumeTween:Play()
end
function MusicPlayer:setDucked(ducked)
	self.ducked=ducked; self:_volume()
end
function MusicPlayer:setVolume(value)
	self.volume=Rules.volume(value); self:_volume(); self.onChanged()
end
function MusicPlayer:_stop(fade)
	if self.ended then self.ended:Disconnect(); self.ended=nil end
	if self.loaded then self.loaded:Disconnect(); self.loaded=nil end
	local sound=self.sound; self.sound=nil
	if not sound then return end
	if fade and sound.IsPlaying then
		TweenService:Create(sound,TweenInfo.new(0.2),{Volume=0}):Play()
		task.delay(0.22,function() sound:Destroy() end)
	else sound:Stop(); sound:Destroy() end
end
function MusicPlayer:_unavailable(message)
	self.serial+=1; self.enabled=false; self.phase="unavailable"; self.message=message
	self:_stop(false); self:_volume(); self.onChanged()
end
function MusicPlayer:toggle()
	if self.enabled then
		self.enabled=false; self.serial+=1; self.phase="off"; self.message="Music is off. World sounds stay on."
		if self.volumeTween then self.volumeTween:Cancel() end
		self.group.Volume=0; self:_stop(false)
		for _,sound in self.folder:GetChildren() do sound:Destroy() end
		self.onChanged()
	else
		self.enabled=true; self:_volume()
		local tracks=self.playlists[self.style]
		if tracks and self.index>0 and not self.failed[tracks[self.index].id] then self:playIndex(self.index) else self:load() end
	end
end
function MusicPlayer:selectStyle(style)
	if not Catalog.Styles[style] or (self.style==style and self.enabled) then return end
	self.style=style; self.index=0; self.failed={}; self.enabled=true; self:_volume(); self:load()
end
function MusicPlayer:load()
	self.serial+=1; local serial=self.serial; local style=self.style
	self:_stop(true); self.phase="loading"; self.message="Tuning "..Catalog.Styles[style].name.."…"; self.onChanged()
	local cached=self.playlists[style]
	if cached then self:advance(1); return end
	-- Late remote replies may fill the cache, but never resume muted music or
	-- replace a more recently selected style. No notebook request lock is used.
	task.delay(28,function()
		if Rules.current(self.serial,serial,self.enabled) then self:_unavailable("The music library is taking too long. Try another style or Retry.") end
	end)
	task.spawn(function()
		for attempt=1,3 do
			if not Rules.current(self.serial,serial,self.enabled) then return end
			local ok,result=pcall(function() return self.remote:InvokeServer(style) end)
			local tracks=if ok and type(result)=="table" and result.ok then Rules.tracks(result.tracks,Catalog.MaxTracks) else {}
			if #tracks>0 then self.playlists[style]=tracks end
			if not Rules.current(self.serial,serial,self.enabled) then return end
			if #tracks>0 then self:advance(1); return end
			local waitFor=if ok and type(result)=="table" then tonumber(result.retryAfter) else nil
			if attempt<3 and waitFor and waitFor>0 and waitFor<=Catalog.SearchInterval then task.wait(waitFor+0.1)
			else self:_unavailable("This playlist is temporarily unavailable. Try another style or Retry."); return end
		end
	end)
end
function MusicPlayer:retry()
	self.enabled=true; self.failed={}; self.index=0; self.playlists[self.style]=nil; self:_volume(); self:load()
end
function MusicPlayer:advance(direction)
	local tracks=self.playlists[self.style] or {}
	local index=Rules.nextIndex(tracks,self.index,direction,self.failed)
	if not index then self:_unavailable("No playable tracks in this playlist right now. Try another style or Retry."); return end
	self:playIndex(index)
end
function MusicPlayer:playIndex(index)
	local tracks=self.playlists[self.style]; local track=tracks and tracks[index]
	if not track then return end
	self.enabled=true; self.serial+=1; local serial=self.serial
	self:_stop(true); self:_volume(); self.index=index; self.phase="loading"; self.message="Loading "..track.title.."…"; self.onChanged()
	local sound=make("Sound","BackgroundTrack",self.folder)
	sound.SoundGroup=self.group; sound.SoundId="rbxassetid://"..string.format("%.0f",track.id); sound.Looped=false; sound.Volume=0
	self.sound=sound
	local function failed()
		if not Rules.current(self.serial,serial,self.enabled) then return end
		self.failed[track.id]=true; self:advance(1)
	end
	local function ready()
		if not Rules.current(self.serial,serial,self.enabled) or self.phase~="loading" or not sound.IsLoaded then return end
		self.phase="playing"; self.message="Now playing"; sound:Play()
		TweenService:Create(sound,TweenInfo.new(0.6),{Volume=0.65}):Play(); self.onChanged()
	end
	self.ended=sound.Ended:Connect(function() if Rules.current(self.serial,serial,self.enabled) then self:advance(1) end end)
	self.loaded=sound.Loaded:Connect(ready)
	task.delay(12,function() if self.phase=="loading" then failed() end end)
	task.spawn(function()
		local ok=pcall(function() ContentProvider:PreloadAsync({sound}) end)
		if not Rules.current(self.serial,serial,self.enabled) then return end
		if self.phase=="playing" then return end -- Loaded may have already started it.
		if ok and sound.IsLoaded then ready() else failed() end
	end)
end
function MusicPlayer:destroy()
	self.serial+=1; self.enabled=false; self:_stop(false)
	if self.volumeTween then self.volumeTween:Cancel() end
	self.connection:Disconnect(); self.folder:Destroy(); self.group:Destroy()
end
return MusicPlayer
