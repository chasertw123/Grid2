local Grid2 = Grid2
local Grid2Layout = Grid2:NewModule("Grid2Layout")

local pairs, ipairs, next = pairs, ipairs, next

--{{{ Frame config function for secure headers
local function GridHeader_InitialConfigFunction(self, name)
	-- Stamp pet-ness from the owning header (set in GridLayoutHeaderClass.new) before the frame is
	-- registered, so its initial size and appearance are chosen correctly on first paint. Stable for
	-- the frame's life; it never flips on vehicle swaps, so no unit-refresh hook needs to touch it.
	local header = self:GetParent()
	self.isPet = header and header.isPetHeader or nil
	Grid2Frame:RegisterFrame(self)
	RegisterUnitWatch(self)
	self:SetAttribute("*type1", "target")
	self:SetAttribute("useparent-toggleForVehicle", true)
	self:SetAttribute("useparent-allowVehicleTarget", true)
	self:SetAttribute("useparent-unitsuffix", true)
end
--}}}

--{{{ Class for group headers

local NUM_HEADERS = 0
local SecureHeaderTemplates = {
	party = "SecurePartyHeaderTemplate",
	partypet = "SecurePartyPetHeaderTemplate",
	raid = "SecureRaidGroupHeaderTemplate",
	raidpet = "SecureRaidPetHeaderTemplate"
}

local GridLayoutHeaderClass = {
	prototype = {},
	new = function(self, type)
		NUM_HEADERS = NUM_HEADERS + 1
		local frame
		if (type == "spacer") then
			frame = CreateFrame("Frame", "Grid2LayoutHeader" .. NUM_HEADERS, Grid2Layout.frame)
		else
			frame = CreateFrame("Frame", "Grid2LayoutHeader" .. NUM_HEADERS, Grid2Layout.frame, assert(SecureHeaderTemplates[type]))
			frame:SetAttribute("template", _G.ClickCastHeader and "ClickCastUnitTemplate,SecureUnitButtonTemplate" or "Grid2SecureUnitButtonTemplate")
			frame.initialConfigFunction = GridHeader_InitialConfigFunction
			frame.isPetHeader = (type == "raidpet" or type == "partypet") or nil
		end
		for name, func in pairs(self.prototype) do
			frame[name] = func
		end
		frame:Reset()
		frame:SetOrientation()
		return frame
	end
}

local HeaderAttributes = {
	"showPlayer",
	"showSolo",
	"nameList",
	"groupFilter",
	"strictFiltering",
	"sortDir",
	"groupBy",
	"groupingOrder",
	"maxColumns",
	"unitsPerColumn",
	"startingIndex",
	"columnSpacing",
	"columnAnchorPoint",
	"useOwnerUnit",
	"filterOnPet",
	"unitsuffix",
	"allowVehicleTarget",
	"toggleForVehicle"
}
function GridLayoutHeaderClass.prototype:Reset()
	if self.initialConfigFunction then
		self:SetLayoutAttribute("sortMethod", "NAME")
		for _, attr in ipairs(HeaderAttributes) do
			self:SetLayoutAttribute(attr, nil)
		end
	end
	self:Hide()
end

local anchorPoints = {
	[false] = {TOPLEFT = "TOP", TOPRIGHT = "TOP", BOTTOMLEFT = "BOTTOM", BOTTOMRIGHT = "BOTTOM"},
	[true] = {TOPLEFT = "LEFT", TOPRIGHT = "RIGHT", BOTTOMLEFT = "LEFT", BOTTOMRIGHT = "RIGHT"},
	TOP = -1,
	BOTTOM = 1,
	LEFT = 1,
	RIGHT = -1
}

-- ============================ Per-layout setting overrides ============================
-- Each layout (by name) may optionally override a small set of layout-level settings. LayoutValue/SetLayoutValue
-- resolve a key against the named layout's override -- only when that override is enabled AND actually holds the
-- key -- else the global profile. LGet/LSet are the active-layout shortcuts the engine's own read/write sites
-- use. With no overrides everything falls through to the global key byte-for-byte. Overridable = the position,
-- scale and geometry VALUES (main + pet). The pet MODE toggles (petEnabled/petOwnScale/petOwnGrowth) are resolved
-- per-layout by PetMode below: a layout's ov.petOverride turns them on for that layout without the global flag.
local OVERRIDABLE = {
	PosX = true, PosY = true, anchor = true, ScaleSize = true, Padding = true, Spacing = true, horizontal = true, groupAnchor = true,
	PetPosX = true, PetPosY = true, petAnchor = true, PetScaleSize = true, petPadding = true, petSpacing = true, petHorizontal = true, petGroupAnchor = true,
}
-- Pet override keys are governed by a SEPARATE per-layout enable (ov.petOverride) so the main-grid and pet
-- overrides toggle independently; every other key is governed by the main ov.enabled.
local PET_OV_KEY = {
	PetPosX = true, PetPosY = true, petAnchor = true, PetScaleSize = true, petPadding = true, petSpacing = true, petHorizontal = true, petGroupAnchor = true,
}
local function OverrideOn(ov, key)
	if not ov then return false end
	if PET_OV_KEY[key] then return ov.petOverride end
	return ov.enabled
end
function Grid2Layout:LayoutValue(name, key)
	local p = self.db.profile
	local ov = p.layoutOverrides and p.layoutOverrides[name or "solo"]
	if OverrideOn(ov, key) and ov[key] ~= nil then return ov[key] end   -- presence test: untouched keys use the global
	return p[key]
end
function Grid2Layout:SetLayoutValue(name, key, value)
	local p = self.db.profile
	local ov = p.layoutOverrides and p.layoutOverrides[name or "solo"]
	if OverrideOn(ov, key) and OVERRIDABLE[key] then
		ov[key] = value
		-- Pin the anchor on the first coordinate write so a later change to the GLOBAL anchor can't reinterpret
		-- this layout's saved offset.
		if (key == "PosX" or key == "PosY") and ov.anchor == nil then
			ov.anchor = p.anchor
		elseif (key == "PetPosX" or key == "PetPosY") and ov.petAnchor == nil then
			ov.petAnchor = p.petAnchor
		end
	else
		p[key] = value
	end
end
local function LGet(key) return Grid2Layout:LayoutValue(Grid2Layout.layoutName, key) end
local function LSet(key, v) Grid2Layout:SetLayoutValue(Grid2Layout.layoutName, key, v) end

-- A pet MODE is active for the ACTIVE layout when its GLOBAL toggle is on OR that layout's own pet override is
-- enabled -- making a per-layout pet override fully self-contained (pets go to their own container, at their own
-- scale/growth, for just that layout, without needing the global "Position pet frames separately"). With no
-- overrides these all reduce to the plain global toggle, so default behavior is byte-for-byte unchanged.
local function PetMode(p, globalKey)
	if p[globalKey] then return true end
	local ov = p.layoutOverrides and p.layoutOverrides[Grid2Layout.layoutName or "solo"]
	return (ov and ov.petOverride) or false
end
local function PetSeparate(p) return PetMode(p, "petEnabled") end
local function PetOwnScale(p) return PetMode(p, "petOwnScale") end
local function PetOwnGrowth(p) return PetMode(p, "petOwnGrowth") end

-- Resolve growth (horizontal, groupAnchor, Padding, Spacing) for a header. Pet headers use their own
-- values only when pets are separate + own-growth (each inheriting the main value when unset); everything else
-- returns the main values, so with the feature off this is byte-for-byte the old behavior. Declared BEFORE
-- SetOrientation on purpose: it is a file-local upvalue bound at function-definition time.
local function GetGrowth(p, isPet)
	if isPet and PetSeparate(p) and PetOwnGrowth(p) then
		local h = LGet("petHorizontal")
		if h == nil then h = LGet("horizontal") end
		return h, LGet("petGroupAnchor") or LGet("groupAnchor"), LGet("petPadding") or LGet("Padding"), LGet("petSpacing") or LGet("Spacing")
	end
	return LGet("horizontal"), LGet("groupAnchor"), LGet("Padding"), LGet("Spacing")
end

-- Growth resolved per-header from self.isPetHeader (stamped at creation); no parameter (callers pass none).
function GridLayoutHeaderClass.prototype:SetOrientation()
	if not self.initialConfigFunction then return end
	local p = Grid2Layout.db.profile
	local horizontal, groupAnchor, padding = GetGrowth(p, self.isPetHeader)
	local vertical = not horizontal
	local point = anchorPoints[not vertical][groupAnchor]
	local direction = anchorPoints[point]
	local xOffset = horizontal and padding * direction or 0
	local yOffset = vertical and padding * direction or 0
	self:SetLayoutAttribute("xOffset", xOffset)
	self:SetLayoutAttribute("yOffset", yOffset)
	self:SetLayoutAttribute("point", point)
end

-- MSaint fix see: http://forums.wowace.com/showpost.php?p=315982&postcount=215
-- To maintain the code consistent all calls to SetAttribute were replaced with SetLayoutAttribute
-- including those which not affect anchors, the only exception: calls from GridLayoutHeaderClass.new)
function GridLayoutHeaderClass.prototype:SetLayoutAttribute(name, value)
	if name == "point" or name == "columnAnchorPoint" or name == "unitsPerColumn" then
		self:ClearChildrenPoints()
	end
	self:SetAttribute(name, value)
end

function GridLayoutHeaderClass.prototype:ClearChildrenPoints()
	local count = 1
	local uframe = self:GetAttribute("child1")
	while uframe do
		uframe:ClearAllPoints()
		count = count + 1
		uframe = self:GetAttribute("child" .. count)
	end
end

--{{{ Grid2Layout

-- AceDB defaults
Grid2Layout.defaultDB = {
	profile = {
		debug = false,
		FrameDisplay = "Always",
		layouts = {
			solo = "Solo w/Pet",
			party = "By Group 5 w/Pets",
			raid10 = "By Group 10 w/Pets",
			raid15 = "By Group 15 w/Pets",
			raid25 = "By Group 25 w/Pets",
			raid40 = "By Group 40",
			arena = "By Group 5 w/Pets"
		},
		layoutScales = {},
		layoutOverrides = {},   -- [layoutName] = { enabled=bool, PosX=, PosY=, anchor=, ScaleSize=, ... } per-layout overrides
		horizontal = true,
		-- Party/raid sorting (GridPartySort.lua). sortRoleOrder is created lazily (not here) to avoid AceDB
		-- sharing a nested-table default by reference across profiles.
		sortBy = "NONE",       -- "NONE" | "NAME" | "ROLE"
		sortReverse = false,
		clamp = true,
		FrameLock = false,
		ClickThrough = false,
		Padding = 0,
		Spacing = 10,
		ScaleSize = 1,
		BorderTexture = "Blizzard Tooltip",
		BorderR = .5,
		BorderG = .5,
		BorderB = .5,
		BorderA = 1,
		BackgroundR = .1,
		BackgroundG = .1,
		BackgroundB = .1,
		BackgroundA = .65,
		anchor = "TOPLEFT",
		groupAnchor = "TOPLEFT",
		PosX = 500,
		PosY = -200,
		-- Separate pet container. petEnabled=false => pet frames flow inside the main grid exactly as before.
		petEnabled = false,
		petAnchor = "TOPLEFT",
		PetPosX = 500,
		PetPosY = -400,
		petClamp = true,
		petOwnScale = false,
		PetScaleSize = 1,
		-- (deferred feature) independent pet frame-lock; false => pet follows the shared FrameLock/ClickThrough.
		-- PetFrameLock / PetClickThrough are intentionally absent => inherit the main values until overridden.
		petOwnLock = false,
		-- (deferred feature) independent pet backdrop/border styling; false => pet uses the shared main style.
		-- Pet* style keys are intentionally absent => inherit the main values until overridden.
		petOwnStyle = false,
		-- (deferred feature) independent pet growth direction; false => pet uses main horizontal/groupAnchor.
		-- petHorizontal / petGroupAnchor / petPadding / petSpacing are intentionally absent => inherit main.
		petOwnGrowth = false
	}
}

Grid2Layout.frameBackdrop = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	tile = true,
	tileSize = 16,
	edgeSize = 16,
	insets = {left = 4, right = 4, top = 4, bottom = 4}
}

-- Separate scratch backdrop for the pet container so its own textures are never written into the shared
-- frameBackdrop (which would otherwise leak onto the main frame on its next SetBackdrop).
Grid2Layout.petFrameBackdrop = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	tile = true,
	tileSize = 16,
	edgeSize = 16,
	insets = {left = 4, right = 4, top = 4, bottom = 4}
}

Grid2Layout.layoutSettings = {}

Grid2Layout.layoutHeaderClass = GridLayoutHeaderClass

function Grid2Layout:OnModuleInitialize()
	self.groups = {
		raid = {},
		raidpet = {},
		party = {},
		partypet = {},
		spacer = {}
	}
	self.indexes = {
		raid = 0,
		raidpet = 0,
		party = 0,
		partypet = 0,
		spacer = 0
	}
	self:AddCustomLayouts()
end

function Grid2Layout:OnModuleEnable()
	if not self.frame then
		self:CreateFrame()
	end
	self:RestorePosition()
	if self.layoutName then
		self:ReloadLayout()
	end
	self:RegisterMessage("Grid_GroupTypeChanged")
	self:RegisterMessage("Grid_UpdateLayoutSize", "UpdateSizeSoon")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function Grid2Layout:OnModuleDisable()
	self:UnregisterMessage("Grid_GroupTypeChanged")
	self:UnregisterMessage("Grid_UpdateLayoutSize", "UpdateSize")
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	self.frame:Hide()
	if self.petFrame then self.petFrame:Hide() end
end

--{{{ Event handlers
function Grid2Layout:PLAYER_REGEN_ENABLED()
	if self.reloadLayoutQueued then
		return self:ReloadLayout()
	end
	if self.updateSizeQueued then
		return self:UpdateSize()
	end
	if self.restorePositionQueued then
		return self:RestorePosition()
	end
end

function Grid2Layout:Grid_GroupTypeChanged(_, type)
	Grid2Layout:Debug("GroupTypeChanged", type)
	self.partyType = type
	self:ReloadLayout()
end

--}}}

function Grid2Layout:StartMoveFrame(button, frame)
	frame = frame or self.frame
	if not self:GetFrameLockState(frame) and button == "LeftButton" then
		frame:StartMoving()
		frame.isMoving = true
	end
end

function Grid2Layout:StopMoveFrame(frame)
	frame = frame or self.frame
	if frame.isMoving then
		frame:StopMovingOrSizing()
		self:SavePosition(frame)
		frame.isMoving = false
		self:RestorePosition()
	end
end

-- Resolve the effective lock + click-through for a frame. The pet frame uses its own values only when
-- petOwnLock is on (each falling back to the main value when unset); every other case uses the shared
-- FrameLock/ClickThrough, so with the feature off this returns exactly the old values.
function Grid2Layout:GetFrameLockState(frame)
	local p = self.db.profile
	local fl, ct
	if frame == self.petFrame and p.petOwnLock then
		fl = p.PetFrameLock
		if fl == nil then fl = p.FrameLock end
		ct = p.PetClickThrough
		if ct == nil then ct = p.ClickThrough end
	else
		fl, ct = p.FrameLock, p.ClickThrough
	end
	if not fl then ct = false end -- click-through only applies while locked, so an unlocked frame stays draggable
	return fl, ct
end

-- Apply each frame's resolved click-through to its mouse-enabled state.
function Grid2Layout:ApplyClickThrough()
	local _, ct = self:GetFrameLockState(self.frame)
	self.frame:EnableMouse(not ct)
	if self.petFrame then
		local _, pct = self:GetFrameLockState(self.petFrame)
		self.petFrame:EnableMouse(not pct)
	end
end

-- nil:toggle, false:disable movement, true:enable movement
function Grid2Layout:FrameLock(locked)
	local p = self.db.profile
	if (locked == nil) then
		p.FrameLock = not p.FrameLock
	else
		p.FrameLock = locked
	end
	if not p.FrameLock and p.ClickThrough then
		p.ClickThrough = false
	end
	self:ApplyClickThrough()
end

-- Independent pet lock toggle (mirrors FrameLock for the pet frame; PetFrameLock inherits FrameLock when unset).
function Grid2Layout:PetFrameLock(locked)
	local p = self.db.profile
	if locked == nil then
		local cur = p.PetFrameLock
		if cur == nil then cur = p.FrameLock end
		p.PetFrameLock = not cur
	else
		p.PetFrameLock = locked
	end
	if not p.PetFrameLock and p.PetClickThrough then
		p.PetClickThrough = false
	end
	self:ApplyClickThrough()
end

--{{{ ConfigMode support
CONFIGMODE_CALLBACKS = CONFIGMODE_CALLBACKS or {}
CONFIGMODE_CALLBACKS["Grid2"] = function(action)
	if (action == "ON") then
		Grid2Layout:FrameLock(false)
		if Grid2Layout.db.profile.petOwnLock then Grid2Layout:PetFrameLock(false) end
	elseif (action == "OFF") then
		Grid2Layout:FrameLock(true)
		if Grid2Layout.db.profile.petOwnLock then Grid2Layout:PetFrameLock(true) end
	end
end
--}}}

function Grid2Layout:CreateFrame()
	local p = self.db.profile
	-- create main frame to hold all our gui elements
	local f = CreateFrame("Frame", "Grid2LayoutFrame", UIParent)
	self.frame = f
	-- Key names let the shared Save/Restore/Scale machinery service either frame; the main frame uses the
	-- original literals so the no-arg calls are byte-for-byte identical to before.
	f.posXKey, f.posYKey, f.anchorKey = "PosX", "PosY", "anchor"
	f:SetMovable(true)
	f:SetClampedToScreen(p.clamp)
	f:SetPoint("CENTER", UIParent, "CENTER")
	f:SetScript("OnMouseUp", function() self:StopMoveFrame() end)
	f:SetScript("OnHide", function() self:StopMoveFrame() end)
	f:SetScript("OnMouseDown", function(_, button) self:StartMoveFrame(button) end)
	f:SetFrameStrata(p.FrameStrata or "MEDIUM")
	f:SetFrameLevel(0)
	self:UpdateTextures()
	self:SetFrameLock(p.FrameLock, p.ClickThrough)
	self.CreateFrame = nil
end

-- Separate, non-secure container for pet frames, created lazily only when the feature is enabled.
-- It carries its own DB key names so the shared positioning code reads/writes the Pet* profile keys.
function Grid2Layout:CreatePetFrame()
	if self.petFrame then return end
	local p = self.db.profile
	local f = CreateFrame("Frame", "Grid2LayoutPetFrame", UIParent)
	self.petFrame = f
	f.posXKey, f.posYKey, f.anchorKey = "PetPosX", "PetPosY", "petAnchor"
	f:SetMovable(true)
	f:SetClampedToScreen(p.petClamp)
	f:SetPoint("CENTER", UIParent, "CENTER")
	f:SetScript("OnMouseUp", function() self:StopMoveFrame(f) end)
	f:SetScript("OnHide", function() self:StopMoveFrame(f) end)
	f:SetScript("OnMouseDown", function(_, button) self:StartMoveFrame(button, f) end)
	f:SetFrameStrata(p.FrameStrata or "MEDIUM")
	f:SetFrameLevel(0)
	local _, petCt = self:GetFrameLockState(f)
	f:EnableMouse(not petCt)
	self:UpdateTextures(f)
	self:UpdateColor(f)
	-- Position from the saved DB coords now, mirroring how OnModuleEnable positions the main frame before
	-- its first Scale/SavePosition. Without this, the first SavePosition(petFrame) inside Scale would read
	-- the CENTER/zero-size creation anchor and overwrite PetPosX/PetPosY with screen-center coordinates.
	self:RestoreFramePosition(f)
end

-- Show/hide feedback for the options master toggle (real creation is guaranteed by LoadLayout, out of combat).
function Grid2Layout:SetupPetFrame()
	if PetSeparate(self.db.profile) then
		if not self.petFrame and not InCombatLockdown() then
			self:CreatePetFrame()
		end
		if self.petFrame then self.petFrame:Show() end
	elseif self.petFrame then
		self.petFrame:Hide()
	end
end

local relativePoints = {
	[false] = {TOPLEFT = "BOTTOMLEFT", TOPRIGHT = "BOTTOMRIGHT", BOTTOMLEFT = "TOPLEFT", BOTTOMRIGHT = "TOPRIGHT"},
	[true] = {TOPLEFT = "TOPRIGHT", TOPRIGHT = "TOPLEFT", BOTTOMLEFT = "BOTTOMRIGHT", BOTTOMRIGHT = "BOTTOMLEFT"},
	xMult = {TOPLEFT = 1, TOPRIGHT = -1, BOTTOMLEFT = 1, BOTTOMRIGHT = -1},
	yMult = {TOPLEFT = -1, TOPRIGHT = -1, BOTTOMLEFT = 1, BOTTOMRIGHT = 1}
}
local previousFrame, previousPetFrame
function Grid2Layout:PlaceGroup(frame, groupNumber)
	local settings = self.db.profile
	-- Route pet headers (already stamped isPetHeader at creation) to the pet container when enabled;
	-- everything else stays on the main frame. Each container keeps its own placement chain so the first
	-- group of each is corner-anchored and the rest chain off the previous one. prev==nil detects "first".
	local usePet = PetSeparate(settings) and self.petFrame and frame.isPetHeader
	-- Explicit if/else, NOT `usePet and X or Y`: for the first pet header previousPetFrame is nil, and
	-- `(usePet and nil) or previousFrame` would wrongly fall through to the main grid's last header,
	-- anchoring the pet group to the main grid instead of the pet container.
	local container, prev
	if usePet then
		container, prev = self.petFrame, previousPetFrame
	else
		container, prev = self.frame, previousFrame
	end
	local horizontal, anchor, padding, spacing = GetGrowth(settings, frame.isPetHeader)
	local vertical = not horizontal
	local relPoint = relativePoints[vertical][anchor]
	local xMult = relativePoints.xMult[anchor]
	local yMult = relativePoints.yMult[anchor]
	frame:ClearAllPoints()
	frame:SetParent(container)
	if prev == nil then
		frame:SetPoint(anchor, container, anchor, spacing * xMult, spacing * yMult)
	else
		xMult = vertical and xMult * padding or 0
		yMult = horizontal and yMult * padding or 0
		frame:SetPoint(anchor, prev, relPoint, xMult, yMult)
	end
	self:Debug("Placing group", groupNumber, frame:GetName(), anchor, prev and prev:GetName(), relPoint)
	if usePet then
		previousPetFrame = frame
	else
		previousFrame = frame
	end
end

function Grid2Layout:AddLayout(layoutName, layout)
	self.layoutSettings[layoutName] = layout
end

function Grid2Layout:SetClamp()
	self.frame:SetClampedToScreen(self.db.profile.clamp)
end

function Grid2Layout:ReloadLayout(force)
	if InCombatLockdown() and not force then
		self.reloadLayoutQueued = true
		return
	end
	self.reloadLayoutQueued = nil
	self:LoadLayout(self.db.profile.layouts[self.partyType or "solo"])
end

function Grid2Layout:RefreshLayout()
	return self:ReloadLayout(true)
end

local function SetAllAttributes(header, p, list, fix)
	local petgroup = false
	for attr, value in next, list do
		if attr == "unitsPerColumn" then
			-- Resolve per-header so a pet group's column spacing/anchor match its own growth axis.
			local ph, pa, ppad = GetGrowth(p, header.isPetHeader)
			header:SetLayoutAttribute("columnSpacing", ppad)
			header:SetLayoutAttribute("unitsPerColumn", value)
			header:SetLayoutAttribute("columnAnchorPoint", anchorPoints[not ph][pa] or pa)
		elseif attr ~= "type" then
			header:SetLayoutAttribute(attr, value)
		else
			petgroup = (value == "partypet" or value == "raidpet")
		end
	end
	if fix and petgroup then
		-- force these so that the bug in SecureGroupPetHeader_Update doesn't trigger
		header:SetLayoutAttribute("useOwnerUnit", false)
		header:SetLayoutAttribute("unitsuffix", nil)
	end
end

-- Precreate frames to avoid a blizzard bug that prevents initializing unit frames in combat
-- http://forums.wowace.com/showpost.php?p=307503&postcount=3163
local function ForceFramesCreation(header)
	local startingIndex = header:GetAttribute("startingIndex")
	local maxColumns = header:GetAttribute("maxColumns") or 1
	local unitsPerColumn = header:GetAttribute("unitsPerColumn") or 5
	local maxFrames = maxColumns * unitsPerColumn
	local count = header.FrameCount
	if not count or count < maxFrames then
		header:Show()
		header:SetAttribute("startingIndex", 1 - maxFrames)
		header:SetAttribute("startingIndex", startingIndex)
		header.FrameCount = maxFrames
	end
end

function Grid2Layout:LoadLayout(layoutName)
	local layout = self.layoutSettings[layoutName]
	if not layout then return end
	self:Debug("LoadLayout", layoutName)

	self.layoutName = layoutName
	-- LoadLayout only runs out of combat (ReloadLayout is combat-guarded), so lazily creating the pet
	-- container here is safe and guarantees it exists before Scale and before pet headers are parented to it.
	if PetSeparate(self.db.profile) and not self.petFrame then
		self:CreatePetFrame()
	end
	-- Apply THIS layout's stored position BEFORE Scale(): Scale()'s internal SavePosition re-captures the
	-- current on-screen rect, so without this it would write the previous layout's position into this layout's
	-- override. Restoring first makes that internal save idempotent (per-layout position overrides depend on it).
	self:RestorePosition()
	self:Scale()

	local p = self.db.profile

	for type, headers in pairs(self.groups) do
		self.indexes[type] = 0
		for _, g in ipairs(headers) do
			g:Reset()
		end
	end

	local defaults = layout.defaults
	local default_type = defaults and defaults.type or "raid"

	-- Reset both placement chains each load; PlaceGroup detects the first group of each via prev==nil.
	previousFrame, previousPetFrame = nil, nil

	for i, l in ipairs(layout) do
		local type = l.type or default_type
		local headers = assert(self.groups[type], "Bad " .. type)
		local index = self.indexes[type] + 1
		local layoutGroup = headers[index]
		if not layoutGroup then
			layoutGroup = self.layoutHeaderClass:new(type)
			headers[index] = layoutGroup
		end
		self.indexes[type] = index

		if type ~= "spacer" then
			if defaults then
				SetAllAttributes(layoutGroup, p, defaults)
			end
			SetAllAttributes(layoutGroup, p, l, true)
			ForceFramesCreation(layoutGroup)
			layoutGroup:SetOrientation()
		end
		self:PlaceGroup(layoutGroup, i)

		layoutGroup:Show()
	end

	self:UpdateDisplay()

	-- WoW 3.3.5a secure SecureGroupHeaders arrange/size their child buttons on a LATER frame, so right now
	-- g:GetWidth()/g:GetHeight() (read by UpdateSize) are still stale/zero and UIParent's effective scale may not
	-- be final -- so the container size AND the pixel-snapped anchor (RestoreFramePosition divides the stored coord
	-- by the not-yet-final GetEffectiveScale) both come out wrong on a fresh /reload or login. Toggling Test layout
	-- OFF only "fixes" centering because LayoutHide re-runs UpdateSize + RestoreFramePosition AFTER the frames
	-- settle. Mirror that on the load path: once the headers settle, re-run size + position. Use AceTimer (embedded
	-- on the Grid2 core -- C_Timer is NOT part of 3.3.5a, only polyfilled by some other addons, so it can't be
	-- relied on here) for a safe ~0.1s window. Both calls self-guard InCombatLockdown and LoadLayout only runs out
	-- of combat, so this never reconfigures anything in combat; re-running for the current layout is idempotent.
	Grid2:ScheduleTimer(function()
		self:UpdateSize()
		self:RestorePosition()
	end, 0.1)
end

function Grid2Layout:UpdateDisplay()
	self:UpdateTextures()
	self:UpdateColor()
	if self.petFrame then
		self:UpdateTextures(self.petFrame)
		self:UpdateColor(self.petFrame)
	end
	self:CheckVisibility()
	self:UpdateSize()
end

function Grid2Layout:UpdateSize()
	if InCombatLockdown() then
		self.updateSizeQueued = true
		return
	end
	self.updateSizeQueued = nil

	local p = self.db.profile
	local usePet = PetSeparate(p) and self.petFrame
	-- Resolve growth per container so a pet group on its own axis is accumulated and sized correctly.
	-- With petOwnGrowth off these all equal the main values, so the math is byte-for-byte the old behavior.
	local mh, _, mPad, mSpc = GetGrowth(p, false)
	local ph, _, pPad, pSpc = GetGrowth(p, true)
	local mSpc2, pSpc2 = mSpc * 2, pSpc * 2
	local curWidth, curHeight, maxWidth, maxHeight = 0, 0, 0, 0
	local pCurWidth, pCurHeight, pMaxWidth, pMaxHeight = 0, 0, 0, 0

	local frameWidth, frameHeight = Grid2Frame:GetFrameSize()
	for i = 1, self.indexes.spacer do
		self.groups.spacer[i]:SetSize(frameWidth, frameHeight)
	end

	for type, headers in pairs(self.groups) do
		-- When the pet container is active, pet groups size it instead of the main frame; otherwise all
		-- groups fold into the main frame exactly as before.
		local petType = usePet and (type == "raidpet" or type == "partypet")
		for i = 1, self.indexes[type] do
			local g = headers[i]
			local width, height = g:GetWidth(), g:GetHeight()
			if petType then
				pCurWidth = pCurWidth + width + pPad
				pCurHeight = pCurHeight + height + pPad
				if pMaxWidth < width then
					pMaxWidth = width
				end
				if pMaxHeight < height then
					pMaxHeight = height
				end
			else
				curWidth = curWidth + width + mPad
				curHeight = curHeight + height + mPad
				if maxWidth < width then
					maxWidth = width
				end
				if maxHeight < height then
					maxHeight = height
				end
			end
		end
	end

	self.frame:SetWidth(mh and maxWidth + mSpc2 or curWidth + mSpc2 - mPad)
	self.frame:SetHeight(mh and curHeight + mSpc2 - mPad or maxHeight + mSpc2)
	if usePet then
		self.petFrame:SetWidth(ph and pMaxWidth + pSpc2 or pCurWidth + pSpc2 - pPad)
		self.petFrame:SetHeight(ph and pCurHeight + pSpc2 - pPad or pMaxHeight + pSpc2)
	end
end

-- Grid_UpdateLayoutSize is fired by a unit-frame's OnShow/OnHide when the roster changes. On 3.3.5a the secure
-- headers arrange/measure their child buttons on a LATER frame, so a synchronous UpdateSize here reads a STALE
-- (usually too-small) header width. For an open-world party size change (3<->4<->5) partyType stays "party", so
-- LoadLayout -- and its own 0.1s deferred re-measure -- never runs, leaving the container mis-sized: with a
-- TOP/center anchor and left-aligned content a too-small width renders the group off-center with an apparent
-- empty left slot. Do the immediate size as before, then re-measure once the headers settle, mirroring the
-- LoadLayout heal. Trailing-debounced so a burst of OnShow/OnHide coalesces into one settled pass. UpdateSize and
-- RestorePosition both self-guard InCombatLockdown and only touch the non-secure container frames, so this never
-- reconfigures anything secure in combat. AceTimer (Grid2:ScheduleTimer) because C_Timer is not part of 3.3.5a.
function Grid2Layout:UpdateSizeSoon()
	self:UpdateSize()
	if self.updateSizeTimer then Grid2:CancelTimer(self.updateSizeTimer) end
	self.updateSizeTimer = Grid2:ScheduleTimer(function()
		self.updateSizeTimer = nil
		self:UpdateSize()
		self:RestorePosition()
	end, 0.1)
end

function Grid2Layout:UpdateTextures(frame)
	local f = frame or self.frame
	local p = self.db.profile
	-- The pet frame paints from its own petFrameBackdrop with pet textures (each inheriting the main value
	-- when unset) only when petOwnStyle is on; otherwise this is the original main path on frameBackdrop.
	local ownStyle = (f == self.petFrame) and p.petEnabled and p.petOwnStyle
	local backdrop, bgTex, borderTex, tile, tileSize
	if ownStyle then
		backdrop = self.petFrameBackdrop
		bgTex = p.PetBackgroundTexture or p.BackgroundTexture
		borderTex = p.PetBorderTexture or p.BorderTexture
		if p.PetBackgroundTile ~= nil then tile = p.PetBackgroundTile else tile = p.BackgroundTile end
		tileSize = p.PetBackgroundTileSize or p.BackgroundTileSize
	else
		backdrop = self.frameBackdrop
		bgTex, borderTex, tile, tileSize = p.BackgroundTexture, p.BorderTexture, p.BackgroundTile, p.BackgroundTileSize
	end
	backdrop.bgFile = Grid2:MediaFetch("background", bgTex, "Interface\\ChatFrame\\ChatFrameBackground")
	backdrop.edgeFile = Grid2:MediaFetch("border", borderTex)
	backdrop.tile = tile
	backdrop.tileSize = tileSize or 16
	f:SetBackdrop(backdrop)
end

function Grid2Layout:UpdateColor(frame)
	local f = frame or self.frame
	local p = self.db.profile
	if (f == self.petFrame) and p.petEnabled and p.petOwnStyle then
		f:SetBackdropBorderColor(p.PetBorderR or p.BorderR, p.PetBorderG or p.BorderG, p.PetBorderB or p.BorderB, p.PetBorderA or p.BorderA)
		f:SetBackdropColor(p.PetBackgroundR or p.BackgroundR, p.PetBackgroundG or p.BackgroundG, p.PetBackgroundB or p.BackgroundB, p.PetBackgroundA or p.BackgroundA)
	else
		f:SetBackdropBorderColor(p.BorderR, p.BorderG, p.BorderB, p.BorderA)
		f:SetBackdropColor(p.BackgroundR, p.BackgroundG, p.BackgroundB, p.BackgroundA)
	end
end

function Grid2Layout:CheckVisibility()
	local p = self.db.profile
	local frameDisplay = p.FrameDisplay
	local show =
		(frameDisplay == "Always") or (frameDisplay == "Grouped" and self.partyType ~= "solo") or
			(frameDisplay == "Raid" and self.partyType:find("raid"))
	if show then
		self.frame:Show()
	else
		self.frame:Hide()
	end
	if self.petFrame then
		-- hide the pet container when there are no pet groups so an empty box doesn't linger
		local hasPets = (self.indexes.raidpet + self.indexes.partypet) > 0
		if show and PetSeparate(p) and hasPets then
			self.petFrame:Show()
		else
			self.petFrame:Hide()
		end
	end
end

-- Pixel-perfect helpers -------------------------------------------------------
-- WoW's UI root is always 768 units tall, so one physical pixel spans
-- (768 / physicalScreenHeight) root units. Reading the physical height at run
-- time keeps this independent of the monitor/resolution. Returns nil when the
-- height can't be determined so callers can no-op safely (never worse than before).
local function GetPhysicalHeight()
	if GetPhysicalScreenSize then
		local _, h = GetPhysicalScreenSize()
		if h and h > 0 then return h end
	end
	local res = GetCVar and GetCVar("gxResolution")
	local h = res and tonumber(res:match("%d+%s*[xX]%s*(%d+)"))
	if h and h > 0 then return h end
	if GetScreenResolutions and GetCurrentResolution then
		res = ({GetScreenResolutions()})[GetCurrentResolution() or 0]
		h = res and tonumber(res:match("%d+%s*[xX]%s*(%d+)"))
		if h and h > 0 then return h end
	end
end

-- Size, in a frame's own coordinates, of one physical screen pixel.
local function GetFramePixel(frame)
	local physH = GetPhysicalHeight()
	if physH then return (768 / physH) / frame:GetEffectiveScale() end
end

-- Snap a scale so one UI unit maps to a whole number of physical pixels (same basis as RestoreFramePosition).
local function SnapScale(scale)
	if Grid2Layout.db.profile.pixelPerfect ~= false then
		local physH = GetPhysicalHeight()
		if physH then
			local uiScale = UIParent:GetEffectiveScale()
			local pp = 768 / physH
			local k = math.floor(scale * uiScale / pp + 0.5)
			if k >= 1 then scale = k * pp / uiScale end
		end
	end
	return scale
end

-- Reads/writes each frame's own position keys (main frame: PosX/PosY/anchor; pet frame: PetPosX/PetPosY/petAnchor).
function Grid2Layout:SavePosition(frame)
	local f = frame or self.frame
	if f:GetLeft() and f:GetWidth() then
		local a = LGet(f.anchorKey)
		local s = f:GetEffectiveScale()
		local t = UIParent:GetEffectiveScale()
		local x = (a:find("LEFT") and f:GetLeft() * s) or (a:find("RIGHT") and f:GetRight() * s - UIParent:GetWidth() * t) or (f:GetLeft() + f:GetWidth() / 2) * s - UIParent:GetWidth() / 2 * t
		local y = (a:find("BOTTOM") and f:GetBottom() * s) or (a:find("TOP") and f:GetTop() * s - UIParent:GetHeight() * t) or (f:GetTop() - f:GetHeight() / 2) * s - UIParent:GetHeight() / 2 * t
		LSet(f.posXKey, x)
		LSet(f.posYKey, y)
		self:Debug("Saved Position", a, x, y)
	end
end

function Grid2Layout:ResetPosition()
	local s = UIParent:GetEffectiveScale()
	LSet("PosX", UIParent:GetWidth() / 2 * s)
	LSet("PosY", -UIParent:GetHeight() / 2 * s)
	LSet("anchor", "TOPLEFT")
	self:RestorePosition()
	self:SavePosition()
end

function Grid2Layout:ResetPetPosition()
	local s = UIParent:GetEffectiveScale()
	LSet("PetPosX", UIParent:GetWidth() / 2 * s)
	LSet("PetPosY", -UIParent:GetHeight() / 2 * s)
	LSet("petAnchor", "TOPLEFT")
	self:RestorePosition()
	if self.petFrame then
		self:SavePosition(self.petFrame)
	end
end

function Grid2Layout:RestorePosition()
	if InCombatLockdown() then
		self.restorePositionQueued = true
		return
	end
	self.restorePositionQueued = nil
	self:RestoreFramePosition(self.frame)
	if self.petFrame then
		self:RestoreFramePosition(self.petFrame)
	end
end

-- Position one frame from its own DB keys, snapped to the physical pixel grid. Shared by both containers;
-- the main frame's keys are the original literals, so restoring it is byte-for-byte the previous behavior.
function Grid2Layout:RestoreFramePosition(f, layoutOverrideName)
	local p = self.db.profile
	local name = layoutOverrideName or self.layoutName   -- read-only: preview passes the previewed name
	local s = f:GetEffectiveScale()
	local x = self:LayoutValue(name, f.posXKey) / s
	local y = self:LayoutValue(name, f.posYKey) / s
	if p.pixelPerfect ~= false then
		local px = GetFramePixel(f)
		if px then
			x = math.floor(x / px + 0.5) * px
			y = math.floor(y / px + 0.5) * px
		end
	end
	local a = self:LayoutValue(name, f.anchorKey)
	f:ClearAllPoints()
	f:SetPoint(a, x, y)
	self:Debug("Restored Position", a, x, y)
end

function Grid2Layout:Scale()
	local p = self.db.profile
	self:SavePosition()
	if self.petFrame then
		self:SavePosition(self.petFrame)
	end
	-- Snap the grid's effective scale so one UI unit maps to a whole number of physical pixels; frame edges
	-- then land exactly on the pixel grid instead of between pixels (avoids a 1px class-color sliver at
	-- fractional scales). Monitor independent; no-op if the physical height can't be determined.
	local ls = p.layoutScales[self.layoutName or "solo"] or 1   -- per-layout MULTIPLIER; composes with the ScaleSize override
	local base = LGet("ScaleSize") * ls
	self.frame:SetScale(SnapScale(base))
	if self.petFrame then
		-- pet container follows the main scale unless given its own; snapped the same way
		local pbase = PetOwnScale(p) and (LGet("PetScaleSize") * ls) or base
		self.petFrame:SetScale(SnapScale(pbase))
	end
	self:RestorePosition()
end

function Grid2Layout:SetFrameLock(FrameLock, ClickThrough)
	local p = self.db.profile
	p.FrameLock = FrameLock
	if not FrameLock then
		ClickThrough = false
	end
	p.ClickThrough = ClickThrough
	self:ApplyClickThrough()
end

function Grid2Layout:AddCustomLayouts()
	local customLayouts = self.db.global.customLayouts
	if customLayouts then
		for n, l in pairs(customLayouts) do
			Grid2Layout:AddLayout(n, l)
		end
	end
end

_G.Grid2Layout = Grid2Layout