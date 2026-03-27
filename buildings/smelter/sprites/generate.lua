-- smelter_sprite.lua
-- Top-down smelter: warm copper/brass identity, large crucible with molten metal.
-- 2x3 tiles (64x96 per frame), 2 layers, 10 frames:
-- idle(2) + windup(2) + active(4) + winddown(2).
--
-- Base layer (z=0): minimal — mold interiors for code-animated bars, output cell floor.
-- Top layer (z=10): nearly everything structural — items render UNDER this.
-- Cell (1,1) has an opening in the top layer so items flow visibly through.

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, FH = 64, 96
local LAYERS = {"base", "top"}
local TAGS = {
  {name="idle",     from=1, to=2, duration=0.5},
  {name="windup",   from=3, to=4, duration=0.15},
  {name="active",   from=5, to=8, duration=0.15},
  {name="winddown", from=9, to=10, duration=0.15},
}

-- Smelter identity: warm copper/brass, bright molten
local COPPER    = H.hex("#B87333")
local COPPER_DK = H.hex("#8B5A2B")
local COPPER_RM = H.hex("#A06830")
local BRASS     = H.hex("#C9A84C")
local MOLTEN    = H.hex("#FF8C00")
local MOLTEN_BR = H.hex("#FFB347")
local MOLTEN_DM = H.hex("#A05A10")

-- ═══════════════════════════════════════════════════════════════════════════
-- BASE LAYER: only recessed interiors visible through top-layer openings
-- ═══════════════════════════════════════════════════════════════════════════
local function draw_base(img, tag, phase)
  -- Mold interiors (dark background for code-animated bars at z=5)
  H.rect(img, 8, 73, 24, 87, C.shadow)
  H.rect(img, 39, 73, 55, 87, C.shadow)

  -- Output cell floor (visible through top layer opening; conveyor overlays this)
  H.rect(img, 34, 34, 62, 62, C.panel)
  H.rect(img, 35, 43, 63, 52, C.panel_inner)

  -- Diagonal channel from crucible to mold area (idle frame 0 only)
  if tag == "idle" and phase == 0 then
    local ch = {
      {60,0,2},{61,2,6},{62,7,9},{63,10,12},{64,12,14},{65,14,15},
      {66,16,17},{67,17,19},{68,19,21},{69,21,22},{70,23,24},
      {71,24,26},{72,26,27},{73,27,29},{74,29,29},
    }
    for _, r in ipairs(ch) do
      H.line(img, r[2], r[1], r[3], r[1], C.conv_light)
    end
  end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- TOP LAYER: all structural elements — renders above items
