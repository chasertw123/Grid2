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
			Grid2Layout:ApplyClickThrough()
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
local function petStyleDisabled()
	return petPosDisabled() or not Grid2Layout.db.profile.petOwnStyle
end
local function petGrowthDisabled()
	return petPosDisabled() or not Grid2Layout.db.profile.petOwnGrowth
end
-- Repaint just the pet container after a style change (it is created lazily; repaint only, no reload).
local function RefreshPetStyle()
	local f = Grid2Layout.petFrame
	if f then
		Grid2Layout:UpdateTextures(f)
		Grid2Layout:UpdateColor(f)
	end
end

Grid2Options:AddGeneralOptions("Pets", "Pet Position", {
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
	},
	petLockHeader = {
		type = "header",
		order = 20,
		name = L["Pet Frame Lock"]
	},
	petownlock = {
		type = "toggle",
		width = "full",
		order = 21,
		name = L["Lock pet frame separately"],
		desc = L["Give the pet container its own lock and click-through instead of following the main grid."],
		disabled = petPosDisabled,
		get = function()
			return Grid2Layout.db.profile.petOwnLock
		end,
		set = function(_, v)
			Grid2Layout.db.profile.petOwnLock = v
			Grid2Layout:ApplyClickThrough()
		end
	},
	petlock = {
		type = "toggle",
		order = 22,
		name = L["Pet frame lock"],
		desc = L["Locks/unlocks the pet container for movement."],
		disabled = function()
			return petPosDisabled() or not Grid2Layout.db.profile.petOwnLock
		end,
		get = function()
			local p = Grid2Layout.db.profile
			local v = p.PetFrameLock
			if v == nil then v = p.FrameLock end
			return v
		end,
		set = function()
			Grid2Layout:PetFrameLock()
		end
	},
	petclickthrough = {
		type = "toggle",
		order = 23,
		name = L["Click through the pet frame"],
		desc = L["Allows mouse click through the pet container."],
		disabled = function()
			local p = Grid2Layout.db.profile
			local fl = p.PetFrameLock
			if fl == nil then fl = p.FrameLock end
			return petPosDisabled() or not p.petOwnLock or not fl
		end,
		get = function()
			local p = Grid2Layout.db.profile
			local v = p.PetClickThrough
			if v == nil then v = p.ClickThrough end
			return v
		end,
		set = function()
			local p = Grid2Layout.db.profile
			local cur = p.PetClickThrough
			if cur == nil then cur = p.ClickThrough end
			p.PetClickThrough = not cur
			Grid2Layout:ApplyClickThrough()
		end
	},
	petStyleHeader = {
		type = "header",
		order = 40,
		name = L["Pet Container Style"]
	},
	petownstyle = {
		type = "toggle",
		width = "full",
		order = 41,
		name = L["Use a separate pet style"],
		desc = L["Give the pet container its own background/border textures and colors instead of the main grid's."],
		disabled = petPosDisabled,
		get = function()
			return Grid2Layout.db.profile.petOwnStyle
		end,
		set = function(_, v)
			Grid2Layout.db.profile.petOwnStyle = v
			RefreshPetStyle()
		end
	},
	petBackgroundTexture = {
		type = "select",
		dialogControl = "LSM30_Background",
		order = 42,
		name = L["Background Texture"],
		desc = L["Adjust the background texture."],
		disabled = petStyleDisabled,
		get = function()
			local p = Grid2Layout.db.profile
			return p.PetBackgroundTexture or p.BackgroundTexture or "None"
		end,
		set = function(_, v)
			Grid2Layout.db.profile.PetBackgroundTexture = v
			RefreshPetStyle()
		end,
		values = AceGUIWidgetLSMlists.background
	},
	petBorderTexture = {
		type = "select",
		dialogControl = "LSM30_Border",
		order = 43,
		name = L["Border Texture"],
		desc = L["Adjust the border texture."],
		disabled = petStyleDisabled,
		get = function()
			local p = Grid2Layout.db.profile
			return p.PetBorderTexture or p.BorderTexture or "Grid2 Flat"
		end,
		set = function(_, v)
			Grid2Layout.db.profile.PetBorderTexture = v
			RefreshPetStyle()
		end,
		values = AceGUIWidgetLSMlists.border
	},
	petBackground = {
		type = "color",
		order = 44,
		name = L["Background Color"],
		desc = L["Adjust background color and alpha."],
		hasAlpha = true,
		disabled = petStyleDisabled,
		get = function()
			local p = Grid2Layout.db.profile
			return p.PetBackgroundR or p.BackgroundR, p.PetBackgroundG or p.BackgroundG, p.PetBackgroundB or p.BackgroundB, p.PetBackgroundA or p.BackgroundA
		end,
		set = function(_, r, g, b, a)
			local p = Grid2Layout.db.profile
			p.PetBackgroundR, p.PetBackgroundG, p.PetBackgroundB, p.PetBackgroundA = r, g, b, a
			RefreshPetStyle()
		end
	},
	petBorder = {
		type = "color",
		order = 45,
		name = L["Border Color"],
		desc = L["Adjust border color and alpha."],
		hasAlpha = true,
		disabled = petStyleDisabled,
		get = function()
			local p = Grid2Layout.db.profile
			return p.PetBorderR or p.BorderR, p.PetBorderG or p.BorderG, p.PetBorderB or p.BorderB, p.PetBorderA or p.BorderA
		end,
		set = function(_, r, g, b, a)
			local p = Grid2Layout.db.profile
			p.PetBorderR, p.PetBorderG, p.PetBorderB, p.PetBorderA = r, g, b, a
			RefreshPetStyle()
		end
	},
	petBackgroundTile = {
		type = "toggle",
		order = 46,
		name = L["Tile"],
		desc = L["Tile the background texture."],
		disabled = petStyleDisabled,
		get = function()
			local p = Grid2Layout.db.profile
			local v = p.PetBackgroundTile
			if v == nil then v = p.BackgroundTile end
			return v
		end,
		set = function(_, v)
			Grid2Layout.db.profile.PetBackgroundTile = v
			RefreshPetStyle()
		end
	},
	petBackgroundTileSize = {
		type = "range",
		order = 47,
		name = L["Tile size"],
		desc = L["The size of the texture pattern."],
		min = 0,
		max = floor(GetScreenWidth()),
		step = 1,
		disabled = petStyleDisabled,
		get = function()
			local p = Grid2Layout.db.profile
			return p.PetBackgroundTileSize or p.BackgroundTileSize
		end,
		set = function(_, v)
			Grid2Layout.db.profile.PetBackgroundTileSize = v
			RefreshPetStyle()
		end
	},
	petGrowthHeader = {
		type = "header",
		order = 60,
		name = L["Pet Growth"]
	},
	petowngrowth = {
		type = "toggle",
		width = "full",
		order = 61,
		name = L["Use separate pet growth"],
		desc = L["Let pet groups grow in their own direction/anchor instead of following the main grid."],
		disabled = petPosDisabled,
		get = function()
			return Grid2Layout.db.profile.petOwnGrowth
		end,
		set = function(_, v)
			Grid2Layout.db.profile.petOwnGrowth = v
			Grid2Layout:ReloadLayout()
			if Grid2Options.LayoutTestRefresh then
				Grid2Options:LayoutTestRefresh()
			end
		end
	},
	petHorizontal = {
		type = "toggle",
		order = 62,
		name = L["Horizontal groups"],
		desc = L["Switch between horzontal/vertical groups."],
		disabled = petGrowthDisabled,
		get = function()
			local p = Grid2Layout.db.profile
			local h = p.petHorizontal
			if h == nil then h = p.horizontal end
			return h
		end,
		set = function(_, v)
			Grid2Layout.db.profile.petHorizontal = v
			Grid2Layout:ReloadLayout()
			if Grid2Options.LayoutTestRefresh then
				Grid2Options:LayoutTestRefresh()
			end
		end
	},
	petGroupAnchor = {
		type = "select",
		order = 63,
		name = L["Group Anchor"],
		desc = L["Sets where groups are anchored relative to the layout frame."],
		disabled = petGrowthDisabled,
		get = function()
			local p = Grid2Layout.db.profile
			return p.petGroupAnchor or p.groupAnchor
		end,
		set = function(_, v)
			Grid2Layout.db.profile.petGroupAnchor = v
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
	petPadding = {
		type = "range",
		order = 64,
		name = L["Padding"],
		desc = L["Adjust frame padding."],
		min = 0,
		max = 20,
		step = 1,
		disabled = petGrowthDisabled,
		get = function()
			local p = Grid2Layout.db.profile
			return p.petPadding or p.Padding
		end,
		set = function(_, v)
			Grid2Layout.db.profile.petPadding = v
			Grid2Layout:ReloadLayout()
		end
	},
	petSpacing = {
		type = "range",
		order = 65,
		name = L["Spacing"],
		desc = L["Adjust frame spacing."],
		min = 0,
		max = 25,
		step = 1,
		disabled = petGrowthDisabled,
		get = function()
			local p = Grid2Layout.db.profile
			return p.petSpacing or p.Spacing
		end,
		set = function(_, v)
			Grid2Layout.db.profile.petSpacing = v
			Grid2Layout:ReloadLayout()
		end
	}
})

