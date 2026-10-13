-- First-person camera: soepel rondkijken (de camera loopt een fractie achter de muis aan),
-- sprinten met Shift met een lichte op-en-neer-bob, en een "^"-vormige crosshair in het midden.
-- Staat uit in de lobby (daar heb je de muis nodig voor de queue-knoppen).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local SENSITIVITY = 0.0035 -- radialen per pixel muisbeweging
local SMOOTHNESS = 18 -- hoger = sneller bij de muis, lager = zachter/trager
local MAX_PITCH = math.rad(80)
local EYE_HEIGHT = 1.5 -- boven de HumanoidRootPart
local WALK_SPEED = 12
local SPRINT_SPEED = 20
local SPRINT_KEYS = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift }
local BOB_FREQUENCY = 11 -- radialen per seconde
local BOB_HEIGHT = 0.12 -- studs op en neer
local BOB_ROLL = math.rad(0.6) -- klein beetje kantelen mee met de pas

if workspace:FindFirstChild("Lobby") then
	return
end

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local targetYaw, targetPitch = 0, 0
local yaw, pitch = 0, 0
local bobTime, bobAmount = 0, 0
local hiddenParts = {} -- delen van je eigen karakter (lichaam, haar, hoeden, gezicht)

local function isSprinting(): boolean
	for _, key in SPRINT_KEYS do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

-- eigen lichaam onzichtbaar (alleen voor jezelf), anders zie je je haar en lijf.
-- De standaard camerascripts zetten dit elke frame terug, dus we zetten het elke frame opnieuw.
local function trackCharacter(character: Model)
	table.clear(hiddenParts)
	local function add(part: Instance)
		if part:IsA("BasePart") or part:IsA("Decal") then
			table.insert(hiddenParts, part)
		end
	end
	for _, d in character:GetDescendants() do
		add(d)
	end
	character.DescendantAdded:Connect(add)
end

local function hideCharacter()
	for i = #hiddenParts, 1, -1 do
		local part = hiddenParts[i]
		if part.Parent then
			part.LocalTransparencyModifier = 1
		else
			table.remove(hiddenParts, i)
		end
	end
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = WALK_SPEED
	-- kijkrichting overnemen van hoe het karakter spawnt
	local _, spawnYaw = root.CFrame:ToOrientation()
	targetYaw, yaw = spawnYaw, spawnYaw
	targetPitch, pitch = 0, 0
	trackCharacter(character)
end

-- crosshair: twee schuine streepjes die samen een brede "^" vormen
local gui = Instance.new("ScreenGui")
gui.Name = "Crosshair"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
for _, side in { -1, 1 } do
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Size = UDim2.fromOffset(11, 2)
	line.Position = UDim2.new(0.5, side * 5, 0.5, 2)
	line.Rotation = side * 28
	line.BackgroundColor3 = Color3.new(1, 1, 1)
	line.BackgroundTransparency = 0.25
	line.BorderSizePixel = 0
	line.Parent = gui
end

UserInputService.MouseIconEnabled = false
camera.CameraType = Enum.CameraType.Scriptable

RunService:BindToRenderStep("FirstPersonCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	local delta = UserInputService:GetMouseDelta()
	targetYaw -= delta.X * SENSITIVITY
	targetPitch = math.clamp(targetPitch - delta.Y * SENSITIVITY, -MAX_PITCH, MAX_PITCH)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and root) or humanoid.Health <= 0 then
		return
	end
	hideCharacter()

	-- soepel achter de muis aan
	local alpha = 1 - math.exp(-SMOOTHNESS * dt)
	yaw += (targetYaw - yaw) * alpha
	pitch += (targetPitch - pitch) * alpha

	-- lichaam draait mee met de kijkrichting (alleen om de verticale as)
	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)

	-- sprinten + bob
	local moving = humanoid.MoveDirection.Magnitude > 0.1
		and humanoid.FloorMaterial ~= Enum.Material.Air
	local sprinting = isSprinting() and moving
	humanoid.WalkSpeed = sprinting and SPRINT_SPEED or WALK_SPEED
	bobAmount += ((sprinting and 1 or 0) - bobAmount) * math.min(1, dt * 6)
	if bobAmount > 0.01 then
		bobTime += dt * BOB_FREQUENCY
	end
	local bobY = math.abs(math.sin(bobTime)) * BOB_HEIGHT * bobAmount
	local roll = math.sin(bobTime) * BOB_ROLL * bobAmount

	local eye = root.Position + Vector3.new(0, EYE_HEIGHT + bobY, 0)
	camera.CFrame = CFrame.new(eye) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0) * CFrame.Angles(0, 0, roll)
end)

if player.Character then
	task.spawn(onCharacter, player.Character)
end
player.CharacterAdded:Connect(onCharacter)
