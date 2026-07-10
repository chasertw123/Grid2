--[[ Indicators options ]]--
local Grid2Options = Grid2Options
local L = Grid2Options.L

-- Direct link to AceConfigTable indicators list
Grid2Options.indicatorOptions = Grid2Options.options.args.indicators.args
-- Path to indicator icons
Grid2Options.indicatorIconPath = "Interface\\Addons\\Grid2Options\\media\\indicator-"
-- Creatable indicators list
Grid2Options.indicatorTypes = {}
-- Indicators sort order
Grid2Options.indicatorTypesOrder = {background = 1, alpha = 2, border = 3, glowborder = 4, multibar = 5, bar = 6, text = 7, square = 8, shape = 9, icon = 10, icons = 11, portrait = 12}

-- Register indicator options
function Grid2Options:RegisterIndicatorOptions(type, isCreatable, funcMakeOptions, optionParams)
	self.typeMakeOptions[type] = funcMakeOptions
	self.optionParams[type] = optionParams
	if isCreatable then
		self.indicatorTypes[type] = L[type]
	end
end

-- Insert options of a indicator in AceConfigTable
function Grid2Options:AddIndicatorOptions(indicator, statusOptions, layoutOptions, colorOptions)
	local options = self.indicatorOptions[indicator.name].args
	wipe(options)
	if statusOptions then
		options["statuses"] = {type = "group", order = 10, name = L["statuses"], args = statusOptions}
	end
	if colorOptions then
		options["colors"] = {type = "group", order = 20, name = L["Colors"], args = colorOptions}
	end
	if layoutOptions then
		options["layout"] = {type = "group", order = 30, name = L["Layout"], args = layoutOptions}
	end
	self:MakeIndicatorLoadOptions(indicator, options) -- re-add here too: AddIndicatorOptions wipes options and is
	-- called on its own during refreshes, which was dropping the Load tab added by MakeIndicatorOptions
end

-- Don't remove options param (openmanager hooks this function and needs this parameter)
function Grid2Options:MakeIndicatorChildOptions(indicator, options)
	local funcMakeOptions = self.typeMakeOptions[indicator.dbx.type]
	if funcMakeOptions then
		funcMakeOptions(self, indicator)
	end
end

-- Insert indicator group option in AceConfigTable
function Grid2Options:MakeIndicatorOptions(indicator)
	local type, options = indicator.dbx.type, {}
	self.indicatorOptions[indicator.name] = {
		type = "group",
		childGroups = "tab",
		icon = self.indicatorIconPath .. (self.indicatorTypesOrder[type] and type or "default"),
		order = self.indicatorTypesOrder[type] or nil,
		name = L[indicator.name],
		desc = L["Options for %s."]:format(indicator.name),
		args = options
	}
	self:MakeIndicatorChildOptions(indicator, options)
	self:MakeIndicatorLoadOptions(indicator, options)
end

-- Load filter tab (Player Class + Unit Type) -- added to every indicator
do
	local classValues = {}
	for class, name in pairs(LOCALIZED_CLASS_NAMES_MALE) do
		classValues[class] = name
	end
	local unitValues = { player = "Player (self only)", players = "Players (incl. self)", pet = "Pets" }

	local function Load(indicator)
		indicator.dbx.load = indicator.dbx.load or {}
		return indicator.dbx.load
	end
	local function Apply()
		Grid2Frame:UpdateIndicators()
	end

	function Grid2Options:MakeIndicatorLoadOptions(indicator, options)
		options.load = {
			type = "group", order = 40, name = "Load",
			args = {
				classToggle = {
					type = "toggle", order = 1, width = "full",
					name = "Only load for your class",
					desc = "Load this indicator only when your own character is one of the selected classes.",
					get = function() local d = indicator.dbx.load; return (d and d.classEnabled) or false end,
					set = function(_, v) Load(indicator).classEnabled = v or nil; Apply() end,
				},
				classList = {
					type = "multiselect", order = 2, name = "Classes",
					hidden = function() local d = indicator.dbx.load; return not (d and d.classEnabled) end,
					values = classValues,
					get = function(_, k) local d = indicator.dbx.load; return (d and d.classes and d.classes[k]) or false end,
					set = function(_, k, v) local d = Load(indicator); d.classes = d.classes or {}; d.classes[k] = v or nil; Apply() end,
				},
				sep = { type = "header", order = 3, name = "" },
				unitToggle = {
					type = "toggle", order = 4, width = "full",
					name = "Only show on certain unit types",
					desc = "Show this indicator only on frames whose unit matches the selected types.",
					get = function() local d = indicator.dbx.load; return (d and d.unitEnabled) or false end,
					set = function(_, v) Load(indicator).unitEnabled = v or nil; Apply() end,
				},
				unitList = {
					type = "multiselect", order = 5, name = "Unit Types",
					hidden = function() local d = indicator.dbx.load; return not (d and d.unitEnabled) end,
					values = unitValues,
					get = function(_, k) local d = indicator.dbx.load; return (d and d.units and d.units[k]) or false end,
					set = function(_, k, v) local d = Load(indicator); d.units = d.units or {}; d.units[k] = v or nil; Apply() end,
				},
			},
		}
	end
end

-- Remove indicator options from AceConfigTable
function Grid2Options:DeleteIndicatorOptions(indicator)
	self.indicatorOptions[indicator.name] = nil
	if indicator.OnDelete then
		indicator:OnDelete()
	end
end

-- Refresh indicator options
function Grid2Options:RefreshIndicatorOptions(indicator)
	local options = self.indicatorOptions[indicator.name]
	if not options and indicator.parentName then
		options = self.indicatorOptions[indicator.parentName]
		indicator = Grid2.indicators[indicator.parentName]
	end
	if indicator and options and not options.args.openManager then
		self:MakeIndicatorOptions(indicator)
	end
end

-- Create all indicators options (dont remove options param, is used by openmanager)
function Grid2Options:MakeIndicatorsOptions(options)
	-- remove old options
	options = options or self.indicatorOptions
	wipe(options)
	-- make new indicator options
	if self.MakeNewIndicatorOptions then
		self:MakeNewIndicatorOptions()
	end
	-- make indicators options
	local indicators = Grid2.db.profile.indicators
	for baseKey, dbx in pairs(indicators) do
		if self.typeMakeOptions[dbx.type] then -- filter bar-color&text-color indicators
			local indicator = Grid2.indicators[baseKey]
			if indicator then
				local ok, err = pcall(self.MakeIndicatorOptions, self, indicator)
				if not ok then Grid2:Print("|cffff4040Grid2 options error [indicator " .. tostring(baseKey) .. "]:|r " .. tostring(err)) end
			end
		end
	end
end