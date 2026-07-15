--[[ Party/raid sorting for the normal layouts ]]--
-- Adds a global "sort by Name (native) or Role (nameList)" on top of whatever layout is active, plus a reverse
-- toggle and a configurable tank/healer/dps order. Two engines behind profile.sortBy:
--   NAME -> native secure-header sortMethod="NAME" + sortDir (per-group A->Z, self-updating, no roster scan).
--   ROLE -> build a role-ordered comma name list and push it as nameList/sortMethod="NAMELIST" per header,
--           since the secure groupBy cannot express tank/healer/dps. Role comes from Grid2.GetUnitRole (LFG
--           role, else class shortcut, else LibGroupTalents talent inspection -> async, trickles in).
--           When the current roster has NO role distinction at all (every unit falls in one bucket -- e.g. nobody
--           assigned/detected as tank or healer), NAMELIST would only reproduce name order while still paying the
--           combat-lock cost, so ROLE quietly drops to native NAME for the numeric headers (self-maintaining, no
--           queued re-push); it flips back to NAMELIST the moment a real tank/healer role appears.
-- Re-applied after every LoadLayout so it survives reloads; secure SetAttribute is combat-protected, so work
-- is queued to PLAYER_REGEN_ENABLED. The drag-ordered "Free Layout" owns its own nameList and is skipped.
-- MUST load AFTER GridFreeLayout.lua so THIS LoadLayout wrapper is the outermost one.
local Grid2, Grid2Layout = Grid2, Grid2Layout
local fmt, tsort, tconcat = string.format, table.sort, table.concat
local wipe, ipairs, tonumber, type = wipe, ipairs, tonumber, type
local InCombatLockdown = InCombatLockdown
local GetNumRaidMembers, GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers
local GetRaidRosterInfo, UnitName = GetRaidRosterInfo, UnitName
local GetUnitRole = Grid2.GetUnitRole
local LGT = LibStub("LibGroupTalents-1.0", true)

local UNIT_TYPES = {"raid", "party"}
local PET_TYPES  = {"raidpet", "partypet"}

local db, activeLayout, sortQueued, rolesDiffer, firstBucket
local roleRank    = {}   -- role token -> rank 1..K (from the configured order)
local sortedNames = {}   -- reused: global role-ordered unit names
local nameKey     = {}   -- reused: name -> "<rank><name>" sort key
local nameGroup   = {}   -- reused: name -> subgroup (for per-group header filtering)
local origFilter  = {}   -- header -> its pristine groupFilter, snapshotted at load (before we clear it)
local origBy      = {}   -- header -> pristine groupBy       (snapshotted with origFilter; for restoring native grouping)
local origOrder   = {}   -- header -> pristine groupingOrder (snapshotted with origFilter; for restoring native grouping)
local lastList    = {}   -- header -> last pushed nameList (dirty-check to skip redundant secure writes)
local scratch     = {}   -- reused: per-header list builder
local groupSet    = {}   -- reused: parsed groupFilter set
local Events = {}

-- Profile-owned role order table, lazily created. Deliberately NOT an AceDB table default: AceDB shares nested
-- table defaults by reference across profiles, so mutating one would corrupt the others.
local function GetRoleOrder()
	local p = Grid2Layout.db.profile
	if type(p.sortRoleOrder) ~= "table" or #p.sortRoleOrder ~= 3 then
		p.sortRoleOrder = {"TANK", "HEALER", "DAMAGER"}
	end
	return p.sortRoleOrder
end

local function LoadConfig()
	db = Grid2Layout.db.profile   -- refresh pointer (changes on profile switch)
	wipe(roleRank)
	for i, role in ipairs(GetRoleOrder()) do roleRank[role] = i end
end

