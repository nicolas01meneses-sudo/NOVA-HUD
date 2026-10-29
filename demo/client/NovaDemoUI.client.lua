--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
if not player then
	return
end
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local Catalog = require(ReplicatedStorage:WaitForChild("NOVA_Demo"):WaitForChild("DemoCatalog"))
local IntegrationResolver = require(ReplicatedStorage.NOVA.Integration)
local providerModule = ReplicatedStorage:WaitForChild("NOVA_AuthorizedIntegration")
local provider, providerStatus = IntegrationResolver.resolve(providerModule)

local old = playerGui:FindFirstChild("NOVA_AUTHORIZED_DEMO")
if old then
	old:Destroy()
end

local COLORS = {
	background = Color3.fromRGB(6, 14, 28),
	panel = Color3.fromRGB(12, 31, 55),
	cyan = Color3.fromRGB(0, 220, 255),
	green = Color3.fromRGB(26, 214, 118),
	greenDim = Color3.fromRGB(44, 102, 75),
	text = Color3.fromRGB(239, 248, 255),
	muted = Color3.fromRGB(155, 184, 210),
	warning = Color3.fromRGB(255, 196, 92),
	danger = Color3.fromRGB(255, 94, 122),
}

local function make(className: string, properties: { [string]: any }, parent: Instance): Instance
	local instance = Instance.new(className)
	for key, value in pairs(properties) do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local screen = make("ScreenGui", {
	Name = "NOVA_AUTHORIZED_DEMO",
	ResetOnSpawn = false,
	DisplayOrder = 20,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui) :: ScreenGui

local card = make("Frame", {
	Name = "DemoCard",
	Size = UDim2.new(1, -24, 0, 318),
	Position = UDim2.new(0.5, 0, 1, -12),
	AnchorPoint = Vector2.new(0.5, 1),
	BackgroundColor3 = COLORS.background,
	BorderSizePixel = 0,
}, screen) :: Frame
make("UISizeConstraint", {
	MinSize = Vector2.new(280, 300),
	MaxSize = Vector2.new(420, 318),
}, card)
make("UICorner", { CornerRadius = UDim.new(0, 14) }, card)
make("UIStroke", { Color = COLORS.cyan, Thickness = 1.5, Transparency = 0.15 }, card)
make("UIPadding", {
	PaddingTop = UDim.new(0, 12),
	PaddingBottom = UDim.new(0, 12),
	PaddingLeft = UDim.new(0, 14),
	PaddingRight = UDim.new(0, 14),
}, card)
make("UIListLayout", {
	Padding = UDim.new(0, 7),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, card)

local function label(text: string, height: number, size: number, color: Color3): TextLabel
	return make("TextLabel", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		Font = Enum.Font.Gotham,
		TextSize = size,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, card) :: TextLabel
end

local title = label("NOVA • COMPRA REMOTA AUTORIZADA", 28, 15, COLORS.cyan)
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Center

local summaryRow = make("Frame", {
	Size = UDim2.new(1, 0, 0, 32),
	BackgroundColor3 = COLORS.panel,
	BorderSizePixel = 0,
}, card) :: Frame
make("UICorner", { CornerRadius = UDim.new(0, 8) }, summaryRow)

local walletLabel = make("TextLabel", {
	Name = "Wallet",
	Size = UDim2.new(0.5, -4, 1, 0),
	Position = UDim2.fromOffset(8, 0),
	BackgroundTransparency = 1,
	Text = "Billetera: esperando",
	TextColor3 = COLORS.text,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
}, summaryRow) :: TextLabel
walletLabel:SetAttribute("NOVA_ControlId", "nova-demo-wallet")
walletLabel:SetAttribute("NOVA_Currency", Catalog.Currency)
CollectionService:AddTag(walletLabel, "NOVA_WalletLabel")

local counterLabel = make("TextLabel", {
	Name = "PurchaseCounter",
	Size = UDim2.new(0.5, -12, 1, 0),
	Position = UDim2.new(0.5, 4, 0, 0),
	BackgroundTransparency = 1,
	Text = "Compras: 0/0",
	TextColor3 = COLORS.text,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Right,
}, summaryRow) :: TextLabel
counterLabel:SetAttribute("NOVA_ControlId", "nova-demo-counter")
CollectionService:AddTag(counterLabel, "NOVA_PurchaseCounter")

local upgradeLabel = label("Esperando estado del servidor...", 28, 13, COLORS.muted)
upgradeLabel.Name = "CurrentUpgrade"
upgradeLabel.TextXAlignment = Enum.TextXAlignment.Center

local buyButton = make("TextButton", {
	Name = "AuthorizedBuyButton",
	Size = UDim2.new(1, 0, 0, 62),
	BackgroundColor3 = COLORS.green,
	BorderSizePixel = 0,
	Text = "BUY",
	TextColor3 = Color3.fromRGB(3, 30, 20),
	Font = Enum.Font.GothamBlack,
	TextSize = 19,
	TextWrapped = true,
	AutoButtonColor = true,
	Active = true,
}, card) :: TextButton
make("UICorner", { CornerRadius = UDim.new(0, 12) }, buyButton)
make("UIStroke", { Color = Color3.fromRGB(156, 255, 205), Thickness = 1.5 }, buyButton)
buyButton:SetAttribute("NOVA_Role", "remote-buy")
buyButton:SetAttribute("NOVA_ControlId", Catalog.ControlId)
buyButton:SetAttribute("NOVA_Currency", Catalog.Currency)
CollectionService:AddTag(buyButton, "NOVA_RemoteBuyControl")

local statusLabel = label(providerStatus, 48, 11, COLORS.warning)
statusLabel.Name = "Status"
statusLabel.Font = Enum.Font.Code
statusLabel.TextXAlignment = Enum.TextXAlignment.Center

local testButton = make("TextButton", {
	Name = "RunFullStudioTest",
	Size = UDim2.new(1, 0, 0, 44),
	BackgroundColor3 = COLORS.panel,
	BorderSizePixel = 0,
	Text = "EJECUTAR PRUEBA COMPLETA EN STUDIO",
	TextColor3 = COLORS.cyan,
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	AutoButtonColor = true,
	Visible = RunService:IsStudio(),
}, card) :: TextButton
make("UICorner", { CornerRadius = UDim.new(0, 9) }, testButton)

local busy = false
local connections: { RBXScriptConnection } = {}

local function setStatus(message: string, color: Color3?)
	statusLabel.Text = message
	statusLabel.TextColor3 = color or COLORS.warning
end

local function refresh()
	local wallet = player:GetAttribute("NOVA_DemoWallet")
	local count = player:GetAttribute("NOVA_DemoPurchaseCount")
	local total = player:GetAttribute("NOVA_DemoTotal")
	local upgradeName = player:GetAttribute("NOVA_DemoCurrentName")
	local price = player:GetAttribute("NOVA_DemoCurrentPrice")
	local terminal = player:GetAttribute("NOVA_DemoTerminal") == true

	if type(wallet) == "number" then
		walletLabel.Text = string.format("Billetera: %s%d", Catalog.Currency, wallet)
		walletLabel:SetAttribute("NOVA_Price", wallet)
	end
	if type(count) == "number" and type(total) == "number" then
		counterLabel.Text = string.format("Compras: %d/%d", count, total)
		counterLabel:SetAttribute("NOVA_Count", count)
	end
	if terminal then
		upgradeLabel.Text = "Todas las mejoras autorizadas fueron compradas"
		buyButton.Text = "COMPLETADO"
		buyButton.BackgroundColor3 = COLORS.greenDim
		buyButton.AutoButtonColor = false
		buyButton:SetAttribute("NOVA_Price", nil)
	elseif type(upgradeName) == "string" and type(price) == "number" then
		upgradeLabel.Text = "Siguiente mejora: " .. upgradeName
		buyButton.Text = string.format("BUY\n%s • %s%d", upgradeName, Catalog.Currency, price)
		buyButton.BackgroundColor3 = COLORS.green
		buyButton.AutoButtonColor = true
		buyButton:SetAttribute("NOVA_Price", price)
	end
end

for _, attribute in ipairs({
	"NOVA_DemoWallet",
	"NOVA_DemoPurchaseCount",
	"NOVA_DemoTotal",
	"NOVA_DemoCurrentName",
	"NOVA_DemoCurrentPrice",
	"NOVA_DemoTerminal",
}) do
	table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(refresh))
end

table.insert(connections, buyButton.Activated:Connect(function()
	if busy or player:GetAttribute("NOVA_DemoTerminal") == true then
		return
	end
	busy = true
	setStatus("Enviando solicitud al servidor...", COLORS.cyan)
	task.spawn(function()
		local result = provider.requestPurchase(Catalog.ControlId, {
			source = "green-buy-button",
		})
		if not result.accepted or not result.requestId then
			setStatus("Solicitud bloqueada: " .. tostring(result.reason), COLORS.danger)
		else
			local receipt = provider.readReceipt(result.requestId)
			if receipt and receipt.success then
				setStatus("CONFIRMADA por servidor: " .. tostring(receipt.upgradeName), COLORS.green)
			else
				setStatus("RECHAZADA por servidor: " .. tostring(receipt and receipt.reason), COLORS.danger)
			end
		end
		busy = false
	end)
end))

table.insert(connections, testButton.Activated:Connect(function()
	local event = playerGui:FindFirstChild("NOVA_DemoRunFlow")
	if not event or not event:IsA("BindableEvent") then
		setStatus("El arnés de Studio todavía no está listo", COLORS.danger)
		return
	end
	event:Fire()
end))

table.insert(connections, player:GetAttributeChangedSignal("NOVA_DemoTestStatus"):Connect(function()
	local state = player:GetAttribute("NOVA_DemoTestStatus")
	local details = player:GetAttribute("NOVA_DemoTestDetails")
	if type(state) == "string" then
		setStatus(state .. ": " .. tostring(details), if state == "PASS" then COLORS.green
			elseif state == "FAIL" then COLORS.danger else COLORS.cyan)
	end
end))

screen.Destroying:Connect(function()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end)

refresh()