-- ============================ Party/raid sorting ============================
-- Appended into the existing "Layout Settings" section (AddGeneralOptions merges args). Drives the engine in
-- Grid2/GridPartySort.lua via profile.sortBy / sortReverse / sortRoleOrder; every setter routes through
-- ReloadLayout (itself combat-queued), which re-applies the sort after rebuilding the layout.
local ROLE_VALUES = { TANK = L["Tank"], HEALER = L["Healer"], DAMAGER = L["DPS"] }
-- Same lazily-created, profile-owned role order the engine uses (avoids AceDB nested-default aliasing).
local function GetRoleOrder()
	local p = Grid2Layout.db.profile
	if type(p.sortRoleOrder) ~= "table" or #p.sortRoleOrder ~= 3 then
		p.sortRoleOrder = {"TANK", "HEALER", "DAMAGER"}
	end
	return p.sortRoleOrder
end
local function sortDisabled() return (Grid2Layout.db.profile.sortBy or "NONE") == "NONE" end
local function roleDisabled() return (Grid2Layout.db.profile.sortBy or "NONE") ~= "ROLE" end

local sort_o = order_layout + 8  -- after Grow Direction / Frame lock, before the display/anchor sections
local sortingOptions = {
	sortingHeader = { type = "header", order = sort_o, name = L["Sorting"] },
	sortBy = {
		type = "select",
		order = sort_o + 0.1,
		name = L["Sort By"],
		desc = L["Order units in the current layout by name or by role (tank/healer/dps)."],
		values = { NONE = L["Layout Default"], NAME = L["Name"], ROLE = L["Role"] },
		get = function() return Grid2Layout.db.profile.sortBy or "NONE" end,
		set = function(_, v)
			Grid2Layout.db.profile.sortBy = v
			Grid2Layout:ReloadLayout()
			if Grid2Options.LayoutTestRefresh then Grid2Options:LayoutTestRefresh() end
		end
	},
	sortReverse = {
		type = "toggle",
		order = sort_o + 0.2,
		name = L["Reverse order"],
		desc = L["Invert the chosen sort order."],
		disabled = sortDisabled,
		get = function() return Grid2Layout.db.profile.sortReverse end,
		set = function(_, v)
			Grid2Layout.db.profile.sortReverse = v
			Grid2Layout:ReloadLayout()
			if Grid2Options.LayoutTestRefresh then Grid2Options:LayoutTestRefresh() end
		end
	}
}
-- Three "Role Order" dropdowns. Picking a role in a slot swaps it with wherever that role currently sits, so
-- the stored array stays a valid permutation of the three roles (no dupes, none missing) with no validation UI.
for slot = 1, 3 do
	sortingOptions["roleSlot" .. slot] = {
		type = "select",
		order = sort_o + 0.2 + slot * 0.1,
		width = "half",
		name = slot == 1 and L["Role Order"] or " ",
		desc = L["Configure the tank/healer/dps ordering used by Role sort."],
		values = ROLE_VALUES,
		disabled = roleDisabled,
		get = function() return GetRoleOrder()[slot] end,
		set = function(_, v)
			local order = GetRoleOrder()
			local cur
			for i = 1, #order do if order[i] == v then cur = i break end end
			if cur then order[cur], order[slot] = order[slot], v end  -- swap => always a valid permutation
			Grid2Layout:ReloadLayout()
			if Grid2Options.LayoutTestRefresh then Grid2Options:LayoutTestRefresh() end
		end
	}
