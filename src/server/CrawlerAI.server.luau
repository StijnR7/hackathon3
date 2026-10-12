-- Crawler-AI: kruipt over vloer, muren en plafond richting de dichtstbijzijnde speler.
-- De server bepaalt alleen waar het lijf is; de poten worden op de client geanimeerd (CrawlerAnimator).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("CrawlerConfig"))
local template = Shared:WaitForChild("Monsters"):WaitForChild("Crawler")

local CLIMB_PROBE = 3 -- hoe ver vooruit we naar een muur zoeken
local PROBE_HEIGHT = 2 -- hoogte van de vooruit-straal boven het oppervlak

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
	self.model = model
	self.body = body
	-- body.CFrame = pivot * bodyOffset
	self.bodyOffset = body.PivotOffset:Inverse()
	local head = body:FindFirstChild("Head", true) :: Bone
	self.headLocal = (body.CFrame * body.PivotOffset):PointToObjectSpace(head.WorldPosition)

	self.pos = spawnCFrame.Position
	self.visPos = self.pos
	self.up = Vector3.yAxis
	self.visUp = self.up
	self.look = project(spawnCFrame.LookVector, self.up).Unit
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
	self.pos += self.up * 1.5
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
	if offSurface < 6 or along > 12 + offSurface then
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
	self.up = self.up:Lerp(Vector3.yAxis, math.min(1, dt * 3)).Unit
	if hit then
		-- grijpt elk oppervlak vast, ook een muur
		self.falling = false
		self.velocity = Vector3.zero
		self.pos = hit.Position
		self.up = hit.Normal
		local look = project(self.look, self.up)
		self.look = look.Magnitude > 0.1 and look.Unit or project(Vector3.yAxis, self.up).Unit
	else
		self.pos += step
	end
end

function Crawler:updateCrawling(dt: number, targetPos: Vector3?)
	local up = self.up
	local desired
	if targetPos then
		local rel = targetPos - self.pos
		desired = project(rel, up)
		-- speler hoog boven ons en onbereikbaar over de vloer: eerst naar een muur
		if up.Y > 0.7 and rel:Dot(up) > 8 and desired.Magnitude < 25 then
			local wall = self:nearestWall()
			if wall then
				desired = project(wall - self.pos, up)
			end
		elseif math.abs(up.Y) < 0.7 and rel:Dot(up) < -2 then
			-- speler zit achter de muur waar we op hangen: omhoog en eroverheen
			local sideways = desired.Magnitude > 0.01 and desired.Unit * 0.5 or Vector3.zero
			desired = project(Vector3.yAxis, up) * 2 + sideways
		end
	else
		-- rondzwerven: langzaam slingerend
		local t = os.clock() + self.wanderSeed
		desired = CFrame.fromAxisAngle(up, math.noise(t * 0.3) * 2):VectorToWorldSpace(self.look)
	end
	if desired.Magnitude > 0.5 then
		self.look = rotateTowards(self.look, desired.Unit, up, Config.TurnSpeed * dt)
	end

	local speed = targetPos and Config.ChaseSpeed or Config.WalkSpeed
	local move = self.look * speed * dt

	-- muur (of plafond) voor ons: daarop overstappen
	local ahead = workspace:Raycast(self.pos + up * PROBE_HEIGHT, self.look * (move.Magnitude + CLIMB_PROBE), rayParams)
	if ahead and ahead.Normal:Dot(up) < 0.7 then
		self.pos = ahead.Position
		self.up = ahead.Normal
		self.look = project(up, self.up).Unit -- de oude "omhoog" wordt de nieuwe looprichting
		return
	end

	local newPos = self.pos + move
	local ground = workspace:Raycast(newPos + up * PROBE_HEIGHT, -up * (PROBE_HEIGHT + 3), rayParams)
	if ground then
		self.pos = ground.Position
		self.up = ground.Normal
		local look = project(self.look, self.up)
		if look.Magnitude > 0.1 then
			self.look = look.Unit
		end
		return
	end

	-- geen grond meer: over een bolle rand heen kruipen (bv. bovenkant van een muur)
	local wrap = workspace:Raycast(newPos - up * 1.5, -self.look * 4, rayParams)
	if wrap then
		self.pos = wrap.Position
		self.up = wrap.Normal
		self.look = project(-up, self.up).Unit
		return
	end

	self:startFalling()
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
	local origin = self.pos + self.up * 3
	for i = 0, 11 do
		local dir = CFrame.fromAxisAngle(self.up, i * math.pi / 6):VectorToWorldSpace(self.look)
		local hit = workspace:Raycast(origin, dir * 150, rayParams)
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

	if self.pos.Y < workspace.FallenPartsDestroyHeight + 20 then
		self.pos = self.spawnPos
		self.velocity = Vector3.zero
	end

	-- vloeiend naar nieuwe oppervlakken draaien
	local alpha = 1 - math.exp(-Config.SurfaceAlignSpeed * dt)
	self.visUp = self.visUp:Lerp(self.up, alpha).Unit
	self.visPos = self.visPos:Lerp(self.pos, 1 - math.exp(-20 * dt))
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
