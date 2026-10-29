--!strict

export type Upgrade = {
	id: string,
	name: string,
	price: number,
}

export type Catalog = {
	ControlId: string,
	Currency: string,
	InitialWallet: number,
	MinimumServerIntervalSeconds: number,
	MaximumReceiptHistory: number,
	Upgrades: { Upgrade },
}

export type Receipt = {
	requestId: string,
	success: boolean,
	controlId: string,
	revision: number,
	terminal: boolean,
	reason: string?,
	upgradeId: string?,
	upgradeName: string?,
	price: number?,
	wallet: number,
	purchaseCount: number,
}

export type Snapshot = {
	wallet: number,
	purchaseCount: number,
	revision: number,
	terminal: boolean,
	currentUpgrade: Upgrade?,
}

type PlayerState = {
	wallet: number,
	upgradeIndex: number,
	revision: number,
	lastRequestAt: number,
	receipts: { [string]: Receipt },
	receiptOrder: { string },
}

local DemoPurchaseService = {}
DemoPurchaseService.__index = DemoPurchaseService

export type Service = typeof(setmetatable({} :: {
	_catalog: Catalog,
	_states: { [any]: PlayerState },
}, DemoPurchaseService))

local function copyReceipt(receipt: Receipt): Receipt
	return table.clone(receipt)
end

local function validRequestId(value: any): boolean
	if type(value) ~= "string" then
		return false
	end
	local length = utf8.len(value)
	return length ~= nil and length >= 8 and length <= 80
end

function DemoPurchaseService.new(catalog: Catalog): Service
	assert(type(catalog.ControlId) == "string" and catalog.ControlId ~= "", "ControlId is required")
	assert(type(catalog.InitialWallet) == "number" and catalog.InitialWallet >= 0, "InitialWallet is invalid")
	assert(#catalog.Upgrades > 0, "at least one upgrade is required")
	return setmetatable({
		_catalog = catalog,
		_states = {},
	}, DemoPurchaseService)
end

function DemoPurchaseService.addPlayer(self: Service, playerKey: any)
	self._states[playerKey] = {
		wallet = self._catalog.InitialWallet,
		upgradeIndex = 1,
		revision = 0,
		lastRequestAt = -math.huge,
		receipts = {},
		receiptOrder = {},
	}
end

function DemoPurchaseService.removePlayer(self: Service, playerKey: any)
	self._states[playerKey] = nil
end

function DemoPurchaseService.snapshot(self: Service, playerKey: any): Snapshot?
	local state = self._states[playerKey]
	if not state then
		return nil
	end
	local current = self._catalog.Upgrades[state.upgradeIndex]
	return {
		wallet = state.wallet,
		purchaseCount = state.upgradeIndex - 1,
		revision = state.revision,
		terminal = current == nil,
		currentUpgrade = current,
	}
end

function DemoPurchaseService._remember(self: Service, state: PlayerState, receipt: Receipt): Receipt
	state.receipts[receipt.requestId] = receipt
	table.insert(state.receiptOrder, receipt.requestId)
	while #state.receiptOrder > self._catalog.MaximumReceiptHistory do
		local oldest = table.remove(state.receiptOrder, 1)
		state.receipts[oldest] = nil
	end
	return copyReceipt(receipt)
end

function DemoPurchaseService._reject(
	self: Service,
	state: PlayerState,
	requestId: string,
	reason: string,
	terminal: boolean?
): Receipt
	return self:_remember(state, {
		requestId = requestId,
		success = false,
		controlId = self._catalog.ControlId,
		revision = state.revision,
		terminal = terminal == true,
		reason = reason,
		wallet = state.wallet,
		purchaseCount = state.upgradeIndex - 1,
	})
end

function DemoPurchaseService.purchase(
	self: Service,
	playerKey: any,
	payload: any,
	now: number
): Receipt?
	local state = self._states[playerKey]
	if not state or type(payload) ~= "table" or not validRequestId(payload.requestId) then
		return nil
	end
	local requestId = payload.requestId :: string
	local previous = state.receipts[requestId]
	if previous then
		return copyReceipt(previous)
	end
	if now - state.lastRequestAt < self._catalog.MinimumServerIntervalSeconds then
		return self:_reject(state, requestId, "server rate limit")
	end
	state.lastRequestAt = now
	if payload.controlId ~= self._catalog.ControlId then
		return self:_reject(state, requestId, "controlId is not authorized")
	end
	if type(payload.expectedRevision) ~= "number"
		or payload.expectedRevision % 1 ~= 0
		or payload.expectedRevision ~= state.revision then
		return self:_reject(state, requestId, "revision mismatch")
	end
	local upgrade = self._catalog.Upgrades[state.upgradeIndex]
	if not upgrade then
		return self:_reject(state, requestId, "all demo upgrades are already purchased", true)
	end
	if state.wallet < upgrade.price then
		return self:_reject(state, requestId, "insufficient server-authoritative balance")
	end

	state.wallet -= upgrade.price
	state.upgradeIndex += 1
	state.revision += 1
	local terminal = self._catalog.Upgrades[state.upgradeIndex] == nil
	return self:_remember(state, {
		requestId = requestId,
		success = true,
		controlId = self._catalog.ControlId,
		revision = state.revision,
		terminal = terminal,
		upgradeId = upgrade.id,
		upgradeName = upgrade.name,
		price = upgrade.price,
		wallet = state.wallet,
		purchaseCount = state.upgradeIndex - 1,
	})
end

return DemoPurchaseService
