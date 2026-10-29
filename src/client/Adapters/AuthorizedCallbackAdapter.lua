--!strict

export type Integration = {
	Authorized: boolean,
	Capabilities: { RemoteBuy: boolean },
	requestPurchase: (controlId: string, context: { [string]: any }) -> {
		accepted: boolean,
		requestId: string?,
		reason: string?,
	},
	readReceipt: (requestId: string) -> any?,
}

local AuthorizedCallbackAdapter = {}
AuthorizedCallbackAdapter.__index = AuthorizedCallbackAdapter

export type Adapter = typeof(setmetatable({} :: { _integration: Integration }, AuthorizedCallbackAdapter))

function AuthorizedCallbackAdapter.new(integration: Integration): Adapter
	assert(integration.Authorized == true, "integration must explicitly set Authorized=true")
	assert(integration.Capabilities.RemoteBuy == true, "RemoteBuy capability is not enabled")
	return setmetatable({ _integration = integration }, AuthorizedCallbackAdapter)
end

function AuthorizedCallbackAdapter.canActivate(_self: Adapter): boolean
	return true
end

function AuthorizedCallbackAdapter.requestPurchase(
	self: Adapter,
	controlId: string,
	context: { [string]: any }
)
	if controlId == "" then
		return { accepted = false, reason = "an explicit NOVA_ControlId is required" }
	end
	local ok, result = pcall(self._integration.requestPurchase, controlId, context)
	if not ok then
		return { accepted = false, reason = "authorized callback failed: " .. tostring(result) }
	end
	if type(result) ~= "table" or type(result.accepted) ~= "boolean" then
		return { accepted = false, reason = "authorized callback returned an invalid result" }
	end
	if result.accepted and (type(result.requestId) ~= "string" or result.requestId == "") then
		return { accepted = false, reason = "accepted requests require a non-empty requestId" }
	end
	return result
end

function AuthorizedCallbackAdapter.readReceipt(self: Adapter, requestId: string)
	local ok, receipt = pcall(self._integration.readReceipt, requestId)
	return if ok then receipt else nil
end

return AuthorizedCallbackAdapter
