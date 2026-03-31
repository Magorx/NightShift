-- generate_atlas.lua
-- Item atlas: 8 columns x 8 rows = 128x128 pixels, each cell 16x16.
-- Run: aseprite -b --script resources/items/sprites/generate_atlas.lua

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")

local CELL = 16
local COLS, ROWS = 8, 8
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

-- New item colors (table to avoid Lua local variable limit)
local C = {}

-- Oil
C.OIL_BASE     = H.hex("#1A1020")
C.OIL_HI       = H.hex("#3A2848")
C.OIL_SH       = H.hex("#0E0A14")
C.OIL_SHEEN    = H.hex("#6848A0")

-- Crystal
C.CRYS_BASE    = H.hex("#8040C0")
C.CRYS_HI      = H.hex("#B070E8")
C.CRYS_SH      = H.hex("#502888")
C.CRYS_EDGE    = H.hex("#381868")
C.CRYS_GLEAM   = H.hex("#E0C0FF")

-- Uranium Ore
C.UORE_BASE    = H.hex("#506850")
C.UORE_HI      = H.hex("#70A060")
C.UORE_SH      = H.hex("#304830")
C.UORE_GLOW    = H.hex("#80FF60")

-- Biomass
C.BIO_BASE     = H.hex("#408030")
C.BIO_HI       = H.hex("#60A848")
C.BIO_SH       = H.hex("#286020")
C.BIO_LEAF     = H.hex("#50C838")

-- Plastic
C.PLAS_BASE    = H.hex("#E8E0D0")
C.PLAS_HI      = H.hex("#F8F4EC")
C.PLAS_SH      = H.hex("#B8B0A0")

-- Rubber
C.RUB_BASE     = H.hex("#303030")
C.RUB_HI       = H.hex("#484848")
C.RUB_SH       = H.hex("#1A1A1A")

-- Acid
C.ACID_BASE    = H.hex("#40E840")
C.ACID_HI      = H.hex("#70FF70")
C.ACID_SH      = H.hex("#20A820")
C.ACID_VIAL    = H.hex("#C0D8E8")

-- Silicon
C.SILI_BASE    = H.hex("#405060")
C.SILI_HI      = H.hex("#607080")
C.SILI_SH      = H.hex("#283040")
C.SILI_GRID    = H.hex("#506878")

-- Carbon Fiber
C.CFIB_BASE    = H.hex("#282828")
C.CFIB_HI      = H.hex("#404040")
C.CFIB_SH      = H.hex("#141414")
C.CFIB_WEAVE   = H.hex("#383838")

-- Refined Uranium
C.RURA_BASE    = H.hex("#40C830")
C.RURA_HI      = H.hex("#70FF50")
C.RURA_SH      = H.hex("#209018")
C.RURA_GLOW    = H.hex("#A0FF80")

-- Bio Compound
C.BIOC_BASE    = H.hex("#38A030")
C.BIOC_HI      = H.hex("#58C848")
C.BIOC_SH      = H.hex("#207818")
C.BIOC_CAP     = H.hex("#C0C8D0")

-- Ceramic
C.CERA_BASE    = H.hex("#D0C0A0")
C.CERA_HI      = H.hex("#E8D8C0")
C.CERA_SH      = H.hex("#A89878")

-- Alloy Plate
C.ALLOY_BASE   = H.hex("#7080A0")
C.ALLOY_HI     = H.hex("#90A0C0")
C.ALLOY_SH     = H.hex("#506078")

-- Insulated Wire
C.IWIRE_BASE   = H.hex("#D88840")
C.IWIRE_COAT   = H.hex("#303030")
C.IWIRE_COAT_H = H.hex("#484848")

-- Heat Sink
C.HSINK_BASE   = H.hex("#909098")
C.HSINK_HI     = H.hex("#B0B0B8")
C.HSINK_SH     = H.hex("#606068")
C.HSINK_FIN    = H.hex("#A0A0A8")

-- Filter
C.FILT_BASE    = H.hex("#808088")
C.FILT_HI      = H.hex("#A0A0A8")
C.FILT_SH      = H.hex("#585860")
C.FILT_MESH    = H.hex("#C0C0C8")

-- Plastic Casing
C.PCAS_BASE    = H.hex("#E0D8C8")
C.PCAS_HI      = H.hex("#F0EAE0")
C.PCAS_SH      = H.hex("#B0A898")

-- Crystal Oscillator
C.COSC_BASE    = H.hex("#8040C0")
C.COSC_HI      = H.hex("#A060E0")
C.COSC_CASE    = H.hex("#707880")
C.COSC_CASE_H  = H.hex("#9098A0")

-- Quantum Chip
C.QCHP_BASE    = H.hex("#1A1848")
C.QCHP_HI      = H.hex("#2A2868")
C.QCHP_TRACE   = H.hex("#40C0FF")
C.QCHP_GLOW    = H.hex("#80E0FF")

-- Nano Fiber
C.NFIB_BASE    = H.hex("#181820")
C.NFIB_HI      = H.hex("#303040")
C.NFIB_SH      = H.hex("#0C0C10")
C.NFIB_SHIM    = H.hex("#4848A0")

-- Fusion Cell
C.FCEL_BASE    = H.hex("#30B0C0")
C.FCEL_HI      = H.hex("#60E0F0")
C.FCEL_SH      = H.hex("#208090")
C.FCEL_GLOW    = H.hex("#A0FFFF")

-- Robot Arm
C.RARM_BASE    = H.hex("#808890")
C.RARM_HI      = H.hex("#A0A8B0")
C.RARM_SH      = H.hex("#505860")
C.RARM_JOINT   = H.hex("#606870")

-- Science Pack 4 (purple)
C.SP4_LIQUID   = H.hex("#8030D0")
C.SP4_LIQ_HI   = H.hex("#A050F0")
C.SP4_LIQ_SH   = H.hex("#6020A0")

-- Quantum Computer
C.QCOM_BASE    = H.hex("#1A1840")
C.QCOM_HI      = H.hex("#2A2860")
C.QCOM_SH      = H.hex("#0E0C28")
C.QCOM_GLOW    = H.hex("#40C0FF")

-- Power Armor
C.PARM_BASE    = H.hex("#B07030")
C.PARM_HI      = H.hex("#D09048")
C.PARM_SH      = H.hex("#805020")
C.PARM_EDGE    = H.hex("#6A3818")

-- Terraformer
C.TERR_BASE    = H.hex("#508040")
C.TERR_HI      = H.hex("#70A058")
C.TERR_SH      = H.hex("#386028")
C.TERR_PLANT   = H.hex("#40C830")
C.TERR_SOIL    = H.hex("#705030")


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
-- ORE TEMPLATES: each material has a distinct silhouette
-- ═══════════════════════════════════════════════════════════════════════════

--- Iron ore: large angular chunk with jagged edges, fills most of 16x16
local function draw_iron_ore(img, row, col, base, light, dark, crack)
  -- Big angular body
  crect(img, 3, 3, 13, 13, row, col, base)
  crect(img, 2, 4, 14, 12, row, col, base)
  crect(img, 4, 2, 12, 14, row, col, base)
  -- Jagged protrusions
  cpx(img, 1, 5, row, col, base)
  cpx(img, 1, 6, row, col, base)
  cpx(img, 14, 8, row, col, base)
  cpx(img, 5, 1, row, col, base)
  cpx(img, 13, 14, row, col, base)
  -- Highlight: top-left
  crect(img, 3, 3, 8, 5, row, col, light)
  crect(img, 2, 4, 3, 7, row, col, light)
  cpx(img, 4, 2, row, col, light)
  cpx(img, 5, 2, row, col, light)
  cpx(img, 5, 1, row, col, light)
  -- Shadow: bottom-right
  crect(img, 10, 11, 13, 13, row, col, dark)
  crect(img, 12, 9, 14, 12, row, col, dark)
  cpx(img, 11, 14, row, col, dark)
  cpx(img, 12, 14, row, col, dark)
  cpx(img, 13, 14, row, col, dark)
  -- Cracks
  cpx(img, 6, 7, row, col, crack)
  cpx(img, 7, 8, row, col, crack)
  cpx(img, 8, 9, row, col, crack)
  cpx(img, 5, 10, row, col, crack)
  cpx(img, 6, 11, row, col, crack)
  cpx(img, 9, 6, row, col, crack)
  -- Outline
  cline(img, 4, 1, 6, 1, row, col, OL)
  cpx(img, 3, 2, row, col, OL)
  cpx(img, 7, 1, row, col, OL)
  cline(img, 7, 2, 12, 2, row, col, OL)
  cpx(img, 13, 3, row, col, OL)
  cpx(img, 1, 4, row, col, OL)
  cpx(img, 0, 5, row, col, OL)
  cpx(img, 0, 6, row, col, OL)
  cpx(img, 0, 7, row, col, OL)
  cpx(img, 1, 8, row, col, OL)
  cline(img, 1, 9, 1, 12, row, col, OL)
  cpx(img, 2, 13, row, col, OL)
  cline(img, 3, 14, 10, 14, row, col, OL)
  cpx(img, 14, 4, row, col, OL)
  cpx(img, 15, 5, row, col, OL)
  cline(img, 15, 6, 15, 8, row, col, OL)
  cpx(img, 14, 9, row, col, OL)
  cline(img, 14, 10, 14, 13, row, col, OL)
  cpx(img, 11, 15, row, col, OL)
  cpx(img, 12, 15, row, col, OL)
  cpx(img, 13, 15, row, col, OL)
end

--- Copper ore: layered/banded rock with horizontal striations
local function draw_copper_ore(img, row, col)
  -- Rounded body
  crect(img, 3, 2, 12, 13, row, col, CU_BASE)
  crect(img, 2, 4, 13, 11, row, col, CU_BASE)
  crect(img, 4, 1, 11, 14, row, col, CU_BASE)
  cpx(img, 1, 5, row, col, CU_BASE)
  cpx(img, 1, 6, row, col, CU_BASE)
  cpx(img, 14, 8, row, col, CU_BASE)
  cpx(img, 14, 9, row, col, CU_BASE)
  -- Horizontal band striations (signature copper look)
  for _, y in ipairs({3, 6, 9, 12}) do
    cline(img, 3, y, 12, y, row, col, CU_LIGHT)
  end
  for _, y in ipairs({5, 8, 11}) do
    cline(img, 3, y, 12, y, row, col, CU_DARK)
  end
  -- Green patina spots
  cpx(img, 4, 4, row, col, H.hex("#5A9A70"))
  cpx(img, 5, 4, row, col, H.hex("#5A9A70"))
  cpx(img, 10, 7, row, col, H.hex("#5A9A70"))
  cpx(img, 11, 7, row, col, H.hex("#5A9A70"))
  cpx(img, 6, 10, row, col, H.hex("#5A9A70"))
  -- Highlight top-left
  crect(img, 3, 2, 7, 3, row, col, CU_LIGHT)
  cpx(img, 4, 1, row, col, CU_LIGHT)
  cpx(img, 5, 1, row, col, CU_LIGHT)
  -- Shadow bottom-right
  crect(img, 10, 12, 12, 13, row, col, CU_DARK)
  cpx(img, 10, 14, row, col, CU_DARK)
  cpx(img, 11, 14, row, col, CU_DARK)
  -- Outline
  cline(img, 4, 0, 11, 0, row, col, OL)
  cpx(img, 3, 1, row, col, OL)
  cpx(img, 12, 1, row, col, OL)
  cpx(img, 1, 4, row, col, OL)
  cpx(img, 0, 5, row, col, OL)
  cpx(img, 0, 6, row, col, OL)
  cpx(img, 0, 7, row, col, OL)
  cpx(img, 1, 8, row, col, OL)
  cpx(img, 1, 9, row, col, OL)
  cpx(img, 2, 3, row, col, OL)
  cpx(img, 2, 12, row, col, OL)
  cline(img, 3, 14, 4, 14, row, col, OL)
  cline(img, 5, 15, 10, 15, row, col, OL)
  cpx(img, 11, 14, row, col, OL)
  cpx(img, 13, 4, row, col, OL)
  cpx(img, 13, 12, row, col, OL)
  cpx(img, 14, 5, row, col, OL)
  cline(img, 14, 6, 14, 7, row, col, OL)
  cpx(img, 15, 8, row, col, OL)
  cpx(img, 15, 9, row, col, OL)
  cpx(img, 14, 10, row, col, OL)
  cpx(img, 14, 11, row, col, OL)
  cpx(img, 12, 13, row, col, OL)
end

