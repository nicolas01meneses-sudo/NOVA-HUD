--!strict

local Amount = require("../src/shared/Amount")
local ControlFingerprint = require("../src/shared/ControlFingerprint")
local PurchaseEvidence = require("../src/shared/PurchaseEvidence")
local RemotePurchaseState = require("../src/shared/RemotePurchaseState")
local AuthorizedCallbackAdapter = require("../src/client/Adapters/AuthorizedCallbackAdapter")
local ReadOnlyAdapter = require("../src/client/Adapters/ReadOnlyAdapter")
local IntegrationResolver = require("../src/shared/Integration")
local DemoCatalog = require("../demo/shared/DemoCatalog")
local DemoPurchaseService = require("../demo/server/DemoPurchaseService")

local passed = 0
local failed = 0

local function expect(condition: boolean, message: string?)
	if not condition then
		error(message or "expectation failed", 2)
	end
end

local function test(name: string, callback: () -> ())
	local ok, message = pcall(callback)
	if ok then
		passed += 1
		print("PASS " .. name)
	else
		failed += 1
		warn("FAIL " .. name .. ": " .. tostring(message))
	end
end

test("parses grouped and suffixed prices", function()
	local grouped = Amount.parse("$195,000")
	local suffixed = Amount.parse("$8.8K")
	expect(grouped ~= nil and suffixed ~= nil)
	expect(Amount.compare(grouped, suffixed) > 0, "$195,000 must be greater than $8.8K")
end)

test("rejects a mismatched currency", function()
	local value, reason = Amount.parse("$10K", "Φ")
	expect(value == nil)
	expect(reason == "currency mismatch")
end)

test("uses an explicit currency when the text omits its symbol", function()
	local value = Amount.parse("10K", "$")
	expect(value ~= nil)
	expect(value.currency == "$")
end)

test("parses the localized sexdecillion suffix seen in the reference UI", function()
	local value = Amount.parse("Φ68.758 sexdecillón")
	expect(value ~= nil)
	expect(value.exponent3 == 17)
end)

test("resolves a recreated control by stable fingerprint", function()
	local original = {
		controlId = "remote-buy-main",
		source = "attribute",
		screenGui = "TycoonHud",
		path = "RemoteBuy/Buy",
		className = "TextButton",
		name = "Buy",
		role = "remote-buy",
		text = "BUY $195,000",
		centerX = 0.52,
		centerY = 0.86,
		width = 0.09,
		height = 0.08,
	}
	local recreated = table.clone(original)
	recreated.instance = "new-instance"
	recreated.centerX = 0.521
	local other = table.clone(original)
	other.controlId = "premium-shop"
	other.path = "Store/Buy"
	other.text = "BUY R$"
	local result = ControlFingerprint.resolve(
		ControlFingerprint.capture(original),
		{ other, recreated },
		48,
		8
	)
	expect(result.descriptor == recreated, result.reason)
end)

test("refuses an ambiguous heuristic binding", function()
	local original = {
		controlId = nil,
		source = "heuristic",
		screenGui = "Hud",
		path = "Remote/Buy",
		className = "ImageButton",
		name = "Buy",
		role = "purchase",
		text = "BUY",
		centerX = 0.5,
		centerY = 0.8,
		width = 0.1,
		height = 0.1,
	}
	local left = table.clone(original)
	local right = table.clone(original)
	local result = ControlFingerprint.resolve(
		ControlFingerprint.capture(original),
		{ left, right },
		48,
		8
	)
	expect(result.descriptor == nil)
	expect(result.reason == "binding is ambiguous")
end)

test("never downgrades an explicit control id to an unlabelled candidate", function()
	local explicit = {
		controlId = "remote-buy-main",
		source = "attribute",
		screenGui = "Hud",
		path = "Remote/Buy",
		className = "TextButton",
		name = "Buy",
		role = "remote-buy",
		text = "BUY",
		centerX = 0.5,
		centerY = 0.8,
		width = 0.1,
		height = 0.1,
	}
	local unlabelled = table.clone(explicit)
	unlabelled.controlId = nil
	unlabelled.source = "heuristic"
	local result = ControlFingerprint.resolve(
		ControlFingerprint.capture(explicit),
		{ unlabelled },
		48,
		8
	)
	expect(result.descriptor == nil)
end)

