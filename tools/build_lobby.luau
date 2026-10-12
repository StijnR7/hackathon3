-- Bouwt de enge lobby in Workspace.Lobby + donkere Lighting + terrain.
-- Gebruik: plak in de Studio command bar en klik Run. Opnieuw runnen vervangt de oude lobby.
-- Modellen komen uit tools/blender/lobby_models.py (geïmporteerd in Roblox, ids hieronder).
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local AssetService = game:GetService("AssetService")
local Terrain = workspace.Terrain

local MESH = {
	TreeA = "rbxassetid://77098545468253",
	TreeB = "rbxassetid://112113487752093",
	TreeC = "rbxassetid://137534942561850",
	TreeBig = "rbxassetid://79809566629563",
	DeadBush = "rbxassetid://87291523534168",
	GraveRound = "rbxassetid://105463784918919",
	GraveCross = "rbxassetid://84167894312254",
	GraveBroken = "rbxassetid://109761862492604",
	Obelisk = "rbxassetid://92717193796034",
	Coffin = "rbxassetid://93688854707614",
	RockA = "rbxassetid://111989095086868",
	RockB = "rbxassetid://79870777750759",
	LampPost = "rbxassetid://135950153685701",
	Lantern = "rbxassetid://120941129957285",
	FenceSegment = "rbxassetid://104930797058688",
	GateArch = "rbxassetid://114844940580315",
	Crypt = "rbxassetid://106492121005024",
}
-- Hoogte van elk model in Blender (meters) uit lobby_models.json; schaal 1 = 1 stud per meter.
local HEIGHT = {
	TreeA = 9.754, TreeB = 7.709, TreeC = 11.502, TreeBig = 14.438, DeadBush = 2.384,
	GraveRound = 1.664, GraveCross = 1.864, GraveBroken = 1.116, Obelisk = 2.958, Coffin = 0.58,
	RockA = 1.269, RockB = 1.627, LampPost = 7.15, Lantern = 1.46, FenceSegment = 4.0,
	GateArch = 8.781, Crypt = 16.024,
}
-- Als de deur van de crypte de verkeerde kant op staat: zet op -1.
local CRYPT_DOOR = 1

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

local templates = {}
local function mesh(name, fidelity)
	local key = name .. tostring(fidelity)
	if not templates[key] then
		local mp = AssetService:CreateMeshPartAsync(MESH[name], { CollisionFidelity = fidelity or Enum.CollisionFidelity.Hull })
		mp.Anchored = true
		mp.Name = name
		templates[key] = mp
	end
	return templates[key]:Clone()
end

-- Zet model `name` met de onderkant op `cf` (grondpunt + rotatie), schaal = studs per Blender-meter.
local function place(parent, name, scale, cf, props, fidelity)
	local mp = mesh(name, fidelity)
	local k = HEIGHT[name] * scale / mp.MeshSize.Y
	mp.Size = mp.MeshSize * k
	mp.CFrame = cf * CFrame.new(0, mp.Size.Y / 2, 0)
	for key, v in props or {} do
		mp[key] = v
	end
	mp.Parent = parent
	return mp
end

local function light(parent, color, range, brightness, flicker)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = true
	l.Parent = parent
	if flicker then
		CollectionService:AddTag(parent, "Flicker")
	end
	return l
end

local function getOrCreate(className)
	local inst = Lighting:FindFirstChildOfClass(className)
	if not inst then
		inst = Instance.new(className)
		inst.Parent = Lighting
	end
	return inst
end

local IRON = Color3.fromRGB(22, 22, 24)
local STONE = Color3.fromRGB(62, 63, 66)
local BARK = Color3.fromRGB(38, 31, 27)
local LAMP_COLOR = Color3.fromRGB(255, 145, 70)
local RED = Color3.fromRGB(190, 20, 20)

--------------------------------------------------------------------- sfeer
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
atmo.Density = 0.4
atmo.Offset = 0
atmo.Color = Color3.fromRGB(55, 58, 70)
atmo.Decay = Color3.fromRGB(20, 20, 26)
atmo.Glare = 0
atmo.Haze = 2

local cc = getOrCreate("ColorCorrectionEffect")
cc.Brightness = 0.02
cc.Contrast = 0.18
cc.Saturation = -0.45
cc.TintColor = Color3.fromRGB(200, 210, 230)

local bloom = getOrCreate("BloomEffect")
bloom.Intensity = 0.7
bloom.Size = 30
bloom.Threshold = 1.4

local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
if rays then rays.Enabled = false end

local sky = getOrCreate("Sky")
sky.MoonAngularSize = 15
sky.StarCount = 400