end
Grid2Options:AddGeneralOptions("General", "Layout Settings", sortingOptions)

-- ============================ Per-Layout Overrides ============================
-- Each layout can optionally override its position/scale/geometry (main + pet). A dropdown picks WHICH layout
-- to configure; a toggle enables that layout's override; the controls read/write THAT layout's override via the
-- engine resolver (Grid2Layout:LayoutValue / SetLayoutValue). Editing a non-active layout is a pure data write
-- (it applies when that layout next loads); editing the active layout drives a live refresh. The selected
-- layout is a module-local, never stored in the profile.
local floor = math.floor
local OV_ANCHOR = {
	["CENTER"] = L["CENTER"], ["TOP"] = L["TOP"], ["BOTTOM"] = L["BOTTOM"], ["LEFT"] = L["LEFT"], ["RIGHT"] = L["RIGHT"],
	["TOPLEFT"] = L["TOPLEFT"], ["TOPRIGHT"] = L["TOPRIGHT"], ["BOTTOMLEFT"] = L["BOTTOMLEFT"], ["BOTTOMRIGHT"] = L["BOTTOMRIGHT"],
}
local OV_GROUPANCHOR = {
	["TOPLEFT"] = L["TOPLEFT"], ["TOPRIGHT"] = L["TOPRIGHT"], ["BOTTOMLEFT"] = L["BOTTOMLEFT"], ["BOTTOMRIGHT"] = L["BOTTOMRIGHT"],
}
local selName  -- module-local: which layout the UI is currently configuring
local function Sel() return selName or Grid2Layout.layoutName or "solo" end
local function Ov() local lo = Grid2Layout.db.profile.layoutOverrides; return lo and lo[Sel()] end
local function OvOff() local o = Ov(); return not (o and o.enabled) end
local function IsActive(n) return n == (Grid2Layout.layoutName or "solo") end
-- pet override controls only do anything when the matching GLOBAL pet toggle is on, so gate them on both.
local function petPosGate() return OvOff() or not Grid2Layout.db.profile.petEnabled end
local function petScaleGate() local p = Grid2Layout.db.profile; return OvOff() or not (p.petEnabled and p.petOwnScale) end
local function petGeoGate() local p = Grid2Layout.db.profile; return OvOff() or not (p.petEnabled and p.petOwnGrowth) end

