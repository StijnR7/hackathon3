-- Een ronde in het ziekenhuis:
--   1. wachten tot de groep binnen is, iedereen spawnt bij de receptie
--   2. FuseCount zekeringen liggen verspreid (op FuseSpawn-markers). Oppakken met een ProximityPrompt
--   3. zekeringen in de stroomkast (tag FuseBox) stoppen. Alle erin → voordeur gaat open
--   4. na GracePeriod wordt de Crawler losgelaten (Workspace-attribuut CrawlerEnabled)
--   5. gepakt = dood (geen respawn, je kijkt mee); in de ExitZone als de deur open is = ontsnapt
--   6. niemand meer binnen → uitslag → iedereen terug naar de lobby (in Studio: nieuwe ronde)
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("RoundConfig"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

Players.CharacterAutoLoads = false
-- Crawler pas loslaten als de ronde loopt
workspace:SetAttribute("CrawlerEnabled", false)

local phase = "Waiting" -- Waiting | Intro | Playing | Ended
local status = {} -- [Player] = "alive" | "dead" | "escaped"
local carrying = {} -- [Player] = aantal zekeringen
local fusesPlaced = 0
local doorOpen = false
local crawlerFree = false
local roundEndsAt = 0
local roundId = 0

local fuseFolder = Instance.new("Folder")
fuseFolder.Name = "RoundFuses"
fuseFolder.Parent = workspace

-- ---------------------------------------------------------------- toestand naar clients
local function snapshot()
	local players = {}
	for player, s in status do
		players[tostring(player.UserId)] = { name = player.DisplayName, status = s, carrying = carrying[player] or 0 }
	end
	return {
		phase = phase,
		fusesPlaced = fusesPlaced,
		fusesTotal = Config.FuseCount,
		doorOpen = doorOpen,
		crawlerFree = crawlerFree,
		timeLeft = phase == "Playing" and math.max(0, roundEndsAt - os.clock()) or nil,
		players = players,
	}
end

local function broadcast()
	Remotes.RoundState:FireAllClients(snapshot())
end

local function message(text: string, kind: string?, target: Player?)
	if target then
		Remotes.RoundMessage:FireClient(target, text, kind or "info")
	else
		Remotes.RoundMessage:FireAllClients(text, kind or "info")
	end
end

-- ---------------------------------------------------------------- map-onderdelen
local function tagged(tag: string): { BasePart }
	local list = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) then
			table.insert(list, inst)
		end
	end
	return list
end

local function findAll(name: string): { BasePart }
	local list = {}
	for _, d in workspace:GetDescendants() do
		if d.Name == name and d:IsA("BasePart") and not d:IsDescendantOf(fuseFolder) then
			table.insert(list, d)
		end
	end
	return list
end

-- voordeur: originelen bewaren zodat een nieuwe ronde (in Studio) alles kan terugzetten
local door = { leaves = {}, locks = {}, light = nil }
local function captureDoor()
	for _, name in { "EntranceDoor", "EntranceGlass" } do
		for _, p in findAll(name) do
			table.insert(door.leaves, { part = p, cframe = p.CFrame })
		end
	end
	for _, name in { "Chain", "Padlock" } do
		for _, p in findAll(name) do
			table.insert(door.locks, { part = p, cframe = p.CFrame, parent = p.Parent, collide = p.CanCollide })
		end
	end
end

local function resetDoor()
	for _, leaf in door.leaves do
		leaf.part.CFrame = leaf.cframe
		leaf.part.CanCollide = true
	end
	for _, lock in door.locks do
		lock.part.Anchored = true
		lock.part.CanCollide = lock.collide
		lock.part.CFrame = lock.cframe
		lock.part.Parent = lock.parent
	end
	if door.light then
		door.light:Destroy()
		door.light = nil
	end
end

local function openDoor()
	doorOpen = true
	-- ketting en hangslot vallen eraf
	for _, lock in door.locks do
		lock.part.Anchored = false
		lock.part.CanCollide = true
	end
	task.delay(4, function()
		for _, lock in door.locks do
			if doorOpen then
				lock.part.Parent = nil
			end
		end
	end)
	-- deuren zwaaien naar binnen open, om de buitenkant van elke deur
	local center = Vector3.zero
	for _, leaf in door.leaves do
		center += leaf.cframe.Position
	end
	center /= math.max(1, #door.leaves)
	for _, leaf in door.leaves do
		local side = math.sign(leaf.cframe.Position.X - center.X)
		local hinge = Vector3.new(center.X + side * 5.1, leaf.cframe.Position.Y, leaf.cframe.Position.Z)
		-- naar binnen (de receptie in), niet de muur in
		local swing = CFrame.new(hinge) * CFrame.Angles(0, -side * math.rad(100), 0) * CFrame.new(-hinge)
		leaf.part.CanCollide = false
		TweenService:Create(leaf.part, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = swing * leaf.cframe,
		}):Play()
	end
	-- fel licht van buiten in de deuropening
	local light = Instance.new("Part")
	light.Name = "Daylight"
	light.Anchored = true
	light.CanCollide = false
	light.CanQuery = false
	light.Material = Enum.Material.Neon
	light.Color = Color3.fromRGB(235, 240, 255)
	light.Size = Vector3.new(10, 9.5, 0.1)
	light.CFrame = CFrame.new(center.X, 4.75, center.Z + 0.15)
	local surface = Instance.new("SurfaceLight")
	surface.Face = Enum.NormalId.Front
	surface.Brightness = 4
	surface.Range = 30
	surface.Angle = 120
	surface.Color = Color3.fromRGB(220, 230, 255)
	surface.Parent = light
	light.Parent = workspace
	door.light = light