--- Coal: rounded lumpy piece with glossy facets
local function draw_coal_ore(img, row, col)
  -- Round lumpy body
  ccircle(img, 7, 7, 6, row, col, COAL_BASE)
  crect(img, 2, 4, 13, 12, row, col, COAL_BASE)
  crect(img, 4, 2, 11, 13, row, col, COAL_BASE)
  -- Faceted highlight patches (glossy look)
  crect(img, 3, 3, 6, 5, row, col, COAL_LIGHT)
  cpx(img, 4, 2, row, col, COAL_LIGHT)
  crect(img, 8, 6, 10, 8, row, col, COAL_LIGHT)
  -- Glint spots (shiny reflections)
  cpx(img, 4, 3, row, col, COAL_GLINT)
  cpx(img, 5, 4, row, col, COAL_GLINT)
  cpx(img, 9, 7, row, col, COAL_GLINT)
  cpx(img, 7, 10, row, col, COAL_GLINT)
  cpx(img, 3, 8, row, col, COAL_GLINT)
  -- Dark shadow
  crect(img, 9, 10, 12, 12, row, col, COAL_DARK)
  cpx(img, 11, 9, row, col, COAL_DARK)
  cpx(img, 8, 12, row, col, COAL_DARK)
  -- Outline
  cline(img, 4, 1, 11, 1, row, col, OL)
  cpx(img, 3, 2, row, col, OL)
  cpx(img, 12, 2, row, col, OL)
  cpx(img, 2, 3, row, col, OL)
  cpx(img, 13, 3, row, col, OL)
  cline(img, 1, 4, 1, 11, row, col, OL)
  cline(img, 14, 4, 14, 11, row, col, OL)
  cpx(img, 2, 12, row, col, OL)
  cpx(img, 13, 12, row, col, OL)
  cpx(img, 3, 13, row, col, OL)
  cpx(img, 12, 13, row, col, OL)
  cline(img, 4, 14, 11, 14, row, col, OL)
end

--- Stone: smooth rounded cobblestone
local function draw_stone_ore(img, row, col)
  -- Wide oval body
  crect(img, 2, 4, 13, 12, row, col, STONE_BASE)
  crect(img, 4, 2, 11, 13, row, col, STONE_BASE)
  crect(img, 3, 3, 12, 13, row, col, STONE_BASE)
  cpx(img, 1, 6, row, col, STONE_BASE)
  cpx(img, 1, 7, row, col, STONE_BASE)
  cpx(img, 1, 8, row, col, STONE_BASE)
  cpx(img, 1, 9, row, col, STONE_BASE)
  cpx(img, 14, 6, row, col, STONE_BASE)
  cpx(img, 14, 7, row, col, STONE_BASE)
  cpx(img, 14, 8, row, col, STONE_BASE)
  cpx(img, 14, 9, row, col, STONE_BASE)
  -- Highlight
  crect(img, 3, 3, 8, 5, row, col, STONE_LIGHT)
  cpx(img, 4, 2, row, col, STONE_LIGHT)
  cpx(img, 5, 2, row, col, STONE_LIGHT)
  cpx(img, 2, 4, row, col, STONE_LIGHT)
  cpx(img, 2, 5, row, col, STONE_LIGHT)
  -- Shadow
  crect(img, 9, 11, 12, 12, row, col, STONE_DARK)
  cpx(img, 13, 9, row, col, STONE_DARK)
  cpx(img, 13, 10, row, col, STONE_DARK)
  cpx(img, 10, 13, row, col, STONE_DARK)
  cpx(img, 11, 13, row, col, STONE_DARK)
  -- Crack
  cpx(img, 7, 6, row, col, STONE_CRACK)
  cpx(img, 8, 7, row, col, STONE_CRACK)
  cpx(img, 7, 8, row, col, STONE_CRACK)
  cpx(img, 6, 9, row, col, STONE_CRACK)
  -- Outline
  cline(img, 4, 1, 11, 1, row, col, OL)
  cpx(img, 3, 2, row, col, OL)
  cpx(img, 12, 2, row, col, OL)
  cpx(img, 2, 3, row, col, OL)
  cpx(img, 13, 3, row, col, OL)
  cpx(img, 1, 4, row, col, OL)
  cpx(img, 1, 5, row, col, OL)
  cpx(img, 0, 6, row, col, OL)
  cline(img, 0, 7, 0, 8, row, col, OL)
  cpx(img, 0, 9, row, col, OL)
  cpx(img, 1, 10, row, col, OL)
  cpx(img, 1, 11, row, col, OL)
  cpx(img, 2, 12, row, col, OL)
  cpx(img, 3, 13, row, col, OL)
  cpx(img, 14, 4, row, col, OL)
  cpx(img, 14, 5, row, col, OL)
  cpx(img, 15, 6, row, col, OL)
  cline(img, 15, 7, 15, 8, row, col, OL)
  cpx(img, 15, 9, row, col, OL)
  cpx(img, 14, 10, row, col, OL)
  cpx(img, 14, 11, row, col, OL)
  cpx(img, 13, 12, row, col, OL)
  cpx(img, 12, 13, row, col, OL)
  cline(img, 4, 14, 11, 14, row, col, OL)
end

--- Tin ore: cluster of small prisms/crystals
local function draw_tin_ore(img, row, col)
  -- Main crystal (left)
  crect(img, 2, 3, 6, 13, row, col, TIN_BASE)
  cpx(img, 3, 2, row, col, TIN_BASE)
  cpx(img, 4, 2, row, col, TIN_BASE)
  cpx(img, 5, 2, row, col, TIN_BASE)
  crect(img, 2, 3, 4, 5, row, col, TIN_LIGHT)
  cpx(img, 3, 2, row, col, TIN_LIGHT)
  cpx(img, 4, 2, row, col, TIN_LIGHT)
  crect(img, 5, 10, 6, 13, row, col, TIN_DARK)
  -- Second crystal (right, shorter)
  crect(img, 8, 5, 12, 14, row, col, TIN_BASE)
  cpx(img, 9, 4, row, col, TIN_BASE)
  cpx(img, 10, 4, row, col, TIN_BASE)
  cpx(img, 11, 4, row, col, TIN_BASE)
  crect(img, 8, 5, 10, 7, row, col, TIN_LIGHT)
  cpx(img, 9, 4, row, col, TIN_LIGHT)
  cpx(img, 10, 4, row, col, TIN_LIGHT)
  crect(img, 11, 11, 12, 14, row, col, TIN_DARK)
  -- Small crystal (middle)
  crect(img, 5, 7, 8, 13, row, col, TIN_BASE)
  crect(img, 6, 6, 7, 7, row, col, TIN_LIGHT)
  -- Outline left crystal
  cpx(img, 2, 1, row, col, OL)
  cpx(img, 6, 1, row, col, OL)
  cline(img, 3, 1, 5, 1, row, col, OL)
  cline(img, 1, 2, 1, 13, row, col, OL)
  cpx(img, 7, 2, row, col, OL)
  cline(img, 7, 3, 7, 9, row, col, OL)
  cline(img, 2, 14, 6, 14, row, col, OL)
  -- Outline right crystal
  cpx(img, 8, 4, row, col, OL)
  cpx(img, 12, 4, row, col, OL)
  cline(img, 9, 3, 11, 3, row, col, OL)
  cline(img, 13, 5, 13, 14, row, col, OL)
  cline(img, 8, 15, 12, 15, row, col, OL)
  -- Outline middle crystal
  cpx(img, 4, 7, row, col, OL)
  cpx(img, 4, 8, row, col, OL)
  cpx(img, 5, 6, row, col, OL)
  cpx(img, 8, 6, row, col, OL)
  cline(img, 6, 5, 7, 5, row, col, OL)
  cline(img, 7, 10, 7, 13, row, col, OL)
  cline(img, 5, 14, 7, 14, row, col, OL)
end

--- Gold ore: large irregular nugget
local function draw_gold_ore(img, row, col)
  -- Wide lumpy nugget body
  crect(img, 3, 3, 12, 12, row, col, GOLD_BASE)
  crect(img, 2, 4, 13, 11, row, col, GOLD_BASE)
  crect(img, 4, 2, 11, 13, row, col, GOLD_BASE)
  cpx(img, 1, 6, row, col, GOLD_BASE)
  cpx(img, 1, 7, row, col, GOLD_BASE)
  cpx(img, 14, 7, row, col, GOLD_BASE)
  cpx(img, 14, 8, row, col, GOLD_BASE)
  cpx(img, 12, 13, row, col, GOLD_BASE)
  -- Bright highlight
  crect(img, 3, 3, 7, 5, row, col, GOLD_LIGHT)
  cpx(img, 4, 2, row, col, GOLD_LIGHT)
  cpx(img, 5, 2, row, col, GOLD_LIGHT)
  cpx(img, 2, 4, row, col, GOLD_LIGHT)
  cpx(img, 2, 5, row, col, GOLD_LIGHT)
  cpx(img, 5, 6, row, col, GOLD_LIGHT)
  -- Deep shadow
  crect(img, 10, 10, 12, 12, row, col, GOLD_DARK)
  cpx(img, 13, 9, row, col, GOLD_DARK)
  cpx(img, 13, 10, row, col, GOLD_DARK)
  cpx(img, 10, 13, row, col, GOLD_DARK)
  cpx(img, 11, 13, row, col, GOLD_DARK)
  cpx(img, 11, 12, row, col, GOLD_DEEP)
  cpx(img, 12, 12, row, col, GOLD_DEEP)
  cpx(img, 12, 11, row, col, GOLD_DEEP)
  -- Outline
  cline(img, 4, 1, 11, 1, row, col, OL)
  cpx(img, 3, 2, row, col, OL)
  cpx(img, 12, 2, row, col, OL)
  cpx(img, 1, 4, row, col, OL)
  cpx(img, 1, 5, row, col, OL)
  cpx(img, 0, 6, row, col, OL)
  cpx(img, 0, 7, row, col, OL)
  cpx(img, 1, 8, row, col, OL)
  cline(img, 1, 9, 1, 11, row, col, OL)
  cpx(img, 2, 12, row, col, OL)
  cpx(img, 3, 13, row, col, OL)
  cline(img, 4, 14, 9, 14, row, col, OL)
  cpx(img, 2, 3, row, col, OL)
  cpx(img, 13, 3, row, col, OL)
  cpx(img, 14, 4, row, col, OL)
  cline(img, 14, 5, 14, 6, row, col, OL)
  cpx(img, 15, 7, row, col, OL)
  cpx(img, 15, 8, row, col, OL)
  cpx(img, 14, 9, row, col, OL)
  cpx(img, 14, 10, row, col, OL)
  cpx(img, 13, 11, row, col, OL)
  cpx(img, 13, 12, row, col, OL)
  cpx(img, 12, 14, row, col, OL)
  cpx(img, 10, 14, row, col, OL)
  cpx(img, 11, 14, row, col, OL)
end

--- Quartz: tall pointed crystal shard (bigger, fills space)
local function draw_quartz_ore(img, row, col)
  -- Tall hexagonal crystal
  cpx(img, 7, 0, row, col, QRTZ_LIGHT)
  cpx(img, 8, 0, row, col, QRTZ_LIGHT)
  crect(img, 6, 1, 9, 2, row, col, QRTZ_LIGHT)
  crect(img, 5, 3, 10, 5, row, col, QRTZ_LIGHT)
  crect(img, 4, 4, 11, 6, row, col, QRTZ_BASE)
  crect(img, 3, 5, 12, 9, row, col, QRTZ_BASE)
  crect(img, 3, 10, 12, 13, row, col, QRTZ_DARK)
  crect(img, 4, 14, 11, 14, row, col, QRTZ_DARK)
  -- Bright facet on left
  crect(img, 5, 3, 7, 5, row, col, QRTZ_LIGHT)
  cpx(img, 4, 5, row, col, QRTZ_LIGHT)
  cpx(img, 4, 6, row, col, QRTZ_LIGHT)
  cpx(img, 3, 6, row, col, QRTZ_LIGHT)
  cpx(img, 3, 7, row, col, QRTZ_LIGHT)
  -- Bright gleam
  cpx(img, 6, 3, row, col, H.hex("#E8F0FF"))
  cpx(img, 6, 4, row, col, H.hex("#E0EEFF"))
  -- Shadow facet right
  crect(img, 10, 7, 12, 12, row, col, QRTZ_EDGE)
  cpx(img, 11, 14, row, col, QRTZ_EDGE)
  -- Outline
  cpx(img, 6, 0, row, col, OL)
  cpx(img, 9, 0, row, col, OL)
  cpx(img, 5, 1, row, col, OL)
  cpx(img, 10, 1, row, col, OL)
  cpx(img, 4, 2, row, col, OL)
  cpx(img, 11, 2, row, col, OL)
  cpx(img, 3, 3, row, col, OL)
  cpx(img, 12, 3, row, col, OL)
  cpx(img, 2, 4, row, col, OL)
  cpx(img, 13, 4, row, col, OL)
  cline(img, 2, 5, 2, 13, row, col, OL)
  cline(img, 13, 5, 13, 13, row, col, OL)
  cpx(img, 3, 14, row, col, OL)
  cpx(img, 12, 14, row, col, OL)
  cline(img, 4, 15, 11, 15, row, col, OL)
end

--- Sulfur: crusty round/bubbly formation
local function draw_sulfur_ore(img, row, col)
  -- Main round body
  ccircle(img, 7, 8, 6, row, col, SULF_BASE)
  crect(img, 2, 4, 13, 12, row, col, SULF_BASE)
  crect(img, 4, 2, 11, 14, row, col, SULF_BASE)
  -- Bubbly surface bumps (small circles on top)
  ccircle(img, 5, 5, 2, row, col, SULF_LIGHT)
  ccircle(img, 10, 6, 2, row, col, SULF_LIGHT)
  ccircle(img, 7, 10, 2, row, col, SULF_LIGHT)
  -- Crystalline facet highlights
  cpx(img, 4, 4, row, col, H.hex("#F0FF90"))
  cpx(img, 5, 4, row, col, H.hex("#F0FF90"))
  cpx(img, 9, 5, row, col, H.hex("#F0FF90"))
  -- Dark crusty edges
  crect(img, 10, 11, 12, 13, row, col, SULF_DARK)
  cpx(img, 13, 9, row, col, SULF_DARK)
  cpx(img, 13, 10, row, col, SULF_DARK)
  cpx(img, 9, 13, row, col, SULF_DARK)
  cpx(img, 10, 13, row, col, SULF_EDGE)
  cpx(img, 11, 12, row, col, SULF_EDGE)
  -- Outline
  cline(img, 4, 1, 11, 1, row, col, OL)
  cpx(img, 3, 2, row, col, OL)
  cpx(img, 12, 2, row, col, OL)
  cpx(img, 2, 3, row, col, OL)
  cpx(img, 13, 3, row, col, OL)
  cline(img, 1, 4, 1, 12, row, col, OL)
  cline(img, 14, 4, 14, 12, row, col, OL)
  cpx(img, 2, 13, row, col, OL)
  cpx(img, 13, 13, row, col, OL)
  cpx(img, 3, 14, row, col, OL)
  cpx(img, 12, 14, row, col, OL)
  cline(img, 4, 15, 11, 15, row, col, OL)
