--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DemoPurchaseService = require(script.Parent.DemoPurchaseService)
local demoFolder = ReplicatedStorage:WaitForChild("NOVA_Demo")
local Catalog = require(demoFolder:WaitForChild("DemoCatalog"))

local function childOfClass(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing.ClassName == className, name .. " has an unexpected class")
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function ensureWorld()
	if not Workspace:FindFirstChild("NOVA_DemoBaseplate") then
		local baseplate = Instance.new("Part")
		baseplate.Name = "NOVA_DemoBaseplate"
		baseplate.Anchored = true
		baseplate.Size = Vector3.new(160, 1, 160)
		baseplate.Position = Vector3.new(0, -0.5, 0)
		baseplate.Color = Color3.fromRGB(10, 25, 48)
		baseplate.Material = Enum.Material.SmoothPlastic
		baseplate.Parent = Workspace
	end
	if not Workspace:FindFirstChild("NOVA_DemoSpawn") then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "NOVA_DemoSpawn"
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.Position = Vector3.new(0, 0.5, 0)
		spawn.Color = Color3.fromRGB(0, 220, 255)
		spawn.Parent = Workspace
	end
end

ensureWorld()

local purchaseRemote = childOfClass(demoFolder, "RemoteFunction", "PurchaseUpgrade") :: RemoteFunction
local service = DemoPurchaseService.new(Catalog)

local function syncPlayer(player: Player)
	local snapshot = service:snapshot(player.UserId)
	if not snapshot then
		return
	end
	local upgrade = snapshot.currentUpgrade
	player:SetAttribute("NOVA_DemoWallet", snapshot.wallet)
	player:SetAttribute("NOVA_DemoPurchaseCount", snapshot.purchaseCount)
	player:SetAttribute("NOVA_DemoRevision", snapshot.revision)
	player:SetAttribute("NOVA_DemoTerminal", snapshot.terminal)
	player:SetAttribute("NOVA_DemoTotal", #Catalog.Upgrades)
	player:SetAttribute("NOVA_DemoCurrentId", upgrade and upgrade.id or nil)
	player:SetAttribute("NOVA_DemoCurrentName", upgrade and upgrade.name or nil)
	player:SetAttribute("NOVA_DemoCurrentPrice", upgrade and upgrade.price or nil)
end

local function addPlayer(player: Player)
	service:addPlayer(player.UserId)
	syncPlayer(player)
end

for _, player in ipairs(Players:GetPlayers()) do
	addPlayer(player)
end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	service:removePlayer(player.UserId)
end)

purchaseRemote.OnServerInvoke = function(player: Player, payload: any)
	local receipt = service:purchase(player.UserId, payload, os.clock())
	if receipt then
		syncPlayer(player)
	end
	return receipt
end

demoFolder:SetAttribute("NOVA_DemoServerReady", true)
print("[NOVA DEMO] Authorized purchase server is ready")