local function snapshot(overrides: { [string]: any }?)
	local value = {
		capturedAt = 1,
		controlKey = "remote-buy-main",
		controlPresent = true,
		controlText = "BUY $10K",
		price = Amount.parse("$10K"),
		walletKey = "wallet-main",
		wallet = Amount.parse("$100K"),
		counterKey = "counter-main",
		counter = 4,
	}
	for key, item in pairs(overrides or {}) do
		value[key] = item
	end
	return value
end

test("confirms only an explicit counter increase", function()
	local assessment = PurchaseEvidence.assess(snapshot(), snapshot({ counter = 5 }), nil)
	expect(assessment.status == "confirmed")
end)

test("wallet decrease is observed, never confirmed", function()
	local assessment = PurchaseEvidence.assess(snapshot(), snapshot({
		wallet = Amount.parse("$90K"),
	}), nil)
	expect(assessment.status == "observed")
end)

test("successful authorized receipt confirms a purchase", function()
	local assessment = PurchaseEvidence.assess(snapshot(), snapshot(), {
		requestId = "request-123",
		success = true,
		controlId = "remote-buy-main",
	})
	expect(assessment.status == "confirmed")
end)

test("read-only adapter never exposes activation", function()
	local adapter = ReadOnlyAdapter.new()
	expect(adapter:canActivate() == false)
	local result = adapter:requestPurchase("remote-buy-main", {})
	expect(result.accepted == false)
end)

test("authorized adapter requires a request id for accepted work", function()
	local adapter = AuthorizedCallbackAdapter.new({
		Authorized = true,
		Capabilities = { RemoteBuy = true },
		requestPurchase = function()
			return { accepted = true }
		end,
		readReceipt = function()
			return nil
		end,
	})
	local result = adapter:requestPurchase("remote-buy-main", {})
	expect(result.accepted == false)
	expect(result.reason == "accepted requests require a non-empty requestId")
end)

test("integration resolver is read-only without an explicit provider", function()
	local provider, reason = IntegrationResolver.resolve(nil)
	expect(provider.Authorized == false)
	expect(reason == "NOVA_AuthorizedIntegration is not installed")
end)

test("integration resolver accepts a complete authorized contract", function()
	local candidate = {
		Authorized = true,
		ProviderId = "test-provider",
		Capabilities = { RemoteBuy = true },
		requestPurchase = function()
			return { accepted = false }
		end,
		readReceipt = function()
			return nil
		end,
	}
	local provider = IntegrationResolver.resolve(candidate)
	expect(provider == candidate)
end)

test("auto remains locked after observed evidence", function()
	local machine = RemotePurchaseState.new()
	machine:link(true)
	local began = machine:beginTest()
	expect(began == true)
	machine:finishTest({
		status = "observed",
		reason = "wallet changed",
		evidence = { "wallet-decreased" },
	})
	local enabled = machine:setAuto(true)
	expect(enabled == false)
	expect(machine.autoUnlocked == false)
end)

test("confirmed test unlocks only an activation-capable adapter", function()
	local observation = RemotePurchaseState.new()
	observation:link(false)
	observation:beginTest()
	observation:finishTest({ status = "confirmed", reason = "counter", evidence = {} })
	expect(observation.autoUnlocked == false)

	local authorized = RemotePurchaseState.new()
	authorized:link(true)
	authorized:beginTest()
	authorized:finishTest({ status = "confirmed", reason = "receipt", evidence = {} })
	expect(authorized.autoUnlocked == true)
	local enabled = authorized:setAuto(true)
	expect(enabled == true and authorized.autoEnabled == true)
end)

test("unlink clears authorization and prior evidence", function()
	local machine = RemotePurchaseState.new()
	machine:link(true)
	machine:beginTest()
	machine:finishTest({ status = "confirmed", reason = "receipt", evidence = {} })
	machine:unlink("new binding required")
	expect(machine.linked == false)
	expect(machine.activationCapable == false)
	expect(machine.autoUnlocked == false)
	expect(machine.lastAssessment == nil)
end)

