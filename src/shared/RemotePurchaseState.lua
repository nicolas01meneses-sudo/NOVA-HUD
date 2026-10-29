--!strict

local RemotePurchaseState = {}
RemotePurchaseState.__index = RemotePurchaseState

export type Assessment = {
	status: "confirmed" | "observed" | "rejected" | "inconclusive",
	reason: string,
	evidence: { string },
}

export type State = {
	status: string,
	message: string,
	linked: boolean,
	activationCapable: boolean,
	autoUnlocked: boolean,
	autoEnabled: boolean,
	pending: boolean,
	lastAssessment: Assessment?,
}

export type Machine = typeof(setmetatable({} :: State, RemotePurchaseState))

function RemotePurchaseState.new(): Machine
	return setmetatable({
		status = "unlinked",
		message = "No Remote Buy control is linked",
		linked = false,
		activationCapable = false,
		autoUnlocked = false,
		autoEnabled = false,
		pending = false,
		lastAssessment = nil,
	}, RemotePurchaseState)
end

function RemotePurchaseState.link(self: Machine, activationCapable: boolean)
	self.linked = true
	self.activationCapable = activationCapable
	self.autoUnlocked = false
	self.autoEnabled = false
	self.pending = false
	self.lastAssessment = nil
	self.status = "linked"
	self.message = if activationCapable
		then "Control linked; one confirmed test is required"
		else "Control linked in observation mode"
end

function RemotePurchaseState.unlink(self: Machine, reason: string?)
	self.linked = false
	self.activationCapable = false
	self.autoUnlocked = false
	self.autoEnabled = false
	self.pending = false
	self.lastAssessment = nil
	self.status = "unlinked"
	self.message = reason or "Control link was cleared"
end

function RemotePurchaseState.beginTest(self: Machine): (boolean, string)
	if not self.linked then
		return false, "link a control first"
	end
	if self.pending then
		return false, "a verification is already pending"
	end
	self.pending = true
	self.status = "testing"
	self.message = if self.activationCapable
		then "Authorized request sent; waiting for evidence"
		else "Observation armed; press the game control manually"
	return true, self.message
end

function RemotePurchaseState.finishTest(self: Machine, assessment: Assessment)
	self.pending = false
	self.lastAssessment = assessment
	if assessment.status == "confirmed" then
		if self.activationCapable then
			self.autoUnlocked = true
			if self.autoEnabled then
				self.status = "auto"
				self.message = "Authorized Auto Remote Buy remains enabled"
			else
				self.status = "ready"
				self.message = "Confirmed test; authorized auto mode is available"
			end
		else
			self.status = "manual-verified"
			self.message = "Manual purchase confirmed; automation remains unavailable"
		end
	elseif assessment.status == "observed" then
		self.status = "observed"
		self.message = "Change observed but not confirmed; auto remains locked"
	elseif assessment.status == "rejected" then
		self.status = "rejected"
		self.message = assessment.reason
	else
		self.status = "inconclusive"
		self.message = assessment.reason
	end
end

function RemotePurchaseState.setAuto(self: Machine, enabled: boolean): (boolean, string)
	if not enabled then
		self.autoEnabled = false
		if self.autoUnlocked then
			self.status = "ready"
		end
		return true, "Auto Remote Buy disabled"
	end
	if not self.activationCapable then
		return false, "the current adapter is observation-only"
	end
	if not self.autoUnlocked then
		return false, "one authoritative test must be confirmed first"
	end
	if self.pending then
		return false, "wait for the pending verification"
	end
	self.autoEnabled = true
	self.status = "auto"
	return true, "Authorized Auto Remote Buy enabled"
end

function RemotePurchaseState.snapshot(self: Machine): State
	return {
		status = self.status,
		message = self.message,
		linked = self.linked,
		activationCapable = self.activationCapable,
		autoUnlocked = self.autoUnlocked,
		autoEnabled = self.autoEnabled,
		pending = self.pending,
		lastAssessment = self.lastAssessment,
	}
end

return RemotePurchaseState
