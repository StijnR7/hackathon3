-- Geluid in de lobby: ambience + wind (2D), gefluister bij de crypten (3D) en af en toe een eng geluid om je heen.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundIds = require(ReplicatedStorage.Shared.SoundIds)

local player = Players.LocalPlayer
local rng = Random.new()

local function loop(id, volume, parent)
	if id == "" then return end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Looped = true
	s.Parent = parent or SoundService
	s:Play()
	return s
end

loop(SoundIds.Ambience, 0.5)
loop(SoundIds.Wind, 0.35)

-- Gefluister in elke crypte
local function addWhisper(model)
	local zone = model:WaitForChild("Zone", 10)
	local s = zone and loop(SoundIds.Whisper or "", 0.6, zone)
	if s then
		s.RollOffMinDistance = 4
		s.RollOffMaxDistance = 28
	end
end
for _, m in CollectionService:GetTagged("Queue") do
	task.spawn(addWhisper, m)
end
CollectionService:GetInstanceAddedSignal("Queue"):Connect(addWhisper)

-- Losse enge geluiden op een willekeurige plek om de speler heen
local anchor = Instance.new("Part")
anchor.Name = "ScareSoundAnchor"
anchor.Anchored = true
anchor.CanCollide = false
anchor.CanQuery = false
anchor.CanTouch = false
anchor.Transparency = 1
anchor.Size = Vector3.one
anchor.Parent = workspace

while true do
	task.wait(rng:NextNumber(18, 45))
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and #SoundIds.Random > 0 then
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(12, 30)
		anchor.Position = root.Position + Vector3.new(math.cos(angle) * dist, rng:NextNumber(0, 6), math.sin(angle) * dist)
		local s = Instance.new("Sound")
		s.SoundId = SoundIds.Random[rng:NextInteger(1, #SoundIds.Random)]
		s.Volume = rng:NextNumber(0.5, 0.9)
		s.PlaybackSpeed = rng:NextNumber(0.9, 1.05)
		s.RollOffMinDistance = 10
		s.RollOffMaxDistance = 80
		s.Parent = anchor
		s:Play()
		s.Ended:Once(function() s:Destroy() end)
	end
end
