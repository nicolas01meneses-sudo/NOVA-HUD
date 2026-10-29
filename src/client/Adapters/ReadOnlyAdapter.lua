--!strict

local ReadOnlyAdapter = {}
ReadOnlyAdapter.__index = ReadOnlyAdapter

export type Adapter = typeof(setmetatable({}, ReadOnlyAdapter))

function ReadOnlyAdapter.new(): Adapter
	return setmetatable({}, ReadOnlyAdapter)
end

function ReadOnlyAdapter.canActivate(_self: Adapter): boolean
	return false
end

function ReadOnlyAdapter.requestPurchase(_self: Adapter, _controlId: string, _context: { [string]: any })
	return {
		accepted = false,
		reason = "observation mode cannot activate game controls",
	}
end

function ReadOnlyAdapter.readReceipt(_self: Adapter, _requestId: string)
	return nil
end

return ReadOnlyAdapter
