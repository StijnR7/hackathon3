-- Geluid in het ziekenhuis: drone + eng achtergrondgeluid (2D), druppels en monitor op vaste plekken (3D)
-- en af en toe een eng geluid ergens om de speler heen.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HospitalSounds = require(ReplicatedStorage.Shared.HospitalSounds)

local player = Players.LocalPlayer
local rng = Random.new()

local function loop(id, volume, parent, maxDistance)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Looped = true
	if maxDistance then
		s.RollOffMinDistance = 4
		s.RollOffMaxDistance = maxDistance
	end
	s.Parent = parent
	s:Play()
	return s
end

loop(HospitalSounds.Drone, 0.45, SoundService)
loop(HospitalSounds.Eerie, 0.3, SoundService)

local hospital = workspace:WaitForChild("Hospital", 30)
if hospital then
	local props = hospital:WaitForChild("Props", 10)
	local sink = props and props:FindFirstChild("Bathroom") and props.Bathroom:FindFirstChild("Sink")
	if sink then
		loop(HospitalSounds.Drip, 0.6, sink, 40)
	end
	local screen = props and props:FindFirstChild("Surgery") and props.Surgery:FindFirstChild("MonitorScreen")
	if screen then
		loop(HospitalSounds.Monitor, 0.25, screen, 30)
	end
end

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
	task.wait(rng:NextNumber(15, 40))
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(10, 28)
		anchor.Position = root.Position + Vector3.new(math.cos(angle) * dist, rng:NextNumber(0, 5), math.sin(angle) * dist)
		local s = Instance.new("Sound")
		s.SoundId = HospitalSounds.Random[rng:NextInteger(1, #HospitalSounds.Random)]
		s.Volume = rng:NextNumber(0.5, 0.9)
		s.PlaybackSpeed = rng:NextNumber(0.85, 1.05)
		s.RollOffMinDistance = 8
		s.RollOffMaxDistance = 70
		s.Parent = anchor
		s:Play()
		s.Ended:Once(function() s:Destroy() end)
	end
end
