-- generate.lua -- Isometric splitter: item routing/splitting
-- 64x48: bottom 32px = isometric diamond, top 16px = elevation
-- 2 layers (base, top), 4 frames: default(4)
--
-- Diamond base with raised mechanical housing and sorting arms

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, FH = 64, 48
local LAYERS = {"base", "top"}
local TAGS = {
  {name="default", from=1, to=4, duration=0.3},
}
local DIR = "/Users/gorishniymax/Repos/factor/buildings/splitter/sprites"

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

-- Splitter accent: warm bronze/brass
local MECH     = H.hex("#8B7355")
local MECH_DK  = H.hex("#6B5535")
local MECH_LT  = H.hex("#A89070")

-- =========================================================================
-- BASE LAYER: platform with track grooves
-- =========================================================================
local function draw_base(img, tag, phase)
  draw_diamond_base(img, C.panel, C.outline, C.body_light, C.shadow)

  -- Track grooves on platform surface (items travel along these)
  -- Input track (from left diamond edge toward center)
  local tcx, tcy = 31, 32
  H.line(img, 10, 28, 31, 32, C.panel_inner)
  H.line(img, 10, 29, 31, 33, C.panel_inner)
  -- Output tracks (from center splitting to right edges)
  H.line(img, 31, 32, 52, 26, C.panel_inner)
  H.line(img, 31, 33, 52, 27, C.panel_inner)
  H.line(img, 31, 32, 52, 38, C.panel_inner)
  H.line(img, 31, 33, 52, 39, C.panel_inner)
end

-- =========================================================================
-- TOP LAYER: mechanical housing with sorting mechanism
-- =========================================================================
local function draw_top(img, tag, phase)
  -- Wider housing that fills more of the diamond
  local box_top = 6
  local box_mid = 18     -- where top face meets front face
  local box_bot = 36     -- bottom of front face

  -- Top face (lit from upper-left, warm gray)
  for y = box_top, box_mid do
    local t = (y - box_top) / (box_mid - box_top)
    -- Wider top face that narrows slightly (isometric perspective)
    local xl = math.floor(14 + t * 4)
    local xr = math.floor(48 - t * 4)
    for x = xl, xr do
      H.px(img, x, y, H.lerp_color(MECH_LT, MECH, t * 0.6))
    end
  end

  -- Front-left face (medium)
  for y = box_mid + 1, box_bot do
    local t = (y - box_mid) / (box_bot - box_mid)
    local xl = math.floor(18 + t * 5)
    local xr = math.floor(30 + t * 1)
    for x = xl, xr do
      H.px(img, x, y, MECH)
    end
  end

  -- Front-right face (darker)
  for y = box_mid + 1, box_bot do
    local t = (y - box_mid) / (box_bot - box_mid)
    local xl = math.floor(31 + t * 1)
    local xr = math.floor(44 - t * 5)
    for x = xl, xr do
      H.px(img, x, y, MECH_DK)
    end
  end

  -- Housing outline edges
  H.line(img, 14, box_top, 48, box_top, C.outline)         -- top
  H.line(img, 14, box_top, 18, box_mid, C.outline)         -- top-left to mid
  H.line(img, 48, box_top, 44, box_mid, C.outline)         -- top-right to mid
  H.line(img, 18, box_mid, 23, box_bot, C.outline)         -- mid-left to bottom
  H.line(img, 44, box_mid, 39, box_bot, C.outline)         -- mid-right to bottom
  H.line(img, 23, box_bot, 39, box_bot, C.outline)         -- bottom edge
  -- Top-to-front edge
  H.line(img, 18, box_mid, 44, box_mid, C.outline)
  -- Front center ridge
  H.line(img, 31, box_mid, 31, box_bot, C.shadow)

  -- Yellow accent stripe on top face
  for x = 16, 46 do
    H.px(img, x, box_top + 2, YELLOW)
  end
  -- Yellow stripe on front face
  H.line(img, 20, box_mid + 3, 42, box_mid + 3, YELLOW_DK)

  -- Input port (left side)
  H.rect(img, 12, box_mid - 3, 17, box_mid + 3, C.panel_inner)
  H.rect_outline(img, 12, box_mid - 3, 17, box_mid + 3, MECH_DK)
  H.px(img, 10, box_mid, YELLOW)
  H.px(img, 11, box_mid, YELLOW)

  -- Three output chutes (right side, fanned out)
  -- Top chute
  H.rect(img, 45, box_mid - 6, 49, box_mid - 3, C.panel_inner)
  H.rect_outline(img, 45, box_mid - 6, 49, box_mid - 3, MECH_DK)
  H.px(img, 50, box_mid - 5, YELLOW)
  -- Middle chute
  H.rect(img, 45, box_mid - 1, 49, box_mid + 1, C.panel_inner)
  H.rect_outline(img, 45, box_mid - 1, 49, box_mid + 1, MECH_DK)
  H.px(img, 50, box_mid, YELLOW)
  -- Bottom chute
  H.rect(img, 45, box_mid + 3, 49, box_mid + 6, C.panel_inner)
  H.rect_outline(img, 45, box_mid + 3, 49, box_mid + 6, MECH_DK)
  H.px(img, 50, box_mid + 5, YELLOW)

  -- Sorting mechanism on top face: rotating divider arm
  local arm_offset = phase % 4
  local arm_spread = (arm_offset % 2 == 0) and 2 or 4

  -- Y-shaped sorting arm
  -- Input guide
  H.line(img, 20, box_top + 6, 30, box_top + 4, MECH_LT)
  -- Split point
  H.px(img, 31, box_top + 4, YELLOW)
  H.px(img, 32, box_top + 4, YELLOW)
  -- Upper arm
  H.line(img, 32, box_top + 4, 40, box_top + 2 - (arm_spread > 2 and 1 or 0), MECH_LT)
  -- Lower arm
  H.line(img, 32, box_top + 4, 40, box_top + 6 + (arm_spread > 2 and 1 or 0), MECH_LT)

  -- Rivets
  for _, p in ipairs({{16, box_top+1}, {46, box_top+1}, {21, box_bot-1}, {41, box_bot-1}}) do
    H.px(img, p[1], p[2], C.rivet)
  end
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr, DIR, "main")
print("[splitter] done")
