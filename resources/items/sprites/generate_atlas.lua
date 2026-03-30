-- generate_atlas.lua
-- Item atlas: 8 columns x 5 rows = 128x80 pixels, each cell 16x16.
-- Run: aseprite -b --script resources/items/sprites/generate_atlas.lua

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")

local CELL = 16
local COLS, ROWS = 8, 5
local W, HT = COLS * CELL, ROWS * CELL

-- ═══════════════════════════════════════════════════════════════════════════
-- COLOR PALETTE
-- ═══════════════════════════════════════════════════════════════════════════

local T = H.TRANSPARENT

-- Outline
local OL = H.hex("#1A1A2E")

-- Iron ore
local IRON_BASE    = H.hex("#7A7A8A")
local IRON_LIGHT   = H.hex("#9A9AAA")
local IRON_DARK    = H.hex("#4A4A5A")
local IRON_CRACK   = H.hex("#33334A")

-- Copper ore
local CU_BASE      = H.hex("#B87333")
local CU_LIGHT     = H.hex("#D4944A")
local CU_DARK      = H.hex("#8B5523")
local CU_CRACK     = H.hex("#6B3B13")

-- Coal
local COAL_BASE    = H.hex("#2A2A2E")
local COAL_LIGHT   = H.hex("#3E3E44")
local COAL_DARK    = H.hex("#1A1A1E")
local COAL_GLINT   = H.hex("#5A5A6A")

-- Stone
local STONE_BASE   = H.hex("#B0A890")
local STONE_LIGHT  = H.hex("#CCC4AA")
local STONE_DARK   = H.hex("#8A8270")
local STONE_CRACK  = H.hex("#706858")

-- Tin ore
local TIN_BASE     = H.hex("#8899AA")
local TIN_LIGHT    = H.hex("#A8B8CC")
local TIN_DARK     = H.hex("#667788")
local TIN_CRACK    = H.hex("#4A5A6A")

-- Gold ore
local GOLD_BASE    = H.hex("#E8C840")
local GOLD_LIGHT   = H.hex("#FFE878")
local GOLD_DARK    = H.hex("#B89830")
local GOLD_DEEP    = H.hex("#8A7020")

-- Quartz
local QRTZ_BASE    = H.hex("#B0C8E8")
local QRTZ_LIGHT   = H.hex("#D0E0FF")
local QRTZ_DARK    = H.hex("#7898C0")
local QRTZ_EDGE    = H.hex("#5878A0")

-- Sulfur
local SULF_BASE    = H.hex("#C8CC44")
local SULF_LIGHT   = H.hex("#E8F070")
local SULF_DARK    = H.hex("#909820")
local SULF_EDGE    = H.hex("#6A7018")

-- Iron plate
local IPLATE_BASE  = H.hex("#8888A0")
local IPLATE_HI    = H.hex("#AAAABC")
local IPLATE_SH    = H.hex("#5A5A72")

-- Copper plate
local CPLATE_BASE  = H.hex("#D4884A")
local CPLATE_HI    = H.hex("#F0A868")
local CPLATE_SH    = H.hex("#A06030")

-- Tin plate
local TPLATE_BASE  = H.hex("#99AABC")
local TPLATE_HI    = H.hex("#B8C8DC")
local TPLATE_SH    = H.hex("#6A7A8C")

-- Gold ingot
local GBAR_BASE    = H.hex("#E8C840")
local GBAR_HI      = H.hex("#FFE870")
local GBAR_SH      = H.hex("#B89828")

-- Steel
local STEEL_BASE   = H.hex("#5A6070")
local STEEL_HI     = H.hex("#788090")
local STEEL_SH     = H.hex("#3A4050")

-- Glass
local GLASS_BASE   = H.hex("#C0D8F0")
local GLASS_HI     = H.hex("#E8F0FF")
local GLASS_SH     = H.hex("#88A8C8")
local GLASS_SHEEN  = H.hex("#FFFFFF")

-- Brick
local BRICK_BASE   = H.hex("#A85030")
local BRICK_HI     = H.hex("#C87050")
local BRICK_SH     = H.hex("#783020")
local BRICK_MORT   = H.hex("#C8B898")

-- Coke
local COKE_BASE    = H.hex("#382828")
local COKE_LIGHT   = H.hex("#504038")
local COKE_DARK    = H.hex("#201818")

-- Copper wire
local CWIRE_BASE   = H.hex("#D88840")
local CWIRE_HI     = H.hex("#F0A858")
local CWIRE_SH     = H.hex("#A06028")

-- Gold wire
local GWIRE_BASE   = H.hex("#E8C840")
local GWIRE_HI     = H.hex("#FFE060")
local GWIRE_SH     = H.hex("#B89828")

-- Iron gear
local GEAR_BASE    = H.hex("#7A7A8C")
local GEAR_HI      = H.hex("#9898AC")
local GEAR_SH      = H.hex("#50506A")
local GEAR_HOLE    = H.hex("#2A2A3E")

-- Iron tube
local TUBE_BASE    = H.hex("#8888A0")
local TUBE_HI      = H.hex("#A8A8BC")
local TUBE_SH      = H.hex("#5A5A72")
local TUBE_HOLE    = H.hex("#3A3A52")

-- Tin can
local CAN_BASE     = H.hex("#A0B0C0")
local CAN_HI       = H.hex("#C0D0DD")
local CAN_SH       = H.hex("#708090")
local CAN_RIM      = H.hex("#B8C8D8")

-- Steel beam
local BEAM_BASE    = H.hex("#4A5060")
local BEAM_HI      = H.hex("#687888")
local BEAM_SH      = H.hex("#303848")

-- Glass lens
local LENS_BASE    = H.hex("#B0D0F0")
local LENS_HI      = H.hex("#D8EAFF")
local LENS_SH      = H.hex("#6898C0")
local LENS_GLEAM   = H.hex("#FFFFFF")

-- Pipe
local PIPE_BASE    = H.hex("#707888")
local PIPE_HI      = H.hex("#9098A8")
local PIPE_SH      = H.hex("#484858")
local PIPE_FLANGE  = H.hex("#8890A0")

-- Circuit board
local PCB_BASE     = H.hex("#2A8040")
local PCB_LIGHT    = H.hex("#40A058")
local PCB_TRACE    = H.hex("#D0D080")
local PCB_DARK     = H.hex("#1A6030")

-- Motor
local MOT_BODY     = H.hex("#606878")
local MOT_HI       = H.hex("#808898")
local MOT_SH       = H.hex("#404858")
local MOT_COIL     = H.hex("#D08838")
local MOT_COIL_HI  = H.hex("#F0A858")

-- Battery
local BAT_BASE     = H.hex("#4060A8")
local BAT_HI       = H.hex("#6080C8")
local BAT_SH       = H.hex("#2A4080")
local BAT_PLUS     = H.hex("#E03030")
local BAT_MINUS    = H.hex("#303030")
local BAT_TOP      = H.hex("#888898")

-- Steel frame
local FRAME_BASE   = H.hex("#5A6070")
local FRAME_HI     = H.hex("#7A8090")
local FRAME_SH     = H.hex("#3A4050")

