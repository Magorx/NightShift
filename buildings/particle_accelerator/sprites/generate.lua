-- Generate Particle Accelerator sprites (3x3 bbox = 96x96 pixels, L-shaped)
-- Cells occupied: (0,0)(1,0)(2,0)(0,1)(0,2)
-- Non-occupied cells (1,1)(2,1)(1,2)(2,2) are transparent
-- 2 layers (base, top), tags: idle(2f), windup(2f), active(4f), winddown(2f)

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, HH = 96, 96
local CELL = 32  -- pixels per cell

local tags = {
  {name="idle",     from=1, to=2,  duration=0.5},
  {name="windup",   from=3, to=4,  duration=0.167},
  {name="active",   from=5, to=8,  duration=0.167},
  {name="winddown", from=9, to=10, duration=0.167},
}

local spr, layers = H.new_sprite(W, HH, {"base", "top"}, tags)

-- Occupied cells: (0,0)(1,0)(2,0)(0,1)(0,2)
local function in_shape(px, py)
  local cx = math.floor(px / CELL)
  local cy = math.floor(py / CELL)
  if cy == 0 then return true end  -- top row all 3
  if cx == 0 then return true end  -- left column
  return false
end

-- Safe drawing: only draw within occupied cells
local function safe_rect(img, x1, y1, x2, y2, c)
  for y = math.max(0, y1), math.min(img.height - 1, y2) do
    for x = math.max(0, x1), math.min(img.width - 1, x2) do
      if in_shape(x, y) then
        img:drawPixel(x, y, c)
      end
    end
  end
end

local function safe_px(img, x, y, c)
  if x >= 0 and x < img.width and y >= 0 and y < img.height and in_shape(x, y) then
    img:drawPixel(x, y, c)
  end
end

local function safe_line(img, x1, y1, x2, y2, c)
  -- Simple horizontal/vertical line
  if y1 == y2 then
    for x = math.min(x1, x2), math.max(x1, x2) do safe_px(img, x, y1, c) end
  elseif x1 == x2 then
    for y = math.min(y1, y2), math.max(y1, y2) do safe_px(img, x1, y, c) end
  else
    H.line(img, x1, y1, x2, y2, c)  -- diagonal, trust it's in shape
  end
end

-- Colors: deep purple, high-tech
local body      = H.hex("#2A2040")
local body_lt   = H.hex("#3A2E54")
local body_dk   = H.hex("#1C1430")
local panel     = H.hex("#241C38")
local panel_dk  = H.hex("#1A1228")
local metal     = H.hex("#504870")
local metal_dk  = H.hex("#3E3658")
local tube      = H.hex("#382C50")
local tube_lt   = H.hex("#483C64")
local tube_dk   = H.hex("#2A2040")
local beam      = H.hex("#8866CC")
local beam_lt   = H.hex("#AA88EE")
local beam_hot  = H.hex("#CC99FF")
local arc       = H.hex("#BB99FF")
local dark      = H.hex("#0E0A18")
local chamber   = H.hex("#120E1C")
local rivet     = H.hex("#5A5070")
local glow_off  = H.hex("#342850")
local glow_on   = H.hex("#7755BB")

