-- generate.lua -- Isometric source: test item producer
-- 64x72: 3D isometric box (roof diamond + left/right walls) + hopper above roof
-- 2 layers (base, top), 4 frames: default(4)
--
-- Brown industrial building with green accent identity.
-- Base layer: shadow only. Top layer: full 3D box + hopper/funnel.

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local Box = dofile("/Users/gorishniymax/Repos/factor/tools/iso_box.lua")
local C = H.load_palette("buildings")

local W, FH = 64, 72
local WALL_H = 24
local ROOF_OFFSET = 16  -- box starts 16px down to leave room for hopper

local LAYERS = {"base", "top"}
local TAGS = {
  {name="default", from=1, to=4, duration=0.3},
}
local DIR = "/Users/gorishniymax/Repos/factor/buildings/source/sprites"

-- Palette colors (already resolved to pixel colors by load_palette)
local outline    = C.outline
local body       = C.body
local body_light = C.body_light
local panel      = C.panel
local panel_inner = C.panel_inner
local shadow_c   = C.shadow
local rivet      = C.rivet
local rim        = C.rim
local pipe       = C.pipe
local pipe_inner = C.pipe_inner
local chamber    = C.chamber
local chamber_deep = C.chamber_deep
local flange     = C.flange
local conv_yellow = C.conv_yellow

-- Green accent (source identity -- used sparingly)
local GREEN      = H.hex("#3A8A4A")
local GREEN_DK   = H.hex("#2D6B3F")
local GREEN_LT   = H.hex("#4CAF50")
local GREEN_BR   = H.hex("#5DC060")
local GREEN_DIM  = H.hex("#2A5A35")

-- Box geometry (operates at y-offset ROOF_OFFSET on canvas)
local box = Box.new(WALL_H)

-- Helper: check if canvas pixel (x, y) maps to box coordinate space
local function box_y(cy)
  return cy - ROOF_OFFSET
end

local function in_box_roof(x, cy)
  return Box.in_roof(box, x, box_y(cy))
end

local function in_box_left(x, cy)
  return Box.in_left_wall(box, x, box_y(cy))
end

local function in_box_right(x, cy)
  return Box.in_right_wall(box, x, box_y(cy))
end

-- =========================================================================
-- HOPPER / FUNNEL (y=0..20, above roof)
-- Trapezoidal structure sitting on the roof center
-- =========================================================================

local function in_hopper(px, py)
  -- Hopper is an isometric diamond-trapezoid narrowing upward
  -- Base (y=19): ~28px wide, Top (y=2): ~10px wide
  -- Uses diamond shape (iso perspective) not just a rectangle
  local cx = 31.5

  if py < 2 or py > 19 then return false end

  -- Interpolate dimensions: wider at base, narrower at top
  local t = (19 - py) / 17.0  -- 0 at bottom, 1 at top
  local half_w = 14 - t * 9   -- 14 at bottom, 5 at top
  local half_h = 0.5           -- thin iso diamond per row

  -- Simple horizontal bounds (iso diamond per-row gives a tapered shape)
  local dx = math.abs(px - cx)
  if dx > half_w then return false end

  return true
end

local function is_hopper_outline(px, py)
  if not in_hopper(px, py) then return false end
  -- Check 4-neighbors
  local neighbors = {{px-1, py}, {px+1, py}, {px, py-1}, {px, py+1}}
  for _, n in ipairs(neighbors) do
    if not in_hopper(n[1], n[2]) and not in_box_roof(n[1], n[2]) then
      return true
    end
  end
  return false
end