--------------------------------------------------------------------- grond (terrain)
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate.CFrame = CFrame.new(0, -40, 0)
	baseplate.Transparency = 1
end

local CENTER = Vector3.new(0, 0, -6) -- midden van het plein
Terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(46, 41, 35))
Terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(36, 31, 27))
Terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(48, 50, 36))
Terrain:SetMaterialColor(Enum.Material.Cobblestone, Color3.fromRGB(72, 72, 74))
Terrain:FillBlock(CFrame.new(0, -8, -10), Vector3.new(220, 16, 220), Enum.Material.Ground)
for _ = 1, 70 do
	local r = rng:NextNumber(4, 9)
	local mat = rng:NextNumber() < 0.5 and Enum.Material.LeafyGrass or Enum.Material.Mud
	Terrain:FillBall(Vector3.new(rng:NextNumber(-95, 95), -r + rng:NextNumber(0.3, 1.2), rng:NextNumber(-110, 90)), r, mat)
end
-- pad van de poort naar het plein + plein
Terrain:FillBlock(CFrame.new(0, -2, 34), Vector3.new(10, 4, 52), Enum.Material.Cobblestone)
Terrain:FillCylinder(CFrame.new(CENTER - Vector3.new(0, 2, 0)), 4, 17, Enum.Material.Cobblestone)

--------------------------------------------------------------------- spawn
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then
	for _, d in spawn:GetChildren() do
		if d:IsA("Decal") then d:Destroy() end
	end
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.6, 60)
	spawn.Transparency = 1
	spawn.CanCollide = false
end

--------------------------------------------------------------------- poort + hek
local fence = folder("Fence")
local FRONT, BACK, SIDE = 50, -82, 62
place(fence, "GateArch", 1.25, CFrame.new(0, 0, FRONT), { Material = Enum.Material.Slate, Color = Color3.fromRGB(60, 60, 63) }, Enum.CollisionFidelity.PreciseConvexDecomposition)

local SEG = 8.36 * 1.4
local function fenceLine(a, b, gap)
	local dir = b - a
	local n = math.floor(dir.Magnitude / SEG)
	local step = dir / n
	for i = 0, n - 1 do
		local mid = a + step * (i + 0.5)
		if not (gap and math.abs(mid.X) < gap) then
			local cf = CFrame.lookAt(mid, mid + step) * CFrame.Angles(0, math.pi / 2, 0)
			cf = cf * CFrame.Angles(math.rad(rng:NextNumber(-3, 3)), 0, math.rad(rng:NextNumber(-2, 2)))
			place(fence, "FenceSegment", 1.4, cf, { Material = Enum.Material.Metal, Color = IRON }, Enum.CollisionFidelity.Box)
		end
	end
end
fenceLine(Vector3.new(-SIDE, 0, FRONT), Vector3.new(SIDE, 0, FRONT), 8)
fenceLine(Vector3.new(-SIDE, 0, BACK), Vector3.new(SIDE, 0, BACK))
fenceLine(Vector3.new(-SIDE, 0, BACK), Vector3.new(-SIDE, 0, FRONT))
fenceLine(Vector3.new(SIDE, 0, BACK), Vector3.new(SIDE, 0, FRONT))

--------------------------------------------------------------------- lantaarns
local lamps = folder("Lamps")
local LAMP_SCALE = 1.35
-- ophangpunt t.o.v. het midden van de LampPost-mesh (Blender: hang (1.45, 5.9), bbox x -0.38..1.52, z 0..7.15).
-- De import spiegelt X, dus de arm wijst in Roblox naar -X.
local HANG = Vector3.new(-(1.45 - (-0.38 + 1.52) / 2), 5.9 - 7.15 / 2, 0)
local function lampPost(pos, towards, broken)
	local look = Vector3.new(towards.X, pos.Y, towards.Z)
	local cf = CFrame.lookAt(pos, look) * CFrame.Angles(0, -math.pi / 2, 0) -- arm (-X) wijst naar `towards`
	local post = place(lamps, "LampPost", LAMP_SCALE, cf, { Material = Enum.Material.Metal, Color = IRON })
	local hang = post.CFrame * (HANG * LAMP_SCALE)
	local lantern = place(lamps, "Lantern", LAMP_SCALE, CFrame.new(hang - Vector3.new(0, 1.46 * LAMP_SCALE, 0)) * cf.Rotation, { Material = Enum.Material.Metal, Color = IRON, CanCollide = false })
	local glass = part(lamps, {
		Name = "LampGlass",
		Size = Vector3.new(0.4, 0.66, 0.4) * LAMP_SCALE,
		CFrame = lantern.CFrame * CFrame.new(0, -0.14 * LAMP_SCALE, 0),
		Material = broken and Enum.Material.Glass or Enum.Material.Neon,
		Color = broken and Color3.fromRGB(30, 26, 22) or Color3.fromRGB(255, 160, 80),
		Transparency = broken and 0.2 or 0.15,
		CanCollide = false,
		CastShadow = false,
	})
	if not broken then
		light(glass, LAMP_COLOR, 22, 1.3, true)
	end
