-- Crawler-AI: kruipt over vloer, muren en plafond richting de dichtstbijzijnde speler.
-- De server bepaalt alleen waar het lijf is; de poten worden op de client geanimeerd (CrawlerAnimator).
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

-- Draait vector `v` een fractie `alpha` richting `target` (werkt ook als ze tegengesteld zijn)
local function turnTowards(v: Vector3, target: Vector3, alpha: number, axisFallback: Vector3): Vector3
	local axis = v:Cross(target)
	local angle = math.atan2(axis.Magnitude, v:Dot(target))
	if angle < 1e-4 then
		return target
	end
	axis = axis.Magnitude > 1e-4 and axis.Unit or axisFallback
	return CFrame.fromAxisAngle(axis, angle * alpha):VectorToWorldSpace(v).Unit
end

local function isNaN(v: Vector3): boolean
	return v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z
end

-- Bouwt een CFrame met `up` als UpVector en `look` (zo goed mogelijk) als LookVector
local function frameFrom(pos: Vector3, up: Vector3, look: Vector3): CFrame
	local right = look:Cross(up)
	if right.Magnitude < 1e-3 then
		right = up:Cross(math.abs(up.Y) < 0.9 and Vector3.yAxis or Vector3.zAxis)
	end
	right = right.Unit
	look = up:Cross(right).Unit
	return CFrame.fromMatrix(pos, right, up, -look)
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
	local head = body:FindFirstChild("Head", true) :: Bone
	local pivot = body.CFrame * body.PivotOffset
	self.headLocal = pivot:PointToObjectSpace(head.WorldPosition)
	-- hoe ver het lijf voor en achter het draaipunt uitsteekt (voor overgangen naar muren)
	self.front, self.rear = 0, 0
	for _, b in body:GetDescendants() do
		if b:IsA("Bone") then
			local z = pivot:PointToObjectSpace(b.WorldPosition).Z
			self.front = math.max(self.front, -z)
			self.rear = math.max(self.rear, z)
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
	self.visPos = self.pos
	self.up = Vector3.yAxis
	self.visUp = self.up
	self.look = tangent(spawnCFrame.LookVector, self.up)
	self.falling = true
	self.velocity = Vector3.zero
	self.lastCatch = 0
	self.bestDistance = math.huge
	self.progressTimer = 0
	self.wanderSeed = math.random() * 100

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
	self.frame = frame
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

function Crawler:startFalling(velocity: Vector3?)
	self.falling = true
	self.velocity = velocity or Vector3.zero
	-- los van het oppervlak, anders raakt de eerste straal meteen hetzelfde vlak
	self.pos += self.up * PROBE_HEIGHT
end

-- Springt als de speler niet over het oppervlak te bereiken is (hoger/lager of los van de muur)
function Crawler:tryLeap(targetPos: Vector3): boolean
	local now = os.clock()
	if self.lastLeap and now - self.lastLeap < Config.LeapCooldown then
		return false
	end
	local rel = targetPos - self.pos
	if rel.Magnitude > Config.LeapRange then
		return false
	end
	local offSurface = rel:Dot(self.up) -- hoe ver de speler "boven" ons oppervlak zit
	local along = project(rel, self.up).Magnitude
	if offSurface < Config.LeapMinHeight or along > Config.LeapRange * 0.6 + offSurface then
		return false
	end
	self.lastLeap = now
	local flightTime = math.clamp(rel.Magnitude / 45, 0.35, 1)
	local velocity = rel / flightTime + Vector3.new(0, 0.5 * Config.Gravity * flightTime, 0)
	self:startFalling(velocity)
	return true
end

function Crawler:updateFalling(dt: number)
	self.velocity += Vector3.new(0, -Config.Gravity * dt, 0)
	local step = self.velocity * dt
	local hit = workspace:Raycast(self.pos, step + step.Unit * 0.5, rayParams)
	-- tijdens het vallen draait het lijf weer rechtop
	self.up = turnTowards(self.up, Vector3.yAxis, math.min(1, dt * 3), self.look:Cross(self.up).Unit)
	if hit then
		-- grijpt elk oppervlak vast, ook een muur
		self.falling = false
		self.velocity = Vector3.zero
		self.pos = hit.Position
		self.up = hit.Normal
		self.look = tangent(self.look, self.up, self.velocity)
	else
		self.pos += step
	end
