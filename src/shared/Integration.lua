--!strict

-- This resolver is the only integration seam for game-specific actions.
-- The default project does not include NOVA_AuthorizedIntegration, so it stays
-- read-only. An authorized Studio project may provide that exact ModuleScript.

export type RequestResult = {
	accepted: boolean,
	requestId: string?,
	reason: string?,
}

export type Receipt = {
	requestId: string,
	success: boolean,
	controlId: string?,
	revision: number?,
	terminal: boolean?,
	reason: string?,
}

export type Provider = {
	Authorized: boolean,
	ProviderId: string,
	Capabilities: { RemoteBuy: boolean },
	requestPurchase: (controlId: string, context: { [string]: any }) -> RequestResult,
	readReceipt: (requestId: string) -> Receipt?,
}

local DisabledProvider = {
	Authorized = false,
	ProviderId = "disabled",
	Capabilities = table.freeze({
		RemoteBuy = false,
		AutoBuy = false,
		AutoIce = false,
		AutoRebirth = false,
	}),
}

function DisabledProvider.requestPurchase(_controlId: string, _context: { [string]: any }): RequestResult
	return {
		accepted = false,
		reason = "No authorized purchase adapter is configured",
	}
end

function DisabledProvider.readReceipt(_requestId: string): Receipt?
	return nil
end

local Integration = {}

local function loadCandidate(candidate: any): (any?, string?)
	if candidate == nil then
		return nil, "NOVA_AuthorizedIntegration is not installed"
	end
	if type(candidate) == "table" then
		return candidate, nil
	end
	local ok, value = pcall(require, candidate)
	if not ok then
		return nil, "authorized provider failed to load: " .. tostring(value)
	end
	return value, nil
end

function Integration.resolve(candidate: any): (Provider, string)
	local provider, loadError = loadCandidate(candidate)
	if not provider then
		return DisabledProvider :: Provider, loadError or "authorized provider is unavailable"
	end
	if type(provider) ~= "table"
		or provider.Authorized ~= true
		or type(provider.ProviderId) ~= "string"
		or provider.ProviderId == ""
		or type(provider.Capabilities) ~= "table"
		or provider.Capabilities.RemoteBuy ~= true
		or type(provider.requestPurchase) ~= "function"
		or type(provider.readReceipt) ~= "function" then
		return DisabledProvider :: Provider, "authorized provider contract is invalid"
	end
	return provider :: Provider, "authorized provider: " .. provider.ProviderId
end

Integration.DisabledProvider = table.freeze(DisabledProvider)

return table.freeze(Integration)
