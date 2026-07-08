--[[ Layouts test mode ]] --
-- Preview renderer for the layout selector. Draws non-secure placeholder frames that mirror the REAL config:
-- real unit-frame colours/texture/size, and -- when the pet container feature is on -- pet groups as a SECOND
-- grid anchored at the real pet container. Only this file changes; frames are plain (non-secure), no taint.
local Grid2 = Grid2
local Grid2Layout = Grid2:GetModule("Grid2Layout")
local Grid2Frame  = Grid2:GetModule("Grid2Frame")

local max = math.max
local pairs, ipairs, unpack = pairs, ipairs, unpack

local layoutName  -- name of the layout being previewed (nil => test off)

-- One descriptor per preview grid. mainGrid -> Grid2Layout.frame; petGrid -> Grid2Layout.petFrame (only when
-- the pet container feature is enabled). Each owns pooled frames that persist across loads, the per-column
-- membership rebuilt every refresh, and the container scale saved on first render.
local mainGrid = { isPet = false, frames = {}, cols = {}, colCount = 0, rowCount = 0, active = false }
local petGrid  = { isPet = true,  frames = {}, cols = {}, colCount = 0, rowCount = 0, active = false }
local grids = { mainGrid, petGrid }
local TINT = 0.25  -- strength of the per-group readability tint over the real content colour (0 = pure real)

-- Toggle every real header (main + pet + spacer). Unchanged.
function Grid2Layout:ShowFrames(enabled)
	for type, headers in pairs(self.groups) do
		for i = 1, self.indexes[type] do
			local g = headers[i]
			if enabled then g:Show() else g:Hide() end
		end
	end
end

-- Growth resolver copied from Grid2/GridLayout.lua GetGrowth (a file-local there, not exported).
local function GetGrowth(p, isPet)
	if isPet and p.petEnabled and p.petOwnGrowth then
		local h = p.petHorizontal
		if h == nil then h = p.horizontal end
		return h, p.petGroupAnchor or p.groupAnchor, p.petPadding or p.Padding, p.petSpacing or p.Spacing
	end
	return p.horizontal, p.groupAnchor, p.Padding, p.Spacing
end

-- Real unit-frame appearance, mirroring GridFrame.lua UpdatePetProfile: a pet frame reads db.profile.pet.<key>
-- when the pet override is on (each key falling back to the player value), else it is a player frame. Returns
-- texture path, ring colour (frameColor), content colour (frameContentColor) and the inner-border inset -- the
-- exact values GridFramePrototype:Layout paints. Outer edge is MAIN for both grids because the real engine
-- shares one frameBackdrop across player and pet frames.
local function GetFrameStyle(isPet)
	local fp  = Grid2Frame.db.profile
	local pet = isPet and fp.pet
	if pet and pet.enabled then
		return Grid2:MediaFetch("statusbar", pet.frameTexture or fp.frameTexture, "Gradient"),
			pet.frameColor or fp.frameColor,
			pet.frameContentColor or fp.frameContentColor,
			((pet.frameBorder or fp.frameBorder) + (pet.frameBorderDistance or fp.frameBorderDistance)) * 2
	end
	return Grid2:MediaFetch("statusbar", fp.frameTexture, "Gradient"),
		fp.frameColor, fp.frameContentColor, (fp.frameBorder + fp.frameBorderDistance) * 2
end

-- Shared outer backdrop, rebuilt each refresh from the MAIN profile (same border tex/size the real
-- frameBackdrop shares). bgFile=WHITE8X8 is coloured per-cell with frameColor.
local sharedBackdrop = { bgFile = [[Interface\Buttons\WHITE8X8]], tile = true, tileSize = 16,
	insets = { left = 0, right = 0, top = 0, bottom = 0 } }
local function UpdateSharedBackdrop()
	local fp = Grid2Frame.db.profile
	local e = fp.frameBorder
	sharedBackdrop.edgeFile = Grid2:MediaFetch("border", fp.frameBorderTexture, "Grid2 Flat")
	sharedBackdrop.edgeSize = e
	local ins = sharedBackdrop.insets
	ins.left, ins.right, ins.top, ins.bottom = e, e, e, e
end

-- Pooled frame #i for a grid, parented to that grid's container. Each carries a child "content" texture that
-- reproduces the real inner container; the frame's own backdrop reproduces the outer frame (frameColor ring).
local function LayoutGetTestFrame(grid, i)
	local pool = grid.frames
	local f = pool[i]
	if not f then
		f = CreateFrame("Frame", nil, grid.container)
		local t = f:CreateTexture(nil, "ARTWORK")
		t:SetPoint("CENTER", f, "CENTER")
		f.content = t
		pool[i] = f
	end
	f:SetBackdrop(sharedBackdrop)
	return f