end

-- stroomkast: lampjes (rood → groen) en de prompt
local fuseBox = tagged("FuseBox")[1]
local boxLamps = {}
local boxPrompt
if fuseBox then
	for i = 1, Config.FuseCount do
		local lamp = Instance.new("Part")
		lamp.Name = "FuseLamp"
		lamp.Anchored = true
		lamp.CanCollide = false
		lamp.Material = Enum.Material.Neon
		lamp.Size = Vector3.new(0.35, 0.35, 0.1)
		local x = (i - (Config.FuseCount + 1) / 2) * 0.8
		lamp.CFrame = fuseBox.CFrame * CFrame.new(x, 1.2, -fuseBox.Size.Z / 2 - 0.05)
		lamp.Parent = fuseBox.Parent
		table.insert(boxLamps, lamp)
	end
	boxPrompt = Instance.new("ProximityPrompt")
	boxPrompt.ActionText = "Insert fuse"
	boxPrompt.ObjectText = "Fuse box"
	boxPrompt.HoldDuration = Config.InsertHold
	boxPrompt.MaxActivationDistance = Config.PromptDistance
	boxPrompt.RequiresLineOfSight = false
	boxPrompt.Parent = fuseBox
else
	warn("[Round] geen part met tag FuseBox gevonden")
end

local function updateLamps()
	for i, lamp in boxLamps do
		lamp.Color = i <= fusesPlaced and Color3.fromRGB(60, 255, 90) or Color3.fromRGB(150, 20, 15)
	end
end

-- ---------------------------------------------------------------- zekeringen
local function spawnFuse(position: Vector3)
	local fuse = Instance.new("Part")
	fuse.Name = "Fuse"
	fuse.Shape = Enum.PartType.Cylinder
	fuse.Size = Vector3.new(1.1, 0.45, 0.45)
	fuse.Color = Color3.fromRGB(225, 215, 180)
	fuse.Material = Enum.Material.SmoothPlastic
	fuse.Anchored = true
	fuse.CanCollide = false
	fuse.CFrame = CFrame.new(position) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	for _, side in { -1, 1 } do
		local cap = Instance.new("Part")
		cap.Name = "Cap"
		cap.Shape = Enum.PartType.Cylinder
		cap.Size = Vector3.new(0.15, 0.5, 0.5)
		cap.Color = Color3.fromRGB(190, 160, 70)
		cap.Material = Enum.Material.Metal
		cap.Anchored = true
		cap.CanCollide = false
		cap.CFrame = fuse.CFrame * CFrame.new(side * 0.55, 0, 0)
		cap.Parent = fuse
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 220, 140)
	glow.Brightness = 0.6
	glow.Range = 7
	glow.Parent = fuse
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = "Fuse"
	prompt.HoldDuration = Config.PickupHold
	prompt.MaxActivationDistance = Config.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = fuse
	prompt.Triggered:Connect(function(player)
		if phase ~= "Playing" or status[player] ~= "alive" or not fuse.Parent then
			return
		end
		fuse:Destroy()
		carrying[player] = (carrying[player] or 0) + 1
		message("You picked up a fuse", "small", player)
		broadcast()
	end)
	fuse.Parent = fuseFolder
end

