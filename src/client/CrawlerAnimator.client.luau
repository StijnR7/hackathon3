-- Procedurele animatie voor de Crawler: IKControl per poot, diagonaal stappen,
-- werkt op elk oppervlak (vloer/muur/plafond) omdat alles relatief is aan het lijf.
-- Poten mogen nooit door iets heen: een poot die geblokkeerd raakt stapt in z'n eentje
-- naar het blok toe, de rest blijft staan.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CrawlerConfig"))

-- group: poten in dezelfde groep stappen samen (diagonaal paar)
local LEGS = {
	{ root = "UpperArm.L", mid = "LowerArm.L", tip = "Hand.L", group = 1 },
	{ root = "UpperArm.R", mid = "LowerArm.R", tip = "Hand.R", group = 2 },
	{ root = "Thigh.L", mid = "Shin.L", tip = "Foot.L", group = 2 },
	{ root = "Thigh.R", mid = "Shin.R", tip = "Foot.R", group = 1 },
}

local TURN_FREEZE_RATE = 1.2 -- rad/s: draait het lijf sneller (overgang naar muur/plafond), dan blijven de poten staan
local SOLO_STEP_TIME = Config.StepTime * 0.4 -- losse correctiestap is snel, zodat een poot kort in iets zit

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

local function raycast(from: Vector3, to: Vector3): RaycastResult?
	local dir = to - from
	if dir.Magnitude < 1e-3 then
		return nil
	end
	return workspace:Raycast(from, dir, rayParams)
end

local function smoothstep(t: number): number
	return t * t * (3 - 2 * t)
end

local active = {}

local function setup(model: Model)
	local body = model:WaitForChild("Body", 10) :: MeshPart?
	local controller = model:WaitForChild("AnimationController", 10)
	if not body or not controller or active[model] then
		return
	end
	if not controller:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = controller
	end

	local function bone(name: string): Bone
		return body:FindFirstChild(name, true) :: Bone
	end

	local frame = body.CFrame * body.PivotOffset
	local state = {
		model = model,
		body = body,
		legs = {},
		instances = {},
		lastPos = frame.Position,
		lastUp = frame.UpVector,
		velocity = Vector3.zero,
		jaw = bone("Jaw"),
		head = bone("Head"),
		neck = bone("Neck1"),
		chest = bone("Chest"),
		headRoll = 0,
		headRollTarget = 0,
		nextTwitch = 0,
		time = math.random() * 10,
	}

	for _, def in LEGS do
		local root, mid, tip = bone(def.root), bone(def.mid), bone(def.tip)
		local target = Instance.new("Attachment")
		target.Name = "CrawlerIKTarget"
		target.Parent = workspace.Terrain
		local pole = Instance.new("Attachment")
		pole.Name = "CrawlerIKPole"
		pole.Parent = workspace.Terrain

		local ik = Instance.new("IKControl")
		ik.Name = "IK_" .. def.tip
		ik.Type = Enum.IKControlType.Position
		ik.ChainRoot = root
		ik.EndEffector = tip
		ik.Target = target
		ik.Pole = pole
		ik.SmoothTime = 0
		ik.Parent = controller

		local midLocal = frame:PointToObjectSpace(mid.WorldPosition)
		local leg = {
			group = def.group,
			root = root,
			mid = mid,
			restLocal = frame:PointToObjectSpace(tip.WorldPosition),
			hipHeight = (root.WorldPosition - tip.WorldPosition):Dot(frame.UpVector),
			reach = (mid.WorldPosition - root.WorldPosition).Magnitude + (tip.WorldPosition - mid.WorldPosition).Magnitude,
			-- pool boven de elleboog/knie houdt de gewrichten hoog
			poleLocal = midLocal,
			poleHeight = midLocal.Y * 0.6,
			polePush = Vector3.zero, -- duwt de elleboog/knie weg van iets waar het bovenbeen in zit
			target = target,
			pole = pole,
			planted = tip.WorldPosition,
			current = tip.WorldPosition,
			from = tip.WorldPosition,
			to = tip.WorldPosition,
			t = 0,
			duration = Config.StepTime,
			stepping = false,
		}
		table.insert(state.legs, leg)
		table.insert(state.instances, target)
		table.insert(state.instances, pole)
		table.insert(state.instances, ik)
	end

	active[model] = state
