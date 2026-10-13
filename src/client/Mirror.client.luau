-- Spiegels: elk part met de tag "Mirror" laat op de voorkant een spiegelbeeld zien.
-- Hoe: op de spiegel staat een SurfaceGui met een ViewportFrame. Daarin staat een gespiegelde kopie
-- van de kamer en van de spelers in de buurt. De viewport-camera staat op jouw oog en kijkt loodrecht
-- de spiegel in; de ViewportFrame wordt zo verschoven en geschaald dat het precies een venster naar
-- de gespiegelde wereld is. Je spiegelbeeld heeft alleen een ander gezicht...
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MirrorConfig"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

local STRIP = { "Script", "LocalScript", "ModuleScript", "Sound", "Light", "JointInstance", "WeldConstraint",
	"ForceField", "ParticleEmitter", "BillboardGui", "SurfaceGui", "ProximityPrompt", "ClickDetector", "Attachment" }

local function strip(root: Instance)
	for _, d in root:GetDescendants() do
		for _, class in STRIP do
			if d:IsA(class) then
				d:Destroy()
				break
			end
		end
	end
end

local mirrors = {}

-- spiegeling in het vlak (punt P, normaal n). Een spiegeling draait links/rechts om; omdat een
-- CFrame dat niet kan, klappen we de X-as terug (voor symmetrische delen ziet dat er hetzelfde uit).
local function reflectPoint(m, p: Vector3): Vector3
	return p - 2 * (p - m.point):Dot(m.normal) * m.normal
end
local function reflectVector(m, v: Vector3): Vector3
	return v - 2 * v:Dot(m.normal) * m.normal
end
local function reflectCFrame(m, cf: CFrame): CFrame
	return CFrame.fromMatrix(
		reflectPoint(m, cf.Position),
		-reflectVector(m, cf.RightVector),
		reflectVector(m, cf.UpVector),
		reflectVector(m, -cf.LookVector)
	)
end

local function isCharacterPart(part: Instance): boolean
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") or CollectionService:HasTag(model, "Crawler") then
			return true
		end
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	return false
end

-- statische omgeving (muren, meubels) eenmalig gespiegeld neerzetten
local function buildEnvironment(m)
	local range = Config.EnvironmentRadius
	local parts = workspace:GetPartBoundsInRadius(m.point, range)
	for _, part in parts do
		-- alleen wat vóór de spiegel staat (de muur erachter zou gespiegeld juist vóór het beeld komen)
		if part ~= m.part and part.Transparency < 1 and not isCharacterPart(part)
			and (part.Position - m.point):Dot(m.normal) > 0 then
			local ok, copy = pcall(function()
				return part:Clone()
			end)
			if ok and copy then
				strip(copy)
				for _, child in copy:GetChildren() do
					if child:IsA("BasePart") then
						child:Destroy() -- geneste parts komen zelf al in de lijst
					end
				end
				copy.Anchored = true
				copy.CFrame = reflectCFrame(m, part.CFrame)
				copy.Parent = m.world
			end
		end
	end
end

-- kopie van een karakter met het enge gezicht; houdt bij welk deel bij welk origineel hoort
local function makeReflection(m, character: Model)
	local wasArchivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = wasArchivable
	if not copy then
		return nil
	end
	strip(copy)
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	-- eigen gezicht weg (losse decal of, bij dynamic heads, in de hoofd-texture)
	local head = copy:FindFirstChild("Head")
	if head then
		for _, d in head:GetChildren() do
			if d:IsA("Decal") or d:IsA("FaceControls") then
				d:Destroy()
			end
		end
		if head:IsA("MeshPart") then
			head.TextureID = ""
		end
	end

	local pairs_ = {}
	local sources, copies = {}, {}
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(sources, d)
		end
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(copies, d)
		end
	end
	for i, source in sources do
		local c = copies[i]
		if c then
			c.Anchored = true
			c.LocalTransparencyModifier = 0
			table.insert(pairs_, { source = source, copy = c })
		end
	end
	-- de enge mond: een onzichtbaar plaatje met de decal vóór het gezicht (een decal direct op een
	-- hoofd-mesh rekt over de hele mesh uit en komt dan op de verkeerde plek)
	local mouth, mouthOffset
	local sourceHead = character:FindFirstChild("Head") :: BasePart?
	if head and sourceHead then
		local faceFront = sourceHead:FindFirstChild("FaceFrontAttachment") :: Attachment?
		local front = faceFront and faceFront.Position or Vector3.new(0, 0, -sourceHead.Size.Z / 2)
		local width = sourceHead.Size.X * 0.95
		mouth = Instance.new("Part")
		mouth.Name = "CreepyMouth"
		mouth.Anchored = true
		mouth.Transparency = 1
		mouth.CanCollide = false
		mouth.Size = Vector3.new(width, width / Config.FaceAspect, 0.05)
		local decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Front
		decal.Texture = Config.FaceImage
		decal.Color3 = Config.FaceColor
		decal.Parent = mouth
		mouth.Parent = copy
		mouthOffset = CFrame.new(front + Vector3.new(0, -sourceHead.Size.Y * Config.FaceDrop, -0.06))
	end

	copy.Parent = m.world
	return { model = copy, pairs = pairs_, head = head, mouth = mouth, mouthOffset = mouthOffset }
