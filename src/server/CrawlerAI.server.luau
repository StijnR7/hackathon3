-- Crawler-AI: loopt naar de dichtstbijzijnde speler. Komt hij tegen een muur of plafond aan,
-- dan klapt hij er meteen op (geen vloeiende overgang). De loopanimatie speelt op de client.
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("CrawlerConfig"))
local template = Shared:WaitForChild("Monsters"):WaitForChild("Crawler")

local PROBE_HEIGHT = Config.ProbeHeight

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function refreshFilter()
	local list = CollectionService:GetTagged(Config.Tag)
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	rayParams.FilterDescendantsInstances = list
end

local function project(v: Vector3, normal: Vector3): Vector3
	return v - normal * v:Dot(normal)
end

-- Richting langs het vlak met normaal `up`; valt terug op `fallback` en daarna op een willekeurige
-- richting langs het vlak (nooit een nulvector → geen NaN).
local function tangent(v: Vector3, up: Vector3, fallback: Vector3?): Vector3
	local t = project(v, up)
	if t.Magnitude > 0.1 then
		return t.Unit
	end
	if fallback then
		t = project(fallback, up)
		if t.Magnitude > 0.1 then
			return t.Unit
		end
	end
	return up:Cross(math.abs(up.X) < 0.9 and Vector3.xAxis or Vector3.zAxis).Unit
end

local function isNaN(v: Vector3): boolean
	return v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z
end

-- CFrame met `up` als UpVector en `look` (zo goed mogelijk) als LookVector
local function frameFrom(pos: Vector3, up: Vector3, look: Vector3): CFrame
	local right = tangent(look, up):Cross(up).Unit
	return CFrame.fromMatrix(pos, right, up, -up:Cross(right).Unit)
end

local function rotateTowards(look: Vector3, desired: Vector3, up: Vector3, maxAngle: number): Vector3
	local angle = math.atan2(look:Cross(desired):Dot(up), look:Dot(desired))
	angle = math.clamp(angle, -maxAngle, maxAngle)
	return CFrame.fromAxisAngle(up, angle):VectorToWorldSpace(look)
end

