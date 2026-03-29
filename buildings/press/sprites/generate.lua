-- press_sprite.lua
-- Top-down press: heavy stamping machine with flat pressing surface.
-- 2x1 tiles (64x32 per frame), 2 layers, 10 frames:
-- idle(2) + windup(2) + active(4) + winddown(2).

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, FH = 64, 32
local LAYERS = {"base", "top"}
local TAGS = {
  {name="idle",     from=1, to=2, duration=0.5},
  {name="windup",   from=3, to=4, duration=0.15},
  {name="active",   from=5, to=8, duration=0.15},
  {name="winddown", from=9, to=10, duration=0.15},
}

-- Press identity: heavy iron, dark metallic
local IRON      = H.hex("#808088")
local IRON_DK   = H.hex("#606068")
local IRON_DD   = H.hex("#505058")
local IRON_LT   = H.hex("#909098")
local STEEL     = H.hex("#707078")
local PISTON    = H.hex("#585860")
local STAMP_TOP = H.hex("#9898A0")

local function draw_base(img, tag, phase)
  -- overall outline
  H.rect_outline(img, 0, 0, 63, 31, C.outline)
  H.line(img, 31, 0, 31, 31, C.outline)

  -- LEFT TILE: intake/feed area
  H.rect(img, 1, 1, 30, 30, IRON_DK)
  H.rect(img, 2, 2, 29, 29, IRON_DD)

  -- Feed conveyor rails
  H.rect(img, 3, 6, 28, 8, C.panel_inner)
  H.rect(img, 3, 23, 28, 25, C.panel_inner)
  -- Feed bed
  H.rect(img, 3, 9, 28, 22, C.panel)
  -- Roller marks
  for x = 5, 27, 4 do
    H.line(img, x, 9, x, 22, IRON_DD)
  end

  -- Feed chute to press
  H.rect(img, 26, 11, 33, 20, C.panel_inner)
  H.line(img, 26, 10, 33, 10, IRON_DK)
  H.line(img, 26, 21, 33, 21, IRON_DK)

  -- RIGHT TILE: press chamber
  H.rect(img, 32, 1, 62, 30, IRON_DK)
  H.rect(img, 33, 2, 61, 29, C.panel)

  -- Press bed (anvil surface)
  H.rect(img, 36, 8, 58, 23, IRON_DD)
  H.rect(img, 37, 9, 57, 22, STEEL)

  -- Anvil surface markings
  H.rect(img, 40, 12, 54, 19, IRON)
  -- Impact marks in active state
  if tag == "active" then
    local cx, cy = 47, 15
    local sh = {{-1,0},{1,0},{0,-1},{0,1}}
    local s = sh[(phase % 4) + 1]
    H.px(img, cx + s[1], cy + s[2], IRON_LT)
    H.px(img, cx - s[1], cy - s[2], IRON_LT)
    H.px(img, cx, cy, STAMP_TOP)
    -- Sparks
    H.px(img, cx + s[1]*3, cy + s[2]*2, C.fire_inner)
    H.px(img, cx - s[1]*2, cy - s[2]*3, C.fire_mid)
  elseif tag == "windup" then
    -- Material placed
    H.rect(img, 44, 13, 50, 18, C.iron_ore)
  elseif tag == "winddown" then
    if phase == 0 then
      -- Just stamped, cooling
      H.px(img, 47, 15, C.fire_dim)
      H.px(img, 46, 16, C.ember)
    end
  end

  -- Corner bolts
  for _, p in ipairs({{34,3},{60,3},{34,28},{60,28}}) do
    H.px(img, p[1], p[2], C.rivet)
  end
end

local function draw_top(img, tag, phase)
  -- Press ram/stamp head (top-down view of the pressing mechanism)
  local cx, cy = 47, 15

  -- Hydraulic frame (two vertical pillars)
  H.rect(img, 35, 3, 38, 28, IRON_DK)
  H.rect(img, 56, 3, 59, 28, IRON_DK)
  -- Cross beam at top
  H.rect(img, 35, 3, 59, 6, IRON_DK)
  H.rect(img, 36, 4, 58, 5, STEEL)

  -- Piston cylinders
  H.rect(img, 39, 7, 42, 24, PISTON)
  H.rect(img, 52, 7, 55, 24, PISTON)
  H.px(img, 40, 8, IRON_LT)
  H.px(img, 53, 8, IRON_LT)

  -- Central stamp head
  if tag == "active" then
    -- Stamp down (large, fills press area)
    H.rect(img, 41, 10, 53, 21, IRON)
    H.rect(img, 42, 11, 52, 20, STAMP_TOP)
    H.rect(img, 44, 13, 50, 18, IRON_LT)
    -- Impact ring
    H.rect_outline(img, 43, 12, 51, 19, IRON_DK)
  elseif tag == "windup" then
    -- Stamp raised (smaller shadow)
    if phase == 0 then
      H.rect(img, 43, 12, 51, 19, IRON)
      H.rect(img, 44, 13, 50, 18, IRON_DK)
    else
      -- Coming down
      H.rect(img, 42, 11, 52, 20, IRON)
      H.rect(img, 43, 12, 51, 19, STAMP_TOP)
    end
  elseif tag == "winddown" then
    if phase == 0 then
      -- Retracting
      H.rect(img, 42, 11, 52, 20, IRON)
      H.rect(img, 43, 12, 51, 19, IRON_DK)
    else
      -- Fully retracted
      H.rect(img, 43, 12, 51, 19, IRON)
      H.rect(img, 44, 13, 50, 18, IRON_DK)
    end
  else
    -- Idle: stamp head resting high
    H.rect(img, 43, 12, 51, 19, IRON)
    H.rect(img, 44, 13, 50, 18, IRON_DK)
    -- Subtle idle animation
    if phase == 1 then
      H.px(img, 47, 15, STEEL)
    end
  end

  -- Gauge on left tile
  H.circle(img, 15, 15, 4, C.panel_inner)
  H.circle_outline(img, 15, 15, 4, IRON_DK)
  H.px(img, 15, 15, C.rivet)
  -- Gauge needle
  if tag == "active" then
    H.px(img, 15, 12, C.warning_red)
  else
    H.px(img, 14, 13, C.active_green)
  end

  -- Left tile frame bolts
  for _, p in ipairs({{2,2},{29,2},{2,29},{29,29}}) do
    H.px(img, p[1], p[2], C.rivet)
  end
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr,
  "/Users/gorishniymax/Repos/factor/buildings/press/sprites", "main")
print("[press] done")