end

local function setupMirror(part: BasePart)
	if mirrors[part] then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "MirrorGui"
	gui.Face = Enum.NormalId.Front
	gui.Adornee = part
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = Config.PixelsPerStud
	gui.ClipsDescendants = true
	gui.LightInfluence = 0.4
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local viewport = Instance.new("ViewportFrame")
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
	viewport.BorderSizePixel = 0
	viewport.ImageColor3 = Config.Tint
	viewport.Ambient = Config.Ambient
	viewport.LightColor = Config.LightColor
	viewport.Visible = false
	viewport.Parent = gui

	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local cam = Instance.new("Camera")
	cam.Parent = viewport
	viewport.CurrentCamera = cam

	local m = {
		part = part,
		gui = gui,
		viewport = viewport,
		world = world,
		camera = cam,
		reflections = {},
		built = false,
	}
	mirrors[part] = m
end

local function teardownMirror(part: BasePart)
	local m = mirrors[part]
	if m then
		m.gui:Destroy()
		mirrors[part] = nil
	end
end

local function updateMirror(m)
	local part = m.part
	if not part.Parent then
		teardownMirror(part)
		return
	end
	m.normal = part.CFrame.LookVector
	m.point = part.CFrame:PointToWorldSpace(Vector3.new(0, 0, -part.Size.Z / 2))

	local eye = camera.CFrame.Position
	local distance = (eye - m.point):Dot(m.normal)
	if distance < 0.05 or (eye - m.point).Magnitude > Config.Range then
		m.viewport.Visible = false
		return
	end
	if not m.built then
		m.built = true
		buildEnvironment(m)
	end

	-- spelers in de buurt spiegelen (en weghalen als ze weg zijn)
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local near = root and (root.Position - m.point).Magnitude < Config.Range
		local reflection = m.reflections[other]
		if reflection and (not near or reflection.character ~= character) then
			reflection.model:Destroy()
			m.reflections[other] = nil
			reflection = nil
		end
		if near and not reflection then
			reflection = makeReflection(m, character)
			if reflection then
				reflection.character = character
				m.reflections[other] = reflection
			end
		end
		if reflection then
			for _, pair in reflection.pairs do
				pair.copy.CFrame = reflectCFrame(m, pair.source.CFrame)
			end
			if reflection.mouth then
				reflection.mouth.CFrame = reflection.head.CFrame * reflection.mouthOffset
			end
		end
	end

	-- camera op je oog, loodrecht de spiegel in kijkend
	local up = part.CFrame.UpVector
	local camRight = up:Cross(m.normal)
	m.camera.CFrame = CFrame.fromMatrix(eye, camRight, up, m.normal)

	-- het punt recht voor je oog op de spiegel, t.o.v. het midden van de spiegel
	local foot = eye - distance * m.normal
	local a = (foot - m.point):Dot(camRight)
	local b = (foot - m.point):Dot(up)
	local half = math.max(math.abs(a) + part.Size.X / 2, math.abs(b) + part.Size.Y / 2) + 0.1
	m.camera.FieldOfView = math.deg(2 * math.atan(half / distance))

	-- viewport zo neerzetten dat zijn midden recht voor je oog ligt en 1 stud = 1 stud spiegel
	-- zo scherp mogelijk, maar het beeld mag niet groter worden dan MaxPixels
	local ppx = math.min(Config.PixelsPerStud, Config.MaxPixels / (2 * half))
	m.gui.PixelsPerStud = ppx
	m.viewport.Size = UDim2.fromOffset(2 * half * ppx, 2 * half * ppx)
	m.viewport.Position = UDim2.new(0.5, a * ppx, 0.5, -b * ppx)
	m.viewport.LightDirection = -m.normal
	m.viewport.Visible = true
end

RunService:BindToRenderStep("Mirrors", Enum.RenderPriority.Camera.Value + 2, function()
	for _, m in mirrors do
		updateMirror(m)
	end
end)

CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(function(part)
	if part:IsA("BasePart") then
		setupMirror(part)
	end
end)
CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(teardownMirror)
for _, part in CollectionService:GetTagged(Config.Tag) do
	if part:IsA("BasePart") then
		setupMirror(part)
	end
end