end


-- ═══════════════════════════════════════════════════════════════════════════
-- PLATE / INTERMEDIATE TEMPLATES
-- ═══════════════════════════════════════════════════════════════════════════

--- Iron plate: flat rectangle with bevel (KEEP ORIGINAL)
local function draw_plate(img, row, col, base, hi, sh)
  cshaded(img, 2, 4, 13, 12, row, col, base, hi, sh)
  coutline(img, 2, 4, 13, 12, row, col, OL)
  cpx(img, 3, 5, row, col, hi)
  cpx(img, 4, 5, row, col, hi)
  cpx(img, 3, 6, row, col, hi)
end

--- Copper ring: washer/ring shape (circle with large hole)
local function draw_copper_ring(img, row, col)
  -- Outer filled circle
  ccircle(img, 7, 7, 6, row, col, CPLATE_BASE)
  -- Inner hole
  ccircle(img, 7, 7, 3, row, col, H.TRANSPARENT)
  -- Highlight on top-left arc
  cpx(img, 4, 3, row, col, CPLATE_HI)
  cpx(img, 5, 2, row, col, CPLATE_HI)
  cpx(img, 6, 2, row, col, CPLATE_HI)
  cpx(img, 7, 1, row, col, CPLATE_HI)
  cpx(img, 8, 1, row, col, CPLATE_HI)
  cpx(img, 3, 4, row, col, CPLATE_HI)
  cpx(img, 2, 5, row, col, CPLATE_HI)
  cpx(img, 2, 6, row, col, CPLATE_HI)
  cpx(img, 1, 7, row, col, CPLATE_HI)
  cpx(img, 3, 5, row, col, CPLATE_HI)
  -- Shadow on bottom-right arc
  cpx(img, 10, 11, row, col, CPLATE_SH)
  cpx(img, 11, 10, row, col, CPLATE_SH)
  cpx(img, 12, 8, row, col, CPLATE_SH)
  cpx(img, 12, 9, row, col, CPLATE_SH)
  cpx(img, 13, 7, row, col, CPLATE_SH)
  cpx(img, 11, 11, row, col, CPLATE_SH)
  cpx(img, 9, 12, row, col, CPLATE_SH)
  cpx(img, 8, 12, row, col, CPLATE_SH)
  -- Outer outline
  ccircle_ol(img, 7, 7, 7, row, col, OL)
  -- Inner outline
  ccircle_ol(img, 7, 7, 2, row, col, OL)
end

--- Tin disc: thin angled coin/disc shape
local function draw_tin_disc(img, row, col)
  -- Elliptical disc seen at slight angle (wider than tall)
  crect(img, 2, 5, 13, 11, row, col, TPLATE_BASE)
  crect(img, 3, 4, 12, 12, row, col, TPLATE_BASE)
  crect(img, 5, 3, 10, 13, row, col, TPLATE_BASE)
  -- Highlight top
  crect(img, 3, 4, 12, 5, row, col, TPLATE_HI)
  crect(img, 5, 3, 10, 4, row, col, TPLATE_HI)
  cpx(img, 2, 5, row, col, TPLATE_HI)
  cpx(img, 2, 6, row, col, TPLATE_HI)
  -- Shadow bottom
  crect(img, 3, 11, 12, 12, row, col, TPLATE_SH)
  crect(img, 5, 13, 10, 13, row, col, TPLATE_SH)
  cpx(img, 13, 10, row, col, TPLATE_SH)
  cpx(img, 13, 11, row, col, TPLATE_SH)
  -- Sheen line across
  cline(img, 4, 7, 11, 7, row, col, TPLATE_HI)
  -- Outline
  cline(img, 5, 2, 10, 2, row, col, OL)
  cpx(img, 3, 3, row, col, OL)
  cpx(img, 4, 3, row, col, OL)
  cpx(img, 11, 3, row, col, OL)
  cpx(img, 12, 3, row, col, OL)
  cpx(img, 1, 5, row, col, OL)
  cpx(img, 2, 4, row, col, OL)
  cpx(img, 13, 4, row, col, OL)
  cpx(img, 14, 5, row, col, OL)
  cline(img, 1, 6, 1, 10, row, col, OL)
  cline(img, 14, 6, 14, 10, row, col, OL)
  cpx(img, 2, 11, row, col, OL)
  cpx(img, 13, 11, row, col, OL)
  cpx(img, 2, 12, row, col, OL)
  cpx(img, 13, 12, row, col, OL)
  cpx(img, 3, 13, row, col, OL)
  cpx(img, 4, 13, row, col, OL)
  cpx(img, 11, 13, row, col, OL)
  cpx(img, 12, 13, row, col, OL)
  cline(img, 5, 14, 10, 14, row, col, OL)
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
-- NEW ITEM DRAW FUNCTIONS (indices 37-62)
-- ═══════════════════════════════════════════════════════════════════════════

--- 37: Oil - dark viscous droplet with iridescent sheen
function C.draw_oil(img, row, col)
  -- Droplet body
  cpx(img, 7, 1, row, col, C.OIL_BASE)
  cpx(img, 8, 1, row, col, C.OIL_BASE)
  crect(img, 6, 2, 9, 3, row, col, C.OIL_BASE)
  crect(img, 5, 4, 10, 5, row, col, C.OIL_BASE)
  crect(img, 4, 6, 11, 8, row, col, C.OIL_BASE)
  crect(img, 3, 7, 12, 11, row, col, C.OIL_BASE)
  crect(img, 4, 12, 11, 13, row, col, C.OIL_BASE)
  crect(img, 5, 14, 10, 14, row, col, C.OIL_BASE)
  -- Iridescent purple sheen
  cpx(img, 6, 4, row, col, C.OIL_SHEEN)
  cpx(img, 7, 5, row, col, C.OIL_SHEEN)
  cpx(img, 5, 7, row, col, C.OIL_SHEEN)
  cpx(img, 6, 8, row, col, C.OIL_SHEEN)
  cpx(img, 5, 9, row, col, H.hex("#5838A0"))
  -- Highlight
  cpx(img, 6, 2, row, col, C.OIL_HI)
  cpx(img, 7, 2, row, col, C.OIL_HI)
  cpx(img, 5, 5, row, col, C.OIL_HI)
  cpx(img, 4, 7, row, col, C.OIL_HI)
  -- Shadow
  crect(img, 9, 11, 11, 12, row, col, C.OIL_SH)
  cpx(img, 10, 13, row, col, C.OIL_SH)
  -- Outline
  cpx(img, 6, 1, row, col, OL)
  cpx(img, 9, 1, row, col, OL)
  cpx(img, 5, 2, row, col, OL)
  cpx(img, 10, 2, row, col, OL)
  cpx(img, 5, 3, row, col, OL)
  cpx(img, 10, 3, row, col, OL)
  cpx(img, 4, 4, row, col, OL)
  cpx(img, 11, 4, row, col, OL)
  cpx(img, 4, 5, row, col, OL)
  cpx(img, 11, 5, row, col, OL)
  cpx(img, 3, 6, row, col, OL)
  cpx(img, 12, 6, row, col, OL)
  cline(img, 2, 7, 2, 11, row, col, OL)
  cline(img, 13, 7, 13, 11, row, col, OL)
  cpx(img, 3, 12, row, col, OL)
  cpx(img, 12, 12, row, col, OL)
  cpx(img, 4, 13, row, col, OL)
  cpx(img, 11, 13, row, col, OL)
  cline(img, 5, 15, 10, 15, row, col, OL)
  cpx(img, 4, 14, row, col, OL)
  cpx(img, 11, 14, row, col, OL)
end

--- 38: Crystal - purple faceted crystal with prismatic highlights
function C.draw_crystal(img, row, col)
  -- Main tall crystal body (hexagonal shape)
  crect(img, 5, 2, 10, 13, row, col, C.CRYS_BASE)
  crect(img, 4, 4, 11, 11, row, col, C.CRYS_BASE)
  cpx(img, 6, 1, row, col, C.CRYS_BASE)
  cpx(img, 7, 1, row, col, C.CRYS_BASE)
  cpx(img, 8, 1, row, col, C.CRYS_BASE)
  cpx(img, 9, 1, row, col, C.CRYS_BASE)
  -- Left facet highlight
  crect(img, 5, 3, 7, 6, row, col, C.CRYS_HI)
  cpx(img, 6, 1, row, col, C.CRYS_HI)
  cpx(img, 7, 1, row, col, C.CRYS_HI)
  cpx(img, 4, 5, row, col, C.CRYS_HI)
  cpx(img, 4, 6, row, col, C.CRYS_HI)
  -- Gleam spot
  cpx(img, 6, 3, row, col, C.CRYS_GLEAM)
  cpx(img, 7, 3, row, col, C.CRYS_GLEAM)
  cpx(img, 6, 4, row, col, H.hex("#D0B0F0"))
  -- Right facet shadow
  crect(img, 9, 8, 11, 12, row, col, C.CRYS_SH)
  cpx(img, 10, 13, row, col, C.CRYS_SH)
  -- Deep edge
  cpx(img, 11, 10, row, col, C.CRYS_EDGE)
  cpx(img, 11, 11, row, col, C.CRYS_EDGE)
  -- Prismatic color accents
  cpx(img, 5, 7, row, col, H.hex("#FF80C0"))
  cpx(img, 8, 5, row, col, H.hex("#80C0FF"))
  cpx(img, 7, 10, row, col, H.hex("#80FFE0"))
  -- Outline
  cpx(img, 5, 1, row, col, OL)
  cpx(img, 10, 1, row, col, OL)
  cline(img, 6, 0, 9, 0, row, col, OL)
  cpx(img, 4, 2, row, col, OL)
  cpx(img, 11, 2, row, col, OL)
  cpx(img, 4, 3, row, col, OL)
  cpx(img, 11, 3, row, col, OL)
  cpx(img, 3, 4, row, col, OL)
  cpx(img, 12, 4, row, col, OL)
  cline(img, 3, 5, 3, 11, row, col, OL)
  cline(img, 12, 5, 12, 11, row, col, OL)
  cpx(img, 4, 12, row, col, OL)
  cpx(img, 11, 12, row, col, OL)
  cpx(img, 4, 13, row, col, OL)
  cpx(img, 11, 13, row, col, OL)
  cline(img, 5, 14, 10, 14, row, col, OL)
end

--- 39: Uranium Ore - green-glowing rocky chunk
function C.draw_uranium_ore(img, row, col)
  -- Rocky body (reuse iron ore shape style)
  crect(img, 3, 3, 12, 13, row, col, C.UORE_BASE)
  crect(img, 2, 5, 13, 11, row, col, C.UORE_BASE)
  crect(img, 4, 2, 11, 14, row, col, C.UORE_BASE)
  -- Highlight
  crect(img, 3, 3, 7, 5, row, col, C.UORE_HI)
  cpx(img, 4, 2, row, col, C.UORE_HI)
  cpx(img, 5, 2, row, col, C.UORE_HI)
  -- Shadow
  crect(img, 10, 11, 12, 13, row, col, C.UORE_SH)
  cpx(img, 11, 14, row, col, C.UORE_SH)
  -- Radioactive glow spots
  cpx(img, 5, 6, row, col, C.UORE_GLOW)
  cpx(img, 6, 7, row, col, C.UORE_GLOW)
  cpx(img, 9, 5, row, col, C.UORE_GLOW)
  cpx(img, 8, 10, row, col, C.UORE_GLOW)
  cpx(img, 10, 8, row, col, C.UORE_GLOW)
  cpx(img, 4, 9, row, col, C.UORE_GLOW)
  cpx(img, 7, 12, row, col, C.UORE_GLOW)
  -- Cracks
  cpx(img, 7, 8, row, col, C.UORE_SH)
  cpx(img, 8, 9, row, col, C.UORE_SH)
  cpx(img, 6, 11, row, col, C.UORE_SH)
  -- Outline
  cline(img, 4, 1, 11, 1, row, col, OL)
  cpx(img, 3, 2, row, col, OL)
  cpx(img, 12, 2, row, col, OL)
  cpx(img, 1, 5, row, col, OL)
  cpx(img, 1, 6, row, col, OL)
  cline(img, 1, 7, 1, 10, row, col, OL)
  cpx(img, 2, 4, row, col, OL)
  cpx(img, 2, 11, row, col, OL)
  cpx(img, 13, 4, row, col, OL)
  cpx(img, 14, 5, row, col, OL)
  cline(img, 14, 6, 14, 10, row, col, OL)
  cpx(img, 13, 11, row, col, OL)
  cpx(img, 3, 14, row, col, OL)
  cpx(img, 12, 14, row, col, OL)
  cline(img, 4, 15, 11, 15, row, col, OL)