end

function Crawler:updateCrawling(dt: number, targetPos: Vector3?)
	local up = self.up
	local desired
	local waypoint
	local wandering = targetPos == nil
	if targetPos then
		local rel = targetPos - self.pos
		desired = project(rel, up)
		if up.Y > 0.7 then
			-- op de vloer: route via PathfindingService (deuren, om meubels heen)
			self:updatePath(targetPos)
			waypoint = self:nextWaypoint()
			if waypoint then
				desired = project(waypoint - self.pos, up)
			elseif self.noPath then
				if rel:Dot(up) > Config.LeapMinHeight and desired.Magnitude < Config.LeapRange then
					-- speler staat ergens bovenop (kast, bed): via de dichtstbijzijnde muur
					local wall = self:nearestWall()
					if wall then
						desired = project(wall - self.pos, up)
					end
				elseif desired.Magnitude > Config.LeapRange then
					-- onbereikbaar (andere verdieping, dichte deur): rondsluipen tot er een route is
					wandering = true
				end
			end
		elseif rel:Dot(up) < -2 then
			-- speler zit achter de muur/het plafond waar we op hangen: loslaten
			self:startFalling()
			return
		end
	end
	if wandering then
		-- rondzwerven: langzaam slingerend, met een voorkeur richting de speler (als die er is)
		local t = os.clock() + self.wanderSeed
		local base = desired and desired.Magnitude > 0.5 and desired.Unit or self.look
		desired = CFrame.fromAxisAngle(up, math.noise(t * 0.3) * (targetPos and 1.2 or 2)):VectorToWorldSpace(base)
	end
	if desired.Magnitude > 0.5 then
		self.look = rotateTowards(self.look, desired.Unit, up, Config.TurnSpeed * dt)
	end

	local speed = wandering and Config.WalkSpeed or Config.ChaseSpeed
	local move = self.look * speed * dt

	-- muur (of plafond) voor ons: daarop overstappen
	-- vanaf het draaipunt tot voorbij de kop kijken, anders steekt de kop al in de muur
	local probe = self.look * (move.Magnitude + self.front + Config.ClimbProbe)
	local ahead = workspace:Raycast(self.pos + up * PROBE_HEIGHT, probe, rayParams)
	if not ahead then
		-- iets op lijfhoogte (tafelblad, plank): niet eronder door maar eroverheen.
		-- Een blok i.p.v. een straal, anders glipt een dun tafelblad ertussendoor.
		local span = Config.BodyHeight - PROBE_HEIGHT
		local box = frameFrom(self.pos + up * (PROBE_HEIGHT + span / 2), up, self.look)
		ahead = workspace:Blockcast(box, Vector3.new(1.5, span, 0.2), probe, rayParams)
	end
	-- volgen we een route en ligt het volgende punt dichterbij dan de muur? dan niet klimmen
	local wallFirst = not waypoint or (ahead and (ahead.Position - self.pos).Magnitude < (waypoint - self.pos).Magnitude)
	if ahead and ahead.Normal:Dot(up) < 0.7 and wandering then
		-- tijdens rondsluipen niet de muur op, maar een andere kant op draaien
		local turn = (math.random() < 0.5 and -1 or 1) * (math.pi * (0.5 + math.random() * 0.4))
		self.look = CFrame.fromAxisAngle(up, turn):VectorToWorldSpace(self.look)
		return
	end
	if ahead and ahead.Normal:Dot(up) < 0.7 and wallFirst then
		-- niet heen en weer flippen in een hoek (muur ↔ plafond): net vandaan gekomen? dan loeren
		local justLeft = self.previousUp and ahead.Normal:Dot(self.previousUp) > 0.9
			and os.clock() - self.lastClimb < Config.ClimbBackDelay
		if not justLeft then
			self:climbOnto(ahead, up)
		end
		return
	end

	local newPos = self.pos + move
	local ground = workspace:Raycast(newPos + up * PROBE_HEIGHT, -up * (PROBE_HEIGHT + 3), rayParams)
	if ground then
		self.pos = ground.Position
		self.up = ground.Normal
		self.look = tangent(self.look, self.up)
		return
	end

	-- geen grond meer: over een bolle rand heen kruipen (bv. bovenkant van een muur)
	local wrap = workspace:Raycast(newPos - up * PROBE_HEIGHT, -self.look * (PROBE_HEIGHT * 3), rayParams)
	if wrap then
		self.pos = wrap.Position
		self.up = wrap.Normal
		self.look = tangent(-up, self.up, self.look)
		return
	end

	self:startFalling()
