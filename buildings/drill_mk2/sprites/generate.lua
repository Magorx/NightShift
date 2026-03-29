-- drill_mk2_sprite.lua
-- Top-down drill mk2: faster extractor with reinforced housing.
-- 1x1 tile (32x32 per frame), 2 layers, 10 frames:
-- idle(2) + windup(2) + active(4) + winddown(2).

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
local DIR = "/Users/gorishniymax/Repos/factor/buildings/drill_mk2/sprites"

-- Drill Mk2 identity: steel blue-gray, reinforced look
local STEEL    = H.hex("#708090")
local STEEL_DK = H.hex("#506070")
local STEEL_LT = H.hex("#90A0B0")
local BIT      = H.hex("#8898A8")
local BIT_DK   = H.hex("#6878A0")
local REINF    = H.hex("#586878")
local BOLT     = H.hex("#A0B0C0")

local function draw_base(img, tag, phase)
  -- Outline and reinforced body
  H.rect_outline(img, 0, 0, 31, 31, C.outline)
  H.rect(img, 1, 1, 30, 30, STEEL_DK)
  H.rect(img, 2, 2, 29, 29, STEEL)

  -- Reinforced corner brackets (mk2 distinction)
  H.rect(img, 1, 1, 5, 5, REINF)
  H.rect(img, 26, 1, 30, 5, REINF)
  H.rect(img, 1, 26, 5, 30, REINF)
  H.rect(img, 26, 26, 30, 30, REINF)

  -- Central bore hole
  local cx, cy = 15, 15
  H.circle(img, cx, cy, 10, C.chamber)

  if tag == "active" then
    -- Active: faster spinning debris
    H.circle(img, cx, cy, 9, C.bore)
    H.circle(img, cx, cy, 7, C.bore_deep)
    -- Double debris pattern (faster drill = more particles)
    local angles = {{1,0},{0,1},{-1,0},{0,-1}}
    local a = angles[(phase % 4) + 1]
    local b = angles[((phase + 2) % 4) + 1]
    H.px(img, cx + a[1]*5, cy + a[2]*5, C.iron_ore)
    H.px(img, cx - a[1]*3, cy + a[2]*4, C.copper_ore)
    H.px(img, cx + a[2]*6, cy - a[1]*6, C.iron_ore)
    -- Extra debris for mk2
    H.px(img, cx + b[1]*4, cy + b[2]*4, C.copper_ore)
    H.px(img, cx + b[2]*5, cy - b[1]*3, C.iron_ore)
  elseif tag == "windup" then
    H.circle(img, cx, cy, 9, C.bore)
    if phase == 1 then
      H.px(img, cx+3, cy, C.iron_ore)
      H.px(img, cx-2, cy+2, C.copper_ore)
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

  -- Corner bolts (reinforced housing)
  for _, p in ipairs({{3,3},{28,3},{3,28},{28,28}}) do
    H.px(img, p[1], p[2], BOLT)
  end
  -- Extra mid-edge bolts (mk2 reinforcement)
  for _, p in ipairs({{15,2},{15,29},{2,15},{29,15}}) do
    H.px(img, p[1], p[2], BOLT)
  end

  -- Output chute (right side)
  H.rect(img, 27, 13, 30, 18, C.panel_inner)
  H.line(img, 27, 12, 27, 19, C.rim)
end

local function draw_top(img, tag, phase)
  local cx, cy = 15, 15

  -- Drill bit (cross/X shape, mk2 has thicker arms)
  local function draw_bit(rot)
    local arms = {
      {{0,-1},{0,-2},{0,-3},{0,-4},{0,-5},{0,-6},{1,-3},{1,-4},{1,-5}},
      {{0,1},{0,2},{0,3},{0,4},{0,5},{0,6},{-1,3},{-1,4},{-1,5}},
      {{-1,0},{-2,0},{-3,0},{-4,0},{-5,0},{-6,0},{-3,-1},{-4,-1},{-5,-1}},
      {{1,0},{2,0},{3,0},{4,0},{5,0},{6,0},{3,1},{4,1},{5,1}},
    }
    local diag_arms = {
      {{-1,-1},{-2,-2},{-3,-3},{-4,-4},{-2,-1},{-3,-2}},
      {{1,-1},{2,-2},{3,-3},{4,-4},{2,-1},{3,-2}},
      {{-1,1},{-2,2},{-3,3},{-4,4},{-2,1},{-3,2}},
      {{1,1},{2,2},{3,3},{4,4},{2,1},{3,2}},
    }
    local use_arms = (rot % 2 == 0) and arms or diag_arms
    for _, arm in ipairs(use_arms) do
      for _, p in ipairs(arm) do
        H.px(img, cx+p[1], cy+p[2], BIT)
      end
    end
    -- Center hub (slightly larger for mk2)
    H.circle(img, cx, cy, 3, STEEL)
    H.circle(img, cx, cy, 1, STEEL_LT)
    H.px(img, cx, cy, BOLT)
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

  -- Bore rim
  H.circle_outline(img, cx, cy, 9, C.rim)

  -- Reinforced housing frame corners (thicker)
  for _, p in ipairs({{5,5},{26,5},{5,26},{26,26}}) do
    H.px(img, p[1], p[2], REINF)
    H.px(img, p[1]+1, p[2], REINF)
    H.px(img, p[1], p[2]+1, REINF)
  end
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr, DIR, "main")
print("[drill_mk2] done")