test("a terminal receipt completes and stops authorized auto", function()
	local machine = RemotePurchaseState.new()
	machine:link(true)
	machine:beginTest()
	machine:finishTest({ status = "confirmed", reason = "receipt", evidence = {}, terminal = false })
	machine:setAuto(true)
	machine:beginTest()
	machine:finishTest({ status = "confirmed", reason = "last receipt", evidence = {}, terminal = true })
	expect(machine.status == "complete")
	expect(machine.terminal == true)
	expect(machine.autoEnabled == false)
	local began = machine:beginTest()
	expect(began == false)
end)

test("demo server validates revision, rate and idempotency", function()
	local service = DemoPurchaseService.new(DemoCatalog)
	service:addPlayer("player")
	local first = service:purchase("player", {
		requestId = "request-first",
		controlId = DemoCatalog.ControlId,
		expectedRevision = 0,
	}, 1)
	expect(first ~= nil and first.success == true)
	local duplicate = service:purchase("player", {
		requestId = "request-first",
		controlId = DemoCatalog.ControlId,
		expectedRevision = 0,
	}, 1.01)
	expect(duplicate ~= nil and duplicate.success == true)
	expect(duplicate.wallet == first.wallet)

	local limited = service:purchase("player", {
		requestId = "request-rate",
		controlId = DemoCatalog.ControlId,
		expectedRevision = 1,
	}, 1.05)
	expect(limited ~= nil and limited.success == false)
	expect(limited.reason == "server rate limit")

	local stale = service:purchase("player", {
		requestId = "request-stale",
		controlId = DemoCatalog.ControlId,
		expectedRevision = 0,
	}, 2)
	expect(stale ~= nil and stale.success == false)
	expect(stale.reason == "revision mismatch")
	local snapshot = service:snapshot("player")
	expect(snapshot ~= nil and snapshot.purchaseCount == 1)
end)

test("demo server rejects an unauthorized control id", function()
	local service = DemoPurchaseService.new(DemoCatalog)
	service:addPlayer("player")
	local receipt = service:purchase("player", {
		requestId = "request-wrong-control",
		controlId = "some-other-button",
		expectedRevision = 0,
	}, 1)
	expect(receipt ~= nil and receipt.success == false)
	expect(receipt.reason == "controlId is not authorized")
	local snapshot = service:snapshot("player")
	expect(snapshot ~= nil and snapshot.purchaseCount == 0)
end)

test("demo server never trusts a client to bypass its balance", function()
	local poorCatalog = {
		ControlId = "buy",
		Currency = "$",
		InitialWallet = 5,
		MinimumServerIntervalSeconds = 0,
		MaximumReceiptHistory = 8,
		Upgrades = {
			{ id = "expensive", name = "Expensive", price = 10 },
		},
	}
	local service = DemoPurchaseService.new(poorCatalog)
	service:addPlayer(1)
	local receipt = service:purchase(1, {
		requestId = "request-no-money",
		controlId = "buy",
		expectedRevision = 0,
		price = 0,
	}, 1)
	expect(receipt ~= nil and receipt.success == false)
	expect(receipt.reason == "insufficient server-authoritative balance")
	local snapshot = service:snapshot(1)
	expect(snapshot ~= nil and snapshot.wallet == 5 and snapshot.purchaseCount == 0)
end)

test("demo server buys the catalog in order and returns a terminal receipt", function()
	local service = DemoPurchaseService.new(DemoCatalog)
	service:addPlayer(42)
	local expectedWallet = DemoCatalog.InitialWallet
	local receipt = nil
	for index, upgrade in ipairs(DemoCatalog.Upgrades) do
		receipt = service:purchase(42, {
			requestId = string.format("request-%02d", index),
			controlId = DemoCatalog.ControlId,
			expectedRevision = index - 1,
		}, index)
		expectedWallet -= upgrade.price
		expect(receipt ~= nil and receipt.success == true)
		expect(receipt.upgradeId == upgrade.id)
		expect(receipt.wallet == expectedWallet)
	end
	expect(receipt ~= nil and receipt.terminal == true)
	local snapshot = service:snapshot(42)
	expect(snapshot ~= nil and snapshot.terminal == true)
	expect(snapshot.purchaseCount == #DemoCatalog.Upgrades)
	expect(snapshot.wallet == expectedWallet)
end)

print(string.format("RESULT %d passed, %d failed", passed, failed))
if failed > 0 then
	error(string.format("%d test(s) failed", failed))
end
