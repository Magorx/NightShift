-- hand_assembler_sprite.lua
-- Top-down manual workbench: wooden surface with tools.
-- 1x1 tile (32x32 per frame), 2 layers, 10 frames:
-- idle(2) + windup(2) + active(4) + winddown(2).

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
local DIR = "/Users/gorishniymax/Repos/factor/buildings/hand_assembler/sprites"

-- Workbench identity colors
local WOOD      = H.hex("#7A5C3A")
local WOOD_LT   = H.hex("#8E6E48")
local WOOD_DK   = H.hex("#5A4228")
local WOOD_EDGE = H.hex("#4A3420")
local PLANK     = H.hex("#6E5234")
local TOOL_METAL = H.hex("#8890A0")
local TOOL_DK    = H.hex("#606878")
local HANDLE     = H.hex("#5A3818")

local function draw_base(img, tag, phase)
  -- Workbench surface
  H.rect_outline(img, 0, 0, 31, 31, C.outline)
  H.rect(img, 1, 1, 30, 30, WOOD)
  H.shaded_rect(img, 2, 2, 29, 29, WOOD, WOOD_LT, WOOD_DK)

  -- Plank grain lines (horizontal)
  for y = 6, 26, 5 do
    H.line(img, 2, y, 29, y, PLANK)
  end

  -- Edge trim
  H.line(img, 1, 1, 30, 1, WOOD_EDGE)
  H.line(img, 1, 30, 30, 30, WOOD_EDGE)

  -- Corner leg posts
  for _, p in ipairs({{2,2},{29,2},{2,29},{29,29}}) do
    H.px(img, p[1], p[2], WOOD_DK)
  end

  -- Small vise/clamp on left edge
  H.rect(img, 1, 12, 4, 19, TOOL_DK)
  H.rect(img, 2, 13, 3, 18, TOOL_METAL)

  -- Crafting activity indicator
  if tag == "active" then
    -- Sparks from hammering
    local sparks = {{14+phase,10},{18-phase,22},{12,14+phase},{20,18-phase}}
    for i, s in ipairs(sparks) do
      if (i + phase) % 2 == 0 then
        H.px(img, s[1], s[2], C.fire_inner)
      end
    end
  elseif tag == "windup" then
    if phase == 1 then
      H.px(img, 16, 16, C.fire_dim)
    end
  elseif tag == "winddown" then
    if phase == 0 then
      H.px(img, 15, 15, C.fire_dim)
      H.px(img, 17, 17, C.ember)
    end
  end
end

local function draw_top(img, tag, phase)
  -- Hammer tool (center-right)
  -- Handle
  H.line(img, 18, 8, 18, 16, HANDLE)
  -- Head
  H.rect(img, 16, 6, 20, 8, TOOL_METAL)
  H.px(img, 16, 7, TOOL_DK)
  H.px(img, 20, 7, TOOL_DK)

  -- Wrench (bottom left area)
  H.line(img, 8, 20, 8, 27, TOOL_METAL)
  H.px(img, 7, 20, TOOL_METAL)
  H.px(img, 9, 20, TOOL_METAL)
  H.px(img, 7, 21, TOOL_DK)
  H.px(img, 9, 21, TOOL_DK)

  -- Small nail/pin
  H.px(img, 24, 14, TOOL_METAL)
  H.px(img, 24, 15, TOOL_DK)

  -- Bolt accents
  for _, p in ipairs({{4,4},{27,4},{4,27},{27,27}}) do
    H.px(img, p[1], p[2], C.rivet)
  end

  -- Active: tool motion blur
  if tag == "active" then
    local off = (phase % 2 == 0) and -1 or 1
    H.px(img, 18 + off, 7, TOOL_METAL)
  end
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr, DIR, "main")
print("[hand_assembler] done")
