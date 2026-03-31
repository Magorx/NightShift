-- Generate Fabricator sprites (3x3 bbox = 96x96 pixels, T-shaped)
-- Cells occupied: (0,0)(1,0)(2,0)(1,1)(1,2)
-- Non-occupied cells (0,1)(2,1)(0,2)(2,2) are transparent
-- 2 layers (base, top), tags: idle(2f), windup(2f), active(4f), winddown(2f)

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, HH = 96, 96
local CELL = 32

local tags = {
  {name="idle",     from=1, to=2,  duration=0.5},
  {name="windup",   from=3, to=4,  duration=0.167},
  {name="active",   from=5, to=8,  duration=0.167},
  {name="winddown", from=9, to=10, duration=0.167},
}

local spr, layers = H.new_sprite(W, HH, {"base", "top"}, tags)

-- Occupied cells: (0,0)(1,0)(2,0)(1,1)(1,2) — T shape
local function in_shape(px, py)
  local cx = math.floor(px / CELL)
  local cy = math.floor(py / CELL)
  if cy == 0 then return true end           -- top row all 3
  if cx == 1 and cy <= 2 then return true end  -- center column
  return false
end

local function safe_rect(img, x1, y1, x2, y2, c)
  for y = math.max(0, y1), math.min(img.height - 1, y2) do
    for x = math.max(0, x1), math.min(img.width - 1, x2) do
      if in_shape(x, y) then img:drawPixel(x, y, c) end
    end
  end
end

local function safe_px(img, x, y, c)
  if x >= 0 and x < img.width and y >= 0 and y < img.height and in_shape(x, y) then
    img:drawPixel(x, y, c)
  end
end

-- Colors: purple-gray, precision assembly
local body      = H.hex("#38303E")
local body_lt   = H.hex("#483E50")
local body_dk   = H.hex("#282230")
local panel     = H.hex("#302A36")
local panel_dk  = H.hex("#241E2A")
local metal     = H.hex("#585068")
local metal_dk  = H.hex("#484058")
local arm_base  = H.hex("#504868")
local arm_ext   = H.hex("#6A6088")
local arm_tip   = H.hex("#8878A8")
local arm_glow  = H.hex("#AA90D0")
local dark      = H.hex("#141018")
local chamber   = H.hex("#100C14")
local rivet     = H.hex("#5A5268")
local glow_off  = H.hex("#3A3248")
local glow_on   = H.hex("#7766AA")
local glow_hot  = H.hex("#9988CC")
local work_bed  = H.hex("#1E1A24")

