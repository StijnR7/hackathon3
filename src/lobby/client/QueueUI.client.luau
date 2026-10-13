-- Queue-UI: paneel zodra je in een queue staat. Host kiest aantal spelers en start; daarna countdown + fade.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local SoundIds = require(ReplicatedStorage.Shared.SoundIds)

local player = Players.LocalPlayer

local TITLE_FONT = Font.new("rbxasset://fonts/families/Creepster.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/SpecialElite.json")
local RED = Color3.fromRGB(175, 20, 20)
local DARK_RED = Color3.fromRGB(70, 12, 12)
local BONE = Color3.fromRGB(215, 205, 188)
local PANEL = Color3.fromRGB(13, 10, 10)

local function new(class, props, children)
	local inst = Instance.new(class)
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function stroke(color, thickness)
	return new("UIStroke", { Color = color, Thickness = thickness or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function playSound(id, volume)
	if not id or id == "" then return end
	local s = new("Sound", { SoundId = id, Volume = volume or 0.6, Parent = SoundService })
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
end

local heartbeat = new("Sound", { SoundId = SoundIds.Heartbeat, Volume = 1, Looped = true, Parent = SoundService })

local gui = new("ScreenGui", {
	Name = "QueueUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Paneel
local HIDDEN_POS = UDim2.new(0.5, 0, 1, 280)
local SHOWN_POS = UDim2.new(0.5, 0, 1, -20)
local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = HIDDEN_POS,
	Size = UDim2.fromOffset(460, 250),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.08,
	Parent = gui,
}, {
	corner(8),
	stroke(DARK_RED, 2),
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 90, 90)),
	}),
	new("UIScale", { Name = "Scale" }),
})

local function updateScale()
	local cam = workspace.CurrentCamera
	if cam then
		panel.Scale.Scale = math.clamp(cam.ViewportSize.X / 560, 0.6, 1)
	end
end
updateScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

local title = new("TextLabel", {
	Position = UDim2.fromOffset(22, 10),
	Size = UDim2.new(1, -120, 0, 44),
	BackgroundTransparency = 1,
	FontFace = TITLE_FONT,
	TextSize = 40,
	TextColor3 = RED,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "CRYPT",
	Parent = panel,
})

local count = new("TextLabel", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -22, 0, 12),
	Size = UDim2.fromOffset(90, 40),
	BackgroundTransparency = 1,
	FontFace = TITLE_FONT,
	TextSize = 34,
	TextColor3 = BONE,
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "0/4",
	Parent = panel,
})

local status = new("TextLabel", {
	Position = UDim2.fromOffset(22, 54),
	Size = UDim2.new(1, -44, 0, 20),
	BackgroundTransparency = 1,
	FontFace = BODY_FONT,
	TextSize = 16,
	TextColor3 = BONE,
	TextTransparency = 0.25,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
	Parent = panel,
})

-- Spelersplekken
local slotRow = new("Frame", {
	Position = UDim2.fromOffset(22, 84),
	Size = UDim2.new(1, -44, 0, 76),
	BackgroundTransparency = 1,
	Parent = panel,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local slots = {}
for i = 1, GameConfig.MaxPlayers do
	local slot = new("Frame", {
		LayoutOrder = i,
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = Color3.fromRGB(24, 18, 18),
		Parent = slotRow,
	}, { corner(32), stroke(DARK_RED, 2) })
	local img = new("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "",
		Parent = slot,
	}, { corner(32) })
	local empty = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = TITLE_FONT,
		TextSize = 30,
		TextColor3 = DARK_RED,
		Text = "?",
		Parent = slot,
	})
	local crown = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(48, 16),
		BackgroundColor3 = RED,
		FontFace = BODY_FONT,
		TextSize = 11,
		TextColor3 = BONE,
		Text = "HOST",
		Visible = false,
		Parent = slot,
	}, { corner(4) })
	slots[i] = { frame = slot, img = img, empty = empty, crown = crown, stroke = slot:FindFirstChildOfClass("UIStroke") }
end

-- Host: aantal spelers kiezen
local sizeRow = new("Frame", {
	Position = UDim2.fromOffset(22, 168),
	Size = UDim2.new(1, -44, 0, 26),
	BackgroundTransparency = 1,
	Parent = panel,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}),
})
new("TextLabel", {
	LayoutOrder = 0,
	Size = UDim2.fromOffset(78, 26),
	BackgroundTransparency = 1,
	FontFace = BODY_FONT,
	TextSize = 14,
	TextColor3 = BONE,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "PLAYERS",
	Parent = sizeRow,
})
local sizeButtons = {}
for n = 1, GameConfig.MaxPlayers do
	local b = new("TextButton", {
		LayoutOrder = n,
		Size = UDim2.fromOffset(34, 26),
		BackgroundColor3 = Color3.fromRGB(28, 20, 20),
		FontFace = BODY_FONT,
		TextSize = 16,
		TextColor3 = BONE,
		Text = tostring(n),
		AutoButtonColor = true,
		Parent = sizeRow,
	}, { corner(4), stroke(DARK_RED, 1.5) })
	b.Activated:Connect(function()
		Remotes.QueueAction:FireServer("SetMax", n)
	end)
	sizeButtons[n] = b
end

