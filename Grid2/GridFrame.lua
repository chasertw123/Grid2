local Grid2 = Grid2
local SecureButton_GetModifiedUnit = SecureButton_GetModifiedUnit
local UnitFrame_OnEnter = UnitFrame_OnEnter
local UnitFrame_OnLeave = UnitFrame_OnLeave
local next = next
local Grid2Frame

--{{{ Registered unit frames tracking
local frames_of_unit = setmetatable({}, {__index = function(self, key)
	local result = {}
	self[key] = result
	return result
end})
local unit_of_frame = {}

function Grid2:SetFrameUnit(frame, unit)
	local prev_unit = unit_of_frame[frame]
	if prev_unit then
		frames_of_unit[prev_unit][frame] = nil
	end
	if unit then
		frames_of_unit[unit][frame] = true
	end
	unit_of_frame[frame] = unit
end

function Grid2:GetUnitFrames(unit)
	return unit and frames_of_unit[unit]
end
--}}}

--{{{ Dropdown menu management
local ToggleUnitMenu
do
	local frame, unit = CreateFrame("Frame", "Grid2_UnitFrame_DropDown", UIParent, "UIDropDownMenuTemplate")
	UIDropDownMenu_Initialize(frame, function()
		if unit then
			local menu, raid
			if UnitIsUnit(unit, "player") then
				menu = "SELF"
			elseif UnitIsUnit(unit, "pet") then
				menu = "PET"
			elseif Grid2:UnitIsPet(unit) then
				menu = "RAID_TARGET_ICON"
			elseif Grid2:UnitIsParty(unit) then
				menu = "PARTY"
			elseif Grid2:UnitIsRaid(unit) then
				menu, raid = "RAID_PLAYER", UnitInRaid(unit)
			else
				return
			end

			frame:SetScript("OnUpdate", Grid2.UnitPopup_OnUpdate)
			Grid2:UnitPopup_ShowMenu(frame, menu, unit, nil, raid)
		end
	end, "MENU")
	ToggleUnitMenu = function(self)
		unit = self.unit
		ToggleDropDownMenu(1, nil, frame, "cursor")
	end
end
--}}}

-- {{ Precalculated backdrop table, shared by all frames
local frameBackdrop
-- Pet appearance override: the player profile shallow-merged with db.profile.pet overrides. Stays nil
-- unless the pet override is enabled, so player frames (and pet frames with the override off) use the
-- normal path unchanged. Rebuilt in Grid2Frame:UpdatePetProfile alongside frameBackdrop.
local petProfile
-- }}

--{{{ Grid2Frame script handlers
local GridFrameEvents = {}
function GridFrameEvents:OnShow()
	Grid2Frame:SendMessage("Grid_UpdateLayoutSize")
end

function GridFrameEvents:OnHide()
	Grid2Frame:SendMessage("Grid_UpdateLayoutSize")
end

function GridFrameEvents:OnAttributeChanged(name, value)
	if name == "unit" then
		if value then
			local unit = SecureButton_GetModifiedUnit(self)
			if self.unit ~= unit then
				Grid2Frame:Debug("updated", self:GetName(), name, value, unit)
				self.unit = unit
				self:UpdateIndicators()
				Grid2:SetFrameUnit(self, unit)
			end
		elseif self.unit then
			Grid2Frame:Debug("removed", self:GetName(), name, self.unit)
			self.unit = nil
			Grid2:SetFrameUnit(self, nil)
			for _, indicator in Grid2:IterateIndicators() do
				if indicator.OnUnitLost then -- let indicators tear down per-frame timers when a frame is de-occupied
					indicator:OnUnitLost(self)
				end
			end
		end
	end
end

function GridFrameEvents:OnEnter()
	Grid2Frame:OnFrameEnter(self)
end

function GridFrameEvents:OnLeave()
	Grid2Frame:OnFrameLeave(self)
end
--}}}

