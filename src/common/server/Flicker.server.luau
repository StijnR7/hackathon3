-- Laat lampen flikkeren: parts met tag "Flicker" en één of meer Lights (Point/Surface/Spot) erin.
local CollectionService = game:GetService("CollectionService")

local function flicker(part)
	local lights = {}
	for _, child in part:GetChildren() do
		if child:IsA("Light") then
			lights[child] = child.Brightness
		end
	end
	if next(lights) == nil then return end
	local baseTransparency = part.Transparency
	local rng = Random.new()

	local function set(factor, transparency)
		for l, base in lights do
			l.Brightness = base * factor
		end
		part.Transparency = transparency
	end

	while part.Parent do
		task.wait(rng:NextNumber(0.5, 4))
		for _ = 1, rng:NextInteger(1, 4) do
			set(rng:NextNumber(0, 0.3), math.max(baseTransparency, 0.6))
			task.wait(rng:NextNumber(0.03, 0.12))
			set(1, baseTransparency)
			task.wait(rng:NextNumber(0.03, 0.15))
		end
	end
end

for _, part in CollectionService:GetTagged("Flicker") do
	task.spawn(flicker, part)
end
CollectionService:GetInstanceAddedSignal("Flicker"):Connect(flicker)
