-- generate_atlas.lua
-- Night Shift elemental item atlas: 8 columns x 1 row = 128x16 pixels, each cell 16x16.
-- Items: Pyromite, Crystalline, Biovine, Steam Burst, Verdant Compound, Frozen Flame, (empty x2)
-- Run: /Applications/Aseprite.app/Contents/MacOS/aseprite -b --script resources/items/sprites/generate_atlas.lua

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local pal = H.load_palette("elements")

local CELL = 16
local COLS = 8
local W, HT = COLS * CELL, CELL
local T = H.TRANSPARENT
local OL = pal.outline

local spr = Sprite(W, HT, ColorMode.RGB)
app.activeSprite = spr
local layer = spr.layers[1]
layer.name = "items"
-- Delete default cel
for _, cel in ipairs(layer.cels) do spr:deleteCel(cel) end
local img = Image(W, HT, ColorMode.RGB)

-- Helper: draw into a cell by index (0-based)
local function cell_x(idx) return idx * CELL end

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEX 0: PYROMITE — Jagged flame-shaped crystal chunk
-- Silhouette: tall jagged angular mineral, flame-like peaks
-- ═══════════════════════════════════════════════════════════════════════════
local function draw_pyromite(img, ox)
  local base = pal.pyro_base
  local hi   = pal.pyro_hi
  local dk   = pal.pyro_dark
  local dp   = pal.pyro_deep
  local glow = pal.pyro_glow

  -- Outline shape: jagged crystal with flame-like peaks
  -- Build from filled columns defining the silhouette
  local cols = {
  -- x, y_top, y_bot (relative to cell, 0-indexed)
    {3,  11, 14},
    {4,  8,  14},
    {5,  5,  14},
    {6,  3,  14},
    {7,  1,  14},
    {8,  2,  14},
    {9,  4,  14},
    {10, 6,  14},
    {11, 3,  14},
    {12, 5,  14},
    {13, 8,  14},
  }

  -- Fill body
  for _, c in ipairs(cols) do
    for y = c[2], c[3] do
      H.px(img, ox + c[1], y, base)
    end
  end

  -- Add a secondary peak to make it more jagged
  for y = 6, 14 do H.px(img, ox + 10, y, base) end
  H.px(img, ox + 10, 5, base)

  -- Dark side (right edges, bottom)
  for _, c in ipairs(cols) do
    H.px(img, ox + c[1], c[3], dk)
  end
  -- Right edge shadow
  for y = 5, 14 do H.px(img, ox + 13, y, dk) end
  for y = 3, 14 do H.px(img, ox + 12, y, dk) end

  -- Highlight left edges and peaks
  H.px(img, ox + 7, 1, hi)
  H.px(img, ox + 7, 2, hi)
  H.px(img, ox + 6, 3, hi)
  H.px(img, ox + 6, 4, hi)
  H.px(img, ox + 5, 5, hi)
  H.px(img, ox + 5, 6, hi)
  H.px(img, ox + 4, 8, hi)
  H.px(img, ox + 4, 9, hi)
  H.px(img, ox + 3, 11, hi)
  H.px(img, ox + 11, 3, hi)
  H.px(img, ox + 11, 4, hi)

  -- Glow spots (hot core)
  H.px(img, ox + 7, 4, glow)
  H.px(img, ox + 8, 5, glow)
  H.px(img, ox + 7, 6, glow)
  H.px(img, ox + 8, 8, glow)
  H.px(img, ox + 6, 9, glow)
  H.px(img, ox + 9, 7, hi)

  -- Deep shadows at base
  for x = 4, 12 do H.px(img, ox + x, 14, dp) end
  for x = 5, 11 do H.px(img, ox + x, 13, dk) end

  -- Internal fracture lines
  H.line(img, ox + 8, 6, ox + 6, 12, dk)
  H.line(img, ox + 10, 7, ox + 11, 12, dp)

  -- 1px outline
  -- Top contour
  local outline_pixels = {}
  -- Scan each column, mark pixels just outside the body
  for x = 2, 14 do
    for y = 0, 15 do
      -- Check if this pixel is empty and adjacent to a body pixel
      local px_here = img:getPixel(ox + x, y)
      if px_here == T or px_here == 0 then
        local has_neighbor = false
        for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
          local nx, ny = ox + x + d[1], y + d[2]
          if nx >= ox and nx < ox + 16 and ny >= 0 and ny < 16 then
            local np = img:getPixel(nx, ny)
            if np ~= T and np ~= 0 then
              has_neighbor = true
              break
            end
          end
        end
        if has_neighbor then
          table.insert(outline_pixels, {ox + x, y})
        end
      end
    end
  end
  for _, p in ipairs(outline_pixels) do
    H.px(img, p[1], p[2], OL)
  end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEX 1: CRYSTALLINE — Hexagonal prismatic crystal cluster
