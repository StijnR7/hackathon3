-- Alle RemoteEvents op één plek. Nieuwe remote? Voeg de naam hier toe (zie CLAUDE.md).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NAMES = {
	"QueueState", -- server → client: lijst met alle queues
	"QueueAction", -- client → server: "Sync" | "Leave" | "SetMax" | "Start" | "Cancel"
	"QueueNotice", -- server → client: korte melding (string)
	"RoundState", -- server → client: stand van de ronde (fase, zekeringen, wie leeft/dood/ontsnapt)
	"RoundMessage", -- server → client: grote melding in beeld (tekst, soort)
}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for _, name in NAMES do
	Remotes[name] = folder:WaitForChild(name)
end
return Remotes
