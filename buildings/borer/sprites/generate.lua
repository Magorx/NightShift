-- borer_sprite.lua
-- Top-down borer: wall resource extractor with grinding wheel.
-- Faces RIGHT in default orientation: grinding end on right, output chute on left.
-- 2 layers (base, top), 10 frames: idle(2) + windup(2) + active(4) + winddown(2).

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, FH = 32, 32
local LAYERS = {"base", "top"}
local TAGS = {
  {name="idle",     from=1, to=2, duration=0.5},
  {name="windup",   from=3, to=4, duration=0.15},
  {name="active",   from=5, to=8, duration=0.15},
  {name="winddown", from=9, to=10, duration=0.15},
}
local DIR = "/Users/gorishniymax/Repos/factor/buildings/borer/sprites"

-- Borer identity colors: earthy brown-tan (wall mining machine)
local HOUSING     = H.hex("#6B5843")
local HOUSING_DK  = H.hex("#53442F")
local HOUSING_LT  = H.hex("#7D6A52")
local WHEEL       = H.hex("#8A7A6A")
local WHEEL_DK    = H.hex("#6B5F50")
local WHEEL_EDGE  = H.hex("#9A8C7C")
local STONE_CHIP  = H.hex("#8C8880")
local STONE_DUST  = H.hex("#A09C96")

local function draw_base(img, tag, phase)
  -- Outline and body
  H.rect_outline(img, 0, 0, 31, 31, C.outline)
  H.rect(img, 1, 1, 30, 30, C.body)
  H.rect(img, 2, 2, 29, 29, C.panel)

  -- Machine housing (left-center area)
  H.rect(img, 3, 4, 20, 27, HOUSING_DK)
  H.rect(img, 4, 5, 19, 26, HOUSING)

  -- Output chute on left side
  H.rect(img, 1, 12, 4, 19, C.panel_inner)
  H.line(img, 4, 11, 4, 20, C.rim)
  -- Chute opening
  H.rect(img, 1, 13, 3, 18, C.chamber)

  -- Grinding chamber on right side
  H.rect(img, 21, 3, 30, 28, C.chamber)
  H.rect(img, 22, 4, 29, 27, C.chamber_deep)

  if tag == "active" then
    -- Stone debris flying around in grinding chamber
    local offsets = {
      {{24,6},{27,10},{23,15},{28,20},{25,24}},
      {{26,8},{23,12},{27,17},{24,22},{26,26}},
      {{25,5},{28,14},{23,19},{27,23},{24,9}},
      {{27,7},{24,11},{26,18},{23,21},{28,25}},
    }
    local dust = offsets[(phase % 4) + 1]
    for _, p in ipairs(dust) do
      H.px(img, p[1], p[2], STONE_CHIP)
    end
    -- Dust particles
    H.px(img, 22 + (phase * 2) % 7, 7 + phase * 3 % 15, STONE_DUST)
  elseif tag == "windup" then
    if phase == 1 then
      H.px(img, 25, 12, STONE_CHIP)
      H.px(img, 26, 18, STONE_CHIP)
    end
  elseif tag == "winddown" then
    -- Settling dust
    if phase == 0 then
      H.px(img, 24, 20, STONE_CHIP)
      H.px(img, 27, 24, STONE_DUST)
    end
  end

  -- Corner rivets
  for _, p in ipairs({{3,3},{28,3},{3,28},{28,28}}) do
    H.px(img, p[1], p[2], C.rivet)
  end

  -- Motor housing detail
  H.rect(img, 8, 8, 16, 23, HOUSING_DK)
  H.rect(img, 9, 9, 15, 22, HOUSING)
  -- Motor bolts
  H.px(img, 9, 9, C.rivet)
  H.px(img, 15, 9, C.rivet)
  H.px(img, 9, 22, C.rivet)
  H.px(img, 15, 22, C.rivet)
end

local function draw_top(img, tag, phase)
  -- Grinding wheel (right side, partially overlapping chamber)
  local cx, cy = 25, 15

  local function draw_wheel(rot)
    -- Wheel disc
    H.circle(img, cx, cy, 8, WHEEL_DK)
    H.circle(img, cx, cy, 7, WHEEL)

    -- Grinding teeth (rotate based on phase)
    local teeth_cardinal = {
      {{0,-6},{0,-5}}, {{0,6},{0,5}},
      {{-6,0},{-5,0}}, {{6,0},{5,0}},
    }
    local teeth_diagonal = {
      {{-4,-4},{-3,-3}}, {{4,-4},{3,-3}},
      {{-4,4},{-3,3}}, {{4,4},{3,3}},
    }
    local use_teeth = (rot % 2 == 0) and teeth_cardinal or teeth_diagonal
    for _, tooth in ipairs(use_teeth) do
      for _, p in ipairs(tooth) do
        H.px(img, cx+p[1], cy+p[2], WHEEL_EDGE)
      end
    end

    -- Center axle
    H.circle(img, cx, cy, 2, HOUSING_DK)
    H.px(img, cx, cy, HOUSING_LT)
  end

  if tag == "active" then
    draw_wheel(phase)
  elseif tag == "windup" then
    draw_wheel(0)
    if phase == 1 then
      H.px(img, cx+1, cy-1, HOUSING_LT)
    end
  elseif tag == "winddown" then
    draw_wheel(0)
    if phase == 0 then
      H.px(img, cx-1, cy+1, HOUSING_LT)
    end
  else
    -- Idle
    draw_wheel(0)
  end

  -- Wheel rim outline
  H.circle_outline(img, cx, cy, 8, C.rim)

  -- Drive shaft from motor to wheel
  H.line(img, 16, 15, 19, 15, HOUSING_DK)
  H.line(img, 16, 16, 19, 16, HOUSING)
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr, DIR, "main")
print("[borer] done")
