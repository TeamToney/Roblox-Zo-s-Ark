--!nonstrict
local Catalog=require(game:GetService("ReplicatedStorage"):WaitForChild("ZoShared").MusicCatalog)
local MusicView={}
function MusicView.render(player,ctx)
	local p,card,text,button,make=ctx.palette,ctx.card,ctx.text,ctx.button,ctx.make
	local tracks=player.playlists[player.style] or {}
	local track=tracks[player.index]
	local now=card(144)
	text(now,Catalog.Styles[player.style].name:upper().."  /  "..(if player.enabled then "RADIO ON" else "RADIO OFF"),12,p.mint,UDim2.fromOffset(14,8),UDim2.new(1,-28,0,23),true)
	text(now,if track then track.title else "Choose your expedition soundtrack",19,p.cream,UDim2.fromOffset(14,34),UDim2.new(1,-28,0,45),true)
	text(now,if track then track.artist else "Your music and volume are personal to you.",12,p.muted,UDim2.fromOffset(14,80),UDim2.new(1,-28,0,23))
	local status=text(now,player.message,11,p.mint,UDim2.fromOffset(14,106),UDim2.new(1,-28,0,26))
	local bar=make("Frame",{BackgroundColor3=p.soft,BorderSizePixel=0,Position=UDim2.new(0,14,1,-6),Size=UDim2.new(1,-28,0,3)},now)
	local fill=make("Frame",{BackgroundColor3=p.mint,BorderSizePixel=0,Size=UDim2.fromScale(0,1)},bar)
	player.progress={label=status,fill=fill}
	local transport=card(56)
	for i,entry in {{"◀ Prev",function() player:advance(-1) end},{if player.enabled then "Music OFF" else "Music ON",function() player:toggle() end},{"Next ▶",function() player:advance(1) end},{"Retry",function() player:retry() end}} do
		local b=button(transport,entry[1],UDim2.new((i-1)/4,5,0,8),UDim2.new(0.25,-10,0,40),entry[2],i~=2)
		b.TextSize=12
	end
	local volume=card(56)
	text(volume,"VOLUME  "..math.floor(player.volume*100+0.5).."%",12,p.cream,UDim2.fromOffset(14,8),UDim2.new(0.55,-14,0,40),true)
	button(volume,"−",UDim2.new(0.56,0,0,8),UDim2.new(0.2,-7,0,40),function() player:setVolume(player.volume-0.1) end,true)
	button(volume,"+",UDim2.new(0.77,0,0,8),UDim2.new(0.23,-10,0,40),function() player:setVolume(player.volume+0.1) end,true)
	local styles=card(126)
	text(styles,"PICK A STYLE",12,p.mint,UDim2.fromOffset(14,4),UDim2.new(1,-28,0,25),true)
	for i,id in Catalog.Order do
		button(styles,Catalog.Styles[id].name,UDim2.new(((i-1)%3)/3,5,0,32+math.floor((i-1)/3)*44),UDim2.new(1/3,-10,0,38),function() player:selectStyle(id) end,player.style~=id)
	end
	local info=card(68)
	text(info,Catalog.Styles[player.style].description,12,p.muted,UDim2.fromOffset(14,5),UDim2.new(1,-28,0,28))
	text(info,"Playlist repeats automatically • Tracks from Roblox's music library",10,p.mint,UDim2.fromOffset(14,34),UDim2.new(1,-28,0,28))
	for i,entry in tracks do
		local row=card(66)
		button(row,(if i==player.index then "♫  " else tostring(i)..".  ")..entry.title.."\n"..entry.artist,UDim2.fromOffset(8,6),UDim2.new(1,-16,1,-12),function() player.failed[entry.id]=nil; player:playIndex(i) end,i~=player.index)
	end
end
return MusicView
