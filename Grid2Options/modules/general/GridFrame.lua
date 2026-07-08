--[[ Grid2 frames/cells options ]] --
local Grid2 = Grid2
local Grid2Options = Grid2Options

local L = Grid2Options.L

Grid2Options:AddGeneralOptions("General", "Frames", {
	orientation = {
		type = "select",
		order = 10,
		name = L["Orientation of Frame"],
		desc = L["Set frame orientation."],
		get = function()
			return Grid2Frame.db.profile.orientation
		end,
		set = function(_, v)
			Grid2Frame.db.profile.orientation = v
			for _, indicator in Grid2:IterateIndicators() do
				if indicator.SetOrientation and indicator.orientation == nil then
					Grid2Frame:WithAllFrames(indicator, "Layout")
				end
			end
		end,
		values = {["VERTICAL"] = L["VERTICAL"], ["HORIZONTAL"] = L["HORIZONTAL"]}
	},
	texture = {
		type = "select",
		dialogControl = "LSM30_Statusbar",
		order = 20,
		name = L["Background Texture"],
		desc = L["Select the frame background texture."],
		get = function(info)
			return Grid2Frame.db.profile.frameTexture or "Gradient"
		end,
		set = function(info, v)
			Grid2Frame.db.profile.frameTexture = v
			Grid2Frame:LayoutFrames()
		end,
		values = AceGUIWidgetLSMlists.statusbar
	},
	font = {
		type = "select",
		dialogControl = "LSM30_Font",
		order = 30,
		name = L["Default Font"],
		desc = L["Adjust the font settings"],
		get = function(info)
			return Grid2Frame.db.profile.font
		end,
		set = function(info, v)
			Grid2Frame.db.profile.font = v
			for _, indicator in Grid2:IterateIndicators() do
				if indicator.textfont and indicator.dbx.font == nil then
					Grid2Options:RefreshIndicator(indicator, "Create")
				end
			end
		end,
		values = AceGUIWidgetLSMlists.font
	},
	tooltip = {
		type = "select",
		order = 40,
		name = L["Show Tooltip"],
		desc = L["Show unit tooltip.  Choose 'Always', 'Never', or 'OOC'."],
		get = function()
			return Grid2Frame.db.profile.showTooltip
		end,
		set = function(_, v)
			Grid2Frame.db.profile.showTooltip = v
		end,
		values = {["Always"] = L["Always"], ["Never"] = L["Never"], ["OOC"] = L["OOC"]}
	},
	framewidth = {
		type = "range",
		order = 50,
		name = L["Frame Width"],
		desc = L["Adjust the width of each unit's frame."],
		min = 10,
		max = 150,
		step = 1,
		get = function()
			return Grid2Frame.db.profile.frameWidth
		end,
		set = function(_, v)
			Grid2Frame.db.profile.frameWidth = v
			Grid2Frame:LayoutFrames()
			Grid2Layout:UpdateHeadersSize()
			Grid2Layout:UpdateSize()
			if Grid2Options.LayoutTestRefresh then
				Grid2Options:LayoutTestRefresh()
			end
		end,
		disabled = InCombatLockdown
	},
	frameheight = {
		type = "range",
		order = 60,
		name = L["Frame Height"],
		desc = L["Adjust the height of each unit's frame."],
		min = 10,
		max = 100,
		step = 1,
		get = function()
			return Grid2Frame.db.profile.frameHeight
		end,
		set = function(_, v)
			Grid2Frame.db.profile.frameHeight = v
			Grid2Frame:LayoutFrames()
			Grid2Layout:UpdateHeadersSize()
			Grid2Layout:UpdateSize()
			if Grid2Options.LayoutTestRefresh then
				Grid2Options:LayoutTestRefresh()
			end
		end,
		disabled = InCombatLockdown
	},
	borderDistance = {
		type = "range",
		name = L["Inner Border Size"],
		desc = L["Sets the size of the inner border of each unit frame"],
		min = -16,
		max = 16,
		step = 1,
		order = 70,
		get = function()
			return Grid2Frame.db.profile.frameBorderDistance
		end,
		set = function(_, v)
			Grid2Frame.db.profile.frameBorderDistance = v
			Grid2Frame:LayoutFrames()
		end
	},
	colorFrame = {
		type = "color",
		order = 80,
		name = L["Inner Border Color"],
		desc = L["Sets the color of the inner border of each unit frame"],
		get = function()
			local c = Grid2Frame.db.profile.frameColor
			return c.r, c.g, c.b, c.a
		end,
		set = function(info, r, g, b, a)
			local c = Grid2Frame.db.profile.frameColor
			c.r, c.g, c.b, c.a = r, g, b, a
			Grid2Frame:LayoutFrames()
		end,
		hasAlpha = true
	},
	colorContent = {
		type = "color",
		order = 90,
		name = L["Background Color"],
		desc = L["Sets the background color of each unit frame"],
		get = function()
			local c = Grid2Frame.db.profile.frameContentColor
			return c.r, c.g, c.b, c.a
		end,
		set = function(info, r, g, b, a)
			local c = Grid2Frame.db.profile.frameContentColor
			c.r, c.g, c.b, c.a = r, g, b, a
			Grid2Frame:LayoutFrames()
			Grid2Frame:UpdateIndicators()
		end,
		hasAlpha = true
	},
	mouseoverHighlight = {
		type = "toggle",
		name = L["Mouseover Highlight"],
		desc = L["Toggle mouseover highlight."],
		order = 100,
		get = function()
			return Grid2Frame.db.profile.mouseoverHighlight
		end,
		set = function(_, v)
			Grid2Frame.db.profile.mouseoverHighlight = v
			Grid2Frame:LayoutFrames()
		end
	}
})

