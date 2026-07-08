local Grid2 = Grid2
local Background = Grid2.indicatorPrototype:new("background")

local cr, cg, cb, ca = 0, 0, 0, 1
-- Pet background color cache. This indicator owns the container color and repaints it on every unit
-- update, so the pet frameContentColor override (applied in GridFramePrototype:Layout) would otherwise
-- be overwritten with the player color. When the pet override is enabled we paint pet frames from here.
local petOn, pr, pg, pb, pa = false, 0, 0, 0, 1

Background.Create = Grid2.Dummy
Background.Layout = Grid2.Dummy

function Background:Disable(parent)
	parent.container:SetVertexColor(0, 0, 0, 0)
end

function Background:OnUpdate(parent, unit, status)
	if status then
		parent.container:SetVertexColor(status:GetColor(unit))
	elseif petOn and parent.isPet then
		parent.container:SetVertexColor(pr, pg, pb, pa)
	else
		parent.container:SetVertexColor(cr, cg, cb, ca)
	end
end

function Background:UpdateDB()
	local p = Grid2Frame.db.profile
	local c = p.frameContentColor
	cr, cg, cb, ca = c.r, c.g, c.b, c.a
	local pet = p.pet
	if pet and pet.enabled then
		local pc = pet.frameContentColor or c
		petOn, pr, pg, pb, pa = true, pc.r, pc.g, pc.b, pc.a
	else
		petOn = false
	end
end

local function CreateBackground(indicatorKey, dbx)
	Background.dbx = dbx
	Background:UpdateDB()
	Grid2:RegisterIndicator(Background, {"color"})
	return Background
end

Grid2.setupFunc["background"] = CreateBackground