-- Silhouette: geometric, faceted, angular symmetry
-- ═══════════════════════════════════════════════════════════════════════════
local function draw_crystalline(img, ox)
  local base = pal.cryst_base
  local hi   = pal.cryst_hi
  local dk   = pal.cryst_dark
  local dp   = pal.cryst_deep
  local glow = pal.cryst_glow

  -- Main tall crystal (center)
  -- Diamond/hexagonal prism shape
  local function fill_diamond(cx, cy, hw, hh, color)
    for dy = -hh, hh do
      local w = math.floor(hw * (1 - math.abs(dy) / hh) + 0.5)
      for dx = -w, w do
        H.px(img, cx + dx, cy + dy, color)
      end
    end
  end

  -- Large center crystal
  fill_diamond(ox + 8, ox and 7 or 7, 3, 6, base)
  -- Overwrite: use absolute y
  -- Clear and redo properly
  -- Main crystal body: tall hexagonal prism
  for y = 1, 13 do
    local half
    if y <= 3 then half = y - 1
    elseif y <= 10 then half = 3
    else half = 13 - y
    end
    for dx = -half, half do
      H.px(img, ox + 7 + dx, y, base)
    end
  end

  -- Second smaller crystal (right, angled)
  for y = 4, 13 do
    local half
    if y <= 6 then half = y - 4
    elseif y <= 11 then half = 2
    else half = 13 - y
    end
    for dx = -half, half do
      H.px(img, ox + 12 + dx, y, base)
    end
  end

  -- Third small crystal (left)
  for y = 6, 14 do
    local half
    if y <= 8 then half = y - 6
    elseif y <= 12 then half = 2
    else half = 14 - y
    end
    for dx = -half, half do
      H.px(img, ox + 4 + dx, y, base)
    end
  end

  -- Highlights (left faces catch light)
  for y = 2, 9 do H.px(img, ox + 5, y, hi) end
  for y = 1, 4 do H.px(img, ox + 7, y, hi) end
  H.px(img, ox + 6, 2, hi)
  for y = 5, 8 do H.px(img, ox + 10, y, hi) end
  H.px(img, ox + 3, 7, hi)
  H.px(img, ox + 3, 8, hi)

  -- Glow core
  H.px(img, ox + 7, 5, glow)
  H.px(img, ox + 7, 6, glow)
  H.px(img, ox + 8, 7, glow)
  H.px(img, ox + 12, 7, glow)
  H.px(img, ox + 4, 9, glow)

  -- Dark faces (right side)
  for y = 2, 12 do H.px(img, ox + 10, y, dk) end
  for y = 5, 12 do H.px(img, ox + 14, y, dk) end
  for y = 7, 13 do H.px(img, ox + 6, y, dk) end

  -- Deep shadow at base
  for x = 5, 9 do H.px(img, ox + x, 13, dp) end
  for x = 10, 13 do H.px(img, ox + x, 13, dp) end
  H.px(img, ox + 4, 14, dp)
  H.px(img, ox + 5, 14, dp)

  -- Facet lines
  H.line(img, ox + 7, 1, ox + 7, 13, dk)

  -- Outline
  local outline_pixels = {}
  for x = 1, 15 do
    for y = 0, 15 do
      local px_here = img:getPixel(ox + x, y)
      if px_here == T or px_here == 0 then
        for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
          local nx, ny = ox + x + d[1], y + d[2]
          if nx >= ox and nx < ox + 16 and ny >= 0 and ny < 16 then
            local np = img:getPixel(nx, ny)
            if np ~= T and np ~= 0 then
              table.insert(outline_pixels, {ox + x, y})
              break
            end
          end
        end
      end
    end
  end
  for _, p in ipairs(outline_pixels) do H.px(img, p[1], p[2], OL) end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEX 2: BIOVINE — Organic seed pod with tendrils
