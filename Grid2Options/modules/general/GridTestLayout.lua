--[[ Layouts test mode ]] --
-- Preview renderer for the layout selector. Builds REAL Grid2 unit frames (Grid2Frame.Prototype) that
-- self-render EVERY configured indicator for a live unit, so the preview looks exactly like the real frames
-- with the user's indicators + settings. Frames are plain (non-secure) and are deliberately NOT registered
-- with Grid2Frame, NOT added to ClickCastFrames, carry NO GridFrameEvents scripts and never call
-- Grid2:SetFrameUnit -- so they are invisible to the live engine and cannot disturb real frames/statuses.
-- Only this file changes.
local Grid2 = Grid2
local Grid2Layout = Grid2:GetModule("Grid2Layout")
local Grid2Frame  = Grid2:GetModule("Grid2Frame")

local max = math.max
local format = string.format
local wipe = wipe
local pairs, ipairs, unpack = pairs, ipairs, unpack
local UnitExists = UnitExists

local layoutName  -- name of the layout being previewed (nil => test off)

-- Resolve a setting for the PREVIEWED layout through the engine's read-only per-layout override resolver, so the
-- preview reflects that layout's own position/scale/geometry overrides. Reads only -- never persists anything.
local function LV(key) return Grid2Layout:LayoutValue(layoutName, key) end

-- One descriptor per preview grid. mainGrid -> Grid2Layout.frame; petGrid -> Grid2Layout.petFrame (only when
-- the pet container feature is enabled). Each owns pooled REAL frames that persist across loads, the per-column
-- membership rebuilt every refresh, and the container scale saved on first render. headerId seeds a unique,
-- pattern-matching frame name (see AcquireFrame) so the icon/cooldown indicators do not crash on a nil name.
local mainGrid = { isPet = false, headerId = 901, frames = {}, cols = {}, colCount = 0, rowCount = 0, active = false }
local petGrid  = { isPet = true,  headerId = 902, frames = {}, cols = {}, colCount = 0, rowCount = 0, active = false }
local grids = { mainGrid, petGrid }

-- Toggle every real header (main + pet + spacer). Unchanged.
function Grid2Layout:ShowFrames(enabled)
	for type, headers in pairs(self.groups) do
		for i = 1, self.indexes[type] do
			local g = headers[i]
			if enabled then g:Show() else g:Hide() end
		end
	end
end

-- Growth resolver mirroring Grid2/GridLayout.lua GetGrowth, but resolving each value for the PREVIEWED layout
-- via LV (read-only per-layout override lookup). Pet MODE gates (petEnabled/petOwnGrowth) stay global.
local function GetGrowth(p, isPet)
	if isPet and p.petEnabled and p.petOwnGrowth then
		local h = LV("petHorizontal")
		if h == nil then h = LV("horizontal") end
		return h, LV("petGroupAnchor") or LV("groupAnchor"), LV("petPadding") or LV("Padding"), LV("petSpacing") or LV("Spacing")
	end
	return LV("horizontal"), LV("groupAnchor"), LV("Padding"), LV("Spacing")
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
-- the pet frame). Idempotent on savedScale. Re-anchors with RestoreFramePosition, which only READS the stored
-- PosX/PosY -- the preview must NEVER call SavePosition: that recomputes position from the (scaled/resized)
-- preview rect and PERSISTS it, permanently changing the user's saved layout position. Testing a layout must
-- never mutate settings.
local function EnsureScaled(grid)
	if grid.savedScale ~= nil then return end
	local f = grid.container
	if not f then return end
	local p = Grid2Layout.db.profile
	local ls = p.layoutScales[layoutName] or 1
	local base = LV("ScaleSize") * ls
	local scale = grid.isPet and (p.petOwnScale and (LV("PetScaleSize") * ls) or base) or base
	grid.savedScale = f:GetScale()
	f:SetScale(scale)
	Grid2Layout:RestoreFramePosition(f, layoutName)   -- read-only re-anchor at the previewed layout's position
end

local function RestoreScale(grid)
	if grid.savedScale == nil then return end
	local f = grid.container
	if f then
		f:SetScale(grid.savedScale)
		Grid2Layout:RestoreFramePosition(f)   -- read-only re-anchor back at the original scale
	end
	grid.savedScale = nil
end