-- Knoppen
local function button(text, color, pos, anchorX)
	return new("TextButton", {
		AnchorPoint = Vector2.new(anchorX, 1),
		Position = pos,
		Size = UDim2.fromOffset(150, 40),
		BackgroundColor3 = color,
		FontFace = TITLE_FONT,
		TextSize = 26,
		TextColor3 = BONE,
		Text = text,
		AutoButtonColor = true,
		Parent = panel,
	}, { corner(6), stroke(Color3.fromRGB(0, 0, 0), 2) })
end
local leaveBtn = button("LEAVE", Color3.fromRGB(35, 28, 28), UDim2.new(0, 22, 1, -14), 0)
local startBtn = button("START", RED, UDim2.new(1, -22, 1, -14), 1)

-- Countdown + fade
local countdown = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromOffset(300, 200),
	BackgroundTransparency = 1,
	FontFace = TITLE_FONT,
	TextSize = 150,
	TextColor3 = RED,
	TextStrokeTransparency = 0.4,
	Text = "",
	Visible = false,
	Parent = gui,
})
local fade = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	ZIndex = 10,
	Parent = gui,
})
local notice = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.fromOffset(500, 40),
	BackgroundTransparency = 1,
	FontFace = BODY_FONT,
	TextSize = 22,
	TextColor3 = BONE,
	TextStrokeTransparency = 0.3,
	TextTransparency = 1,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	ZIndex = 11,
	Parent = gui,
})

local function tween(inst, time, props)
	TweenService:Create(inst, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- Headshots
local thumbCache = {}
local function headshot(userId)
	if thumbCache[userId] then return thumbCache[userId] end
	local ok, url = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	thumbCache[userId] = ok and url or ""
	return thumbCache[userId]
end

-- Render
local shown = false
local current
local lastCountdown

local function setShown(on)
	if on == shown then return end
	shown = on
	tween(panel, 0.35, { Position = on and SHOWN_POS or HIDDEN_POS })
	if on then
		playSound(SoundIds.QueueJoin, 0.7)
	end
end

local function render(q)
	current = q
	if not q then
		setShown(false)
		countdown.Visible = false
		lastCountdown = nil
		heartbeat:Stop()
		tween(fade, 0.6, { BackgroundTransparency = 1 })
		return
	end
	setShown(true)

	local isHost = q.host == player.UserId
	title.Text = q.name
	count.Text = #q.players .. "/" .. q.max
	if q.teleporting then
		status.Text = "There is no way back now..."
	elseif q.countdown then
		status.Text = "The doors are closing..."
	elseif isHost then
		status.Text = "You are the host. Pick the group size and start."
	else
		status.Text = "Waiting for the host to start..."
	end

	for i, s in slots do
		local userId = q.players[i]
		s.frame.Visible = i <= q.max
		s.empty.Visible = userId == nil
		s.crown.Visible = userId ~= nil and userId == q.host
		s.stroke.Color = userId and RED or DARK_RED
		s.img.Image = ""
		if userId then
			task.spawn(function()
				local url = headshot(userId)
				if current == q and q.players[i] == userId then
					s.img.Image = url
				end
			end)
		end
	end

	sizeRow.Visible = isHost and not q.countdown and not q.teleporting
	for n, b in sizeButtons do
		local selected = n == q.max
		local allowed = n >= #q.players
		b.BackgroundColor3 = selected and RED or Color3.fromRGB(28, 20, 20)
		b.TextTransparency = allowed and 0 or 0.7
		b.Active = allowed
	end

	startBtn.Visible = isHost and not q.teleporting
	startBtn.Text = q.countdown and "CANCEL" or "START"
	leaveBtn.Visible = not q.teleporting

	if q.countdown and q.countdown ~= lastCountdown then
		countdown.Visible = true
		countdown.Text = tostring(q.countdown)
		countdown.TextTransparency = 0
		countdown.Size = UDim2.fromOffset(420, 280)
		tween(countdown, 0.8, { Size = UDim2.fromOffset(300, 200), TextTransparency = 0.6 })
		if not heartbeat.IsPlaying and heartbeat.SoundId ~= "" then
			heartbeat:Play()
		end
	elseif not q.countdown then
		countdown.Visible = false
	end
	if not q.countdown and not q.teleporting then
		heartbeat:Stop()
	end
	lastCountdown = q.countdown

	if q.teleporting then
		playSound(SoundIds.Launch, 0.8)
		tween(fade, 1.5, { BackgroundTransparency = 0 })
	else
		tween(fade, 0.6, { BackgroundTransparency = 1 })
	end
end

startBtn.Activated:Connect(function()
	if current and current.countdown then
		Remotes.QueueAction:FireServer("Cancel")
	else
		Remotes.QueueAction:FireServer("Start")
	end
end)
leaveBtn.Activated:Connect(function()
	Remotes.QueueAction:FireServer("Leave")
end)

Remotes.QueueState.OnClientEvent:Connect(function(all)
	local mine
	for _, q in all do
		if table.find(q.players, player.UserId) then
			mine = q
			break
		end
	end
	local wasTeleporting = current and current.teleporting
	if mine and mine.teleporting and wasTeleporting then return end
	render(mine)
end)

Remotes.QueueNotice.OnClientEvent:Connect(function(text)
	notice.Text = text
	notice.TextTransparency = 0
	notice.TextStrokeTransparency = 0.3
	task.delay(2.5, function()
		if notice.Text == text then
			tween(notice, 0.8, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end)

Remotes.QueueAction:FireServer("Sync")