-- Silhouette: rounded organic shape with curling tendrils, asymmetric
-- ═══════════════════════════════════════════════════════════════════════════
local function draw_biovine(img, ox)
  local base = pal.bio_base
  local hi   = pal.bio_hi
  local dk   = pal.bio_dark
  local dp   = pal.bio_deep
  local glow = pal.bio_glow

  -- Central pod (rounded bulb, slightly oval)
  H.circle(img, ox + 8, 8, 4, base)
  -- Extend pod slightly taller
  H.rect(img, ox + 5, 5, ox + 11, 11, base)
  H.circle(img, ox + 8, 6, 3, base)
  H.circle(img, ox + 8, 10, 3, base)

  -- Top sprout
  H.px(img, ox + 7, 2, base)
  H.px(img, ox + 8, 1, base)
  H.px(img, ox + 9, 2, base)
  H.px(img, ox + 8, 2, hi)
  H.px(img, ox + 8, 3, base)
  -- Leaf nubs at top
  H.px(img, ox + 6, 3, base)
  H.px(img, ox + 5, 2, base)
  H.px(img, ox + 10, 3, base)
  H.px(img, ox + 11, 2, base)

  -- Tendril bottom-left
  H.px(img, ox + 4, 12, base)
  H.px(img, ox + 3, 13, base)
  H.px(img, ox + 2, 14, base)
  H.px(img, ox + 2, 13, dk)

  -- Tendril bottom-right
  H.px(img, ox + 12, 12, base)
  H.px(img, ox + 13, 13, base)
  H.px(img, ox + 14, 13, base)
  H.px(img, ox + 14, 12, dk)

  -- Tendril right side
  H.px(img, ox + 13, 9, base)
  H.px(img, ox + 14, 8, base)
  H.px(img, ox + 14, 9, dk)

  -- Highlights (upper-left lit)
  H.px(img, ox + 6, 5, hi)
  H.px(img, ox + 7, 4, hi)
  H.px(img, ox + 7, 5, hi)
  H.px(img, ox + 6, 6, hi)
  H.px(img, ox + 5, 6, hi)

  -- Glow spots (bioluminescent)
  H.px(img, ox + 8, 7, glow)
  H.px(img, ox + 7, 8, glow)
  H.px(img, ox + 9, 9, glow)
  H.px(img, ox + 6, 10, hi)

  -- Vein lines through pod
  H.line(img, ox + 8, 3, ox + 6, 11, dk)
  H.line(img, ox + 8, 4, ox + 10, 11, dk)
  H.px(img, ox + 9, 6, dk)

  -- Dark underside
  for x = 5, 11 do H.px(img, ox + x, 12, dk) end
  for x = 6, 10 do H.px(img, ox + x, 11, dk) end
  H.px(img, ox + 11, 10, dk)
  H.px(img, ox + 11, 9, dk)

  -- Deep shadow
  for x = 6, 10 do H.px(img, ox + x, 12, dp) end

  -- Outline
  local outline_pixels = {}
  for x = 1, 15 do
    for y = 0, 15 do
      local px_here = img:getPixel(ox + x, y)
      if px_here == T or px_here == 0 then
        for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
          local nx, ny = ox + x + d[1], y + d[2]
          if nx >= ox and nx < ox + 16 and ny >= 0 and ny < 16 then
            local np = img:getPixel(nx, ny)
            if np ~= T and np ~= 0 then
              table.insert(outline_pixels, {ox + x, y})
              break
            end
          end
        end
      end
    end
  end
  for _, p in ipairs(outline_pixels) do H.px(img, p[1], p[2], OL) end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEX 3: STEAM BURST — Swirling pink-purple vapor orb
