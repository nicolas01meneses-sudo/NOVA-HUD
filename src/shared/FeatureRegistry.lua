--!strict

-- These are compatibility declarations, not claims of live-game validation.
return table.freeze({
	Scanner = table.freeze({
		mode = "read-only",
		implementation = "migrated",
		validation = "automated-pure-and-static",
	}),
	RemoteBuy = table.freeze({
		mode = "observation-or-authorized-adapter",
		implementation = "migrated-core",
		validation = "automated-core-studio-harness-pending-execution",
	}),
	AuthorizedDemo = table.freeze({
		mode = "game-owner-authorized",
		implementation = "server-client-demo-and-studio-harness",
		validation = "rojo-built-no-studio-runtime-result-yet",
	}),
	AutoBuy = table.freeze({
		mode = "authorized-adapter-required",
		implementation = "legacy-preserved-not-migrated",
		validation = "not-live-validated",
	}),
	AutoStations = table.freeze({
		mode = "authorized-adapter-required",
		implementation = "legacy-preserved-not-migrated",
		validation = "not-live-validated",
	}),
	AutoIce = table.freeze({
		mode = "authorized-adapter-required",
		implementation = "legacy-preserved-not-migrated",
		validation = "not-live-validated",
	}),
	AutoCollectFruit = table.freeze({
		mode = "authorized-interaction-required",
		implementation = "legacy-preserved-not-migrated",
		validation = "not-live-validated",
	}),
	AutoCollectCash = table.freeze({
		mode = "authorized-interaction-required",
		implementation = "legacy-preserved-not-migrated",
		validation = "not-live-validated",
	}),
	IceBatchAndTeleport = table.freeze({
		mode = "authorized-interaction-required",
		implementation = "legacy-preserved-not-migrated",
		validation = "not-live-validated",
	}),
	InfiniteJump = table.freeze({
		mode = "game-owner-opt-in",
		implementation = "migrated",
		validation = "static-only",
	}),
	AutoRebirth = table.freeze({
		mode = "disabled-without-authorized-adapter",
		implementation = "legacy-preserved-not-migrated",
		validation = "not-live-validated",
	}),
	Radar = table.freeze({
		mode = "read-only-visualization",
		implementation = "legacy-preserved-not-migrated",
		validation = "static-only",
	}),
	Diagnostics = table.freeze({
		mode = "read-only",
		implementation = "partially-migrated",
		validation = "automated-core-and-static",
	}),
	UiAppearance = table.freeze({
		mode = "local-ui-only",
		implementation = "legacy-preserved-with-new-minimal-hud",
		validation = "static-only",
	}),
})
