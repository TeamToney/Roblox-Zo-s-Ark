--!strict
local Forestry={MaxTrees=160,MaxGround=180}
export type Plant={x: number,y: number,kind: string,scale: number,yaw: number,tint: number}
type Candidate={x: number,y: number,habitat: string,rank: number}
local habitats={meadow=true,jungle=true,summit=true} :: {[string]: boolean}
local function noise(x: number,y: number,seed: number): number
	local n=math.sin(x*12.9898+y*78.233+seed*37.719)*43758.5453
	return n-math.floor(n)
end
local function inside(Geometry: any,room: any,x: number,y: number,margin: number): boolean
	if room.rect then return Geometry.contains(room.rect,x,y,-margin) end
	local spans=Geometry.scanline(room.polygon,y)
	for i=1,#spans,2 do if x>=spans[i]-margin and x<=spans[i+1]+margin then return true end end
	for _,edge in Geometry.walls(room) do if Geometry.distanceToSegment(x,y,edge)<margin then return true end end
	return false
end
function Forestry.prepare(plan: any,Geometry: any): any
	local source=plan.Source; local scale=source.scale
	local paths: {{number}}={}; local protected: {{number}}={}; local walls: {{number}}={}; local lanes: {{number}}={}
	for _,rect in plan.Corridors do table.insert(paths,rect) end
	for _,name in {"Dock","DockRamp","SwimSteps"} do
		local rect=plan[name]; if rect and rect[1] then table.insert(paths,rect) end
	end
	for _,name in {"ShoreExits","Checkpoints","Chests"} do
		for _,marker in plan[name] or {} do table.insert(protected,{marker.x,marker.y,if name=="ShoreExits" then 19 else 15}) end
	end
	for _,name in {"Spawn","Hub"} do
		local point=plan[name]; if point then table.insert(protected,{point[1],point[2],28}) end
	end
	for _,room in plan.Rooms do
		for _,edge in Geometry.walls(room) do table.insert(walls,edge) end
		if habitats[room.kind] and room.rect then
			local r=room.rect; local cx,cy=Geometry.center(r)
			for _,door in room.doors do
				local x=if door.side=="east" then r[3] elseif door.side=="west" then r[1] else door.center
				local y=if door.side=="north" then r[2] elseif door.side=="south" then r[4] else door.center
				table.insert(lanes,{x,y,cx,cy})
			end
		end
	end
	local api={}
	function api.site(x: number,y: number,radius: number): string?
		local inset=radius/scale
		for _,offset in {{0,0},{inset,0},{-inset,0},{0,inset},{0,-inset},{inset,inset},{-inset,inset},{inset,-inset},{-inset,-inset}} do
			if Geometry.inWater(plan,x+offset[1],y+offset[2]) then return nil end
		end
		for _,rect in paths do if Geometry.contains(rect,x,y,-(radius+3)/scale) then return nil end end
		for _,point in protected do if ((x-point[1])^2+(y-point[2])^2)*scale^2<(point[3]+radius)^2 then return nil end end
		for _,line in walls do if Geometry.distanceToSegment(x,y,line)*scale<radius+1 then return nil end end
		for _,line in lanes do if Geometry.distanceToSegment(x,y,line)*scale<radius+5 then return nil end end
		local habitat=nil
		for _,room in plan.Rooms do
			if inside(Geometry,room,x,y,inset) then
				if not habitats[room.kind] then return nil end
				habitat=room.kind
			end
		end
		for _,court in plan.Courtyards do if Geometry.contains(court.rect,x,y) then habitat=court.habitat end end
		-- Animal gathering areas stay open, with vegetation around their edges.
		for _,zone in plan.Zones do
			if zone.habitat~="reef" and zone.habitat~="ocean" and Geometry.contains(zone.rect,x,y) then
				local cx,cy=Geometry.center(zone.rect)
				local clearing=math.min(18,math.min(zone.rect[3]-zone.rect[1],zone.rect[4]-zone.rect[2])*scale*0.23)
				if ((x-cx)^2+(y-cy)^2)*scale^2<(clearing+radius)^2 then return nil end
				habitat=zone.habitat
			end
		end
		return habitat or "outside"
	end
	return api
end
function Forestry.generate(plan: any,Geometry: any): {trees: {Plant},ground: {Plant}}
	local site=Forestry.prepare(plan,Geometry)
	local source=plan.Source; local s=source.scale
	local seed=if plan.Id=="canopy" then 23 elseif plan.Id=="moonstone" then 47 else 11
	local trees: {Plant}={}; local ground: {Plant}={}
	local candidates: {Candidate}={}
	local spacing=20/s
	for y=plan.Bounds[2]+spacing/2,plan.Bounds[4]-spacing/2,spacing do
		for x=plan.Bounds[1]+spacing/2,plan.Bounds[3]-spacing/2,spacing do
			local px=x+(noise(x,y,seed)-0.5)*spacing*0.55
			local py=y+(noise(y,x,seed+1)-0.5)*spacing*0.55
			local habitat=site.site(px,py,5)
			if not habitat then continue end
			local rank=noise(x,y,seed+2)
			-- Small thickets alternate with open lawns, rather than uniform rows.
			if habitat=="outside" and math.sin(px*0.018+seed)+math.cos(py*0.022)<-0.25 then continue end
			table.insert(candidates,{x=px,y=py,habitat=habitat,rank=rank})
		end
	end
	table.sort(candidates,function(a: Candidate,b: Candidate) return a.rank>b.rank end)
	for _,candidate in candidates do
		if #trees>=Forestry.MaxTrees then break end
		local x,y=candidate.x,candidate.y
		local spaced=true
		for _,tree in trees do if ((x-tree.x)^2+(y-tree.y)^2)*s*s<14^2 then spaced=false; break end end
		if not spaced then continue end
		local value=noise(x,y,seed+3)
		local kind=if candidate.habitat=="summit" then "pine"
			elseif candidate.habitat=="jungle" or plan.Id=="canopy" then (if value<0.22 then "palm" else "broadleaf")
			elseif plan.Id=="moonstone" then (if value<0.5 then "pine" else "birch")
			else (if value<0.2 then "birch" else "broadleaf")
		table.insert(trees,{x=x,y=y,kind=kind,scale=0.8+noise(x,y,seed+4)*0.45,yaw=value*math.pi*2,tint=noise(x,y,seed+5)})
	end
	-- Low undergrowth is grouped around trees, with the same access exclusions.
	for index,tree in trees do
		for offset=1,2 do
			if #ground>=Forestry.MaxGround then break end
			local angle=tree.yaw+offset*2.4
			local x,y=tree.x+math.cos(angle)*8/s,tree.y+math.sin(angle)*8/s
			if not site.site(x,y,2.5) then continue end
			local kind=if index%19==0 and offset==1 then "log" elseif (index+offset)%11==0 then "rock" elseif (index+offset)%4==0 then "flowers" else "fern"
			table.insert(ground,{x=x,y=y,kind=kind,scale=0.8+tree.tint*0.4,yaw=angle,tint=tree.tint})
		end
	end
	return {trees=trees,ground=ground}
end
return Forestry