end

--- 40: Biomass - organic green mass with leaf motifs
function C.draw_biomass(img, row, col)
  -- Irregular organic blob
  crect(img, 3, 3, 12, 13, row, col, C.BIO_BASE)
  crect(img, 2, 5, 13, 11, row, col, C.BIO_BASE)
  crect(img, 5, 2, 10, 14, row, col, C.BIO_BASE)
  -- Leaf vein patterns
  cline(img, 4, 5, 7, 8, row, col, C.BIO_LEAF)
  cline(img, 7, 8, 11, 6, row, col, C.BIO_LEAF)
  cpx(img, 5, 10, row, col, C.BIO_LEAF)
  cpx(img, 6, 11, row, col, C.BIO_LEAF)
  cpx(img, 9, 10, row, col, C.BIO_LEAF)
  cpx(img, 10, 11, row, col, C.BIO_LEAF)
  -- Highlight
  crect(img, 4, 4, 7, 5, row, col, C.BIO_HI)
  cpx(img, 3, 5, row, col, C.BIO_HI)
  cpx(img, 3, 6, row, col, C.BIO_HI)
  -- Shadow
  crect(img, 10, 11, 12, 12, row, col, C.BIO_SH)
  cpx(img, 11, 13, row, col, C.BIO_SH)
  -- Texture spots
  cpx(img, 8, 4, row, col, H.hex("#306820"))
  cpx(img, 6, 9, row, col, H.hex("#306820"))
  cpx(img, 10, 7, row, col, H.hex("#306820"))
  -- Outline
  cline(img, 5, 1, 10, 1, row, col, OL)
  cpx(img, 4, 2, row, col, OL)
  cpx(img, 11, 2, row, col, OL)
  cpx(img, 2, 4, row, col, OL)
  cpx(img, 13, 4, row, col, OL)
  cline(img, 1, 5, 1, 11, row, col, OL)
  cline(img, 14, 5, 14, 11, row, col, OL)
  cpx(img, 2, 12, row, col, OL)
  cpx(img, 13, 12, row, col, OL)
  cpx(img, 3, 2, row, col, OL)
  cpx(img, 12, 2, row, col, OL)
  cpx(img, 4, 14, row, col, OL)
  cpx(img, 11, 14, row, col, OL)
  cline(img, 5, 15, 10, 15, row, col, OL)
  cpx(img, 3, 13, row, col, OL)
  cpx(img, 12, 13, row, col, OL)
end

--- 41: Plastic - smooth white pellet
function C.draw_plastic(img, row, col)
  -- Smooth rounded rectangle pellet
  crect(img, 3, 4, 12, 12, row, col, C.PLAS_BASE)
  crect(img, 4, 3, 11, 13, row, col, C.PLAS_BASE)
  crect(img, 5, 2, 10, 14, row, col, C.PLAS_BASE)
  -- Highlight (large bright area)
  crect(img, 4, 4, 8, 6, row, col, C.PLAS_HI)
  cpx(img, 5, 3, row, col, C.PLAS_HI)
  cpx(img, 6, 3, row, col, C.PLAS_HI)
  cpx(img, 3, 5, row, col, C.PLAS_HI)
  cpx(img, 3, 6, row, col, C.PLAS_HI)
  -- White gleam
  cpx(img, 5, 4, row, col, H.hex("#FFFFFF"))
  cpx(img, 6, 4, row, col, H.hex("#FFFFFF"))
  -- Shadow
  crect(img, 9, 11, 11, 12, row, col, C.PLAS_SH)
  cpx(img, 12, 9, row, col, C.PLAS_SH)
  cpx(img, 12, 10, row, col, C.PLAS_SH)
  cpx(img, 10, 13, row, col, C.PLAS_SH)
  -- Subtle seam line
  cline(img, 3, 8, 12, 8, row, col, H.hex("#D0C8B8"))
  -- Outline
  cline(img, 5, 1, 10, 1, row, col, OL)
  cpx(img, 4, 2, row, col, OL)
  cpx(img, 11, 2, row, col, OL)
  cpx(img, 3, 3, row, col, OL)
  cpx(img, 12, 3, row, col, OL)
  cpx(img, 2, 4, row, col, OL)
  cpx(img, 13, 4, row, col, OL)
  cline(img, 2, 5, 2, 11, row, col, OL)
  cline(img, 13, 5, 13, 11, row, col, OL)
  cpx(img, 3, 12, row, col, OL)
  cpx(img, 12, 12, row, col, OL)
  cpx(img, 4, 13, row, col, OL)
  cpx(img, 11, 13, row, col, OL)
  cline(img, 5, 15, 10, 15, row, col, OL)
  cpx(img, 4, 14, row, col, OL)
  cpx(img, 11, 14, row, col, OL)
end

--- 42: Rubber - dark elastic block
function C.draw_rubber(img, row, col)
  -- Blocky body with slight rounding
  crect(img, 2, 3, 13, 13, row, col, C.RUB_BASE)
  crect(img, 3, 2, 12, 14, row, col, C.RUB_BASE)
  -- Highlight
  crect(img, 3, 3, 6, 5, row, col, C.RUB_HI)
  cpx(img, 3, 2, row, col, C.RUB_HI)
  cpx(img, 4, 2, row, col, C.RUB_HI)
  cpx(img, 2, 4, row, col, C.RUB_HI)
  -- Shadow
  crect(img, 10, 11, 13, 13, row, col, C.RUB_SH)
  cpx(img, 12, 14, row, col, C.RUB_SH)
  -- Elastic stretch marks (subtle lines)
  cline(img, 4, 7, 11, 7, row, col, H.hex("#3A3A3A"))
  cline(img, 4, 10, 11, 10, row, col, H.hex("#3A3A3A"))
  -- Matte texture dots
  cpx(img, 6, 6, row, col, H.hex("#3C3C3C"))
  cpx(img, 9, 9, row, col, H.hex("#3C3C3C"))
  cpx(img, 5, 12, row, col, H.hex("#3C3C3C"))
  -- Outline
  cline(img, 3, 1, 12, 1, row, col, OL)
  cpx(img, 2, 2, row, col, OL)
  cpx(img, 13, 2, row, col, OL)
  cpx(img, 1, 3, row, col, OL)
  cpx(img, 14, 3, row, col, OL)
  cline(img, 1, 4, 1, 12, row, col, OL)
  cline(img, 14, 4, 14, 12, row, col, OL)
  cpx(img, 2, 13, row, col, OL)
  cpx(img, 13, 13, row, col, OL)
  cpx(img, 2, 14, row, col, OL)
  cpx(img, 13, 14, row, col, OL)
  cline(img, 3, 15, 12, 15, row, col, OL)
end

--- 43: Acid - bright green liquid in a vial
function C.draw_acid(img, row, col)
  -- Vial body (tall thin glass)
  crect(img, 5, 3, 10, 13, row, col, C.ACID_VIAL)
  crect(img, 6, 2, 9, 14, row, col, C.ACID_VIAL)
  -- Neck
  crect(img, 6, 1, 9, 2, row, col, C.ACID_VIAL)
  -- Stopper
  crect(img, 7, 0, 8, 1, row, col, H.hex("#606060"))
  coutline(img, 7, 0, 8, 1, row, col, OL)
  -- Green liquid fill
  crect(img, 5, 7, 10, 13, row, col, C.ACID_BASE)
  crect(img, 6, 6, 9, 14, row, col, C.ACID_BASE)
  -- Liquid highlight
  cpx(img, 6, 7, row, col, C.ACID_HI)
  cpx(img, 7, 7, row, col, C.ACID_HI)
  cpx(img, 6, 8, row, col, C.ACID_HI)
  -- Liquid shadow
  cpx(img, 9, 13, row, col, C.ACID_SH)
  cpx(img, 10, 12, row, col, C.ACID_SH)
  cpx(img, 9, 14, row, col, C.ACID_SH)
  -- Bubbles
  cpx(img, 7, 5, row, col, H.hex("#80FF80"))
  cpx(img, 8, 6, row, col, H.hex("#A0FFA0"))
  -- Glass sheen
  cpx(img, 5, 4, row, col, H.hex("#FFFFFF"))
  cpx(img, 5, 5, row, col, H.hex("#E8F0FF"))
  -- Outline
  cpx(img, 5, 1, row, col, OL)
  cpx(img, 10, 1, row, col, OL)
  cpx(img, 4, 2, row, col, OL)
  cpx(img, 11, 2, row, col, OL)
  cpx(img, 4, 3, row, col, OL)
  cpx(img, 11, 3, row, col, OL)
  cline(img, 4, 4, 4, 12, row, col, OL)
  cline(img, 11, 4, 11, 12, row, col, OL)
  cpx(img, 5, 13, row, col, OL)
  cpx(img, 10, 13, row, col, OL)
  cpx(img, 5, 14, row, col, OL)
  cpx(img, 10, 14, row, col, OL)
  cline(img, 6, 15, 9, 15, row, col, OL)
end

--- 44: Silicon - dark blue-gray wafer with grid pattern
function C.draw_silicon(img, row, col)
  -- Square wafer body
  crect(img, 2, 2, 13, 13, row, col, C.SILI_BASE)
  crect(img, 3, 1, 12, 14, row, col, C.SILI_BASE)
  -- Highlight
  crect(img, 3, 2, 7, 4, row, col, C.SILI_HI)
  cpx(img, 2, 3, row, col, C.SILI_HI)
  cpx(img, 2, 4, row, col, C.SILI_HI)
  -- Shadow
  crect(img, 10, 11, 13, 13, row, col, C.SILI_SH)
  cpx(img, 12, 14, row, col, C.SILI_SH)
  -- Grid pattern (die markings)
  for y = 4, 12, 2 do
    cline(img, 3, y, 12, y, row, col, C.SILI_GRID)
  end
  for x = 4, 12, 2 do
    cline(img, x, 3, x, 13, row, col, C.SILI_GRID)
  end
  -- Orientation notch
  cpx(img, 7, 1, row, col, T)
  cpx(img, 8, 1, row, col, T)
  -- Outline
  cline(img, 3, 0, 6, 0, row, col, OL)
  cline(img, 9, 0, 12, 0, row, col, OL)
  cpx(img, 2, 1, row, col, OL)
  cpx(img, 13, 1, row, col, OL)
  cpx(img, 1, 2, row, col, OL)
  cpx(img, 14, 2, row, col, OL)
  cline(img, 1, 3, 1, 13, row, col, OL)
  cline(img, 14, 3, 14, 13, row, col, OL)
  cpx(img, 2, 14, row, col, OL)
  cpx(img, 13, 14, row, col, OL)
  cline(img, 3, 15, 12, 15, row, col, OL)
end

--- 45: Carbon Fiber - woven dark sheet with crosshatch
function C.draw_carbon_fiber(img, row, col)
  -- Sheet body
  crect(img, 2, 2, 13, 13, row, col, C.CFIB_BASE)
  crect(img, 3, 1, 12, 14, row, col, C.CFIB_BASE)
  -- Crosshatch weave pattern
  for y = 2, 13 do
    for x = 2, 13 do
      if (x + y) % 2 == 0 then
        cpx(img, x, y, row, col, C.CFIB_WEAVE)
      end
    end
  end
  -- Highlight (top-left corner)
  crect(img, 3, 2, 6, 4, row, col, C.CFIB_HI)
  cpx(img, 2, 3, row, col, C.CFIB_HI)
  cpx(img, 2, 4, row, col, C.CFIB_HI)
  -- Shadow
  crect(img, 10, 11, 13, 13, row, col, C.CFIB_SH)
  cpx(img, 11, 14, row, col, C.CFIB_SH)
  -- Subtle fiber shine
  cpx(img, 4, 3, row, col, H.hex("#505050"))
  cpx(img, 6, 5, row, col, H.hex("#505050"))
  cpx(img, 8, 7, row, col, H.hex("#505050"))
  -- Outline
  cline(img, 3, 0, 12, 0, row, col, OL)
  cpx(img, 2, 1, row, col, OL)
  cpx(img, 13, 1, row, col, OL)
  cpx(img, 1, 2, row, col, OL)
  cpx(img, 14, 2, row, col, OL)
  cline(img, 1, 3, 1, 13, row, col, OL)
  cline(img, 14, 3, 14, 13, row, col, OL)
  cpx(img, 2, 14, row, col, OL)
  cpx(img, 13, 14, row, col, OL)
  cline(img, 3, 15, 12, 15, row, col, OL)
end

