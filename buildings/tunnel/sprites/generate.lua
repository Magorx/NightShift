-- generate.lua -- Isometric tunnel: underground item passage
-- 64x48: bottom 32px = isometric diamond, top 16px = elevation
-- 2 layers (base, top), 4 frames: default(4)
--
-- Diamond base with arch/portal structure rising above, dark interior

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, FH = 64, 48
local LAYERS = {"base", "top"}
local TAGS = {
  {name="default", from=1, to=4, duration=0.3},
}
local DIR = "/Users/gorishniymax/Repos/factor/buildings/tunnel/sprites"

-- Diamond geometry
local CX, CY = 31.5, 31.5
local HX, HY = 31, 15
local BASE_TOP = 16

local function diamond_sdf(px, py)
  local dx = math.abs(px - CX) / (HX + 0.5)
  local dy = math.abs((py - BASE_TOP) - HY) / (HY + 0.5)
  return 1.0 - dx - dy
end

local function classify(px, py)
  if py < BASE_TOP then return "outside", -1 end
  local d = diamond_sdf(px, py)
  if d < 0 then return "outside", d end
  if d < 0.06 then return "outline", d end
  if d < 0.14 then return "rail", d end
  return "surface", d
end

local function draw_diamond_base(img, fill, outline_c, highlight, shadow_c)
  for y = BASE_TOP, FH - 1 do
    for x = 0, W - 1 do
      local zone, d = classify(x, y)
      if zone == "outline" then
        if y <= CY then
          H.px(img, x, y, highlight or outline_c)
        else
          H.px(img, x, y, outline_c)
        end
      elseif zone == "rail" then
        H.px(img, x, y, shadow_c or C.rim)
      elseif zone == "surface" then
        local t = (y - BASE_TOP) / (FH - 1 - BASE_TOP)
        local c = H.lerp_color(fill, H.brighten(fill, 0.7), t)
        H.px(img, x, y, c)
      end
    end
  end
end

-- Tunnel accent: stone/masonry
local STONE    = H.hex("#5A5550")
local STONE_DK = H.hex("#3E3A36")
local STONE_LT = H.hex("#706B65")
local ARCH     = H.hex("#4A4540")

-- =========================================================================
-- BASE LAYER: platform with tunnel opening in center
-- =========================================================================
local function draw_base(img, tag, phase)
  draw_diamond_base(img, C.panel, C.outline, C.body_light, C.shadow)

  -- Dark tunnel opening/pit in center of diamond
  local tcx, tcy = 31, 33
  -- Oval opening (wider than tall for iso perspective)
  for y = tcy - 4, tcy + 5 do
    for x = tcx - 8, tcx + 8 do
      local dx = (x - tcx) / 8.5
      local dy = (y - tcy) / 5.5
      if dx*dx + dy*dy <= 1.0 then
        local depth = dx*dx + dy*dy
        local col = H.lerp_color(C.chamber_deep, C.chamber, depth)
        H.px(img, x, y, col)
      end
    end
  end

  -- Subtle glow/shimmer in tunnel depths (animated)
  local shimmer_positions = {
    {{30, 33}, {32, 34}},
    {{29, 32}, {33, 33}},
    {{31, 34}, {30, 32}},
    {{32, 33}, {29, 34}},
  }
  local sp = shimmer_positions[(phase % 4) + 1]
  for _, p in ipairs(sp) do
    H.px(img, p[1], p[2], C.panel_inner)
  end
end

