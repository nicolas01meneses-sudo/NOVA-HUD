--!strict

local function frozenUpgrade(id: string, name: string, price: number)
	return table.freeze({
		id = id,
		name = name,
		price = price,
	})
end

return table.freeze({
	Version = "1.0.0",
	ControlId = "nova-demo-remote-buy",
	Currency = "$",
	InitialWallet = 15000,
	MinimumServerIntervalSeconds = 0.2,
	MaximumReceiptHistory = 64,
	RunAutomatedStudioFlow = false,
	Upgrades = table.freeze({
		frozenUpgrade("foundation", "Foundation", 250),
		frozenUpgrade("railings", "Railings", 450),
		frozenUpgrade("garage-door", "Garage Door", 800),
		frozenUpgrade("windows", "Windows", 1200),
		frozenUpgrade("balcony", "Balcony", 1800),
		frozenUpgrade("plants", "Plants", 2500),
		frozenUpgrade("upper-walls", "Upper Walls", 3500),
	}),
})
