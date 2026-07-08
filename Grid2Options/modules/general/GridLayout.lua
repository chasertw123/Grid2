--[[ Layout Section ]]--
local Grid2 = Grid2
local Grid2Options = Grid2Options
local L = Grid2Options.L

local order_layout = 20
local order_display = 30
local order_anchor = 40

Grid2Options:AddGeneralOptions("General", "Layout Settings", {
	horizontal = {
		type = "toggle",
		name = L["Horizontal groups"],
		desc = L["Switch between horzontal/vertical groups."],
		order = order_layout + 4,
		get = function()
			return Grid2Layout.db.profile.horizontal
		end,
		set = function()
			Grid2Layout.db.profile.horizontal = not Grid2Layout.db.profile.horizontal
			Grid2Layout:ReloadLayout()
			if Grid2Options.LayoutTestRefresh then
				Grid2Options:LayoutTestRefresh()
			end
		end
	},
	lock = {
		type = "toggle",
		name = L["Frame lock"],
		desc = L["Locks/unlocks the grid for movement."],
		order = order_layout + 6,
		get = function()
			return Grid2Layout.db.profile.FrameLock
		end,
		set = function()
			Grid2Layout:FrameLock()
		end
	},
	clickthrough = {
		type = "toggle",
		name = L["Click through the Grid Frame"],
		desc = L["Allows mouse click through the Grid Frame."],
		order = order_layout + 7,
		get = function()
			return Grid2Layout.db.profile.ClickThrough
		end,
		set = function()
			local v = not Grid2Layout.db.profile.ClickThrough
			Grid2Layout.db.profile.ClickThrough = v
			Grid2Layout.frame:EnableMouse(not v)
		end,
		disabled = function()
			return not Grid2Layout.db.profile.FrameLock
		end
	},
	displayheader = {
		type = "header",
		order = order_display,
		name = L["Display"]
	},
	display = {
		type = "select",
		name = L["Show Frame"],
		desc = L["Sets when the Grid is visible: Choose 'Always', 'Grouped', or 'Raid'."],
		order = order_display + 1,
		get = function()
			return Grid2Layout.db.profile.FrameDisplay
		end,
		set = function(_, v)
			Grid2Layout.db.profile.FrameDisplay = v
			Grid2Layout:CheckVisibility()
		end,
		values = {["Always"] = L["Always"], ["Grouped"] = L["Grouped"], ["Raid"] = L["Raid"]}
	},
	frameStrata = {
		type = "select",
		name = L["Frame Strata"],
		desc = L["Sets the strata in which the layout frame should be layered."],
		order = order_display + 2,
		get = function()
			return Grid2Layout.db.profile.FrameStrata or "MEDIUM"
		end,
		set = function(_, v)
			Grid2LayoutFrame:SetFrameStrata(v)
			Grid2Layout.db.profile.FrameStrata = (v ~= "MEDIUM") and v or nil
		end,
		values = {BACKGROUND = L["BACKGROUND"], LOW = L["LOW"], MEDIUM = L["MEDIUM"], HIGH = L["HIGH"]}
	},
	backgroundTexture = {
		type = "select",
		dialogControl = "LSM30_Background",
		order = order_display + 3,
		name = L["Background Texture"],
		desc = L["Adjust the background texture."],
		get = function(info)
			return Grid2Layout.db.profile.BackgroundTexture or "None"
		end,
		set = function(info, v)
			Grid2Layout.db.profile.BackgroundTexture = v
			Grid2Layout:UpdateTextures()
			Grid2Layout:UpdateColor()
		end,
		values = AceGUIWidgetLSMlists.background
	},
	borderTexture = {
		type = "select",
		dialogControl = "LSM30_Border",
		order = order_display + 3.1,
		name = L["Border Texture"],
		desc = L["Adjust the border texture."],
		get = function(info)
			return Grid2Layout.db.profile.BorderTexture or "Grid2 Flat"
		end,
		set = function(info, v)
			Grid2Layout.db.profile.BorderTexture = v
			Grid2Layout:UpdateTextures()
			Grid2Layout:UpdateColor()
		end,
		values = AceGUIWidgetLSMlists.border
	},
	background = {
		type = "color",
		name = L["Background Color"],
		desc = L["Adjust background color and alpha."],
		order = order_display + 3.2,
		get = function()
			local settings = Grid2Layout.db.profile
			return settings.BackgroundR, settings.BackgroundG, settings.BackgroundB, settings.BackgroundA
		end,
		set = function(_, r, g, b, a)
			local settings = Grid2Layout.db.profile
			settings.BackgroundR, settings.BackgroundG, settings.BackgroundB, settings.BackgroundA = r, g, b, a
			Grid2Layout:UpdateColor()
		end,
		hasAlpha = true
	},
	border = {
		type = "color",
		name = L["Border Color"],
		desc = L["Adjust border color and alpha."],
		order = order_display + 3.3,
		get = function()
			local settings = Grid2Layout.db.profile
			return settings.BorderR, settings.BorderG, settings.BorderB, settings.BorderA
		end,
		set = function(_, r, g, b, a)
			local settings = Grid2Layout.db.profile
			settings.BorderR, settings.BorderG, settings.BorderB, settings.BorderA = r, g, b, a
			Grid2Layout:UpdateColor()
		end,
		hasAlpha = true
	},
	backgroundTile = {
		type = "toggle",
		name = L["Tile"],
		desc = L["Tile the background texture."],
		order = order_display + 4,
		get = function()
			return Grid2Layout.db.profile.BackgroundTile
		end,
		set = function(info, v)
			Grid2Layout.db.profile.BackgroundTile = v
			Grid2Layout:UpdateTextures()
			Grid2Layout:UpdateColor()
		end
	},
	backgroundTileSize = {
		type = "range",
		name = L["Tile size"],
		desc = L["The size of the texture pattern."],
		order = order_display + 4.5,
		get = function()
			return Grid2Layout.db.profile.BackgroundTileSize
		end,
		set = function(info, v)
			Grid2Layout.db.profile.BackgroundTileSize = v
			Grid2Layout:UpdateTextures()
			Grid2Layout:UpdateColor()
		end,
		min = 0,
		max = floor(GetScreenWidth()),
		step = 1.0,
		bigStep = 1
	},
	spacing = {
		type = "range",
		name = L["Spacing"],
		desc = L["Adjust frame spacing."],
		order = order_display + 5,
		max = 25,
		min = 0,
		step = 1,
		get = function()
			return Grid2Layout.db.profile.Spacing
		end,
		set = function(_, v)
			Grid2Layout.db.profile.Spacing = v
			Grid2Layout:ReloadLayout()
		end
	},
	padding = {
		type = "range",
		name = L["Padding"],
		desc = L["Adjust frame padding."],
		order = order_display + 6,
		max = 20,
		min = 0,
		step = 1,
		get = function()
			return Grid2Layout.db.profile.Padding
		end,
		set = function(_, v)
			Grid2Layout.db.profile.Padding = v
			Grid2Layout:ReloadLayout()
		end
	},
	scale = {
		type = "range",
		name = L["Scale"],
		desc = L["Adjust Grid scale."],
		order = order_display + 7,
		min = 0.5,
		max = 2.0,
		step = 0.05,
		width = "double",
		isPercent = true,
		get = function()
			return Grid2Layout.db.profile.ScaleSize
		end,
		set = function(_, v)
			Grid2Layout.db.profile.ScaleSize = v
			Grid2Layout:Scale()
		end
	},
	anchorheader = {
		type = "header",
		order = order_anchor,
		name = L["Position and Anchor"]
	},
	layoutanchor = {
		type = "select",
		name = L["Layout Anchor"],
		desc = L["Sets where Grid is anchored relative to the screen."],
		order = order_anchor + 1,
		get = function()
			return Grid2Layout.db.profile.anchor
		end,
		set = function(_, v)
			Grid2Layout.db.profile.anchor = v
			Grid2Layout:SavePosition()
			Grid2Layout:RestorePosition()
		end,
		values = {
			["CENTER"] = L["CENTER"],
			["TOP"] = L["TOP"],
			["BOTTOM"] = L["BOTTOM"],
			["LEFT"] = L["LEFT"],
			["RIGHT"] = L["RIGHT"],
			["TOPLEFT"] = L["TOPLEFT"],
			["TOPRIGHT"] = L["TOPRIGHT"],
			["BOTTOMLEFT"] = L["BOTTOMLEFT"],
			["BOTTOMRIGHT"] = L["BOTTOMRIGHT"]
		}
	},
	posx = {
		type = "range",
		name = L["Horizontal Position"],
		desc = L["Adjust the horizontal position of the Grid frame."],
		order = order_anchor + 1.1,
		softMin = -2048,
		softMax = 2048,
		step = 1,
		bigStep = 5,
		get = function()
			return floor(Grid2Layout.db.profile.PosX + 0.5)
		end,
		set = function(_, v)
			Grid2Layout.db.profile.PosX = v
			Grid2Layout:RestorePosition()
		end
	},
	posy = {
		type = "range",
		name = L["Vertical Position"],
		desc = L["Adjust the vertical position of the Grid frame."],
		order = order_anchor + 1.2,
		softMin = -2048,
		softMax = 2048,
		step = 1,
		bigStep = 5,
		get = function()
			return floor(Grid2Layout.db.profile.PosY + 0.5)
		end,
		set = function(_, v)
			Grid2Layout.db.profile.PosY = v
			Grid2Layout:RestorePosition()
		end
	},
	groupanchor = {
		type = "select",
		name = L["Group Anchor"],
		desc = L["Sets where groups are anchored relative to the layout frame."],
		order = order_anchor + 2,
		get = function()
			return Grid2Layout.db.profile.groupAnchor
		end,
		set = function(_, v)
			Grid2Layout.db.profile.groupAnchor = v
			Grid2Layout:ReloadLayout()
			if Grid2Options.LayoutTestRefresh then
				Grid2Options:LayoutTestRefresh()
			end
		end,
		values = {
			["TOPLEFT"] = L["TOPLEFT"],
			["TOPRIGHT"] = L["TOPRIGHT"],
			["BOTTOMLEFT"] = L["BOTTOMLEFT"],
			["BOTTOMRIGHT"] = L["BOTTOMRIGHT"]
		}
	},
	clamp = {
		type = "toggle",
		name = L["Clamped to screen"],
		desc = L["Toggle whether to permit movement out of screen."],
		order = order_anchor + 3,
		get = function()
			return Grid2Layout.db.profile.clamp
		end,
		set = function()
			Grid2Layout.db.profile.clamp = not Grid2Layout.db.profile.clamp
			Grid2Layout:SetClamp()
		end
	},
	reset = {
		type = "execute",
		width = "half",
		name = L["Reset"],
		desc = L["Resets the layout frame's position and anchor."],
		order = order_anchor + 4,
		func = function()
			Grid2Layout:ResetPosition()
		end
	}
})