local function draw_hopper(img, phase)
  -- Fill hopper body
  for y = 2, 19 do
    for x = 0, 63 do
      if in_hopper(x, y) then
        if is_hopper_outline(x, y) then
          H.px(img, x, y, outline)
        else
          -- Left side slightly darker, right slightly lighter
          if x < 31 then
            H.px(img, x, y, body)
          else
            H.px(img, x, y, body_light)
          end
        end
      end
    end
  end

  -- Green accent band across the hopper (y=8..12, 5px tall for visibility)
  for y = 8, 12 do
    for x = 0, 63 do
      if in_hopper(x, y) and not is_hopper_outline(x, y) then
        if x < 31 then
          H.px(img, x, y, GREEN_DK)
        else
          H.px(img, x, y, GREEN)
        end
      end
    end
  end
  -- Brighter green highlight in center of band
  for y = 9, 11 do
    for x = 0, 63 do
      if in_hopper(x, y) and not is_hopper_outline(x, y) then
        H.px(img, x, y, GREEN)
      end
    end
  end
  -- Subtle pulsing glow on the green band (phase-dependent brightness)
  local band_pulse = {GREEN, GREEN_LT, GREEN, GREEN_DK}
  local bp_color = band_pulse[(phase % 4) + 1]
  for x = 0, 63 do
    if in_hopper(x, 10) and not is_hopper_outline(x, 10) then
      H.px(img, x, 10, bp_color)
    end
  end

  -- Hopper opening at top (dark interior, y=3..4)
  for y = 3, 4 do
    for x = 0, 63 do
      if in_hopper(x, y) and not is_hopper_outline(x, y) then
        H.px(img, x, y, chamber)
      end
    end
  end
  -- Even darker center of opening
  for x = 0, 63 do
    if in_hopper(x, 3) and not is_hopper_outline(x, 3) then
      H.px(img, x, 3, chamber_deep)
    end
  end

  -- Indicator light on very top of hopper (pulsing)
  local pulse_colors = { GREEN_LT, GREEN_BR, GREEN_LT, GREEN_DIM }
  local pulse = pulse_colors[(phase % 4) + 1]
  -- 2x1 light sitting on top edge
  H.px(img, 31, 2, pulse)
  H.px(img, 32, 2, pulse)

  -- Rivets on hopper sides (wider placement for wider hopper)
  H.px(img, 22, 15, rivet)
  H.px(img, 41, 15, rivet)
  H.px(img, 25, 7, rivet)
  H.px(img, 38, 7, rivet)
  H.px(img, 20, 18, rivet)
  H.px(img, 43, 18, rivet)

  -- Vertical seam lines on hopper (structural dividers)
  for y = 5, 18 do
    -- Skip the green band area
    if y < 8 or y > 12 then
      if in_hopper(28, y) and not is_hopper_outline(28, y) then
        H.px(img, 28, y, panel)
      end
      if in_hopper(35, y) and not is_hopper_outline(35, y) then
        H.px(img, 35, y, rim)
      end
    end
  end

  -- Flange/lip at hopper base where it meets the roof (y=18..19)
  for x = 0, 63 do
    if in_hopper(x, 18) and not is_hopper_outline(x, 18) then
      H.px(img, x, 18, flange)
    end
    if in_hopper(x, 19) and not is_hopper_outline(x, 19) then
      H.px(img, x, 19, rim)
    end
  end
end

-- =========================================================================
-- ROOF DETAILS (drawn on top of Box.draw_structure)
-- =========================================================================
local function draw_roof_details(img)
  -- Panel seam lines following iso axes
  -- Seam parallel to top-left edge (slope ~ -0.5)
  for _, offset in ipairs({-6, 6}) do
    for x = 3, 60 do
      local y = math.floor(15 + (15.5 / 31.5) * (x - 31.5) + offset) + ROOF_OFFSET
      if in_box_roof(x, y) and not Box.is_roof_outline(box, x, box_y(y)) then
        H.px(img, x, y, rim)
      end
    end
  end
  -- Seam parallel to top-right edge (slope ~ +0.5)
  for _, offset in ipairs({-6, 6}) do
    for x = 3, 60 do
      local y = math.floor(15 - (15.5 / 31.5) * (x - 31.5) + offset) + ROOF_OFFSET
      if in_box_roof(x, y) and not Box.is_roof_outline(box, x, box_y(y)) then
        H.px(img, x, y, rim)
      end
    end
  end

  -- Corner rivets (inset from diamond corners)
  local roof_rivets = {
    {31, 3 + ROOF_OFFSET}, {32, 3 + ROOF_OFFSET},     -- top
    {31, 28 + ROOF_OFFSET}, {32, 28 + ROOF_OFFSET},   -- bottom
    {5, 15 + ROOF_OFFSET}, {6, 15 + ROOF_OFFSET},     -- left
    {57, 15 + ROOF_OFFSET}, {58, 15 + ROOF_OFFSET},   -- right
    -- Mid positions
    {18, 7 + ROOF_OFFSET}, {45, 7 + ROOF_OFFSET},
    {18, 24 + ROOF_OFFSET}, {45, 24 + ROOF_OFFSET},
  }
  for _, rp in ipairs(roof_rivets) do
    if in_box_roof(rp[1], rp[2]) then
      H.px(img, rp[1], rp[2], rivet)
    end
  end

  -- "S" label on roof using green accent (6x5 area)
  -- Positioned on right side of roof
  local sx, sy = 40, 19 + ROOF_OFFSET
  -- S shape: top bar, left drop, middle bar, right drop, bottom bar
  local s_pixels = {
    -- top bar
    {0,0},{1,0},{2,0},{3,0},
    -- left drop
    {0,1},
    -- middle bar
    {0,2},{1,2},{2,2},{3,2},
    -- right drop
    {3,3},
    -- bottom bar
    {0,4},{1,4},{2,4},{3,4},
  }
  for _, p in ipairs(s_pixels) do
    local px, py = sx + p[1], sy + p[2]
    if in_box_roof(px, py) and not Box.is_roof_outline(box, px, box_y(py)) then
      H.px(img, px, py, GREEN)
    end
  end
