--[[ General Settings ]]--
local Grid2Options = Grid2Options
local L = Grid2Options.L

local tabs_order = 10
local sect_order = 10

-- Tabs whose sections render as a navigable tree (one panel per section) instead of stacking as inline
-- groups in one long scroll. Value = childGroups mode ("tree"). Any tab NOT listed keeps the original
-- inline behavior (e.g. Misc, whose sections are only 1-2 controls each and read better inline).
local NAVIGABLE_TABS = {["General"] = "tree", ["Pets"] = "tree"}

function Grid2Options:AddGeneralOptions(TabName, SectionName, extraOptions)
	local Tabs = Grid2Options.options.args["general"]
	local navMode = NAVIGABLE_TABS[TabName]
	local CurTab = Tabs.args[TabName]
	if (not CurTab) and (SectionName or (not extraOptions.args)) then
		CurTab = {type = "group", order = tabs_order, name = L[TabName], args = {}}
		if navMode then CurTab.childGroups = navMode end
		tabs_order = tabs_order + 1
		Tabs.args[TabName] = CurTab
	end
	if SectionName then
		local CurSec = CurTab.args[SectionName]
		if CurSec then
			for key, value in pairs(extraOptions) do
				CurSec.args[key] = value
			end
		else
			if extraOptions.args then
				extraOptions.order = sect_order
				CurTab.args[SectionName] = extraOptions
			else
				CurTab.args[SectionName] = {
					type = "group",
					-- Navigable tabs get non-inline sections (tree nodes); all other tabs stay inline as before.
					inline = (not navMode) or nil,
					order = sect_order,
					name = L[SectionName],
					desc = L["Options for %s."]:format(L[SectionName]),
					args = extraOptions
				}
			end
			sect_order = sect_order + 1
		end
	else
		if extraOptions.args then
			extraOptions.order = tabs_order
			tabs_order = tabs_order + 1
			Tabs.args[TabName] = extraOptions
		else
			for key, value in pairs(extraOptions) do
				CurTab.args[key] = value
			end
		end
	end
end