--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.NOVA.Config)
local ControlFingerprint = require(ReplicatedStorage.NOVA.ControlFingerprint)
local PurchaseEvidence = require(ReplicatedStorage.NOVA.PurchaseEvidence)
local RemotePurchaseState = require(ReplicatedStorage.NOVA.RemotePurchaseState)
local HitTest = require(script.Parent.HitTest)

export type Descriptor = ControlFingerprint.Descriptor

type Pending = {
	before: PurchaseEvidence.Snapshot,
	controlKey: string?,
	requestId: string?,
	manual: boolean,
}

local RemotePurchaseController = {}
RemotePurchaseController.__index = RemotePurchaseController

export type Controller = typeof(setmetatable({} :: {
	_scanner: any,
	_snapshotter: any,
	_adapter: any,
	_machine: RemotePurchaseState.Machine,
	_fingerprint: ControlFingerprint.Fingerprint?,
	_pending: Pending?,
	_lastActionAt: number,
	_failures: number,
	_manualConnection: RBXScriptConnection?,
	_onStatus: (RemotePurchaseState.State) -> (),
	_destroyed: boolean,
}, RemotePurchaseController))

local function rejected(reason: string): PurchaseEvidence.Assessment
	return {
		status = "rejected",
		reason = reason,
		evidence = {},
	}
end

function RemotePurchaseController.new(
	scanner: any,
	snapshotter: any,
	adapter: any,
	onStatus: ((RemotePurchaseState.State) -> ())?
): Controller
	local self = setmetatable({
		_scanner = scanner,
		_snapshotter = snapshotter,
		_adapter = adapter,
		_machine = RemotePurchaseState.new(),
		_fingerprint = nil,
		_pending = nil,
		_lastActionAt = -math.huge,
		_failures = 0,
		_manualConnection = nil,
		_onStatus = onStatus or function() end,
		_destroyed = false,
	}, RemotePurchaseController)
	self:_notify()
	return self
end

function RemotePurchaseController._notify(self: Controller)
	self._onStatus(self._machine:snapshot())
end

function RemotePurchaseController.link(self: Controller, descriptor: Descriptor): (boolean, string)
	if self._destroyed then
		return false, "controller is destroyed"
	end
	if self._machine.pending then
		return false, "finish or cancel the pending verification before relinking"
	end
	if descriptor.role ~= "remote-buy" and descriptor.role ~= "remote-confirm"
		and descriptor.role ~= "purchase" then
		return false, "the selected object is not a purchase control"
	end
	self._fingerprint = ControlFingerprint.capture(descriptor)
	local explicit = descriptor.source ~= "heuristic" and descriptor.controlId ~= nil
	local activationCapable = self._adapter:canActivate() and explicit
	self._machine:link(activationCapable)
	self._failures = 0
	self:_notify()
	return true, if activationCapable
		then "explicit purchase control linked"
		else "control linked for observation; no authorized activation is available"
end

function RemotePurchaseController.resolve(self: Controller): (Descriptor?, string)
	local fingerprint = self._fingerprint
	if not fingerprint then
		return nil, "no control fingerprint"
	end
	local candidates = self._scanner:scan(fingerprint.role)
	local result = ControlFingerprint.resolve(
		fingerprint,
		candidates,
		Config.BindingMinimumScore,
		Config.BindingMinimumGap
	)
	return result.descriptor, result.reason
end

function RemotePurchaseController._finishVerification(self: Controller)
	if self._destroyed then
		return
	end
	local pending = self._pending
	if not pending then
		return
	end
	self._pending = nil
	local descriptor = self:resolve()
	local after = self._snapshotter:capture(descriptor, pending.controlKey)
	local receipt = nil
	if pending.requestId then
		receipt = self._adapter:readReceipt(pending.requestId)
	end
	local assessment
	if receipt and receipt.requestId ~= pending.requestId then
		assessment = rejected("authorized receipt did not match the pending request")
	elseif receipt and receipt.controlId and pending.controlKey
		and receipt.controlId ~= pending.controlKey then
		assessment = rejected("authorized receipt referred to another control")
	else
		assessment = PurchaseEvidence.assess(pending.before, after, receipt)
	end
	self._machine:finishTest(assessment)
	if assessment.status == "confirmed" then
		self._failures = 0
	else
		self._failures += 1
		if self._machine.autoEnabled and self._failures >= 2 then
			self._machine:setAuto(false)
			self._machine.message = "Auto stopped after two unconfirmed attempts"
		end
	end
	self:_notify()
end

function RemotePurchaseController._scheduleVerification(self: Controller)
	task.delay(Config.VerificationDelaySeconds, function()
		self:_finishVerification()
	end)