--- 46: Refined Uranium - bright green glowing rod
function C.draw_refined_uranium(img, row, col)
  -- Cylindrical rod body
  crect(img, 5, 2, 10, 14, row, col, C.RURA_BASE)
  crect(img, 6, 1, 9, 14, row, col, C.RURA_BASE)
  -- Top cap
  crect(img, 5, 1, 10, 2, row, col, H.hex("#808088"))
  coutline(img, 5, 1, 10, 2, row, col, OL)
  -- Bottom cap
  crect(img, 5, 13, 10, 14, row, col, H.hex("#808088"))
  coutline(img, 5, 13, 10, 14, row, col, OL)
  -- Glow highlight
  crect(img, 6, 4, 8, 7, row, col, C.RURA_HI)
  cpx(img, 7, 5, row, col, C.RURA_GLOW)
  cpx(img, 7, 6, row, col, C.RURA_GLOW)
  -- Shadow side
  crect(img, 9, 8, 10, 12, row, col, C.RURA_SH)
  -- Radioactive symbol hint
  cpx(img, 7, 9, row, col, H.hex("#1A1A1E"))
  cpx(img, 8, 10, row, col, H.hex("#1A1A1E"))
  cpx(img, 7, 11, row, col, H.hex("#1A1A1E"))
  -- Glow aura pixels
  cpx(img, 4, 5, row, col, H.hex("#60FF4080"))
  cpx(img, 4, 8, row, col, H.hex("#60FF4080"))
  cpx(img, 11, 6, row, col, H.hex("#60FF4080"))
  cpx(img, 11, 9, row, col, H.hex("#60FF4080"))
  -- Outline
  cpx(img, 4, 2, row, col, OL)
  cpx(img, 11, 2, row, col, OL)
  cline(img, 4, 3, 4, 12, row, col, OL)
  cline(img, 11, 3, 11, 12, row, col, OL)
  cpx(img, 5, 0, row, col, OL)
  cpx(img, 10, 0, row, col, OL)
end

--- 47: Bio Compound - green gel in a capsule
function C.draw_bio_compound(img, row, col)
  -- Capsule body (rounded pill shape)
  crect(img, 4, 3, 11, 13, row, col, C.BIOC_BASE)
  crect(img, 3, 5, 12, 11, row, col, C.BIOC_BASE)
  crect(img, 5, 2, 10, 14, row, col, C.BIOC_BASE)
  -- Capsule top cap (metallic)
  crect(img, 4, 2, 11, 4, row, col, C.BIOC_CAP)
  crect(img, 5, 1, 10, 3, row, col, C.BIOC_CAP)
  coutline(img, 5, 1, 10, 3, row, col, OL)
  cpx(img, 4, 2, row, col, OL)
  cpx(img, 11, 2, row, col, OL)
  cpx(img, 4, 3, row, col, OL)
  cpx(img, 11, 3, row, col, OL)
  -- Gel highlight
  crect(img, 5, 5, 7, 7, row, col, C.BIOC_HI)
  cpx(img, 4, 6, row, col, C.BIOC_HI)
  -- Gel shadow
  crect(img, 9, 11, 11, 12, row, col, C.BIOC_SH)
  cpx(img, 10, 13, row, col, C.BIOC_SH)
  -- Organic swirl marks
  cpx(img, 6, 8, row, col, H.hex("#48B840"))
  cpx(img, 7, 9, row, col, H.hex("#48B840"))
  cpx(img, 8, 8, row, col, H.hex("#48B840"))
  cpx(img, 9, 10, row, col, H.hex("#48B840"))
  -- Outline
  cpx(img, 3, 4, row, col, OL)
  cpx(img, 12, 4, row, col, OL)
  cline(img, 3, 5, 3, 11, row, col, OL)
  cline(img, 12, 5, 12, 11, row, col, OL)
  cpx(img, 4, 12, row, col, OL)
  cpx(img, 11, 12, row, col, OL)
  cpx(img, 4, 13, row, col, OL)
  cpx(img, 11, 13, row, col, OL)
  cline(img, 5, 15, 10, 15, row, col, OL)
  cpx(img, 4, 14, row, col, OL)
  cpx(img, 11, 14, row, col, OL)
end

--- 48: Ceramic - smooth tan disc/tile
function C.draw_ceramic(img, row, col)
  -- Wide disc body
  crect(img, 2, 4, 13, 12, row, col, C.CERA_BASE)
  crect(img, 3, 3, 12, 13, row, col, C.CERA_BASE)
  crect(img, 5, 2, 10, 14, row, col, C.CERA_BASE)
  -- Highlight top
  crect(img, 3, 3, 10, 5, row, col, C.CERA_HI)
  cpx(img, 5, 2, row, col, C.CERA_HI)
  cpx(img, 6, 2, row, col, C.CERA_HI)
  cpx(img, 2, 5, row, col, C.CERA_HI)
  cpx(img, 2, 6, row, col, C.CERA_HI)
  -- Shadow bottom
  crect(img, 9, 11, 12, 12, row, col, C.CERA_SH)
  cpx(img, 10, 13, row, col, C.CERA_SH)
  cpx(img, 13, 9, row, col, C.CERA_SH)
  cpx(img, 13, 10, row, col, C.CERA_SH)
  -- Glaze sheen
  cpx(img, 5, 4, row, col, H.hex("#F0E8D0"))
  cpx(img, 6, 4, row, col, H.hex("#F0E8D0"))
  -- Subtle center design
  ccircle_ol(img, 7, 8, 2, row, col, H.hex("#C0B090"))
  -- Outline
  cline(img, 5, 1, 10, 1, row, col, OL)
  cpx(img, 4, 2, row, col, OL)
  cpx(img, 11, 2, row, col, OL)
  cpx(img, 2, 3, row, col, OL)
  cpx(img, 13, 3, row, col, OL)
  cpx(img, 1, 4, row, col, OL)
  cpx(img, 14, 4, row, col, OL)
  cline(img, 1, 5, 1, 11, row, col, OL)
  cline(img, 14, 5, 14, 11, row, col, OL)
  cpx(img, 2, 12, row, col, OL)
  cpx(img, 13, 12, row, col, OL)
  cpx(img, 3, 13, row, col, OL)
  cpx(img, 12, 13, row, col, OL)
  cpx(img, 4, 14, row, col, OL)
  cpx(img, 11, 14, row, col, OL)
  cline(img, 5, 15, 10, 15, row, col, OL)
end

--- 49: Alloy Plate - blue-gray metallic plate
function C.draw_alloy_plate(img, row, col)
  cshaded(img, 2, 3, 13, 13, row, col, C.ALLOY_BASE, C.ALLOY_HI, C.ALLOY_SH)
  coutline(img, 2, 3, 13, 13, row, col, OL)
  -- Bevel highlight
  cpx(img, 3, 4, row, col, C.ALLOY_HI)
  cpx(img, 4, 4, row, col, C.ALLOY_HI)
  cpx(img, 3, 5, row, col, C.ALLOY_HI)
  -- Alloy speckle pattern
  cpx(img, 6, 6, row, col, H.hex("#8898B0"))
  cpx(img, 9, 7, row, col, H.hex("#8898B0"))
  cpx(img, 5, 9, row, col, H.hex("#8898B0"))
  cpx(img, 10, 10, row, col, H.hex("#8898B0"))
  cpx(img, 7, 11, row, col, H.hex("#8898B0"))
  -- Center sheen line
  cline(img, 3, 8, 12, 8, row, col, C.ALLOY_HI)
end

--- 50: Insulated Wire - copper wire with black rubber coating
function C.draw_insulated_wire(img, row, col)
  -- Coiled wire with insulation showing
  for i = 0, 3 do
    local cy = 4 + i * 3
    -- Black insulation outer
    crect(img, 4, cy, 11, cy + 1, row, col, C.IWIRE_COAT)
    cpx(img, 3, cy, row, col, C.IWIRE_COAT)
    cpx(img, 12, cy, row, col, C.IWIRE_COAT)
    cpx(img, 3, cy + 1, row, col, C.IWIRE_COAT_H)
    cpx(img, 12, cy + 1, row, col, C.IWIRE_COAT_H)
    -- Copper core visible in gaps
    crect(img, 5, cy + 2, 10, cy + 2, row, col, C.IWIRE_BASE)
    cpx(img, 6, cy + 2, row, col, H.hex("#F0A858"))
    cpx(img, 7, cy + 2, row, col, H.hex("#F0A858"))
  end
  -- End caps
  cpx(img, 7, 3, row, col, OL)
  cpx(img, 8, 3, row, col, OL)
  cpx(img, 7, 14, row, col, C.IWIRE_COAT)
  cpx(img, 8, 14, row, col, C.IWIRE_COAT)
  -- Outline on sides
  cline(img, 3, 3, 3, 14, row, col, OL)
  cline(img, 12, 3, 12, 14, row, col, OL)
  cpx(img, 4, 3, row, col, OL)
  cpx(img, 11, 3, row, col, OL)
  cpx(img, 4, 14, row, col, OL)
  cpx(img, 11, 14, row, col, OL)
end

--- 51: Heat Sink - metallic finned radiator
function C.draw_heat_sink(img, row, col)
  -- Base plate
  crect(img, 2, 11, 13, 14, row, col, C.HSINK_BASE)
  cline(img, 2, 11, 13, 11, row, col, C.HSINK_HI)
  -- Fins (vertical)
  for x = 3, 12, 2 do
    crect(img, x, 2, x + 1, 11, row, col, C.HSINK_FIN)
    cpx(img, x, 2, row, col, C.HSINK_HI)
    cpx(img, x, 3, row, col, C.HSINK_HI)
    cpx(img, x + 1, 9, row, col, C.HSINK_SH)
    cpx(img, x + 1, 10, row, col, C.HSINK_SH)
  end
  -- Shadow on base
  crect(img, 10, 12, 13, 13, row, col, C.HSINK_SH)
  -- Outline
  cline(img, 2, 1, 13, 1, row, col, OL)
  cline(img, 2, 12, 2, 14, row, col, OL)
  cline(img, 1, 2, 1, 11, row, col, OL)
  cline(img, 14, 2, 14, 11, row, col, OL)
  cline(img, 1, 12, 1, 14, row, col, OL)
  cline(img, 14, 12, 14, 14, row, col, OL)
  cline(img, 2, 15, 13, 15, row, col, OL)
  -- Gaps between fins
  for x = 4, 12, 2 do
    cline(img, x + 1, 2, x + 1, 10, row, col, OL)
  end
end

--- 52: Filter - gray mesh/screen in frame
function C.draw_filter(img, row, col)
  -- Outer frame
  coutline(img, 2, 2, 13, 13, row, col, C.FILT_BASE)
  coutline(img, 3, 3, 12, 12, row, col, C.FILT_BASE)
  -- Frame highlight
  cline(img, 2, 2, 13, 2, row, col, C.FILT_HI)
  cline(img, 2, 3, 2, 13, row, col, C.FILT_HI)
  -- Frame shadow
  cline(img, 2, 13, 13, 13, row, col, C.FILT_SH)
  cline(img, 13, 2, 13, 13, row, col, C.FILT_SH)
  -- Mesh interior (checkerboard pattern)
  for y = 4, 11 do
    for x = 4, 11 do
      if (x + y) % 2 == 0 then
        cpx(img, x, y, row, col, C.FILT_MESH)
      else
        cpx(img, x, y, row, col, C.FILT_SH)
      end
    end
  end
  -- Outline
  coutline(img, 1, 1, 14, 14, row, col, OL)
  -- Inner outline
  coutline(img, 4, 4, 11, 11, row, col, OL)
  -- Corner rivets
  cpx(img, 3, 3, row, col, OL)
  cpx(img, 12, 3, row, col, OL)
  cpx(img, 3, 12, row, col, OL)
  cpx(img, 12, 12, row, col, OL)
end

--- 53: Plastic Casing - white/cream box or shell
function C.draw_plastic_casing(img, row, col)
  -- Box body
  cshaded(img, 2, 3, 13, 14, row, col, C.PCAS_BASE, C.PCAS_HI, C.PCAS_SH)
  -- Lid/top
  crect(img, 2, 2, 13, 4, row, col, C.PCAS_HI)
  cline(img, 2, 4, 13, 4, row, col, C.PCAS_SH)
  -- Snap detail on lid
  crect(img, 6, 2, 9, 3, row, col, C.PCAS_SH)
  -- Side rib details
  cline(img, 3, 7, 12, 7, row, col, H.hex("#D0C8B8"))
  cline(img, 3, 10, 12, 10, row, col, H.hex("#D0C8B8"))
  -- Rounded corner hint
  cpx(img, 2, 3, row, col, C.PCAS_HI)
  cpx(img, 13, 3, row, col, C.PCAS_SH)
  -- Outline
  cline(img, 2, 1, 13, 1, row, col, OL)
  cpx(img, 1, 2, row, col, OL)
  cpx(img, 14, 2, row, col, OL)
  cline(img, 1, 3, 1, 13, row, col, OL)
  cline(img, 14, 3, 14, 13, row, col, OL)
  cpx(img, 2, 14, row, col, OL)
  cpx(img, 13, 14, row, col, OL)
  cline(img, 2, 15, 13, 15, row, col, OL)
end

