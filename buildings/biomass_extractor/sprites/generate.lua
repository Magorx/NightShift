-- biomass_extractor_sprite.lua
-- Top-down biomass extractor: organic suction device that pulls biomass from ground.
-- Extraction part: 1x2 tile (64x32), left=suction maw, right=collection hopper.
-- Output device: 1x1 tile (32x32), pipe junction with output chute.
--
-- Base layer: internal machinery visible through openings.
-- Top layer: structural housing, suction ring, pipe connections.

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local LAYERS = {"base", "top"}
local TAGS = {
  {name="idle",     from=1, to=2, duration=0.5},
  {name="windup",   from=3, to=4, duration=0.15},
  {name="active",   from=5, to=8, duration=0.15},
  {name="winddown", from=9, to=10, duration=0.15},
}

-- Biomass extractor identity: earthy green-brown, organic
local BARK      = H.hex("#4A3C28")  -- dark wood/bark outer
local BARK_DK   = H.hex("#3A2E1E")  -- deep shadow bark
local BARK_LT   = H.hex("#5A4C34")  -- bark highlight
local MOSS      = H.hex("#3E5A2A")  -- moss/organic accent
local MOSS_DK   = H.hex("#2E4820")  -- deep moss
local MOSS_LT   = H.hex("#4E7038")  -- bright moss
local SAP       = H.hex("#6A8840")  -- sap/fluid green
local SAP_GLOW  = H.hex("#82A84E")  -- bright sap
local MULCH     = H.hex("#2A2218")  -- dark organic interior
local MULCH_MID = H.hex("#382E20")  -- mid organic
local ROOT      = H.hex("#5A4830")  -- root/tendril color
local ROOT_DK   = H.hex("#483A24")  -- dark root

local DIR = "/Users/gorishniymax/Repos/factor/buildings/biomass_extractor/sprites"

-- ═══════════════════════════════════════════════════════════════════════════
-- EXTRACTION PART (1x2 = 64x32)
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_extractor_base(img, tag, phase)
  -- Overall dark base
  H.rect(img, 0, 0, 63, 31, C.outline)

  -- LEFT CELL: suction maw interior (visible through top opening)
  H.rect(img, 1, 1, 30, 30, BARK_DK)
  local cx, cy = 15, 15

  -- Circular suction pit
  H.circle(img, cx, cy, 11, MULCH)

  if tag == "active" then
    -- Swirling biomass being pulled in
    H.circle(img, cx, cy, 10, MOSS_DK)
    H.circle(img, cx, cy, 7, MULCH)
    -- Rotating tendril/debris pattern (4 phases)
    local offsets = {{1,0},{0,1},{-1,0},{0,-1}}
    local a = offsets[(phase % 4) + 1]
    -- Inner swirl particles
    H.px(img, cx + a[1]*4, cy + a[2]*4, SAP)
    H.px(img, cx - a[1]*3, cy + a[2]*3, MOSS_LT)
    H.px(img, cx + a[2]*5, cy - a[1]*5, SAP_GLOW)
    H.px(img, cx - a[2]*6, cy + a[1]*6, MOSS)
    -- Outer swirl ring
    H.px(img, cx + a[1]*8, cy + a[2]*8, ROOT)
    H.px(img, cx - a[2]*7, cy + a[1]*7, ROOT_DK)
    H.px(img, cx + a[2]*9, cy - a[1]*9, MOSS_DK)
    -- Center vortex
    H.circle(img, cx, cy, 2, SAP)
    H.px(img, cx, cy, SAP_GLOW)
  elseif tag == "windup" then
    H.circle(img, cx, cy, 10, MULCH_MID)
    if phase == 0 then
      H.px(img, cx-2, cy, MOSS_DK)
      H.px(img, cx+3, cy+2, ROOT)
    else
      H.circle(img, cx, cy, 4, MOSS_DK)
      H.px(img, cx, cy, SAP)
      H.px(img, cx+3, cy-2, MOSS)
    end
  elseif tag == "winddown" then
    if phase == 0 then
      H.circle(img, cx, cy, 10, MOSS_DK)
      H.circle(img, cx, cy, 5, MULCH_MID)
      H.px(img, cx-3, cy+1, ROOT)
      H.px(img, cx+2, cy-3, MOSS)
    else
      H.circle(img, cx, cy, 10, MULCH)
      H.px(img, cx-3, cy, ROOT_DK)
      H.px(img, cx+4, cy+2, MOSS_DK)
    end
  else
    -- Idle: dark pit with faint residue
    H.circle(img, cx, cy, 10, MULCH)
    local em = phase == 0
      and {{cx-3,cy-2},{cx+4,cy+3},{cx+1,cy-4}}
      or  {{cx+3,cy-3},{cx-4,cy+2},{cx-1,cy+4}}
    for _, p in ipairs(em) do H.px(img, p[1], p[2], MOSS_DK) end
    H.px(img, cx + (phase == 0 and -1 or 1), cy, ROOT_DK)
  end

  -- Fuel chute between cells (internal pipe floor)
  H.rect(img, 28, 12, 35, 19, MULCH_MID)
  H.line(img, 28, 11, 35, 11, BARK_DK)
  H.line(img, 28, 20, 35, 20, BARK_DK)

  -- RIGHT CELL: collection hopper interior
  H.rect(img, 32, 1, 62, 30, BARK_DK)
  H.rect(img, 34, 3, 60, 28, MULCH)
  -- Collected biomass texture (organic debris)
  local chunks = {
    {36,5},{42,6},{48,4},{54,7},
    {37,11},{44,10},{50,13},{56,11},
    {35,17},{41,16},{49,18},{55,17},
    {38,23},{45,22},{51,24},{57,23},
    {36,27},{43,27},{50,26},{56,27},
  }
  for _, p in ipairs(chunks) do
    H.px(img, p[1], p[2], MOSS_DK)
    H.px(img, p[1]+1, p[2], MULCH_MID)
  end
  for _, p in ipairs({{40,8},{52,15},{58,22},{44,20},{36,14}}) do
    H.px(img, p[1], p[2], ROOT_DK)
  end
