-- smelter_sprite.lua
-- Top-down smelter: warm copper/brass identity, large crucible with molten metal.
-- 2x3 tiles (64x96 per frame), 2 layers, 6 frames (2 idle + 4 active).

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, FH = 64, 96
local LAYERS = {"base", "top"}
local TAGS = {
  {name="idle",   from=1, to=2, duration=0.5},
  {name="active", from=3, to=6, duration=0.15},
}

-- Smelter identity: warm copper/brass, bright molten
local COPPER    = H.hex("#B87333")
local COPPER_DK = H.hex("#8B5A2B")
local COPPER_RM = H.hex("#A06830")
local BRASS     = H.hex("#C9A84C")
local MOLTEN    = H.hex("#FF8C00")
local MOLTEN_BR = H.hex("#FFB347")
local MOLTEN_DM = H.hex("#A05A10")

local function draw_base(img, tag, phase)
  -- OUTLINES (L-shape + output cell)
  H.rect_outline(img, 0, 0, 63, 31, C.outline)   -- top row
  H.rect_outline(img, 0, 32, 31, 63, C.outline)   -- middle-left
  H.rect_outline(img, 32, 32, 63, 63, C.outline)   -- middle-right (output)
  H.rect_outline(img, 0, 64, 63, 95, C.outline)   -- bottom row

  -- BODY FILL
  H.rect(img, 1, 1, 62, 30, C.body_light)
  H.rect(img, 2, 2, 61, 29, C.panel)
  H.rect(img, 1, 33, 30, 62, C.body_light)
  H.rect(img, 2, 34, 29, 61, C.panel)
  H.rect(img, 33, 33, 62, 62, C.body)
  H.rect(img, 34, 34, 61, 61, C.panel)
  H.rect(img, 1, 65, 62, 94, C.body_light)
  H.rect(img, 2, 66, 61, 93, C.panel)

  -- COPPER ACCENT STRIPS (key differentiator from coal burner)
  for x = 4, 59 do
    H.px(img, x, 3, COPPER_DK)
    H.px(img, x, 28, COPPER_DK)
    H.px(img, x, 68, COPPER_DK)
    H.px(img, x, 92, COPPER_DK)
  end
  for y = 4, 60 do H.px(img, 3, y, COPPER_DK) end
  for y = 68, 91 do H.px(img, 3, y, COPPER_DK) end

  -- TOP ROW: Input Hoppers (symmetric pair of funnels)
  -- Left hopper: concentric rectangles getting darker toward center
  H.bordered_rect(img, 5, 5, 27, 27, C.panel_inner, COPPER_RM)
  H.bordered_rect(img, 8, 8, 24, 24, C.chamber, COPPER_DK)
  H.bordered_rect(img, 11, 11, 21, 21, C.chamber_deep, C.shadow)
  -- Right hopper
  H.bordered_rect(img, 36, 5, 58, 27, C.panel_inner, COPPER_RM)
  H.bordered_rect(img, 39, 8, 55, 24, C.chamber, COPPER_DK)
  H.bordered_rect(img, 42, 11, 52, 21, C.chamber_deep, C.shadow)

  -- MIDDLE-LEFT: Large Crucible (smelter centerpiece)
  local cx, cy = 15, 47
  H.circle(img, cx, cy, 13, COPPER_DK)   -- outer rim
  H.circle(img, cx, cy, 12, C.chamber)   -- inner wall

  -- MIDDLE-RIGHT: Output Channel
  H.rect(img, 30, 44, 62, 51, C.panel_inner)
  H.line(img, 30, 43, 62, 43, COPPER_DK)
  H.line(img, 30, 52, 62, 52, COPPER_DK)
  H.rect(img, 59, 45, 62, 50, C.chamber)

  -- CRUCIBLE CONTENTS
  if tag == "active" then
    -- bright molten metal in crucible
    H.circle(img, cx, cy, 11, MOLTEN_DM)
    H.circle(img, cx, cy, 9, C.fire_outer)
    local sh = {{-1,0},{1,0},{0,-1},{0,1}}
    local s = sh[(phase % 4) + 1]
    H.circle(img, cx + s[1], cy + s[2], 7, MOLTEN)
    H.circle(img, cx - s[1], cy - s[2], 4, MOLTEN_BR)
    H.circle(img, cx + s[2], cy + s[1], 2, C.fire_core)
    if phase >= 2 then H.px(img, cx, cy, C.fire_hot) end
    H.circle_outline(img, cx, cy, 12, C.glow_wall)

    -- molten metal flowing in output channel
    H.rect(img, 32, 46, 58, 49, MOLTEN_DM)
    local fl = phase % 2 == 0
    H.rect(img, fl and 34 or 36, 46, fl and 54 or 56, 49, C.fire_outer)
    H.rect(img, fl and 38 or 40, 47, fl and 50 or 52, 48, MOLTEN)
  else
    -- idle: dark crucible with faint residual warmth
    H.circle(img, cx, cy, 11, C.chamber_deep)
    local em = phase == 0
      and {{cx-3,cy},{cx+4,cy+2}}
      or  {{cx+2,cy-3},{cx-2,cy+3}}
    for _, p in ipairs(em) do H.px(img, p[1], p[2], C.ember) end
    H.rect(img, 32, 46, 58, 49, C.shadow)
  end

  -- BOTTOM ROW: Casting Molds (symmetric pair)
  H.bordered_rect(img, 5, 70, 27, 90, C.panel_inner, C.rim)
  H.bordered_rect(img, 8, 73, 24, 87, C.shadow, C.panel_inner)
  H.bordered_rect(img, 36, 70, 58, 90, C.panel_inner, C.rim)
  H.bordered_rect(img, 39, 73, 55, 87, C.shadow, C.panel_inner)
  -- mold divider lines
  H.line(img, 8, 80, 24, 80, C.panel_inner)
  H.line(img, 39, 80, 55, 80, C.panel_inner)
  -- warm glow in molds when active
  if tag == "active" then
    H.rect(img, 10, 75, 22, 78, C.fire_dim)
    H.rect(img, 41, 75, 53, 78, C.fire_dim)
    if phase % 2 == 0 then
      H.rect(img, 12, 76, 20, 77, C.ember)
    end
  end

  -- COPPER BOLTS (warm accent points)
  for _, p in ipairs({
    {4,4},{59,4},{4,27},{59,27},
    {4,69},{59,69},{4,91},{59,91},
    {4,36},{28,36},{4,60},{28,60},
  }) do
    H.px(img, p[1], p[2], COPPER)
  end
