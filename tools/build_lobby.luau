-- Bouwt de enge lobby in Workspace.Lobby + donkere Lighting.
-- Gebruik: plak in de Studio command bar en druk Enter. Opnieuw runnen vervangt de oude lobby.
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local old = workspace:FindFirstChild("Lobby")
if old then old:Destroy() end
local lobby = Instance.new("Model")
lobby.Name = "Lobby"
lobby.Parent = workspace

local rng = Random.new(1313)

local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = lobby
	return f
end

local function part(parent, props, class)
	local p = Instance.new(class or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function getOrCreate(className)
	local inst = Lighting:FindFirstChildOfClass(className)
	if not inst then
		inst = Instance.new(className)
		inst.Parent = Lighting
	end
	return inst
end

-- Sfeer
pcall(function() Lighting.Technology = Enum.Technology.Future end)
Lighting.ClockTime = 0
Lighting.Brightness = 1
Lighting.Ambient = Color3.fromRGB(30, 30, 40)
Lighting.OutdoorAmbient = Color3.fromRGB(70, 72, 95)
Lighting.EnvironmentDiffuseScale = 0.2
Lighting.EnvironmentSpecularScale = 0.3
Lighting.GlobalShadows = true
Lighting.ExposureCompensation = 0.3

local atmo = getOrCreate("Atmosphere")
atmo.Density = 0.38
atmo.Offset = 0
atmo.Color = Color3.fromRGB(55, 58, 70)
atmo.Decay = Color3.fromRGB(20, 20, 26)
atmo.Glare = 0
atmo.Haze = 2

local cc = getOrCreate("ColorCorrectionEffect")
cc.Brightness = 0.02
cc.Contrast = 0.15
cc.Saturation = -0.45
cc.TintColor = Color3.fromRGB(200, 210, 230)

local bloom = getOrCreate("BloomEffect")
bloom.Intensity = 0.6
bloom.Size = 30
bloom.Threshold = 1.5

local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
if rays then rays.Enabled = false end

local sky = getOrCreate("Sky")
sky.MoonAngularSize = 15
sky.StarCount = 500

-- Grond en spawn
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	for _, t in baseplate:GetChildren() do
		if t:IsA("Texture") then t:Destroy() end
	end
	baseplate.Material = Enum.Material.Ground
	baseplate.Color = Color3.fromRGB(28, 30, 26)
end

local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then
	for _, d in spawn:GetChildren() do
		if d:IsA("Decal") then d:Destroy() end
	end
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(0, 0.5, 40)
	spawn.Material = Enum.Material.Slate
	spawn.Color = Color3.fromRGB(40, 40, 44)
end

-- Pad
part(lobby, {
	Name = "Path",
	Size = Vector3.new(8, 0.4, 90),
	CFrame = CFrame.new(0, 0.2, -5),
	Material = Enum.Material.Cobblestone,
	Color = Color3.fromRGB(45, 45, 48),
})

-- Lantaarns langs het pad
local lamps = folder("Lamps")
local lampIndex = 0
for z = 32, -32, -16 do
	for _, side in { -1, 1 } do
		lampIndex += 1
		local x = side * 6
		part(lamps, { Name = "Pole", Size = Vector3.new(0.5, 10, 0.5), CFrame = CFrame.new(x, 5, z), Material = Enum.Material.Metal, Color = Color3.fromRGB(20, 20, 20) })
		part(lamps, { Name = "Arm", Size = Vector3.new(1.8, 0.3, 0.3), CFrame = CFrame.new(x - side * 0.9, 10, z), Material = Enum.Material.Metal, Color = Color3.fromRGB(20, 20, 20) })
		local lantern = part(lamps, {
			Name = "Lantern",
			Size = Vector3.new(0.8, 1.1, 0.8),
			CFrame = CFrame.new(x - side * 1.6, 9.2, z),
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(190, 110, 50),
			Transparency = 0.35,
		})
		if lampIndex ~= 5 then -- één kapotte lamp
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 150, 80)
			light.Range = 20
			light.Brightness = 1.2
			light.Shadows = true
			light.Parent = lantern
			CollectionService:AddTag(lantern, "Flicker")
		else
			lantern.Color = Color3.fromRGB(40, 35, 30)
		end
	end
end

