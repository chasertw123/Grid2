-- "targeted-count" status: how many ENEMIES are currently targeting each unit (an aggro / "who has threat"
-- count). Enemies are enumerated from the visible NAMEPLATES (nameplate1..40 -- Ascension backports nameplate
-- units, the same ones ElvUI's nameplate module and the reference WeakAura use), plus boss1..5 and your
-- target/focus for enemies that may lack a nameplate. Each enemy is counted once (de-duped by GUID) against
-- the group member it is targeting, and only if it is hostile to that target.
-- NOTE: this depends on enemy NAMEPLATES being shown -- an enemy with no nameplate (nameplates off, out of
-- range, and not a boss/your target/your focus) cannot be seen and is not counted.
-- Polled on a short repeating timer and DIFFED so only units whose count changed are refreshed; the status is
-- opt-in, so the poll runs only while it is mapped to an indicator.
local Grid2 = Grid2

local UnitGUID, UnitExists = UnitGUID, UnitExists
local UnitIsDead, UnitIsFriend = UnitIsDead, UnitIsFriend
local wipe, tostring = wipe, tostring

local TargetedCount = Grid2.statusPrototype:new("targeted-count")
TargetedCount.GetColor = Grid2.statusLibrary.GetColor

local counts, prev, seen = {}, {}, {}

-- Count enemy `eunit` against the group member it is targeting, if any. De-duped by GUID so an enemy reached
-- through several tokens (its nameplate plus your target/focus) is only counted once.
local function AddEnemy(eunit)
	local eguid = UnitGUID(eunit)
	if not eguid or seen[eguid] then return end
	seen[eguid] = true
	if UnitIsDead(eunit) then return end
	local tar = eunit .. "target"
	local tguid = UnitGUID(tar)
	if not tguid or UnitIsFriend(eunit, tar) then return end   -- must be hostile to whatever it is targeting
	if Grid2:GetUnitidByGUID(tguid) then                       -- ...and that target is a unit Grid shows
		counts[tguid] = (counts[tguid] or 0) + 1
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