--{{{ GridFramePrototype
local pairs = pairs
local GridFramePrototype = {}
local function GridFrame_Init(frame, width, height)
	for name, value in pairs(GridFramePrototype) do
		frame[name] = value
	end
	for event, handler in pairs(GridFrameEvents) do
		frame:SetScript(event, handler)
	end
	if frame:CanChangeAttribute() then
		frame:SetAttribute("initial-width", width)
		frame:SetAttribute("initial-height", height)
	end
	frame.menu = ToggleUnitMenu
	frame.container = frame:CreateTexture()
	frame:CreateIndicators()
	frame:Layout()
	ClickCastFrames = ClickCastFrames or {}
	ClickCastFrames[frame] = true
end

function GridFramePrototype:Layout()
	-- Pet frames read the merged pet profile when the override is enabled; otherwise (and for all player
	-- frames) petProfile is nil and this is the original Grid2Frame.db.profile. The rest of the function
	-- is unchanged: it reads every appearance value through dbx, so pet values flow through automatically.
	local dbx = (self.isPet and petProfile) or Grid2Frame.db.profile
	local w = dbx.frameWidth
	local h = dbx.frameHeight
	-- external border controlled by the border indicator
	local r, g, b, a = self:GetBackdropBorderColor()
	self:SetBackdrop(frameBackdrop)
	self:SetBackdropBorderColor(r, g, b, a)
	-- inner border color (sure that is the inner border)
	local cf = dbx.frameColor
	self:SetBackdropColor(cf.r, cf.g, cf.b, cf.a)
	-- visible background
	local container = self.container
	container:SetPoint("CENTER", self, "CENTER")
	-- visible background color
	local cb = dbx.frameContentColor
	container:SetVertexColor(cb.r, cb.g, cb.b, cb.a)
	-- shrink the background, showing part of the real frame background (that is behind) as a inner border.
	local inset = (dbx.frameBorder + dbx.frameBorderDistance) * 2
	container:SetSize(w - inset, h - inset)
	-- visible background texture
	local texture = Grid2:MediaFetch("statusbar", dbx.frameTexture, "Gradient")
	self.container:SetTexture(texture)
	-- set size
	if not InCombatLockdown() then
		self:SetSize(w, h)
		-- Keep the secure header's per-child "initial" size in sync with the size we just applied. The header
		-- applies initial-width/initial-height to a child (ApplyUnitButtonConfiguration in Blizzard's
		-- SecureTemplates.lua) ONLY when it (re)creates that child. Left at the stale registration-time value
		-- (baked from the PLAYER size, because pet.enabled was still false the first time the pet frames were
		-- created) the header snaps pet children back to the player size on the next creation / ForceFramesCreation
		-- / ReloadLayout pass -- which is why a per-pet size only "took" after also enabling the separate pet
		-- container (that path runs a full ReloadLayout). Refreshing them here, the single place that already
		-- resolves the correct player-or-pet size, keeps both correct without a ReloadLayout.
		self:SetAttribute("initial-width", w)
		self:SetAttribute("initial-height", h)
	end
	-- highlight texture
	self:SetHighlightTexture(dbx.mouseoverHighlight and "Interface\\QuestFrame\\UI-QuestTitleHighlight" or nil)
	-- Adjust indicators position to the new size
	for _, indicator in Grid2:IterateIndicators() do
		indicator:Layout(self)
	end
end

function GridFramePrototype:CreateIndicators()
	for _, indicator in Grid2:IterateIndicators() do
		indicator:Create(self)
	end
end

function GridFramePrototype:UpdateIndicators()
	local unit = self.unit
	if unit then
		for _, indicator in Grid2:IterateIndicators() do
			indicator:Update(self, unit)
		end
	end
end
--}}}