-- Silhouette: soft round shape with wispy edges, cloud-like
-- ═══════════════════════════════════════════════════════════════════════════
local function draw_steam_burst(img, ox)
  local base = pal.steam_base
  local hi   = pal.steam_hi
  local dk   = pal.steam_dark
  local dp   = pal.steam_deep
  local glow = pal.steam_glow

  -- Main cloud body (overlapping circles for puffy shape)
  H.circle(img, ox + 8, 8, 5, base)
  H.circle(img, ox + 6, 7, 3, base)
  H.circle(img, ox + 10, 7, 3, base)
  H.circle(img, ox + 8, 5, 3, base)

  -- Wispy tendrils extending outward
  H.px(img, ox + 2, 7, base)
  H.px(img, ox + 2, 6, base)
  H.px(img, ox + 1, 6, dk)

  H.px(img, ox + 14, 7, base)
  H.px(img, ox + 14, 6, base)
  H.px(img, ox + 14, 5, dk)

  -- Top wisps
  H.px(img, ox + 7, 1, base)
  H.px(img, ox + 8, 1, base)
  H.px(img, ox + 6, 2, base)
  H.px(img, ox + 10, 2, base)

  -- Bottom wisps
  H.px(img, ox + 5, 13, base)
  H.px(img, ox + 11, 14, base)
  H.px(img, ox + 10, 13, base)

  -- Swirl pattern inside (darker)
  H.line(img, ox + 6, 5, ox + 10, 7, dk)
  H.line(img, ox + 10, 7, ox + 8, 10, dk)
  H.line(img, ox + 8, 10, ox + 5, 8, dk)
  H.px(img, ox + 7, 7, dp)

  -- Highlights
  H.px(img, ox + 5, 4, hi)
  H.px(img, ox + 6, 4, hi)
  H.px(img, ox + 5, 5, hi)
  H.px(img, ox + 4, 6, hi)
  H.px(img, ox + 7, 3, hi)
  H.px(img, ox + 9, 3, hi)

  -- Glow center
  H.px(img, ox + 8, 6, glow)
  H.px(img, ox + 9, 6, glow)
  H.px(img, ox + 8, 7, glow)
  H.px(img, ox + 7, 5, glow)

  -- Bottom shadow
  for x = 5, 11 do H.px(img, ox + x, 12, dk) end
  for x = 6, 10 do H.px(img, ox + x, 13, dp) end

  -- Outline
  local outline_pixels = {}
  for x = 0, 15 do
    for y = 0, 15 do
      local px_here = img:getPixel(ox + x, y)
      if px_here == T or px_here == 0 then
        for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
          local nx, ny = ox + x + d[1], y + d[2]
          if nx >= ox and nx < ox + 16 and ny >= 0 and ny < 16 then
            local np = img:getPixel(nx, ny)
            if np ~= T and np ~= 0 then
              table.insert(outline_pixels, {ox + x, y})
              break
            end
          end
        end
      end
    end
  end
  for _, p in ipairs(outline_pixels) do H.px(img, p[1], p[2], OL) end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEX 4: VERDANT COMPOUND — Crystallized leaf, angular but organic