H.render_frames(spr, layers, tags, function(img, layer, fi, tag, phase)
  if layer == "base" then
    -- Top row (3 cells)
    H.shaded_rect(img, 1, 1, 94, 30, body, body_lt, body_dk)
    H.rect_outline(img, 0, 0, 95, 31, dark)

    -- Center column cell (1,1)
    H.shaded_rect(img, 33, 32, 62, 62, body, body_lt, body_dk)
    H.rect_outline(img, 32, 32, 63, 63, dark)
    safe_px(img, 32, 31, dark)
    safe_px(img, 63, 31, dark)

    -- Center column cell (1,2)
    H.shaded_rect(img, 33, 64, 62, 94, body, body_lt, body_dk)
    H.rect_outline(img, 32, 64, 63, 95, dark)
    safe_px(img, 32, 63, dark)
    safe_px(img, 63, 63, dark)

    -- Input panels on top row (left and right sides)
    safe_rect(img, 2, 4, 10, 28, panel)
    safe_rect(img, 85, 4, 94, 28, panel)

    -- IO openings on top row
    safe_rect(img, 0, 10, 3, 22, chamber)     -- left input
    safe_rect(img, 92, 10, 95, 22, chamber)    -- right input

    -- Work bed in center column
    safe_rect(img, 36, 36, 60, 90, work_bed)
    safe_rect(img, 38, 38, 58, 88, chamber)

    -- Assembly track rails
    safe_rect(img, 40, 36, 42, 90, panel_dk)
    safe_rect(img, 54, 36, 56, 90, panel_dk)

    -- Central processing area in top row
    safe_rect(img, 20, 6, 76, 26, panel_dk)
    safe_rect(img, 22, 8, 74, 24, chamber)

    -- Feed channels from top row into center column
    safe_rect(img, 44, 26, 52, 36, panel_dk)

    -- Output at bottom
    safe_rect(img, 44, 92, 52, 95, chamber)

    -- Rivets
    safe_px(img, 2, 2, rivet)
    safe_px(img, 93, 2, rivet)
    safe_px(img, 2, 29, rivet)
    safe_px(img, 93, 29, rivet)
    safe_px(img, 34, 34, rivet)
    safe_px(img, 61, 34, rivet)
    safe_px(img, 34, 93, rivet)
    safe_px(img, 61, 93, rivet)

  elseif layer == "top" then
    -- Top row frame
    safe_rect(img, 0, 0, 95, 1, metal_dk)
    safe_rect(img, 0, 30, 95, 31, metal_dk)
    safe_rect(img, 0, 0, 1, 31, metal_dk)
    safe_rect(img, 94, 0, 95, 31, metal_dk)

    -- Center column frames
    safe_rect(img, 32, 32, 33, 95, metal_dk)
    safe_rect(img, 62, 32, 63, 95, metal_dk)
    safe_rect(img, 32, 94, 63, 95, metal_dk)

    -- Input casings
    safe_rect(img, 2, 2, 14, 29, body)
    H.rect_outline(img, 2, 2, 14, 29, metal_dk)
    safe_rect(img, 4, 6, 12, 27, panel_dk)

    safe_rect(img, 81, 2, 93, 29, body)
    H.rect_outline(img, 81, 2, 93, 29, metal_dk)
    safe_rect(img, 83, 6, 91, 27, panel_dk)

    -- Gate openings
    safe_rect(img, 0, 10, 2, 22, chamber)
    safe_rect(img, 93, 10, 95, 22, chamber)
    safe_rect(img, 44, 93, 52, 95, chamber)

    -- Assembly area cover
    safe_rect(img, 36, 36, 60, 88, panel)
    H.rect_outline(img, 36, 36, 60, 88, metal_dk)

    -- Robotic arms (animated)
    if tag == "idle" then
      local bob = phase == 0 and 0 or 1
      -- Left arm
      safe_rect(img, 38, 44 + bob, 46, 52 + bob, arm_base)
      safe_px(img, 42, 48 + bob, arm_tip)
      -- Right arm
      safe_rect(img, 50, 44 + bob, 58, 52 + bob, arm_base)
      safe_px(img, 54, 48 + bob, arm_tip)
      safe_px(img, 48, 40, glow_off)

    elseif tag == "windup" then
      local ext = phase * 4
      -- Arms extending down
      safe_rect(img, 38, 44, 46, 52 + ext, arm_base)
      safe_rect(img, 50, 44, 58, 52 + ext, arm_base)
      safe_px(img, 42, 50 + ext, arm_tip)
      safe_px(img, 54, 50 + ext, arm_tip)
      safe_px(img, 48, 40, H.lerp_color(glow_off, glow_on, phase * 0.5))

    elseif tag == "active" then
      -- Arms working at different positions
      local positions = {
        {0, 0},   -- center
        {-4, 6},  -- left-down
        {4, 12},  -- right-far
        {0, 6},   -- center-down
      }
      local p = positions[phase + 1]

      -- Left arm
      safe_rect(img, 38 + p[1], 44 + p[2], 46 + p[1], 52 + p[2], arm_base)
      safe_rect(img, 40 + p[1], 46 + p[2], 44 + p[1], 50 + p[2], arm_ext)
      safe_px(img, 42 + p[1], 48 + p[2], arm_tip)

      -- Right arm (mirror)
      safe_rect(img, 50 - p[1], 44 + p[2], 58 - p[1], 52 + p[2], arm_base)
      safe_rect(img, 52 - p[1], 46 + p[2], 56 - p[1], 50 + p[2], arm_ext)
      safe_px(img, 54 - p[1], 48 + p[2], arm_tip)

      -- Sparks at work point
      if phase == 0 or phase == 2 then
        safe_px(img, 48, 50 + p[2], arm_glow)
        safe_px(img, 47, 49 + p[2], glow_hot)
      end
      safe_px(img, 48, 40, glow_on)

    elseif tag == "winddown" then
      local ext = (1 - phase) * 6
      safe_rect(img, 38, 44 + ext, 46, 52 + ext, arm_base)
      safe_rect(img, 50, 44 + ext, 58, 52 + ext, arm_base)
      safe_px(img, 42, 50 + ext, arm_tip)
      safe_px(img, 54, 50 + ext, arm_tip)
      safe_px(img, 48, 40, H.lerp_color(glow_on, glow_off, phase * 0.5))
    end

    -- Rivets
    safe_px(img, 3, 3, rivet)
    safe_px(img, 92, 3, rivet)
    safe_px(img, 3, 28, rivet)
    safe_px(img, 92, 28, rivet)
    safe_px(img, 34, 34, rivet)
    safe_px(img, 61, 34, rivet)
    safe_px(img, 34, 92, rivet)
    safe_px(img, 61, 92, rivet)
  end
end)

local dir = "/Users/gorishniymax/Repos/factor/buildings/fabricator/sprites"
H.save_and_export(spr, dir, "main")
print("[fabricator] done")
