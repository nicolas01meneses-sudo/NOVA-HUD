--!strict

local ConnectionBag = {}
ConnectionBag.__index = ConnectionBag

export type Disconnectable = RBXScriptConnection | { Disconnect: (self: any) -> () }
export type Bag = typeof(setmetatable({} :: { _items: { Disconnectable } }, ConnectionBag))

function ConnectionBag.new(): Bag
	return setmetatable({ _items = {} }, ConnectionBag)
end

function ConnectionBag.add(self: Bag, item: Disconnectable): Disconnectable
	table.insert(self._items, item)
	return item
end

function ConnectionBag.disconnectAll(self: Bag)
	for index = #self._items, 1, -1 do
		local item = self._items[index]
		self._items[index] = nil
		pcall(function()
			item:Disconnect()
		end)
	end
end

return ConnectionBag
