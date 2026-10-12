-- Procedurele animatie voor de Crawler: IKControl per poot, diagonaal stappen,
-- werkt op elk oppervlak (vloer/muur/plafond) omdat alles relatief is aan het lijf.
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
		local tip, mid = bone(def.tip), bone(def.mid)
		local target = Instance.new("Attachment")
		target.Name = "CrawlerIKTarget"
		target.Parent = workspace.Terrain
		local pole = Instance.new("Attachment")
		pole.Name = "CrawlerIKPole"
		pole.Parent = workspace.Terrain

		local ik = Instance.new("IKControl")
		ik.Name = "IK_" .. def.tip
		ik.Type = Enum.IKControlType.Position
		ik.ChainRoot = bone(def.root)
		ik.EndEffector = tip
		ik.Target = target
		ik.Pole = pole
		ik.SmoothTime = 0
		ik.Parent = controller

		local restLocal = frame:PointToObjectSpace(tip.WorldPosition)
		local leg = {
			group = def.group,
			restLocal = restLocal,
			-- pool boven de elleboog/knie houdt de gewrichten hoog
			poleLocal = frame:PointToObjectSpace(mid.WorldPosition) + Vector3.new(0, 8, 0),
			target = target,
			pole = pole,
			planted = tip.WorldPosition,
			from = tip.WorldPosition,
			to = tip.WorldPosition,
			t = 0,
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

local function groundPoint(origin: Vector3, up: Vector3): Vector3?
	local hit = workspace:Raycast(origin + up * 6, -up * 14, rayParams)
	return hit and hit.Position
end

local function updateLegs(state, frame: CFrame, dt: number)
	local up = frame.UpVector
	local planar = state.velocity - up * state.velocity:Dot(up)
	local airborne = groundPoint(frame.Position, up) == nil

	local stepping = { false, false }
	for _, leg in state.legs do
		if leg.stepping then
			stepping[leg.group] = true
		end
	end

	local wantStep = { false, false }
	for _, leg in state.legs do
		local home = frame:PointToWorldSpace(leg.restLocal) + planar * Config.StepLead
		leg.ideal = groundPoint(home, up) or home
		local dist = (leg.ideal - leg.planted).Magnitude
		if airborne or dist > Config.MaxReach then
			-- in de lucht of te ver: poot hangt mee met het lijf
			leg.stepping = false
			leg.planted = home
		elseif not leg.stepping and dist > Config.StepDistance then
			wantStep[leg.group] = true
		end
	end

	for group = 1, 2 do
		local other = group == 1 and 2 or 1
		if wantStep[group] and not stepping[group] and not stepping[other] then
			for _, leg in state.legs do
				if leg.group == group and (leg.ideal - leg.planted).Magnitude > 0.5 then
					leg.stepping = true
					leg.t = 0
					leg.from = leg.planted
					leg.to = leg.ideal
				end
			end
			stepping[group] = true
		end
	end

	local speedFactor = math.clamp(planar.Magnitude / Config.WalkSpeed, 0.7, 2)
	for _, leg in state.legs do
		local pos = leg.planted
		if leg.stepping then
			leg.t += dt * speedFactor / Config.StepTime
			if leg.t >= 1 then
				leg.stepping = false
				leg.planted = leg.to
				pos = leg.to
			else
				local s = smoothstep(leg.t)
				pos = leg.from:Lerp(leg.to, s) + up * math.sin(leg.t * math.pi) * Config.StepHeight
			end
		end
		leg.target.WorldPosition = pos
		leg.pole.WorldPosition = frame:PointToWorldSpace(leg.poleLocal)
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