--- 54: Crystal Oscillator - purple crystal in metal housing
function C.draw_crystal_oscillator(img, row, col)
  -- Metal housing (rectangular can)
  crect(img, 3, 5, 12, 13, row, col, C.COSC_CASE)
  cline(img, 3, 5, 12, 5, row, col, C.COSC_CASE_H)
  cline(img, 3, 6, 3, 12, row, col, C.COSC_CASE_H)
  -- Purple crystal visible through window
  crect(img, 5, 7, 10, 11, row, col, C.COSC_BASE)
  cpx(img, 6, 7, row, col, C.COSC_HI)
  cpx(img, 7, 7, row, col, C.COSC_HI)
  cpx(img, 6, 8, row, col, C.COSC_HI)
  -- Crystal gleam
  cpx(img, 7, 8, row, col, C.CRYS_GLEAM)
  -- Pins protruding from top
  cpx(img, 5, 2, row, col, H.hex("#E8C840"))
  cpx(img, 5, 3, row, col, H.hex("#E8C840"))
  cpx(img, 5, 4, row, col, H.hex("#E8C840"))
  cpx(img, 10, 2, row, col, H.hex("#E8C840"))
  cpx(img, 10, 3, row, col, H.hex("#E8C840"))
  cpx(img, 10, 4, row, col, H.hex("#E8C840"))
  -- Pin outlines
  cpx(img, 4, 2, row, col, OL)
  cpx(img, 6, 2, row, col, OL)
  cpx(img, 4, 3, row, col, OL)
  cpx(img, 6, 3, row, col, OL)
  cpx(img, 4, 4, row, col, OL)
  cpx(img, 6, 4, row, col, OL)
  cpx(img, 9, 2, row, col, OL)
  cpx(img, 11, 2, row, col, OL)
  cpx(img, 9, 3, row, col, OL)
  cpx(img, 11, 3, row, col, OL)
  cpx(img, 9, 4, row, col, OL)
  cpx(img, 11, 4, row, col, OL)
  -- Housing outline
  coutline(img, 3, 5, 12, 13, row, col, OL)
  -- Window outline
  coutline(img, 5, 7, 10, 11, row, col, H.hex("#505860"))
end

--- 55: Quantum Chip - deep blue/purple chip with glowing traces
function C.draw_quantum_chip(img, row, col)
  -- Chip body
  crect(img, 3, 3, 12, 13, row, col, C.QCHP_BASE)
  crect(img, 4, 2, 11, 14, row, col, C.QCHP_BASE)
  -- Top surface
  crect(img, 4, 3, 11, 12, row, col, C.QCHP_HI)
  -- Glowing traces
  cline(img, 5, 5, 10, 5, row, col, C.QCHP_TRACE)
  cline(img, 7, 5, 7, 10, row, col, C.QCHP_TRACE)
  cline(img, 5, 8, 10, 8, row, col, C.QCHP_TRACE)
  cline(img, 5, 11, 10, 11, row, col, C.QCHP_TRACE)
  -- Glow center
  cpx(img, 7, 7, row, col, C.QCHP_GLOW)
  cpx(img, 8, 7, row, col, C.QCHP_GLOW)
  cpx(img, 7, 8, row, col, C.QCHP_GLOW)
  cpx(img, 8, 8, row, col, C.QCHP_GLOW)
  -- Gold pins
  for i = 0, 3 do
    cpx(img, 4 + i * 2, 1, row, col, H.hex("#E8C840"))
    cpx(img, 4 + i * 2, 14, row, col, H.hex("#E8C840"))
    cpx(img, 2, 4 + i * 2, row, col, H.hex("#E8C840"))
    cpx(img, 13, 4 + i * 2, row, col, H.hex("#E8C840"))
  end
  -- Outline
  cline(img, 3, 2, 12, 2, row, col, OL)
  cline(img, 3, 13, 12, 13, row, col, OL)
  cpx(img, 3, 3, row, col, OL)
  cpx(img, 12, 3, row, col, OL)
  cpx(img, 3, 12, row, col, OL)
  cpx(img, 12, 12, row, col, OL)
  cline(img, 2, 3, 2, 12, row, col, OL)
  cline(img, 13, 3, 13, 12, row, col, OL)
end

--- 56: Nano Fiber - very dark strand bundle with subtle shimmer
function C.draw_nano_fiber(img, row, col)
  -- Bundle of strands (vertical)
  crect(img, 4, 2, 11, 14, row, col, C.NFIB_BASE)
  crect(img, 3, 3, 12, 13, row, col, C.NFIB_BASE)
  -- Individual strand highlights
  for y = 3, 13 do
    cpx(img, 5, y, row, col, C.NFIB_HI)
    cpx(img, 8, y, row, col, C.NFIB_HI)
    cpx(img, 11, y, row, col, C.NFIB_HI)
  end
  -- Shimmer spots
  cpx(img, 5, 4, row, col, C.NFIB_SHIM)
  cpx(img, 8, 6, row, col, C.NFIB_SHIM)
  cpx(img, 11, 5, row, col, C.NFIB_SHIM)
  cpx(img, 5, 9, row, col, C.NFIB_SHIM)
  cpx(img, 8, 11, row, col, C.NFIB_SHIM)
  cpx(img, 11, 10, row, col, C.NFIB_SHIM)
  -- Shadow edges
  crect(img, 10, 12, 12, 13, row, col, C.NFIB_SH)
  -- Binding ties
  cline(img, 4, 4, 11, 4, row, col, H.hex("#404060"))
  cline(img, 4, 12, 11, 12, row, col, H.hex("#404060"))
  -- Outline
  cline(img, 4, 1, 11, 1, row, col, OL)
  cpx(img, 3, 2, row, col, OL)
  cpx(img, 12, 2, row, col, OL)
  cline(img, 2, 3, 2, 13, row, col, OL)
  cline(img, 13, 3, 13, 13, row, col, OL)
  cpx(img, 3, 14, row, col, OL)
  cpx(img, 12, 14, row, col, OL)
  cline(img, 4, 15, 11, 15, row, col, OL)
end

--- 57: Fusion Cell - cyan/teal glowing cylinder
function C.draw_fusion_cell(img, row, col)
  -- Cylindrical body
  crect(img, 4, 3, 11, 13, row, col, C.FCEL_BASE)
  crect(img, 5, 2, 10, 14, row, col, C.FCEL_BASE)
  -- Top cap
  crect(img, 4, 2, 11, 3, row, col, H.hex("#606870"))
  coutline(img, 4, 2, 11, 3, row, col, OL)
  -- Bottom cap
  crect(img, 4, 13, 11, 14, row, col, H.hex("#606870"))
  coutline(img, 4, 13, 11, 14, row, col, OL)
  -- Glow highlight center
  crect(img, 6, 6, 9, 10, row, col, C.FCEL_HI)
  cpx(img, 7, 7, row, col, C.FCEL_GLOW)
  cpx(img, 8, 7, row, col, C.FCEL_GLOW)
  cpx(img, 7, 8, row, col, C.FCEL_GLOW)
  cpx(img, 8, 8, row, col, C.FCEL_GLOW)
  -- Shadow
  crect(img, 10, 9, 11, 12, row, col, C.FCEL_SH)
  -- Energy bands
  cline(img, 5, 5, 10, 5, row, col, C.FCEL_HI)
  cline(img, 5, 11, 10, 11, row, col, C.FCEL_HI)
  -- Outline
  cpx(img, 3, 3, row, col, OL)
  cpx(img, 12, 3, row, col, OL)
  cline(img, 3, 4, 3, 12, row, col, OL)
  cline(img, 12, 4, 12, 12, row, col, OL)
  cpx(img, 4, 1, row, col, OL)
  cpx(img, 11, 1, row, col, OL)
end

--- 58: Robot Arm - metallic articulated arm with joints
function C.draw_robot_arm(img, row, col)
  -- Base mount
  crect(img, 5, 12, 10, 14, row, col, C.RARM_BASE)
  coutline(img, 5, 12, 10, 14, row, col, OL)
  cline(img, 5, 12, 10, 12, row, col, C.RARM_HI)
  -- Lower arm segment
  crect(img, 8, 7, 10, 12, row, col, C.RARM_BASE)
  cline(img, 8, 7, 8, 11, row, col, C.RARM_HI)
  cpx(img, 10, 10, row, col, C.RARM_SH)
  cpx(img, 10, 11, row, col, C.RARM_SH)
  -- Elbow joint
  ccircle(img, 8, 7, 2, row, col, C.RARM_JOINT)
  ccircle_ol(img, 8, 7, 2, row, col, OL)
  cpx(img, 8, 7, row, col, H.hex("#404850"))
  -- Upper arm segment
  crect(img, 5, 3, 8, 7, row, col, C.RARM_BASE)
  cline(img, 5, 3, 5, 6, row, col, C.RARM_HI)
  cpx(img, 8, 5, row, col, C.RARM_SH)
  cpx(img, 8, 6, row, col, C.RARM_SH)
  -- Shoulder joint
  ccircle(img, 5, 3, 2, row, col, C.RARM_JOINT)
  ccircle_ol(img, 5, 3, 2, row, col, OL)
  cpx(img, 5, 3, row, col, H.hex("#404850"))
  -- Gripper/hand
  crect(img, 3, 1, 7, 3, row, col, C.RARM_HI)
  coutline(img, 3, 1, 7, 3, row, col, OL)
  -- Gripper prongs
  cpx(img, 3, 0, row, col, C.RARM_BASE)
  cpx(img, 7, 0, row, col, C.RARM_BASE)
  cpx(img, 2, 0, row, col, OL)
  cpx(img, 8, 0, row, col, OL)
  cpx(img, 2, 1, row, col, OL)
  cpx(img, 8, 1, row, col, OL)
  -- Outline segments
  cpx(img, 7, 7, row, col, OL)
  cpx(img, 11, 7, row, col, OL)
  cline(img, 11, 8, 11, 11, row, col, OL)
  cpx(img, 4, 3, row, col, OL)
  cpx(img, 4, 4, row, col, OL)
  cpx(img, 9, 4, row, col, OL)
  cline(img, 9, 5, 9, 6, row, col, OL)
end

--- 59: Science Pack 4 (Purple) - glass flask with purple liquid
function C.draw_science_pack_4(img, row, col)
  draw_flask(img, row, col, C.SP4_LIQUID, C.SP4_LIQ_HI, C.SP4_LIQ_SH, SP1_GLASS, SP1_CORK)
end

--- 60: Quantum Computer - dark blue/purple box with glowing center
function C.draw_quantum_computer(img, row, col)
  -- Main box body
  cshaded(img, 2, 2, 13, 14, row, col, C.QCOM_BASE, C.QCOM_HI, C.QCOM_SH)
  coutline(img, 2, 2, 13, 14, row, col, OL)
  -- Glowing center orb
  ccircle(img, 7, 8, 3, row, col, C.QCOM_GLOW)
  ccircle(img, 7, 8, 2, row, col, H.hex("#80E0FF"))
  cpx(img, 7, 8, row, col, H.hex("#FFFFFF"))
  ccircle_ol(img, 7, 8, 3, row, col, H.hex("#2050A0"))
  -- Radiating traces from center
  cline(img, 3, 8, 4, 8, row, col, C.QCOM_GLOW)
  cline(img, 11, 8, 12, 8, row, col, C.QCOM_GLOW)
  cline(img, 7, 3, 7, 4, row, col, C.QCOM_GLOW)
  cline(img, 7, 12, 7, 13, row, col, C.QCOM_GLOW)
  -- Corner details
  cpx(img, 3, 3, row, col, H.hex("#303058"))
  cpx(img, 12, 3, row, col, H.hex("#303058"))
  cpx(img, 3, 13, row, col, H.hex("#303058"))
  cpx(img, 12, 13, row, col, H.hex("#303058"))
  -- Status LED
  cpx(img, 12, 4, row, col, H.hex("#40FF40"))
  -- Top panel line
  cline(img, 3, 4, 12, 4, row, col, H.hex("#202048"))
end

--- 61: Power Armor - orange/brown armored chestplate
function C.draw_power_armor(img, row, col)
  -- Chestplate body
  crect(img, 3, 3, 12, 13, row, col, C.PARM_BASE)
  crect(img, 2, 5, 13, 11, row, col, C.PARM_BASE)
  -- Shoulder pads
  crect(img, 1, 3, 4, 6, row, col, C.PARM_BASE)
  crect(img, 11, 3, 14, 6, row, col, C.PARM_BASE)
  cpx(img, 1, 3, row, col, C.PARM_HI)
  cpx(img, 2, 3, row, col, C.PARM_HI)
  cpx(img, 11, 3, row, col, C.PARM_HI)
  cpx(img, 12, 3, row, col, C.PARM_HI)
  -- Neck hole
  crect(img, 5, 2, 10, 3, row, col, C.PARM_EDGE)
  -- Center plate seam
  cline(img, 7, 4, 8, 4, row, col, C.PARM_EDGE)
  cline(img, 7, 5, 8, 5, row, col, C.PARM_EDGE)
  cline(img, 7, 6, 8, 12, row, col, C.PARM_SH)
  -- Highlight left shoulder/chest
  crect(img, 3, 4, 6, 6, row, col, C.PARM_HI)
  cpx(img, 2, 5, row, col, C.PARM_HI)
  cpx(img, 3, 3, row, col, C.PARM_HI)
  -- Shadow right/bottom
  crect(img, 10, 10, 12, 12, row, col, C.PARM_SH)
  cpx(img, 13, 8, row, col, C.PARM_SH)
  cpx(img, 13, 9, row, col, C.PARM_SH)
  -- Power core glow
  cpx(img, 7, 8, row, col, H.hex("#40C0FF"))
  cpx(img, 8, 8, row, col, H.hex("#40C0FF"))
  -- Armor edge rivets
  cpx(img, 4, 7, row, col, C.PARM_EDGE)
  cpx(img, 11, 7, row, col, C.PARM_EDGE)
  cpx(img, 4, 12, row, col, C.PARM_EDGE)
  cpx(img, 11, 12, row, col, C.PARM_EDGE)
  -- Outline
  cline(img, 1, 2, 4, 2, row, col, OL)
  cline(img, 11, 2, 14, 2, row, col, OL)
  cpx(img, 0, 3, row, col, OL)
  cpx(img, 15, 3, row, col, OL)
  cline(img, 0, 4, 0, 6, row, col, OL)
  cline(img, 15, 4, 15, 6, row, col, OL)
  cpx(img, 1, 7, row, col, OL)
  cpx(img, 14, 7, row, col, OL)
  cline(img, 1, 8, 1, 12, row, col, OL)
  cline(img, 14, 8, 14, 12, row, col, OL)
  cpx(img, 2, 13, row, col, OL)
  cpx(img, 13, 13, row, col, OL)
  cline(img, 3, 14, 12, 14, row, col, OL)
  cpx(img, 5, 1, row, col, OL)
  cpx(img, 10, 1, row, col, OL)
