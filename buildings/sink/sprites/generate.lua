-- generate.lua -- Isometric sink: test item consumer
-- 64x48: bottom 32px = isometric diamond, top 16px = elevation
-- 2 layers (base, top), 4 frames: default(4)
--
-- Red intake pit with grate, raised rim on diamond base

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, FH = 64, 48
local LAYERS = {"base", "top"}
local TAGS = {
  {name="default", from=1, to=4, duration=0.3},
}
local DIR = "/Users/gorishniymax/Repos/factor/buildings/sink/sprites"

-- Sink identity: dark red
local SINK    = H.hex("#6B2D2D")
local SINK_DK = H.hex("#5B1D1D")
local SINK_LT = H.hex("#7B3D3D")
local SINK_BR = H.hex("#9B4D4D")

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

-- =========================================================================
-- BASE LAYER: platform + deep pit interior
-- =========================================================================
local function draw_base(img, tag, phase)
  draw_diamond_base(img, C.panel, C.outline, C.body_light, C.shadow)

  -- Deep intake pit in center (visible through grate on top layer)
  local pcx, pcy = 31, 32
  H.circle(img, pcx, pcy, 10, C.chamber)
  H.circle(img, pcx, pcy, 8, C.chamber_deep)

  -- Swirling consumption indicator
  local dirs = {{1,0},{0,1},{-1,0},{0,-1}}
  local d = dirs[(phase % 4) + 1]
  H.px(img, pcx + d[1]*3, pcy + d[2]*2, SINK_BR)
  H.px(img, pcx - d[1]*4, pcy + d[2]*3, SINK_LT)
  H.px(img, pcx + d[2]*2, pcy - d[1]*3, SINK_BR)
end

-- =========================================================================
-- TOP LAYER: raised rim with grate
-- =========================================================================
local function draw_top(img, tag, phase)
  local CLEAR = H.TRANSPARENT
  local pcx, pcy = 31, 32

  -- Raised rim walls around the pit (extends into elevation zone)
  -- Back wall (higher = further back in iso)
  local rim_height = 10  -- how far the rim extends above diamond surface

  -- Back rim wall (visible above diamond, y = BASE_TOP-rim_height to BASE_TOP area)
  -- Left wall segment
  for y = 8, 22 do
    local progress = (y - 8) / 14
    local xl = math.floor(20 + progress * (-4))
    local xr = math.floor(42 - progress * (-4))
    for x = xl, xr do
      -- Top portion = highlight, getting darker as we go down
      local t = progress
      local col = H.lerp_color(SINK_LT, SINK_DK, t)
      H.px(img, x, y, col)
    end
  end

  -- Front-left wall
  for y = 22, 38 do
    local progress = (y - 22) / 16
    local xl = math.floor(16 + progress * 6)
    local xr = math.floor(28 + progress * 3)
    for x = xl, xr do
      H.px(img, x, y, SINK)
    end
  end

  -- Front-right wall
  for y = 22, 38 do
    local progress = (y - 22) / 16
    local xl = math.floor(34 - progress * 3)
    local xr = math.floor(46 - progress * 6)
    for x = xl, xr do
      H.px(img, x, y, SINK_DK)
    end
  end

  -- Rim top edge (isometric diamond shape, smaller than base)
  -- Draw as outline
  H.line(img, 20, 8, 42, 8, C.outline)   -- top edge
  H.line(img, 20, 8, 14, 22, C.outline)   -- top-left to mid-left
  H.line(img, 42, 8, 48, 22, C.outline)   -- top-right to mid-right
  H.line(img, 14, 22, 22, 38, C.outline)  -- mid-left to bottom-left
  H.line(img, 48, 22, 40, 38, C.outline)  -- mid-right to bottom-right
  H.line(img, 22, 38, 40, 38, C.outline)  -- bottom front edge

  -- Inner rim highlight
  H.line(img, 21, 9, 41, 9, SINK_LT)

  -- Grate bars over the pit (horizontal + vertical in iso perspective)
  -- Horizontal bars (in iso = diagonal)
  for i = 0, 3 do
    local offset = i * 5
    local y1 = 14 + offset
    local y2 = 14 + offset
    local x1 = 22 + math.floor(offset * 0.3)
    local x2 = 40 - math.floor(offset * 0.3)
    H.line(img, x1, y1, x2, y2, C.grate)
  end

  -- Vertical bars (in iso = other diagonal)
  for i = 0, 3 do
    local offset = i * 6
    local x = 24 + offset
    H.line(img, x, 12, x + 3, 32, C.grate)
  end

  -- Clear center of pit so base shows through
  H.circle(img, pcx, pcy - 6, 5, CLEAR)

  -- Input arrow (left side)
  H.px(img, 10, 24, C.conv_yellow)
  H.px(img, 11, 24, C.conv_yellow)
  H.px(img, 12, 24, C.conv_yellow)

  -- "X" disposal marker on front rim
  H.px(img, 29, 36, SINK_BR)
  H.px(img, 30, 37, SINK_BR)
  H.px(img, 31, 36, SINK_BR)
  H.px(img, 30, 35, SINK_BR)
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr, DIR, "main")
print("[sink] done")
