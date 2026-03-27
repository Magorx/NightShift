-- drill_sprite.lua
-- Top-down drill: resource extractor with rotating drill bit.
-- 2 layers (base, top), 10 frames: idle(2) + windup(2) + active(4) + winddown(2).

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

local function draw_base(img, tag, phase)
  -- Outline and body
  H.rect_outline(img, 0, 0, 31, 31, C.outline)
  H.rect(img, 1, 1, 30, 30, C.body)
  H.rect(img, 2, 2, 29, 29, C.panel)

  -- Central bore hole
  local cx, cy = 15, 15
  H.circle(img, cx, cy, 10, C.chamber)

  if tag == "active" then
    -- Active: drill debris / particles
    H.circle(img, cx, cy, 9, C.bore)
    H.circle(img, cx, cy, 7, C.bore_deep)
    -- Rotating debris pattern
    local angles = {{1,0},{0,1},{-1,0},{0,-1}}
    local a = angles[(phase % 4) + 1]
    H.px(img, cx + a[1]*5, cy + a[2]*5, C.iron_ore)
    H.px(img, cx - a[1]*3, cy + a[2]*4, C.copper_ore)
    H.px(img, cx + a[2]*6, cy - a[1]*6, C.iron_ore)
  elseif tag == "windup" then
    H.circle(img, cx, cy, 9, C.bore)
    if phase == 1 then
      H.px(img, cx+3, cy, C.iron_ore)
    end
  elseif tag == "winddown" then
    H.circle(img, cx, cy, 9, C.bore)
    if phase == 0 then
      H.px(img, cx-3, cy, C.iron_ore)
    end
  else
    -- Idle: dark bore hole
    H.circle(img, cx, cy, 9, C.bore_deep)
  end

  -- Corner rivets
  for _, p in ipairs({{3,3},{28,3},{3,28},{28,28}}) do
    H.px(img, p[1], p[2], C.rivet)
  end

  -- Output chute (right side)
  H.rect(img, 27, 13, 30, 18, C.panel_inner)
  H.line(img, 27, 12, 27, 19, C.rim)
end

local function draw_top(img, tag, phase)
  local cx, cy = 15, 15

  -- Drill bit (cross shape that rotates when active)
  local function draw_bit(rot)
    -- 4 arms of the drill bit
    local arms = {
      {{0,-1},{0,-2},{0,-3},{0,-4},{0,-5},{0,-6}},
      {{0,1},{0,2},{0,3},{0,4},{0,5},{0,6}},
      {{-1,0},{-2,0},{-3,0},{-4,0},{-5,0},{-6,0}},
      {{1,0},{2,0},{3,0},{4,0},{5,0},{6,0}},
    }
    local diag_arms = {
      {{-1,-1},{-2,-2},{-3,-3},{-4,-4}},
      {{1,-1},{2,-2},{3,-3},{4,-4}},
      {{-1,1},{-2,2},{-3,3},{-4,4}},
      {{1,1},{2,2},{3,3},{4,4}},
    }
    -- Choose arm set based on rotation
    local use_arms = (rot % 2 == 0) and arms or diag_arms
    for _, arm in ipairs(use_arms) do
      for _, p in ipairs(arm) do
        H.px(img, cx+p[1], cy+p[2], BIT)
      end
    end
    -- Center hub
    H.circle(img, cx, cy, 2, STEEL)
    H.px(img, cx, cy, STEEL_LT)
  end

  if tag == "active" then
    draw_bit(phase)
  elseif tag == "windup" then
    draw_bit(0)  -- bit visible but stationary
    if phase == 1 then
      -- Slight movement hint
      H.px(img, cx+1, cy-1, STEEL_LT)
    end
  elseif tag == "winddown" then
    draw_bit(0)
    if phase == 0 then
      H.px(img, cx-1, cy+1, STEEL_LT)
    end
  else
    -- Idle: bit resting (+ shape)
    draw_bit(0)
  end

  -- Bore rim (always visible)
  H.circle_outline(img, cx, cy, 9, C.rim)

  -- Housing frame corners
  for _, p in ipairs({{5,5},{26,5},{5,26},{26,26}}) do
    H.px(img, p[1], p[2], STEEL_DK)
  end
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr, DIR, "main")
print("[drill] done")
