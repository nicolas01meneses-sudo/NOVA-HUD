--!strict

-- Safe defaults. A game owner must deliberately enable capabilities in their
-- own experience; NOVA does not infer authorization from the current place.
return table.freeze({
	Version = "6.0.1-demo",
	AllowInfiniteJump = false,
	VerificationDelaySeconds = 2.8,
	MinimumPurchaseIntervalSeconds = 3.5,
	MaximumScannedGuiObjects = 1500,
	BindingMinimumScore = 48,
	BindingMinimumGap = 8,
})
