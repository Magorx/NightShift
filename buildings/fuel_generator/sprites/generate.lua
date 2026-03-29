-- fuel_generator_sprite.lua
-- Top-down fuel generator: 2x2 tiles (64x64 per frame), dark copper industrial.
-- Burns coke for high-output power. Turbine with exhaust pipes and power coils.
-- 2 layers (base, top), 10 frames: idle(2) + windup(2) + active(4) + winddown(2).

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, FH = 64, 64
local LAYERS = {"base", "top"}
local TAGS = {
  {name="idle",     from=1, to=2, duration=0.5},
  {name="windup",   from=3, to=4, duration=0.15},
  {name="active",   from=5, to=8, duration=0.15},
  {name="winddown", from=9, to=10, duration=0.15},
}
local DIR = "/Users/gorishniymax/Repos/factor/buildings/fuel_generator/sprites"

-- Fuel generator identity: dark copper tones
local COPPER     = H.hex("#806050")
local COPPER_DK  = H.hex("#5A4030")
local COPPER_LT  = H.hex("#A07860")
local COIL       = H.hex("#C8A020")
local COIL_DK    = H.hex("#907818")
local COIL_GLOW  = H.hex("#FFD840")
local TURBINE    = H.hex("#607080")
local TURBINE_DK = H.hex("#485868")
local TURBINE_LT = H.hex("#7888A0")
local EXHAUST    = H.hex("#403830")
local EXHAUST_DK = H.hex("#302820")

local function draw_base(img, tag, phase)
  -- Overall outline
  H.rect_outline(img, 0, 0, 63, 63, C.outline)
  -- Inner grid lines
  H.line(img, 31, 0, 31, 63, C.outline)
  H.line(img, 0, 31, 63, 31, C.outline)

  -- Fill all 4 cells
  H.rect(img, 1, 1, 30, 30, COPPER_DK)
  H.rect(img, 32, 1, 62, 30, COPPER_DK)
  H.rect(img, 1, 32, 30, 62, COPPER_DK)
  H.rect(img, 32, 32, 62, 62, COPPER_DK)

  -- Inner panels
  H.rect(img, 2, 2, 29, 29, COPPER)
  H.rect(img, 33, 2, 61, 29, COPPER)
  H.rect(img, 2, 33, 29, 61, COPPER)
  H.rect(img, 33, 33, 61, 61, COPPER)

  -- Central turbine chamber (spans all 4 cells)
  local cx, cy = 31, 31
  H.circle(img, cx, cy, 18, C.chamber)
  H.circle(img, cx, cy, 17, C.chamber_deep)

  if tag == "active" then
    -- Spinning turbine blades
    H.circle(img, cx, cy, 16, TURBINE_DK)
    -- 4 blade positions that rotate
    local blades = {
      {{0,-1},{0,-5},{0,-9},{0,-13}},
      {{1,0},{5,0},{9,0},{13,0}},
      {{0,1},{0,5},{0,9},{0,13}},
      {{-1,0},{-5,0},{-9,0},{-13,0}},
    }
    local diag_blades = {
      {{-1,-1},{-3,-3},{-6,-6},{-9,-9}},
      {{1,-1},{3,-3},{6,-6},{9,-9}},
      {{1,1},{3,3},{6,6},{9,9}},
      {{-1,1},{-3,3},{-6,6},{-9,9}},
    }
    local use = (phase % 2 == 0) and blades or diag_blades
    for _, blade in ipairs(use) do
      for _, p in ipairs(blade) do
        H.px(img, cx+p[1], cy+p[2], TURBINE)
        H.px(img, cx+p[1]+1, cy+p[2], TURBINE_DK)
      end
    end
    -- Core glow
    H.circle(img, cx, cy, 3, C.fire_mid)
    H.circle(img, cx, cy, 1, C.fire_inner)
  elseif tag == "windup" then
    H.circle(img, cx, cy, 16, TURBINE_DK)
    if phase == 1 then
      H.circle(img, cx, cy, 3, C.ember)
      H.px(img, cx, cy, C.fire_dim)
    end
  elseif tag == "winddown" then
    H.circle(img, cx, cy, 16, TURBINE_DK)
    if phase == 0 then
      H.circle(img, cx, cy, 2, C.ember)
    end
  else
    -- Idle: dark turbine
    H.circle(img, cx, cy, 16, TURBINE_DK)
    H.circle(img, cx, cy, 3, TURBINE)
    H.px(img, cx, cy, TURBINE_LT)
  end

  -- Fuel intake (left side, top and bottom cells)
  H.rect(img, 0, 12, 3, 19, C.panel_inner)
  H.rect(img, 0, 44, 3, 51, C.panel_inner)

  -- Corner rivets
  for _, p in ipairs({{3,3},{60,3},{3,60},{60,60},{3,28},{60,28},{3,35},{60,35}}) do
    H.px(img, p[1], p[2], C.rivet)
  end
end

local function draw_top(img, tag, phase)
  local cx, cy = 31, 31

  -- Turbine rim (always visible)
  H.circle_outline(img, cx, cy, 17, C.rim)
  H.circle_outline(img, cx, cy, 18, C.outline)

  -- Power output coils (right side, top-right corner area)
  local coil_color = COIL_DK
  if tag == "active" then
    coil_color = (phase % 2 == 0) and COIL_GLOW or COIL
  elseif tag == "windup" and phase == 1 then
    coil_color = COIL
  end

  -- Top-right coil cluster
  H.rect(img, 52, 4, 58, 8, coil_color)
  H.rect_outline(img, 52, 4, 58, 8, COIL_DK)
  -- Bottom-right coil cluster
  H.rect(img, 52, 55, 58, 59, coil_color)
  H.rect_outline(img, 52, 55, 58, 59, COIL_DK)

  -- Exhaust pipes (top side)
  H.rect(img, 10, 1, 14, 5, EXHAUST)
  H.rect_outline(img, 10, 1, 14, 5, EXHAUST_DK)
  H.px(img, 12, 3, C.chamber_deep)

  H.rect(img, 20, 1, 24, 5, EXHAUST)
  H.rect_outline(img, 20, 1, 24, 5, EXHAUST_DK)
  H.px(img, 22, 3, C.chamber_deep)

  -- Smoke from exhaust when active
  if tag == "active" or tag == "windup" then
    local o = (phase % 2 == 0) and 0 or 1
    H.px(img, 12 + o, 0, C.smoke_dark)
    H.px(img, 22 - o, 0, C.smoke_mid)
  end

  -- Housing bolts
  for _, p in ipairs({{5,5},{58,5},{5,58},{58,58}}) do
    H.px(img, p[1], p[2], COPPER_LT)
  end

  -- Center hub cap
  H.circle(img, cx, cy, 4, TURBINE)
  H.circle_outline(img, cx, cy, 4, TURBINE_DK)
  H.px(img, cx, cy, TURBINE_LT)
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr, DIR, "main")
print("[fuel_generator] done")