end

local function draw_top(img, tag, phase)
  local cx, cy = 15, 47

  -- crucible copper rim (prominent warm ring)
  H.circle_outline(img, cx, cy, 12, COPPER)
  H.circle_outline(img, cx, cy, 13, COPPER_DK)

  -- pipes: hoppers -> crucible
  -- left pipe (straight down from left hopper)
  H.line(img, 15, 28, 15, 35, C.pipe)
  H.px(img, 14, 28, C.pipe)
  H.px(img, 16, 28, C.pipe)
  -- right pipe (down then left from right hopper to crucible area)
  H.line(img, 47, 28, 47, 40, C.pipe)
  H.line(img, 28, 40, 47, 40, C.pipe)
  H.px(img, 46, 28, C.pipe)
  H.px(img, 48, 28, C.pipe)
  -- pipe flanges (copper)
  H.px(img, 14, 31, COPPER_DK)
  H.px(img, 16, 31, COPPER_DK)
  H.px(img, 46, 34, COPPER_DK)
  H.px(img, 48, 34, COPPER_DK)

  -- hopper copper rims
  H.rect_outline(img, 5, 5, 27, 27, COPPER)
  H.rect_outline(img, 36, 5, 58, 27, COPPER)

  -- heat shimmer above crucible (active)
  if tag == "active" then
    local offsets = {{-2,-1},{2,-1},{0,1},{-1,0}}
    local o = offsets[(phase % 4) + 1]
    H.px(img, cx + o[1], cy - 14 + o[2], C.smoke_light)
    H.px(img, cx - o[1], cy - 15, C.smoke_mid)
  end
end

-- render & export
local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr,
  "/Users/gorishniymax/Repos/factor/buildings/smelter/sprites", "main")
print("[smelter] done")
