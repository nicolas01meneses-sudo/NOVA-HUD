--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Config = require(ReplicatedStorage.NOVA.Config)
local Integration = require(ReplicatedStorage.NOVA.Integration)
local FeatureRegistry = require(ReplicatedStorage.NOVA.FeatureRegistry)

local ConnectionBag = require(script.Parent.ConnectionBag)
local ControlScanner = require(script.Parent.ControlScanner)
local HitTest = require(script.Parent.HitTest)
local UiSnapshot = require(script.Parent.UiSnapshot)
local RemotePurchaseController = require(script.Parent.RemotePurchaseController)
local InfiniteJumpController = require(script.Parent.InfiniteJumpController)
local ReadOnlyAdapter = require(script.Parent.Adapters.ReadOnlyAdapter)
local AuthorizedCallbackAdapter = require(script.Parent.Adapters.AuthorizedCallbackAdapter)

local player = Players.LocalPlayer
if not player then
	return
end
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local old = playerGui:FindFirstChild("NOVA_HUD_6_0")
if old then
	old:Destroy()
end

local COLORS = {
	background = Color3.fromRGB(4, 11, 25),
	panel = Color3.fromRGB(10, 25, 48),
	accent = Color3.fromRGB(0, 220, 255),
	text = Color3.fromRGB(239, 248, 255),
	muted = Color3.fromRGB(151, 180, 209),
	green = Color3.fromRGB(0, 231, 174),
	warning = Color3.fromRGB(255, 190, 81),
	danger = Color3.fromRGB(255, 91, 122),
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
	Name = "NOVA_HUD_6_0",
	ResetOnSpawn = false,
	DisplayOrder = 105,
	IgnoreGuiInset = false,
}, playerGui) :: ScreenGui
screen:SetAttribute("NOVA_Internal", true)

local window = make("Frame", {
	Name = "Window",
	Size = UDim2.fromOffset(460, 430),
	Position = UDim2.fromScale(0.5, 0.52),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = COLORS.background,
	BorderSizePixel = 0,
	Active = true,
}, screen) :: Frame
window:SetAttribute("NOVA_Internal", true)
make("UICorner", { CornerRadius = UDim.new(0, 14) }, window)
make("UIStroke", { Color = COLORS.accent, Thickness = 1.5, Transparency = 0.2 }, window)

local title = make("TextLabel", {
	Size = UDim2.new(1, -60, 0, 54),
	Position = UDim2.fromOffset(18, 5),
	BackgroundTransparency = 1,
	Text = "NOVA 6.0  •  SAFE ARCHITECTURE",
	TextColor3 = COLORS.accent,
	Font = Enum.Font.GothamBold,
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
}, window) :: TextLabel

local close = make("TextButton", {
	Size = UDim2.fromOffset(38, 34),
	Position = UDim2.new(1, -48, 0, 10),
	BackgroundColor3 = COLORS.panel,
	BorderSizePixel = 0,
	Text = "×",
	TextColor3 = COLORS.danger,
	Font = Enum.Font.GothamBold,
	TextSize = 22,
}, window) :: TextButton
close:SetAttribute("NOVA_Internal", true)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, close)

local subtitle = make("TextLabel", {
	Size = UDim2.new(1, -36, 0, 38),
	Position = UDim2.fromOffset(18, 50),
	BackgroundTransparency = 1,
	Text = "Modo seguro: observa UI. No simula toques ni busca remotes privados.",
	TextColor3 = COLORS.muted,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, window) :: TextLabel

local content = make("Frame", {
	Size = UDim2.new(1, -36, 1, -100),
	Position = UDim2.fromOffset(18, 90),
	BackgroundTransparency = 1,
}, window) :: Frame
make("UIListLayout", {
	Padding = UDim.new(0, 7),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, content)

local function button(text: string): TextButton
	local object = make("TextButton", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = COLORS.text,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		AutoButtonColor = true,
	}, content) :: TextButton
	object:SetAttribute("NOVA_Internal", true)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, object)
	return object
end

local scanButton = button("ESCANEAR CONTROLES")
local linkButton = button("VINCULAR BUY VISIBLE")
local testButton = button("ARMAR PRUEBA MANUAL")
local autoButton = button("AUTO REMOTE BUY: OFF")
local jumpButton = button("SALTO INFINITO: OFF")

local status = make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 82),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Color3.fromRGB(7, 18, 36),
	BorderSizePixel = 0,
	Text = "Inicializando...",
	TextColor3 = COLORS.warning,
	Font = Enum.Font.Code,
	TextSize = 11,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, content) :: TextLabel
status:SetAttribute("NOVA_Internal", true)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, status)
make("UIPadding", {
	PaddingTop = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 8),
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
}, status)

local compatibility = make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 45),
	BackgroundTransparency = 1,
	Text = "Auto Ice / Auto Comprar: requieren adaptador autorizado.\nNo se declaran probados en Sell Lemons.",
	TextColor3 = COLORS.muted,
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, content) :: TextLabel

local connections = ConnectionBag.new()
local scanner = ControlScanner.new(playerGui)
local snapshotter = UiSnapshot.new(playerGui)
local adapter: any
if Integration.Authorized and Integration.Capabilities.RemoteBuy then
	adapter = AuthorizedCallbackAdapter.new(Integration :: any)
	testButton.Text = "PROBAR ADAPTADOR AUTORIZADO"
else
	adapter = ReadOnlyAdapter.new()
end

