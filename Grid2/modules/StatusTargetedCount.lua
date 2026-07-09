-- "targeted-count" status: how many ENEMIES are currently targeting each unit (an aggro / "who has threat"
-- count). This client won't let an addon read an enemy's target directly (the "<enemy>target" unit token
-- returns nil here), so instead we use the THREAT table: for a mob in combat, exactly one unit has aggro on it
-- (is "tanking" it) -- that is the unit the mob is targeting. UnitDetailedThreatSituation(member, mob) reports
-- that, so for every enemy we can find (visible nameplates, plus boss1..5 and your target/focus) we scan the
-- roster and credit the member the mob is fixated on.
-- Because it reads the threat table, this only sees mobs that are IN COMBAT (idle mobs have no threat and are
-- not counted), which is exactly what "enemies targeting a player" means in practice.
-- Polled on a short repeating timer and DIFFED so only units whose count changed are refreshed; opt-in.
local Grid2 = Grid2

local UnitExists, UnitGUID, UnitIsDead = UnitExists, UnitGUID, UnitIsDead
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local wipe, tostring = wipe, tostring

local TargetedCount = Grid2.statusPrototype:new("targeted-count")
TargetedCount.GetColor = Grid2.statusLibrary.GetColor

local counts, prev, seen = {}, {}, {}

-- For enemy `mob`, credit the one roster member that currently has aggro on it (the member it is targeting).
-- De-duped by GUID so a mob reached through several tokens (its nameplate plus your target/focus) counts once.
local function AddEnemy(mob)
	local mguid = UnitGUID(mob)
	if not mguid or seen[mguid] then return end
	seen[mguid] = true
	if UnitIsDead(mob) then return end
	for guid, unit in Grid2:IterateRoster() do
		if UnitDetailedThreatSituation(unit, mob) then   -- isTanking -> this member is the mob's current target
			counts[guid] = (counts[guid] or 0) + 1
			break
		end
	end
end

-- Enemy pool: every visible nameplate, plus bosses and your target/focus (which may not have a nameplate).
local function ScanEnemies()
	wipe(seen)
	for i = 1, 40 do
		local u = "nameplate" .. i
		if UnitExists(u) then AddEnemy(u) end
	end
	for i = 1, 5 do AddEnemy("boss" .. i) end
	AddEnemy("target")
	AddEnemy("focus")
end

-- Rescan into `counts`, keeping the previous scan in `prev`, and refresh only the units whose count changed.
local function DoScan()
	prev, counts = counts, prev
	wipe(counts)
	ScanEnemies()
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
		self.timer = Grid2:ScheduleRepeatingTimer(DoScan, 0.3)
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
