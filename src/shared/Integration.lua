--!strict

-- This module is the only integration seam for game-specific actions.
-- Keep Authorized=false in third-party experiences. The game owner may replace
-- the callbacks inside their own Studio project with server-validated logic.

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
	reason: string?,
}

local Integration = {
	Authorized = false,
	Capabilities = table.freeze({
		RemoteBuy = false,
		AutoBuy = false,
		AutoIce = false,
		AutoRebirth = false,
	}),
}

function Integration.requestPurchase(_controlId: string, _context: { [string]: any }): RequestResult
	return {
		accepted = false,
		reason = "No authorized purchase adapter is configured",
	}
end

function Integration.readReceipt(_requestId: string): Receipt?
	return nil
end

return table.freeze(Integration)
