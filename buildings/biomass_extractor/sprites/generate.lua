-- biomass_extractor_sprite.lua
-- Top-down biomass extractor: organic suction device that pulls biomass from ground.
-- Extraction part: 1x2 tile (64x32), left=suction maw, right=collection hopper.
-- Output device: 1x1 tile (32x32), pipe junction with output chute.

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
local BARK      = H.hex("#4A3C28")
local BARK_DK   = H.hex("#3A2E1E")
local BARK_LT   = H.hex("#5A4C34")
local MOSS      = H.hex("#3E5A2A")
local MOSS_DK   = H.hex("#2E4820")
local MOSS_LT   = H.hex("#4E7038")
local SAP       = H.hex("#6A8840")
local SAP_GLOW  = H.hex("#82A84E")
local MULCH     = H.hex("#2A2218")
local MULCH_MID = H.hex("#382E20")
local ROOT      = H.hex("#5A4830")
local ROOT_DK   = H.hex("#483A24")

local DIR = "/Users/gorishniymax/Repos/factor/buildings/biomass_extractor/sprites"

-- ═══════════════════════════════════════════════════════════════════════════
-- EXTRACTION PART (1x2 = 64x32)
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_extractor_base(img, tag, phase)
  H.rect(img, 0, 0, 63, 31, C.outline)

  -- LEFT CELL: suction maw interior
  H.rect(img, 1, 1, 30, 30, BARK_DK)
  local cx, cy = 15, 15
  H.circle(img, cx, cy, 11, MULCH)

  if tag == "active" then
    H.circle(img, cx, cy, 10, MOSS_DK)
    H.circle(img, cx, cy, 7, MULCH)
    local offsets = {{1,0},{0,1},{-1,0},{0,-1}}
    local a = offsets[(phase % 4) + 1]
    H.px(img, cx + a[1]*4, cy + a[2]*4, SAP)
    H.px(img, cx - a[1]*3, cy + a[2]*3, MOSS_LT)
    H.px(img, cx + a[2]*5, cy - a[1]*5, SAP_GLOW)
    H.px(img, cx - a[2]*6, cy + a[1]*6, MOSS)
    H.px(img, cx + a[1]*8, cy + a[2]*8, ROOT)
    H.px(img, cx - a[2]*7, cy + a[1]*7, ROOT_DK)
    H.px(img, cx + a[2]*9, cy - a[1]*9, MOSS_DK)
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
    H.circle(img, cx, cy, 10, MULCH)
    local em = phase == 0
      and {{cx-3,cy-2},{cx+4,cy+3},{cx+1,cy-4}}
      or  {{cx+3,cy-3},{cx-4,cy+2},{cx-1,cy+4}}
    for _, p in ipairs(em) do H.px(img, p[1], p[2], MOSS_DK) end
    H.px(img, cx + (phase == 0 and -1 or 1), cy, ROOT_DK)
  end

  -- Transfer pipe between cells
  H.rect(img, 28, 12, 35, 19, MULCH_MID)
  H.line(img, 28, 11, 35, 11, BARK_DK)
  H.line(img, 28, 20, 35, 20, BARK_DK)

  -- RIGHT CELL: collection hopper interior
  H.rect(img, 32, 1, 62, 30, BARK_DK)
  H.rect(img, 34, 3, 60, 28, MULCH)

  -- Hopper fill level varies with tag
  if tag == "active" then
    -- Biomass churning inside — phase-shifted chunks
    local base_chunks = {
      {36,5},{42,6},{48,4},{54,7},
      {37,11},{44,10},{50,13},{56,11},
      {35,17},{41,16},{49,18},{55,17},
      {38,23},{45,22},{51,24},{57,23},
    }
    for i, p in ipairs(base_chunks) do
      local shift = ((phase + i) % 4)
      local dx = (shift < 2) and 1 or -1
      H.px(img, p[1] + dx, p[2], MOSS_DK)
      H.px(img, p[1] + dx + 1, p[2], MULCH_MID)
    end
    -- Sap drips flowing through
    local drip_y = 5 + (phase * 6) % 24
    H.px(img, 47, drip_y, SAP)
    H.px(img, 47, drip_y + 1, SAP_GLOW)
    H.px(img, 53, (drip_y + 12) % 24 + 5, SAP)
  elseif tag == "windup" then
    -- Sparse chunks, starting to fill
    local chunks = {{38,8},{46,12},{52,18},{44,24},{56,6}}
    for _, p in ipairs(chunks) do
      H.px(img, p[1], p[2], MOSS_DK)
    end
    if phase == 1 then
      H.px(img, 42, 15, SAP)
    end
  elseif tag == "winddown" then
    -- Chunks settling
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
    if phase == 0 then
      H.px(img, 47, 15, SAP)
    end
  else
    -- Idle: static debris
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
end

