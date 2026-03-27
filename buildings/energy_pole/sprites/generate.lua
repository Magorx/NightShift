-- energy_pole_sprite.lua
-- Top-down energy pole: relay tower with cross arms and insulators.
-- 2 layers (base, top), 4 frames with pulsing glow.

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, FH = 32, 32
local LAYERS = {"base", "top"}
local TAGS = {
  {name="default", from=1, to=4, duration=0.3},
}
local DIR = "/Users/gorishniymax/Repos/factor/buildings/energy_pole/sprites"

-- Energy pole identity: steel blue with electric accents
local POLE   = H.hex("#5A6878")
local POLE_DK= H.hex("#4A5868")
local POLE_LT= H.hex("#6A7888")
local BASE   = H.hex("#505A60")
local BASE_DK= H.hex("#404A50")
local ELEC   = H.hex("#FFD232")
local ELEC_DM= H.hex("#C8A028")
local ELEC_BR= H.hex("#FFE878")
local INS    = H.hex("#3A7ABB")
local INS_BR = H.hex("#4A9ADB")

local function draw_base(img, tag, phase)
  -- Concrete/metal base pad
  H.rect_outline(img, 0, 0, 31, 31, C.outline)
  H.rect(img, 1, 1, 30, 30, C.body)
  H.rect(img, 2, 2, 29, 29, C.panel)
  -- Base plate (octagonal-ish)
  H.rect(img, 8, 8, 23, 23, BASE)
  H.rect(img, 10, 6, 21, 25, BASE)
  H.rect(img, 6, 10, 25, 21, BASE)
  H.rect_outline(img, 8, 8, 23, 23, BASE_DK)
  -- Corner bolt details
  for _, p in ipairs({{3,3},{28,3},{3,28},{28,28}}) do
    H.px(img, p[1], p[2], C.rivet)
  end
end

local function draw_top(img, tag, phase)
  local cx, cy = 15, 15
  -- Pole shaft (center dot)
  H.circle(img, cx, cy, 2, POLE)
  H.px(img, cx, cy, POLE_LT)
  -- Cross arms
  H.line(img, cx-8, cy, cx+8, cy, POLE_DK)
  H.line(img, cx, cy-8, cx, cy+8, POLE_DK)
  H.line(img, cx-8, cy, cx+8, cy, POLE)
  H.line(img, cx, cy-8, cx, cy+8, POLE)
  -- Insulators at arm ends (4 dots that pulse)
  local glow = (phase == 0 or phase == 2) and INS_BR or INS
  for _, p in ipairs({{cx-7,cy},{cx+7,cy},{cx,cy-7},{cx,cy+7}}) do
    H.px(img, p[1], p[2], glow)
    H.px(img, p[1]-1, p[2], INS)
    H.px(img, p[1]+1, p[2], INS)
    H.px(img, p[1], p[2]-1, INS)
    H.px(img, p[1], p[2]+1, INS)
  end
  -- Center energy glow (pulses)
  local center_glow = (phase % 2 == 0) and ELEC_BR or ELEC
  H.px(img, cx, cy, center_glow)
  -- Diagonal braces
  for i = 1, 3 do
    H.px(img, cx-i, cy-i, POLE_DK)
    H.px(img, cx+i, cy-i, POLE_DK)
    H.px(img, cx-i, cy+i, POLE_DK)
    H.px(img, cx+i, cy+i, POLE_DK)
  end
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr, DIR, "main")
print("[energy_pole] done")