-- ═══════════════════════════════════════════════════════════════════════════
local function draw_top(img, tag, phase)
  local cx, cy = 15, 47

  -- ── Section fills ────────────────────────────────────────────────────
  -- Top row (full)
  H.rect(img, 1, 1, 62, 30, C.body_light)
  H.rect(img, 2, 2, 61, 29, C.panel)
  -- Middle-left (full)
  H.rect(img, 1, 33, 30, 62, C.body_light)
  H.rect(img, 2, 34, 29, 61, C.panel)
  -- Middle-right: frame strips only — center open for item visibility
  H.rect(img, 33, 33, 62, 37, C.body)       -- top strip
  H.rect(img, 34, 34, 61, 36, C.panel)
  H.rect(img, 33, 58, 62, 62, C.body)       -- bottom strip
  H.rect(img, 34, 59, 61, 61, C.panel)
  H.rect(img, 33, 38, 36, 57, C.body)       -- left strip (crucible connection)
  H.rect(img, 34, 38, 35, 57, C.panel)
  -- Bottom row (full)
  H.rect(img, 1, 65, 62, 94, C.body_light)
  H.rect(img, 2, 66, 61, 93, C.panel)

  -- ── Section outlines ─────────────────────────────────────────────────
  H.rect_outline(img, 0, 0, 63, 31, C.outline)
  H.rect_outline(img, 0, 32, 31, 63, C.outline)
  H.rect_outline(img, 32, 32, 63, 63, C.outline)
  H.rect_outline(img, 0, 64, 63, 95, C.outline)

  -- ── Copper accent strips ─────────────────────────────────────────────
  for x = 4, 59 do
    H.px(img, x, 3, COPPER_DK)
    H.px(img, x, 28, COPPER_DK)
    H.px(img, x, 68, COPPER_DK)
    H.px(img, x, 92, COPPER_DK)
  end
  for y = 4, 60 do H.px(img, 3, y, COPPER_DK) end
  for y = 68, 91 do H.px(img, 3, y, COPPER_DK) end

  -- ── Input hoppers ────────────────────────────────────────────────────
  H.bordered_rect(img, 5, 5, 27, 27, C.panel_inner, COPPER_RM)
  H.bordered_rect(img, 8, 8, 24, 24, C.chamber, COPPER_DK)
  H.bordered_rect(img, 11, 11, 21, 21, C.chamber_deep, C.shadow)
  H.rect_outline(img, 5, 5, 27, 27, COPPER)
  H.bordered_rect(img, 36, 5, 58, 27, C.panel_inner, COPPER_RM)
  H.bordered_rect(img, 39, 8, 55, 24, C.chamber, COPPER_DK)
  H.bordered_rect(img, 42, 11, 52, 21, C.chamber_deep, C.shadow)
  H.rect_outline(img, 36, 5, 58, 27, COPPER)

  -- ── Crucible ─────────────────────────────────────────────────────────
  H.circle(img, cx, cy, 13, COPPER_DK)
  H.circle(img, cx, cy, 12, C.chamber)

  -- Crucible contents (state-dependent)
  if tag == "active" then
    H.circle(img, cx, cy, 11, MOLTEN_DM)
    H.circle(img, cx, cy, 9, C.fire_outer)
    local sh = {{-1,0},{1,0},{0,-1},{0,1}}
    local s = sh[(phase % 4) + 1]
    H.circle(img, cx + s[1], cy + s[2], 7, MOLTEN)
    H.circle(img, cx - s[1], cy - s[2], 4, MOLTEN_BR)
    H.circle(img, cx + s[2], cy + s[1], 2, C.fire_core)
    if phase >= 2 then H.px(img, cx, cy, C.fire_hot) end
    H.circle_outline(img, cx, cy, 12, C.glow_wall)
  elseif tag == "windup" then
    H.circle(img, cx, cy, 11, C.chamber_deep)
    if phase == 0 then
      H.px(img, cx-2, cy, C.ember)
      H.px(img, cx+3, cy+1, C.ember)
    else
      H.circle(img, cx, cy, 6, C.fire_dim)
      H.circle(img, cx, cy, 3, C.ember)
      H.circle(img, cx, cy, 1, MOLTEN_DM)
    end
  elseif tag == "winddown" then
    if phase == 0 then
      H.circle(img, cx, cy, 11, MOLTEN_DM)
      H.circle(img, cx, cy, 7, C.fire_dim)
      H.circle(img, cx, cy, 3, C.ember)
    else
      H.circle(img, cx, cy, 11, C.chamber_deep)
      H.px(img, cx-2, cy, C.ember)
      H.px(img, cx+3, cy+1, C.ember)
    end
  else
    H.circle(img, cx, cy, 11, C.chamber_deep)
    local em = phase == 0
      and {{cx-3,cy},{cx+4,cy+2}}
      or  {{cx+2,cy-3},{cx-2,cy+3}}
    for _, p in ipairs(em) do H.px(img, p[1], p[2], C.ember) end
  end

  -- Crucible rim (on top of contents)
  H.circle_outline(img, cx, cy, 12, COPPER)
  H.circle_outline(img, cx, cy, 13, COPPER_DK)

  -- ── Output opening frame detail ──────────────────────────────────────
  -- Channel walls at opening edges
  H.line(img, 37, 38, 62, 38, COPPER_DK)    -- top wall
  H.line(img, 37, 57, 62, 57, COPPER_DK)    -- bottom wall
  H.line(img, 37, 38, 37, 57, COPPER_DK)    -- left wall (at crucible)

  -- ── Casting mold frames (covers bar overflow) ────────────────────────
  -- Left mold frame strips
  H.rect(img, 5, 70, 27, 72, C.panel_inner)
  H.rect(img, 5, 88, 27, 90, C.panel_inner)
  H.rect(img, 5, 73, 7, 87, C.panel_inner)
  H.rect(img, 25, 73, 27, 87, C.panel_inner)
  H.rect_outline(img, 5, 70, 27, 90, C.rim)
  H.rect_outline(img, 8, 73, 24, 87, C.panel_inner)
  -- Right mold frame strips
  H.rect(img, 36, 70, 58, 72, C.panel_inner)
  H.rect(img, 36, 88, 58, 90, C.panel_inner)
  H.rect(img, 36, 73, 38, 87, C.panel_inner)
  H.rect(img, 56, 73, 58, 87, C.panel_inner)
  H.rect_outline(img, 36, 70, 58, 90, C.rim)
  H.rect_outline(img, 39, 73, 55, 87, C.panel_inner)
  -- Mold separators (bars slide underneath)
  H.line(img, 8, 80, 24, 80, C.panel_inner)
  H.line(img, 39, 80, 55, 80, C.panel_inner)

  -- Clear mold interiors so base layer bars/items show through
  local CLEAR = H.rgba(0, 0, 0, 0)
  H.rect(img, 9, 74, 23, 79, CLEAR)
  H.rect(img, 9, 81, 23, 86, CLEAR)
  H.rect(img, 40, 74, 54, 79, CLEAR)
  H.rect(img, 40, 81, 54, 86, CLEAR)

  -- ── Pipes: hoppers → crucible ────────────────────────────────────────
  H.line(img, 15, 28, 15, 35, C.pipe)
  H.px(img, 14, 28, C.pipe)
  H.px(img, 16, 28, C.pipe)
  H.line(img, 47, 28, 47, 40, C.pipe)
  H.line(img, 28, 40, 47, 40, C.pipe)
  H.px(img, 46, 28, C.pipe)
  H.px(img, 48, 28, C.pipe)
  H.px(img, 14, 31, COPPER_DK)
  H.px(img, 16, 31, COPPER_DK)
  H.px(img, 46, 34, COPPER_DK)
  H.px(img, 48, 34, COPPER_DK)

  -- ── Copper bolts ─────────────────────────────────────────────────────
  for _, p in ipairs({
    {4,4},{59,4},{4,27},{59,27},
    {4,69},{59,69},{4,91},{59,91},
    {4,36},{28,36},{4,60},{28,60},
  }) do
    H.px(img, p[1], p[2], COPPER)
  end

  -- ── Heat shimmer ─────────────────────────────────────────────────────
  if tag == "active" or (tag == "windup" and phase == 1) then
    local offsets = {{-2,-1},{2,-1},{0,1},{-1,0}}
    local o = offsets[(phase % 4) + 1]
    H.px(img, cx + o[1], cy - 14 + o[2], C.smoke_light)
    H.px(img, cx - o[1], cy - 15, C.smoke_mid)
  end
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr,
  "/Users/gorishniymax/Repos/factor/buildings/smelter/sprites", "main")
print("[smelter] done")
