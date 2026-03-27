-- source_sprite.lua
-- Top-down source: test item producer, green-accented box with output chute.
-- 2 layers (base, top), 4 frames.

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, FH = 32, 32
local LAYERS = {"base", "top"}
local TAGS = {
  {name="default", from=1, to=4, duration=0.3},
}
local DIR = "/Users/gorishniymax/Repos/factor/buildings/source/sprites"

-- Source identity: green
local SRC     = H.hex("#2D6B3F")
local SRC_DK  = H.hex("#1D5B2F")
local SRC_LT  = H.hex("#3D7B4F")
local SRC_BR  = H.hex("#4D9B5F")

local function draw_base(img, tag, phase)
  -- Green box with output chute on right
  H.rect_outline(img, 0, 0, 31, 31, C.outline)
  H.rect(img, 1, 1, 30, 30, SRC)
  H.shaded_rect(img, 2, 2, 29, 29, SRC, SRC_LT, SRC_DK)
  -- Inner panel
  H.bordered_rect(img, 4, 4, 24, 27, C.panel, SRC_DK)
  -- Output chute (right edge)
  H.rect(img, 25, 12, 30, 19, C.panel_inner)
  H.line(img, 25, 11, 25, 20, SRC_DK)
  H.rect(img, 28, 14, 30, 17, C.conv_base)
  -- Pulsing item indicator inside
  local pulse = (phase % 2 == 0) and SRC_BR or SRC_LT
  H.circle(img, 13, 15, 4, C.panel_inner)
  H.circle(img, 13, 15, 3, pulse)
  H.circle(img, 13, 15, 1, SRC_BR)
  -- Corner bolts
  for _, p in ipairs({{3,3},{28,3},{3,28},{28,28}}) do
    H.px(img, p[1], p[2], C.rivet)
  end
end

local function draw_top(img, tag, phase)
  -- Output arrow
  H.px(img, 26, 15, C.conv_yellow)
  H.px(img, 27, 15, C.conv_yellow)
  H.px(img, 28, 15, C.conv_yellow)
  H.px(img, 26, 16, C.conv_yellow)
  H.px(img, 27, 16, C.conv_yellow)
  H.px(img, 28, 16, C.conv_yellow)
  -- "S" letter indicator (top-left)
  H.px(img, 6, 6, SRC_BR)
  H.px(img, 7, 6, SRC_BR)
  H.px(img, 5, 7, SRC_BR)
  H.px(img, 6, 8, SRC_BR)
  H.px(img, 7, 9, SRC_BR)
  H.px(img, 5, 10, SRC_BR)
  H.px(img, 6, 10, SRC_BR)
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr, DIR, "main")
print("[source] done")
