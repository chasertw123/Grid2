-- "targeted-count" status: how many ENEMIES are currently targeting each unit (an aggro / "who has threat"
-- count). 3.3.5 has no way to enumerate every enemy, so we scan the enemies reachable via unit tokens --
-- boss1..5 plus whatever each group member (and their pet) is currently targeting -- de-duplicate by GUID, and
-- for each hostile, alive one check whether its target is a unit shown in Grid (a group member). Enemies that
-- nobody in the group is targeting and that are not boss units can't be seen, so they are not counted.
-- Polled on a short repeating timer and DIFFED so only units whose count changed are refreshed; the status is
-- opt-in, so the poll runs only while it is mapped to an indicator.
local Grid2 = Grid2

local UnitGUID = UnitGUID
local UnitCanAttack, UnitIsDeadOrGhost = UnitCanAttack, UnitIsDeadOrGhost
local GetNumRaidMembers, GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers
local wipe, tostring = wipe, tostring

local TargetedCount = Grid2.statusPrototype:new("targeted-count")
TargetedCount.GetColor = Grid2.statusLibrary.GetColor

local counts, prev = {}, {}
local seen = {}   -- enemy GUIDs already counted this scan (de-dup: one enemy can be reached via several tokens)

-- If `eunit` is a hostile, living enemy we haven't counted yet, and it is targeting a unit shown in Grid,
-- increment that unit's count.
local function AddEnemy(eunit)
	local eguid = UnitGUID(eunit)
	if not eguid or seen[eguid] then return end
	if not UnitCanAttack("player", eunit) or UnitIsDeadOrGhost(eunit) then return end
	seen[eguid] = true
	local tguid = UnitGUID(eunit .. "target")   -- who this enemy is targeting
	if tguid and Grid2:GetUnitidByGUID(tguid) then   -- ...and that target is a unit Grid shows (a group member)
		counts[tguid] = (counts[tguid] or 0) + 1
	end
end

-- Build the reachable enemy pool and count how many target each group member.
local function ScanEnemies()
	wipe(seen)
	for i = 1, 5 do AddEnemy("boss" .. i) end
	local nRaid = GetNumRaidMembers()
	if nRaid > 0 then
		for i = 1, nRaid do
			AddEnemy("raid" .. i .. "target")
			AddEnemy("raidpet" .. i .. "target")
		end
	else
		AddEnemy("target")
		AddEnemy("pettarget")
		for i = 1, GetNumPartyMembers() do
			AddEnemy("party" .. i .. "target")
			AddEnemy("partypet" .. i .. "target")
		end
	end
	AddEnemy("focus")
	AddEnemy("mouseover")
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
