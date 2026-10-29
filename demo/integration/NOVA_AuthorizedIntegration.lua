--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
assert(player, "NOVA authorized integration requires a LocalPlayer")

local demoFolder = ReplicatedStorage:WaitForChild("NOVA_Demo")
local purchaseRemote = demoFolder:WaitForChild("PurchaseUpgrade") :: RemoteFunction
local receipts: { [string]: any } = {}

local Integration = {
	Authorized = true,
	ProviderId = "nova-studio-demo-v1",
	Capabilities = table.freeze({
		RemoteBuy = true,
		AutoBuy = false,
		AutoIce = false,
		AutoRebirth = false,
	}),
}

function Integration.requestPurchase(controlId: string, _context: { [string]: any })
	local revision = player:GetAttribute("NOVA_DemoRevision")
	if type(revision) ~= "number" then
		return {
			accepted = false,
			reason = "server revision is not replicated yet",
		}
	end
	local requestId = HttpService:GenerateGUID(false)
	local ok, receipt = pcall(function()
		return purchaseRemote:InvokeServer({
			requestId = requestId,
			controlId = controlId,
			expectedRevision = revision,
		})
	end)
	if not ok then
		return {
			accepted = false,
			reason = "PurchaseUpgrade invocation failed: " .. tostring(receipt),
		}
	end
	if type(receipt) ~= "table" or receipt.requestId ~= requestId
		or type(receipt.success) ~= "boolean" then
		return {
			accepted = false,
			reason = "server returned an invalid or uncorrelated receipt",
		}
	end
	receipts[requestId] = receipt
	return {
		accepted = true,
		requestId = requestId,
	}
end

function Integration.readReceipt(requestId: string)
	local receipt = receipts[requestId]
	return if receipt then table.clone(receipt) else nil
end

return table.freeze(Integration)