end

function RemotePurchaseController._beginAuthorized(self: Controller): (boolean, string)
	if os.clock() - self._lastActionAt < Config.MinimumPurchaseIntervalSeconds then
		return false, "waiting for the minimum purchase interval"
	end
	local descriptor, reason = self:resolve()
	if not descriptor then
		return false, "linked control could not be resolved: " .. reason
	end
	if descriptor.source == "heuristic" or not descriptor.controlId then
		return false, "automation requires an explicit NOVA_ControlId"
	end
	local began, beginReason = self._machine:beginTest()
	if not began then
		return false, beginReason
	end
	local before = self._snapshotter:capture(descriptor, descriptor.controlId)
	local result = self._adapter:requestPurchase(descriptor.controlId, {
		role = descriptor.role,
		price = before.price,
		capturedAt = before.capturedAt,
	})
	self._lastActionAt = os.clock()
	if not result.accepted then
		self._machine:finishTest(rejected(result.reason or "authorized request was not accepted"))
		self._failures += 1
		if self._machine.autoEnabled and self._failures >= 2 then
			self._machine:setAuto(false)
			self._machine.message = "Auto stopped after two rejected requests"
		end
		self:_notify()
		return false, self._machine.message
	end
	self._pending = {
		before = before,
		controlKey = before.controlKey,
		requestId = result.requestId,
		manual = false,
	}
	self:_notify()
	self:_scheduleVerification()
	return true, "authorized request accepted; verification pending"
end

function RemotePurchaseController._armManual(
	self: Controller,
	userInputService: UserInputService,
	guiService: GuiService
): (boolean, string)
	local descriptor, reason = self:resolve()
	if not descriptor then
		return false, "linked control could not be resolved: " .. reason
	end
	local began, beginReason = self._machine:beginTest()
	if not began then
		return false, beginReason
	end
	local fallbackKey = descriptor.controlId or (descriptor.screenGui .. ":" .. descriptor.path)
	local before = self._snapshotter:capture(descriptor, fallbackKey)
	if self._manualConnection then
		self._manualConnection:Disconnect()
	end
	local armedAt = os.clock()
	self._manualConnection = userInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local current = self:resolve()
		if not current then
			return
		end
		local selected = HitTest.pick(
			self._snapshotter:getPlayerGui(),
			guiService,
			Vector2.new(input.Position.X, input.Position.Y),
			function(candidate)
				return candidate == current.instance
					or candidate:IsDescendantOf(current.instance)
					or current.instance:IsDescendantOf(candidate)
			end
		)
		if not selected then
			return
		end
		if self._manualConnection then
			self._manualConnection:Disconnect()
			self._manualConnection = nil
		end
		self._lastActionAt = os.clock()
		self._pending = {
			before = before,
			controlKey = before.controlKey,
			requestId = nil,
			manual = true,
		}
		self:_notify()
		self:_scheduleVerification()
	end)
	task.delay(15, function()
		if self._destroyed or not self._machine.pending or self._pending ~= nil
			or os.clock() - armedAt < 14.5 then
			return
		end
		if self._manualConnection then
			self._manualConnection:Disconnect()
			self._manualConnection = nil
		end
		self._machine:finishTest({
			status = "inconclusive",
			reason = "manual observation timed out without a tap on the bound control",
			evidence = {},
		})
		self:_notify()
	end)
	self:_notify()
	return true, "observation armed; tap the linked game control manually"
end

function RemotePurchaseController.testOnce(
	self: Controller,
	userInputService: UserInputService,
	guiService: GuiService
): (boolean, string)
	if self._machine.activationCapable then
		return self:_beginAuthorized()
	end
	return self:_armManual(userInputService, guiService)
end

function RemotePurchaseController.setAutoEnabled(self: Controller, enabled: boolean): (boolean, string)
	local ok, reason = self._machine:setAuto(enabled)
	self:_notify()
	return ok, reason
end

function RemotePurchaseController.step(self: Controller)
	if self._destroyed or not self._machine.autoEnabled or self._machine.pending then
		return
	end
	local ok = self:_beginAuthorized()
	if not ok and os.clock() - self._lastActionAt >= Config.MinimumPurchaseIntervalSeconds then
		self._lastActionAt = os.clock()
	end
end

function RemotePurchaseController.getState(self: Controller): RemotePurchaseState.State
	return self._machine:snapshot()
end

function RemotePurchaseController.destroy(self: Controller)
	self._destroyed = true
	self._pending = nil
	if self._manualConnection then
		self._manualConnection:Disconnect()
		self._manualConnection = nil
	end
	self._machine:unlink("controller destroyed")
end

return RemotePurchaseController
