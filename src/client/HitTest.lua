--!strict

local HitTest = {}

local function addAncestors(
	objects: { GuiObject },
	seen: { [GuiObject]: boolean },
	object: GuiObject
)
	local current: Instance? = object
	for _ = 1, 6 do
		if not current or current:IsA("ScreenGui") or current:IsA("PlayerGui") then
			break
		end
		if current:IsA("GuiObject") and not seen[current] then
			seen[current] = true
			table.insert(objects, current)
		end
		current = current.Parent
	end
end

local function query(playerGui: PlayerGui, point: Vector2): { GuiObject }
	local ok, result = pcall(function()
		return playerGui:GetGuiObjectsAtPosition(math.floor(point.X), math.floor(point.Y))
	end)
	if not ok then
		return {}
	end
	return result
end

function HitTest.pointsForInput(guiService: GuiService, inputPosition: Vector2): { Vector2 }
	local points = {}
	local ok, topLeftInset = pcall(function()
		local topLeft = guiService:GetGuiInset()
		return topLeft
	end)
	if ok and topLeftInset then
		table.insert(points, Vector2.new(
			math.max(0, inputPosition.X - topLeftInset.X),
			math.max(0, inputPosition.Y - topLeftInset.Y)
		))
	end
	table.insert(points, inputPosition)
	return points
end

function HitTest.pick(
	playerGui: PlayerGui,
	guiService: GuiService,
	inputPosition: Vector2,
	predicate: (GuiObject) -> boolean
): (GuiObject?, string)
	local objects = {}
	local seen = {}
	for index, point in ipairs(HitTest.pointsForInput(guiService, inputPosition)) do
		for _, object in ipairs(query(playerGui, point)) do
			addAncestors(objects, seen, object)
		end
		for _, object in ipairs(objects) do
			if object:GetAttribute("NOVA_Internal") ~= true and predicate(object) then
				return object, if index == 1 then "gui-inset-adjusted" else "raw-input-position"
			end
		end
	end
	return nil, "no eligible GuiObject at input position"
end

return table.freeze(HitTest)
