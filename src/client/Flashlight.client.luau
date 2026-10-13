-- Zaklamp: volgt de camera (met een beetje vertraging), aan/uit met F (of de knop op mobiel).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HospitalSounds = require(ReplicatedStorage.Shared.HospitalSounds)

local camera = workspace.CurrentCamera
local rng = Random.new()

local holder = Instance.new("Part")
holder.Name = "Flashlight"
holder.Anchored = true
holder.CanCollide = false
holder.CanQuery = false
holder.CanTouch = false
holder.Transparency = 1
holder.Size = Vector3.new(0.2, 0.2, 0.2)
holder.Parent = camera

local beam = Instance.new("SpotLight")
beam.Face = Enum.NormalId.Front
beam.Brightness = 2.4
beam.Range = 55
beam.Angle = 50
beam.Color = Color3.fromRGB(255, 238, 205)
beam.Shadows = true
beam.Parent = holder

local fill = Instance.new("PointLight")
fill.Brightness = 0.25
fill.Range = 7
fill.Color = beam.Color
fill.Parent = holder

local click = Instance.new("Sound")
click.SoundId = HospitalSounds.FlashlightClick
click.Volume = 0.5
click.Parent = SoundService

local on = true
local function setOn(value)
	on = value
	beam.Enabled = on
	fill.Enabled = on
	click:Play()
end

ContextActionService:BindAction("ToggleFlashlight", function(_, state)
	if state == Enum.UserInputState.Begin then
		setOn(not on)
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle("ToggleFlashlight", "Light")

RunService.RenderStepped:Connect(function(dt)
	local target = camera.CFrame * CFrame.new(0.7, -0.6, -0.5)
	holder.CFrame = holder.CFrame:Lerp(target, math.min(1, dt * 16))
end)

-- Af en toe hapert de zaklamp even
task.spawn(function()
	while true do
		task.wait(rng:NextNumber(35, 90))
		if on then
			for _ = 1, rng:NextInteger(2, 5) do
				beam.Brightness = rng:NextNumber(0, 0.6)
				task.wait(rng:NextNumber(0.04, 0.15))
				beam.Brightness = 2.4
				task.wait(rng:NextNumber(0.04, 0.2))
			end
		end
	end
end)