--[[ Pet Position Section ]]--
-- Route pet frames to a separate, independently-positionable container. OFF by default (pets stay in the
-- main grid). Every non-master control is disabled until the feature is enabled.
local function petPosDisabled()
	return not Grid2Layout.db.profile.petEnabled
end

Grid2Options:AddGeneralOptions("General", "Pet Position", {
	petEnabled = {
		type = "toggle",
		width = "full",
		order = 1,
		name = L["Position pet frames separately"],
		desc = L["Route pet frames to their own movable container, positioned independently of the main grid."],
		disabled = InCombatLockdown,
		get = function()
			return Grid2Layout.db.profile.petEnabled
		end,
		set = function(_, v)
			Grid2Layout.db.profile.petEnabled = v
			Grid2Layout:SetupPetFrame()
			Grid2Layout:ReloadLayout()
			if Grid2Options.LayoutTestRefresh then
				Grid2Options:LayoutTestRefresh()
			end
		end
	},
	petanchor = {
		type = "select",
		order = 2,
		name = L["Pet Layout Anchor"],
		desc = L["Sets where the pet container is anchored relative to the screen."],
		disabled = petPosDisabled,
		get = function()
			return Grid2Layout.db.profile.petAnchor
		end,
		set = function(_, v)
			Grid2Layout.db.profile.petAnchor = v
			-- Re-express the stored offset against the new anchor from the frame's current on-screen rect
			-- so it stays put visually, mirroring the main-frame Layout Anchor handler above.
			if Grid2Layout.petFrame then
				Grid2Layout:SavePosition(Grid2Layout.petFrame)
			end
			Grid2Layout:RestorePosition()
		end,
		values = {
			["CENTER"] = L["CENTER"],
			["TOP"] = L["TOP"],
			["BOTTOM"] = L["BOTTOM"],
			["LEFT"] = L["LEFT"],
			["RIGHT"] = L["RIGHT"],
			["TOPLEFT"] = L["TOPLEFT"],
			["TOPRIGHT"] = L["TOPRIGHT"],
			["BOTTOMLEFT"] = L["BOTTOMLEFT"],
			["BOTTOMRIGHT"] = L["BOTTOMRIGHT"]
		}
	},
	petposx = {
		type = "range",
		order = 3,
		name = L["Pet Horizontal Position"],
		desc = L["Adjust the horizontal position of the pet container."],
		softMin = -2048,
		softMax = 2048,
		step = 1,
		bigStep = 5,
		disabled = petPosDisabled,
		get = function()
			return floor(Grid2Layout.db.profile.PetPosX + 0.5)
		end,
		set = function(_, v)
			Grid2Layout.db.profile.PetPosX = v
			Grid2Layout:RestorePosition()
		end
	},
	petposy = {
		type = "range",
		order = 4,
		name = L["Pet Vertical Position"],
		desc = L["Adjust the vertical position of the pet container."],
		softMin = -2048,
		softMax = 2048,
		step = 1,
		bigStep = 5,
		disabled = petPosDisabled,
		get = function()
			return floor(Grid2Layout.db.profile.PetPosY + 0.5)
		end,
		set = function(_, v)
			Grid2Layout.db.profile.PetPosY = v
			Grid2Layout:RestorePosition()
		end
	},
	petclamp = {
		type = "toggle",
		order = 5,
		name = L["Pet Clamped to screen"],
		desc = L["Toggle whether to permit moving the pet container off screen."],
		disabled = petPosDisabled,
		get = function()
			return Grid2Layout.db.profile.petClamp
		end,
		set = function()
			local v = not Grid2Layout.db.profile.petClamp
			Grid2Layout.db.profile.petClamp = v
			if Grid2Layout.petFrame then
				Grid2Layout.petFrame:SetClampedToScreen(v)
			end
		end
	},
	petownscale = {
		type = "toggle",
		order = 6,
		name = L["Use a separate pet scale"],
		desc = L["Scale the pet container independently of the main grid."],
		disabled = petPosDisabled,
		get = function()
			return Grid2Layout.db.profile.petOwnScale
		end,
		set = function(_, v)
			Grid2Layout.db.profile.petOwnScale = v
			Grid2Layout:Scale()
		end
	},
	petscale = {
		type = "range",
		order = 7,
		name = L["Pet Scale"],
		desc = L["Adjust the pet container scale."],
		min = 0.5,
		max = 2.0,
		step = 0.05,
		isPercent = true,
		disabled = function()
			return petPosDisabled() or not Grid2Layout.db.profile.petOwnScale
		end,
		get = function()
			return Grid2Layout.db.profile.PetScaleSize
		end,
		set = function(_, v)
			Grid2Layout.db.profile.PetScaleSize = v
			Grid2Layout:Scale()
		end
	},
	petreset = {
		type = "execute",
		width = "half",
		order = 8,
		name = L["Reset"],
		desc = L["Resets the pet container's position and anchor."],
		disabled = petPosDisabled,
		func = function()
			Grid2Layout:ResetPetPosition()
		end
	}
})