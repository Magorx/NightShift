-- iso_box.lua -- Reusable isometric box geometry for building sprites
-- Usage: local Box = dofile("/Users/gorishniymax/Repos/factor/tools/iso_box.lua")
--
-- Draws a 3D isometric box (roof diamond + left wall + right wall) and provides
-- helpers for hit-testing each face, coordinate conversion, and outline detection.
--
-- For a 64-wide canvas with wall_height W:
--   Canvas size: 64 x (32 + W)
--   Roof diamond: top (31.5, 0), right (63, 15), bottom (31.5, 31), left (0, 15)
--   Left wall: parallelogram below roof's bottom-left edge, extending W pixels down
--   Right wall: parallelogram below roof's bottom-right edge, extending W pixels down
--
-- API:
--   Box.new(wall_height)          -> box config table
--   Box.roof_sdf(box, px, py)     -> signed distance (positive = inside)
--   Box.in_roof(box, px, py)      -> bool
--   Box.in_left_wall(box, px, py) -> bool
--   Box.in_right_wall(box, px, py)-> bool
--   Box.is_roof_outline(box, px, py)       -> bool
--   Box.is_left_wall_outline(box, px, py)  -> bool
--   Box.is_right_wall_outline(box, px, py) -> bool
--   Box.draw_structure(img, box, colors)    -- draw filled box + outlines
--   Box.draw_shadow(img, box, H)            -- draw ground shadow on base layer
--   Box.roof_to_canvas(box, roof_x, roof_y)   -> px, py or nil
--   Box.wall_to_canvas(box, wall, wall_x, wall_y) -> px, py or nil
--   Box.roof_bounds(box) -> x1, y1, x2, y2
--   Box.wall_bounds(box, wall) -> x1, y1, x2, y2

local Box = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- CONSTANTS
-- ═══════════════════════════════════════════════════════════════════════════

local CX = 31.5     -- center X of diamond (between pixels 31 and 32)
local HX = 31.5     -- half-width of diamond (0 to 63 -> radius 31.5)
local HY = 15.5     -- half-height of diamond (0 to 31 -> radius 15.5)
local ROOF_CY = 15  -- roof diamond center Y

-- ═══════════════════════════════════════════════════════════════════════════
-- CONSTRUCTOR
-- ═══════════════════════════════════════════════════════════════════════════

--- Create a new box configuration.
-- @param wall_height  pixels of wall below roof (default 24)
-- @return box config table used by all other functions
function Box.new(wall_height)
  local wh = wall_height or 24
  return {
    wall_h   = wh,
    canvas_w = 64,
    canvas_h = 32 + wh,

    -- Roof diamond vertices
    roof_top    = { CX, 0 },
    roof_right  = { 63, ROOF_CY },
    roof_bottom = { CX, 31 },
    roof_left   = { 0, ROOF_CY },

    -- Bottom vertices (wall base)
    base_left   = { 0, ROOF_CY + wh },
    base_front  = { CX, 31 + wh },
    base_right  = { 63, ROOF_CY + wh },
  }
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ROOF DIAMOND
-- ═══════════════════════════════════════════════════════════════════════════

--- Signed distance field for the roof diamond.
-- Positive values are inside, negative outside.
-- The diamond is defined by |dx/HX| + |dy/HY| <= 1.
function Box.roof_sdf(box, px, py)
  local dx = math.abs(px - CX) / (HX + 0.5)
  local dy = math.abs(py - ROOF_CY) / (HY + 0.5)
  return 1.0 - dx - dy
end

--- Check if pixel (px, py) is inside the roof diamond.
function Box.in_roof(box, px, py)
  return Box.roof_sdf(box, px, py) >= 0
end

--- Check if pixel is on the roof outline (1px border).
function Box.is_roof_outline(box, px, py)
  local d = Box.roof_sdf(box, px, py)
  return d >= 0 and d < 0.06
end

-- ═══════════════════════════════════════════════════════════════════════════
-- WALL GEOMETRY
-- ═══════════════════════════════════════════════════════════════════════════

-- Each wall is a parallelogram defined by the bottom edge of the roof diamond
-- extruded straight down by wall_h pixels.
--
-- Left wall: below the bottom-left roof edge (from vertex (0, 15) to (31.5, 31)).
--   At a given x in [0, 31], the top of the wall is on the line y = 15 + 16*(x/31.5)
--   and the bottom is top + wall_h.
--
-- Right wall: below the bottom-right roof edge (from vertex (31.5, 31) to (63, 15)).
--   At a given x in [32, 63], the top is on the line y = 31 - 16*((x-31.5)/31.5)
--   and the bottom is top + wall_h.