local function draw_extractor_top(img, tag, phase)
  local cx, cy = 15, 15
  local CLEAR = H.rgba(0, 0, 0, 0)

  -- LEFT CELL: suction housing
  H.rect_outline(img, 0, 0, 31, 31, C.outline)
  H.rect(img, 1, 1, 30, 30, BARK)
  H.rect(img, 2, 2, 29, 29, BARK_LT)

  for y = 4, 27, 3 do
    for x = 2, 29 do
      if (x + y) % 7 < 2 then H.px(img, x, y, BARK) end
    end
  end

  for x = 4, 27 do
    H.px(img, x, 3, MOSS_DK)
    H.px(img, x, 28, MOSS_DK)
  end
  for y = 4, 27 do
    H.px(img, 3, y, MOSS_DK)
    H.px(img, 28, y, MOSS_DK)
  end

  H.circle(img, cx, cy, 10, CLEAR)
  H.circle_outline(img, cx, cy, 10, MOSS)
  H.circle_outline(img, cx, cy, 11, BARK_DK)

  -- Rim glow when active
  if tag == "active" then
    -- Pulsing rim highlight
    local glow_col = (phase % 2 == 0) and MOSS_LT or MOSS
    H.circle_outline(img, cx, cy, 10, glow_col)

    -- Rotating root tendrils
    local r = phase % 4
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
  elseif tag == "windup" then
    H.circle_outline(img, cx, cy, 10, MOSS)
    if phase == 1 then
      H.px(img, cx-9, cy, ROOT_DK)
      H.px(img, cx+9, cy, ROOT_DK)
    end
  elseif tag == "winddown" then
    H.circle_outline(img, cx, cy, 10, MOSS)
    if phase == 0 then
      for _, p in ipairs({{cx-9,cy},{cx+9,cy},{cx,cy-9},{cx,cy+9}}) do
        H.px(img, p[1], p[2], ROOT)
      end
    end
  else
    for _, p in ipairs({{cx-9,cy},{cx+9,cy},{cx,cy-9},{cx,cy+9}}) do
      H.px(img, p[1], p[2], ROOT_DK)
    end
  end

  -- RIGHT CELL: hopper housing
  H.rect_outline(img, 32, 0, 63, 31, C.outline)
  H.rect(img, 33, 1, 62, 30, BARK)
  H.rect(img, 34, 2, 61, 29, BARK_LT)

  for y = 4, 27, 3 do
    for x = 34, 61 do
      if (x + y) % 7 < 2 then H.px(img, x, y, BARK) end
    end
  end

  H.rect(img, 36, 5, 59, 26, CLEAR)
  H.rect_outline(img, 36, 5, 59, 26, BARK_DK)
  H.rect_outline(img, 37, 6, 58, 25, MOSS_DK)

  -- Connecting pipe frame
  H.line(img, 28, 11, 35, 11, C.outline)
  H.line(img, 28, 20, 35, 20, C.outline)
  H.px(img, 30, 12, BARK_DK)
  H.px(img, 30, 19, BARK_DK)
  H.px(img, 33, 12, BARK_DK)
  H.px(img, 33, 19, BARK_DK)

  -- Pipe flow indicator (active only)
  if tag == "active" then
    local flow_x = 29 + (phase % 4) * 2
    if flow_x <= 34 then
      H.px(img, flow_x, 15, SAP)
      H.px(img, flow_x, 16, SAP)
    end
  end

  for _, p in ipairs({{3,3},{28,3},{3,28},{28,28}}) do
    H.px(img, p[1], p[2], ROOT)
  end
  for _, p in ipairs({{35,3},{60,3},{35,28},{60,28}}) do
    H.px(img, p[1], p[2], ROOT)
  end
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
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_output_base(img, tag, phase)
  H.rect(img, 0, 0, 31, 31, C.outline)
  H.rect(img, 1, 1, 30, 30, BARK_DK)
  H.rect(img, 4, 4, 27, 27, MULCH)

  if tag == "active" then
    -- Biomass flowing through — animated chunks
    local chunks = {
      {6,6},{10,8},{14,6},{18,10},{22,7},
      {8,14},{12,18},{16,14},{20,20},{24,16},
      {7,22},{13,24},{19,22},{25,26},
    }
    for i, p in ipairs(chunks) do
      local shift = ((phase + i) % 4)
      local dx = (shift < 2) and 1 or 0
      local dy = (shift == 1 or shift == 2) and 1 or 0
      H.px(img, p[1] + dx, p[2] + dy, MOSS_DK)
    end
    -- Flow toward output chute
    local flow_x = 22 + (phase % 3)
    H.px(img, flow_x, 15, SAP)
    H.px(img, flow_x, 16, SAP_GLOW)
    -- Chute actively feeding
    H.rect(img, 26, 12, 31, 19, MULCH_MID)
    H.px(img, 28 + (phase % 3), 15, SAP)
  elseif tag == "windup" then
    for _, p in ipairs({{6,6},{14,6},{22,7},{8,14},{16,14},{24,16}}) do
      H.px(img, p[1], p[2], MOSS_DK)
    end
    H.rect(img, 26, 12, 31, 19, MULCH_MID)
    if phase == 1 then
      H.px(img, 15, 15, SAP)
    end
  elseif tag == "winddown" then
    for _, p in ipairs({{6,6},{10,8},{14,6},{18,10},{22,7},{8,14},{12,18},{16,14}}) do
      H.px(img, p[1], p[2], MOSS_DK)
    end
    H.rect(img, 26, 12, 31, 19, MULCH_MID)
    if phase == 0 then
      H.px(img, 24, 15, SAP)
    end
  else
    -- Idle: static residue
    for _, p in ipairs({{6,6},{10,8},{14,6},{18,10},{22,7}}) do
      H.px(img, p[1], p[2], MOSS_DK)
    end
    for _, p in ipairs({{8,14},{12,18},{16,14},{20,20},{24,16}}) do
      H.px(img, p[1], p[2], MULCH_MID)
    end
    for _, p in ipairs({{7,22},{13,24},{19,22},{25,26}}) do
      H.px(img, p[1], p[2], ROOT_DK)
    end
    H.rect(img, 26, 12, 31, 19, MULCH_MID)
  end
