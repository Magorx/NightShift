-- wire_drawer_sprite.lua
-- Top-down wire drawer: spools with drawing dies.
-- 1x2 tiles (32x64 per frame), 2 layers, 10 frames:
-- idle(2) + windup(2) + active(4) + winddown(2).

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, FH = 32, 64
local LAYERS = {"base", "top"}
local TAGS = {
  {name="idle",     from=1, to=2, duration=0.5},
  {name="windup",   from=3, to=4, duration=0.15},
  {name="active",   from=5, to=8, duration=0.15},
  {name="winddown", from=9, to=10, duration=0.15},
}

-- Wire drawer identity: copper-tinted, mechanical
local COPPER    = H.hex("#B87333")
local COPPER_DK = H.hex("#8B5A2B")
local COPPER_LT = H.hex("#D4915A")
local COPPER_RM = H.hex("#A06830")
local WIRE      = H.hex("#C9A84C")
local WIRE_DK   = H.hex("#A08838")
local DIE_METAL = H.hex("#707078")
local DIE_DARK  = H.hex("#505058")
local SPOOL_BG  = H.hex("#3A2A1E")

local function draw_base(img, tag, phase)
  -- overall outline
  H.rect_outline(img, 0, 0, 31, 63, C.outline)
  H.line(img, 0, 31, 31, 31, C.outline)

  -- TOP TILE: input spool (raw material)
  H.rect(img, 1, 1, 30, 30, C.body)
  H.rect(img, 2, 2, 29, 29, C.panel)

  -- Input spool (circular, top-down)
  local sx, sy = 15, 15
  H.circle(img, sx, sy, 12, SPOOL_BG)
  H.circle(img, sx, sy, 11, COPPER_DK)
  -- Wire wound on spool
  H.circle(img, sx, sy, 10, COPPER)
  H.circle(img, sx, sy, 8, COPPER_RM)
  H.circle(img, sx, sy, 5, COPPER_DK)
  -- Spool center hub
  H.circle(img, sx, sy, 3, C.panel_inner)
  H.circle(img, sx, sy, 2, DIE_METAL)
  H.px(img, sx, sy, C.rivet)

  -- Spool rotation animation
  if tag == "active" then
    local angle_offsets = {{3,0},{2,2},{0,3},{-2,2}}
    local o = angle_offsets[(phase % 4) + 1]
    H.px(img, sx + o[1], sy + o[2], COPPER_LT)
    H.px(img, sx - o[1], sy - o[2], COPPER_LT)
    -- Wire being drawn (feeding downward)
    H.line(img, sx, sy + 12, sx, 31, WIRE)
  elseif tag == "windup" then
    if phase == 1 then
      H.line(img, sx, sy + 12, sx, 31, WIRE_DK)
    end
  elseif tag == "winddown" then
    if phase == 0 then
      H.line(img, sx, sy + 12, sx, 31, WIRE_DK)
    end
  end

  -- BOTTOM TILE: drawing die area
  H.rect(img, 1, 32, 30, 62, C.body)
  H.rect(img, 2, 33, 29, 61, C.panel)

  -- Die block (central mechanism)
  H.rect(img, 8, 38, 23, 50, DIE_DARK)
  H.rect(img, 9, 39, 22, 49, DIE_METAL)
  -- Die hole (where wire passes through)
  H.circle(img, 15, 44, 3, C.chamber)
  H.circle(img, 15, 44, 2, C.chamber_deep)
  H.px(img, 15, 44, WIRE)

  -- Output guide channel
  H.rect(img, 14, 50, 16, 62, C.panel_inner)
  -- Wire emerging
  if tag == "active" then
    H.line(img, 15, 44, 15, 62, WIRE)
    -- Drawing sparks
    local sh = {{-1,0},{1,0},{0,-1},{0,1}}
    local s = sh[(phase % 4) + 1]
    H.px(img, 15 + s[1], 44 + s[2], C.fire_inner)
  elseif tag == "winddown" and phase == 0 then
    H.line(img, 15, 44, 15, 62, WIRE_DK)
  end

  -- Corner bolts
  for _, p in ipairs({{3,3},{28,3},{3,28},{28,28},{3,34},{28,34},{3,60},{28,60}}) do
    H.px(img, p[1], p[2], C.rivet)
  end
end

local function draw_top(img, tag, phase)
  -- Spool flanges (raised edges visible from top)
  local sx, sy = 15, 15
  H.circle_outline(img, sx, sy, 12, COPPER_DK)
  H.circle_outline(img, sx, sy, 13, C.outline)

  -- Spool axle cap
  H.circle(img, sx, sy, 2, DIE_METAL)
  H.px(img, sx, sy, COPPER_LT)

  -- Die housing top (structural frame over the die)
  H.rect(img, 6, 36, 25, 52, C.body_light)
  H.rect(img, 7, 37, 24, 51, C.panel)
  H.rect_outline(img, 6, 36, 25, 52, COPPER_DK)

  -- Die opening (clear so base layer die is visible)
  local CLEAR = H.rgba(0, 0, 0, 0)
  H.rect(img, 10, 40, 20, 48, CLEAR)

  -- Tensioner arm
  H.rect(img, 13, 30, 17, 37, C.body)
  H.rect(img, 14, 31, 16, 36, DIE_METAL)
  H.rect_outline(img, 13, 30, 17, 37, C.outline)

  -- Tensioner rollers
  H.circle(img, 15, 31, 1, COPPER)
  H.circle(img, 15, 36, 1, COPPER)

  -- Guide bolts on die housing
  for _, p in ipairs({{8,38},{23,38},{8,50},{23,50}}) do
    H.px(img, p[1], p[2], COPPER)
  end

  -- Active state: vibration/heat on die
  if tag == "active" then
    local sh = {{-1,0},{1,0},{0,-1},{0,1}}
    local s = sh[(phase % 4) + 1]
    H.px(img, 15 + s[1], 44, C.fire_mid)
    -- Die housing glow
    H.px(img, 10, 44, C.pipe_warm)
    H.px(img, 20, 44, C.pipe_warm)
  elseif tag == "windup" and phase == 1 then
    H.px(img, 15, 44, C.ember)
  end
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr,
  "/Users/gorishniymax/Repos/factor/buildings/wire_drawer/sprites", "main")
print("[wire_drawer] done")