end

-- Vector maths, unchanged from the original.
local LayoutGetVectors
do
	local vectors = {
		["TOPLEFT"]     = {1, 0, 0, 1, 0, 0},
		["TOPRIGHT"]    = {-1, 0, 0, 1, 1, 0},
		["BOTTOMLEFT"]  = {1, 0, 0, -1, 0, 1},
		["BOTTOMRIGHT"] = {-1, 0, 0, -1, 1, 1}
	}
	LayoutGetVectors = function(anchor, horizontal, ox, oy, w, h, cols, rows)
		local ux, uy, vx, vy, px, py = unpack(vectors[anchor])
		if horizontal then
			return vx * w, vy * h, ux * w, uy * h, px * (rows - 1) * w + ox, py * (cols - 1) * h + oy, rows, cols
		else
			return ux * w, uy * h, vx * w, vy * h, px * (cols - 1) * w + ox, py * (rows - 1) * h + oy, cols, rows
		end
	end
end

-- Lazily save a container's scale and apply the previewed layout's scale (main formula, or the pet formula for
-- the pet frame). Idempotent on savedScale so later refreshes don't churn. Save/restore position keeps it put.
local function EnsureScaled(grid)
	if grid.savedScale ~= nil then return end
	local f = grid.container
	if not f then return end
	local p = Grid2Layout.db.profile
	local ls = p.layoutScales[layoutName] or 1
	local base = p.ScaleSize * ls
	local scale = grid.isPet and (p.petOwnScale and (p.PetScaleSize * ls) or base) or base
	grid.savedScale = f:GetScale()
	Grid2Layout:SavePosition(f)
	f:SetScale(scale)
	Grid2Layout:RestoreFramePosition(f)
end

local function RestoreScale(grid)
	if grid.savedScale == nil then return end
	local f = grid.container
	if f then
		Grid2Layout:SavePosition(f)
		f:SetScale(grid.savedScale)
		Grid2Layout:RestoreFramePosition(f)
	end
	grid.savedScale = nil
end

