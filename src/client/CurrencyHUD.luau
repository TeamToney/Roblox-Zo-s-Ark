--!nonstrict
local TweenService = game:GetService("TweenService")
local CurrencyHUD = {}; CurrencyHUD.__index = CurrencyHUD
local function format(value)
	local n=tostring(math.abs(math.floor(value)))
	return (if value<0 then "-" else "")..n:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,", "")
end
function CurrencyHUD.new(parent, make)
	local self=setmetatable({rows={},loaded=false},CurrencyHUD)
	self.frame=make("Frame",{Name="FixedCurrencyDisplay",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-8,0,3),Size=UDim2.fromOffset(270,52),BackgroundTransparency=1,ZIndex=20},parent)
	for i,key in {"coins","points"} do
		local color=if key=="coins" then Color3.fromRGB(255,210,49) else Color3.fromRGB(224,113,255)
		local card=make("Frame",{Position=UDim2.new((i-1)/2,3,0,0),Size=UDim2.new(0.5,-6,1,0),BackgroundColor3=Color3.fromRGB(19,60,85),BorderSizePixel=0,ZIndex=21},self.frame)
		make("UICorner",{CornerRadius=UDim.new(0,10)},card)
		local stroke=make("UIStroke",{Color=color,Thickness=1.5,Transparency=0.35},card)
		local icon=make("TextLabel",{Text=if key=="coins" then "$" else "★",Font=Enum.Font.GothamBold,TextSize=21,TextColor3=color,BackgroundTransparency=1,Size=UDim2.fromOffset(26,43),Position=UDim2.fromOffset(3,7),ZIndex=23},card)
		make("TextLabel",{Text=if key=="coins" then "COINS" else "ARK POINTS",Font=Enum.Font.GothamBold,TextSize=9,TextColor3=color,BackgroundTransparency=1,Position=UDim2.fromOffset(30,3),Size=UDim2.new(1,-34,0,15),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=23},card)
		local label=make("TextLabel",{Text="…",Font=Enum.Font.GothamBold,TextSize=20,TextScaled=true,TextColor3=Color3.fromRGB(255,250,228),BackgroundTransparency=1,Position=UDim2.fromOffset(30,19),Size=UDim2.new(1,-36,0,29),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=23},card)
		make("UITextSizeConstraint",{MinTextSize=10,MaxTextSize=20},label)
		local value=make("NumberValue",{Value=0},card); value.Changed:Connect(function(n) label.Text=format(n) end)
		local gain=make("TextLabel",{Text="",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=color,BackgroundTransparency=1,AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-4,0,32),Size=UDim2.fromOffset(90,20),TextXAlignment=Enum.TextXAlignment.Right,ZIndex=25,TextTransparency=1},card)
		self.rows[key]={value=value,label=label,icon=icon,stroke=stroke,gain=gain,color=color,target=nil}
	end
	return self
end
function CurrencyHUD:update(coins,points)
	for key,target in {coins=coins,points=points} do
		local row=self.rows[key]
		if row.target==target then continue end
		if row.tween then row.tween:Cancel() end
		if row.target==nil then row.value.Value=target; row.label.Text=format(target)
		else
			local delta=target-row.target
			row.tween=TweenService:Create(row.value,TweenInfo.new(0.45,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Value=target}); row.tween:Play()
			if row.gainTween then row.gainTween:Cancel() end
			row.gain.Text=(if delta>=0 then "+" else "")..format(delta)
			row.gain.TextColor3=if delta>=0 then Color3.fromRGB(66,255,174) else Color3.fromRGB(255,126,130)
			row.gain.Position=UDim2.new(1,-4,0,32); row.gain.TextTransparency=0
			row.gainTween=TweenService:Create(row.gain,TweenInfo.new(1.2),{Position=UDim2.new(1,-4,0,5),TextTransparency=1}); row.gainTween:Play()
			row.icon.Rotation=-18; TweenService:Create(row.icon,TweenInfo.new(0.45,Enum.EasingStyle.Back),{Rotation=0}):Play()
			row.stroke.Transparency=0; TweenService:Create(row.stroke,TweenInfo.new(0.7),{Transparency=0.35}):Play()
		end
		row.target=target
	end
end
function CurrencyHUD:resize(width)
	self.frame.Size=UDim2.fromOffset(if width<720 then 184 else 270,52)
	-- Reserve desktop space for Roblox's player list, which renders above game UI.
	self.frame.Position=UDim2.new(1,if width>=560 then -200 else -8,0,3)
end
return CurrencyHUD