end

-- Stapt over op een nieuw vlak (muur/plafond). Het draaipunt komt zo ver op het nieuwe vlak
-- dat het achterlijf niet meer in het oude vlak steekt.
function Crawler:climbOnto(hit: RaycastResult, oldUp: Vector3)
	local newUp = hit.Normal
	local along = tangent(oldUp, newUp, self.look) -- de oude "omhoog" wordt de nieuwe looprichting
	local pos = hit.Position
	for _, distance in { self.rear, self.rear * 0.5 } do
		local candidate = hit.Position + along * distance
		local check = workspace:Raycast(candidate + newUp * 0.5, -newUp * 1.5, rayParams)
		if check and check.Normal:Dot(newUp) > 0.9 then
			pos = check.Position
			break
		end
	end
	self.previousUp = self.up
	self.lastClimb = os.clock()
	self.pos = pos
	self.up = newUp
	self.look = along
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
		if ok and self.path.Status == Enum.PathStatus.Success then
			self.waypoints = self.path:GetWaypoints()
			self.waypointIndex = 2
			self.noPath = false
		else
			self.waypoints = nil
			self.noPath = true
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

-- Dichtstbijzijnde muur rondom (gecached, want 12 stralen per frame is zonde)
function Crawler:nearestWall(): Vector3?
	local now = os.clock()
	if self.wallCacheTime and now - self.wallCacheTime < 1 then
		return self.wallCache
	end
	self.wallCacheTime = now
	self.wallCache = nil
	local bestDist = math.huge
	local origin = self.pos + self.up * PROBE_HEIGHT * 1.5
	for i = 0, 11 do
		local dir = CFrame.fromAxisAngle(self.up, i * math.pi / 6):VectorToWorldSpace(self.look)
		local hit = workspace:Raycast(origin, dir * 80, rayParams)
		if hit and math.abs(hit.Normal:Dot(self.up)) < 0.3 then
			local dist = (hit.Position - origin).Magnitude
			if dist < bestDist then
				bestDist = dist
				self.wallCache = hit.Position
			end
		end
	end
	return self.wallCache
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
		if not self.falling and not (targetPos and self:tryLeap(targetPos)) then
			self:updateCrawling(dt, targetPos)
		end
	end
	self:checkProgress(dt, targetPos)

	if self.pos.Y < workspace.FallenPartsDestroyHeight + 50 or isNaN(self.pos) or isNaN(self.look) or isNaN(self.visUp) then
		-- uit de wereld gevallen of kapotgerekend: terug naar het begin
		self.pos = self.spawnPos
		self.visPos = self.spawnPos
		self.up = Vector3.yAxis
		self.visUp = Vector3.yAxis
		self.look = -Vector3.zAxis
		self.velocity = Vector3.zero
		self.falling = true
	end

	-- vloeiend naar nieuwe oppervlakken draaien
	local alpha = 1 - math.exp(-Config.SurfaceAlignSpeed * dt)
	self.visUp = turnTowards(self.visUp, self.up, alpha, self.look:Cross(self.visUp).Unit)
	self.visPos = self.visPos:Lerp(self.pos, 1 - math.exp(-Config.SurfaceAlignSpeed * 1.5 * dt))
	local frame = frameFrom(self.visPos, self.visUp, self.look)
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

refreshFilter()
local crawler = Crawler.new(spawnCFrame())
crawler.spawnPos = crawler.pos

RunService.Heartbeat:Connect(function(dt)
	refreshFilter()
	crawler:update(math.min(dt, 0.1))
end)

print("[Server] Crawler gespawnd")