-- Column membership per grid. Pet groups form the separate pet grid only when the feature is enabled AND the
-- pet container exists; otherwise they fold into the main grid. Rebuilt every refresh. Unchanged.
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
		local unitPerColumn = l.unitsPerColumn or defaults.unitsPerColumn or 5
		local maxColumns    = l.maxColumns    or defaults.maxColumns    or 1
		grid.colCount = grid.colCount + maxColumns
		grid.rowCount = max(grid.rowCount, unitPerColumn)
		for _ = 1, maxColumns do
			local col = grid.cols[grid.col] or {}
			col.spacer = isSpacer
			grid.cols[grid.col] = col
			grid.col = grid.col + 1
		end
	end
	mainGrid.active = mainGrid.colCount > 0
	petGrid.active  = petSeparate and petGrid.colCount > 0
end

-- ============================ REAL-FRAME construction & rendering ============================

-- Existing unit tokens, split main vs pet, cycled so every filled cell shows a real unit. Rebuilt per refresh.
local unitPool = { [false] = {}, [true] = {} }
local function BuildUnitPools()
	local main, pet = unitPool[false], unitPool[true]
	wipe(main); wipe(pet)
	if UnitExists("player") then main[#main + 1] = "player" end
	for i = 1, 4  do local u = "party" .. i; if UnitExists(u) then main[#main + 1] = u end end
	for i = 1, 40 do local u = "raid"  .. i; if UnitExists(u) then main[#main + 1] = u end end
	if UnitExists("pet") then pet[#pet + 1] = "pet" end
	for i = 1, 4  do local u = "partypet" .. i; if UnitExists(u) then pet[#pet + 1] = u end end
	for i = 1, 40 do local u = "raidpet"  .. i; if UnitExists(u) then pet[#pet + 1] = u end end
end
-- nth filled cell -> a real token (wraps around); fallback to "player" (always exists) so a status always has
-- a valid unit to read.
local function PickUnit(isPet, n)
	local pool = unitPool[isPet]
	local c = #pool
	if c == 0 then return "player" end
	return pool[((n - 1) % c) + 1]
end

-- Acquire pooled REAL frame #i for a grid. Created ONCE: a plain (non-secure) frame with a UNIQUE,
-- pattern-matching name (Grid2LayoutHeader<headerId>UnitButton<i>) so the icon/cooldown indicators'
-- parent:GetName():match("Grid2LayoutHeader(%d+)UnitButton(%d+)") resolves instead of crashing on a nil name;
-- headerId 901/902 cannot collide with real headers. We copy the prototype closures (they keep their upvalues
-- frameBackdrop/petProfile/Grid2Frame/Grid2, so they render exactly like real frames) and create the container
-- TEXTURE that Layout()/the bar indicators size themselves from. We do NOT: RegisterFrame, add to
-- ClickCastFrames, attach GridFrameEvents, or set the initial-width/height secure attributes.
local function AcquireFrame(grid, i)
	local pool = grid.frames
	local f = pool[i]
	if not f then
		-- Button, NOT Frame: real Grid2 frames are Buttons (SecureUnitButtonTemplate), and
		-- GridFramePrototype:Layout calls self:SetHighlightTexture -- a Button-only method that errors on a
		-- plain Frame. A non-secure Button has every Frame method plus the button methods Layout/indicators need.
		f = CreateFrame("Button", format("Grid2LayoutHeader%dUnitButton%d", grid.headerId, i), grid.container)
		for name, value in pairs(Grid2Frame.Prototype) do
			f[name] = value  -- Layout, CreateIndicators, UpdateIndicators
		end
		f.container = f:CreateTexture()  -- a TEXTURE, exactly like GridFrame_Init
		f.isPet = grid.isPet
		f.builtIndicators = {}           -- name-set of indicators for which we have created a sub-region
		pool[i] = f
	elseif f:GetParent() ~= grid.container then
		f:SetParent(grid.container)
	end
	return f
end

-- Keep a frame's indicator sub-regions in sync with the live indicator set, WITHOUT ever calling
-- indicator:Disable (which mutates the SHARED indicator object -- self.Layout=nil/self.OnUpdate=nil -- and
-- would break every real frame). We call CreateIndicators only on the first build or when an indicator was
-- ADDED (cheap gate; CreateFrame is the expensive part), and we manually Hide the sub-region of any indicator
-- that was REMOVED since the last refresh so it does not leave a ghost.
local function SyncIndicators(frame)
	local built = frame.builtIndicators
	local needCreate = not frame.created
	for name in Grid2:IterateIndicators() do
		if not built[name] then needCreate = true end
	end
	if needCreate then
		frame:CreateIndicators()  -- idempotent: reuses existing sub-regions, builds newly-added ones
		frame.created = true
	end
	for name in pairs(built) do
		if not Grid2.indicators[name] then
			local r = frame[name]
			if r and r.Hide then r:Hide() end
			built[name] = nil
		end
	end
	for name in Grid2:IterateIndicators() do
		built[name] = true
	end
end

-- Turn pooled frame #i into a live cell for `unit`: real size/appearance + every configured indicator, exactly
-- as the live frames do. Positioning/sizing is done by the caller.
local function PrepareFrame(grid, i, unit, frameLevel)
	local f = AcquireFrame(grid, i)
	f.isPet = grid.isPet             -- pet appearance/size is chosen inside GridFramePrototype:Layout
	f:SetFrameLevel(frameLevel)      -- BEFORE Layout: bar/icon levels are parent:GetFrameLevel() + offset
	SyncIndicators(f)                -- create added indicators, hide removed ones
	f:Layout()                       -- size + backdrop + container + indicator layout, all from the live profile
	f.unit = unit                    -- DIRECT field assignment -- never Grid2:SetFrameUnit (stays isolated)
	f:UpdateIndicators()             -- pull live status data once (pure reads)
	return f
end

-- Release a preview cell before hiding: drive each live indicator with a NIL status so timer-owning indicators
-- (duration/elapsed Text -> TimerStop, duration Bar -> tcancel) deregister themselves from their module's
-- shared timer tables -- otherwise they keep firing on the hidden preview widget for the rest of the session.
-- Keyed by this frame's OWN sub-regions, so real frames are never touched. pcall-guarded so a throwing
-- indicator can't abort teardown.
local function ReleaseFrame(f)
	if f.unit then
		local unit = f.unit
		f.unit = nil
		for _, indicator in Grid2:IterateIndicators() do
			if indicator.OnUpdate then
				pcall(indicator.OnUpdate, indicator, f, unit, nil)
			end
		end
	end
	f:Hide()
end

-- Render one grid into its container. Reuses the original geometry: growth, frame size, LayoutGetVectors, the
-- nx/ny placement loop with its TOPLEFT formula, the spacer skip, leftover-hide and the final container sizing.
-- The ONLY change from the schematic version is that each non-spacer cell is a real self-rendering frame.
local function RenderGrid(grid)
	local f0 = grid.container
	if not (grid.active and f0) then
		local pool = grid.frames
		for j = 1, #pool do ReleaseFrame(pool[j]) end
		RestoreScale(grid)  -- hand the container back its real scale when we stop previewing into it
		return
	end
	EnsureScaled(grid)

	local p = Grid2Layout.db.profile
	local horizontal, groupAnchor, Padding, Spacing = GetGrowth(p, grid.isPet)
	local width, height = Grid2Frame:GetFrameSize(grid.isPet)
	local frameLevel = f0:GetFrameLevel() + 1

	local ux, uy, vx, vy, px, py, realCols, realRows =
		LayoutGetVectors(groupAnchor, horizontal, Spacing, Spacing, width + Padding, height + Padding, grid.colCount, grid.rowCount)

	local i, filled = 1, 0
	for nx = 0, grid.colCount - 1 do
		local col = grid.cols[nx + 1]
		for ny = 0, grid.rowCount - 1 do
			if col.spacer then
				ReleaseFrame(AcquireFrame(grid, i))  -- keep the pool dense (no nil holes -> #pool stays valid)
			else
				filled = filled + 1
				local frame = PrepareFrame(grid, i, PickUnit(grid.isPet, filled), frameLevel)
				frame:ClearAllPoints()
				frame:SetPoint("TOPLEFT", f0, "TOPLEFT", nx * ux + ny * vx + px, -(nx * uy + ny * vy + py))
				frame:SetSize(width, height)  -- explicit + combat-safe (non-secure); Layout skips SetSize in combat
				frame:Show()
			end
			i = i + 1
		end
	end
	local pool = grid.frames  -- hide leftovers from a previous, larger render of this grid
	for j = i, #pool do ReleaseFrame(pool[j]) end

	f0:SetSize(Spacing * 2 + realCols * (width + Padding) - Padding,
	           Spacing * 2 + realRows * (height + Padding) - Padding)
end

local function LayoutHide(restoreRealLayout)
	if not layoutName then return end
	for _, grid in ipairs(grids) do
		local pool = grid.frames
		for j = 1, #pool do ReleaseFrame(pool[j]) end  -- deregister timers + hide each frame + its sub-regions
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
	BuildUnitPools()               -- refresh which real unit tokens currently exist
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