-- Column membership per grid. Pet groups form the separate pet grid only when the feature is enabled AND the
-- pet container exists; otherwise they fold into the main grid exactly as before. Rebuilt every refresh so a
-- petEnabled toggle (which only triggers a refresh, not a reload) re-partitions correctly.
local colorsTable = { partypet = { r = 0, g = 1, b = 0 }, raidpet = { r = 0, g = 1, b = 0 } }
local function LayoutBuild()
	mainGrid.active, petGrid.active = false, false
	mainGrid.colCount, mainGrid.rowCount, mainGrid.col = 0, 0, 1
	petGrid.colCount,  petGrid.rowCount,  petGrid.col  = 0, 0, 1
	mainGrid.container = Grid2Layout.frame
	petGrid.container  = Grid2Layout.petFrame

	local layout = Grid2Layout.layoutSettings[layoutName]
	if not layout then return end
	local p = Grid2Layout.db.profile
	local petSeparate = p.petEnabled and Grid2Layout.petFrame ~= nil
	local defaults = layout.defaults or {}

	for i, l in ipairs(layout) do
		local ptype    = l.type
		local isPet    = ptype == "raidpet" or ptype == "partypet"
		local isSpacer = ptype == "spacer"
		local grid     = (petSeparate and isPet) and petGrid or mainGrid
		local unitPerColumn = l.unitsPerColumn or defaults.unitsPerColumn or 5  -- was defaults.unitPerColumn (typo)
		local maxColumns    = l.maxColumns    or defaults.maxColumns    or 1
		grid.colCount = grid.colCount + maxColumns
		grid.rowCount = max(grid.rowCount, unitPerColumn)
		local c = colorsTable[ptype] or RAID_CLASS_COLORS[CLASS_SORT_ORDER[((i - 1) % #CLASS_SORT_ORDER) + 1]]
		for _ = 1, maxColumns do
			local col = grid.cols[grid.col] or {}
			col.spacer = isSpacer
			col.tr, col.tg, col.tb = c.r, c.g, c.b
			grid.cols[grid.col] = col
			grid.col = grid.col + 1
		end
	end
	mainGrid.active = mainGrid.colCount > 0
	petGrid.active  = petSeparate and petGrid.colCount > 0
end

-- Render one grid into its container with its OWN growth, frame size, style and colours.
local function RenderGrid(grid)
	local f0 = grid.container
	if not (grid.active and f0) then
		local pool = grid.frames
		for j = 1, #pool do pool[j]:Hide() end
		RestoreScale(grid)  -- hand the container back its real scale when we stop previewing into it
		return
	end
	EnsureScaled(grid)

	local p = Grid2Layout.db.profile
	local horizontal, groupAnchor, Padding, Spacing = GetGrowth(p, grid.isPet)
	local width, height = Grid2Frame:GetFrameSize(grid.isPet)
	local texture, fc, cc, inset = GetFrameStyle(grid.isPet)
	local iw = max(width  - inset, 1)
	local ih = max(height - inset, 1)
	local frameLevel = f0:GetFrameLevel() + 1

	local ux, uy, vx, vy, px, py, realCols, realRows =
		LayoutGetVectors(groupAnchor, horizontal, Spacing, Spacing, width + Padding, height + Padding, grid.colCount, grid.rowCount)

	local i = 1
	for nx = 0, grid.colCount - 1 do
		local col = grid.cols[nx + 1]
		for ny = 0, grid.rowCount - 1 do
			local frame = LayoutGetTestFrame(grid, i)
			if col.spacer then
				frame:Hide()
			else
				frame:ClearAllPoints()
				frame:SetPoint("TOPLEFT", f0, "TOPLEFT", nx * ux + ny * vx + px, -(nx * uy + ny * vy + py))
				frame:SetSize(width, height)
				frame:SetFrameLevel(frameLevel)
				frame:SetBackdropColor(fc.r, fc.g, fc.b, fc.a)  -- outer ring == real frameColor
				frame:SetBackdropBorderColor(0, 0, 0, 0)        -- resting edge (no border indicator active)
				local content = frame.content
				content:SetTexture(texture)
				content:SetSize(iw, ih)
				content:SetVertexColor(
					cc.r * (1 - TINT) + col.tr * TINT,
					cc.g * (1 - TINT) + col.tg * TINT,
					cc.b * (1 - TINT) + col.tb * TINT, cc.a or 1)
				frame:Show()
			end
			i = i + 1
		end
	end
	local pool = grid.frames  -- hide leftovers from a previous, larger render of this grid
	for j = i, #pool do pool[j]:Hide() end

	f0:SetSize(Spacing * 2 + realCols * (width + Padding) - Padding,
	           Spacing * 2 + realRows * (height + Padding) - Padding)
end

local function LayoutHide(restoreRealLayout)
	if not layoutName then return end
	for _, grid in ipairs(grids) do
		local pool = grid.frames
		for j = 1, #pool do pool[j]:Hide() end
		RestoreScale(grid)
	end
	if restoreRealLayout then
		layoutName = nil
		Grid2Layout:ShowFrames(true)
		Grid2Layout:UpdateSize()
		-- restore the pet container's real visibility (the preview may have hidden it). Mirrors the pet branch
		-- of CheckVisibility but reads the main frame's shown state instead of partyType.
		local pf = Grid2Layout.petFrame
		if pf then
			local pp = Grid2Layout.db.profile
			local hasPets = (Grid2Layout.indexes.raidpet + Grid2Layout.indexes.partypet) > 0
			if Grid2Layout.frame:IsShown() and pp.petEnabled and hasPets then pf:Show() else pf:Hide() end
		end
	end
end

local function LayoutRefresh()
	if not layoutName then return end
	Grid2Layout:ShowFrames(false)  -- hide all real headers behind the preview
	UpdateSharedBackdrop()         -- pick up live border texture/size
	LayoutBuild()                  -- (re)partition main vs pet from the live petEnabled state
	RenderGrid(mainGrid)
	RenderGrid(petGrid)
	local pf = Grid2Layout.petFrame  -- own the pet container's visibility: shown only if we drew pets into it
	if pf then
		if petGrid.active then pf:Show() else pf:Hide() end
	end
end

local function LayoutLoad(name)
	if layoutName then LayoutHide(false) end  -- tear down current preview (keeps real headers hidden)
	if not Grid2Layout.layoutSettings[name] then return end
	layoutName = name
	return true  -- geometry/scale/render all happen in the LayoutRefresh that follows
end

local function LayoutEnable(self, name)
	if name and name ~= layoutName then
		if LayoutLoad(name) then
			LayoutRefresh()
			return true
		end
	else
		LayoutHide(true)
		return false
	end
end

Grid2Options.LayoutTestEnable = LayoutEnable
Grid2Options.LayoutTestRefresh = LayoutRefresh
