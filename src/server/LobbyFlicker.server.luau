-- Laat lampen flikkeren: parts met tag "Flicker" en een PointLight.
local CollectionService = game:GetService("CollectionService")

local function flicker(part)
	local light = part:FindFirstChildOfClass("PointLight")
	if not light then return end
	local base = light.Brightness
	local rng = Random.new()
	while part.Parent do
		task.wait(rng:NextNumber(0.5, 4))
		for _ = 1, rng:NextInteger(1, 4) do
			light.Brightness = base * rng:NextNumber(0, 0.3)
			task.wait(rng:NextNumber(0.03, 0.12))
			light.Brightness = base
			task.wait(rng:NextNumber(0.03, 0.15))
		end
	end
end

for _, part in CollectionService:GetTagged("Flicker") do
	task.spawn(flicker, part)
end
CollectionService:GetInstanceAddedSignal("Flicker"):Connect(flicker)