--[[ Pet frame appearance overrides ]]--
-- Every setter writes into Grid2Frame.db.profile.pet and reuses the exact refresh sequence the player
-- controls above use. Getters show the effective value: the pet override, or the player value when the
-- pet key is unset. All controls except the master toggle are disabled until the override is enabled.
local function petEnabled()
	return Grid2Frame.db.profile.pet.enabled
end
local function petDisabled()
	return not Grid2Frame.db.profile.pet.enabled
end
local function petDisabledCombat()
	return (not Grid2Frame.db.profile.pet.enabled) or InCombatLockdown()
end
-- Re-lay out frames after a pet size/enable change (same calls the player width/height setters make).
local function petRefreshSize()
	Grid2Frame:LayoutFrames()
	Grid2Layout:UpdateHeadersSize()
	Grid2Layout:UpdateSize()
	if Grid2Options.LayoutTestRefresh then
		Grid2Options:LayoutTestRefresh()
	end
end
-- The background indicator owns the container color and repaints it on unit updates, so a pet background
-- color change must rebuild its cache and repaint. Guarded: the user may have removed the indicator.
local function petRefreshBackground()
	local ind = Grid2:GetIndicatorByName("background")
	if ind then
		Grid2Options:RefreshIndicator(ind, "Update")
	end
end

