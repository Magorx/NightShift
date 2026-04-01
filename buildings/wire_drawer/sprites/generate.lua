-- wire_drawer_sprite.lua
-- Top-down wire drawer: spools with drawing dies.
-- 1x2 tiles (32x64 per frame), 2 layers, 10 frames:
-- idle(2) + windup(2) + active(4) + winddown(2).
--
-- Base layer (z=0): spool interior, wire, die hole — visible through top openings.
-- Top layer (z=10): structural housing, spool flanges, die frame — items render UNDER this.

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

-- ═══════════════════════════════════════════════════════════════════════════
-- BASE LAYER: interiors visible through top layer openings
-- ═══════════════════════════════════════════════════════════════════════════
local function draw_base(img, tag, phase)
  local sx, sy = 15, 15

  -- ── Spool center interior (visible through small top layer opening) ──
  -- Only the innermost part — the wire wound ring is on the top layer
  H.circle(img, sx, sy, 4, COPPER_DK)
  H.circle(img, sx, sy, 3, SPOOL_BG)

  -- ── Die interior (visible through top layer die opening) ─────────────
  -- Die block
  H.rect(img, 8, 38, 23, 50, DIE_DARK)
  H.rect(img, 9, 39, 22, 49, DIE_METAL)
  -- Die hole (where wire passes through)
  H.circle(img, 15, 44, 3, C.chamber)
  H.circle(img, 15, 44, 2, C.chamber_deep)
  H.px(img, 15, 44, WIRE)

  -- Wire being drawn through
  if tag == "active" then
    H.line(img, 15, sy + 11, 15, 44, WIRE)
    H.line(img, 15, 44, 15, 62, WIRE)
    -- Drawing sparks at die
    local sh = {{-1,0},{1,0},{0,-1},{0,1}}
    local s = sh[(phase % 4) + 1]
    H.px(img, 15 + s[1], 44 + s[2], C.fire_inner)
    H.px(img, 15 - s[1], 44 - s[2], C.fire_mid)
  elseif tag == "windup" and phase == 1 then
    H.line(img, 15, sy + 11, 15, 44, WIRE_DK)
    H.px(img, 15, 44, C.ember)
  elseif tag == "winddown" and phase == 0 then
    H.line(img, 15, sy + 11, 15, 44, WIRE_DK)
    H.line(img, 15, 44, 15, 62, WIRE_DK)
  end

  -- Output channel floor
  H.rect(img, 14, 50, 16, 62, C.panel_inner)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- TOP LAYER: structural housing — items render underneath this
-- ═══════════════════════════════════════════════════════════════════════════
local function draw_top(img, tag, phase)
  local sx, sy = 15, 15
  local CLEAR = H.rgba(0, 0, 0, 0)

  -- ── Full structural body (both tiles) ────────────────────────────────
  -- Overall outline
  H.rect_outline(img, 0, 0, 31, 63, C.outline)
  H.line(img, 0, 31, 31, 31, C.outline)

  -- TOP TILE: body fill
  H.rect(img, 1, 1, 30, 30, C.body)
  H.rect(img, 2, 2, 29, 29, C.panel)

  -- BOTTOM TILE: body fill
  H.rect(img, 1, 32, 30, 62, C.body)
  H.rect(img, 2, 33, 29, 61, C.panel)

  -- ── Copper accent strips ─────────────────────────────────────────────
  for x = 4, 27 do
    H.px(img, x, 3, COPPER_DK)
    H.px(img, x, 28, COPPER_DK)
    H.px(img, x, 35, COPPER_DK)
    H.px(img, x, 60, COPPER_DK)
  end
  for y = 4, 28 do H.px(img, 3, y, COPPER_DK) end
  for y = 35, 60 do H.px(img, 3, y, COPPER_DK) end

  -- ── Full spool (on top layer — covers items) ─────────────────────────
  H.circle(img, sx, sy, 13, C.outline)
  H.circle(img, sx, sy, 12, COPPER)
  H.circle(img, sx, sy, 11, COPPER_DK)
  H.circle(img, sx, sy, 10, COPPER)
  H.circle(img, sx, sy, 8, COPPER_RM)
  H.circle(img, sx, sy, 5, COPPER_DK)

  -- Spool rotation animation (spinning streaks across wire rings)
  if tag == "active" then
    -- 4 phases of rotation: streaks rotate around the spool
    local streaks = {
      -- phase 0: horizontal streaks
      {{-9,0},{-8,0},{-7,0},{7,0},{8,0},{9,0},  {0,-6},{0,6}},
      -- phase 1: diagonal streaks (NE-SW)
      {{-6,-6},{-7,-7},{5,5},{6,6},{7,7},  {-5,5},{5,-5}},
      -- phase 2: vertical streaks
      {{0,-9},{0,-8},{0,-7},{0,7},{0,8},{0,9},  {-6,0},{6,0}},
      -- phase 3: diagonal streaks (NW-SE)
      {{6,-6},{7,-7},{-5,5},{-6,6},{-7,7},  {5,5},{-5,-5}},
    }
    for _, p in ipairs(streaks[(phase % 4) + 1]) do
      H.px(img, sx + p[1], sy + p[2], COPPER_LT)
    end
  elseif tag == "windup" then
    -- Slight movement hint
    if phase == 1 then
      H.px(img, sx + 8, sy, COPPER_LT)
      H.px(img, sx - 8, sy, COPPER_LT)
    end
  elseif tag == "winddown" then
    if phase == 0 then
      H.px(img, sx, sy + 8, COPPER_LT)
      H.px(img, sx, sy - 8, COPPER_LT)
    end
  end

  -- ── Small center opening (items clip through hub) ────────────────────
  H.circle(img, sx, sy, 4, CLEAR)

  -- ── Spool axle cap ───────────────────────────────────────────────────
  H.circle(img, sx, sy, 2, DIE_METAL)
  H.px(img, sx, sy, COPPER_LT)

  -- ── Tensioner arm (connecting spool to die) ──────────────────────────
  H.rect(img, 13, 28, 17, 37, C.body)
  H.rect(img, 14, 29, 16, 36, DIE_METAL)
  H.rect_outline(img, 13, 28, 17, 37, C.outline)
  -- Tensioner rollers
  H.circle(img, 15, 29, 1, COPPER)
  H.circle(img, 15, 36, 1, COPPER)

  -- ── Die housing frame (structural, covers die edges) ─────────────────
  H.rect(img, 6, 36, 25, 52, C.body_light)
  H.rect(img, 7, 37, 24, 51, C.panel)
  H.rect_outline(img, 6, 36, 25, 52, COPPER_DK)

  -- ── Clear die opening (base layer die visible through) ───────────────
  H.rect(img, 10, 40, 20, 48, CLEAR)

  -- ── Output guide frame (covers channel edges) ───────────────────────
  H.rect(img, 12, 52, 13, 62, C.panel_inner)
  H.rect(img, 17, 52, 18, 62, C.panel_inner)
  H.line(img, 12, 52, 18, 52, COPPER_DK)

  -- ── Guide bolts on die housing ───────────────────────────────────────
  for _, p in ipairs({{8,38},{23,38},{8,50},{23,50}}) do
    H.px(img, p[1], p[2], COPPER)
  end

  -- ── Corner bolts ─────────────────────────────────────────────────────
  for _, p in ipairs({{3,3},{28,3},{3,28},{28,28},{3,34},{28,34},{3,60},{28,60}}) do
    H.px(img, p[1], p[2], C.rivet)
  end

  -- ── Active state effects (on top layer) ──────────────────────────────
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