local controller: any = nil
local function show(message: string, color: Color3?)
	status.Text = message
	status.TextColor3 = color or COLORS.warning
end

controller = RemotePurchaseController.new(scanner, snapshotter, adapter, function(state)
	autoButton.Text = "AUTO REMOTE BUY: " .. (state.autoEnabled and "ON" or "OFF")
	autoButton.TextColor3 = if state.autoEnabled then COLORS.green else COLORS.text
	show(string.format(
		"Estado: %s\n%s\nVínculo: %s | Adaptador: %s",
		state.status,
		state.message,
		state.linked and "sí" or "no",
		state.activationCapable and "autorizado" or "observación"
	), if state.status == "auto" or state.status == "ready" then COLORS.green else COLORS.warning)
end)

local jump = InfiniteJumpController.new(player, UserInputService, Config.AllowInfiniteJump)

connections:add(scanButton.Activated:Connect(function()
	local remote = scanner:scan("remote-buy")
	local purchases = scanner:scan("purchase")
	local diagnostics = scanner:diagnostics()
	show(string.format(
		"Escaneo: %d objetos%s\nRemote Buy: %d | compras: %d\nSolo lectura; ningún control fue activado.",
		diagnostics.scanned,
		diagnostics.truncated and " (límite alcanzado)" or "",
		#remote,
		#purchases
	), COLORS.accent)
end))

local linkConnection: RBXScriptConnection? = nil
local linkSequence = 0
local function stopLink(message: string)
	linkSequence += 1
	if linkConnection then
		linkConnection:Disconnect()
		linkConnection = nil
	end
	window.Visible = true
	show(message)
end

connections:add(linkButton.Activated:Connect(function()
	linkSequence += 1
	local sequence = linkSequence
	if linkConnection then
		linkConnection:Disconnect()
	end
	window.Visible = false
	show("Vinculación activa")
	local banner = make("TextButton", {
		Size = UDim2.fromOffset(500, 52),
		Position = UDim2.new(0.5, -250, 0, 72),
		BackgroundColor3 = COLORS.accent,
		BorderSizePixel = 0,
		Text = "ABRE COMPRA REMOTA Y TOCA EL BUY VERDE  •  CANCELAR",
		TextColor3 = COLORS.background,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextWrapped = true,
	}, screen) :: TextButton
	banner:SetAttribute("NOVA_Internal", true)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, banner)
	local function finish(message: string)
		if sequence ~= linkSequence then
			return
		end
		if banner.Parent then
			banner:Destroy()
		end
		stopLink(message)
	end
	connections:add(banner.Activated:Connect(function()
		finish("Vinculación cancelada")
	end))
	task.delay(0.25, function()
		if sequence ~= linkSequence or not screen.Parent then
			return
		end
		linkConnection = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch
				and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			local object, coordinateMode = HitTest.pick(
				playerGui,
				GuiService,
				Vector2.new(input.Position.X, input.Position.Y),
				function(candidate)
					return scanner:describe(candidate) ~= nil
				end
			)
			if not object then
				return
			end
			local descriptor = scanner:describe(object)
			if not descriptor then
				return
			end
			local ok, reason = controller:link(descriptor)
			finish((ok and "Vinculado" or "No vinculado") .. " (" .. coordinateMode .. "): " .. reason)
		end)
	end)
	task.delay(30, function()
		if sequence == linkSequence and screen.Parent then
			finish("Vinculación agotó 30 s; no se guardó un toque vacío")
		end
	end)
end))

connections:add(testButton.Activated:Connect(function()
	local ok, reason = controller:testOnce(UserInputService, GuiService)
	if not ok then
		show("Prueba bloqueada: " .. reason, COLORS.danger)
	else
		show(reason, COLORS.accent)
	end
end))

connections:add(autoButton.Activated:Connect(function()
	local state = controller:getState()
	local ok, reason = controller:setAutoEnabled(not state.autoEnabled)
	if not ok then
		show("AUTO bloqueado: " .. reason, COLORS.danger)
	end
end))

connections:add(jumpButton.Activated:Connect(function()
	local ok, reason = jump:setEnabled(not jump:isEnabled())
	jumpButton.Text = "SALTO INFINITO: " .. (jump:isEnabled() and "ON" or "OFF")
	jumpButton.TextColor3 = if jump:isEnabled() then COLORS.green else COLORS.text
	show(reason, if ok then COLORS.accent else COLORS.danger)
end))

local heartbeatAccumulator = 0
connections:add(RunService.Heartbeat:Connect(function(deltaTime)
	heartbeatAccumulator += deltaTime
	if heartbeatAccumulator >= 0.25 then
		heartbeatAccumulator = 0
		controller:step()
	end
end))

connections:add(close.Activated:Connect(function()
	screen:Destroy()
end))

connections:add(screen.Destroying:Connect(function()
	linkSequence += 1
	if linkConnection then
		linkConnection:Disconnect()
		linkConnection = nil
	end
	controller:destroy()
	jump:destroy()
	connections:disconnectAll()
end))

local mode = if Integration.Authorized and Integration.Capabilities.RemoteBuy
	then "adaptador autorizado"
	else "solo observación"
show("NOVA " .. Config.Version .. " listo\nRemote Buy: " .. mode
	.. "\nValidación en vivo: pendiente", COLORS.accent)

-- Keep the compatibility table required so Studio surfaces an error if its
-- declaration is removed accidentally during future refactors.
assert(FeatureRegistry.RemoteBuy ~= nil and FeatureRegistry.AutoIce ~= nil)