Grid2Options:AddGeneralOptions("General", "Pet Frames", {
	petEnabled = {
		type = "toggle",
		order = 5,
		width = "full",
		name = L["Customize pet frames separately"],
		desc = L["When enabled, pet frames use these settings instead of the normal frame settings."],
		disabled = InCombatLockdown,
		get = petEnabled,
		set = function(_, v)
			Grid2Frame.db.profile.pet.enabled = v
			petRefreshSize()
			petRefreshBackground()
		end
	},
	petTexture = {
		type = "select",
		dialogControl = "LSM30_Statusbar",
		order = 20,
		name = L["Background Texture"],
		desc = L["Select the frame background texture."],
		disabled = petDisabled,
		get = function()
			local p = Grid2Frame.db.profile
			return p.pet.frameTexture or p.frameTexture or "Gradient"
		end,
		set = function(_, v)
			Grid2Frame.db.profile.pet.frameTexture = v
			Grid2Frame:LayoutFrames()
		end,
		values = AceGUIWidgetLSMlists.statusbar
	},
	petWidth = {
		type = "range",
		order = 50,
		name = L["Frame Width"],
		desc = L["Adjust the width of each unit's frame."],
		min = 10,
		max = 150,
		step = 1,
		disabled = petDisabledCombat,
		get = function()
			local p = Grid2Frame.db.profile
			return p.pet.frameWidth or p.frameWidth
		end,
		set = function(_, v)
			Grid2Frame.db.profile.pet.frameWidth = v
			petRefreshSize()
		end
	},
	petHeight = {
		type = "range",
		order = 60,
		name = L["Frame Height"],
		desc = L["Adjust the height of each unit's frame."],
		min = 10,
		max = 100,
		step = 1,
		disabled = petDisabledCombat,
		get = function()
			local p = Grid2Frame.db.profile
			return p.pet.frameHeight or p.frameHeight
		end,
		set = function(_, v)
			Grid2Frame.db.profile.pet.frameHeight = v
			petRefreshSize()
		end
	},
	petBorderDistance = {
		type = "range",
		order = 70,
		name = L["Inner Border Size"],
		desc = L["Sets the size of the inner border of each unit frame"],
		min = -16,
		max = 16,
		step = 1,
		disabled = petDisabled,
		get = function()
			local p = Grid2Frame.db.profile
			return p.pet.frameBorderDistance or p.frameBorderDistance
		end,
		set = function(_, v)
			Grid2Frame.db.profile.pet.frameBorderDistance = v
			Grid2Frame:LayoutFrames()
		end
	},
	petColorFrame = {
		type = "color",
		order = 80,
		name = L["Inner Border Color"],
		desc = L["Sets the color of the inner border of each unit frame"],
		hasAlpha = true,
		disabled = petDisabled,
		get = function()
			local p = Grid2Frame.db.profile
			local c = p.pet.frameColor or p.frameColor
			return c.r, c.g, c.b, c.a
		end,
		set = function(_, r, g, b, a)
			local pet = Grid2Frame.db.profile.pet
			local c = pet.frameColor
			if not c then
				c = {}
				pet.frameColor = c
			end
			c.r, c.g, c.b, c.a = r, g, b, a
			Grid2Frame:LayoutFrames()
		end
	},
	petColorContent = {
		type = "color",
		order = 90,
		name = L["Background Color"],
		desc = L["Sets the background color of each unit frame"],
		hasAlpha = true,
		disabled = petDisabled,
		get = function()
			local p = Grid2Frame.db.profile
			local c = p.pet.frameContentColor or p.frameContentColor
			return c.r, c.g, c.b, c.a
		end,
		set = function(_, r, g, b, a)
			local pet = Grid2Frame.db.profile.pet
			local c = pet.frameContentColor
			if not c then
				c = {}
				pet.frameContentColor = c
			end
			c.r, c.g, c.b, c.a = r, g, b, a
			Grid2Frame:LayoutFrames()
			petRefreshBackground()
		end
	},
	petMouseoverHighlight = {
		type = "toggle",
		order = 100,
		name = L["Mouseover Highlight"],
		desc = L["Toggle mouseover highlight."],
		disabled = petDisabled,
		get = function()
			local p = Grid2Frame.db.profile
			local v = p.pet.mouseoverHighlight
			if v == nil then
				v = p.mouseoverHighlight
			end
			return v
		end,
		set = function(_, v)
			Grid2Frame.db.profile.pet.mouseoverHighlight = v
			Grid2Frame:LayoutFrames()
		end
	}
})

-- Force GridLayoutHeaders size recalculation. Called from Grid2Options when frames width or height changes.
-- Without this, UpdateSize calculates wrong layout size because g:GetWidth/g:GetHeight dont return correct values.
-- TODO: A better way to fix this issue ?
function Grid2Layout:UpdateHeadersSize()
	for type, headers in pairs(self.groups) do
		for i = 1, self.indexes[type] do
			local g = headers[i]
			g:Hide()
			g:Show()
		end
	end
end