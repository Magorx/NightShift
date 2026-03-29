-- coke_oven_sprite.lua
-- Top-down coke oven: dark brick structure with interior glow.
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
local DIR = "/Users/gorishniymax/Repos/factor/buildings/coke_oven/sprites"

-- Coke oven identity: dark brick
local BRICK     = H.hex("#6B4030")
local BRICK_LT  = H.hex("#7B5040")
local BRICK_DK  = H.hex("#4A2A1A")
local MORTAR    = H.hex("#3A2818")
local INTERIOR  = H.hex("#1A1210")
local INTERIOR2 = H.hex("#120C08")

local function draw_base(img, tag, phase)
  -- Overall outline
  H.rect_outline(img, 0, 0, 31, 63, C.outline)
  H.line(img, 0, 32, 31, 32, C.outline)

  -- TOP TILE (0,0): input hopper
  H.rect(img, 1, 1, 30, 31, BRICK)
  H.shaded_rect(img, 2, 2, 29, 30, BRICK, BRICK_LT, BRICK_DK)

  -- Brick pattern on top tile
  for y = 3, 28, 4 do
    H.line(img, 2, y, 29, y, MORTAR)
    local off = (math.floor(y / 4) % 2 == 0) and 0 or 8
    for x = off + 2, 29, 16 do
      if x >= 2 and x <= 29 then
        H.line(img, x, y, x, y + 3, MORTAR)
      end
    end
  end

  -- Input opening (top tile center)
  H.bordered_rect(img, 8, 6, 23, 18, INTERIOR, BRICK_DK)
  H.rect(img, 9, 7, 22, 17, INTERIOR2)

  -- Coal inside hopper (idle/active detail)
  if tag ~= "idle" or phase == 0 then
    for _, p in ipairs({{11,9},{15,8},{19,10},{12,13},{17,12},{21,14}}) do
      H.px(img, p[1], p[2], C.coal)
    end
  end

  -- Corner bolts (top tile)
  for _, p in ipairs({{3,3},{28,3},{3,28},{28,28}}) do
    H.px(img, p[1], p[2], C.rivet)
  end

  -- BOTTOM TILE (0,1): combustion/output
  H.rect(img, 1, 33, 30, 62, BRICK)
  H.shaded_rect(img, 2, 33, 29, 61, BRICK, BRICK_LT, BRICK_DK)

  -- Brick pattern on bottom tile
  for y = 35, 60, 4 do
    H.line(img, 2, y, 29, y, MORTAR)
    local off = (math.floor(y / 4) % 2 == 0) and 0 or 8
    for x = off + 2, 29, 16 do
      if x >= 2 and x <= 29 then
        H.line(img, x, y, x, y + 3, MORTAR)
      end
    end
  end

  -- Oven chamber (bottom tile)
  local cx, cy = 15, 47
  H.circle(img, cx, cy, 10, C.rim)
  H.circle(img, cx, cy, 9, C.chamber)

  if tag == "active" then
    H.circle(img, cx, cy, 8, C.fire_dim)
    H.circle(img, cx, cy, 6, C.ember)
    local sh = {{-1,0},{1,0},{0,-1},{0,1}}
    local s = sh[(phase % 4) + 1]
    H.circle(img, cx + s[1], cy + s[2], 4, C.fire_outer)
    H.circle(img, cx - s[1], cy - s[2], 2, C.fire_mid)
    if phase >= 2 then H.px(img, cx, cy, C.fire_inner) end
    H.circle_outline(img, cx, cy, 9, C.glow_wall)
  elseif tag == "windup" then
    H.circle(img, cx, cy, 8, C.chamber_deep)
    if phase == 0 then
      H.px(img, cx - 2, cy, C.ember)
      H.px(img, cx + 2, cy + 1, C.ember)
    else
      H.circle(img, cx, cy, 3, C.fire_dim)
      H.circle(img, cx, cy, 1, C.ember)
    end
  elseif tag == "winddown" then
    if phase == 0 then
      H.circle(img, cx, cy, 8, C.fire_dim)
      H.circle(img, cx, cy, 4, C.ember)
    else
      H.circle(img, cx, cy, 8, C.chamber_deep)
      H.px(img, cx - 2, cy, C.ember)
      H.px(img, cx + 3, cy + 1, C.ember)
    end
  else
    -- idle: faint embers
    H.circle(img, cx, cy, 8, C.chamber_deep)
    local em = phase == 0
      and {{cx-3,cy-2},{cx+3,cy+2},{cx+1,cy-4}}
      or  {{cx+2,cy-3},{cx-3,cy+1},{cx-1,cy+4}}
    for _, p in ipairs(em) do H.px(img, p[1], p[2], C.ember) end
  end

  -- Output chute at bottom edge
  H.rect(img, 12, 58, 19, 63, C.panel_inner)
  H.line(img, 11, 58, 11, 63, BRICK_DK)
  H.line(img, 20, 58, 20, 63, BRICK_DK)

  -- Corner bolts (bottom tile)
  for _, p in ipairs({{3,35},{28,35},{3,60},{28,60}}) do
    H.px(img, p[1], p[2], C.rivet)
  end
end

local function draw_top(img, tag, phase)
  -- Grate bars over oven chamber
  local cx, cy = 15, 47
  local R = 8
  for _, yo in ipairs({-6, -3, 0, 3, 6}) do
    for x = cx - R, cx + R do
      if (x - cx) * (x - cx) + yo * yo <= R * R then
        H.px(img, x, cy + yo, C.grate)
      end
    end
  end

  -- Chimney cap (top-right of bottom tile)
  local chx, chy = 26, 36
  H.circle(img, chx, chy, 2, C.shadow)
  H.circle_outline(img, chx, chy, 2, C.rim)
  H.px(img, chx, chy, C.chamber_deep)

  -- Smoke from chimney when active
  if tag == "active" or tag == "windup" then
    local offsets = {{-1,-1},{1,-1},{0,-1},{-1,0}}
    local o = offsets[(phase % 4) + 1]
    H.px(img, chx + o[1], chy - 3 + o[2], C.smoke_dark)
    if tag == "active" then
      H.px(img, chx - o[1], chy - 4, C.smoke_mid)
    end
  end

  -- Hopper rim highlight
  H.rect_outline(img, 8, 6, 23, 18, BRICK_LT)

  -- Output arrow at bottom
  H.px(img, 15, 60, C.conv_yellow)
  H.px(img, 16, 60, C.conv_yellow)
  H.px(img, 15, 61, C.conv_yellow)
  H.px(img, 16, 61, C.conv_yellow)
end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr, DIR, "main")
print("[coke_oven] done")