-- Hek rondom
local fence = folder("Fence")
local R = 70
local iron = Color3.fromRGB(15, 15, 15)
for i = -R, R, 5 do
	for _, pos in { Vector3.new(i, 0, R), Vector3.new(i, 0, -R), Vector3.new(R, 0, i), Vector3.new(-R, 0, i) } do
		local tilt = CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), 0, math.rad(rng:NextNumber(-6, 6)))
		part(fence, { Name = "Post", Size = Vector3.new(0.4, 8, 0.4), CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)) * tilt, Material = Enum.Material.Metal, Color = iron })
	end
end
for _, y in { 2, 6.5 } do
	part(fence, { Name = "Rail", Size = Vector3.new(2 * R, 0.3, 0.3), CFrame = CFrame.new(0, y, R), Material = Enum.Material.Metal, Color = iron })
	part(fence, { Name = "Rail", Size = Vector3.new(2 * R, 0.3, 0.3), CFrame = CFrame.new(0, y, -R), Material = Enum.Material.Metal, Color = iron })
	part(fence, { Name = "Rail", Size = Vector3.new(0.3, 0.3, 2 * R), CFrame = CFrame.new(R, y, 0), Material = Enum.Material.Metal, Color = iron })
	part(fence, { Name = "Rail", Size = Vector3.new(0.3, 0.3, 2 * R), CFrame = CFrame.new(-R, y, 0), Material = Enum.Material.Metal, Color = iron })
end

-- Kerkhof
local graves = folder("Graveyard")
for gx = -34, -18, 5 do
	for gz = -16, 16, 6 do
		if rng:NextNumber() > 0.3 then
			local cf = CFrame.new(gx, 1.5, gz)
				* CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), math.rad(90 + rng:NextNumber(-8, 8)), math.rad(rng:NextNumber(-10, 10)))
			part(graves, { Name = "Gravestone", Size = Vector3.new(2.6, 3.5, 0.6), CFrame = cf, Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 72, 75) })
			part(graves, { Name = "Mound", Size = Vector3.new(5, 0.5, 2.4), CFrame = CFrame.new(gx + 3, 0.25, gz), Material = Enum.Material.Ground, Color = Color3.fromRGB(40, 32, 26) })
		end
	end
end

-- Dode bomen
local trees = folder("Trees")
local bark = Color3.fromRGB(35, 28, 24)
local function blocked(x, z)
	if math.abs(x) < 14 and z > -70 and z < 46 then return true end -- pad + huis
	if x > -40 and x < -12 and z > -22 and z < 22 then return true end -- kerkhof
	return false
end
local placed = 0
while placed < 45 do
	local x, z = rng:NextNumber(-65, 65), rng:NextNumber(-65, 65)
	if not blocked(x, z) then
		placed += 1
		local h = rng:NextNumber(14, 24)
		local w = rng:NextNumber(1.2, 2)
		local base = CFrame.new(x, h / 2, z) * CFrame.Angles(math.rad(rng:NextNumber(-5, 5)), 0, math.rad(rng:NextNumber(-5, 5)))
		part(trees, { Name = "Trunk", Size = Vector3.new(w, h, w), CFrame = base, Material = Enum.Material.Wood, Color = bark })
		for _ = 1, rng:NextInteger(3, 5) do
			local len = rng:NextNumber(4, 9)
			local cf = base
				* CFrame.new(0, rng:NextNumber(0, h / 2), 0)
				* CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
				* CFrame.Angles(0, 0, math.rad(rng:NextNumber(35, 65)))
				* CFrame.new(0, len / 2, 0)
			part(trees, { Name = "Branch", Size = Vector3.new(w * 0.35, len, w * 0.35), CFrame = cf, Material = Enum.Material.Wood, Color = bark })
		end
	end
end

-- Verlaten huis met speel-portaal
local house = folder("House")
local plank = Color3.fromRGB(48, 38, 32)
local hz = -52
local function wall(name, size, pos)
	return part(house, { Name = name, Size = size, CFrame = CFrame.new(pos), Material = Enum.Material.WoodPlanks, Color = plank })
end
wall("BackWall", Vector3.new(36, 20, 1), Vector3.new(0, 10, hz - 11.5))
wall("LeftWall", Vector3.new(1, 20, 24), Vector3.new(-17.5, 10, hz))
wall("RightWall", Vector3.new(1, 20, 24), Vector3.new(17.5, 10, hz))
wall("FrontLeft", Vector3.new(14, 20, 1), Vector3.new(-11, 10, hz + 11.5))
wall("FrontRight", Vector3.new(14, 20, 1), Vector3.new(11, 10, hz + 11.5))
wall("FrontTop", Vector3.new(8, 8, 1), Vector3.new(0, 16, hz + 11.5))
part(house, { Name = "Floor", Size = Vector3.new(34, 0.4, 22), CFrame = CFrame.new(0, 0.2, hz), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(30, 24, 20) })

