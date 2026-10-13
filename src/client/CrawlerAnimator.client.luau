-- Speelt de loopanimatie van de Crawler af (gemaakt in Blender). De snelheid van de animatie
-- volgt hoe hard hij loopt, zodat de poten niet over de grond glijden.
local CollectionService = game:GetService("CollectionService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("CrawlerConfig"))

local walkAnimation = Instance.new("Animation")
if Config.WalkAnimationId ~= "" then
	walkAnimation.AnimationId = Config.WalkAnimationId
else
	-- nog niet gepubliceerd: tijdelijk id voor de KeyframeSequence (alleen in Studio)
	local sequence = Shared:WaitForChild("Monsters"):WaitForChild("CrawlerWalk")
	walkAnimation.AnimationId = KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
end

local active = {}

local function setup(model: Model)
	if active[model] then
		return
	end
	local controller = model:WaitForChild("AnimationController", 10)
	if not controller then
		return
	end
	local animator = controller:FindFirstChildOfClass("Animator") or Instance.new("Animator", controller)
	local track = animator:LoadAnimation(walkAnimation)
	track.Looped = true
	track:Play(0)
	active[model] = { track = track, speed = 0 }
end

local function teardown(model: Model)
	local state = active[model]
	if state then
		state.track:Stop(0)
		active[model] = nil
	end
end

RunService.RenderStepped:Connect(function(dt)
	for model, state in active do
		if not model.Parent then
			teardown(model)
			continue
		end
		local target = model:GetAttribute("Speed") or 0
		state.speed += (target - state.speed) * math.min(1, dt * 8)
		state.track:AdjustSpeed(state.speed / Config.WalkStride)
	end
end)

CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(function(model)
	task.spawn(setup, model)
end)
CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(teardown)
for _, model in CollectionService:GetTagged(Config.Tag) do
	task.spawn(setup, model)
end