end

local function draw_extractor_top(img, tag, phase)
  local cx, cy = 15, 15
  local CLEAR = H.rgba(0, 0, 0, 0)

  -- ── LEFT CELL: suction housing ──────────────────────────────────────
  H.rect_outline(img, 0, 0, 31, 31, C.outline)
  H.rect(img, 1, 1, 30, 30, BARK)
  H.rect(img, 2, 2, 29, 29, BARK_LT)

  -- Bark texture strips (horizontal grain)
  for y = 4, 27, 3 do
    for x = 2, 29 do
      if (x + y) % 7 < 2 then
        H.px(img, x, y, BARK)
      end
    end
  end

  -- Moss accent along edges
  for x = 4, 27 do
    H.px(img, x, 3, MOSS_DK)
    H.px(img, x, 28, MOSS_DK)
  end
  for y = 4, 27 do
    H.px(img, 3, y, MOSS_DK)
    H.px(img, 28, y, MOSS_DK)
  end

  -- Clear suction opening (base layer shows through)
  H.circle(img, cx, cy, 10, CLEAR)

  -- Suction rim (organic ring)
  H.circle_outline(img, cx, cy, 10, MOSS)
  H.circle_outline(img, cx, cy, 11, BARK_DK)

  -- Root tendrils reaching into the opening (subtle animation)
  if tag == "active" then
    local r = phase % 4
    -- Rotating root pattern
    local tendrils = {
      {{cx-9,cy},{cx-8,cy-1},{cx-7,cy}},
      {{cx,cy-9},{cx+1,cy-8},{cx,cy-7}},
      {{cx+9,cy},{cx+8,cy+1},{cx+7,cy}},
      {{cx,cy+9},{cx-1,cy+8},{cx,cy+7}},
    }
    for i, t in ipairs(tendrils) do
      local col = ((i + r) % 2 == 0) and ROOT or ROOT_DK
      for _, p in ipairs(t) do H.px(img, p[1], p[2], col) end
    end
  elseif tag == "idle" then
    -- Static roots
    for _, p in ipairs({{cx-9,cy},{cx+9,cy},{cx,cy-9},{cx,cy+9}}) do
      H.px(img, p[1], p[2], ROOT_DK)
    end
  end

  -- ── RIGHT CELL: hopper housing ──────────────────────────────────────
  H.rect_outline(img, 32, 0, 63, 31, C.outline)
  H.rect(img, 33, 1, 62, 30, BARK)
  H.rect(img, 34, 2, 61, 29, BARK_LT)

  -- Bark texture
  for y = 4, 27, 3 do
    for x = 34, 61 do
      if (x + y) % 7 < 2 then
        H.px(img, x, y, BARK)
      end
    end
  end

  -- Hopper opening (transparent to show collected biomass)
  H.rect(img, 36, 5, 59, 26, CLEAR)
  H.rect_outline(img, 36, 5, 59, 26, BARK_DK)
  -- Inner rim
  H.rect_outline(img, 37, 6, 58, 25, MOSS_DK)

  -- Connecting pipe frame between cells
  H.line(img, 28, 11, 35, 11, C.outline)
  H.line(img, 28, 20, 35, 20, C.outline)
  H.px(img, 30, 12, BARK_DK)
  H.px(img, 30, 19, BARK_DK)
  H.px(img, 33, 12, BARK_DK)
  H.px(img, 33, 19, BARK_DK)

  -- Corner rivets (bark bolts)
  for _, p in ipairs({{3,3},{28,3},{3,28},{28,28}}) do
    H.px(img, p[1], p[2], ROOT)
  end
  for _, p in ipairs({{35,3},{60,3},{35,28},{60,28}}) do
    H.px(img, p[1], p[2], ROOT)
  end

  -- Structural corner braces
  for _, p in ipairs({{5,5},{26,5},{5,26},{26,26}}) do
    H.px(img, p[1], p[2], MOSS)
  end