-- Add one unit to the scan, baking role rank + reverse + NONE-last into a sortable key.
local function AddUnit(unit, class, subgroup, reverse, K)
	local name = UnitName(unit)
	if not name or name == "" then return end
	local r = roleRank[GetUnitRole(unit, class)]           -- nil for NONE / unknown / not-yet-inspected
	local keyNum = (not r and K + 1) or (reverse and (K + 1 - r)) or r
	-- Track whether the roster splits into >1 role bucket. If everyone lands in the same bucket (all NONE, or
	-- all the same role), role-sort == name-sort, so we can skip the combat-locked NAMELIST and use native NAME.
	local bucket = r or 0
	if firstBucket == nil then firstBucket = bucket elseif bucket ~= firstBucket then rolesDiffer = true end
	sortedNames[#sortedNames + 1] = name
	nameKey[name]   = fmt("%02d%s", keyNum, name)          -- role rank, then name as a stable tiebreak
	nameGroup[name] = subgroup
end

local function ScanRoster()
	wipe(sortedNames); wipe(nameKey); wipe(nameGroup)
	rolesDiffer, firstBucket = false, nil
	local reverse, K = db.sortReverse, #GetRoleOrder()
	local nRaid = GetNumRaidMembers()
	if nRaid > 0 then
		for i = 1, nRaid do
			local name, _, subgroup, _, _, classToken = GetRaidRosterInfo(i)  -- pos6 = class TOKEN
			if name then AddUnit("raid" .. i, classToken, subgroup or 1, reverse, K) end
		end
	else
		AddUnit("player", nil, 1, reverse, K)
		for i = 1, GetNumPartyMembers() do AddUnit("party" .. i, nil, 1, reverse, K) end
	end
	tsort(sortedNames, function(a, b) return nameKey[a] < nameKey[b] end)
end

local function ParseFilter(gf)   -- "1,3" -> {[1]=true,[3]=true}; nil -> nil (include everyone)
	if not gf then return nil end
	wipe(groupSet)
	for g in tostring(gf):gmatch("%d+") do groupSet[tonumber(g)] = true end
	return groupSet
end

local function BuildHeaderList(h)
	local set = ParseFilter(origFilter[h])
	wipe(scratch)
	for i = 1, #sortedNames do
		local name = sortedNames[i]
		if (not set) or set[nameGroup[name]] then scratch[#scratch + 1] = name end
	end
	return tconcat(scratch, ",")
end

-- Hide -> ClearChildrenPoints -> SetAttribute -> Show so the secure header re-runs its arrange cleanly (same
-- bracket the Free Layout engine uses). `grouping` controls the header's native grouping attributes:
--   "clear"       -> nil out groupFilter/groupBy/groupingOrder so the pushed nameList alone drives membership.
--   "restore"     -> put back the pristine groupFilter+groupBy+groupingOrder (per-group native look, NAME mode).
--   "restoreflat" -> keep the pristine groupFilter (subgroup membership) but drop groupBy/groupingOrder, so a
--                    native NAME sort yields ROLE mode's single flat list instead of re-splitting into groups.
--   nil/false     -> leave grouping as-is (headers that already carry the filter we want, e.g. role-token ones).
local function ApplyToHeader(h, method, dir, list, grouping)
	local vis = h:IsVisible()
	if vis then h:Hide() end
	h:ClearChildrenPoints()
	if grouping == "clear" then
		h:SetAttribute("groupFilter", nil)
		h:SetAttribute("groupBy", nil)
		h:SetAttribute("groupingOrder", nil)
	elseif grouping == "restore" then
		h:SetAttribute("groupFilter", origFilter[h])
		h:SetAttribute("groupBy", origBy[h])
		h:SetAttribute("groupingOrder", origOrder[h])
	elseif grouping == "restoreflat" then
		h:SetAttribute("groupFilter", origFilter[h])
		h:SetAttribute("groupBy", nil)
		h:SetAttribute("groupingOrder", nil)
	end
	h:SetAttribute("sortMethod", method)
	h:SetAttribute("sortDir", dir)
	if method == "NAMELIST" then h:SetAttribute("nameList", list) end
	if vis then h:Show() end
end

local function eachHeader(types, fn)
	for _, t in ipairs(types) do
		local hs, n = Grid2Layout.groups[t], Grid2Layout.indexes[t]
		for i = 1, n do fn(hs[i]) end
	end
end

local function ApplySort(fromReload)
	if not db then return end
	if InCombatLockdown() then sortQueued = true; return end   -- secure SetAttribute is combat-protected
	sortQueued = nil
	local mode = db.sortBy or "NONE"
	if activeLayout == "Free Layout" or mode == "NONE" then return end  -- headers keep their layout defaults

	if mode == "NAME" then
		local dir = db.sortReverse and "DESC" or nil
		eachHeader(UNIT_TYPES, function(h) ApplyToHeader(h, "NAME", dir, nil, "restore") end)  -- per-group native, groupBy intact
		eachHeader(PET_TYPES,  function(h) ApplyToHeader(h, "NAME", dir, nil, nil) end)          -- pet grouping is never cleared
		Grid2Layout:UpdateSize()
	else -- ROLE
		ScanRoster()
		-- If no role actually splits this roster, a NAMELIST would only reproduce name order while still paying
		-- the combat-lock cost (every roster/role change is a blocked SetAttribute, deferred to end of combat).
		-- Drop the numeric headers to native NAME instead: self-maintaining, no queued re-push. Reverse honors
		-- the request to use native NAME DESC. (Membership add/remove is still combat-frozen with either method.)
		local useNative = not rolesDiffer
		local dir = db.sortReverse and "DESC" or nil
		local changed = fromReload
		eachHeader(UNIT_TYPES, function(h)
			local of = origFilter[h]
			local roleTokenFilter = of and of:find("%a")   -- e.g. "MAINTANK,MAINASSIST": a secure filter we keep natively
			if roleTokenFilter or useNative then
				-- Native NAME for this header. Role-token headers keep their own filter untouched; a numeric header
				-- dropping out of NAMELIST must restore its subgroup filter (flattened) or it would show EVERYONE.
				if lastList[h] ~= false then       -- `false` sentinel: native NAME applied (distinct from any list string)
					lastList[h] = false
					local grp; if roleTokenFilter then grp = nil else grp = "restoreflat" end
					ApplyToHeader(h, "NAME", dir, nil, grp)
					changed = true
				end
			else
				local list = BuildHeaderList(h)
				if list ~= lastList[h] then
					lastList[h] = list
					ApplyToHeader(h, "NAMELIST", nil, list, "clear")
					changed = true
				end
			end
		end)
		if fromReload then   -- pets can't be role-sorted; set once per load, still honor reverse via sortDir
			eachHeader(PET_TYPES, function(h) ApplyToHeader(h, "NAME", dir, nil, nil) end)
		end
		if changed then Grid2Layout:UpdateSize() end
	end
end

-- Re-apply after every LoadLayout so the sort survives reloads. prev_LoadLayout rebuilds headers from the
-- layout def (Reset wipes each to sortMethod=NAME / nil groupFilter, then the layout re-adds its attributes);
-- we snapshot that pristine groupFilter, then override with the sort. MUST be the outermost LoadLayout wrapper.
local prev_LoadLayout = Grid2Layout.LoadLayout
function Grid2Layout:LoadLayout(name)
	prev_LoadLayout(self, name)
	activeLayout = name
	LoadConfig()
	if name == "Free Layout" then return end   -- Free Layout owns its own nameList; never clobber it
	wipe(origFilter); wipe(origBy); wipe(origOrder); wipe(lastList)
	for _, t in ipairs(UNIT_TYPES) do
		local hs, n = Grid2Layout.groups[t], Grid2Layout.indexes[t]
		for i = 1, n do
			local h = hs[i]
			origFilter[h] = h:GetAttribute("groupFilter")
			origBy[h]     = h:GetAttribute("groupBy")
			origOrder[h]  = h:GetAttribute("groupingOrder")
		end
	end
	ApplySort(true)
end

-- ROLE mode is membership-gated, so recompute on roster changes and as talent-inspection roles trickle in.
-- NAME mode needs none of this (the native header self-updates).
local function RecomputeRole()
	if db and activeLayout ~= "Free Layout" and (db.sortBy or "NONE") == "ROLE" then ApplySort(false) end
end
Events.RAID_ROSTER_UPDATE    = RecomputeRole
Events.PARTY_MEMBERS_CHANGED = RecomputeRole
Events.PLAYER_ROLES_ASSIGNED = RecomputeRole
Events.InspectReady          = RecomputeRole   -- LibGroupTalents_UpdateComplete
function Events:PLAYER_REGEN_ENABLED() if sortQueued then ApplySort(false) end end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, e, ...) local h = Events[e]; if h then h(Events, ...) end end)
f:RegisterEvent("RAID_ROSTER_UPDATE")
f:RegisterEvent("PARTY_MEMBERS_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(f.RegisterEvent, f, "PLAYER_ROLES_ASSIGNED")   -- guard: not every 3.3.5 client exposes it
if LGT then LGT.RegisterCallback(Events, "LibGroupTalents_UpdateComplete", "InspectReady") end
