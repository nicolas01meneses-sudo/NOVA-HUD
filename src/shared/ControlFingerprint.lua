--!strict

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
	instance: any?,
}

export type Fingerprint = {
	controlId: string?,
	source: string,
	screenGui: string,
	path: string,
	className: string,
	name: string,
	role: string,
	textSignature: string,
	centerX: number,
	centerY: number,
	width: number,
	height: number,
}

export type ResolveResult = {
	descriptor: Descriptor?,
	score: number,
	runnerUpScore: number,
	reason: string,
}

local ControlFingerprint = {}

local function normalizeText(text: string): string
	local value = text:lower()
	value = value:gsub("[%c%p]", " ")
	value = value:gsub("%s+", " ")
	value = value:gsub("^%s+", ""):gsub("%s+$", "")
	return value:sub(1, 120)
end

local function closeness(left: number, right: number, tolerance: number): number
	local difference = math.abs(left - right)
	if difference >= tolerance then
		return 0
	end
	return 1 - difference / tolerance
end

function ControlFingerprint.capture(descriptor: Descriptor): Fingerprint
	return {
		controlId = descriptor.controlId,
		source = descriptor.source,
		screenGui = descriptor.screenGui,
		path = descriptor.path,
		className = descriptor.className,
		name = descriptor.name,
		role = descriptor.role,
		textSignature = normalizeText(descriptor.text),
		centerX = descriptor.centerX,
		centerY = descriptor.centerY,
		width = descriptor.width,
		height = descriptor.height,
	}
end

function ControlFingerprint.score(fingerprint: Fingerprint, candidate: Descriptor): number
	if fingerprint.controlId then
		if candidate.controlId ~= fingerprint.controlId then
			return -math.huge
		end
	end

	local score = 0
	if fingerprint.controlId and fingerprint.controlId == candidate.controlId then
		score += 120
	end
	if fingerprint.role == candidate.role then
		score += 22
	end
	if fingerprint.screenGui == candidate.screenGui then
		score += 18
	end
	if fingerprint.path == candidate.path then
		score += 34
	end
	if fingerprint.className == candidate.className then
		score += 10
	end
	if fingerprint.name == candidate.name then
		score += 12
	end
	if fingerprint.source == candidate.source then
		score += 5
	end

	local text = normalizeText(candidate.text)
	if fingerprint.textSignature ~= "" and fingerprint.textSignature == text then
		score += 24
	elseif fingerprint.textSignature ~= "" and text ~= ""
		and (fingerprint.textSignature:find(text, 1, true)
			or text:find(fingerprint.textSignature, 1, true)) then
		score += 11
	end

	score += 10 * closeness(fingerprint.centerX, candidate.centerX, 0.18)
	score += 10 * closeness(fingerprint.centerY, candidate.centerY, 0.18)
	score += 5 * closeness(fingerprint.width, candidate.width, 0.16)
	score += 5 * closeness(fingerprint.height, candidate.height, 0.16)
	return score
end

function ControlFingerprint.resolve(
	fingerprint: Fingerprint,
	candidates: { Descriptor },
	minimumScore: number?,
	minimumGap: number?
): ResolveResult
	local best: Descriptor? = nil
	local bestScore = -math.huge
	local runnerUpScore = -math.huge
	for _, candidate in ipairs(candidates) do
		local score = ControlFingerprint.score(fingerprint, candidate)
		if score > bestScore then
			runnerUpScore = bestScore
			bestScore = score
			best = candidate
		elseif score > runnerUpScore then
			runnerUpScore = score
		end
	end

	local threshold = minimumScore or 48
	local gap = minimumGap or 8
	if not best or bestScore < threshold then
		return {
			descriptor = nil,
			score = bestScore,
			runnerUpScore = runnerUpScore,
			reason = "no candidate reached the minimum score",
		}
	end
	if runnerUpScore > -math.huge and bestScore - runnerUpScore < gap then
		return {
			descriptor = nil,
			score = bestScore,
			runnerUpScore = runnerUpScore,
			reason = "binding is ambiguous",
		}
	end
	return {
		descriptor = best,
		score = bestScore,
		runnerUpScore = runnerUpScore,
		reason = "resolved",
	}
end

return table.freeze(ControlFingerprint)
