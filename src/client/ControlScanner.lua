--!strict

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.NOVA.Config)

export type Descriptor = {
	controlId: string?,
	source: string,
	screenGui: string,
	path: string,
	className: string,
	name: string,
	role: string,
	text: string,
	centerX: number,
	centerY: number,
	width: number,
	height: number,
	instance: GuiObject,
}

local ControlScanner = {}
ControlScanner.__index = ControlScanner

export type Scanner = typeof(setmetatable({} :: {
	_playerGui: PlayerGui,
	_lastScanCount: number,
	_lastTruncated: boolean,
}, ControlScanner))

local PREMIUM_WORDS = {
	"robux", "gamepass", "game pass", "premium", "marketplace",
	"donate", "donar", "catalog", "r$",
}

local ROLE_WORDS = {
	["remote-buy"] = { "remote buy", "compra remota" },
	["remote-confirm"] = { "confirm buy", "buy remote", "comprar remoto" },
	["purchase"] = { "buy", "comprar", "upgrade", "mejorar", "mejora" },
}

local TAG_ROLES = {
	NOVA_RemoteBuyControl = "remote-buy",
	NOVA_RemoteBuyConfirmation = "remote-confirm",
	NOVA_PurchaseControl = "purchase",
}

local function containsAny(text: string, words: { string }): boolean
	for _, word in ipairs(words) do
		if text:find(word, 1, true) then
			return true
		end
	end
	return false
end

local function stringAttribute(instance: Instance, name: string): string?
	local value = instance:GetAttribute(name)
	return if type(value) == "string" and value ~= "" then value else nil
end

local function isVisible(object: GuiObject): boolean
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
	return object.AbsoluteSize.X >= 6 and object.AbsoluteSize.Y >= 6
end

local function shortText(object: GuiObject): string
	local pieces = {}
	if object:IsA("TextButton") or object:IsA("TextLabel") or object:IsA("TextBox") then
		table.insert(pieces, object.Text)
	end
	local checked = 0
	for _, child in ipairs(object:GetDescendants()) do
		checked += 1
		if checked > 36 then
			break
		end
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			local text = child.Text
			if #text <= 90 then
				table.insert(pieces, text)
			end
		end
	end
	return table.concat(pieces, " "):sub(1, 240)
end

local function contextText(object: GuiObject): string
	local values = { object.Name }
	local current: Instance? = object.Parent
	for _ = 1, 6 do
		if not current or current:IsA("PlayerGui") then
			break
		end
		table.insert(values, current.Name)
		current = current.Parent
	end
	return table.concat(values, " "):lower()
end

local function pathFromScreen(object: GuiObject, screen: ScreenGui?): string
	local values = {}
	local current: Instance? = object
	while current and current ~= screen do
		table.insert(values, 1, current.Name)
		current = current.Parent
	end
	return table.concat(values, "/")
end

local function explicitRole(object: GuiObject): (string?, string?)
	local attribute = object:GetAttribute("NOVA_Role")
	if type(attribute) == "string" and attribute ~= "" then
		return attribute, "attribute"
	end
	for tag, role in pairs(TAG_ROLES) do
		if CollectionService:HasTag(object, tag) then
			return role, "tag"
		end
	end
	return nil, nil
end

local function heuristicRole(object: GuiObject, words: string): string?
	-- Observation mode can bind a composite control whose clickable region is
	-- an Active Frame instead of a GuiButton. This expands detection only; it
	-- never grants activation capability to a heuristic binding.
	if not object:IsA("GuiButton") and not object.Active then
		return nil
	end
	for role, tokens in pairs(ROLE_WORDS) do
		if containsAny(words, tokens) then
			return role
		end
	end
	return nil
end

function ControlScanner.new(playerGui: PlayerGui?): Scanner
	local localPlayer = Players.LocalPlayer
	local resolved = playerGui or (localPlayer and localPlayer:WaitForChild("PlayerGui"))
	assert(resolved and resolved:IsA("PlayerGui"), "PlayerGui is required")
	return setmetatable({
		_playerGui = resolved,
		_lastScanCount = 0,
		_lastTruncated = false,
	}, ControlScanner)
end

function ControlScanner.describe(self: Scanner, object: GuiObject): Descriptor?
	if not object:IsDescendantOf(self._playerGui) or object:GetAttribute("NOVA_Internal") == true
		or not isVisible(object) then
		return nil
	end
	local text = shortText(object)
	local context = contextText(object)
	local combined = (text .. " " .. context):lower()
	if containsAny(combined, PREMIUM_WORDS) then
		return nil
	end
	local role, source = explicitRole(object)
	role = role or heuristicRole(object, combined)
	source = source or (role and "heuristic" or nil)
	if not role or not source then
		return nil
	end
	local screen = object:FindFirstAncestorOfClass("ScreenGui")
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1, 1)
	local position = object.AbsolutePosition
	local size = object.AbsoluteSize
	return {
		controlId = stringAttribute(object, "NOVA_ControlId"),
		source = source,
		screenGui = screen and screen.Name or "",
		path = pathFromScreen(object, screen),
		className = object.ClassName,
		name = object.Name,
		role = role,
		text = text,
		centerX = (position.X + size.X * 0.5) / math.max(1, viewport.X),
		centerY = (position.Y + size.Y * 0.5) / math.max(1, viewport.Y),
		width = size.X / math.max(1, viewport.X),
		height = size.Y / math.max(1, viewport.Y),
		instance = object,
	}
end

function ControlScanner.scan(self: Scanner, requestedRole: string?): { Descriptor }
	local descriptors: { Descriptor } = {}
	local queue: { Instance } = { self._playerGui }
	local nextIndex = 1
	local checked = 0
	self._lastTruncated = false
	while nextIndex <= #queue do
		local instance = queue[nextIndex]
		nextIndex += 1
		if instance ~= self._playerGui and instance:GetAttribute("NOVA_Internal") == true then
			continue
		end
		if instance:IsA("GuiObject") then
			if checked >= Config.MaximumScannedGuiObjects then
				self._lastTruncated = true
				break
			end
			checked += 1
			local descriptor = self:describe(instance)
			if descriptor and (not requestedRole or descriptor.role == requestedRole) then
				table.insert(descriptors, descriptor)
			end
		end
		for _, child in ipairs(instance:GetChildren()) do
			table.insert(queue, child)
		end
	end
	self._lastScanCount = checked
	table.sort(descriptors, function(left, right)
		local leftExplicit = if left.source == "heuristic" then 0 else 1
		local rightExplicit = if right.source == "heuristic" then 0 else 1
		if leftExplicit ~= rightExplicit then
			return leftExplicit > rightExplicit
		end
		return left.path < right.path
	end)
	return descriptors
end

function ControlScanner.diagnostics(self: Scanner): { scanned: number, truncated: boolean }
	return {
		scanned = self._lastScanCount,
		truncated = self._lastTruncated,
	}
end

return ControlScanner