local function spawnFuses()
	fuseFolder:ClearAllChildren()
	local spots = tagged("FuseSpawn")
	for i = #spots, 2, -1 do
		local j = math.random(i)
		spots[i], spots[j] = spots[j], spots[i]
	end
	for i = 1, math.min(Config.FuseCount, #spots) do
		spawnFuse(spots[i].Position)
	end
	if #spots < Config.FuseCount then
		warn("[Round] te weinig FuseSpawn-markers:", #spots)
	end
end

if boxPrompt then
	boxPrompt.Triggered:Connect(function(player)
		if phase ~= "Playing" or status[player] ~= "alive" then
			return
		end
		local n = carrying[player] or 0
		if n == 0 then
			message("You need a fuse", "small", player)
			return
		end
		carrying[player] = 0
		fusesPlaced = math.min(Config.FuseCount, fusesPlaced + n)
		updateLamps()
		if fusesPlaced >= Config.FuseCount and not doorOpen then
			openDoor()
			message("The power is back. THE DOOR IS OPEN — GET OUT!", "big")
		else
			message(string.format("%d of %d fuses in place", fusesPlaced, Config.FuseCount), "info")
		end
		broadcast()
	end)
end

-- ---------------------------------------------------------------- spelers
local endRound

local function aliveCount(): number
	local n = 0
	for _, s in status do
		if s == "alive" then
			n += 1
		end
	end
	return n
end

local function checkEnd()
	if phase == "Playing" and aliveCount() == 0 then
		phase = "Ending"
		task.spawn(endRound)
	end
end

local function dropFuses(player: Player, position: Vector3?)
	local n = carrying[player] or 0
	carrying[player] = 0
	if position then
		for i = 1, n do
			spawnFuse(position + Vector3.new((i - 1) * 1.2, -2.4, 0))
		end
	end
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local myRound = roundId
	humanoid.Died:Connect(function()
		if myRound ~= roundId or status[player] ~= "alive" then
			return
		end
		status[player] = "dead"
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		dropFuses(player, root and root.Position)
		message(player.DisplayName .. " was taken", "info")
		message("YOU WERE TAKEN", "death", player)
		broadcast()
		checkEnd()
	end)
end

local function escape(player: Player)
	status[player] = "escaped"
	carrying[player] = 0
	local character = player.Character
	player.Character = nil
	if character then
		character:Destroy()
	end
	message(player.DisplayName .. " escaped", "info")
	message("YOU ESCAPED", "escape", player)
	broadcast()
	checkEnd()
end

local exitZone = tagged("ExitZone")[1]
RunService.Heartbeat:Connect(function()
	if phase ~= "Playing" then
		return
	end
	if os.clock() > roundEndsAt then
		for player, s in status do
			if s == "alive" then
				status[player] = "dead"
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.Health = 0
				end
			end
		end
		message("Time is up. Nobody leaves.", "big")
		broadcast()
		checkEnd()
		return
	end
	if not (doorOpen and exitZone) then
		return
	end
	for player, s in status do
		local root = s == "alive" and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local p = exitZone.CFrame:PointToObjectSpace(root.Position)
			local half = exitZone.Size / 2
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
				escape(player)
			end
		end
	end
end)

-- ---------------------------------------------------------------- rondeverloop
local function startRound()
	roundId += 1
	phase = "Intro"
	fusesPlaced = 0
	doorOpen = false
	crawlerFree = false
	workspace:SetAttribute("CrawlerEnabled", false)
	resetDoor()
	updateLamps()
	spawnFuses()
	table.clear(carrying)
	for _, player in Players:GetPlayers() do
		status[player] = "alive"
		player:LoadCharacter()
	end
	broadcast()
	message("The power is out. Find " .. Config.FuseCount .. " fuses and get them to the fuse box.", "big")

	task.wait(Config.IntroTime)
	phase = "Playing"
	roundEndsAt = os.clock() + Config.TimeLimit
	broadcast()

	local myRound = roundId
	task.delay(Config.GracePeriod, function()
		if phase == "Playing" and roundId == myRound then
			crawlerFree = true
			workspace:SetAttribute("CrawlerEnabled", true)
			message("Something woke up in the morgue...", "big")
			broadcast()
		end
	end)
	-- tijd elke paar seconden bijwerken op de clients
	task.spawn(function()
		while phase == "Playing" and roundId == myRound do
			task.wait(5)
			broadcast()
		end
	end)
end

function endRound()
	phase = "Ended"
	crawlerFree = false
	workspace:SetAttribute("CrawlerEnabled", false)
	local escaped, dead = 0, 0
	for _, s in status do
		if s == "escaped" then
			escaped += 1
		elseif s == "dead" then
			dead += 1
		end
	end
	broadcast()
	message(escaped > 0 and string.format("%d escaped, %d taken", escaped, dead) or "Nobody made it out", "end")

	task.wait(Config.EndDelay)
	local lobby = GameConfig.LobbyPlaceId or 0
	if lobby ~= 0 and not RunService:IsStudio() then
		local group = Players:GetPlayers()
		local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, lobby, group)
		if ok then
			return
		end
		warn("[Round] terug naar lobby mislukt:", err)
	end
	-- Studio (of teleport mislukt): gewoon een nieuwe ronde
	table.clear(status)
	startRound()
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if phase == "Waiting" or phase == "Intro" then
		status[player] = "alive"
		if phase == "Intro" then
			player:LoadCharacter()
		end
	else
		-- te laat binnen: meekijken tot de volgende ronde
		status[player] = "dead"
		message("A round is in progress. You are spectating.", "info", player)
	end
	broadcast()
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if status[player] == "alive" then
		dropFuses(player, root and root.Position)
	end
	status[player] = nil
	carrying[player] = nil
	broadcast()
	checkEnd()
end)

-- ---------------------------------------------------------------- start
captureDoor()
updateLamps()
-- wachten op de groep: start JoinWait seconden na de eerste speler (of meteen als de server vol is)
while #Players:GetPlayers() == 0 do
	task.wait(0.2)
end
local deadline = os.clock() + Config.JoinWait
while os.clock() < deadline and #Players:GetPlayers() < (GameConfig.MaxPlayers or 4) do
	task.wait(0.2)
end
startRound()