end

local function teardown(model: Model)
	local state = active[model]
	if not state then
		return
	end
	for _, inst in state.instances do
		inst:Destroy()
	end
	active[model] = nil
end

-- Zoekt een plek voor de voet bij `home`, zonder door iets heen te gaan.
local function findFoot(leg, up: Vector3, home: Vector3): Vector3?
	local hip = leg.root.WorldPosition
	local above = home + up * leg.hipHeight
	-- iets tussen het lijf en de plek (bv. een kast naast ons): voet gaat op dat blok
	local spot
	local blocked = raycast(hip, above)
	if blocked then
		spot = blocked.Position + blocked.Normal * Config.FootClearance
	else
		local ground = raycast(above, home - up * leg.hipHeight)
		if not ground then
			return nil
		end
		spot = ground.Position + ground.Normal * Config.FootClearance
	end
	-- plek moet ook vanaf de elleboog/knie bereikbaar zijn, anders gaat de onderarm om een hoek heen
	local corner = raycast(leg.mid.WorldPosition, spot)
	if corner and (corner.Position - spot).Magnitude > Config.FootClearance * 2 then
		spot = corner.Position + corner.Normal * Config.FootClearance
	end
	-- buiten beenbereik: de heup zat zelf in iets en de straal "zag" een vlak erachter
	if (spot - hip).Magnitude > leg.reach * 1.05 then
		return nil
	end
	return spot
end

-- Gaat het onderbeen (elleboog/knie → voet) ergens doorheen? Dan geeft dit het punt op het blok.
local function legBlocked(leg, foot: Vector3): Vector3?
	local hit = raycast(leg.mid.WorldPosition, foot)
	if hit and (hit.Position - foot).Magnitude > Config.FootClearance * 2 then
		return hit.Position + hit.Normal * Config.FootClearance
	end
	hit = raycast(leg.root.WorldPosition, leg.mid.WorldPosition)
	if hit then
		-- bovenbeen zit in iets: elleboog/knie ervan wegduwen en voet opnieuw neerzetten
		leg.polePush = hit.Normal * 3
		return nil, true
	end
	return nil
end

local function startStep(leg, to: Vector3, duration: number)
	leg.stepping = true
	leg.t = 0
	leg.duration = duration
	leg.from = leg.current
	leg.to = to
end