end
for i, z in { 42, 30, 18 } do
	lampPost(Vector3.new(-6.5, 0, z), Vector3.new(0, 0, z), false)
	lampPost(Vector3.new(6.5, 0, z), Vector3.new(0, 0, z), i == 2)
end
for i = 0, 5 do
	local a = math.rad(30 + i * 60)
	local pos = CENTER + Vector3.new(math.sin(a), 0, math.cos(a)) * 19
	lampPost(pos, CENTER, false)
end

--------------------------------------------------------------------- plein met de hangboom
local plaza = folder("Plaza")
place(plaza, "TreeBig", 1.7, CFrame.new(CENTER) * CFrame.Angles(0, math.rad(20), 0), { Material = Enum.Material.Wood, Color = BARK, CanCollide = false })
part(plaza, { Name = "TrunkCollider", Shape = Enum.PartType.Cylinder, Size = Vector3.new(14, 3.2, 3.2), CFrame = CFrame.new(CENTER + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 1 })
-- touwen met lantaarns aan de boom
for i = 1, 3 do
	local a = math.rad(i * 120 + 10)
	local top = CENTER + Vector3.new(math.sin(a) * 6, 15, math.cos(a) * 6)
	local len = rng:NextNumber(4, 7)
	part(plaza, { Name = "Rope", Size = Vector3.new(0.12, len, 0.12), CFrame = CFrame.new(top - Vector3.new(0, len / 2, 0)), Material = Enum.Material.Fabric, Color = Color3.fromRGB(60, 50, 38), CanCollide = false })
	local lantern = place(plaza, "Lantern", 1.3, CFrame.new(top - Vector3.new(0, len + 1.46 * 1.3, 0)), { Material = Enum.Material.Metal, Color = IRON, CanCollide = false })
	local glass = part(plaza, { Name = "LampGlass", Size = Vector3.new(0.4, 0.66, 0.4) * 1.3, CFrame = lantern.CFrame * CFrame.new(0, -0.14 * 1.3, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 120, 60), Transparency = 0.15, CanCollide = false, CastShadow = false })
	light(glass, LAMP_COLOR, 16, 1, true)
end

--------------------------------------------------------------------- crypten = queues
local CRYPT_SCALE = 1.15
local queuesFolder = folder("Queues")
local NAMES = { "CRYPT I", "CRYPT II", "CRYPT III" }
for i, deg in { -48, 0, 48 } do
	local a = math.rad(deg)
	local pos = CENTER + Vector3.new(math.sin(a), 0, -math.cos(a)) * 36
	local model = Instance.new("Model")
	model.Name = "Queue" .. i
	model:SetAttribute("Order", i)
	model:SetAttribute("DisplayName", NAMES[i])
	model.Parent = queuesFolder

	-- deur wijst naar het plein
	local face = CFrame.lookAt(pos, Vector3.new(CENTER.X, 0, CENTER.Z))
	local meshCf = face * CFrame.Angles(0, CRYPT_DOOR == 1 and 0 or math.pi, 0)
	place(model, "Crypt", CRYPT_SCALE, meshCf, { Material = Enum.Material.Slate, Color = STONE }, Enum.CollisionFidelity.PreciseConvexDecomposition)

	local s = CRYPT_SCALE
	local floorY = 1.0 * s
	part(model, {
		Name = "Zone",
		Size = Vector3.new(9.5, 8, 10) * s,
		CFrame = face * CFrame.new(0, floorY + 4 * s, 0.75 * s),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	part(model, { Name = "Exit", Size = Vector3.new(4, 1, 4), CFrame = face * CFrame.new(0, 0.5, -(8.76 + 4) * s) * CFrame.Angles(0, math.pi, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })

	-- runencirkel op de vloer
	local ringCf = face * CFrame.new(0, floorY + 0.05, 0.75 * s) * CFrame.Angles(0, 0, math.pi / 2)
	part(model, { Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 8, 8), CFrame = ringCf, Material = Enum.Material.Neon, Color = Color3.fromRGB(60, 10, 10), CanCollide = false, CastShadow = false })
	part(model, { Name = "RingInner", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 7.3, 7.3), CFrame = ringCf, Material = Enum.Material.Slate, Color = Color3.fromRGB(30, 28, 28), CanCollide = false, CastShadow = false })
	for k = 0, 5 do
		local ang = k / 6 * math.pi * 2
		local p = (face * CFrame.new(0, floorY, 0.75 * s)) * CFrame.new(math.cos(ang) * 4.6, 0, math.sin(ang) * 4.6)
		local candle = part(model, { Name = "Candle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(rng:NextNumber(0.6, 1.2), 0.35, 0.35), CFrame = p * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.pi / 2), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(220, 210, 185), CanCollide = false })
		local flame = part(model, { Name = "Flame", Size = Vector3.new(0.15, 0.3, 0.15), CFrame = CFrame.new(candle.Position + Vector3.new(0, candle.Size.X / 2 + 0.15, 0)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 170, 80), CanCollide = false, CastShadow = false })
		if k % 2 == 0 then
			light(flame, Color3.fromRGB(255, 140, 60), 9, 0.8, true)
		end
	end
	local inside = part(model, { Name = "InsideLight", Size = Vector3.new(1, 1, 1), CFrame = face * CFrame.new(0, floorY + 7 * s, 2 * s), Transparency = 1, CanCollide = false, CanQuery = false })
	light(inside, RED, 18, 1.2, false)

	-- bord boven de deur
	local board = part(model, { Name = "Board", Size = Vector3.new(1, 1, 1), CFrame = face * CFrame.new(0, 13.5 * s, -9 * s), Transparency = 1, CanCollide = false, CanQuery = false })
	local gui = Instance.new("BillboardGui")
	gui.Name = "QueueBoard"
	gui.Size = UDim2.fromScale(12, 5)
	gui.LightInfluence = 0
	gui.MaxDistance = 130
	gui.Parent = board
	local function label(name, y, h, text, font, color)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, h)
		l.BackgroundTransparency = 1
		l.TextScaled = true
		l.Text = text
		l.FontFace = Font.new("rbxasset://fonts/families/" .. font .. ".json")
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.5
		l.Parent = gui
		return l
	end
	label("Title", 0, 0.45, NAMES[i], "Creepster", RED)
	label("Count", 0.45, 0.3, "0/4", "Creepster", Color3.fromRGB(215, 205, 188))
	label("Status", 0.75, 0.25, "STEP INSIDE", "SpecialElite", Color3.fromRGB(180, 170, 160))

	-- doodskisten bij de ingang
	for _, side in { -1, 1 } do
		if rng:NextNumber() < 0.6 then
			local cp = face * CFrame.new(side * 9 * s, 0, -6 * s)
			place(model, "Coffin", 3.2, cp * CFrame.Angles(0, math.rad(rng:NextNumber(-30, 30)), 0), { Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(52, 37, 29) })
		end
	end

	CollectionService:AddTag(model, "Queue")
end

--------------------------------------------------------------------- kerkhof
local graves = folder("Graveyard")
local GRAVE_TYPES = { "GraveRound", "GraveRound", "GraveCross", "GraveBroken", "GraveCross", "Obelisk" }
for _, side in { -1, 1 } do
	for row = 0, 3 do
		for col = 0, 4 do
			if rng:NextNumber() < 0.8 then
				local x = side * (13 + row * 5.5) + rng:NextNumber(-0.8, 0.8)
				local z = 44 - col * 6.5 + rng:NextNumber(-0.8, 0.8)
				local kind = GRAVE_TYPES[rng:NextInteger(1, #GRAVE_TYPES)]
				local tint = rng:NextNumber(0.85, 1.1)
				local cf = CFrame.new(x, -0.25, z)
					* CFrame.Angles(0, math.rad(side * 90 + rng:NextNumber(-12, 12)), 0)
					* CFrame.Angles(math.rad(rng:NextNumber(-9, 9)), 0, math.rad(rng:NextNumber(-7, 7)))
				place(graves, kind, kind == "Obelisk" and 2.0 or 2.4, cf, { Material = Enum.Material.Slate, Color = Color3.new(STONE.R * tint, STONE.G * tint, STONE.B * tint) })
			end
		end
	end
end

--------------------------------------------------------------------- bomen, struiken, rotsen
local nature = folder("Nature")
local function free(x, z)
	if math.abs(x) < 10 and z > 8 and z < 66 then return false end -- pad
	if (Vector3.new(x, 0, z) - CENTER).Magnitude < 24 then return false end -- plein
	for _, deg in { -48, 0, 48 } do
		local a = math.rad(deg)
		local c = CENTER + Vector3.new(math.sin(a), 0, -math.cos(a)) * 36
		if (Vector3.new(x, 0, z) - c).Magnitude < 15 then return false end -- crypten
	end
	if math.abs(x) > 9 and math.abs(x) < 38 and z > 14 and z < 50 then return false end -- kerkhof
	return true
end
local function scatter(count, minX, maxX, minZ, maxZ, fn)
	local placed, tries = 0, 0
	while placed < count and tries < count * 40 do
		tries += 1
		local x, z = rng:NextNumber(minX, maxX), rng:NextNumber(minZ, maxZ)
		if free(x, z) then
			placed += 1
			fn(x, z)
		end
	end
end
local TREE_TYPES = { "TreeA", "TreeB", "TreeC" }
scatter(55, -SIDE + 3, SIDE - 3, BACK + 3, FRONT - 3, function(x, z)
	local s = rng:NextNumber(1.5, 2.2)
	local cf = CFrame.new(x, -0.3, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	place(nature, TREE_TYPES[rng:NextInteger(1, 3)], s, cf, { Material = Enum.Material.Wood, Color = BARK, CanCollide = false })
	part(nature, { Name = "TrunkCollider", Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 1.6 * s / 1.8, 1.6 * s / 1.8), CFrame = CFrame.new(x, 5, z) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 1 })
end)
-- bomen buiten het hek (silhouetten in de mist)
for _ = 1, 40 do
	local a = rng:NextNumber(0, math.pi * 2)
	local d = rng:NextNumber(75, 105)
	local x, z = math.cos(a) * d, CENTER.Z + math.sin(a) * d
	place(nature, TREE_TYPES[rng:NextInteger(1, 3)], rng:NextNumber(1.8, 2.6), CFrame.new(x, -0.3, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), { Material = Enum.Material.Wood, Color = BARK, CanCollide = false })
end
scatter(45, -SIDE + 2, SIDE - 2, BACK + 2, FRONT - 2, function(x, z)
	place(nature, "DeadBush", rng:NextNumber(1.2, 1.9), CFrame.new(x, -0.1, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), { Material = Enum.Material.Wood, Color = Color3.fromRGB(45, 38, 30), CanCollide = false })
end)
scatter(25, -SIDE + 2, SIDE - 2, BACK + 2, FRONT - 2, function(x, z)
	local kind = rng:NextNumber() < 0.5 and "RockA" or "RockB"
	place(nature, kind, rng:NextNumber(1, 2.4), CFrame.new(x, -0.5, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), { Material = Enum.Material.Rock, Color = Color3.fromRGB(68, 68, 70) })
end)

--------------------------------------------------------------------- mist en as
local fx = folder("Effects")
local fogPart = part(fx, { Name = "GroundFog", Size = Vector3.new(130, 1, 140), CFrame = CFrame.new(0, 1, -10), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
local fog = Instance.new("ParticleEmitter")
fog.Texture = "rbxasset://textures/particles/smoke_main.dds"
fog.Color = ColorSequence.new(Color3.fromRGB(120, 120, 132))
fog.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.82), NumberSequenceKeypoint.new(1, 1) })
fog.Size = NumberSequence.new(16)
fog.Lifetime = NumberRange.new(9, 14)
fog.Rate = 30
fog.Speed = NumberRange.new(0.5, 1)
fog.SpreadAngle = Vector2.new(180, 0)
fog.Rotation = NumberRange.new(0, 360)
fog.RotSpeed = NumberRange.new(-5, 5)
fog.LightEmission = 0
fog.Parent = fogPart

local ashPart = part(fx, { Name = "Ash", Size = Vector3.new(130, 1, 140), CFrame = CFrame.new(0, 25, -10), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
local ash = Instance.new("ParticleEmitter")
ash.Color = ColorSequence.new(Color3.fromRGB(150, 145, 140))
ash.Size = NumberSequence.new(0.12)
ash.Lifetime = NumberRange.new(12, 18)
ash.Rate = 40
ash.Speed = NumberRange.new(1, 2)
ash.EmissionDirection = Enum.NormalId.Bottom
ash.SpreadAngle = Vector2.new(30, 30)
ash.Rotation = NumberRange.new(0, 360)
ash.RotSpeed = NumberRange.new(-40, 40)
ash.Acceleration = Vector3.new(0.6, 0, 0.2)
ash.Transparency = NumberSequence.new(0.3)
ash.Parent = ashPart

for _, t in templates do
	t:Destroy()
end
print("[Lobby] gebouwd")