--{{{ Grid2Frame
Grid2Frame = Grid2:NewModule("Grid2Frame")

Grid2Frame.defaultDB = {
	profile = {
		debug = false,
		font = "Friz Quadrata TT",
		frameHeight = 48,
		frameWidth = 48,
		frameBorder = 2,
		frameBorderTexture = "Grid2 Flat",
		frameBorderDistance = 1,
		frameTexture = "Gradient",
		frameColor = {r = 0, g = 0, b = 0, a = 1},
		frameContentColor = {r = 0, g = 0, b = 0, a = 1},
		mouseoverHighlight = false,
		showTooltip = "OOC",
		orientation = "VERTICAL",
		textOrientation = "VERTICAL",
		intensity = 0.5,
		blinkType = "Flash",
		blinkFrequency = 2,
		-- Pet frame appearance overrides. enabled=false => pets look exactly like players. When enabled,
		-- only the keys the user changes are stored here; everything else falls back to the player value.
		pet = {enabled = false}
	}
}

function Grid2Frame:OnModuleInitialize()
	self.registeredFrames = {}
end

function Grid2Frame:OnModuleEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateFrameUnits")
	self:RegisterEvent("UNIT_ENTERED_VEHICLE")
	self:RegisterEvent("UNIT_EXITED_VEHICLE")
	self:RegisterMessage("Grid_UnitUpdate")
	self:UpdateBlink()
	self:UpdateBackdrop()
	self:UpdateFrameUnits()
	self:UpdateIndicators()
end

function Grid2Frame:OnModuleDisable()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self:UnregisterEvent("UNIT_ENTERED_VEHICLE")
	self:UnregisterEvent("UNIT_EXITED_VEHICLE")
	self:UnregisterMessage("Grid_UnitUpdate")
end

function Grid2Frame:OnModuleUpdate()
	self:CreateIndicators()
	self:LayoutFrames()
end

function Grid2Frame:RegisterFrame(frame)
	GridFrame_Init(frame, self:GetFrameSize(frame.isPet))
	self.registeredFrames[frame:GetName()] = frame
end

function Grid2Frame:CreateIndicators()
	for _, frame in next, self.registeredFrames do
		frame:CreateIndicators()
	end
end

function Grid2Frame:UpdateIndicators()
	for _, frame in next, self.registeredFrames do
		frame:UpdateIndicators()
	end
end

function Grid2Frame:UpdateBackdrop()
	local dbx = self.db.profile
	local frameBorder = dbx.frameBorder
	frameBackdrop = Grid2:GetBackdropTable(
		Grid2:MediaFetch("border", dbx.frameBorderTexture, "Grid2 Flat"), -- edgeFile
		dbx.frameBorder, -- edgeSize
		[[Interface\Buttons\WHITE8X8]], -- bgFile
		true, -- tile
		16 -- tileSize
	)
	self:UpdatePetProfile()
end

-- Rebuild the merged pet appearance profile. When db.profile.pet.enabled is set, petProfile becomes the
-- player profile overlaid with the pet overrides (any key the user has not overridden falls back to the
-- player value); otherwise it is nil and pet frames use the normal player path. Rebuilt here so it
-- refreshes on every settings change, since UpdateBackdrop runs from OnModuleEnable and LayoutFrames.
function Grid2Frame:UpdatePetProfile()
	local p = self.db.profile
	local pet = p.pet
	if pet and pet.enabled then
		local eff = {}
		for k, v in pairs(p) do
			if k ~= "pet" then eff[k] = v end
		end
		for k, v in pairs(pet) do
			if k ~= "enabled" then eff[k] = v end
		end
		petProfile = eff
	else
		petProfile = nil
	end
end

function Grid2Frame:LayoutFrames()
	self:UpdateBackdrop()
	for name, frame in next, self.registeredFrames do
		frame:Layout()
	end
	self:SendMessage("Grid_UpdateLayoutSize")
end

function Grid2Frame:GetFrameSize(isPet)
	local p = (isPet and petProfile) or self.db.profile
	return p.frameWidth, p.frameHeight
end

-- Grid2Frame:WithAllFrames()
do
	local type, with = type, {}
	with["table"] = function(self, object, func, ...)
		if type(func) == "string" then
			func = object[func]
		end
		for _, frame in next, self.registeredFrames do
			func(object, frame, ...)
		end
	end
	with["function"] = function(self, func, ...)
		for _, frame in next, self.registeredFrames do
			func(frame, ...)
		end
	end
	function Grid2Frame:WithAllFrames(param, ...)
		with[type(param)](self, param, ...)
	end
end

-- shows the default unit tooltip
do
	local TooltipCheck = {
		Always = function() return false end,
		Never = function() return true end,
		OOC = InCombatLockdown
	}
	function Grid2Frame:OnFrameEnter(frame)
		if TooltipCheck[self.db.profile.showTooltip]() then
			UnitFrame_OnLeave(frame)
		else
			UnitFrame_OnEnter(frame)
		end
	end
	function Grid2Frame:OnFrameLeave(frame)
		UnitFrame_OnLeave(frame)
	end
end

-- Frames blink animations management
do
	local blinkDuration
	function Grid2Frame:SetBlinkEffect(frame, enabled)
		local anim = frame.blinkAnim
		if enabled then
			if not anim then
				anim = frame:CreateAnimationGroup()
				local alpha = anim:CreateAnimation("Alpha")
				alpha:SetOrder(1)
				alpha:SetChange(-0.9)
				anim:SetLooping("REPEAT")
				anim.alpha = alpha
				frame.blinkAnim = anim
			end
			if not anim:IsPlaying() then
				anim.alpha:SetDuration(blinkDuration)
				anim:Play()
			end
		elseif anim then
			anim:Stop()
		end
	end
	function Grid2Frame:UpdateBlink()
		local indicator = Grid2.indicatorPrototype
		indicator.Update = self.db.profile.blinkType ~= "None" and indicator.UpdateBlink or indicator.UpdateNoBlink
		blinkDuration = 1 / self.db.profile.blinkFrequency
	end
end

-- Event handlers
function Grid2Frame:UpdateFrameUnits()
	for _, frame in next, self.registeredFrames do
		local old_unit = frame.unit
		local unit = SecureButton_GetModifiedUnit(frame)
		if old_unit ~= unit then
			Grid2:SetFrameUnit(frame, unit)
			frame.unit = unit
			frame:UpdateIndicators()
		end
	end
end

function Grid2Frame:UNIT_ENTERED_VEHICLE(_, unit)
	for frame in next, Grid2:GetUnitFrames(unit) do
		local old, new = frame.unit, SecureButton_GetModifiedUnit(frame)
		if old ~= new then
			Grid2:SetFrameUnit(frame, new)
			frame.unit = new
			frame:UpdateIndicators()
		end
	end
end

function Grid2Frame:UNIT_EXITED_VEHICLE(_, unit)
	local pet = Grid2:GetPetUnitByUnit(unit) or unit
	for frame in next, Grid2:GetUnitFrames(pet) do
		local old, new = frame.unit, SecureButton_GetModifiedUnit(frame)
		if old ~= new then
			Grid2:SetFrameUnit(frame, new)
			frame.unit = new
			frame:UpdateIndicators()
		end
	end
end

function Grid2Frame:Grid_UnitUpdate(_, unit)
	for frame in next, Grid2:GetUnitFrames(unit) do
		local old, new = frame.unit, SecureButton_GetModifiedUnit(frame)
		if old ~= new then
			Grid2:SetFrameUnit(frame, new)
			frame.unit = new
		end
		frame:UpdateIndicators()
	end
end
--}}}

_G.Grid2Frame = Grid2Frame

-- Allow other modules/addons to easily modify the grid unit frames
Grid2Frame.Events = GridFrameEvents
Grid2Frame.Prototype = GridFramePrototype