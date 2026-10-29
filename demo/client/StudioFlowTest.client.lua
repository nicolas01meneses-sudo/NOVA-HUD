--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

if not RunService:IsStudio() then
	return
end

local player = Players.LocalPlayer
if not player then
	return
end
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local coreFolder = script.Parent.Parent:WaitForChild("NOVA")
local Catalog = require(ReplicatedStorage:WaitForChild("NOVA_Demo"):WaitForChild("DemoCatalog"))
local Amount = require(ReplicatedStorage.NOVA.Amount)
local IntegrationResolver = require(ReplicatedStorage.NOVA.Integration)
local AuthorizedCallbackAdapter = require(coreFolder.Adapters.AuthorizedCallbackAdapter)
local ControlScanner = require(coreFolder.ControlScanner)
local PriceReader = require(coreFolder.PriceReader)
local RemotePurchaseController = require(coreFolder.RemotePurchaseController)
local UiSnapshot = require(coreFolder.UiSnapshot)

local providerModule = ReplicatedStorage:WaitForChild("NOVA_AuthorizedIntegration")
local provider, providerStatus = IntegrationResolver.resolve(providerModule)
local runEvent = playerGui:FindFirstChild("NOVA_DemoRunFlow")
if runEvent then
	runEvent:Destroy()
end
runEvent = Instance.new("BindableEvent")
runEvent.Name = "NOVA_DemoRunFlow"
runEvent.Parent = playerGui

local running = false

local function report(state: string, details: string)
	player:SetAttribute("NOVA_DemoTestStatus", state)
	player:SetAttribute("NOVA_DemoTestDetails", details)
	print(string.format("[NOVA STUDIO TEST] %s: %s", state, details))
end

local function waitUntil(predicate: () -> boolean, timeout: number, description: string)
	local deadline = os.clock() + timeout
	repeat
		if predicate() then
			return
		end
		task.wait(0.05)
	until os.clock() >= deadline
	error("timeout: " .. description, 2)
end

local function expectedFinalWallet(): number
	local wallet = Catalog.InitialWallet
	for _, upgrade in ipairs(Catalog.Upgrades) do
		wallet -= upgrade.price
	end
	return wallet
end

local function runFlow()
	if running then
		return
	end
	running = true
	report("RUNNING", "detect → price → receipt → next upgrades")

	local controller: any = nil
	local ok, failure = xpcall(function()
		assert(provider.Authorized == true, providerStatus)
		waitUntil(function()
			return type(player:GetAttribute("NOVA_DemoPurchaseCount")) == "number"
		end, 8, "server state replication")
		assert(player:GetAttribute("NOVA_DemoPurchaseCount") == 0,
			"restart Play before running the complete flow")

		local scanner = ControlScanner.new(playerGui)
		local descriptor: any = nil
		waitUntil(function()
			for _, candidate in ipairs(scanner:scan("remote-buy")) do
				if candidate.controlId == Catalog.ControlId then
					descriptor = candidate
					return true
				end
			end
			return false
		end, 8, "green BUY detection")

		local firstPrice = PriceReader.readControlPrice(descriptor.instance)
		local expectedPrice = Amount.fromNumber(Catalog.Upgrades[1].price, Catalog.Currency)
		assert(firstPrice and expectedPrice and Amount.compare(firstPrice, expectedPrice) == 0,
			"the first BUY price was not read correctly")

		local adapter = AuthorizedCallbackAdapter.new(provider)
		local snapshotter = UiSnapshot.new(playerGui)
		controller = RemotePurchaseController.new(scanner, snapshotter, adapter, function(state)
			player:SetAttribute("NOVA_DemoControllerState", state.status)
		end)

		local linked, linkReason = controller:link(descriptor)
		assert(linked, linkReason)
		assert(controller:getState().activationCapable == true,
			"the explicit BUY was not connected to the authorized adapter")

		local started, startReason = controller:testOnce(UserInputService, GuiService)
		assert(started, startReason)
		waitUntil(function()
			return controller:getState().pending == false
		end, 10, "first receipt verification")
		local firstState = controller:getState()
		assert(firstState.lastAssessment and firstState.lastAssessment.status == "confirmed",
			"the first server receipt was not confirmed")
		waitUntil(function()
			return player:GetAttribute("NOVA_DemoPurchaseCount") == 1
		end, 5, "server counter after the first purchase")
		assert(player:GetAttribute("NOVA_DemoWallet")
			== Catalog.InitialWallet - Catalog.Upgrades[1].price,
			"the server wallet did not subtract the first catalog price")

		local secondExpected = Amount.fromNumber(Catalog.Upgrades[2].price, Catalog.Currency)
		waitUntil(function()
			local current = controller:resolve()
			if not current then
				return false
			end
			local currentPrice = PriceReader.readControlPrice(current.instance)
			return currentPrice ~= nil and secondExpected ~= nil
				and Amount.compare(currentPrice, secondExpected) == 0
		end, 5, "next upgrade price after the first receipt")

		local autoEnabled, autoReason = controller:setAutoEnabled(true)
		assert(autoEnabled, autoReason)
		waitUntil(function()
			controller:step()
			return controller:getState().terminal == true
		end, 60, "automatic continuation through the catalog")

		local finalState = controller:getState()
		assert(finalState.status == "complete", "controller did not enter complete state")
		assert(finalState.autoEnabled == false, "AUTO did not stop at the terminal receipt")
		assert(player:GetAttribute("NOVA_DemoPurchaseCount") == #Catalog.Upgrades,
			"not every authorized upgrade was purchased")
		assert(player:GetAttribute("NOVA_DemoWallet") == expectedFinalWallet(),
			"final server-authoritative wallet is incorrect")
	end, debug.traceback)

	if controller then
		controller:destroy()
	end
	if ok then
		report("PASS", string.format(
			"%d upgrades; wallet %s%d; terminal receipt confirmed",
			#Catalog.Upgrades,
			Catalog.Currency,
			expectedFinalWallet()
		))
	else
		report("FAIL", tostring(failure))
	end
	running = false
end

(runEvent :: BindableEvent).Event:Connect(runFlow)
if Catalog.RunAutomatedStudioFlow then
	task.delay(1, runFlow)
else
	report("READY", "press EJECUTAR PRUEBA COMPLETA EN STUDIO")
end