end

-- =========================================================================
-- LEFT WALL DETAILS
-- =========================================================================
local function draw_left_wall_details(img)
  -- Horizontal seam across middle of left wall
  for x = 2, 30 do
    local top_y = Box.left_wall_top_y(box, x)
    local mid_y = math.floor(top_y + WALL_H * 0.5) + ROOF_OFFSET
    if in_box_left(x, mid_y) and not Box.is_left_wall_outline(box, x, box_y(mid_y)) then
      H.px(img, x, mid_y, rim)
    end
  end

  -- Large control panel (10x10 area) on left wall
  local panel_cx = 14
  local panel_top_base = Box.left_wall_top_y(box, panel_cx)
  local panel_y = math.floor(panel_top_base + WALL_H * 0.15) + ROOF_OFFSET

  -- Panel frame (dark rectangle)
  for dy = 0, 9 do
    for dx = -5, 4 do
      local px, py = panel_cx + dx, panel_y + dy
      if in_box_left(px, py) and not Box.is_left_wall_outline(box, px, box_y(py)) then
        if dy == 0 or dy == 9 or dx == -5 or dx == 4 then
          H.px(img, px, py, outline)
        elseif dy >= 1 and dy <= 6 then
          -- Screen area (dark)
          H.px(img, px, py, chamber)
        else
          -- Lower panel area
          H.px(img, px, py, panel_inner)
        end
      end
    end
  end

  -- Green status indicator on panel screen
  H.px(img, panel_cx - 2, panel_y + 2, GREEN)
  H.px(img, panel_cx - 1, panel_y + 2, GREEN)
  H.px(img, panel_cx, panel_y + 3, GREEN_DK)
  H.px(img, panel_cx + 1, panel_y + 3, GREEN_DK)
  -- Small readout dots
  H.px(img, panel_cx - 3, panel_y + 5, GREEN_DIM)
  H.px(img, panel_cx - 1, panel_y + 5, GREEN_DIM)
  H.px(img, panel_cx + 1, panel_y + 5, GREEN_DIM)
  -- Buttons below screen
  H.px(img, panel_cx - 2, panel_y + 8, rivet)
  H.px(img, panel_cx + 1, panel_y + 8, GREEN_DK)

  -- Horizontal pipe run connecting to output side (lower on wall)
  for x = 2, 30 do
    local top_y = Box.left_wall_top_y(box, x)
    local pipe_y = math.floor(top_y + WALL_H * 0.75) + ROOF_OFFSET
    if in_box_left(x, pipe_y) and not Box.is_left_wall_outline(box, x, box_y(pipe_y)) then
      H.px(img, x, pipe_y, pipe)
    end
    -- Pipe highlight (top edge)
    local ph_y = pipe_y - 1
    if in_box_left(x, ph_y) and not Box.is_left_wall_outline(box, x, box_y(ph_y)) then
      H.px(img, x, ph_y, flange)
    end
  end

  -- Structural bolts at corners
  local bolt_positions = {
    {4, 0.15}, {4, 0.85},
    {24, 0.15}, {24, 0.85},
  }
  for _, bp in ipairs(bolt_positions) do
    local bx = bp[1]
    local top_y = Box.left_wall_top_y(box, bx)
    local by = math.floor(top_y + WALL_H * bp[2]) + ROOF_OFFSET
    if in_box_left(bx, by) and not Box.is_left_wall_outline(box, bx, box_y(by)) then
      H.px(img, bx, by, rivet)
    end
  end
end