-- =========================================================================
-- TOP LAYER: arch/portal structure extending above diamond
-- =========================================================================
local function draw_top(img, tag, phase)
  local CLEAR = H.TRANSPARENT

  -- Stone arch structure
  -- The arch frames the tunnel opening and extends upward into elevation zone

  -- Left pillar (front-left of arch)
  for y = 6, 36 do
    local width = 4
    if y < 10 then width = 3 end  -- taper at top
    local px_start = 18
    for dx = 0, width - 1 do
      local t = (y - 6) / 30
      local col = H.lerp_color(STONE_LT, STONE_DK, t)
      H.px(img, px_start + dx, y, col)
    end
  end

  -- Right pillar (front-right of arch)
  for y = 6, 36 do
    local width = 4
    if y < 10 then width = 3 end
    local px_start = 41
    for dx = 0, width - 1 do
      local t = (y - 6) / 30
      local col = H.lerp_color(STONE, STONE_DK, t * 1.2)
      H.px(img, px_start + dx, y, col)
    end
  end

  -- Arch top (curved connection between pillars)
  -- Semi-circular arch from left pillar top to right pillar top
  local arch_cx, arch_cy = 31, 10
  local arch_rx, arch_ry = 12, 6  -- horizontal and vertical radii

  for y = 2, 14 do
    for x = 19, 44 do
      local dx = (x - arch_cx) / arch_rx
      local dy = (y - arch_cy) / arch_ry
      local dist = dx*dx + dy*dy
      -- Arch band: between two ellipses
      if dist >= 0.5 and dist <= 1.2 and y <= arch_cy + 2 then
        local t = (y - 2) / 12
        H.px(img, x, y, H.lerp_color(STONE_LT, STONE, t))
      end
    end
  end

  -- Arch outline
  for x = 19, 44 do
    for y = 1, 14 do
      local dx = (x - arch_cx) / arch_rx
      local dy = (y - arch_cy) / arch_ry
      local dist = dx*dx + dy*dy
      if math.abs(dist - 1.15) < 0.15 and y <= arch_cy + 2 then
        H.px(img, x, y, C.outline)
      end
    end
  end

  -- Keystone at top of arch
  H.rect(img, 29, 2, 33, 5, STONE_LT)
  H.rect_outline(img, 29, 2, 33, 5, C.outline)
  H.px(img, 31, 3, C.rivet)  -- keystone rivet

  -- Pillar outlines
  H.line(img, 17, 6, 17, 36, C.outline)  -- left pillar outer
  H.line(img, 22, 10, 22, 36, C.outline)  -- left pillar inner
  H.line(img, 40, 10, 40, 36, C.outline)  -- right pillar inner
  H.line(img, 45, 6, 45, 36, C.outline)  -- right pillar outer
  H.line(img, 17, 36, 22, 36, C.outline)  -- left pillar bottom
  H.line(img, 40, 36, 45, 36, C.outline)  -- right pillar bottom

  -- Dark interior of arch (portal opening)
  for y = 10, 34 do
    for x = 23, 39 do
      local dx = (x - arch_cx) / (arch_rx - 2)
      local dy = (y - arch_cy) / (arch_ry - 1)
      if dx*dx + dy*dy <= 1.0 or y > arch_cy + 2 then
        if y >= 10 then
          H.px(img, x, y, C.chamber_deep)
        end
      end
    end
  end

  -- Clear interior so base layer tunnel depths show through
  for y = 18, 34 do
    for x = 24, 38 do
      H.px(img, x, y, CLEAR)
    end
  end

  -- Stone texture details on pillars
  H.px(img, 19, 14, STONE_DK)
  H.px(img, 20, 20, STONE_LT)
  H.px(img, 19, 26, STONE_DK)
  H.px(img, 42, 16, STONE_DK)
  H.px(img, 43, 22, STONE_LT)
  H.px(img, 42, 28, STONE_DK)

  -- Pillar base blocks
  H.shaded_rect(img, 16, 33, 23, 38, STONE, STONE_LT, STONE_DK)
  H.shaded_rect(img, 39, 33, 46, 38, STONE, STONE_LT, STONE_DK)

  -- Direction indicator arrows (items entering)
  local arrow_col = C.conv_yellow
  if phase % 2 == 0 then
    H.px(img, 25, 28, arrow_col)
    H.px(img, 26, 28, arrow_col)
  else
    H.px(img, 36, 28, arrow_col)
    H.px(img, 37, 28, arrow_col)
  end
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr, DIR, "main")
print("[tunnel] done")