end

--- 62: Terraformer - green/brown device with plant motifs
function C.draw_terraformer(img, row, col)
  -- Device body (box with rounded top)
  crect(img, 3, 5, 12, 14, row, col, C.TERR_BASE)
  crect(img, 4, 4, 11, 14, row, col, C.TERR_BASE)
  -- Soil-colored base
  crect(img, 3, 12, 12, 14, row, col, C.TERR_SOIL)
  cline(img, 3, 12, 12, 12, row, col, H.hex("#886840"))
  -- Dome/greenhouse top
  crect(img, 5, 3, 10, 5, row, col, C.TERR_HI)
  crect(img, 6, 2, 9, 4, row, col, C.TERR_HI)
  cpx(img, 7, 1, row, col, C.TERR_HI)
  cpx(img, 8, 1, row, col, C.TERR_HI)
  -- Plant growth on top
  cpx(img, 7, 2, row, col, C.TERR_PLANT)
  cpx(img, 6, 3, row, col, C.TERR_PLANT)
  cpx(img, 8, 3, row, col, C.TERR_PLANT)
  cpx(img, 7, 3, row, col, H.hex("#50D840"))
  cpx(img, 9, 4, row, col, C.TERR_PLANT)
  cpx(img, 5, 4, row, col, C.TERR_PLANT)
  -- Leaf detail
  cpx(img, 5, 2, row, col, C.TERR_PLANT)
  cpx(img, 10, 2, row, col, C.TERR_PLANT)
  -- Highlight on body
  crect(img, 4, 5, 6, 7, row, col, C.TERR_HI)
  cpx(img, 3, 6, row, col, C.TERR_HI)
  -- Shadow
  crect(img, 10, 10, 12, 13, row, col, C.TERR_SH)
  -- Panel details
  cline(img, 4, 8, 11, 8, row, col, H.hex("#406830"))
  cline(img, 4, 10, 11, 10, row, col, H.hex("#406830"))
  -- Status light
  cpx(img, 5, 9, row, col, H.hex("#40FF40"))
  -- Outline
  cpx(img, 6, 1, row, col, OL)
  cpx(img, 9, 1, row, col, OL)
  cpx(img, 5, 2, row, col, OL)
  cpx(img, 10, 2, row, col, OL)
  cpx(img, 4, 3, row, col, OL)
  cpx(img, 11, 3, row, col, OL)
  cpx(img, 3, 4, row, col, OL)
  cpx(img, 12, 4, row, col, OL)
  cpx(img, 2, 5, row, col, OL)
  cpx(img, 13, 5, row, col, OL)
  cline(img, 2, 6, 2, 13, row, col, OL)
  cline(img, 13, 6, 13, 13, row, col, OL)
  cpx(img, 3, 14, row, col, OL)
  cpx(img, 12, 14, row, col, OL)
  cline(img, 3, 15, 12, 15, row, col, OL)
end


