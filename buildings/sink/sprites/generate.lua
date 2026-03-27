-- sink_sprite.lua
-- Top-down sink: test item consumer, red-accented grating with intake pit.
-- 2 layers (base, top), 4 frames.

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, FH = 32, 32
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

local function draw_base(img, tag, phase)
  -- Red box with intake on left
  H.rect_outline(img, 0, 0, 31, 31, C.outline)
  H.rect(img, 1, 1, 30, 30, SINK)
  H.shaded_rect(img, 2, 2, 29, 29, SINK, SINK_LT, SINK_DK)
  -- Input chute (left edge)
  H.rect(img, 1, 12, 6, 19, C.panel_inner)
  H.line(img, 6, 11, 6, 20, SINK_DK)
  H.rect(img, 1, 14, 3, 17, C.conv_base)
  -- Central intake pit (dark grating)
  H.bordered_rect(img, 8, 6, 27, 25, C.chamber, SINK_DK)
  H.rect(img, 9, 7, 26, 24, C.chamber_deep)
  -- Grate bars (horizontal)
  for y = 9, 22, 4 do
    H.line(img, 9, y, 26, y, C.grate)
  end
  -- Grate bars (vertical)
  for x = 13, 22, 5 do
    H.line(img, x, 7, x, 24, C.grate)
  end
  -- Swirling indicator (items being consumed)
  local cx, cy = 17, 15
  local dirs = {{1,0},{0,1},{-1,0},{0,-1}}
  local d = dirs[(phase % 4) + 1]
  H.px(img, cx + d[1]*2, cy + d[2]*2, SINK_BR)
  H.px(img, cx - d[1]*3, cy + d[2]*3, SINK_LT)
  -- Corner bolts
  for _, p in ipairs({{3,3},{28,3},{3,28},{28,28}}) do
    H.px(img, p[1], p[2], C.rivet)
  end
end

local function draw_top(img, tag, phase)
  -- Input arrow (pointing inward)
  H.px(img, 3, 15, C.conv_yellow)
  H.px(img, 4, 15, C.conv_yellow)
  H.px(img, 5, 15, C.conv_yellow)
  H.px(img, 3, 16, C.conv_yellow)
  H.px(img, 4, 16, C.conv_yellow)
  H.px(img, 5, 16, C.conv_yellow)
  -- Funnel rim around intake
  H.rect_outline(img, 8, 6, 27, 25, SINK_LT)
  -- "X" disposal marker in corner
  H.px(img, 25, 3, SINK_BR)
  H.px(img, 26, 4, SINK_BR)
  H.px(img, 26, 3, SINK_BR)
  H.px(img, 25, 4, SINK_BR)
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr, DIR, "main")
print("[sink] done")