-- Silhouette: leaf/arrow shape with crystalline facets
-- ═══════════════════════════════════════════════════════════════════════════
local function draw_verdant_compound(img, ox)
  local base = pal.verd_base
  local hi   = pal.verd_hi
  local dk   = pal.verd_dark
  local dp   = pal.verd_deep
  local glow = pal.verd_glow

  -- Leaf/arrowhead shape: wide at middle, pointed at top and bottom
  -- Build silhouette column by column
  local rows = {
  -- y, x_left, x_right (0-indexed within cell)
    {1,  7, 8},
    {2,  6, 9},
    {3,  5, 10},
    {4,  4, 11},
    {5,  3, 12},
    {6,  2, 13},
    {7,  2, 13},
    {8,  3, 12},
    {9,  3, 12},
    {10, 4, 11},
    {11, 5, 10},
    {12, 6, 9},
    {13, 7, 8},
    {14, 7, 8},
  }

  for _, r in ipairs(rows) do
    for x = r[2], r[3] do
      H.px(img, ox + x, r[1], base)
    end
  end

  -- Stem at bottom
  H.px(img, ox + 7, 14, dk)
  H.px(img, ox + 8, 14, dk)

  -- Central vein (darker, vertical)
  for y = 2, 13 do
    H.px(img, ox + 7, y, dk)
    H.px(img, ox + 8, y, dk)
  end

  -- Crystal facet lines (diagonal)
  H.line(img, ox + 7, 2, ox + 3, 6, dk)
  H.line(img, ox + 8, 2, ox + 12, 6, dk)
  H.line(img, ox + 7, 8, ox + 4, 11, dk)
  H.line(img, ox + 8, 8, ox + 11, 11, dk)

  -- Highlights (upper-left facets)
  H.px(img, ox + 5, 4, hi)
  H.px(img, ox + 4, 5, hi)
  H.px(img, ox + 3, 6, hi)
  H.px(img, ox + 4, 6, hi)
  H.px(img, ox + 6, 3, hi)
  H.px(img, ox + 5, 5, hi)
  H.px(img, ox + 4, 9, hi)
  H.px(img, ox + 5, 10, hi)

  -- Glow along center
  H.px(img, ox + 7, 4, glow)
  H.px(img, ox + 8, 5, glow)
  H.px(img, ox + 7, 7, glow)
  H.px(img, ox + 8, 9, glow)
  H.px(img, ox + 7, 11, glow)

  -- Dark right facets
  H.px(img, ox + 11, 5, dk)
  H.px(img, ox + 12, 6, dk)
  H.px(img, ox + 12, 7, dk)
  H.px(img, ox + 11, 9, dk)
  H.px(img, ox + 11, 10, dk)
  H.px(img, ox + 10, 11, dk)

  -- Deep shadow
  for x = 6, 9 do H.px(img, ox + x, 13, dp) end

  -- Outline
  local outline_pixels = {}
  for x = 1, 15 do
    for y = 0, 15 do
      local px_here = img:getPixel(ox + x, y)
      if px_here == T or px_here == 0 then
        for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
          local nx, ny = ox + x + d[1], y + d[2]
          if nx >= ox and nx < ox + 16 and ny >= 0 and ny < 16 then
            local np = img:getPixel(nx, ny)
            if np ~= T and np ~= 0 then
              table.insert(outline_pixels, {ox + x, y})
              break
            end
          end
        end
      end
    end
  end
  for _, p in ipairs(outline_pixels) do H.px(img, p[1], p[2], OL) end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEX 5: FROZEN FLAME — Purple flame crystal with organic veins
