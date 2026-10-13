-- Ronde-UI: doel bovenin (zekeringen / deur open / tijd), grote meldingen in het midden,
-- dood- en ontsnapt-scherm en meekijken met spelers die nog leven (klik = volgende speler).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local FONT = Font.new("rbxasset://fonts/families/SpecialElite.json")
local TITLE_FONT = Font.new("rbxasset://fonts/families/Creepster.json")

local state = nil
local spectateIndex = 1

local gui = Instance.new("ScreenGui")
gui.Name = "RoundUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local function label(name, size, position, textSize, font)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.FontFace = font or FONT
	l.TextSize = textSize
	l.TextColor3 = Color3.fromRGB(215, 210, 195)
	l.TextStrokeTransparency = 0.4
	l.TextWrapped = true
	l.Parent = gui
	return l
end

local objective = label("Objective", UDim2.new(0.8, 0, 0, 30), UDim2.new(0.5, 0, 0, 14), 22)
local timer = label("Timer", UDim2.new(0.3, 0, 0, 22), UDim2.new(0.5, 0, 0, 44), 18)
timer.TextColor3 = Color3.fromRGB(160, 150, 140)
local center = label("Center", UDim2.new(0.8, 0, 0, 120), UDim2.new(0.5, 0, 0.32, 0), 34)
center.TextTransparency = 1
center.TextStrokeTransparency = 1
local spectating = label("Spectating", UDim2.new(0.6, 0, 0, 24), UDim2.new(0.5, 0, 1, -60), 20)
spectating.Visible = false

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel = 0
overlay.ZIndex = 0
overlay.Parent = gui

-- ---------------------------------------------------------------- meldingen
local messageToken = 0
local function showMessage(text: string, kind: string)
	messageToken += 1
	local token = messageToken
	local big = kind == "big" or kind == "death" or kind == "escape" or kind == "end"
	center.Text = text
	center.TextSize = big and 40 or 26
	center.FontFace = (kind == "death" or kind == "escape" or kind == "end") and TITLE_FONT or FONT
	center.TextColor3 = kind == "death" and Color3.fromRGB(200, 25, 20)
		or kind == "escape" and Color3.fromRGB(230, 235, 255)
		or Color3.fromRGB(215, 210, 195)
	center.TextTransparency = 0
	center.TextStrokeTransparency = 0.4

	if kind == "death" then
		overlay.BackgroundColor3 = Color3.fromRGB(90, 0, 0)
		overlay.BackgroundTransparency = 0.2
		TweenService:Create(overlay, TweenInfo.new(3), { BackgroundTransparency = 1 }):Play()
	elseif kind == "escape" then
		overlay.BackgroundColor3 = Color3.new(1, 1, 1)
		overlay.BackgroundTransparency = 0
		TweenService:Create(overlay, TweenInfo.new(3), { BackgroundTransparency = 1 }):Play()
	end

	local duration = kind == "small" and 1.8 or (kind == "end" and 9 or 4)
	task.delay(duration, function()
		if token == messageToken then
			TweenService:Create(center, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

-- ---------------------------------------------------------------- doel bovenin
local function myEntry()
	return state and state.players and state.players[tostring(player.UserId)]
end

local function refreshObjective()
	if not state then
		objective.Text = ""
		timer.Text = ""
		return
	end
	local me = myEntry()
	if state.phase == "Waiting" then
		objective.Text = "Waiting for the others..."
	elseif state.phase == "Ended" or state.phase == "Ending" then
		objective.Text = "Returning to the lobby..."
	elseif state.doorOpen then
		objective.Text = "THE FRONT DOOR IS OPEN — GET OUT"
	else
		local text = string.format("Fuses in the fuse box: %d / %d", state.fusesPlaced, state.fusesTotal)
		if me and me.carrying > 0 then
			text ..= string.format("   •   carrying %d", me.carrying)
		end
		objective.Text = text
	end
	timer.Text = ""
end

local timeLeftAt, timeLeft = 0, nil
RunService.Heartbeat:Connect(function()
	if timeLeft and state and state.phase == "Playing" then
		local left = math.max(0, timeLeft - (os.clock() - timeLeftAt))
		timer.Text = string.format("%d:%02d", left // 60, left % 60)
	else
		timer.Text = ""
	end
end)

-- ---------------------------------------------------------------- meekijken
local function aliveOthers(): { Player }
	local list = {}
	if not state then
		return list
	end
	for _, other in Players:GetPlayers() do
		local entry = state.players[tostring(other.UserId)]
		local humanoid = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
		if other ~= player and entry and entry.status == "alive" and humanoid and humanoid.Health > 0 then
			table.insert(list, other)
		end
	end
	return list
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
		spectateIndex += 1
	end
end)

RunService:BindToRenderStep("RoundSpectate", Enum.RenderPriority.Camera.Value + 3, function()
	local me = myEntry()
	if not me or me.status == "alive" then
		spectating.Visible = false
		return
	end
	local others = aliveOthers()
	if #others == 0 then
		spectating.Visible = false
		return
	end
	local target = others[(spectateIndex - 1) % #others + 1]
	local head = target.Character and target.Character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	-- over de schouder, iets achter en boven het hoofd
	local look = head.CFrame.LookVector
	local eye = head.Position - look * 5 + Vector3.new(0, 1.5, 0)
	camera.CFrame = CFrame.lookAt(eye, head.Position + look * 4)
	spectating.Text = "Spectating " .. target.DisplayName .. "   (click to switch)"
	spectating.Visible = true
end)

-- ---------------------------------------------------------------- remotes
Remotes.RoundState.OnClientEvent:Connect(function(newState)
	state = newState
	if newState.timeLeft then
		timeLeft, timeLeftAt = newState.timeLeft, os.clock()
	else
		timeLeft = nil
	end
	refreshObjective()
end)

Remotes.RoundMessage.OnClientEvent:Connect(function(text, kind)
	showMessage(text, kind)
end)
