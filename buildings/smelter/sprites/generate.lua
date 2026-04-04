-- generate.lua -- Isometric smelter with depth shading
-- 2x3 tiles (64x96 per frame), same canvas size as original
-- IMPORTANT: Canvas stays 64x96 to avoid code refactoring.
-- 2 layers (base, top), 10 frames:
-- idle(2) + windup(2) + active(4) + winddown(2)
--
-- Adds isometric depth: top faces lit, front edges dark, chimney detail.
-- Base layer: mold interiors, output cell floor
-- Top layer: structural housing, crucible, chimney, hoppers

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, FH = 64, 96
local LAYERS = {"base", "top"}
local TAGS = {
  {name="idle",     from=1,  to=2,  duration=0.5},
  {name="windup",   from=3,  to=4,  duration=0.15},
  {name="active",   from=5,  to=8,  duration=0.15},
  {name="winddown", from=9,  to=10, duration=0.15},
}
local DIR = "/Users/gorishniymax/Repos/factor/buildings/smelter/sprites"

-- Smelter identity: warm copper/brass
local COPPER    = H.hex("#B87333")
local COPPER_DK = H.hex("#8B5A2B")
local COPPER_RM = H.hex("#A06830")
local BRASS     = H.hex("#C9A84C")
local MOLTEN    = H.hex("#FF8C00")
local MOLTEN_BR = H.hex("#FFB347")
local MOLTEN_DM = H.hex("#A05A10")

-- Isometric depth shading helper
local function shaded_box(img, x1, y1_top, x2, y_mid, y_bottom, top_col, fl_col, fr_col, out_col)
  -- Top face
  H.rect(img, x1, y1_top, x2, y_mid, top_col)
  -- Front-left face
  local mid_x = math.floor((x1 + x2) / 2)
  H.rect(img, x1, y_mid + 1, mid_x, y_bottom, fl_col)
  -- Front-right face (darker)
  H.rect(img, mid_x + 1, y_mid + 1, x2, y_bottom, fr_col)
  -- Outlines
  H.rect_outline(img, x1, y1_top, x2, y_bottom, out_col)
  H.line(img, x1, y_mid, x2, y_mid, out_col)
end

-- =========================================================================
-- BASE LAYER: recessed interiors visible through top-layer openings
-- =========================================================================
local function draw_base(img, tag, phase)
  -- Mold interiors (dark background for code-animated bars)
  H.rect(img, 8, 73, 24, 87, C.shadow)
  H.rect(img, 39, 73, 55, 87, C.shadow)

  -- Output cell floor
  H.rect(img, 34, 34, 62, 62, C.panel)
  H.rect(img, 35, 43, 63, 52, C.panel_inner)
end

