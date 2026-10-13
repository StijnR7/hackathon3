-- Intro bij binnenkomst (zwart → titel → lobby) en een hint zolang je niet in een queue staat.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local player = Players.LocalPlayer
local TITLE_FONT = Font.new("rbxasset://fonts/families/Creepster.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/SpecialElite.json")

local gui = Instance.new("ScreenGui")
gui.Name = "LobbyIntro"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local black = Instance.new("Frame")
black.Size = UDim2.fromScale(1, 1)
black.BackgroundColor3 = Color3.new(0, 0, 0)
black.Parent = gui

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.42)
title.Size = UDim2.new(0.9, 0, 0, 120)
title.BackgroundTransparency = 1
title.FontFace = TITLE_FONT
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(175, 20, 20)
title.TextTransparency = 1
title.Text = GameConfig.GameName
title.Parent = gui
local titleSize = Instance.new("UITextSizeConstraint")
titleSize.MaxTextSize = 110
titleSize.Parent = title

local sub = Instance.new("TextLabel")
sub.AnchorPoint = Vector2.new(0.5, 0)
sub.Position = UDim2.fromScale(0.5, 0.52)
sub.Size = UDim2.new(0.9, 0, 0, 30)
sub.BackgroundTransparency = 1
sub.FontFace = BODY_FONT
sub.TextSize = 22
sub.TextColor3 = Color3.fromRGB(215, 205, 188)
sub.TextTransparency = 1
sub.Text = "Gather your friends. Choose a crypt. Don't go alone."
sub.Parent = gui

local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -24)
hint.Size = UDim2.fromOffset(420, 26)
hint.BackgroundTransparency = 1
hint.FontFace = BODY_FONT
hint.TextSize = 18
hint.TextColor3 = Color3.fromRGB(215, 205, 188)
hint.TextStrokeTransparency = 0.4
hint.TextTransparency = 1
hint.TextStrokeColor3 = Color3.new(0, 0, 0)
hint.Text = "Walk into a crypt to start a game"
hint.Parent = gui

local function tween(inst, t, props)
	TweenService:Create(inst, TweenInfo.new(t, Enum.EasingStyle.Sine), props):Play()
end

local inQueue = false
local introDone = false
local function updateHint()
	local show = introDone and not inQueue
	tween(hint, 0.5, { TextTransparency = show and 0.15 or 1, TextStrokeTransparency = show and 0.4 or 1 })
end

Remotes.QueueState.OnClientEvent:Connect(function(all)
	inQueue = false
	for _, q in all do
		if table.find(q.players, player.UserId) then
			inQueue = true
		end
	end
	updateHint()
end)

-- Intro
task.wait(1)
tween(title, 2, { TextTransparency = 0 })
task.wait(1.2)
tween(sub, 1.5, { TextTransparency = 0.2 })
task.wait(2.5)
tween(black, 3, { BackgroundTransparency = 1 })
tween(title, 2.5, { TextTransparency = 1 })
tween(sub, 2, { TextTransparency = 1 })
task.wait(3)
black.Visible = false
introDone = true
updateHint()