-- Concrete
local CONC_BASE    = H.hex("#989898")
local CONC_HI      = H.hex("#B0B0B0")
local CONC_SH      = H.hex("#707070")
local CONC_SPECK1  = H.hex("#808080")
local CONC_SPECK2  = H.hex("#A8A8A8")

-- Advanced circuit
local ADV_BASE     = H.hex("#283878")
local ADV_LIGHT    = H.hex("#3A4888")
local ADV_TRACE    = H.hex("#E8C840")
local ADV_DARK     = H.hex("#1A2858")

-- Processor
local PROC_BASE    = H.hex("#1A1A1E")
local PROC_TOP     = H.hex("#2A2A30")
local PROC_PIN     = H.hex("#E8C840")
local PROC_DIE     = H.hex("#404048")

-- Engine
local ENG_BODY     = H.hex("#505868")
local ENG_HI       = H.hex("#707888")
local ENG_SH       = H.hex("#303840")
local ENG_CYL      = H.hex("#606878")
local ENG_BOLT     = H.hex("#D08838")

-- Science pack 1 (red)
local SP1_GLASS    = H.hex("#C0D0E0")
local SP1_LIQUID   = H.hex("#D83030")
local SP1_LIQ_HI   = H.hex("#F05050")
local SP1_LIQ_SH   = H.hex("#A02020")
local SP1_CORK     = H.hex("#A88060")

-- Science pack 2 (green)
local SP2_LIQUID   = H.hex("#30B840")
local SP2_LIQ_HI   = H.hex("#50D860")
local SP2_LIQ_SH   = H.hex("#208830")

-- Science pack 3 (blue)
local SP3_LIQUID   = H.hex("#3060D8")
local SP3_LIQ_HI   = H.hex("#5080F0")
local SP3_LIQ_SH   = H.hex("#2040A0")

-- Robo frame
local ROBO_BASE    = H.hex("#A0A8B8")
local ROBO_HI      = H.hex("#C0C8D8")
local ROBO_SH      = H.hex("#606878")
local ROBO_EYE     = H.hex("#40D0F0")
local ROBO_JOINT   = H.hex("#707880")

-- Energy (lightning bolt)
local NRG_BASE     = H.hex("#F0D030")
local NRG_HI       = H.hex("#FFE870")
local NRG_SH       = H.hex("#C8A020")
local NRG_DARK     = H.hex("#987818")


-- ═══════════════════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

-- Get the top-left pixel of cell (row, col) in the atlas
local function cell_origin(row, col)
  return col * CELL, row * CELL
end

-- Shortcut: draw pixel relative to cell origin
local function cpx(img, ox, oy, row, col, c)
  local bx, by = cell_origin(row, col)
  H.px(img, bx + ox, by + oy, c)
end

-- Shortcut: draw rect relative to cell origin
local function crect(img, x1, y1, x2, y2, row, col, c)
  local bx, by = cell_origin(row, col)
  H.rect(img, bx + x1, by + y1, bx + x2, by + y2, c)
end

-- Shortcut: draw shaded rect relative to cell origin
local function cshaded(img, x1, y1, x2, y2, row, col, fill, hi, sh)
  local bx, by = cell_origin(row, col)
  H.shaded_rect(img, bx + x1, by + y1, bx + x2, by + y2, fill, hi, sh)
end

-- Shortcut: draw rect outline relative to cell origin
local function coutline(img, x1, y1, x2, y2, row, col, c)
  local bx, by = cell_origin(row, col)
  H.rect_outline(img, bx + x1, by + y1, bx + x2, by + y2, c)
end

-- Shortcut: draw line relative to cell origin
local function cline(img, x1, y1, x2, y2, row, col, c)
  local bx, by = cell_origin(row, col)
  H.line(img, bx + x1, by + y1, bx + x2, by + y2, c)
end

-- Shortcut: draw circle relative to cell origin
local function ccircle(img, cx, cy, r, row, col, c)
  local bx, by = cell_origin(row, col)
  H.circle(img, bx + cx, by + cy, r, c)
end

-- Shortcut: draw circle outline relative to cell origin
local function ccircle_ol(img, cx, cy, r, row, col, c)
  local bx, by = cell_origin(row, col)
  H.circle_outline(img, bx + cx, by + cy, r, c)
end


-- ═══════════════════════════════════════════════════════════════════════════
-- ORE CHUNK TEMPLATE: irregular chunky shape with cracks
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_ore_chunk(img, row, col, base, light, dark, crack)
  -- Main body: irregular polygon approximated with overlapping rects
  crect(img, 4, 4, 12, 12, row, col, base)
  crect(img, 3, 5, 13, 11, row, col, base)
  crect(img, 5, 3, 11, 13, row, col, base)
  -- Highlight: top-left region
  crect(img, 4, 4, 8, 6, row, col, light)
  cpx(img, 3, 5, row, col, light)
  cpx(img, 3, 6, row, col, light)
  cpx(img, 5, 3, row, col, light)
  cpx(img, 6, 3, row, col, light)
  -- Shadow: bottom-right region
  crect(img, 9, 11, 12, 12, row, col, dark)
  crect(img, 11, 9, 12, 12, row, col, dark)
  cpx(img, 13, 10, row, col, dark)
  cpx(img, 13, 11, row, col, dark)
  cpx(img, 10, 13, row, col, dark)
  cpx(img, 11, 13, row, col, dark)
  -- Cracks / detail lines
  cpx(img, 6, 7, row, col, crack)
  cpx(img, 7, 8, row, col, crack)
  cpx(img, 8, 8, row, col, crack)
  cpx(img, 9, 9, row, col, crack)
  cpx(img, 5, 10, row, col, crack)
  cpx(img, 6, 11, row, col, crack)
  -- Outline
  -- Top edge
  cline(img, 5, 2, 11, 2, row, col, OL)
  cpx(img, 4, 3, row, col, OL)
  cpx(img, 12, 3, row, col, OL)
  -- Left edge
  cpx(img, 2, 5, row, col, OL)
  cpx(img, 2, 6, row, col, OL)
  cline(img, 2, 7, 2, 10, row, col, OL)
  cpx(img, 2, 11, row, col, OL)
  -- Right edge
  cpx(img, 14, 7, row, col, OL)
  cpx(img, 14, 8, row, col, OL)
  cline(img, 13, 5, 13, 6, row, col, OL)
  cline(img, 14, 9, 14, 10, row, col, OL)
  -- Bottom edge
  cpx(img, 3, 12, row, col, OL)
  cline(img, 4, 13, 10, 13, row, col, OL)
  cpx(img, 11, 14, row, col, OL)
  cpx(img, 12, 13, row, col, OL)
  cpx(img, 13, 12, row, col, OL)
end


-- ═══════════════════════════════════════════════════════════════════════════
-- PLATE TEMPLATE: flat rectangle with bevel
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_plate(img, row, col, base, hi, sh)
  cshaded(img, 3, 5, 12, 11, row, col, base, hi, sh)
  coutline(img, 3, 5, 12, 11, row, col, OL)
  -- Extra bevel highlight along top-left interior
  cpx(img, 4, 6, row, col, hi)
  cpx(img, 5, 6, row, col, hi)
  cpx(img, 4, 7, row, col, hi)
