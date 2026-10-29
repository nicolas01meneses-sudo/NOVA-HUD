--!strict

export type Handle = {
	Disconnect: (self: Handle) -> (),
}

local TapCapture = {}

function TapCapture.connect(
	userInputService: UserInputService,
	callback: (position: Vector2, source: string) -> ()
): Handle
	local connections: { RBXScriptConnection } = {}
	local disconnected = false

	table.insert(connections, userInputService.TouchTap:Connect(function(positions)
		if disconnected or #positions ~= 1 then
			return
		end
		callback(positions[1], "touch-tap")
	end))

	table.insert(connections, userInputService.InputEnded:Connect(function(input)
		if disconnected or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		callback(Vector2.new(input.Position.X, input.Position.Y), "mouse-click")
	end))

	local handle = {} :: any
	function handle:Disconnect()
		if disconnected then
			return
		end
		disconnected = true
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		table.clear(connections)
	end
	return handle :: Handle
end

return table.freeze(TapCapture)