H.render_frames(spr, layers, tags, function(img, layer, fi, tag, phase)
  if layer == "base" then
    -- L-shape body: top row (0-95, 0-31) + left column (0-31, 32-95)

    -- Top row (3 cells wide)
    H.shaded_rect(img, 1, 1, 94, 30, body, body_lt, body_dk)
    H.rect_outline(img, 0, 0, 95, 31, dark)

    -- Left column cell (0,1)
    H.shaded_rect(img, 1, 32, 30, 62, body, body_lt, body_dk)
    H.rect_outline(img, 0, 32, 31, 63, dark)
    -- Fix corner overlap
    safe_px(img, 0, 31, dark)

    -- Left column cell (0,2)
    H.shaded_rect(img, 1, 64, 30, 94, body, body_lt, body_dk)
    H.rect_outline(img, 0, 64, 31, 95, dark)
    safe_px(img, 0, 63, dark)

    -- Beam tube along the L-shape (horizontal along top, vertical down left)
    -- Horizontal tube (top row, centered at y=16)
    safe_rect(img, 4, 10, 92, 22, tube)
    safe_rect(img, 6, 12, 90, 20, tube_lt)
    safe_rect(img, 8, 14, 88, 18, chamber)

    -- Vertical tube (left column, centered at x=16)
    safe_rect(img, 10, 24, 22, 92, tube)
    safe_rect(img, 12, 26, 20, 90, tube_lt)
    safe_rect(img, 14, 28, 18, 88, chamber)

    -- Corner junction (where horizontal meets vertical)
    safe_rect(img, 10, 10, 22, 22, tube_lt)

    -- Magnet segments along horizontal tube
    for i = 0, 2 do
      local bx = 30 + i * 20
      safe_rect(img, bx, 8, bx + 8, 24, metal_dk)
      safe_rect(img, bx + 1, 9, bx + 7, 23, metal)
    end

    -- Magnet segments along vertical tube
    for i = 0, 1 do
      local by = 44 + i * 20
      safe_rect(img, 8, by, 24, by + 8, metal_dk)
      safe_rect(img, 9, by + 1, 23, by + 7, metal)
    end

    -- IO openings
    safe_rect(img, 92, 12, 95, 20, chamber)  -- right end of horizontal
    safe_rect(img, 12, 92, 20, 95, chamber)  -- bottom end of vertical

    -- Corner rivets
    safe_px(img, 2, 2, rivet)
    safe_px(img, 93, 2, rivet)
    safe_px(img, 2, 29, rivet)
    safe_px(img, 29, 29, rivet)
    safe_px(img, 2, 61, rivet)
    safe_px(img, 29, 61, rivet)
    safe_px(img, 2, 93, rivet)
    safe_px(img, 29, 93, rivet)

  elseif layer == "top" then
    -- Top casing for horizontal section
    safe_rect(img, 0, 0, 95, 1, metal_dk)
    safe_rect(img, 0, 30, 95, 31, metal_dk)
    safe_rect(img, 0, 0, 1, 31, metal_dk)
    safe_rect(img, 94, 0, 95, 31, metal_dk)

    -- Top casing for vertical cells
    safe_rect(img, 0, 32, 1, 95, metal_dk)
    safe_rect(img, 30, 32, 31, 95, metal_dk)
    safe_rect(img, 0, 94, 31, 95, metal_dk)

    -- Tube cover (horizontal)
    safe_rect(img, 6, 6, 90, 26, panel)
    safe_rect(img, 8, 8, 88, 24, panel_dk)

    -- Tube cover (vertical)
    safe_rect(img, 6, 28, 26, 90, panel)
    safe_rect(img, 8, 30, 24, 88, panel_dk)

    -- Viewing windows along tube
    safe_rect(img, 28, 12, 38, 20, chamber)
    safe_rect(img, 50, 12, 60, 20, chamber)
    safe_rect(img, 72, 12, 82, 20, chamber)
    safe_rect(img, 12, 42, 20, 52, chamber)
    safe_rect(img, 12, 66, 20, 76, chamber)

    -- Particle beam animation
    if tag == "idle" then
      -- Dim glow in windows
      safe_px(img, 33, 16, glow_off)
      safe_px(img, 55, 16, glow_off)
      safe_px(img, 77, 16, glow_off)
      safe_px(img, 16, 47, glow_off)
      safe_px(img, 16, 71, glow_off)

    elseif tag == "windup" then
      local t = phase * 0.5
      safe_px(img, 33, 16, H.lerp_color(glow_off, beam, t))
      safe_px(img, 55, 16, H.lerp_color(glow_off, beam, t))
      safe_px(img, 77, 16, H.lerp_color(glow_off, beam, t))
      safe_px(img, 16, 47, H.lerp_color(glow_off, beam, t))
      safe_px(img, 16, 71, H.lerp_color(glow_off, beam, t))

    elseif tag == "active" then
      -- Particle beam traveling through tube
      local beam_pos_h = 28 + phase * 16  -- moves along horizontal
      local beam_pos_v = 42 + phase * 10  -- moves along vertical

      -- Beam in horizontal windows
      for wx = 28, 82, 22 do
        safe_rect(img, wx + 2, 14, wx + 8, 18, beam)
      end
      -- Moving particle (horizontal)
      safe_px(img, beam_pos_h, 16, beam_hot)
      safe_px(img, beam_pos_h + 1, 16, beam_lt)
      safe_px(img, beam_pos_h - 1, 16, beam_lt)

      -- Beam in vertical windows
      safe_rect(img, 14, 44, 18, 50, beam)
      safe_rect(img, 14, 68, 18, 74, beam)
      -- Moving particle (vertical)
      safe_px(img, 16, beam_pos_v, beam_hot)
      safe_px(img, 16, beam_pos_v + 1, beam_lt)
      safe_px(img, 16, beam_pos_v - 1, beam_lt)

      -- Energy arcs
      if phase == 1 or phase == 3 then
        safe_px(img, 34, 14, arc)
        safe_px(img, 56, 18, arc)
        safe_px(img, 14, 48, arc)
      end

    elseif tag == "winddown" then
      local t = phase * 0.5
      safe_px(img, 33, 16, H.lerp_color(beam, glow_off, t))
      safe_px(img, 55, 16, H.lerp_color(beam, glow_off, t))
      safe_px(img, 77, 16, H.lerp_color(beam, glow_off, t))
      safe_px(img, 16, 47, H.lerp_color(beam, glow_off, t))
      safe_px(img, 16, 71, H.lerp_color(beam, glow_off, t))
    end

    -- Rivets
    safe_px(img, 3, 3, rivet)
    safe_px(img, 92, 3, rivet)
    safe_px(img, 3, 28, rivet)
    safe_px(img, 28, 28, rivet)
    safe_px(img, 3, 60, rivet)
    safe_px(img, 28, 60, rivet)
    safe_px(img, 3, 92, rivet)
    safe_px(img, 28, 92, rivet)
  end
end)

local dir = "/Users/gorishniymax/Repos/factor/buildings/particle_accelerator/sprites"
H.save_and_export(spr, dir, "main")
print("[particle_accelerator] done")
