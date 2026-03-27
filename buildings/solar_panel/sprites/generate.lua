-- solar_panel_sprite.lua
-- Top-down solar panel: photovoltaic grid with sweeping shimmer.
-- 2 layers (base, top), 4 frames with light reflection sweep.

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, FH = 32, 32
local LAYERS = {"base", "top"}
local TAGS = {
  {name="default", from=1, to=4, duration=0.3},
}
local DIR = "/Users/gorishniymax/Repos/factor/buildings/solar_panel/sprites"

-- Solar panel identity: deep blue cells
local FRAME   = H.hex("#404850")
local FRAME_DK= H.hex("#303840")
local FRAME_LT= H.hex("#505860")
local CELL    = H.hex("#1A3060")
local CELL_LT = H.hex("#2A4080")
local CELL_DK = H.hex("#102050")
local GRID    = H.hex("#506070")
local SHINE   = H.hex("#80B0E0")
local SHINE_BR= H.hex("#C0E0FF")
local IND_ON  = H.hex("#4CAF50")

local function draw_base(img, tag, phase)
  -- Panel frame
  H.rect_outline(img, 0, 0, 31, 31, C.outline)
  H.rect(img, 1, 1, 30, 30, FRAME)
  H.shaded_rect(img, 2, 2, 29, 29, FRAME, FRAME_LT, FRAME_DK)
  -- Solar cells: 2x2 grid of cells
  -- Cell 1 (top-left)
  H.rect(img, 4, 4, 14, 14, CELL)
  H.rect(img, 5, 5, 13, 13, CELL_LT)
  -- Cell 2 (top-right)
  H.rect(img, 17, 4, 27, 14, CELL)
  H.rect(img, 18, 5, 26, 13, CELL_LT)
  -- Cell 3 (bottom-left)
  H.rect(img, 4, 17, 14, 27, CELL)
  H.rect(img, 5, 18, 13, 26, CELL_LT)
  -- Cell 4 (bottom-right)
  H.rect(img, 17, 17, 27, 27, CELL)
  H.rect(img, 18, 18, 26, 26, CELL_LT)
  -- Grid lines (dividers between cells)
  H.line(img, 15, 3, 15, 28, GRID)
  H.line(img, 16, 3, 16, 28, GRID)
  H.line(img, 3, 15, 28, 15, GRID)
  H.line(img, 3, 16, 28, 16, GRID)
  -- Sub-cell grid lines
  for _, x in ipairs({9, 22}) do
    H.line(img, x, 4, x, 14, CELL_DK)
    H.line(img, x, 17, x, 27, CELL_DK)
  end
  for _, y in ipairs({9, 22}) do
    H.line(img, 4, y, 14, y, CELL_DK)
    H.line(img, 17, y, 27, y, CELL_DK)
  end
  -- Corner mounting bolts
  for _, p in ipairs({{3,3},{28,3},{3,28},{28,28}}) do
    H.px(img, p[1], p[2], C.rivet)
  end
end

local function draw_top(img, tag, phase)
  -- Sweeping light reflection across the panel
  -- Diagonal shine line that moves across per frame
  local shine_x = 4 + phase * 7  -- sweeps from left to right
  for i = -1, 1 do
    local sx = shine_x + i
    for y = 4, 27 do
      local sy = y
      if sx >= 4 and sx <= 27 and sy >= 4 and sy <= 27 then
        -- Skip grid lines
        if not (sx == 15 or sx == 16 or sy == 15 or sy == 16) then
          local c = (i == 0) and SHINE_BR or SHINE
          H.px(img, sx, sy, c)
        end
      end
    end
    -- Diagonal: shine also on adjacent diagonal
    local dx = shine_x + i + 3
    for y = 4, 27 do
      local dy = y - 3
      if dx >= 4 and dx <= 27 and dy >= 4 and dy <= 27 then
        if not (dx == 15 or dx == 16 or dy == 15 or dy == 16) then
          H.px(img, dx, dy, SHINE)
        end
      end
    end
  end
  -- Energy indicator dot (bottom-right corner)
  H.px(img, 28, 28, IND_ON)
  H.px(img, 27, 28, IND_ON)
  H.px(img, 28, 27, IND_ON)
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr, DIR, "main")
print("[solar_panel] done")