-- Silhouette: flame shape but with crystalline edges, veiny texture
-- ═══════════════════════════════════════════════════════════════════════════
local function draw_frozen_flame(img, ox)
  local base = pal.frozen_base
  local hi   = pal.frozen_hi
  local dk   = pal.frozen_dark
  local dp   = pal.frozen_deep
  local glow = pal.frozen_glow

  -- Flame body with crystalline facets
  local rows = {
  -- y, x_left, x_right
    {1,  7, 8},
    {2,  6, 9},
    {3,  5, 9},
    {4,  5, 10},
    {5,  4, 11},
    {6,  3, 11},
    {7,  3, 12},
    {8,  3, 12},
    {9,  2, 13},
    {10, 2, 13},
    {11, 3, 12},
    {12, 4, 11},
    {13, 5, 10},
    {14, 6, 9},
  }

  for _, r in ipairs(rows) do
    for x = r[2], r[3] do
      H.px(img, ox + x, r[1], base)
    end
  end

  -- Flickering tip extensions (flame-like)
  H.px(img, ox + 7, 0, base)
  H.px(img, ox + 8, 0, dk)
  -- Side flickers
  H.px(img, ox + 2, 8, base)
  H.px(img, ox + 1, 9, base)
  H.px(img, ox + 13, 8, base)
  H.px(img, ox + 14, 9, base)

  -- Crystal facet lines (angular breaks in the organic form)
  H.line(img, ox + 7, 1, ox + 4, 8, dk)
  H.line(img, ox + 8, 1, ox + 12, 9, dk)
  H.line(img, ox + 5, 10, ox + 8, 14, dk)
  H.line(img, ox + 10, 10, ox + 8, 14, dk)

  -- Organic vein network
  H.line(img, ox + 6, 5, ox + 4, 11, dp)
  H.line(img, ox + 10, 5, ox + 12, 10, dp)
  H.px(img, ox + 7, 8, dp)
  H.px(img, ox + 9, 7, dp)

  -- Highlights (upper flames)
  H.px(img, ox + 6, 3, hi)
  H.px(img, ox + 6, 4, hi)
  H.px(img, ox + 5, 5, hi)
  H.px(img, ox + 5, 6, hi)
  H.px(img, ox + 4, 7, hi)
  H.px(img, ox + 7, 2, hi)

  -- Glow core
  H.px(img, ox + 7, 5, glow)
  H.px(img, ox + 8, 6, glow)
  H.px(img, ox + 7, 7, glow)
  H.px(img, ox + 8, 8, glow)
  H.px(img, ox + 7, 9, glow)
  H.px(img, ox + 8, 10, hi)

  -- Dark base/sides
  for y = 9, 13 do H.px(img, ox + 12, y, dk) end
  for y = 9, 13 do H.px(img, ox + 13, y, dk) end
  for x = 5, 10 do H.px(img, ox + x, 14, dp) end
  for x = 4, 11 do H.px(img, ox + x, 13, dk) end

  -- Outline
  local outline_pixels = {}
  for x = 0, 15 do
    for y = 0, 15 do
      local px_here = img:getPixel(ox + x, y)
      if px_here == T or px_here == 0 then
        for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
          local nx, ny = ox + x + d[1], y + d[2]
          if nx >= ox and nx < ox + 16 and ny >= 0 and ny < 16 then
            local np = img:getPixel(nx, ny)
            if np ~= T and np ~= 0 then
              table.insert(outline_pixels, {ox + x, y})
              break
            end
          end
        end
      end
    end
  end
  for _, p in ipairs(outline_pixels) do H.px(img, p[1], p[2], OL) end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DRAW ALL ITEMS
-- ═══════════════════════════════════════════════════════════════════════════

draw_pyromite(img, cell_x(0))
draw_crystalline(img, cell_x(1))
draw_biovine(img, cell_x(2))
draw_steam_burst(img, cell_x(3))
draw_verdant_compound(img, cell_x(4))
draw_frozen_flame(img, cell_x(5))
-- Index 6 & 7: reserved (transparent)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORT
-- ═══════════════════════════════════════════════════════════════════════════

spr:newCel(layer, spr.frames[1], img, Point(0, 0))

local out_dir = "/Users/gorishniymax/Repos/factor/resources/items/sprites"
spr:saveAs(out_dir .. "/item_atlas.aseprite")

-- Export as PNG directly
spr:saveCopyAs(out_dir .. "/item_atlas.png")
print("Exported: " .. out_dir .. "/item_atlas.png")

spr:close()