-- ═══════════════════════════════════════════════════════════════════════════
-- DRAWING ALL ITEMS
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_all(img)

  -- ═════════════════════════════════════════════════════════════════════════
  -- ROW 0: RAW RESOURCES
  -- ═════════════════════════════════════════════════════════════════════════

  -- (0,0) iron_ore — angular jagged chunk
  draw_iron_ore(img, 0, 0, IRON_BASE, IRON_LIGHT, IRON_DARK, IRON_CRACK)

  -- (0,1) copper_ore — layered banded rock with patina
  draw_copper_ore(img, 0, 1)

  -- (0,2) coal — round lumpy glossy piece
  draw_coal_ore(img, 0, 2)

  -- (0,3) stone — smooth rounded cobblestone
  draw_stone_ore(img, 0, 3)

  -- (0,4) tin_ore — cluster of prismatic crystals
  draw_tin_ore(img, 0, 4)

  -- (0,5) gold_ore — large irregular nugget
  draw_gold_ore(img, 0, 5)

  -- (0,6) quartz — tall pointed crystal shard
  draw_quartz_ore(img, 0, 6)

  -- (0,7) sulfur — crusty bubbly round formation
  draw_sulfur_ore(img, 0, 7)


  -- ═════════════════════════════════════════════════════════════════════════
  -- ROW 1: SMELTED / BASIC MATERIALS
  -- ═════════════════════════════════════════════════════════════════════════

  -- (1,0) iron_plate — flat rectangle with bevel (KEEP AS IS)
  draw_plate(img, 1, 0, IPLATE_BASE, IPLATE_HI, IPLATE_SH)

  -- (1,1) copper_plate — ring/washer shape
  draw_copper_ring(img, 1, 1)

  -- (1,2) tin_plate — wide disc/coin shape
  draw_tin_disc(img, 1, 2)

  -- (1,3) gold_ingot — trapezoidal bar, fills more space
  cshaded(img, 3, 3, 12, 13, 1, 3, GBAR_BASE, GBAR_HI, GBAR_SH)
  coutline(img, 3, 3, 12, 13, 1, 3, OL)
  -- Trapezoidal top bevel
  crect(img, 4, 4, 8, 5, 1, 3, GBAR_HI)
  cpx(img, 4, 6, 1, 3, GBAR_HI)
  -- Stamped mark
  cpx(img, 7, 8, 1, 3, GBAR_SH)
  cpx(img, 8, 8, 1, 3, GBAR_SH)
  cpx(img, 7, 9, 1, 3, GBAR_SH)

  -- (1,4) steel — heavy thick bar, fills space
  cshaded(img, 2, 3, 13, 13, 1, 4, STEEL_BASE, STEEL_HI, STEEL_SH)
  coutline(img, 2, 3, 13, 13, 1, 4, OL)
  -- Subtle center line
  cline(img, 3, 8, 12, 8, 1, 4, STEEL_HI)
  -- Stamped marks
  cpx(img, 5, 6, 1, 4, STEEL_SH)
  cpx(img, 10, 10, 1, 4, STEEL_SH)

  -- (1,5) glass — tall pane with shine
  cshaded(img, 2, 2, 13, 13, 1, 5, GLASS_BASE, GLASS_HI, GLASS_SH)
  coutline(img, 2, 2, 13, 13, 1, 5, OL)
  -- Sheen diagonal
  cpx(img, 4, 4, 1, 5, GLASS_SHEEN)
  cpx(img, 5, 5, 1, 5, GLASS_SHEEN)
  cpx(img, 6, 6, 1, 5, GLASS_SHEEN)
  cpx(img, 3, 5, 1, 5, H.with_alpha(GLASS_SHEEN, 140))
  cpx(img, 4, 6, 1, 5, H.with_alpha(GLASS_SHEEN, 140))
  cpx(img, 7, 7, 1, 5, H.with_alpha(GLASS_SHEEN, 140))

  -- (1,6) brick — reddish rectangle with mortar, bigger
  cshaded(img, 2, 4, 13, 12, 1, 6, BRICK_BASE, BRICK_HI, BRICK_SH)
  coutline(img, 2, 4, 13, 12, 1, 6, OL)
  -- Mortar line across middle
  cline(img, 3, 8, 12, 8, 1, 6, BRICK_MORT)
  -- Vertical mortar
  cpx(img, 7, 5, 1, 6, BRICK_MORT)
  cpx(img, 7, 6, 1, 6, BRICK_MORT)
  cpx(img, 7, 7, 1, 6, BRICK_MORT)
  cpx(img, 10, 9, 1, 6, BRICK_MORT)
  cpx(img, 10, 10, 1, 6, BRICK_MORT)
  cpx(img, 10, 11, 1, 6, BRICK_MORT)

  -- (1,7) coke — porous dark lumpy piece
  -- Round porous body
  ccircle(img, 7, 7, 6, 1, 7, COKE_BASE)
  crect(img, 2, 4, 13, 12, 1, 7, COKE_BASE)
  crect(img, 4, 2, 11, 13, 1, 7, COKE_BASE)
  -- Porous holes
  cpx(img, 5, 5, 1, 7, COKE_DARK)
  cpx(img, 6, 5, 1, 7, COKE_DARK)
  cpx(img, 9, 4, 1, 7, COKE_DARK)
  cpx(img, 4, 8, 1, 7, COKE_DARK)
  cpx(img, 5, 8, 1, 7, COKE_DARK)
  cpx(img, 10, 7, 1, 7, COKE_DARK)
  cpx(img, 7, 10, 1, 7, COKE_DARK)
  cpx(img, 8, 10, 1, 7, COKE_DARK)
  cpx(img, 11, 9, 1, 7, COKE_DARK)
  -- Light facets
  crect(img, 3, 3, 5, 4, 1, 7, COKE_LIGHT)
  cpx(img, 4, 2, 1, 7, COKE_LIGHT)
  -- Reddish tint pixels
  cpx(img, 6, 6, 1, 7, H.hex("#503030"))
  cpx(img, 8, 9, 1, 7, H.hex("#503030"))
  cpx(img, 10, 6, 1, 7, H.hex("#503030"))
  -- Shadow
  crect(img, 9, 10, 12, 12, 1, 7, COKE_DARK)
  cpx(img, 11, 9, 1, 7, COKE_DARK)
  -- Outline
  cline(img, 4, 1, 11, 1, 1, 7, OL)
  cpx(img, 3, 2, 1, 7, OL)
  cpx(img, 12, 2, 1, 7, OL)
  cpx(img, 2, 3, 1, 7, OL)
  cpx(img, 13, 3, 1, 7, OL)
  cline(img, 1, 4, 1, 11, 1, 7, OL)
  cline(img, 14, 4, 14, 11, 1, 7, OL)
  cpx(img, 2, 12, 1, 7, OL)
  cpx(img, 13, 12, 1, 7, OL)
  cpx(img, 3, 13, 1, 7, OL)
  cpx(img, 12, 13, 1, 7, OL)
  cline(img, 4, 14, 11, 14, 1, 7, OL)


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

  -- (2,2) gear — pointy gear with sharp triangular teeth, fills space
  -- Outer ring body
  ccircle(img, 7, 7, 5, 2, 2, GEAR_BASE)
  -- Center hole
  ccircle(img, 7, 7, 1, 2, 2, GEAR_HOLE)
  -- Inner ring highlight
  ccircle_ol(img, 7, 7, 3, 2, 2, GEAR_HI)
  -- 8 sharp pointy teeth (triangular, protruding 2-3px)
  -- Top tooth
  cpx(img, 7, 0, 2, 2, GEAR_BASE)
  cpx(img, 6, 1, 2, 2, GEAR_BASE)
  cpx(img, 7, 1, 2, 2, GEAR_HI)
  cpx(img, 8, 1, 2, 2, GEAR_BASE)
  -- Top-right tooth
  cpx(img, 12, 2, 2, 2, GEAR_BASE)
  cpx(img, 11, 2, 2, 2, GEAR_BASE)
  cpx(img, 11, 3, 2, 2, GEAR_HI)
  cpx(img, 12, 3, 2, 2, GEAR_BASE)
  -- Right tooth
  cpx(img, 14, 7, 2, 2, GEAR_BASE)
  cpx(img, 13, 6, 2, 2, GEAR_BASE)
  cpx(img, 13, 7, 2, 2, GEAR_BASE)
  cpx(img, 13, 8, 2, 2, GEAR_BASE)
  -- Bottom-right tooth
  cpx(img, 12, 12, 2, 2, GEAR_SH)
  cpx(img, 11, 11, 2, 2, GEAR_SH)
  cpx(img, 12, 11, 2, 2, GEAR_SH)
  cpx(img, 11, 12, 2, 2, GEAR_SH)
  -- Bottom tooth
  cpx(img, 7, 14, 2, 2, GEAR_SH)
  cpx(img, 6, 13, 2, 2, GEAR_SH)
  cpx(img, 7, 13, 2, 2, GEAR_SH)
  cpx(img, 8, 13, 2, 2, GEAR_SH)
  -- Bottom-left tooth
  cpx(img, 2, 12, 2, 2, GEAR_SH)
  cpx(img, 3, 11, 2, 2, GEAR_SH)
  cpx(img, 2, 11, 2, 2, GEAR_SH)
  cpx(img, 3, 12, 2, 2, GEAR_SH)
  -- Left tooth
  cpx(img, 0, 7, 2, 2, GEAR_BASE)
  cpx(img, 1, 6, 2, 2, GEAR_HI)
  cpx(img, 1, 7, 2, 2, GEAR_BASE)
  cpx(img, 1, 8, 2, 2, GEAR_BASE)
  -- Top-left tooth
  cpx(img, 2, 2, 2, 2, GEAR_HI)
  cpx(img, 3, 2, 2, 2, GEAR_HI)
  cpx(img, 2, 3, 2, 2, GEAR_HI)
  cpx(img, 3, 3, 2, 2, GEAR_HI)
  -- Highlight top-left body
  cpx(img, 5, 4, 2, 2, GEAR_HI)
  cpx(img, 4, 5, 2, 2, GEAR_HI)
  cpx(img, 5, 5, 2, 2, GEAR_HI)
  -- Shadow bottom-right body
  cpx(img, 9, 10, 2, 2, GEAR_SH)
  cpx(img, 10, 9, 2, 2, GEAR_SH)
  cpx(img, 10, 10, 2, 2, GEAR_SH)
  -- Outline (tooth tips)
  cpx(img, 7, -1, 2, 2, OL)  -- won't draw (clipped), but tooth outline below:
  -- Outline around the full shape
  cpx(img, 5, 0, 2, 2, OL)
  cpx(img, 9, 0, 2, 2, OL)
  cpx(img, 6, 0, 2, 2, OL)
  cpx(img, 8, 0, 2, 2, OL)
  cpx(img, 10, 1, 2, 2, OL)
  cpx(img, 13, 2, 2, 2, OL)
  cpx(img, 13, 4, 2, 2, OL)
  cpx(img, 4, 1, 2, 2, OL)
  cpx(img, 1, 2, 2, 2, OL)
  cpx(img, 1, 4, 2, 2, OL)
  cpx(img, 15, 7, 2, 2, OL)
  cpx(img, 14, 5, 2, 2, OL)
  cpx(img, 14, 9, 2, 2, OL)
  cpx(img, -1, 7, 2, 2, OL)
  cpx(img, 0, 5, 2, 2, OL)
  cpx(img, 0, 9, 2, 2, OL)
  cpx(img, 13, 10, 2, 2, OL)
  cpx(img, 13, 13, 2, 2, OL)
  cpx(img, 10, 13, 2, 2, OL)
  cpx(img, 1, 10, 2, 2, OL)
  cpx(img, 1, 13, 2, 2, OL)
  cpx(img, 4, 13, 2, 2, OL)
  cpx(img, 6, 15, 2, 2, OL)
  cpx(img, 8, 15, 2, 2, OL)
  cpx(img, 5, 14, 2, 2, OL)
  cpx(img, 9, 14, 2, 2, OL)

  -- (2,3) tube — vertical cylinder with hollow opening, straight walls
  -- Main body (straight sides, no rounding)
  crect(img, 3, 3, 12, 13, 2, 3, TUBE_BASE)
  -- Highlight on left wall
  cline(img, 4, 4, 4, 12, 2, 3, TUBE_HI)
  cpx(img, 5, 4, 2, 3, TUBE_HI)
  cpx(img, 5, 5, 2, 3, TUBE_HI)
  -- Shadow on right wall
  cline(img, 11, 4, 11, 12, 2, 3, TUBE_SH)
  cpx(img, 10, 12, 2, 3, TUBE_SH)
  -- Top opening: elliptical rim showing hollow inside
  crect(img, 4, 2, 11, 4, 2, 3, TUBE_HI)  -- bright rim
  crect(img, 5, 3, 10, 4, 2, 3, TUBE_HOLE)  -- dark hole
  -- Rim outline
  cline(img, 4, 1, 11, 1, 2, 3, OL)
  cpx(img, 3, 2, 2, 3, OL)
  cpx(img, 12, 2, 2, 3, OL)
  -- Bottom rim
  cline(img, 3, 13, 12, 13, 2, 3, TUBE_SH)
  -- Outline (straight sides)
  cline(img, 2, 3, 2, 13, 2, 3, OL)
  cline(img, 13, 3, 13, 13, 2, 3, OL)
  cpx(img, 3, 3, 2, 3, OL)
  cpx(img, 12, 3, 2, 3, OL)
  cline(img, 3, 14, 12, 14, 2, 3, OL)

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

  -- (3,1) motor — cylindrical body with visible copper coils and shaft, bigger
  -- Main cylindrical body (rounded rect)
  crect(img, 2, 4, 13, 14, 3, 1, MOT_BODY)
  crect(img, 3, 3, 12, 14, 3, 1, MOT_BODY)
  -- Highlight on left wall
  cline(img, 3, 4, 3, 13, 3, 1, MOT_HI)
  cpx(img, 2, 5, 3, 1, MOT_HI)
  cpx(img, 2, 6, 3, 1, MOT_HI)
  -- Shadow on right wall
  cline(img, 12, 4, 12, 13, 3, 1, MOT_SH)
  cpx(img, 13, 8, 3, 1, MOT_SH)
  cpx(img, 13, 9, 3, 1, MOT_SH)
  -- Copper coil wrappings (wide, with highlights)
  for _, cy in ipairs({5, 7, 9, 11, 13}) do
    cline(img, 3, cy, 12, cy, 3, 1, MOT_COIL)
    cpx(img, 4, cy, 3, 1, MOT_COIL_HI)
    cpx(img, 5, cy, 3, 1, MOT_COIL_HI)
  end
  -- Shaft protruding from top
  crect(img, 6, 0, 9, 3, 3, 1, MOT_HI)
  cline(img, 7, 0, 8, 0, 3, 1, H.hex("#9098A8"))
  coutline(img, 6, 0, 9, 3, 3, 1, OL)
  -- End cap (bottom)
  cline(img, 3, 14, 12, 14, 3, 1, MOT_SH)
  -- Outline
  cline(img, 3, 2, 12, 2, 3, 1, OL)
  cpx(img, 1, 5, 3, 1, OL)
  cpx(img, 1, 6, 3, 1, OL)
  cpx(img, 2, 4, 3, 1, OL)
  cpx(img, 2, 3, 3, 1, OL)
  cline(img, 1, 7, 1, 12, 3, 1, OL)
  cpx(img, 2, 13, 3, 1, OL)
  cpx(img, 14, 5, 3, 1, OL)
  cpx(img, 14, 6, 3, 1, OL)
  cpx(img, 13, 4, 3, 1, OL)
  cpx(img, 13, 3, 3, 1, OL)
  cline(img, 14, 7, 14, 12, 3, 1, OL)
  cpx(img, 13, 13, 3, 1, OL)
  cline(img, 3, 15, 12, 15, 3, 1, OL)
  cpx(img, 2, 14, 3, 1, OL)
  cpx(img, 13, 14, 3, 1, OL)

  -- (3,2) battery_cell — tall cylinder with + terminal on top, colored bands
  -- Main body
  crect(img, 3, 3, 12, 14, 3, 2, BAT_BASE)
  crect(img, 4, 2, 11, 14, 3, 2, BAT_BASE)
  -- Highlight left
  cline(img, 4, 3, 4, 13, 3, 2, BAT_HI)
  cpx(img, 3, 4, 3, 2, BAT_HI)
  cpx(img, 3, 5, 3, 2, BAT_HI)
  -- Shadow right
  cline(img, 11, 3, 11, 13, 3, 2, BAT_SH)
  cpx(img, 12, 8, 3, 2, BAT_SH)
  cpx(img, 12, 9, 3, 2, BAT_SH)
  -- Top terminal (positive nub)
  crect(img, 6, 0, 9, 2, 3, 2, BAT_TOP)
  cpx(img, 7, 0, 3, 2, BAT_PLUS)
  cpx(img, 8, 0, 3, 2, BAT_PLUS)
  coutline(img, 6, 0, 9, 2, 3, 2, OL)
  -- Plus symbol on body
  cline(img, 7, 5, 8, 5, 3, 2, BAT_PLUS)
  cpx(img, 7, 4, 3, 2, BAT_PLUS)
  cpx(img, 8, 6, 3, 2, BAT_PLUS)
  -- Minus stripe near bottom
  cline(img, 5, 11, 10, 11, 3, 2, BAT_MINUS)
  cline(img, 5, 12, 10, 12, 3, 2, BAT_MINUS)
  -- Yellow energy label band
  cline(img, 5, 8, 10, 8, 3, 2, H.hex("#FFFF40"))
  cline(img, 5, 9, 10, 9, 3, 2, H.hex("#E8D830"))
  -- Outline
  cline(img, 4, 1, 11, 1, 3, 2, OL)
  cpx(img, 3, 2, 3, 2, OL)
  cpx(img, 12, 2, 3, 2, OL)
  cline(img, 2, 3, 2, 13, 3, 2, OL)
  cline(img, 13, 3, 13, 13, 3, 2, OL)
  cpx(img, 3, 14, 3, 2, OL)
  cpx(img, 12, 14, 3, 2, OL)
  cline(img, 4, 15, 11, 15, 3, 2, OL)

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

  -- (3,5) advanced_circuit — blue board with prominent gold IC chip and traces
  -- Board body (fills space)
  cshaded(img, 1, 2, 14, 14, 3, 5, ADV_BASE, ADV_LIGHT, ADV_DARK)
  coutline(img, 1, 2, 14, 14, 3, 5, OL)
  -- Central IC chip (bigger, more visible)
  crect(img, 5, 6, 10, 10, 3, 5, H.hex("#1A1A20"))
  coutline(img, 5, 6, 10, 10, 3, 5, H.hex("#303040"))
  -- Gold pins radiating from chip (top, bottom, left, right)
  for i = 0, 2 do
    cpx(img, 6 + i * 2, 5, 3, 5, ADV_TRACE)  -- top pins
    cpx(img, 6 + i * 2, 11, 3, 5, ADV_TRACE)  -- bottom pins
    cpx(img, 4, 7 + i, 3, 5, ADV_TRACE)      -- left pins
    cpx(img, 11, 7 + i, 3, 5, ADV_TRACE)     -- right pins
  end
  -- Gold traces from pins to board edges
  cline(img, 3, 4, 6, 4, 3, 5, ADV_TRACE)
  cline(img, 3, 4, 3, 7, 3, 5, ADV_TRACE)
  cline(img, 10, 4, 12, 4, 3, 5, ADV_TRACE)
  cline(img, 12, 4, 12, 7, 3, 5, ADV_TRACE)
  cline(img, 3, 12, 6, 12, 3, 5, ADV_TRACE)
  cline(img, 3, 10, 3, 12, 3, 5, ADV_TRACE)
  cline(img, 10, 12, 12, 12, 3, 5, ADV_TRACE)
  cline(img, 12, 10, 12, 12, 3, 5, ADV_TRACE)
  -- Chip die marking
  cpx(img, 7, 7, 3, 5, H.hex("#404050"))
  cpx(img, 8, 8, 3, 5, H.hex("#404050"))
  cpx(img, 7, 9, 3, 5, H.hex("#404050"))
  -- Orientation dot
  cpx(img, 6, 7, 3, 5, ADV_TRACE)

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


  -- ═════════════════════════════════════════════════════════════════════════
  -- ROW 4 (cont) + ROW 5-7: NEW ITEMS (indices 37-62)
  -- ═════════════════════════════════════════════════════════════════════════

  -- (4,5) index 37: oil
  C.draw_oil(img, 4, 5)

  -- (4,6) index 38: crystal
  C.draw_crystal(img, 4, 6)

  -- (4,7) index 39: uranium_ore
  C.draw_uranium_ore(img, 4, 7)

  -- (5,0) index 40: biomass
  C.draw_biomass(img, 5, 0)

  -- (5,1) index 41: plastic
  C.draw_plastic(img, 5, 1)

  -- (5,2) index 42: rubber
  C.draw_rubber(img, 5, 2)

  -- (5,3) index 43: acid
  C.draw_acid(img, 5, 3)

  -- (5,4) index 44: silicon
  C.draw_silicon(img, 5, 4)

  -- (5,5) index 45: carbon_fiber
  C.draw_carbon_fiber(img, 5, 5)

  -- (5,6) index 46: refined_uranium
  C.draw_refined_uranium(img, 5, 6)

  -- (5,7) index 47: bio_compound
  C.draw_bio_compound(img, 5, 7)

  -- (6,0) index 48: ceramic
  C.draw_ceramic(img, 6, 0)

  -- (6,1) index 49: alloy_plate
  C.draw_alloy_plate(img, 6, 1)

  -- (6,2) index 50: insulated_wire
  C.draw_insulated_wire(img, 6, 2)

  -- (6,3) index 51: heat_sink
  C.draw_heat_sink(img, 6, 3)

  -- (6,4) index 52: filter
  C.draw_filter(img, 6, 4)

  -- (6,5) index 53: plastic_casing
  C.draw_plastic_casing(img, 6, 5)

  -- (6,6) index 54: crystal_oscillator
  C.draw_crystal_oscillator(img, 6, 6)

  -- (6,7) index 55: quantum_chip
  C.draw_quantum_chip(img, 6, 7)

  -- (7,0) index 56: nano_fiber
  C.draw_nano_fiber(img, 7, 0)

  -- (7,1) index 57: fusion_cell
  C.draw_fusion_cell(img, 7, 1)

  -- (7,2) index 58: robot_arm
  C.draw_robot_arm(img, 7, 2)

  -- (7,3) index 59: science_pack_4
  C.draw_science_pack_4(img, 7, 3)

  -- (7,4) index 60: quantum_computer
  C.draw_quantum_computer(img, 7, 4)

  -- (7,5) index 61: power_armor
  C.draw_power_armor(img, 7, 5)

  -- (7,6) index 62: terraformer
  C.draw_terraformer(img, 7, 6)

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
print("[item_atlas] Generated 128x128 atlas with 63 items (indices 0-62)")
print("[item_atlas] done")
