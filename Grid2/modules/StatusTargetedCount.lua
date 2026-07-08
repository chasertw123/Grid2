-- "targeted-count" status: how many group members are currently targeting each unit.
-- Target changes are not reliably event-driven for every raid member on 3.3.5, so this polls the roster on a
-- short repeating timer and DIFFS the result, refreshing only the units whose count actually changed. The
-- status is opt-in (only enabled when mapped to an indicator), so the poll runs only while it is in use.
local Grid2 = Grid2

local UnitGUID = UnitGUID
local GetNumRaidMembers, GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers
local wipe, tostring = wipe, tostring

local TargetedCount = Grid2.statusPrototype:new("targeted-count")
TargetedCount.GetColor = Grid2.statusLibrary.GetColor

local counts, prev = {}, {}

-- Fill `counts[targetGUID] = number of members targeting that GUID`. In a raid the player is one of raid1..N,
-- so iterating raid1..N covers everyone; otherwise it's the player ("target") plus party1..N.
local function ScanTargets()
	local nRaid = GetNumRaidMembers()
	if nRaid > 0 then
		for i = 1, nRaid do
			local g = UnitGUID("raid" .. i .. "target")
			if g then counts[g] = (counts[g] or 0) + 1 end
		end
	else
		local g = UnitGUID("target")   -- the player's own target
		if g then counts[g] = (counts[g] or 0) + 1 end
		for i = 1, GetNumPartyMembers() do
			g = UnitGUID("party" .. i .. "target")
			if g then counts[g] = (counts[g] or 0) + 1 end
		end
	end
end

-- Rescan into `counts`, keeping the previous scan in `prev`, and refresh only the units whose count changed.
local function DoScan()
	prev, counts = counts, prev
	wipe(counts)
	ScanTargets()
	for guid, n in pairs(counts) do
		if prev[guid] ~= n then
			local u = Grid2:GetUnitidByGUID(guid)
			if u then TargetedCount:UpdateIndicators(u) end
		end
	end
	for guid in pairs(prev) do
		if counts[guid] == nil then   -- count dropped to 0
			local u = Grid2:GetUnitidByGUID(guid)
			if u then TargetedCount:UpdateIndicators(u) end
		end
	end
end

function TargetedCount:OnEnable()
	if not self.timer then
		self.timer = Grid2:ScheduleRepeatingTimer(DoScan, 0.25)
	end
	DoScan()
end

function TargetedCount:OnDisable()
	if self.timer then
		Grid2:CancelTimer(self.timer, true)
		self.timer = nil
	end
	wipe(counts)
	wipe(prev)
end

function TargetedCount:IsActive(unit)
	local g = UnitGUID(unit)
	return g ~= nil and (counts[g] or 0) > 0
end

function TargetedCount:GetCount(unit)
	local g = UnitGUID(unit)
	return (g and counts[g]) or 0
end

function TargetedCount:GetText(unit)
	local g = UnitGUID(unit)
	return tostring((g and counts[g]) or 0)
end

local function Create(baseKey, dbx)
	Grid2:RegisterStatus(TargetedCount, {"color", "text"}, baseKey, dbx)
	return TargetedCount
end

Grid2.setupFunc["targeted-count"] = Create
Grid2:DbSetStatusDefaultValue("targeted-count", {
	type = "targeted-count",
	color1 = {r = 1, g = 0.6, b = 0, a = 1}
})
