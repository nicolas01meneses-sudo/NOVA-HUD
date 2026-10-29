--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Amount = require(ReplicatedStorage.NOVA.Amount)

local PriceReader = {}

local PRICE_ATTRIBUTES = { "NOVA_Price", "Price", "Cost" }

local function visible(object: GuiObject): boolean
	local current: Instance? = object
	while current do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		if current:IsA("ScreenGui") and not current.Enabled then
			return false
		end
		current = current.Parent
	end
	return true
end

local function textOf(instance: Instance): string?
	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		return instance.Text
	end
	return nil
end

local function currencyAttribute(instance: Instance): string?
	local value = instance:GetAttribute("NOVA_Currency")
	return if type(value) == "string" and value ~= "" then value else nil
end

local function amountFromAttribute(instance: Instance): Amount.Amount?
	local currency = currencyAttribute(instance)
	for _, attribute in ipairs(PRICE_ATTRIBUTES) do
		local value = instance:GetAttribute(attribute)
		if type(value) == "number" then
			return Amount.fromNumber(value, currency)
		elseif type(value) == "string" then
			local parsed = Amount.parse(value, currency)
			if parsed then
				return parsed
			end
		end
	end
	return nil
end

local function uniqueTextAmount(scope: Instance, maximumDescendants: number): Amount.Amount?
	local values = {}
	local seen = {}
	local checked = 0
	for _, child in ipairs(scope:GetDescendants()) do
		checked += 1
		if checked > maximumDescendants then
			break
		end
		local raw = textOf(child)
		if raw and child:IsA("GuiObject") and visible(child) then
			local parsed = Amount.parse(raw)
			if parsed then
				local key = string.format("%s:%d:%.9g", parsed.currency or "", parsed.exponent3, parsed.coefficient)
				if not seen[key] then
					seen[key] = true
					table.insert(values, parsed)
				end
			end
		end
	end
	return if #values == 1 then values[1] else nil
end

function PriceReader.readControlPrice(control: Instance?): Amount.Amount?
	if not control then
		return nil
	end
	local current: Instance? = control
	for _ = 1, 4 do
		if not current then
			break
		end
		local attributed = amountFromAttribute(current)
		if attributed then
			return attributed
		end
		current = current.Parent
	end
	local scope = control.Parent
	if not scope then
		return nil
	end
	return uniqueTextAmount(scope, 48)
end

local function explicitTaggedGui(tagName: string, playerGui: PlayerGui): GuiObject?
	local found: GuiObject? = nil
	for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
		if instance:IsA("GuiObject") and instance:IsDescendantOf(playerGui) and visible(instance) then
			if found then
				return nil
			end
			found = instance
		end
	end
	return found
end

function PriceReader.readWallet(playerGui: PlayerGui): (string?, Amount.Amount?)
	local label = explicitTaggedGui("NOVA_WalletLabel", playerGui)
	if not label then
		return nil, nil
	end
	local value = amountFromAttribute(label)
	if not value then
		local raw = textOf(label)
		value = raw and Amount.parse(raw) or nil
	end
	local key = label:GetAttribute("NOVA_ControlId")
	return tostring(key or label:GetFullName()), value
end

function PriceReader.readPurchaseCounter(playerGui: PlayerGui): (string?, number?)
	local label = explicitTaggedGui("NOVA_PurchaseCounter", playerGui)
	if not label then
		return nil, nil
	end
	local rawValue = label:GetAttribute("NOVA_Count")
	local value = if type(rawValue) == "number" then rawValue else nil
	if value == nil then
		local rawText = textOf(label) or ""
		value = tonumber(rawText:match("(%d+)%s*/%s*%d+") or rawText:match("(%d+)"))
	end
	local key = label:GetAttribute("NOVA_ControlId")
	return tostring(key or label:GetFullName()), value
end

return table.freeze(PriceReader)