local function EnableOverride(n, on)
	local p = Grid2Layout.db.profile
	p.layoutOverrides = p.layoutOverrides or {}
	local o = p.layoutOverrides[n]
	if on then
		if not o then o = {}; p.layoutOverrides[n] = o end   -- lazy per-name table (no AceDB shared default)
		o.enabled = true
	elseif o then
		o.enabled = false   -- keep stored values so re-enabling restores the user's tuning
	end
	if IsActive(n) then Grid2Layout:Scale(); Grid2Layout:ReloadLayout() end
	if Grid2Options.LayoutTestRefresh then Grid2Options:LayoutTestRefresh() end
end

-- get: the selected layout's resolved value (override, else global fallback) so sliders always show a number.
local function ovGet(key, xf)
	return function() local v = Grid2Layout:LayoutValue(Sel(), key); if xf then return xf(v) end return v end
end
-- pet geometry get: fall back pet -> main so the inherited value shows even when the pet key is unset.
local function ovGetPet(petKey, mainKey, xf)
	return function()
		local n = Sel()
		local v = Grid2Layout:LayoutValue(n, petKey)
		if v == nil then v = Grid2Layout:LayoutValue(n, mainKey) end
		if xf then return xf(v) end return v
	end
end
-- set: write to the selected layout; live-refresh only when it is the active layout.
local function ovSet(key, refresh)
	return function(_, v)
		local n = Sel()
		Grid2Layout:SetLayoutValue(n, key, v)
		if IsActive(n) then refresh() end
		if Grid2Options.LayoutTestRefresh then Grid2Options:LayoutTestRefresh() end
	end
end
-- anchor set: re-express the stored offset against the new anchor (active layout only; needs the live rect).
local function ovSetAnchor(key, getFrame)
	return function(_, v)
		local n = Sel()
		Grid2Layout:SetLayoutValue(n, key, v)
		if IsActive(n) then
			local f = getFrame()
			if f then Grid2Layout:SavePosition(f) end
			Grid2Layout:RestorePosition()
		end
		if Grid2Options.LayoutTestRefresh then Grid2Options:LayoutTestRefresh() end
	end
end
local function rInt(v) return floor(v + 0.5) end
local function rPos() Grid2Layout:RestorePosition() end
local function rScl() Grid2Layout:Scale() end
local function rGeo() Grid2Layout:ReloadLayout() end