-- Internal helpers for the wall top-edge lines
local function _left_wall_top_y(px)
  -- Line from (0, ROOF_CY) to (CX, 31): slope = 16 / 31.5
  return ROOF_CY + (31 - ROOF_CY) * (px / CX)
end

local function _right_wall_top_y(px)
  -- Line from (CX, 31) to (63, ROOF_CY): slope = -16 / 31.5
  return 31 + (ROOF_CY - 31) * ((px - CX) / (63 - CX))
end

--- Check if pixel is in the left wall parallelogram.
function Box.in_left_wall(box, px, py)
  if px < 0 or px > CX then return false end
  local top_y = _left_wall_top_y(px)
  return py > top_y and py <= top_y + box.wall_h
end

--- Check if pixel is in the right wall parallelogram.
function Box.in_right_wall(box, px, py)
  if px < CX or px > 63 then return false end
  local top_y = _right_wall_top_y(px)
  return py > top_y and py <= top_y + box.wall_h
end

--- Check if pixel is on the left wall outline.
-- A wall pixel is on the outline if any 4-connected neighbor is NOT in the
-- left wall AND not in the roof (to avoid double-drawing the shared edge
-- which the roof outline already covers).
function Box.is_left_wall_outline(box, px, py)
  if not Box.in_left_wall(box, px, py) then return false end

  -- Center ridge is always an outline
  if px >= math.floor(CX) and px <= math.ceil(CX) then return true end

  -- Check 4-connected neighbors
  local neighbors = {{px-1, py}, {px+1, py}, {px, py-1}, {px, py+1}}
  for _, n in ipairs(neighbors) do
    local nx, ny = n[1], n[2]
    if not Box.in_left_wall(box, nx, ny) and not Box.in_roof(box, nx, ny) then
      return true
    end
  end
  return false
end

--- Check if pixel is on the right wall outline.
function Box.is_right_wall_outline(box, px, py)
  if not Box.in_right_wall(box, px, py) then return false end

  -- Center ridge is always an outline
  if px >= math.floor(CX) and px <= math.ceil(CX) then return true end

  -- Check 4-connected neighbors
  local neighbors = {{px-1, py}, {px+1, py}, {px, py-1}, {px, py+1}}
  for _, n in ipairs(neighbors) do
    local nx, ny = n[1], n[2]
    if not Box.in_right_wall(box, nx, ny) and not Box.in_roof(box, nx, ny) then
      return true
    end
  end
  return false
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DRAWING
-- ═══════════════════════════════════════════════════════════════════════════

--- Draw the complete box structure onto an image.
-- @param img     Aseprite Image to draw on
-- @param box     box config from Box.new()
-- @param colors  table with keys: roof, left_wall, right_wall, outline
--
-- Draw order: fills first, then outlines on top for clean edges.
-- The center front ridge (where left and right walls meet) is drawn as outline.
function Box.draw_structure(img, box, colors)
  local w = box.canvas_w
  local h = box.canvas_h

  -- Pass 1: fill all faces
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      if Box.in_roof(box, x, y) then
        img:drawPixel(x, y, colors.roof)
      elseif Box.in_left_wall(box, x, y) then
        img:drawPixel(x, y, colors.left_wall)
      elseif Box.in_right_wall(box, x, y) then
        img:drawPixel(x, y, colors.right_wall)
      end
    end
  end

  -- Pass 2: outlines on top
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      if Box.is_roof_outline(box, x, y) then
        img:drawPixel(x, y, colors.outline)
      elseif Box.is_left_wall_outline(box, x, y) then
        img:drawPixel(x, y, colors.outline)
      elseif Box.is_right_wall_outline(box, x, y) then
        img:drawPixel(x, y, colors.outline)
      end
    end
  end
end

--- Draw a shadow on the base layer.
-- Semi-transparent dark ellipse at ground level beneath the box.
-- @param img  Aseprite Image to draw on
-- @param box  box config from Box.new()
-- @param H    aseprite_helper module (needs H.px, H.with_alpha, H.hex)
function Box.draw_shadow(img, box, H)
  local shadow_color = H.with_alpha(H.hex("#000000"), 30)
  -- Shadow center is at the midpoint of the bottom diamond
  local shadow_cy = ROOF_CY + box.wall_h + 4
  local shadow_rx = 33
  local shadow_ry = 11
  for y = 0, box.canvas_h - 1 do
    for x = 0, box.canvas_w - 1 do
      local dx = math.abs(x - CX) / shadow_rx
      local dy = math.abs(y - shadow_cy) / shadow_ry
      local d = 1.0 - dx - dy
      if d > 0 and d < 0.5 then
        H.px(img, x, y, shadow_color)
      end
    end
  end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- COORDINATE CONVERSION
-- ═══════════════════════════════════════════════════════════════════════════

