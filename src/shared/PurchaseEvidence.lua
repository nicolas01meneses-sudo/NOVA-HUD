--!strict

local Amount = if script ~= nil
	then require(script.Parent.Amount)
	else require("./Amount")

export type Snapshot = {
	capturedAt: number,
	controlKey: string?,
	controlPresent: boolean,
	controlText: string?,
	price: Amount.Amount?,
	walletKey: string?,
	wallet: Amount.Amount?,
	counterKey: string?,
	counter: number?,
}

export type Receipt = {
	requestId: string,
	success: boolean,
	controlId: string?,
	revision: number?,
	terminal: boolean?,
	reason: string?,
}

export type Assessment = {
	status: "confirmed" | "observed" | "rejected" | "inconclusive",
	reason: string,
	evidence: { string },
	terminal: boolean?,
}

local PurchaseEvidence = {}

local function sameStableKey(left: string?, right: string?): boolean
	return left ~= nil and right ~= nil and left == right
end

function PurchaseEvidence.assess(
	before: Snapshot,
	after: Snapshot,
	receipt: Receipt?
): Assessment
	if receipt then
		if receipt.success then
			return {
				status = "confirmed",
				reason = "authorized adapter returned a successful receipt",
				evidence = { "receipt:" .. receipt.requestId },
				terminal = receipt.terminal == true,
			}
		end
		return {
			status = "rejected",
			reason = receipt.reason or "authorized adapter rejected the purchase",
			evidence = { "receipt:" .. receipt.requestId },
		}
	end

	if sameStableKey(before.counterKey, after.counterKey)
		and before.counter ~= nil and after.counter ~= nil
		and after.counter > before.counter then
		return {
			status = "confirmed",
			reason = "the explicitly bound purchase counter increased",
			evidence = { string.format("counter:+%d", after.counter - before.counter) },
		}
	end

	local observed = {}
	if sameStableKey(before.walletKey, after.walletKey)
		and Amount.decreased(before.wallet, after.wallet) then
		table.insert(observed, "wallet-decreased")
	end
	if sameStableKey(before.controlKey, after.controlKey) then
		if before.controlText ~= after.controlText then
			table.insert(observed, "control-text-changed")
		end
		if not Amount.equal(before.price, after.price) then
			table.insert(observed, "price-changed")
		end
	end
	if before.controlPresent and not after.controlPresent then
		table.insert(observed, "control-disappeared")
	end

	if #observed > 0 then
		return {
			status = "observed",
			reason = "UI changed, but there is no authoritative purchase evidence",
			evidence = observed,
		}
	end
	return {
		status = "inconclusive",
		reason = "no correlated UI change was observed",
		evidence = {},
	}
end

return table.freeze(PurchaseEvidence)