Grid2Options:AddGeneralOptions("General", "Per-Layout Overrides", {
	configureLayout = {
		type = "select", order = 1, name = L["Configure layout"],
		desc = L["Pick which layout's settings to view and edit below."],
		values = function() local t = {} for n in pairs(Grid2Layout.layoutSettings) do t[n] = n end return t end,
		get = function() return Sel() end,
		set = function(_, v) selName = v end
	},
	useOverride = {
		type = "toggle", order = 2, width = "full", name = L["Use separate settings for this layout"],
		desc = L["When on, this layout uses its own position/scale/geometry below instead of the global settings."],
		get = function() local o = Ov() return o and o.enabled end,
		set = function(_, v) EnableOverride(Sel(), v) end
	},
	ovAnchor = { type = "select", order = 10, name = L["Layout Anchor"], disabled = OvOff, values = OV_ANCHOR,
		get = ovGet("anchor"), set = ovSetAnchor("anchor", function() return Grid2Layout.frame end) },
	ovPosX = { type = "range", order = 11, name = L["Horizontal Position"], softMin = -2048, softMax = 2048, step = 1, bigStep = 5,
		disabled = OvOff, get = ovGet("PosX", rInt), set = ovSet("PosX", rPos) },
	ovPosY = { type = "range", order = 12, name = L["Vertical Position"], softMin = -2048, softMax = 2048, step = 1, bigStep = 5,
		disabled = OvOff, get = ovGet("PosY", rInt), set = ovSet("PosY", rPos) },
	ovScale = { type = "range", order = 20, name = L["Scale"], min = 0.5, max = 2.0, step = 0.05, isPercent = true, width = "double",
		disabled = OvOff, get = ovGet("ScaleSize"), set = ovSet("ScaleSize", rScl) },
	ovHorizontal = { type = "toggle", order = 30, name = L["Horizontal groups"], disabled = OvOff,
		get = ovGet("horizontal"), set = ovSet("horizontal", rGeo) },
	ovGroupAnchor = { type = "select", order = 31, name = L["Group Anchor"], disabled = OvOff, values = OV_GROUPANCHOR,
		get = ovGet("groupAnchor"), set = ovSet("groupAnchor", rGeo) },
	ovPadding = { type = "range", order = 32, name = L["Padding"], min = 0, max = 20, step = 1, disabled = OvOff,
		get = ovGet("Padding"), set = ovSet("Padding", rGeo) },
	ovSpacing = { type = "range", order = 33, name = L["Spacing"], min = 0, max = 25, step = 1, disabled = OvOff,
		get = ovGet("Spacing"), set = ovSet("Spacing", rGeo) },
	ovPetHeader = { type = "header", order = 39, name = L["Pet Frames"] },
	ovPetAnchor = { type = "select", order = 40, name = L["Pet Layout Anchor"], disabled = petPosGate, values = OV_ANCHOR,
		get = ovGet("petAnchor"), set = ovSetAnchor("petAnchor", function() return Grid2Layout.petFrame end) },
	ovPetPosX = { type = "range", order = 41, name = L["Pet Horizontal Position"], softMin = -2048, softMax = 2048, step = 1, bigStep = 5,
		disabled = petPosGate, get = ovGet("PetPosX", rInt), set = ovSet("PetPosX", rPos) },
	ovPetPosY = { type = "range", order = 42, name = L["Pet Vertical Position"], softMin = -2048, softMax = 2048, step = 1, bigStep = 5,
		disabled = petPosGate, get = ovGet("PetPosY", rInt), set = ovSet("PetPosY", rPos) },
	ovPetScale = { type = "range", order = 43, name = L["Pet Scale"], min = 0.5, max = 2.0, step = 0.05, isPercent = true,
		disabled = petScaleGate, get = ovGet("PetScaleSize"), set = ovSet("PetScaleSize", rScl) },
	ovPetHorizontal = { type = "toggle", order = 44, name = L["Horizontal groups"], disabled = petGeoGate,
		get = function() local n = Sel() local h = Grid2Layout:LayoutValue(n, "petHorizontal") if h == nil then h = Grid2Layout:LayoutValue(n, "horizontal") end return h end,
		set = ovSet("petHorizontal", rGeo) },
	ovPetGroupAnchor = { type = "select", order = 45, name = L["Group Anchor"], disabled = petGeoGate, values = OV_GROUPANCHOR,
		get = ovGetPet("petGroupAnchor", "groupAnchor"), set = ovSet("petGroupAnchor", rGeo) },
	ovPetPadding = { type = "range", order = 46, name = L["Padding"], min = 0, max = 20, step = 1, disabled = petGeoGate,
		get = ovGetPet("petPadding", "Padding"), set = ovSet("petPadding", rGeo) },
	ovPetSpacing = { type = "range", order = 47, name = L["Spacing"], min = 0, max = 25, step = 1, disabled = petGeoGate,
		get = ovGetPet("petSpacing", "Spacing"), set = ovSet("petSpacing", rGeo) },
})