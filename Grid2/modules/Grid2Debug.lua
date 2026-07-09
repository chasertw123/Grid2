-- Temporary debug capture. `/g2debug` toggles on/off, `/g2debug clear` empties it. Rows accumulate in the
-- Grid2CastDebug SavedVariable (flushed to WTF\...\SavedVariables\Grid2.lua on /reload) for offline reading.
-- Current purpose: capture the full life-cycle of a summoned GUARDIAN (Tinker drop) from the combat log --
-- the summon itself, the player's deploy cast, anything the guardian does, and anything done to it -- so the
-- exact events / spellIDs / object flags can be inspected. Diagnostic aid, not a shipping feature.
local Grid2 = Grid2
local bit_band = bit.band
local UnitGUID, GetTime = UnitGUID, GetTime
local MINE, GUARDIAN, PET = 0x1, 0x2000, 0x1000   -- COMBATLOG_OBJECT_AFFILIATION_MINE / TYPE_GUARDIAN / TYPE_PET
local CAP = 400

Grid2CastDebug = Grid2CastDebug or {}

local frame, playerGUID

local function log(t)
	local n = #Grid2CastDebug
	if n < CAP then t.t = GetTime() Grid2CastDebug[n + 1] = t end
end

-- decode the affiliation/type bits we care about into a readable string
local function flagStr(flags)
	flags = flags or 0
	local s = ""
	if bit_band(flags, MINE) ~= 0 then s = s .. "MINE " end
	if bit_band(flags, GUARDIAN) ~= 0 then s = s .. "GUARDIAN " end
	if bit_band(flags, PET) ~= 0 then s = s .. "PET " end
	return s ~= "" and s or "-"
end

-- COMBAT_LOG args (after self,event): timestamp, subevent, srcGUID, srcName, srcFlags, dstGUID, dstName,
-- dstFlags, spellId, spellName, ...
local function OnEvent(_, _, _, subevent, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName)
	playerGUID = playerGUID or UnitGUID("player")
	local srcMineGuard = bit_band(srcFlags or 0, MINE) ~= 0 and bit_band(srcFlags or 0, GUARDIAN + PET) ~= 0
	local dstMineGuard = bit_band(dstFlags or 0, MINE) ~= 0 and bit_band(dstFlags or 0, GUARDIAN + PET) ~= 0
	if subevent == "SPELL_SUMMON"       -- the canonical summon event
		or srcGUID == playerGUID          -- the player's own actions (finds the deploy ability)
		or srcMineGuard                   -- anything my guardian/pet does
		or dstMineGuard then              -- anything done to my guardian (incl. UNIT_DIED)
		log({
			ev = subevent,
			src = srcName or "?", srcGUID = srcGUID, srcFlags = flagStr(srcFlags),
			dst = dstName or "-", dstGUID = dstGUID, dstFlags = flagStr(dstFlags),
			spell = spellName or "?", spellId = spellId,
		})
	end
end

SLASH_G2DEBUG1 = "/g2debug"
SlashCmdList["G2DEBUG"] = function(msg)
	msg = (msg or ""):gsub("%s", ""):lower()
	if not frame then
		frame = CreateFrame("Frame")
		frame:SetScript("OnEvent", OnEvent)
	end
	if msg == "clear" then
		wipe(Grid2CastDebug)
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Grid2 debug:|r cleared")
	elseif frame.on then
		frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		frame.on = nil
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Grid2 debug:|r OFF -- " .. #Grid2CastDebug .. " rows. Type /reload to save.")
	else
		wipe(Grid2CastDebug)
		frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		frame.on = true
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Grid2 debug:|r ON. Drop a guardian and let it act, then /g2debug to stop and /reload to save.")
	end
end
