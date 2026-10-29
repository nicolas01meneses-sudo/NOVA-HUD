--!strict

export type Amount = {
	coefficient: number,
	exponent3: number,
	currency: string?,
	label: string,
}

local Amount = {}

local SUFFIXES: { [string]: number } = {
	[""] = 0,
	k = 1,
	mil = 1,
	m = 2,
	million = 2,
	millions = 2,
	["millón"] = 2,
	millones = 2,
	b = 3,
	billion = 3,
	["billón"] = 3,
	billones = 3,
	trillion = 4,
	t = 4,
	["trillón"] = 4,
	quadrillion = 5,
	["cuatrillón"] = 5,
	quintillion = 6,
	["quintillón"] = 6,
	sextillion = 7,
	["sextillón"] = 7,
	septillion = 8,
	["septillón"] = 8,
	octillion = 9,
	["octillón"] = 9,
	nonillion = 10,
	["nonillón"] = 10,
	decillion = 11,
	["decillón"] = 11,
	undecillion = 12,
	["undecillón"] = 12,
	duodecillion = 13,
	["duodecillón"] = 13,
	tredecillion = 14,
	["tredecillón"] = 14,
	quattuordecillion = 15,
	["cuatordecillón"] = 15,
	quindecillion = 16,
	["quindecillón"] = 16,
	sexdecillion = 17,
	["sexdecillón"] = 17,
	septendecillion = 18,
	["septendecillón"] = 18,
	octodecillion = 19,
	["octodecillón"] = 19,
	novemdecillion = 20,
	["novemdecillón"] = 20,
	vigintillion = 21,
	["vigintillón"] = 21,
	trigintillion = 31,
	["trigintillón"] = 31,
}

local function trim(value: string): string
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalized(amount: Amount): Amount?
	local coefficient = amount.coefficient
	local exponent3 = amount.exponent3
	if coefficient ~= coefficient or coefficient < 0 or exponent3 < 0 then
		return nil
	end
	if coefficient == 0 then
		return {
			coefficient = 0,
			exponent3 = 0,
			currency = amount.currency,
			label = amount.label,
		}
	end
	while coefficient >= 1000 do
		coefficient /= 1000
		exponent3 += 1
	end
	while coefficient < 1 and exponent3 > 0 do
		coefficient *= 1000
		exponent3 -= 1
	end
	return {
		coefficient = coefficient,
		exponent3 = exponent3,
		currency = amount.currency,
		label = amount.label,
	}
end

local function parseDigits(raw: string, exponent3: number): number?
	local separators = select(2, raw:gsub("[,%.]", ""))
	local digits = raw
	if separators > 1 then
		digits = digits:gsub("[,%.]", "")
	elseif separators == 1 then
		local tail = digits:match("[,%.](%d+)$")
		if tail and #tail == 3 and exponent3 == 0 then
			digits = digits:gsub("[,%.]", "")
		else
			digits = digits:gsub(",", ".")
		end
	end
	return tonumber(digits)
end

function Amount.fromNumber(value: number, currency: string?, label: string?): Amount?
	return normalized({
		coefficient = value,
		exponent3 = 0,
		currency = currency,
		label = label or tostring(value),
	})
end

function Amount.parse(text: string, expectedCurrency: string?): (Amount?, string?)
	if type(text) ~= "string" then
		return nil, "amount is not text"
	end
	local first, last, rawDigits = text:find("([%d][%d%.,]*)")
	if not first or not last or not rawDigits then
		return nil, "no numeric amount"
	end

	local before = trim(text:sub(1, first - 1))
	local after = trim(text:sub(last + 1))
	local currency = before:match("([%$Φ])%s*$")
	if expectedCurrency and currency and currency ~= expectedCurrency then
		return nil, "currency mismatch"
	end

	local suffix = (after:match("^([^%s]+)") or ""):lower():gsub("[%p]+$", "")
	local exponent3 = SUFFIXES[suffix]
	if exponent3 == nil then
		return nil, "unknown suffix"
	end
	local coefficient = parseDigits(rawDigits, exponent3)
	if not coefficient then
		return nil, "invalid number"
	end
	local result = normalized({
		coefficient = coefficient,
		exponent3 = exponent3,
		currency = currency or expectedCurrency,
		label = trim(text),
	})
	if not result then
		return nil, "invalid amount"
	end
	return result, nil
end

function Amount.compare(left: Amount, right: Amount): number
	local a = normalized(left)
	local b = normalized(right)
	assert(a and b, "cannot compare invalid amounts")
	if a.currency and b.currency and a.currency ~= b.currency then
		error("cannot compare different currencies")
	end
	if a.exponent3 ~= b.exponent3 then
		return if a.exponent3 < b.exponent3 then -1 else 1
	end
	if math.abs(a.coefficient - b.coefficient) < 1e-9 then
		return 0
	end
	return if a.coefficient < b.coefficient then -1 else 1
end

function Amount.decreased(before: Amount?, after: Amount?): boolean
	if not before or not after then
		return false
	end
	local ok, result = pcall(Amount.compare, after, before)
	return ok and result < 0
end

function Amount.equal(left: Amount?, right: Amount?): boolean
	if not left or not right then
		return left == right
	end
	local ok, result = pcall(Amount.compare, left, right)
	return ok and result == 0
end

return table.freeze(Amount)
