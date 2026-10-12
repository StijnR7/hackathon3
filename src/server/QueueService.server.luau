-- Queues in de lobby. Stap in een queue (Model met tag "Queue", child "Zone"): eerste speler wordt host,
-- host kiest het aantal spelers en start. Na de countdown gaat de groep naar GameConfig.GamePlaceId.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local IDLE_RING = Color3.fromRGB(60, 10, 10)
local ACTIVE_RING = Color3.fromRGB(190, 20, 20)

local queues = {}
local queueOf = {} -- [Player] = queue

local function isInside(zone, pos)
	local p = zone.CFrame:PointToObjectSpace(pos)
	local h = zone.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

local function stateOf(q)
	local ids = {}
	for _, p in q.players do
		table.insert(ids, p.UserId)
	end
	return {
		id = q.id,
		name = q.name,
		players = ids,
		host = q.host and q.host.UserId,
		max = q.max,
		countdown = q.countdown,
		teleporting = q.teleporting,
	}
end

local function allStates()
	local all = {}
	for _, q in queues do
		table.insert(all, stateOf(q))
	end
	return all
end

local function refresh(q)
	local n = #q.players
	if q.count then
		q.count.Text = n .. "/" .. q.max
	end
	if q.status then
		if q.teleporting then
			q.status.Text = "ENTERING..."
		elseif q.countdown then
			q.status.Text = "STARTING IN " .. q.countdown
		elseif n == 0 then
			q.status.Text = "STEP INSIDE"
		elseif n >= q.max then
			q.status.Text = "FULL"
		else
			q.status.Text = "WAITING FOR HOST"
		end
	end
	for _, ring in q.rings do
		ring.Color = n > 0 and ACTIVE_RING or IDLE_RING
	end
	Remotes.QueueState:FireAllClients(allStates())
end

local function pushOut(p, q)
	local char = p.Character
	if char and q.exit then
		char:PivotTo(q.exit.CFrame + Vector3.new(0, 3, 0))
	end
end

local function cancelCountdown(q)
	q.startToken = nil
	q.countdown = nil
end

local function removePlayer(p)
	local q = queueOf[p]
	if not q then return end
	queueOf[p] = nil
	local i = table.find(q.players, p)
	if i then
		table.remove(q.players, i)
	end
	if q.host == p then
		q.host = q.players[1]
		cancelCountdown(q)
	end
	if #q.players == 0 then
		cancelCountdown(q)
		q.max = GameConfig.MaxPlayers
	end
	refresh(q)
end

local function addPlayer(p, q)
	queueOf[p] = q
	table.insert(q.players, p)
	if not q.host then
		q.host = p
	end
	refresh(q)
end

local function launch(q)
	local group = table.clone(q.players)
	if #group == 0 then return end
	q.teleporting = true
	refresh(q)

	local ok, err
	if GameConfig.GamePlaceId ~= 0 and not RunService:IsStudio() then
		local options = Instance.new("TeleportOptions")
		options.ShouldReserveServer = true
		for _ = 1, 3 do
			ok, err = pcall(TeleportService.TeleportAsync, TeleportService, GameConfig.GamePlaceId, group, options)
			if ok then break end
			task.wait(2)
		end
	else
		task.wait(2.5) -- laat de fade zien
		ok, err = false, "GamePlaceId is nog niet ingesteld (of je zit in Studio)"
	end

	if not ok then
		warn("[Queue] teleport mislukt:", err)
		for _, p in group do
			if queueOf[p] == q then
				Remotes.QueueNotice:FireClient(p, "The game isn't ready yet...")
				pushOut(p, q)
				removePlayer(p)
			end
		end
	end
	-- Na een gelukte teleport duurt het even voor spelers echt weg zijn; blokkeer de queue zolang.
	task.delay(ok and 8 or 0, function()
		q.teleporting = false
		refresh(q)
	end)
end

local function startCountdown(q)
	local token = {}
	q.startToken = token
	for i = GameConfig.CountdownSeconds, 1, -1 do
		q.countdown = i
		refresh(q)
		task.wait(1)
		if q.startToken ~= token then return end
	end
	q.countdown = nil
	q.startToken = nil
	launch(q)
end

local function registerQueue(model)
	local zone = model:FindFirstChild("Zone")
	if not zone then
		warn("[Queue] geen Zone in", model:GetFullName())
		return
	end
	local board = model:FindFirstChild("QueueBoard", true)
	local rings = {}
	for _, d in model:GetDescendants() do
		if d.Name == "Ring" and d:IsA("BasePart") then
			table.insert(rings, d)
		end
	end
	local q = {
		id = model:GetAttribute("Order") or #queues + 1,
		name = model:GetAttribute("DisplayName") or model.Name,
		zone = zone,
		exit = model:FindFirstChild("Exit"),
		count = board and board:FindFirstChild("Count", true),
		status = board and board:FindFirstChild("Status", true),
		rings = rings,
		players = {},
		max = GameConfig.MaxPlayers,
	}
	table.insert(queues, q)
	table.sort(queues, function(a, b) return a.id < b.id end)
	refresh(q)
end

for _, model in CollectionService:GetTagged("Queue") do
	registerQueue(model)
end
CollectionService:GetInstanceAddedSignal("Queue"):Connect(registerQueue)

Remotes.QueueAction.OnServerEvent:Connect(function(p, action, value)
	if action == "Sync" then
		Remotes.QueueState:FireClient(p, allStates())
		return
	end
	local q = queueOf[p]
	if not q or q.teleporting then return end

	if action == "Leave" then
		pushOut(p, q)
		removePlayer(p)
	elseif q.host ~= p then
		return
	elseif action == "SetMax" then
		if typeof(value) ~= "number" or q.countdown then return end
		q.max = math.clamp(math.floor(value), math.max(1, #q.players), GameConfig.MaxPlayers)
		refresh(q)
	elseif action == "Start" then
		if not q.countdown then
			task.spawn(startCountdown, q)
		end
	elseif action == "Cancel" then
		cancelCountdown(q)
		refresh(q)
	end
end)

Players.PlayerRemoving:Connect(removePlayer)

-- Kijk wie er in welke queue staat.
while true do
	task.wait(0.2)
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local inside
		if root then
			for _, q in queues do
				if isInside(q.zone, root.Position) then
					inside = q
					break
				end
			end
		end
		local current = queueOf[p]
		if current and current ~= inside and not current.teleporting then
			removePlayer(p)
			current = nil
		end
		if inside and not current then
			if inside.teleporting or #inside.players >= inside.max then
				Remotes.QueueNotice:FireClient(p, inside.teleporting and "This crypt is sealed..." or "This crypt is full.")
				pushOut(p, inside)
			else
				addPlayer(p, inside)
			end
		end
	end
end
