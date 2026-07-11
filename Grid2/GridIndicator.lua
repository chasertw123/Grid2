local Grid2 = Grid2
local Grid2Frame = Grid2Frame

Grid2.indicators = {}
Grid2.indicatorTypes = {}
Grid2.indicatorPrototype = {}

local indicator = Grid2.indicatorPrototype
indicator.__index = indicator

function indicator:new(name)
	local e = setmetatable({}, self)
	local p = {}
	e.sortStatuses = function(a, b) return p[a] > p[b] end
	e.priorities = p
	e.name = name
	e.statuses = {}
	e.prototype = self
	return e
end

function indicator:CreateFrame(ftype, parent)
	local f = parent[self.name]
	if not (f and f:GetObjectType() == ftype) then
		f = CreateFrame(ftype, nil, parent)
		parent[self.name] = f
	end
	f:Hide()
	return f
end

function indicator:AddFrame(f, parent)
	parent[self.name] = f
end

function indicator:Update(parent, unit)
	self:OnUpdate(parent, unit, self:GetCurrentStatus(unit))
end

function indicator:RegisterStatus(status, priority)
	if self.priorities[status] then return end
	self.priorities[status] = priority
	self.statuses[#self.statuses + 1] = status
	self:SortStatuses()
	status:RegisterIndicator(self)
end

function indicator:UnregisterStatus(status)
	if not self.priorities[status] then return end
	self.priorities[status] = nil
	tremove(self.statuses, self:GetStatusIndex(status))
	self:SortStatuses()
	status:UnregisterIndicator(self)
end

function indicator:SortStatuses()
	table.sort(self.statuses, self.sortStatuses)
end

function indicator:SetStatusPriority(status, priority)
	if not self.priorities[status] then return end
	self.priorities[status] = priority
	self:SortStatuses()
end

function indicator:GetStatusPriority(status)
	return self.priorities[status]
end

function indicator:GetStatusIndex(status)
	for i, s in ipairs(self.statuses) do
		if s == status then
			return i
		end
	end
end

function indicator:GetCurrentStatus(unit)
	if unit then
		local statuses = self.statuses
		for i = 1, #statuses do
			local status = statuses[i]
			local state = status:IsActive(unit)
			if state then
				return status, state
			end
		end
	end
end

-- Load filter: gate whether this indicator renders on a given frame/unit.
-- classEnabled -> only when the PLAYER's own class is selected (global); unitEnabled -> only on frames whose
-- unit type (player / players / pet) is selected (per-frame). No dbx.load means "always show" (compatible).
local UnitIsUnit = UnitIsUnit
function indicator:LoadAllows(parent, unit)
	local load = self.dbx and self.dbx.load
	if not load then return true end
	if load.classEnabled then
		local classes = load.classes
		if not (classes and classes[Grid2.playerClass]) then return false end
	end
	if load.unitEnabled then
		local units = load.units
		local ok
		if parent.isPet then
			ok = units and units.pet
		else -- a player frame matches "players" (any player, incl. you) or "player" when it's your own frame
			ok = units and (units.players or (units.player and UnitIsUnit(unit, "player")))
		end
		if not ok then return false end
	end
	return true
end

-- Update functions
function indicator:UpdateBlink(parent, unit)
	if not self:LoadAllows(parent, unit) then
		local func = self.GetBlinkFrame
		if func then Grid2Frame:SetBlinkEffect(func(self, parent), false) end
		return self:OnUpdate(parent, unit, nil)
	end
	local status, state = self:GetCurrentStatus(unit)
	local func = self.GetBlinkFrame
	if func then
		Grid2Frame:SetBlinkEffect(func(self, parent), state == "blink")
	end
	self:OnUpdate(parent, unit, status)
end

function indicator:UpdateNoBlink(parent, unit)
	if not self:LoadAllows(parent, unit) then
		return self:OnUpdate(parent, unit, nil)
	end
	self:OnUpdate(parent, unit, self:GetCurrentStatus(unit))
end

indicator.Update = indicator.UpdateBlink

function Grid2:RegisterIndicator(indicator, types)
	local name = indicator.name
	self.indicators[name] = indicator
	for _, itype in ipairs(types) do
		local t = self.indicatorTypes[itype] or {}
		self.indicatorTypes[itype] = t
		t[name] = indicator
	end
end

function Grid2:UnregisterIndicator(indicator)
	local statuses = indicator.statuses
	while #statuses > 0 do
		indicator:UnregisterStatus(statuses[#statuses])
	end
	if indicator.Disable then
		Grid2Frame:WithAllFrames(indicator, "Disable")
	end
	if indicator.OnDelete then -- let the indicator drop module-level registrations (e.g. Portrait's Portraits set)
		indicator:OnDelete()
	end
	local name = indicator.name
	self.indicators[name] = nil
	for _, t in pairs(self.indicatorTypes) do
		t[name] = nil
	end
	if indicator.sideKick then
		Grid2:UnregisterIndicator(indicator.sideKick)
		indicator.sideKick = nil
	end
end

function Grid2:GetIndicatorByName(name)
	return name and Grid2.indicators[name]
end

function Grid2:IterateIndicators(itype)
	return next, itype and self.indicatorTypes[itype] or self.indicators
end