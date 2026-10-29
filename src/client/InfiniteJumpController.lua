--!strict

local InfiniteJumpController = {}
InfiniteJumpController.__index = InfiniteJumpController

export type Controller = typeof(setmetatable({} :: {
	_player: Player,
	_allowed: boolean,
	_enabled: boolean,
	_lastJumpAt: number,
	_connection: RBXScriptConnection?,
}, InfiniteJumpController))

function InfiniteJumpController.new(
	player: Player,
	userInputService: UserInputService,
	allowedByGameOwner: boolean
): Controller
	local self = setmetatable({
		_player = player,
		_allowed = allowedByGameOwner,
		_enabled = false,
		_lastJumpAt = -math.huge,
		_connection = nil,
	}, InfiniteJumpController)
	self._connection = userInputService.JumpRequest:Connect(function()
		if not self._enabled or not self._allowed then
			return
		end
		local now = os.clock()
		if now - self._lastJumpAt < 0.12 then
			return
		end
		local character = self._player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or humanoid.Sit then
			return
		end
		self._lastJumpAt = now
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end)
	return self
end

function InfiniteJumpController.setEnabled(self: Controller, enabled: boolean): (boolean, string)
	if enabled and not self._allowed then
		self._enabled = false
		return false, "Infinite Jump requires explicit game-owner opt-in in Config.lua"
	end
	self._enabled = enabled
	return true, if enabled then "Infinite Jump enabled" else "Infinite Jump disabled"
end

function InfiniteJumpController.isEnabled(self: Controller): boolean
	return self._enabled
end

function InfiniteJumpController.destroy(self: Controller)
	self._enabled = false
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

return InfiniteJumpController