end

local spr, lm = H.new_sprite(64, 32, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_extractor_base(img, tag, phase)
  else draw_extractor_top(img, tag, phase) end
end)
H.save_and_export(spr, DIR, "extractor")
print("[biomass_extractor] extractor done")

-- ═══════════════════════════════════════════════════════════════════════════
-- OUTPUT DEVICE (1x1 = 32x32)
-- Pipe junction box: receives biomass, outputs to conveyor.
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_output_base(img, _tag, _phase)
  H.rect(img, 0, 0, 31, 31, C.outline)
  H.rect(img, 1, 1, 30, 30, BARK_DK)

  -- Internal pipe chamber
  H.rect(img, 4, 4, 27, 27, MULCH)
  -- Biomass residue texture
  for _, p in ipairs({{6,6},{10,8},{14,6},{18,10},{22,7}}) do
    H.px(img, p[1], p[2], MOSS_DK)
  end
  for _, p in ipairs({{8,14},{12,18},{16,14},{20,20},{24,16}}) do
    H.px(img, p[1], p[2], MULCH_MID)
  end
  for _, p in ipairs({{7,22},{13,24},{19,22},{25,26}}) do
    H.px(img, p[1], p[2], ROOT_DK)
  end

  -- Output chute floor
  H.rect(img, 26, 12, 31, 19, MULCH_MID)
end

local function draw_output_top(img, _tag, _phase)
  local CLEAR = H.rgba(0, 0, 0, 0)

  -- Structural housing
  H.rect_outline(img, 0, 0, 31, 31, C.outline)
  H.rect(img, 1, 1, 30, 30, BARK)
  H.rect(img, 2, 2, 29, 29, BARK_LT)

  -- Bark texture
  for y = 4, 27, 3 do
    for x = 2, 29 do
      if (x + y) % 7 < 2 then
        H.px(img, x, y, BARK)
      end
    end
  end

  -- Moss accent strips
  for x = 4, 27 do
    H.px(img, x, 3, MOSS_DK)
    H.px(img, x, 28, MOSS_DK)
  end
  for y = 4, 27 do
    H.px(img, 3, y, MOSS_DK)
    H.px(img, 28, y, MOSS_DK)
  end

  -- Central pipe opening (shows base layer through)
  H.rect(img, 6, 6, 25, 25, CLEAR)
  H.rect_outline(img, 6, 6, 25, 25, BARK_DK)
  H.rect_outline(img, 7, 7, 24, 24, MOSS_DK)

  -- Output chute frame
  H.line(img, 26, 11, 26, 20, MOSS)
  H.line(img, 31, 11, 31, 20, C.outline)
  H.px(img, 27, 12, BARK_DK)
  H.px(img, 27, 19, BARK_DK)

  -- Corner rivets
  for _, p in ipairs({{3,3},{28,3},{3,28},{28,28}}) do
    H.px(img, p[1], p[2], ROOT)
  end

  -- Corner braces
  for _, p in ipairs({{5,5},{26,5},{5,26},{26,26}}) do
    H.px(img, p[1], p[2], MOSS)
  end
end

local spr2, lm2 = H.new_sprite(32, 32, LAYERS, TAGS)
H.render_frames(spr2, lm2, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_output_base(img, tag, phase)
  else draw_output_top(img, tag, phase) end
end)
H.save_and_export(spr2, DIR, "output")
print("[biomass_extractor] output done")
