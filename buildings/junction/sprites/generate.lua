-- generate.lua -- Isometric junction: crossing tracks intersection
-- 64x48: bottom 32px = isometric diamond, top 16px = elevation
-- 2 layers (base, top), 4 frames: default(4)
--
-- Diamond base with raised track intersection and crossing rails

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, FH = 64, 48
local LAYERS = {"base", "top"}
local TAGS = {
  {name="default", from=1, to=4, duration=0.3},
}
local DIR = "/Users/gorishniymax/Repos/factor/buildings/junction/sprites"

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

-- Junction accent: steel/iron
local RAIL     = H.hex("#606870")
local RAIL_DK  = H.hex("#484E56")
local RAIL_LT  = H.hex("#787E88")

-- =========================================================================
-- BASE LAYER: platform with track grooves
-- =========================================================================
local function draw_base(img, tag, phase)
  draw_diamond_base(img, C.panel, C.outline, C.body_light, C.shadow)

  -- Track grooves crossing on the platform surface
  local tcx, tcy = 31, 32
  -- Track A: top-left to bottom-right (iso grid +X direction)
  H.line(img, 4, 24, 58, 40, C.panel_inner)
  H.line(img, 4, 25, 58, 41, C.panel_inner)
  -- Track B: top-right to bottom-left (iso grid +Y direction)
  H.line(img, 58, 24, 4, 40, C.panel_inner)
  H.line(img, 58, 25, 4, 41, C.panel_inner)
end

-- =========================================================================
-- TOP LAYER: raised crossing platform with guard bumpers
-- =========================================================================
local function draw_top(img, tag, phase)
  -- Central raised crossing platform (isometric box shape)
  -- This is a low box that covers the center of the diamond
  local plat_top = 10    -- top surface
  local plat_mid = 18    -- where top meets front
  local plat_bot = 34    -- bottom of front face

  -- Top face (lit, full crossing plate)
  for y = plat_top, plat_mid do
    local t = (y - plat_top) / (plat_mid - plat_top)
    local xl = math.floor(14 + t * 5)
    local xr = math.floor(48 - t * 5)
    for x = xl, xr do
      H.px(img, x, y, H.lerp_color(RAIL_LT, RAIL, t * 0.5))
    end
  end

  -- Front-left face
  for y = plat_mid + 1, plat_bot do
    local t = (y - plat_mid) / (plat_bot - plat_mid)
    local xl = math.floor(19 + t * 4)
    local xr = math.floor(30 + t * 1)
    for x = xl, xr do
      H.px(img, x, y, RAIL)
    end
  end

  -- Front-right face (darker)
  for y = plat_mid + 1, plat_bot do
    local t = (y - plat_mid) / (plat_bot - plat_mid)
    local xl = math.floor(31 + t * 1)
    local xr = math.floor(43 - t * 4)
    for x = xl, xr do
      H.px(img, x, y, RAIL_DK)
    end
  end

  -- Platform outline
  H.line(img, 14, plat_top, 48, plat_top, C.outline)
  H.line(img, 14, plat_top, 19, plat_mid, C.outline)
  H.line(img, 48, plat_top, 43, plat_mid, C.outline)
  H.line(img, 19, plat_mid, 23, plat_bot, C.outline)
  H.line(img, 43, plat_mid, 39, plat_bot, C.outline)
  H.line(img, 23, plat_bot, 39, plat_bot, C.outline)
  H.line(img, 19, plat_mid, 43, plat_mid, C.outline)
  -- Front ridge
  H.line(img, 31, plat_mid, 31, plat_bot, C.shadow)

  -- Crossing X pattern on top face (track markings)
  -- Track A: diagonal from top-left to bottom-right
  H.line(img, 16, plat_top + 2, 46, plat_mid - 1, RAIL_DK)
  H.line(img, 17, plat_top + 2, 47, plat_mid - 1, RAIL_DK)
  -- Track B: diagonal from top-right to bottom-left
  H.line(img, 46, plat_top + 2, 16, plat_mid - 1, RAIL_DK)
  H.line(img, 47, plat_top + 2, 17, plat_mid - 1, RAIL_DK)

  -- Center crossing bolt plate
  local ccx, ccy = 31, plat_top + 4
  H.rect(img, ccx - 3, ccy - 2, ccx + 3, ccy + 2, RAIL_LT)
  H.rect_outline(img, ccx - 3, ccy - 2, ccx + 3, ccy + 2, RAIL_DK)
  -- Cross on plate
  H.px(img, ccx, ccy, RAIL)
  H.px(img, ccx-1, ccy-1, RAIL)
  H.px(img, ccx+1, ccy-1, RAIL)
  H.px(img, ccx-1, ccy+1, RAIL)
  H.px(img, ccx+1, ccy+1, RAIL)

  -- Corner rivets
  H.px(img, ccx - 2, ccy - 1, C.rivet)
  H.px(img, ccx + 2, ccy - 1, C.rivet)
  H.px(img, ccx - 2, ccy + 1, C.rivet)
  H.px(img, ccx + 2, ccy + 1, C.rivet)

  -- Guard posts at track entries (4 corners, extending into elevation zone)
  local guard_posts = {
    {12, 8, 18},   -- back-left
    {50, 8, 18},   -- back-right
  }
  for _, gp in ipairs(guard_posts) do
    local gx, gy_top, gy_bot = gp[1], gp[2], gp[3]
    for y = gy_top, gy_bot do
      H.px(img, gx, y, RAIL)
      H.px(img, gx + 1, y, RAIL_DK)
    end
    H.px(img, gx, gy_top, RAIL_LT)
    H.px(img, gx + 1, gy_top, RAIL)
  end

  -- Direction indicators (alternate which track is highlighted)
  if phase % 2 == 0 then
    H.px(img, 20, plat_top + 1, C.conv_yellow)
    H.px(img, 42, plat_mid - 2, C.conv_yellow)
  else
    H.px(img, 42, plat_top + 1, C.conv_yellow)
    H.px(img, 20, plat_mid - 2, C.conv_yellow)
  end
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr, DIR, "main")
print("[junction] done")