--- Convert a roof-local coordinate to canvas coordinate.
-- roof_x: 0..1 across the roof diamond (left to right)
-- roof_y: 0..1 across the roof diamond (top to bottom)
-- Returns: canvas px, py (integers) or nil if outside roof
function Box.roof_to_canvas(box, roof_x, roof_y)
  -- Map [0,1] to the roof diamond's bounding box
  -- roof_x=0 -> left corner (x=0), roof_x=1 -> right corner (x=63)
  -- roof_y=0 -> top corner (y=0), roof_y=1 -> bottom corner (y=31)
  --
  -- The diamond is defined by four edges. A point at (rx, ry) in [0,1]x[0,1]
  -- maps to the diamond interior via:
  --   canvas_x = left_x + rx * (right_x - left_x)
  --   canvas_y = top_y + ry * (bottom_y - top_y)
  -- But we need to account for the diamond shape. Use the parameterization:
  --   u = roof_x - 0.5  (range -0.5 to 0.5)
  --   v = roof_y - 0.5  (range -0.5 to 0.5)
  -- Inside diamond: |u| + |v| <= 0.5
  local u = roof_x - 0.5
  local v = roof_y - 0.5
  if math.abs(u) + math.abs(v) > 0.5 then return nil end

  -- Map to canvas: the diamond spans 64 pixels wide, 32 pixels tall
  local px = math.floor(CX + u * 63 + 0.5)
  local py = math.floor(ROOF_CY + v * 31 + 0.5)
  return px, py
end

--- Convert a wall-local coordinate to canvas coordinate.
-- wall: "left" or "right"
-- wall_x: 0..1 across the wall (outer edge to center ridge)
-- wall_y: 0..1 down the wall (top to bottom)
-- Returns: canvas px, py (integers) or nil if outside wall
function Box.wall_to_canvas(box, wall, wall_x, wall_y)
  if wall == "left" then
    -- Left wall spans from x=0 to x=CX (left to center)
    -- At a given x, the top of the wall is the bottom-left roof edge,
    -- and the bottom is that + wall_h.
    -- wall_x=0 -> x=0 (outer edge), wall_x=1 -> x=CX (center ridge)
    local px = math.floor(wall_x * CX + 0.5)
    local top_y = _left_wall_top_y(px)
    local py = math.floor(top_y + wall_y * box.wall_h + 0.5)
    if Box.in_left_wall(box, px, py) then
      return px, py
    end
    return nil

  elseif wall == "right" then
    -- Right wall spans from x=CX to x=63 (center ridge to outer edge)
    -- wall_x=0 -> x=CX (center ridge), wall_x=1 -> x=63 (outer edge)
    local px = math.floor(CX + wall_x * (63 - CX) + 0.5)
    local top_y = _right_wall_top_y(px)
    local py = math.floor(top_y + wall_y * box.wall_h + 0.5)
    if Box.in_right_wall(box, px, py) then
      return px, py
    end
    return nil
  end

  return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- BOUNDING REGIONS
-- ═══════════════════════════════════════════════════════════════════════════

--- Get the roof diamond's bounding region for iteration.
-- Returns: x1, y1, x2, y2 (inclusive pixel bounds)
function Box.roof_bounds(box)
  return 0, 0, 63, 31
end

--- Get wall bounding region for iteration.
-- @param wall  "left" or "right"
-- Returns: x1, y1, x2, y2 (inclusive pixel bounds)
function Box.wall_bounds(box, wall)
  if wall == "left" then
    -- Left wall: x from 0 to floor(CX), y from ROOF_CY to 31 + wall_h
    return 0, ROOF_CY, math.floor(CX), 31 + box.wall_h
  elseif wall == "right" then
    -- Right wall: x from ceil(CX) to 63, y from ROOF_CY to 31 + wall_h
    return math.ceil(CX), ROOF_CY, 63, 31 + box.wall_h
  end
  return 0, 0, 0, 0
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILITY: Wall top-edge Y for a given X (useful for detail placement)
-- ═══════════════════════════════════════════════════════════════════════════

--- Get the Y coordinate of the top edge of the left wall at a given X.
-- This is the bottom-left edge of the roof diamond.
-- @param px  x coordinate (0 to CX)
-- @return y coordinate (fractional)
function Box.left_wall_top_y(box, px)
  return _left_wall_top_y(px)
end

--- Get the Y coordinate of the top edge of the right wall at a given X.
-- This is the bottom-right edge of the roof diamond.
-- @param px  x coordinate (CX to 63)
-- @return y coordinate (fractional)
function Box.right_wall_top_y(box, px)
  return _right_wall_top_y(px)
end

print("[iso_box] loaded")
return Box