-- =========================================================================
-- RIGHT WALL DETAILS
-- =========================================================================
local function draw_right_wall_details(img)
  -- Horizontal seam across middle of right wall
  for x = 33, 62 do
    local top_y = Box.right_wall_top_y(box, x)
    local mid_y = math.floor(top_y + WALL_H * 0.5) + ROOF_OFFSET
    if in_box_right(x, mid_y) and not Box.is_right_wall_outline(box, x, box_y(mid_y)) then
      H.px(img, x, mid_y, rim)
    end
  end

  -- Output chute (10x8 visible area) on right wall
  local chute_cx = 49
  local chute_top_base = Box.right_wall_top_y(box, chute_cx)
  local chute_y = math.floor(chute_top_base + WALL_H * 0.2) + ROOF_OFFSET

  -- Chute frame
  for dy = 0, 7 do
    for dx = -5, 4 do
      local px, py = chute_cx + dx, chute_y + dy
      if in_box_right(px, py) and not Box.is_right_wall_outline(box, px, box_y(py)) then
        if dy == 0 or dy == 7 or dx == -5 or dx == 4 then
          H.px(img, px, py, outline)
        else
          -- Deep interior
          H.px(img, px, py, chamber_deep)
        end
      end
    end
  end

  -- Inner chute shelf (lighter, showing depth)
  for dx = -3, 2 do
    local px = chute_cx + dx
    if in_box_right(px, chute_y + 6) then
      H.px(img, px, chute_y + 6, chamber)
    end
  end
  -- Chute opening highlight
  for dy = 2, 5 do
    local px = chute_cx + 3
    if in_box_right(px, chute_y + dy) then
      H.px(img, px, chute_y + dy, panel_inner)
    end
  end

  -- Green arrow marking next to chute
  local arrow_x = chute_cx + 6
  local arrow_y = chute_y + 3
  if in_box_right(arrow_x, arrow_y) then
    H.px(img, arrow_x, arrow_y, GREEN)
    H.px(img, arrow_x + 1, arrow_y, GREEN)
  end
  if in_box_right(arrow_x - 1, arrow_y - 1) then
    H.px(img, arrow_x - 1, arrow_y - 1, GREEN)
  end
  if in_box_right(arrow_x - 1, arrow_y + 1) then
    H.px(img, arrow_x - 1, arrow_y + 1, GREEN)
  end

  -- Access panel with rivets (lower right wall)
  local ap_cx = 40
  local ap_top_base = Box.right_wall_top_y(box, ap_cx)
  local ap_y = math.floor(ap_top_base + WALL_H * 0.55) + ROOF_OFFSET

  for dy = 0, 5 do
    for dx = -3, 3 do
      local px, py = ap_cx + dx, ap_y + dy
      if in_box_right(px, py) and not Box.is_right_wall_outline(box, px, box_y(py)) then
        if dy == 0 or dy == 5 or dx == -3 or dx == 3 then
          H.px(img, px, py, rim)
        else
          H.px(img, px, py, panel)
        end
      end
    end
  end
  -- Rivets on access panel corners
  H.px(img, ap_cx - 2, ap_y + 1, rivet)
  H.px(img, ap_cx + 2, ap_y + 1, rivet)
  H.px(img, ap_cx - 2, ap_y + 4, rivet)
  H.px(img, ap_cx + 2, ap_y + 4, rivet)

  -- Structural bolts
  local bolt_positions = {
    {36, 0.15}, {36, 0.85},
    {58, 0.15}, {58, 0.85},
  }
  for _, bp in ipairs(bolt_positions) do
    local bx = bp[1]
    local top_y = Box.right_wall_top_y(box, bx)
    local by = math.floor(top_y + WALL_H * bp[2]) + ROOF_OFFSET
    if in_box_right(bx, by) and not Box.is_right_wall_outline(box, bx, box_y(by)) then
      H.px(img, bx, by, rivet)
    end
  end
end

-- =========================================================================
-- BASE LAYER: ground shadow
-- =========================================================================
local function draw_base(img, tag, phase)
  local shadow_color = H.with_alpha(H.hex("#000000"), 30)
  local shadow_cy = ROOF_OFFSET + 15 + WALL_H + 4  -- below box base
  for y = 0, FH - 1 do
    for x = 0, W - 1 do
      local dx = math.abs(x - 31.5) / 33
      local dy = math.abs(y - shadow_cy) / 11
      local d = 1.0 - dx - dy
      if d > 0 and d < 0.5 then
        H.px(img, x, y, shadow_color)
      end
    end
  end
end

-- =========================================================================
-- TOP LAYER: box structure + hopper + details
-- =========================================================================
local function draw_top(img, tag, phase)
  -- Create a temporary image for the box at its natural coordinates,
  -- then stamp it onto the canvas at ROOF_OFFSET
  local box_img = Image(box.canvas_w, box.canvas_h, ColorMode.RGB)

  -- Draw the box structure
  Box.draw_structure(box_img, box, {
    roof       = panel,
    left_wall  = body,
    right_wall = body_light,
    outline    = outline,
  })

  -- Stamp box onto canvas at y=ROOF_OFFSET
  H.stamp(img, box_img, 0, ROOF_OFFSET)

  -- Draw roof details (seams, rivets, label)
  draw_roof_details(img)

  -- Draw wall details
  draw_left_wall_details(img)
  draw_right_wall_details(img)

  -- Draw hopper on top (overlaps roof area)
  draw_hopper(img, phase)
end

-- =========================================================================
-- Build sprite
-- =========================================================================
local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr, DIR, "main")
print("[source] done")