end

local function draw_output_top(img, tag, phase)
  local CLEAR = H.rgba(0, 0, 0, 0)

  H.rect_outline(img, 0, 0, 31, 31, C.outline)
  H.rect(img, 1, 1, 30, 30, BARK)
  H.rect(img, 2, 2, 29, 29, BARK_LT)

  for y = 4, 27, 3 do
    for x = 2, 29 do
      if (x + y) % 7 < 2 then H.px(img, x, y, BARK) end
    end
  end

  for x = 4, 27 do
    H.px(img, x, 3, MOSS_DK)
    H.px(img, x, 28, MOSS_DK)
  end
  for y = 4, 27 do
    H.px(img, 3, y, MOSS_DK)
    H.px(img, 28, y, MOSS_DK)
  end

  H.rect(img, 6, 6, 25, 25, CLEAR)
  H.rect_outline(img, 6, 6, 25, 25, BARK_DK)
  H.rect_outline(img, 7, 7, 24, 24, MOSS_DK)

  -- Output chute frame
  H.line(img, 26, 11, 26, 20, MOSS)
  H.line(img, 31, 11, 31, 20, C.outline)
  H.px(img, 27, 12, BARK_DK)
  H.px(img, 27, 19, BARK_DK)

  -- Chute activity indicator
  if tag == "active" then
    -- Pulsing chute rim
    local chute_col = (phase % 2 == 0) and MOSS_LT or MOSS
    H.line(img, 26, 12, 26, 19, chute_col)
    -- Inner rim glow
    local rim_col = (phase % 2 == 0) and MOSS_LT or MOSS_DK
    H.rect_outline(img, 7, 7, 24, 24, rim_col)
  elseif tag == "windup" then
    if phase == 1 then
      H.rect_outline(img, 7, 7, 24, 24, MOSS)
    end
  end

  for _, p in ipairs({{3,3},{28,3},{3,28},{28,28}}) do
    H.px(img, p[1], p[2], ROOT)
  end
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