-- =========================================================================
-- TOP LAYER: structural elements with isometric depth shading
-- =========================================================================
local function draw_top(img, tag, phase)
  local cx, cy = 15, 47

  -- ── Top row: input hoppers section (3D depth) ───────────────────────
  -- Top face (lit from above)
  H.rect(img, 1, 1, 62, 10, C.body_light)
  -- Front face (darker gradient for depth)
  H.gradient_v(img, 1, 11, 62, 30, C.body, C.panel)
  -- Outline
  H.rect_outline(img, 0, 0, 63, 31, C.outline)
  -- Edge between top face and front face
  H.line(img, 1, 10, 62, 10, C.rim)

  -- Copper accent on top face
  for x = 4, 59 do H.px(img, x, 3, COPPER) end
  -- Shadow strip at bottom of front face
  for x = 4, 59 do H.px(img, x, 29, COPPER_DK) end

  -- ── Input hopper A (left, 3D recessed) ──────────────────────────────
  shaded_box(img, 5, 4, 27, 9, 27, C.panel_inner, C.chamber, C.chamber_deep, COPPER_RM)
  H.rect(img, 9, 5, 23, 8, C.chamber_deep)  -- opening
  H.rect(img, 9, 14, 23, 24, C.chamber)      -- front face pit
  H.rect_outline(img, 9, 14, 23, 24, COPPER_DK)
  H.rect_outline(img, 5, 4, 27, 27, COPPER)

  -- ── Input hopper B (right, 3D recessed) ─────────────────────────────
  shaded_box(img, 36, 4, 58, 9, 27, C.panel_inner, C.chamber, C.chamber_deep, COPPER_RM)
  H.rect(img, 40, 5, 54, 8, C.chamber_deep)
  H.rect(img, 40, 14, 54, 24, C.chamber)
  H.rect_outline(img, 40, 14, 54, 24, COPPER_DK)
  H.rect_outline(img, 36, 4, 58, 27, COPPER)

  -- ── Middle-left: crucible section (3D) ──────────────────────────────
  -- Top face
  H.rect(img, 1, 33, 30, 40, C.body_light)
  -- Front face
  H.gradient_v(img, 1, 41, 30, 62, C.body, C.panel)
  H.rect_outline(img, 0, 32, 31, 63, C.outline)
  H.line(img, 1, 40, 30, 40, C.rim)

  -- ── Middle-right: output channel ────────────────────────────────────
  -- Frame strips (center open for items)
  H.rect(img, 33, 33, 62, 37, C.body_light)
  H.rect(img, 33, 58, 62, 62, C.panel)
  H.rect(img, 33, 38, 36, 57, C.body)
  H.rect_outline(img, 32, 32, 63, 63, C.outline)
  -- Channel walls with depth
  H.line(img, 37, 38, 62, 38, COPPER_DK)
  H.line(img, 37, 57, 62, 57, COPPER_DK)
  H.line(img, 37, 38, 37, 57, COPPER_DK)

  -- ── Crucible ────────────────────────────────────────────────────────
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

  -- Crucible rim (highlight on top, shadow on bottom)
  for a = 0, 359 do
    local rad = math.rad(a)
    local rx = math.floor(cx + 12 * math.cos(rad) + 0.5)
    local ry = math.floor(cy + 12 * math.sin(rad) + 0.5)
    local col = (a >= 180 and a <= 360) and COPPER or COPPER_DK
    H.px(img, rx, ry, col)
  end
  H.circle_outline(img, cx, cy, 13, COPPER_DK)

  -- ── Bottom row: casting molds (3D depth) ────────────────────────────
  -- Top face
  H.rect(img, 1, 65, 62, 72, C.body_light)
  -- Front face
  H.gradient_v(img, 1, 73, 62, 94, C.body, C.panel)
  H.rect_outline(img, 0, 64, 63, 95, C.outline)
  H.line(img, 1, 72, 62, 72, C.rim)

  -- Copper accents
  for x = 4, 59 do H.px(img, x, 68, COPPER) end
  for x = 4, 59 do H.px(img, x, 92, COPPER_DK) end

  -- Left mold (3D)
  shaded_box(img, 5, 70, 27, 73, 90, C.panel_inner, C.shadow, C.shadow, C.rim)
  H.rect_outline(img, 8, 74, 24, 87, C.panel_inner)
  -- Right mold (3D)
  shaded_box(img, 36, 70, 58, 73, 90, C.panel_inner, C.shadow, C.shadow, C.rim)
  H.rect_outline(img, 39, 74, 55, 87, C.panel_inner)
  -- Mold separators
  H.line(img, 8, 80, 24, 80, C.panel_inner)
  H.line(img, 39, 80, 55, 80, C.panel_inner)

  -- Clear mold interiors so base layer shows through
  local CLEAR = H.TRANSPARENT
  H.rect(img, 9, 74, 23, 79, CLEAR)
  H.rect(img, 9, 81, 23, 86, CLEAR)
  H.rect(img, 40, 74, 54, 79, CLEAR)
  H.rect(img, 40, 81, 54, 86, CLEAR)

  -- ── Pipes: hoppers to crucible ──────────────────────────────────────
  H.line(img, 15, 28, 15, 35, C.pipe)
  H.line(img, 16, 28, 16, 35, C.pipe_inner)
  H.px(img, 14, 28, C.pipe)
  H.px(img, 16, 28, C.pipe)
  H.line(img, 47, 28, 47, 40, C.pipe)
  H.line(img, 48, 28, 48, 40, C.pipe_inner)
  H.line(img, 28, 40, 47, 40, C.pipe)
  H.line(img, 28, 41, 47, 41, C.pipe_inner)
  H.px(img, 46, 28, C.pipe)
  H.px(img, 48, 28, C.pipe)
  -- Pipe flanges
  H.px(img, 14, 31, COPPER_DK)
  H.px(img, 16, 31, COPPER_DK)
  H.px(img, 46, 34, COPPER_DK)
  H.px(img, 48, 34, COPPER_DK)

  -- ── Chimney/smokestack (extends above top section) ──────────────────
  local chx = 54
  -- Chimney body (left face lit, right face shadow)
  for y = 0, 5 do
    local t = y / 5
    H.px(img, chx - 2, y, H.lerp_color(C.body_light, C.body, t))
    H.px(img, chx - 1, y, H.lerp_color(C.body_light, C.body, t))
    H.px(img, chx, y, C.body)
    H.px(img, chx + 1, y, H.lerp_color(C.body, C.panel, t))
    H.px(img, chx + 2, y, H.lerp_color(C.body, C.panel, t))
  end
  H.rect_outline(img, chx - 3, 0, chx + 3, 6, C.outline)
  -- Chimney cap
  H.line(img, chx - 3, 0, chx + 3, 0, C.rim)
  -- Chimney soot
  H.line(img, chx - 1, 1, chx + 1, 1, C.soot)

  -- Smoke when active
  if tag == "active" or (tag == "windup" and phase == 1) then
    local offsets = {{-1,-1},{1,-1},{0,1},{-1,0}}
    local o = offsets[(phase % 4) + 1]
    H.px(img, chx + o[1], 0 + o[2], C.smoke_light)
    H.px(img, chx - o[1], -1, C.smoke_mid)
  end

  -- ── Copper bolts ────────────────────────────────────────────────────
  for _, p in ipairs({
    {4,4},{59,4},{4,27},{59,27},
    {4,69},{59,69},{4,91},{59,91},
    {4,36},{28,36},{4,60},{28,60},
  }) do
    H.px(img, p[1], p[2], COPPER)
  end

  -- ── Heat shimmer near crucible ──────────────────────────────────────
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
H.save_and_export(spr, DIR, "main")
print("[smelter] done")