end


-- ═══════════════════════════════════════════════════════════════════════════
-- FLASK TEMPLATE for science packs
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_flask(img, row, col, liquid, liq_hi, liq_sh, glass, cork)
  -- Flask body (rounded bottom)
  crect(img, 5, 7, 10, 13, row, col, glass)
  cpx(img, 4, 8, row, col, glass)
  cpx(img, 4, 9, row, col, glass)
  cpx(img, 4, 10, row, col, glass)
  cpx(img, 4, 11, row, col, glass)
  cpx(img, 4, 12, row, col, glass)
  cpx(img, 11, 8, row, col, glass)
  cpx(img, 11, 9, row, col, glass)
  cpx(img, 11, 10, row, col, glass)
  cpx(img, 11, 11, row, col, glass)
  cpx(img, 11, 12, row, col, glass)
  cpx(img, 5, 14, row, col, glass)
  cpx(img, 6, 14, row, col, glass)
  cpx(img, 9, 14, row, col, glass)
  cpx(img, 10, 14, row, col, glass)
  -- Neck
  crect(img, 6, 4, 9, 6, row, col, glass)
  -- Cork/stopper
  crect(img, 6, 2, 9, 3, row, col, cork)
  coutline(img, 6, 2, 9, 3, row, col, OL)
  -- Liquid fill (lower body)
  crect(img, 5, 9, 10, 13, row, col, liquid)
  cpx(img, 4, 9, row, col, liquid)
  cpx(img, 4, 10, row, col, liquid)
  cpx(img, 4, 11, row, col, liquid)
  cpx(img, 4, 12, row, col, liquid)
  cpx(img, 11, 9, row, col, liquid)
  cpx(img, 11, 10, row, col, liquid)
  cpx(img, 11, 11, row, col, liquid)
  cpx(img, 11, 12, row, col, liquid)
  cpx(img, 5, 14, row, col, liquid)
  cpx(img, 6, 14, row, col, liquid)
  cpx(img, 9, 14, row, col, liquid)
  cpx(img, 10, 14, row, col, liquid)
  -- Liquid highlight
  cpx(img, 5, 9, row, col, liq_hi)
  cpx(img, 6, 9, row, col, liq_hi)
  cpx(img, 5, 10, row, col, liq_hi)
  -- Liquid shadow
  cpx(img, 10, 13, row, col, liq_sh)
  cpx(img, 9, 14, row, col, liq_sh)
  cpx(img, 10, 14, row, col, liq_sh)
  cpx(img, 11, 11, row, col, liq_sh)
  cpx(img, 11, 12, row, col, liq_sh)
  -- Glass sheen
  cpx(img, 5, 7, row, col, GLASS_SHEEN)
  cpx(img, 5, 8, row, col, H.with_alpha(GLASS_SHEEN, 180))
  -- Outline
  -- Body outline
  cpx(img, 3, 8, row, col, OL)
  cline(img, 3, 9, 3, 12, row, col, OL)
  cpx(img, 4, 7, row, col, OL)
  cpx(img, 4, 13, row, col, OL)
  cline(img, 5, 6, 10, 6, row, col, OL)
  cpx(img, 11, 7, row, col, OL)
  cpx(img, 12, 8, row, col, OL)
  cline(img, 12, 9, 12, 12, row, col, OL)
  cpx(img, 11, 13, row, col, OL)
  cline(img, 5, 15, 6, 15, row, col, OL)
  cpx(img, 4, 13, row, col, OL)
  cline(img, 7, 14, 8, 14, row, col, OL)
  cline(img, 9, 15, 10, 15, row, col, OL)
  -- Neck outline
  cpx(img, 5, 4, row, col, OL)
  cpx(img, 5, 5, row, col, OL)
  cpx(img, 10, 4, row, col, OL)
  cpx(img, 10, 5, row, col, OL)
end