local function alive(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root :: BasePart
	end
	return nil, nil
end

local Crawler = {}
Crawler.__index = Crawler

function Crawler.new(spawnCFrame: CFrame)
	local self = setmetatable({}, Crawler)
	local model = template:Clone()
	local body = model:WaitForChild("Body") :: MeshPart
	model.PrimaryPart = body
	model:ScaleTo(Config.Scale)
	self.model = model
	self.body = body
	-- body.CFrame = pivot * bodyOffset
	self.bodyOffset = body.PivotOffset:Inverse()
	local pivot = body.CFrame * body.PivotOffset
	local head = body:FindFirstChild("Head", true) :: Bone
	self.headLocal = pivot:PointToObjectSpace(head.WorldPosition)
	-- hoe ver de kop vóór het draaipunt zit: zo vroeg klappen we op een muur
	self.front = 0
	for _, b in body:GetDescendants() do
		if b:IsA("Bone") then
			self.front = math.max(self.front, -pivot:PointToObjectSpace(b.WorldPosition).Z)
		end
	end
	self.path = PathfindingService:CreatePath({
		AgentRadius = Config.PathRadius,
		AgentHeight = 3,
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = 3,
	})

	self.pos = spawnCFrame.Position
	self.up = Vector3.yAxis
	self.look = tangent(spawnCFrame.LookVector, self.up)
	self.falling = true
	self.velocity = Vector3.zero
	self.lastCatch = 0
	self.bestDistance = math.huge
	self.progressTimer = 0

	body.Anchored = false
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false

	local attachment = Instance.new("Attachment")
	attachment.Name = "DriveAttachment"
	attachment.Parent = body
	local alignPos = Instance.new("AlignPosition")
	alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPos.Attachment0 = attachment
	alignPos.RigidityEnabled = true
	alignPos.Parent = body
	local alignRot = Instance.new("AlignOrientation")
	alignRot.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignRot.Attachment0 = attachment
	alignRot.RigidityEnabled = true
	alignRot.Parent = body
	self.alignPos = alignPos
	self.alignRot = alignRot

	local frame = frameFrom(self.pos, self.up, self.look)
	model:PivotTo(frame)
	self:applyFrame(frame)
	CollectionService:AddTag(model, Config.Tag)
	model.Parent = workspace
	body:SetNetworkOwner(nil)
	return self
end

function Crawler:applyFrame(frame: CFrame)
	local bodyCFrame = frame * self.bodyOffset
	self.alignPos.Position = bodyCFrame.Position
	self.alignRot.CFrame = bodyCFrame
end

function Crawler:findTarget(): (Player?, Vector3?)
	local best, bestPos, bestDist = nil, nil, Config.DetectRange
	for _, player in Players:GetPlayers() do
		local _, root = alive(player)
		if root then
			local dist = (root.Position - self.pos).Magnitude
			if dist < bestDist then
				best, bestPos, bestDist = player, root.Position, dist
			end
		end
	end
	return best, bestPos
end

-- Klapt meteen op een nieuw vlak (muur, plafond, vloer)
function Crawler:snapTo(hit: RaycastResult, newLook: Vector3)
	self.pos = hit.Position
	self.up = hit.Normal
	self.look = tangent(newLook, self.up, self.look)
end

function Crawler:startFalling()
	self.falling = true
	self.velocity = Vector3.zero
	-- los van het oppervlak, anders raakt de eerste straal meteen hetzelfde vlak
	self.pos += self.up * PROBE_HEIGHT
end

function Crawler:updateFalling(dt: number)
	self.velocity += Vector3.new(0, -Config.Gravity * dt, 0)
	local step = self.velocity * dt
	local hit = workspace:Raycast(self.pos, step + step.Unit * 0.5, rayParams)
	if hit then
		self.falling = false
		self.velocity = Vector3.zero
		self:snapTo(hit, self.look)
	else
		self.pos += step
		-- tijdens het vallen meteen rechtop
		self.up = Vector3.yAxis
		self.look = tangent(self.look, self.up)
	end
end

function Crawler:updatePath(targetPos: Vector3)
	if self.pathBusy or os.clock() - (self.pathTime or 0) < 0.5 then
		return
	end
	self.pathBusy = true
	local from = self.pos
	task.spawn(function()
		local ok = pcall(function()
			self.path:ComputeAsync(from, targetPos)
		end)
		if not (ok and self.path.Status == Enum.PathStatus.Success) then
			-- speler staat ergens bovenop: dan in elk geval naar het punt op onze hoogte eronder
			ok = pcall(function()
				self.path:ComputeAsync(from, Vector3.new(targetPos.X, from.Y, targetPos.Z))
			end)
		end
		if ok and self.path.Status == Enum.PathStatus.Success then
			self.waypoints = self.path:GetWaypoints()
			self.waypointIndex = 2
		else
			self.waypoints = nil
		end
		self.pathTime = os.clock()
		self.pathBusy = false
	end)
end

function Crawler:nextWaypoint(): Vector3?
	local waypoints = self.waypoints
	if not waypoints then
		return nil
	end
	while self.waypointIndex <= #waypoints do
		local position = waypoints[self.waypointIndex].Position
		if project(position - self.pos, self.up).Magnitude > 1.5 then
			return position
		end
		self.waypointIndex += 1
	end
	return nil
end

function Crawler:updateCrawling(dt: number, targetPos: Vector3?)
	local up = self.up
	local desired = self.look
	local waypoint
	if targetPos then
		local rel = targetPos - self.pos
		desired = project(rel, up)
		if up.Y > 0.7 then
			-- op de vloer: route via PathfindingService (deuren, om meubels heen)
			self:updatePath(targetPos)
			waypoint = self:nextWaypoint()
			if waypoint then
				desired = project(waypoint - self.pos, up)
			end
		elseif rel:Dot(up) < -2 then
			-- speler zit achter de muur/het plafond waar we op zitten: loslaten
			self:startFalling()
			return
		end
	end
	if desired.Magnitude > 0.5 then
		self.look = rotateTowards(self.look, desired.Unit, up, Config.TurnSpeed * dt)
	end

	local speed = targetPos and Config.ChaseSpeed or Config.WalkSpeed
	local move = self.look * speed * dt

	-- muur of plafond voor de kop: er meteen op klappen, de oude "omhoog" wordt de looprichting
	local probe = self.look * (move.Magnitude + self.front + Config.ClimbProbe)
	local ahead = workspace:Raycast(self.pos + up * PROBE_HEIGHT, probe, rayParams)
	local routeFirst = waypoint and ahead and (waypoint - self.pos).Magnitude < (ahead.Position - self.pos).Magnitude
	if ahead and ahead.Normal:Dot(up) < 0.7 and not routeFirst then
		self:snapTo(ahead, up)
		return
	end

	local newPos = self.pos + move
	local ground = workspace:Raycast(newPos + up * PROBE_HEIGHT, -up * (PROBE_HEIGHT + 3), rayParams)
	if ground then
		self:snapTo(ground, self.look)
		return
	end

	-- geen grond meer: over de rand heen klappen (bv. bovenkant van een muur)
	local wrap = workspace:Raycast(newPos - up * PROBE_HEIGHT, -self.look * (PROBE_HEIGHT * 3), rayParams)
	if wrap then
		self:snapTo(wrap, -up)
		return
	end

	self:startFalling()
end

function Crawler:checkProgress(dt: number, targetPos: Vector3?)
	if not targetPos or self.falling then
		self.bestDistance = math.huge
		self.progressTimer = 0
		return
	end
	local dist = (targetPos - self.pos).Magnitude
	if dist < self.bestDistance - 1 then
		self.bestDistance = dist
		self.progressTimer = 0
	else
		self.progressTimer += dt
		if self.progressTimer > Config.StuckTime then
			-- vast: loslaten (of op de vloer een willekeurige kant op draaien)
			self.progressTimer = 0
			self.bestDistance = math.huge
			if self.up.Y < 0.7 then
				self:startFalling()
			else
				self.look = CFrame.fromAxisAngle(self.up, (math.random() - 0.5) * math.pi):VectorToWorldSpace(self.look)
			end
		end
	end
end

function Crawler:checkCatch(frame: CFrame)
	local now = os.clock()
	if now - self.lastCatch < Config.CatchCooldown then
		return
	end
	local headPos = frame:PointToWorldSpace(self.headLocal)
	for _, player in Players:GetPlayers() do
		local humanoid, root = alive(player)
		if humanoid and root then
			local toHead = (root.Position - headPos).Magnitude
			local toBody = (root.Position - frame.Position).Magnitude
			if toHead < Config.CatchRange or toBody < Config.CatchRange then
				self.lastCatch = now
				self.model:SetAttribute("LastCatch", workspace:GetServerTimeNow())
				humanoid.Health = 0
			end
		end
	end
end

function Crawler:update(dt: number)
	local target, targetPos = self:findTarget()
	self.model:SetAttribute("Chasing", target ~= nil)
	self.model:SetAttribute("TargetUserId", target and target.UserId or 0)

	local before = self.pos
	if self.falling then
		self:updateFalling(dt)
	else
		-- op het plafond en speler (bijna) eronder: loslaten
		if targetPos and self.up.Y < -0.6 then
			local horizontal = project(targetPos - self.pos, self.up).Magnitude
			if horizontal < Config.CeilingDropRange and targetPos.Y < self.pos.Y then
				self:startFalling()
			end
		end
		if not self.falling then
			self:updateCrawling(dt, targetPos)
		end
	end
	self:checkProgress(dt, targetPos)

	if self.pos.Y < workspace.FallenPartsDestroyHeight + 50 or isNaN(self.pos) or isNaN(self.look) then
		-- uit de wereld gevallen of kapotgerekend: terug naar het begin
		self.pos = self.spawnPos
		self.up = Vector3.yAxis
		self.look = -Vector3.zAxis
		self.velocity = Vector3.zero
		self.falling = true
	end

	-- loopsnelheid voor de animatie op de client (studs/s langs het oppervlak)
	local walked = self.falling and 0 or project(self.pos - before, self.up).Magnitude / math.max(dt, 1e-3)
	self.model:SetAttribute("Speed", walked)

	local frame = frameFrom(self.pos, self.up, self.look)
	self:applyFrame(frame)
	self:checkCatch(frame)
end

local function spawnCFrame(): CFrame
	local marker = workspace:FindFirstChild("CrawlerSpawn", true)
	if marker and marker:IsA("BasePart") then
		return marker.CFrame
	end
	return CFrame.new(0, 5, -40)
end

local crawler

-- Workspace-attribuut "CrawlerEnabled" gaat vóór Config.Enabled (handig om zonder monster te testen)
local function isEnabled(): boolean
	local override = workspace:GetAttribute("CrawlerEnabled")
	if typeof(override) == "boolean" then
		return override
	end
	return Config.Enabled
end

local function applyEnabled()
	if isEnabled() and not crawler then
		refreshFilter()
		crawler = Crawler.new(spawnCFrame())
		crawler.spawnPos = crawler.pos
		print("[Server] Crawler gespawnd")
	elseif not isEnabled() and crawler then
		crawler.model:Destroy()
		crawler = nil
		print("[Server] Crawler uitgezet")
	end
end

workspace:GetAttributeChangedSignal("CrawlerEnabled"):Connect(applyEnabled)
applyEnabled()

RunService.Heartbeat:Connect(function(dt)
	if crawler then
		refreshFilter()
		crawler:update(math.min(dt, 0.1))
	end
end)