local function updateLegs(state, frame: CFrame, dt: number)
	local up = frame.UpVector
	local turnRate = dt > 0 and math.acos(math.clamp(up:Dot(state.lastUp), -1, 1)) / dt or 0
	state.lastUp = up
	-- lijf draait naar een nieuw vlak: poten blijven staan tot het lijf stil ligt
	local turning = turnRate > TURN_FREEZE_RATE
	local planar = state.velocity - up * state.velocity:Dot(up)
	local airborne = raycast(frame.Position + up * 2, frame.Position - up * 2) == nil

	local stepping = { false, false }
	for _, leg in state.legs do
		if leg.stepping then
			stepping[leg.group] = true
		end
	end

	local wantStep = { false, false }
	for _, leg in state.legs do
		local home = frame:PointToWorldSpace(leg.restLocal) + planar * Config.StepLead
		local spot = not turning and findFoot(leg, up, home) or nil
		leg.ideal = spot or leg.planted

		if airborne then
			-- in de lucht: poot hangt mee met het lijf, maar nooit door iets heen
			leg.stepping = false
			local hit = raycast(leg.root.WorldPosition, home)
			leg.planted = hit and hit.Position + hit.Normal * Config.FootClearance or home
		elseif not leg.stepping then
			-- deze controle mag altijd, ook als het lijf aan het draaien is
			local blockedSpot, upperBlocked = legBlocked(leg, leg.planted)
			if blockedSpot then
				-- alleen deze poot: op het blok zetten waar hij doorheen ging
				startStep(leg, blockedSpot, SOLO_STEP_TIME)
			elseif not spot then
				-- lijf draait of geen geldige plek: blijven staan
			elseif upperBlocked then
				startStep(leg, spot, SOLO_STEP_TIME)
			else
				local dist = (spot - leg.planted).Magnitude
				if dist > Config.MaxReach then
					startStep(leg, spot, SOLO_STEP_TIME)
				elseif dist > Config.StepDistance then
					wantStep[leg.group] = true
				end
			end
		end
	end

	for group = 1, 2 do
		local other = group == 1 and 2 or 1
		if wantStep[group] and not stepping[group] and not stepping[other] then
			for _, leg in state.legs do
				if leg.group == group and not leg.stepping and (leg.ideal - leg.planted).Magnitude > 0.3 then
					startStep(leg, leg.ideal, Config.StepTime)
				end
			end
		end
	end

	local speedFactor = math.clamp(planar.Magnitude / Config.WalkSpeed, 0.8, 2.5)
	for _, leg in state.legs do
		local pos = leg.planted
		if leg.stepping then
			leg.t += dt * speedFactor / leg.duration
			if leg.t >= 1 then
				leg.stepping = false
				leg.planted = leg.to
				pos = leg.to
			else
				local s = smoothstep(leg.t)
				pos = leg.from:Lerp(leg.to, s) + up * math.sin(leg.t * math.pi) * Config.StepHeight
				-- onderweg iets geraakt: daar neerzetten in plaats van erdoorheen. Vanaf de heup
				-- casten (die zit altijd aan de goede kant), niet vanaf de vorige voetpositie: die kan
				-- na een landing ónder een vlak liggen en zou dan aan de onderkant blijven haken.
				local hit = raycast(leg.root.WorldPosition, pos)
				if hit then
					pos = hit.Position + hit.Normal * Config.FootClearance
					leg.stepping = false
					leg.planted = pos
				end
			end
		end
		leg.current = pos
		leg.target.WorldPosition = pos

		-- pool boven de elleboog/knie, maar lager als er een plafond/tafel boven zit
		local poleBase = frame:PointToWorldSpace(leg.poleLocal)
		local poleHeight = leg.poleHeight
		local ceiling = raycast(poleBase, poleBase + up * poleHeight)
		if ceiling then
			poleHeight = math.max(0, (ceiling.Position - poleBase).Magnitude - 0.5)
		end
		leg.polePush *= math.exp(-dt * 2)
		leg.pole.WorldPosition = poleBase + up * poleHeight + leg.polePush
	end
end

local function updateExtras(state, dt: number)
	local model = state.model
	local chasing = model:GetAttribute("Chasing") == true
	state.time += dt
	local t = state.time

	-- kaak: hangt open, klappert tijdens jagen, wijd open net na een vangst
	local lastCatch = model:GetAttribute("LastCatch")
	local sinceCatch = lastCatch and (workspace:GetServerTimeNow() - lastCatch) or math.huge
	local jawOpen = 0.15 + (chasing and 0.35 * math.abs(math.sin(t * 6)) or 0.05 * math.sin(t))
	if sinceCatch < 0.6 then
		jawOpen = 0.9
	end
	state.jaw.Transform = CFrame.Angles(jawOpen, 0, 0)

	-- hoofd: af en toe een schokkerige kanteling (rol om het bot)
	if t > state.nextTwitch then
		state.nextTwitch = t + 0.4 + math.random() * (chasing and 1 or 2.5)
		state.headRollTarget = (math.random() - 0.5) * (chasing and 1.4 or 0.8)
	end
	state.headRoll += (state.headRollTarget - state.headRoll) * math.min(1, dt * 25)
	state.head.Transform = CFrame.Angles(0, state.headRoll, 0)

	-- ademhaling / sluipende golf door nek en borst
	state.neck.Transform = CFrame.Angles(math.sin(t * 2.1) * 0.06, 0, 0)
	state.chest.Transform = CFrame.Angles(math.sin(t * 1.3) * 0.04, 0, 0)
end

RunService.RenderStepped:Connect(function(dt)
	if next(active) == nil then
		return
	end
	refreshFilter()
	for model, state in active do
		if not model.Parent then
			teardown(model)
			continue
		end
		local frame = state.body.CFrame * state.body.PivotOffset
		if dt > 0 then
			local v = (frame.Position - state.lastPos) / dt
			state.velocity = state.velocity:Lerp(v, math.min(1, dt * 10))
		end
		state.lastPos = frame.Position
		updateLegs(state, frame, dt)
		updateExtras(state, dt)
	end
end)

CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(function(model)
	task.spawn(setup, model)
end)
CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(teardown)
for _, model in CollectionService:GetTagged(Config.Tag) do
	task.spawn(setup, model)
end