-- ═══════════════════════════════════════════════════════════════════════════
-- DRAWING ALL ITEMS
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_all(img)

  -- ═════════════════════════════════════════════════════════════════════════
  -- ROW 0: RAW RESOURCES
  -- ═════════════════════════════════════════════════════════════════════════

  -- (0,0) iron_ore
  draw_ore_chunk(img, 0, 0, IRON_BASE, IRON_LIGHT, IRON_DARK, IRON_CRACK)

  -- (0,1) copper_ore
  draw_ore_chunk(img, 0, 1, CU_BASE, CU_LIGHT, CU_DARK, CU_CRACK)

  -- (0,2) coal
  draw_ore_chunk(img, 0, 2, COAL_BASE, COAL_LIGHT, COAL_DARK, COAL_DARK)
  -- Add glint pixels
  cpx(img, 5, 5, 0, 2, COAL_GLINT)
  cpx(img, 9, 7, 0, 2, COAL_GLINT)
  cpx(img, 7, 10, 0, 2, COAL_GLINT)

  -- (0,3) stone
  draw_ore_chunk(img, 0, 3, STONE_BASE, STONE_LIGHT, STONE_DARK, STONE_CRACK)

  -- (0,4) tin_ore
  draw_ore_chunk(img, 0, 4, TIN_BASE, TIN_LIGHT, TIN_DARK, TIN_CRACK)

  -- (0,5) gold_ore - slightly smaller, nugget-like
  crect(img, 5, 5, 11, 11, 0, 5, GOLD_BASE)
  crect(img, 4, 6, 12, 10, 0, 5, GOLD_BASE)
  crect(img, 6, 4, 10, 12, 0, 5, GOLD_BASE)
  -- Highlight
  crect(img, 5, 5, 8, 7, 0, 5, GOLD_LIGHT)
  cpx(img, 4, 6, 0, 5, GOLD_LIGHT)
  cpx(img, 6, 4, 0, 5, GOLD_LIGHT)
  -- Shadow
  crect(img, 10, 10, 11, 11, 0, 5, GOLD_DARK)
  cpx(img, 12, 9, 0, 5, GOLD_DARK)
  cpx(img, 12, 10, 0, 5, GOLD_DARK)
  cpx(img, 10, 12, 0, 5, GOLD_DARK)
  -- Deep shadow
  cpx(img, 11, 11, 0, 5, GOLD_DEEP)
  -- Outline
  cline(img, 6, 3, 10, 3, 0, 5, OL)
  cpx(img, 5, 4, 0, 5, OL)
  cpx(img, 11, 4, 0, 5, OL)
  cpx(img, 3, 6, 0, 5, OL)
  cline(img, 3, 7, 3, 9, 0, 5, OL)
  cpx(img, 4, 5, 0, 5, OL)
  cpx(img, 4, 10, 0, 5, OL)
  cpx(img, 3, 10, 0, 5, OL)
  cpx(img, 13, 6, 0, 5, OL)
  cline(img, 13, 7, 13, 9, 0, 5, OL)
  cpx(img, 12, 5, 0, 5, OL)
  cpx(img, 11, 4, 0, 5, OL)
  cpx(img, 12, 11, 0, 5, OL)
  cpx(img, 11, 12, 0, 5, OL)
  cline(img, 6, 13, 10, 13, 0, 5, OL)
  cpx(img, 5, 12, 0, 5, OL)
  cpx(img, 4, 11, 0, 5, OL)
  cpx(img, 11, 13, 0, 5, OL)

  -- (0,6) quartz - crystal shard, angular shape
  -- Tall pointed crystal
  cpx(img, 7, 2, 0, 6, QRTZ_LIGHT)
  cpx(img, 8, 2, 0, 6, QRTZ_LIGHT)
  crect(img, 6, 3, 9, 4, 0, 6, QRTZ_LIGHT)
  crect(img, 5, 5, 10, 7, 0, 6, QRTZ_BASE)
  crect(img, 5, 8, 10, 10, 0, 6, QRTZ_BASE)
  crect(img, 4, 6, 4, 9, 0, 6, QRTZ_BASE)
  cpx(img, 11, 7, 0, 6, QRTZ_BASE)
  cpx(img, 11, 8, 0, 6, QRTZ_BASE)
  crect(img, 5, 11, 10, 13, 0, 6, QRTZ_DARK)
  cpx(img, 4, 10, 0, 6, QRTZ_DARK)
  cpx(img, 11, 10, 0, 6, QRTZ_DARK)
  -- Highlight facet
  cpx(img, 6, 3, 0, 6, QRTZ_LIGHT)
  cpx(img, 7, 3, 0, 6, QRTZ_LIGHT)
  cpx(img, 5, 5, 0, 6, QRTZ_LIGHT)
  cpx(img, 6, 5, 0, 6, QRTZ_LIGHT)
  cpx(img, 6, 6, 0, 6, H.hex("#E0EEFF"))
  -- Outline
  cpx(img, 6, 1, 0, 6, OL)
  cpx(img, 9, 1, 0, 6, OL)
  cpx(img, 5, 2, 0, 6, OL)
  cpx(img, 10, 2, 0, 6, OL)
  cpx(img, 4, 4, 0, 6, OL)
  cpx(img, 11, 4, 0, 6, OL)
  cpx(img, 3, 5, 0, 6, OL)
  cline(img, 3, 6, 3, 10, 0, 6, OL)
  cpx(img, 12, 6, 0, 6, OL)
  cpx(img, 12, 7, 0, 6, OL)
  cpx(img, 12, 8, 0, 6, OL)
  cpx(img, 12, 9, 0, 6, OL)
  cpx(img, 11, 5, 0, 6, OL)
  cpx(img, 11, 11, 0, 6, OL)
  cpx(img, 4, 11, 0, 6, OL)
  cline(img, 4, 14, 11, 14, 0, 6, OL)
  cpx(img, 4, 12, 0, 6, OL)
  cpx(img, 4, 13, 0, 6, OL)
  cpx(img, 11, 12, 0, 6, OL)
  cpx(img, 11, 13, 0, 6, OL)

  -- (0,7) sulfur - crystalline chunk, yellow-green
  draw_ore_chunk(img, 0, 7, SULF_BASE, SULF_LIGHT, SULF_DARK, SULF_EDGE)
  -- Add crystalline facet highlights
  cpx(img, 5, 5, 0, 7, SULF_LIGHT)
  cpx(img, 6, 4, 0, 7, SULF_LIGHT)
  cpx(img, 8, 6, 0, 7, H.hex("#F0FF90"))


  -- ═════════════════════════════════════════════════════════════════════════
  -- ROW 1: SMELTED / BASIC MATERIALS
  -- ═════════════════════════════════════════════════════════════════════════

  -- (1,0) iron_plate
  draw_plate(img, 1, 0, IPLATE_BASE, IPLATE_HI, IPLATE_SH)

  -- (1,1) copper_plate
  draw_plate(img, 1, 1, CPLATE_BASE, CPLATE_HI, CPLATE_SH)

  -- (1,2) tin_plate
  draw_plate(img, 1, 2, TPLATE_BASE, TPLATE_HI, TPLATE_SH)

  -- (1,3) gold_ingot - small bar shape, taller than plates
  cshaded(img, 4, 4, 11, 12, 1, 3, GBAR_BASE, GBAR_HI, GBAR_SH)
  coutline(img, 4, 4, 11, 12, 1, 3, OL)
  -- Trapezoidal top bevel
  cpx(img, 5, 5, 1, 3, GBAR_HI)
  cpx(img, 6, 5, 1, 3, GBAR_HI)
  cpx(img, 7, 5, 1, 3, GBAR_HI)
  cpx(img, 5, 6, 1, 3, GBAR_HI)

  -- (1,4) steel - dark blue-gray bar, thicker
  cshaded(img, 3, 4, 12, 12, 1, 4, STEEL_BASE, STEEL_HI, STEEL_SH)
  coutline(img, 3, 4, 12, 12, 1, 4, OL)
  -- Subtle center line
  cline(img, 4, 8, 11, 8, 1, 4, STEEL_HI)

  -- (1,5) glass - transparent-looking sheet
  cshaded(img, 3, 5, 12, 11, 1, 5, GLASS_BASE, GLASS_HI, GLASS_SH)
  coutline(img, 3, 5, 12, 11, 1, 5, OL)
  -- Sheen diagonal
  cpx(img, 5, 6, 1, 5, GLASS_SHEEN)
  cpx(img, 6, 7, 1, 5, GLASS_SHEEN)
  cpx(img, 4, 7, 1, 5, H.with_alpha(GLASS_SHEEN, 140))
  cpx(img, 7, 8, 1, 5, H.with_alpha(GLASS_SHEEN, 140))

  -- (1,6) brick - reddish rectangle with mortar line
  cshaded(img, 3, 5, 12, 11, 1, 6, BRICK_BASE, BRICK_HI, BRICK_SH)
  coutline(img, 3, 5, 12, 11, 1, 6, OL)
  -- Mortar line across middle
  cline(img, 4, 8, 11, 8, 1, 6, BRICK_MORT)
  -- Vertical mortar
  cpx(img, 7, 6, 1, 6, BRICK_MORT)
  cpx(img, 7, 7, 1, 6, BRICK_MORT)
  cpx(img, 9, 9, 1, 6, BRICK_MORT)
  cpx(img, 9, 10, 1, 6, BRICK_MORT)

  -- (1,7) coke - dark lumpy piece, reddish tint vs coal
  draw_ore_chunk(img, 1, 7, COKE_BASE, COKE_LIGHT, COKE_DARK, COKE_DARK)
  -- Reddish tint pixels
  cpx(img, 6, 6, 1, 7, H.hex("#503030"))
  cpx(img, 8, 9, 1, 7, H.hex("#503030"))
  cpx(img, 10, 7, 1, 7, H.hex("#503030"))


  -- ═════════════════════════════════════════════════════════════════════════
  -- ROW 2: COMPONENTS
  -- ═════════════════════════════════════════════════════════════════════════

  -- (2,0) copper_wire - coiled wire
  -- Draw a coil shape: overlapping arcs
  cpx(img, 7, 3, 2, 0, OL)
  cpx(img, 8, 3, 2, 0, OL)
  cpx(img, 6, 4, 2, 0, OL)
  cpx(img, 9, 4, 2, 0, OL)
  cpx(img, 5, 5, 2, 0, CWIRE_SH)
  cpx(img, 10, 5, 2, 0, CWIRE_SH)
  -- Coil loops
  for i = 0, 3 do
    local cy = 5 + i * 2
    crect(img, 5, cy, 10, cy, 2, 0, CWIRE_BASE)
    cpx(img, 4, cy, 2, 0, CWIRE_SH)
    cpx(img, 11, cy, 2, 0, CWIRE_SH)
    crect(img, 5, cy + 1, 10, cy + 1, 2, 0, CWIRE_HI)
    cpx(img, 4, cy + 1, 2, 0, OL)
    cpx(img, 11, cy + 1, 2, 0, OL)
  end
  cpx(img, 5, 13, 2, 0, OL)
  cpx(img, 10, 13, 2, 0, OL)
  -- End caps
  cpx(img, 7, 13, 2, 0, CWIRE_SH)
  cpx(img, 8, 13, 2, 0, CWIRE_SH)
  -- Highlight on top loops
  cpx(img, 6, 5, 2, 0, CWIRE_HI)
  cpx(img, 7, 5, 2, 0, CWIRE_HI)

  -- (2,1) gold_wire - coiled yellow wire (same shape, different color)
  cpx(img, 7, 3, 2, 1, OL)
  cpx(img, 8, 3, 2, 1, OL)
  cpx(img, 6, 4, 2, 1, OL)
  cpx(img, 9, 4, 2, 1, OL)
  cpx(img, 5, 5, 2, 1, GWIRE_SH)
  cpx(img, 10, 5, 2, 1, GWIRE_SH)
  for i = 0, 3 do
    local cy = 5 + i * 2
    crect(img, 5, cy, 10, cy, 2, 1, GWIRE_BASE)
    cpx(img, 4, cy, 2, 1, GWIRE_SH)
    cpx(img, 11, cy, 2, 1, GWIRE_SH)
    crect(img, 5, cy + 1, 10, cy + 1, 2, 1, GWIRE_HI)
    cpx(img, 4, cy + 1, 2, 1, OL)
    cpx(img, 11, cy + 1, 2, 1, OL)
  end
  cpx(img, 5, 13, 2, 1, OL)
  cpx(img, 10, 13, 2, 1, OL)
  cpx(img, 7, 13, 2, 1, GWIRE_SH)
  cpx(img, 8, 13, 2, 1, GWIRE_SH)
  cpx(img, 6, 5, 2, 1, GWIRE_HI)
  cpx(img, 7, 5, 2, 1, GWIRE_HI)

  -- (2,2) iron_gear - classic gear with teeth
  -- Center hub
  ccircle(img, 7, 7, 3, 2, 2, GEAR_BASE)
  ccircle(img, 7, 7, 1, 2, 2, GEAR_HOLE)
  -- Ring
  ccircle_ol(img, 7, 7, 5, 2, 2, GEAR_BASE)
  ccircle_ol(img, 7, 7, 4, 2, 2, GEAR_HI)
  -- Teeth (8 positions around the gear)
  local teeth = {
    {7,1}, {11,3}, {13,7}, {11,11},
    {7,13}, {3,11}, {1,7}, {3,3}
  }
  for _, t in ipairs(teeth) do
    cpx(img, t[1], t[2], 2, 2, GEAR_BASE)
  end
  -- Outline
  ccircle_ol(img, 7, 7, 6, 2, 2, OL)
  -- Shadow on bottom-right
  cpx(img, 10, 10, 2, 2, GEAR_SH)
  cpx(img, 11, 9, 2, 2, GEAR_SH)
  cpx(img, 9, 11, 2, 2, GEAR_SH)
  -- Highlight on top-left
  cpx(img, 5, 4, 2, 2, GEAR_HI)
  cpx(img, 4, 5, 2, 2, GEAR_HI)

  -- (2,3) iron_tube - hollow cylinder
  cshaded(img, 4, 3, 11, 13, 2, 3, TUBE_BASE, TUBE_HI, TUBE_SH)
  coutline(img, 4, 3, 11, 13, 2, 3, OL)
  -- Hollow center
  crect(img, 6, 4, 9, 12, 2, 3, TUBE_HOLE)
  -- Highlight stripe along left
  cline(img, 5, 4, 5, 12, 2, 3, TUBE_HI)
  -- Rim lines top and bottom
  cline(img, 4, 4, 11, 4, 2, 3, TUBE_HI)
  cline(img, 4, 12, 11, 12, 2, 3, TUBE_SH)

  -- (2,4) tin_can - silver cylinder with rim
  cshaded(img, 4, 3, 11, 13, 2, 4, CAN_BASE, CAN_HI, CAN_SH)
  coutline(img, 4, 3, 11, 13, 2, 4, OL)
  -- Rim at top
  crect(img, 4, 3, 11, 4, 2, 4, CAN_RIM)
  cline(img, 4, 3, 11, 3, 2, 4, OL)
  -- Label area
  crect(img, 5, 6, 10, 10, 2, 4, H.hex("#E8E0D0"))
  coutline(img, 5, 6, 10, 10, 2, 4, CAN_SH)
  -- Highlight
  cpx(img, 5, 4, 2, 4, CAN_HI)
  cpx(img, 5, 5, 2, 4, CAN_HI)

  -- (2,5) steel_beam - I-beam cross section
  -- Top flange
  crect(img, 3, 3, 12, 5, 2, 5, BEAM_BASE)
  -- Bottom flange
  crect(img, 3, 11, 12, 13, 2, 5, BEAM_BASE)
  -- Web (center)
  crect(img, 6, 6, 9, 10, 2, 5, BEAM_BASE)
  -- Highlights
  cline(img, 3, 3, 12, 3, 2, 5, BEAM_HI)
  cline(img, 6, 6, 6, 10, 2, 5, BEAM_HI)
  -- Shadows
  cline(img, 3, 5, 12, 5, 2, 5, BEAM_SH)
  cline(img, 3, 13, 12, 13, 2, 5, BEAM_SH)
  cline(img, 9, 6, 9, 10, 2, 5, BEAM_SH)
  -- Outline
  cline(img, 2, 3, 2, 5, 2, 5, OL)
  cline(img, 13, 3, 13, 5, 2, 5, OL)
  cline(img, 3, 2, 12, 2, 2, 5, OL)
  cline(img, 3, 6, 5, 6, 2, 5, OL)
  cline(img, 10, 6, 12, 6, 2, 5, OL)
  cline(img, 5, 6, 5, 10, 2, 5, OL)
  cline(img, 10, 6, 10, 10, 2, 5, OL)
  cline(img, 3, 10, 5, 10, 2, 5, OL)
  cline(img, 10, 10, 12, 10, 2, 5, OL)
  cline(img, 2, 11, 2, 13, 2, 5, OL)
  cline(img, 13, 11, 13, 13, 2, 5, OL)
  cline(img, 3, 14, 12, 14, 2, 5, OL)
  cline(img, 3, 11, 5, 11, 2, 5, OL)
  cline(img, 10, 11, 12, 11, 2, 5, OL)

  -- (2,6) glass_lens - circular with highlight
  ccircle(img, 7, 8, 5, 2, 6, LENS_BASE)
  ccircle(img, 7, 8, 4, 2, 6, LENS_HI)
  ccircle(img, 7, 8, 2, 2, 6, LENS_BASE)
  ccircle_ol(img, 7, 8, 5, 2, 6, OL)
  ccircle_ol(img, 7, 8, 6, 2, 6, OL)
  -- Gleam
  cpx(img, 5, 6, 2, 6, LENS_GLEAM)
  cpx(img, 6, 5, 2, 6, LENS_GLEAM)
  cpx(img, 6, 6, 2, 6, H.with_alpha(LENS_GLEAM, 180))
  -- Shadow
  cpx(img, 9, 10, 2, 6, LENS_SH)
  cpx(img, 10, 9, 2, 6, LENS_SH)
  cpx(img, 10, 10, 2, 6, LENS_SH)

  -- (2,7) pipe - thick tube with flanges
  -- Main tube body
  cshaded(img, 4, 4, 11, 12, 2, 7, PIPE_BASE, PIPE_HI, PIPE_SH)
  -- Flanges at top and bottom
  crect(img, 3, 3, 12, 4, 2, 7, PIPE_FLANGE)
  crect(img, 3, 12, 12, 13, 2, 7, PIPE_FLANGE)
  -- Flange highlights
  cline(img, 3, 3, 12, 3, 2, 7, PIPE_HI)
  cline(img, 3, 12, 12, 12, 2, 7, PIPE_HI)
  -- Outline
  coutline(img, 3, 3, 12, 13, 2, 7, OL)
  -- Inner highlight stripe
  cline(img, 5, 5, 5, 11, 2, 7, PIPE_HI)
  -- Bolt details on flanges
  cpx(img, 4, 3, 2, 7, OL)
  cpx(img, 11, 3, 2, 7, OL)
  cpx(img, 4, 13, 2, 7, OL)
  cpx(img, 11, 13, 2, 7, OL)


  -- ═════════════════════════════════════════════════════════════════════════
  -- ROW 3: ASSEMBLY / ADVANCED
  -- ═════════════════════════════════════════════════════════════════════════

  -- (3,0) circuit_board - green rectangle with traces
  cshaded(img, 2, 3, 13, 13, 3, 0, PCB_BASE, PCB_LIGHT, PCB_DARK)
  coutline(img, 2, 3, 13, 13, 3, 0, OL)
  -- Traces (horizontal and vertical lines)
  cline(img, 4, 5, 8, 5, 3, 0, PCB_TRACE)
  cline(img, 6, 5, 6, 8, 3, 0, PCB_TRACE)
  cline(img, 6, 8, 11, 8, 3, 0, PCB_TRACE)
  cline(img, 4, 10, 9, 10, 3, 0, PCB_TRACE)
  cline(img, 9, 10, 9, 12, 3, 0, PCB_TRACE)
  cline(img, 11, 6, 11, 11, 3, 0, PCB_TRACE)
  -- Component dots
  cpx(img, 4, 5, 3, 0, H.hex("#FF4040"))
  cpx(img, 11, 8, 3, 0, H.hex("#404040"))
  cpx(img, 4, 10, 3, 0, H.hex("#404040"))
  cpx(img, 9, 12, 3, 0, H.hex("#FF4040"))

  -- (3,1) motor - cylindrical with copper coils
  cshaded(img, 3, 3, 12, 13, 3, 1, MOT_BODY, MOT_HI, MOT_SH)
  coutline(img, 3, 3, 12, 13, 3, 1, OL)
  -- Copper coil wrappings
  cline(img, 4, 5, 11, 5, 3, 1, MOT_COIL)
  cline(img, 4, 7, 11, 7, 3, 1, MOT_COIL)
  cline(img, 4, 9, 11, 9, 3, 1, MOT_COIL)
  cline(img, 4, 11, 11, 11, 3, 1, MOT_COIL)
  -- Coil highlights
  cpx(img, 5, 5, 3, 1, MOT_COIL_HI)
  cpx(img, 5, 7, 3, 1, MOT_COIL_HI)
  cpx(img, 5, 9, 3, 1, MOT_COIL_HI)
  cpx(img, 5, 11, 3, 1, MOT_COIL_HI)
  -- Shaft at top
  crect(img, 7, 1, 8, 3, 3, 1, MOT_HI)
  coutline(img, 7, 1, 8, 3, 3, 1, OL)

  -- (3,2) battery_cell - rectangular with terminals
  cshaded(img, 4, 4, 11, 13, 3, 2, BAT_BASE, BAT_HI, BAT_SH)
  coutline(img, 4, 4, 11, 13, 3, 2, OL)
  -- Top terminal strip
  crect(img, 5, 2, 10, 4, 3, 2, BAT_TOP)
  coutline(img, 5, 2, 10, 4, 3, 2, OL)
  -- Plus terminal
  cpx(img, 6, 2, 3, 2, BAT_PLUS)
  cpx(img, 7, 2, 3, 2, BAT_PLUS)
  cpx(img, 6, 3, 3, 2, BAT_PLUS)
  -- Minus terminal
  cpx(img, 9, 2, 3, 2, BAT_MINUS)
  cpx(img, 10, 2, 3, 2, BAT_MINUS)
  -- Label
  cpx(img, 6, 8, 3, 2, H.hex("#FFFF40"))
  cpx(img, 7, 8, 3, 2, H.hex("#FFFF40"))
  cpx(img, 8, 8, 3, 2, H.hex("#FFFF40"))
  cpx(img, 9, 8, 3, 2, H.hex("#FFFF40"))

  -- (3,3) steel_frame - square frame outline
  -- Outer frame
  coutline(img, 2, 2, 13, 13, 3, 3, FRAME_BASE)
  coutline(img, 3, 3, 12, 12, 3, 3, FRAME_BASE)
  -- Highlight on top-left
  cline(img, 2, 2, 13, 2, 3, 3, FRAME_HI)
  cline(img, 2, 3, 2, 13, 3, 3, FRAME_HI)
  cline(img, 3, 3, 12, 3, 3, 3, FRAME_HI)
  cline(img, 3, 4, 3, 12, 3, 3, FRAME_HI)
  -- Shadow on bottom-right
  cline(img, 2, 13, 13, 13, 3, 3, FRAME_SH)
  cline(img, 13, 2, 13, 13, 3, 3, FRAME_SH)
  cline(img, 3, 12, 12, 12, 3, 3, FRAME_SH)
  cline(img, 12, 3, 12, 12, 3, 3, FRAME_SH)
  -- Outline
  coutline(img, 1, 1, 14, 14, 3, 3, OL)
  coutline(img, 4, 4, 11, 11, 3, 3, OL)
  -- Corner bolts
  cpx(img, 3, 3, 3, 3, OL)
  cpx(img, 12, 3, 3, 3, OL)
  cpx(img, 3, 12, 3, 3, OL)
  cpx(img, 12, 12, 3, 3, OL)

  -- (3,4) concrete - gray block with aggregate specks
  cshaded(img, 3, 4, 12, 12, 3, 4, CONC_BASE, CONC_HI, CONC_SH)
  coutline(img, 3, 4, 12, 12, 3, 4, OL)
  -- Aggregate specks
  cpx(img, 5, 6, 3, 4, CONC_SPECK1)
  cpx(img, 8, 5, 3, 4, CONC_SPECK2)
  cpx(img, 10, 7, 3, 4, CONC_SPECK1)
  cpx(img, 6, 9, 3, 4, CONC_SPECK2)
  cpx(img, 11, 10, 3, 4, CONC_SPECK1)
  cpx(img, 4, 11, 3, 4, CONC_SPECK2)
  cpx(img, 9, 11, 3, 4, CONC_SPECK1)
  cpx(img, 7, 7, 3, 4, CONC_SPECK2)

  -- (3,5) advanced_circuit - blue board with gold traces
  cshaded(img, 2, 3, 13, 13, 3, 5, ADV_BASE, ADV_LIGHT, ADV_DARK)
  coutline(img, 2, 3, 13, 13, 3, 5, OL)
  -- Gold traces
  cline(img, 4, 5, 11, 5, 3, 5, ADV_TRACE)
  cline(img, 5, 5, 5, 9, 3, 5, ADV_TRACE)
  cline(img, 5, 9, 10, 9, 3, 5, ADV_TRACE)
  cline(img, 10, 6, 10, 9, 3, 5, ADV_TRACE)
  cline(img, 7, 7, 7, 11, 3, 5, ADV_TRACE)
  cline(img, 4, 11, 7, 11, 3, 5, ADV_TRACE)
  -- IC chip in center
  crect(img, 6, 7, 9, 9, 3, 5, H.hex("#1A1A20"))
  -- Gold pins on chip
  cpx(img, 6, 6, 3, 5, ADV_TRACE)
  cpx(img, 9, 6, 3, 5, ADV_TRACE)
  cpx(img, 6, 10, 3, 5, ADV_TRACE)
  cpx(img, 9, 10, 3, 5, ADV_TRACE)

  -- (3,6) processor - black chip with gold pins
  crect(img, 4, 4, 11, 12, 3, 6, PROC_BASE)
  crect(img, 5, 5, 10, 11, 3, 6, PROC_TOP)
  -- Die marking
  crect(img, 6, 6, 9, 10, 3, 6, PROC_DIE)
  cpx(img, 7, 7, 3, 6, H.hex("#606068"))
  -- Gold pins along edges
  for i = 0, 3 do
    cpx(img, 5 + i * 2, 3, 3, 6, PROC_PIN)   -- top pins
    cpx(img, 5 + i * 2, 13, 3, 6, PROC_PIN)   -- bottom pins
    cpx(img, 3, 5 + i * 2, 3, 6, PROC_PIN)    -- left pins
    cpx(img, 12, 5 + i * 2, 3, 6, PROC_PIN)   -- right pins
  end
  -- Outline
  coutline(img, 4, 4, 11, 12, 3, 6, OL)
  -- Orientation dot
  cpx(img, 5, 5, 3, 6, H.hex("#808088"))

  -- (3,7) engine - complex mechanical piece
  -- Main block
  cshaded(img, 2, 3, 13, 13, 3, 7, ENG_BODY, ENG_HI, ENG_SH)
  coutline(img, 2, 3, 13, 13, 3, 7, OL)
  -- Cylinder heads on top
  crect(img, 4, 1, 6, 3, 3, 7, ENG_CYL)
  coutline(img, 4, 1, 6, 3, 3, 7, OL)
  crect(img, 9, 1, 11, 3, 3, 7, ENG_CYL)
  coutline(img, 9, 1, 11, 3, 3, 7, OL)
  -- Exhaust manifold detail
  cline(img, 3, 6, 12, 6, 3, 7, ENG_SH)
  cline(img, 3, 10, 12, 10, 3, 7, ENG_SH)
  -- Bolts
  cpx(img, 3, 4, 3, 7, ENG_BOLT)
  cpx(img, 12, 4, 3, 7, ENG_BOLT)
  cpx(img, 3, 12, 3, 7, ENG_BOLT)
  cpx(img, 12, 12, 3, 7, ENG_BOLT)
  cpx(img, 7, 8, 3, 7, ENG_BOLT)
  cpx(img, 8, 8, 3, 7, ENG_BOLT)
  -- Highlight detail
  cpx(img, 5, 2, 3, 7, ENG_HI)
  cpx(img, 10, 2, 3, 7, ENG_HI)


  -- ═════════════════════════════════════════════════════════════════════════
  -- ROW 4: SCIENCE PACKS + SPECIAL
  -- ═════════════════════════════════════════════════════════════════════════

  -- (4,0) science_pack_1 - red flask
  draw_flask(img, 4, 0, SP1_LIQUID, SP1_LIQ_HI, SP1_LIQ_SH, SP1_GLASS, SP1_CORK)

  -- (4,1) science_pack_2 - green flask
  draw_flask(img, 4, 1, SP2_LIQUID, SP2_LIQ_HI, SP2_LIQ_SH, SP1_GLASS, SP1_CORK)

  -- (4,2) science_pack_3 - blue flask
  draw_flask(img, 4, 2, SP3_LIQUID, SP3_LIQ_HI, SP3_LIQ_SH, SP1_GLASS, SP1_CORK)

  -- (4,3) robo_frame - humanoid silhouette
  -- Head
  crect(img, 6, 1, 9, 3, 4, 3, ROBO_BASE)
  cpx(img, 6, 1, 4, 3, ROBO_HI)
  cpx(img, 7, 1, 4, 3, ROBO_HI)
  -- Eyes
  cpx(img, 7, 2, 4, 3, ROBO_EYE)
  cpx(img, 8, 2, 4, 3, ROBO_EYE)
  -- Neck
  cpx(img, 7, 4, 4, 3, ROBO_JOINT)
  cpx(img, 8, 4, 4, 3, ROBO_JOINT)
  -- Torso
  crect(img, 5, 5, 10, 9, 4, 3, ROBO_BASE)
  cpx(img, 5, 5, 4, 3, ROBO_HI)
  cpx(img, 6, 5, 4, 3, ROBO_HI)
  cpx(img, 7, 5, 4, 3, ROBO_HI)
  -- Chest detail
  cpx(img, 7, 6, 4, 3, ROBO_EYE)
  cpx(img, 8, 7, 4, 3, ROBO_JOINT)
  -- Arms
  crect(img, 3, 5, 4, 10, 4, 3, ROBO_SH)
  cpx(img, 3, 5, 4, 3, ROBO_BASE)
  crect(img, 11, 5, 12, 10, 4, 3, ROBO_SH)
  cpx(img, 11, 5, 4, 3, ROBO_BASE)
  -- Hands
  cpx(img, 3, 11, 4, 3, ROBO_JOINT)
  cpx(img, 4, 11, 4, 3, ROBO_JOINT)
  cpx(img, 11, 11, 4, 3, ROBO_JOINT)
  cpx(img, 12, 11, 4, 3, ROBO_JOINT)
  -- Legs
  crect(img, 5, 10, 7, 14, 4, 3, ROBO_SH)
  cpx(img, 5, 10, 4, 3, ROBO_BASE)
  cpx(img, 6, 10, 4, 3, ROBO_BASE)
  crect(img, 8, 10, 10, 14, 4, 3, ROBO_SH)
  cpx(img, 9, 10, 4, 3, ROBO_BASE)
  cpx(img, 10, 10, 4, 3, ROBO_BASE)
  -- Feet
  cpx(img, 4, 14, 4, 3, ROBO_JOINT)
  cpx(img, 5, 14, 4, 3, ROBO_JOINT)
  cpx(img, 10, 14, 4, 3, ROBO_JOINT)
  cpx(img, 11, 14, 4, 3, ROBO_JOINT)
  -- Outline
  -- Head outline
  cpx(img, 5, 1, 4, 3, OL)
  cpx(img, 10, 1, 4, 3, OL)
  cline(img, 6, 0, 9, 0, 4, 3, OL)
  cpx(img, 5, 2, 4, 3, OL)
  cpx(img, 5, 3, 4, 3, OL)
  cpx(img, 10, 2, 4, 3, OL)
  cpx(img, 10, 3, 4, 3, OL)
  cpx(img, 6, 4, 4, 3, OL)
  cpx(img, 9, 4, 4, 3, OL)
  -- Torso/arm outline
  cpx(img, 2, 5, 4, 3, OL)
  cpx(img, 13, 5, 4, 3, OL)
  cline(img, 2, 6, 2, 10, 4, 3, OL)
  cline(img, 13, 6, 13, 10, 4, 3, OL)
  cline(img, 5, 4, 10, 4, 4, 3, OL)
  -- Legs outline
  cpx(img, 4, 10, 4, 3, OL)
  cline(img, 4, 11, 4, 14, 4, 3, OL)
  cline(img, 11, 11, 11, 14, 4, 3, OL)
  cpx(img, 7, 10, 4, 3, OL)
  cpx(img, 8, 10, 4, 3, OL)
  cpx(img, 7, 11, 4, 3, OL)
  cpx(img, 8, 11, 4, 3, OL)
  -- Feet outline
  cline(img, 3, 15, 6, 15, 4, 3, OL)
  cline(img, 9, 15, 12, 15, 4, 3, OL)
  cpx(img, 2, 11, 4, 3, OL)
  cpx(img, 3, 12, 4, 3, OL)
  cpx(img, 3, 13, 4, 3, OL)
  cpx(img, 3, 14, 4, 3, OL)
  cpx(img, 13, 11, 4, 3, OL)
  cpx(img, 12, 12, 4, 3, OL)
  cpx(img, 12, 13, 4, 3, OL)
  cpx(img, 12, 14, 4, 3, OL)

  -- (4,4) energy - lightning bolt
  -- Main bolt shape
  crect(img, 7, 2, 10, 3, 4, 4, NRG_BASE)   -- top
  crect(img, 6, 4, 9, 5, 4, 4, NRG_BASE)
  crect(img, 5, 6, 10, 7, 4, 4, NRG_BASE)   -- wide middle bar
  crect(img, 7, 8, 9, 9, 4, 4, NRG_BASE)
  crect(img, 6, 10, 8, 11, 4, 4, NRG_BASE)
  crect(img, 5, 12, 7, 13, 4, 4, NRG_BASE)  -- bottom
  -- Highlight left/top edge
  cpx(img, 7, 2, 4, 4, NRG_HI)
  cpx(img, 8, 2, 4, 4, NRG_HI)
  cpx(img, 6, 4, 4, 4, NRG_HI)
  cpx(img, 7, 4, 4, 4, NRG_HI)
  cpx(img, 5, 6, 4, 4, NRG_HI)
  cpx(img, 6, 6, 4, 4, NRG_HI)
  -- Shadow right/bottom edge
  cpx(img, 10, 3, 4, 4, NRG_SH)
  cpx(img, 9, 5, 4, 4, NRG_SH)
  cpx(img, 10, 7, 4, 4, NRG_SH)
  cpx(img, 9, 9, 4, 4, NRG_SH)
  cpx(img, 8, 11, 4, 4, NRG_SH)
  cpx(img, 7, 13, 4, 4, NRG_SH)
  -- Dark accent
  cpx(img, 6, 13, 4, 4, NRG_DARK)
  cpx(img, 5, 13, 4, 4, NRG_DARK)
  -- Outline
  cline(img, 7, 1, 10, 1, 4, 4, OL)
  cpx(img, 11, 2, 4, 4, OL)
  cpx(img, 11, 3, 4, 4, OL)
  cpx(img, 6, 2, 4, 4, OL)
  cpx(img, 6, 3, 4, 4, OL)
  cpx(img, 5, 4, 4, 4, OL)
  cpx(img, 5, 5, 4, 4, OL)
  cpx(img, 10, 4, 4, 4, OL)
  cpx(img, 10, 5, 4, 4, OL)
  cpx(img, 4, 6, 4, 4, OL)
  cpx(img, 4, 7, 4, 4, OL)
  cpx(img, 11, 6, 4, 4, OL)
  cpx(img, 11, 7, 4, 4, OL)
  cpx(img, 6, 8, 4, 4, OL)
  cpx(img, 10, 8, 4, 4, OL)
  cpx(img, 10, 9, 4, 4, OL)
  cpx(img, 6, 9, 4, 4, OL)
  cpx(img, 5, 10, 4, 4, OL)
  cpx(img, 9, 10, 4, 4, OL)
  cpx(img, 9, 11, 4, 4, OL)
  cpx(img, 4, 12, 4, 4, OL)
  cpx(img, 4, 13, 4, 4, OL)
  cpx(img, 8, 12, 4, 4, OL)
  cline(img, 5, 14, 7, 14, 4, 4, OL)
  cpx(img, 5, 11, 4, 4, OL)
end


-- ═══════════════════════════════════════════════════════════════════════════
-- CREATE SPRITE AND EXPORT
-- ═══════════════════════════════════════════════════════════════════════════

local DIR = "/Users/gorishniymax/Repos/factor/resources/items/sprites"

local spr = Sprite(W, HT, ColorMode.RGB)
app.activeSprite = spr

local layer = spr.layers[1]
layer.name = "items"

-- Delete the default cel, create a fresh one with a blank image
for _, cel in ipairs(layer.cels) do spr:deleteCel(cel) end
local img = Image(W, HT, ColorMode.RGB)
draw_all(img)
spr:newCel(layer, spr.frames[1], img, Point(0, 0))

-- Save .aseprite
spr:saveAs(DIR .. "/item_atlas.aseprite")

-- Export single-frame PNG (no spritesheet splitting needed)
app.command.ExportSpriteSheet {
  ui = false,
  askOverwrite = false,
  type = SpriteSheetType.ROWS,
  textureFilename = DIR .. "/item_atlas.png",
  splitLayers = false,
  splitTags = false,
  mergeDuplicates = false,
}

spr:close()
print("[item_atlas] Generated 128x80 atlas with 37 items")
print("[item_atlas] done")