local a, L = math.rad(35), 15
local ridge = Vector3.new(0, 20 + L * math.sin(a), hz)
for _, s in { 1, -1 } do
	local center = ridge + Vector3.new(0, -math.sin(a), s * math.cos(a)) * (L / 2)
	part(house, { Name = "Roof", Size = Vector3.new(40, 1, L), CFrame = CFrame.new(center) * CFrame.Angles(s * a, 0, 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(25, 25, 28) })
end
local H = L * math.sin(a)
for _, x in { -17.5, 17.5 } do
	part(house, { Name = "Gable", Size = Vector3.new(1, H, 12), CFrame = CFrame.new(x, 20 + H / 2, hz + 6) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.WoodPlanks, Color = plank }, "WedgePart")
	part(house, { Name = "Gable", Size = Vector3.new(1, H, 12), CFrame = CFrame.new(x, 20 + H / 2, hz - 6), Material = Enum.Material.WoodPlanks, Color = plank }, "WedgePart")
end

-- Dichtgetimmerde ramen
for _, x in { -11, 11 } do
	part(house, { Name = "Window", Size = Vector3.new(5, 6, 0.2), CFrame = CFrame.new(x, 11, hz + 12.1), Material = Enum.Material.Glass, Color = Color3.fromRGB(10, 8, 8), Transparency = 0.1 })
	for _, r in { 20, -25 } do
		part(house, { Name = "Board", Size = Vector3.new(6.5, 0.6, 0.3), CFrame = CFrame.new(x, 11 + rng:NextNumber(-1.5, 1.5), hz + 12.3) * CFrame.Angles(0, 0, math.rad(r)), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(60, 48, 38) })
	end
end

-- Rood licht binnen
local inside = part(house, { Name = "InsideLight", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 10, hz - 4), Transparency = 1, CanCollide = false })
local red = Instance.new("PointLight")
red.Color = Color3.fromRGB(200, 20, 20)
red.Range = 30
red.Brightness = 1.5
red.Parent = inside

-- Portaal in de deur (hier komt later de teleport naar de game)
local portal = part(lobby, {
	Name = "PlayPortal",
	Size = Vector3.new(8, 12, 0.4),
	CFrame = CFrame.new(0, 6, hz + 11.5),
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(110, 0, 0),
	Transparency = 0.35,
	CanCollide = false,
})
local glow = Instance.new("PointLight")
glow.Color = Color3.fromRGB(255, 30, 30)
glow.Range = 22
glow.Brightness = 2
glow.Parent = portal

local sign = part(house, { Name = "Sign", Size = Vector3.new(10, 2.5, 0.3), CFrame = CFrame.new(0, 14.5, hz + 12.2) * CFrame.Angles(0, 0, math.rad(-4)), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(55, 42, 34) })
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Back
gui.LightInfluence = 0.3
gui.Parent = sign
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = "ENTER"
label.TextScaled = true
label.TextColor3 = Color3.fromRGB(150, 10, 10)
label.FontFace = Font.new("rbxasset://fonts/families/Creepster.json")
label.Parent = gui

-- Mist over de grond
local fogPart = part(lobby, { Name = "GroundFog", Size = Vector3.new(130, 1, 130), CFrame = CFrame.new(0, 1, -10), Transparency = 1, CanCollide = false, CanQuery = false })
local fog = Instance.new("ParticleEmitter")
fog.Texture = "rbxasset://textures/particles/smoke_main.dds"
fog.Color = ColorSequence.new(Color3.fromRGB(120, 120, 130))
fog.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 1) })
fog.Size = NumberSequence.new(14)
fog.Lifetime = NumberRange.new(8, 12)
fog.Rate = 25
fog.Speed = NumberRange.new(0.5, 1)
fog.SpreadAngle = Vector2.new(180, 0)
fog.Rotation = NumberRange.new(0, 360)
fog.RotSpeed = NumberRange.new(-5, 5)
fog.LightEmission = 0
fog.Parent = fogPart

print("[Lobby] gebouwd")
