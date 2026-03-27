-- battery_sprite.lua
-- Top-down battery: energy storage block with charge indicator.
-- 2 layers (base, top), 4 frames with subtle charge pulse.

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, FH = 32, 32
local LAYERS = {"base", "top"}
local TAGS = {
  {name="default", from=1, to=4, duration=0.4},
}
local DIR = "/Users/gorishniymax/Repos/factor/buildings/battery/sprites"

-- Battery identity: dark green-teal casing
local CASE    = H.hex("#2A4038")
local CASE_DK = H.hex("#1A3028")
local CASE_LT = H.hex("#3A5048")
local TERM    = H.hex("#808880")
local TERM_BR = H.hex("#A0A8A0")
local CHARGE  = H.hex("#4CAF50")
local CHG_DK  = H.hex("#388E3C")
local CHG_BR  = H.hex("#66BB6A")
local BOLT    = H.hex("#FFD232")
local BOLT_DM = H.hex("#C8A028")

local function draw_base(img, tag, phase)
  -- Outer casing
  H.rect_outline(img, 0, 0, 31, 31, C.outline)
  H.rect(img, 1, 1, 30, 30, CASE)
  H.shaded_rect(img, 2, 2, 29, 29, CASE, CASE_LT, CASE_DK)
  -- Terminal nubs (top center)
  H.rect(img, 13, 1, 18, 3, TERM)
  H.line(img, 14, 1, 17, 1, TERM_BR)
  -- Inner fill area background
  H.rect(img, 4, 6, 27, 27, CASE_DK)
  -- Charge fill (shown as half-full static indicator)
  H.rect(img, 5, 16, 26, 26, CHG_DK)
  H.rect(img, 5, 18, 26, 26, CHARGE)
  -- Segment dividers (4 cells)
  for y = 11, 26, 5 do
    H.line(img, 4, y, 27, y, CASE)
  end
  -- Corner rivets
  for _, p in ipairs({{3,4},{28,4},{3,28},{28,28}}) do
    H.px(img, p[1], p[2], C.rivet)
  end
end

local function draw_top(img, tag, phase)
  -- Lightning bolt symbol (centered)
  local cx = 15
  -- Bolt shape: zig-zag
  -- Top segment
  H.line(img, cx+1, 8, cx-1, 14, BOLT)
  H.line(img, cx+2, 8, cx, 14, BOLT)
  -- Middle bar
  H.line(img, cx-2, 14, cx+2, 14, BOLT)
  -- Bottom segment
  H.line(img, cx, 14, cx-2, 22, BOLT)
  H.line(img, cx+1, 14, cx-1, 22, BOLT)
  -- Pulse glow around bolt (phase-dependent)
  if phase == 0 or phase == 2 then
    H.px(img, cx, 10, BOLT_DM)
    H.px(img, cx, 20, BOLT_DM)
  end
  if phase == 1 then
    H.px(img, cx+2, 12, BOLT_DM)
    H.px(img, cx-2, 18, BOLT_DM)
  end
  -- Terminal highlight
  H.px(img, 15, 2, TERM_BR)
  H.px(img, 16, 2, TERM_BR)
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr, DIR, "main")
print("[battery] done")
