-- drill_sprite.lua
-- Top-down drill: resource extractor with rotating drill bit.
-- 1x1 tile (32x32 per frame), 2 layers, 10 frames:
-- idle(2) + windup(2) + active(4) + winddown(2).
--
-- Base layer (z=0): bore hole interior, debris, ore particles — visible through top opening.
-- Top layer (z=10): structural housing, drill bit, rim — items render UNDER this.

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, FH = 32, 32
local LAYERS = {"base", "top"}
local TAGS = {
  {name="idle",     from=1, to=2, duration=0.5},
  {name="windup",   from=3, to=4, duration=0.15},
  {name="active",   from=5, to=8, duration=0.15},
  {name="winddown", from=9, to=10, duration=0.15},
}
local DIR = "/Users/gorishniymax/Repos/factor/buildings/drill/sprites"

-- Drill identity: steel blue-gray
local STEEL    = H.hex("#6A7080")
local STEEL_DK = H.hex("#505866")
local STEEL_LT = H.hex("#808898")
local BIT      = H.hex("#8090A0")
local BIT_DK   = H.hex("#607080")

-- ═══════════════════════════════════════════════════════════════════════════
-- BASE LAYER: bore hole interior — visible through top layer opening
-- ═══════════════════════════════════════════════════════════════════════════
local function draw_base(img, tag, phase)
  local cx, cy = 15, 15

  -- Bore hole background
  H.circle(img, cx, cy, 10, C.chamber)

  if tag == "active" then
    H.circle(img, cx, cy, 9, C.bore)
    H.circle(img, cx, cy, 7, C.bore_deep)
    -- Rotating debris pattern
    local angles = {{1,0},{0,1},{-1,0},{0,-1}}
    local a = angles[(phase % 4) + 1]
    H.px(img, cx + a[1]*5, cy + a[2]*5, C.iron_ore)
    H.px(img, cx - a[1]*3, cy + a[2]*4, C.copper_ore)
    H.px(img, cx + a[2]*6, cy - a[1]*6, C.iron_ore)
    H.px(img, cx - a[2]*4, cy + a[1]*3, C.copper_ore)
  elseif tag == "windup" then
    H.circle(img, cx, cy, 9, C.bore)
    if phase == 1 then
      H.px(img, cx+3, cy, C.iron_ore)
      H.px(img, cx-2, cy+3, C.copper_ore)
    end
  elseif tag == "winddown" then
    H.circle(img, cx, cy, 9, C.bore)
    if phase == 0 then
      H.px(img, cx-3, cy, C.iron_ore)
      H.px(img, cx+2, cy-2, C.copper_ore)
    end
  else
    -- Idle: dark bore hole
    H.circle(img, cx, cy, 9, C.bore_deep)
  end

  -- Output chute floor (visible through top opening)
  H.rect(img, 27, 13, 30, 18, C.panel_inner)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- TOP LAYER: structural housing — items render underneath this
-- ═══════════════════════════════════════════════════════════════════════════
local function draw_top(img, tag, phase)
  local cx, cy = 15, 15
  local CLEAR = H.rgba(0, 0, 0, 0)

  -- ── Full structural body ─────────────────────────────────────────────
  H.rect_outline(img, 0, 0, 31, 31, C.outline)
  H.rect(img, 1, 1, 30, 30, C.body)
  H.rect(img, 2, 2, 29, 29, C.panel)

  -- ── Steel accent strips ──────────────────────────────────────────────
  for x = 4, 27 do
    H.px(img, x, 3, STEEL_DK)
    H.px(img, x, 28, STEEL_DK)
  end
  for y = 4, 27 do
    H.px(img, 3, y, STEEL_DK)
    H.px(img, 28, y, STEEL_DK)
  end

  -- ── Clear bore opening (items and base layer show through) ───────────
  H.circle(img, cx, cy, 10, CLEAR)

  -- ── Bore rim (structural ring around opening) ────────────────────────
  H.circle_outline(img, cx, cy, 10, C.rim)
  H.circle_outline(img, cx, cy, 11, STEEL_DK)

  -- ── Drill bit (cross/X shape that rotates when active) ───────────────
  local function draw_bit(rot)
    local arms = {
      {{0,-1},{0,-2},{0,-3},{0,-4},{0,-5},{0,-6},{0,-7}},
      {{0,1},{0,2},{0,3},{0,4},{0,5},{0,6},{0,7}},
      {{-1,0},{-2,0},{-3,0},{-4,0},{-5,0},{-6,0},{-7,0}},
      {{1,0},{2,0},{3,0},{4,0},{5,0},{6,0},{7,0}},
    }
    local diag_arms = {
      {{-1,-1},{-2,-2},{-3,-3},{-4,-4},{-5,-5}},
      {{1,-1},{2,-2},{3,-3},{4,-4},{5,-5}},
      {{-1,1},{-2,2},{-3,3},{-4,4},{-5,5}},
      {{1,1},{2,2},{3,3},{4,4},{5,5}},
    }
    local use_arms = (rot % 2 == 0) and arms or diag_arms
    for _, arm in ipairs(use_arms) do
      for i, p in ipairs(arm) do
        local col = (i <= 3) and BIT or BIT_DK
        H.px(img, cx+p[1], cy+p[2], col)
      end
    end
    -- Center hub
    H.circle(img, cx, cy, 2, STEEL)
    H.px(img, cx, cy, STEEL_LT)
  end

  if tag == "active" then
    draw_bit(phase)
  elseif tag == "windup" then
    draw_bit(0)
    if phase == 1 then
      H.px(img, cx+1, cy-1, STEEL_LT)
    end
  elseif tag == "winddown" then
    draw_bit(0)
    if phase == 0 then
      H.px(img, cx-1, cy+1, STEEL_LT)
    end
  else
    draw_bit(0)
  end

  -- ── Output chute frame (covers edges, items pass through center) ─────
  H.line(img, 27, 12, 27, 19, C.rim)
  H.line(img, 31, 12, 31, 19, C.outline)

  -- ── Corner rivets ────────────────────────────────────────────────────
  for _, p in ipairs({{3,3},{28,3},{3,28},{28,28}}) do
    H.px(img, p[1], p[2], C.rivet)
  end

  -- ── Housing frame corners (structural mounts) ───────────────────────
  for _, p in ipairs({{5,5},{26,5},{5,26},{26,26}}) do
    H.px(img, p[1], p[2], STEEL)
  end
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr, DIR, "main")
print("[drill] done")
