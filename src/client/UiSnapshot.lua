--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PriceReader = require(script.Parent.PriceReader)

local PurchaseEvidence = require(ReplicatedStorage.NOVA.PurchaseEvidence)

export type Descriptor = {
	controlId: string?,
	source: string,
	screenGui: string,
	path: string,
	className: string,
	name: string,
	role: string,
	text: string,
	centerX: number,
	centerY: number,
	width: number,
	height: number,
	instance: GuiObject,
}

local UiSnapshot = {}
UiSnapshot.__index = UiSnapshot

export type Snapshotter = typeof(setmetatable({} :: { _playerGui: PlayerGui }, UiSnapshot))

function UiSnapshot.new(playerGui: PlayerGui): Snapshotter
	return setmetatable({ _playerGui = playerGui }, UiSnapshot)
end

function UiSnapshot.getPlayerGui(self: Snapshotter): PlayerGui
	return self._playerGui
end

function UiSnapshot.capture(
	self: Snapshotter,
	descriptor: Descriptor?,
	fallbackControlKey: string?
): PurchaseEvidence.Snapshot
	local instance = descriptor and descriptor.instance or nil
	local present = instance ~= nil and instance.Parent ~= nil
		and instance:IsDescendantOf(self._playerGui)
	local controlKey = if descriptor
		then descriptor.controlId or (descriptor.screenGui .. ":" .. descriptor.path)
		else fallbackControlKey
	local walletKey, wallet = PriceReader.readWallet(self._playerGui)
	local counterKey, counter = PriceReader.readPurchaseCounter(self._playerGui)
	return {
		capturedAt = os.clock(),
		controlKey = controlKey,
		controlPresent = present,
		controlText = descriptor and descriptor.text or nil,
		price = PriceReader.readControlPrice(instance),
		walletKey = walletKey,
		wallet = wallet,
		counterKey = counterKey,
		counter = counter,
	}
end

return UiSnapshot
