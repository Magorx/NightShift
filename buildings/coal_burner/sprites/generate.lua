-- coal_burner_sprite.lua
-- Top-down coal burner: sooty dark identity, grate bars over fire pit.
-- 2x1 tiles (64x32 per frame), 2 layers, 6 frames (2 idle + 4 active).

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, FH = 64, 32
local LAYERS = {"base", "top"}
local TAGS = {
  {name="idle",   from=1, to=2, duration=0.5},
  {name="active", from=3, to=6, duration=0.15},
}

-- Coal burner identity: sooty, dark, ember glow
local COAL     = H.hex("#1C1816")
local COAL_MID = H.hex("#282420")
local COAL_HI  = H.hex("#343028")
local SOOT     = C.soot

local function draw_base(img, tag, phase)
  -- overall outline
  H.rect_outline(img, 0, 0, 63, 31, C.outline)
  H.line(img, 31, 0, 31, 31, C.outline)

  -- LEFT TILE: coal hopper (top-down bin)
  H.rect(img, 1, 1, 30, 30, C.body)
  H.rect(img, 2, 2, 29, 29, SOOT)
  H.rect(img, 3, 3, 28, 28, COAL)
  -- coal chunk texture (2px wide blocks scattered)
  local chunks = {
    {5,5},{10,6},{15,4},{20,7},{25,5},
    {6,11},{12,10},{17,13},{22,11},{27,12},
    {4,17},{9,16},{16,18},{21,17},{26,19},
    {7,23},{13,22},{18,24},{23,23},{27,21},
    {5,27},{11,27},{17,26},{22,27},{26,26},
  }
  for _, p in ipairs(chunks) do
    H.px(img, p[1], p[2], COAL_MID)
    H.px(img, p[1]+1, p[2], COAL_MID)
  end
  -- bright specks on coal
  for _, p in ipairs({{8,8},{19,15},{25,23},{12,20},{6,14}}) do
    H.px(img, p[1], p[2], COAL_HI)
  end

  -- fuel chute connecting to combustion chamber (y 13-18)
  H.rect(img, 28, 13, 33, 18, C.panel_inner)
  H.line(img, 28, 12, 33, 12, C.body)
  H.line(img, 28, 19, 33, 19, C.body)

  -- RIGHT TILE: combustion chamber (top-down fire pit)
  H.rect(img, 32, 1, 62, 30, C.body)
  H.rect(img, 33, 2, 61, 29, C.panel)
  -- corner rivets
  for _, p in ipairs({{34,3},{60,3},{34,28},{60,28}}) do
    H.px(img, p[1], p[2], C.rivet)
  end

  -- round fire pit (center 47,15)
  local cx, cy = 47, 15
  H.circle(img, cx, cy, 12, C.rim)
  H.circle(img, cx, cy, 11, C.chamber)

  if tag == "active" then
    -- layered fire glow with per-frame flicker
    H.circle(img, cx, cy, 10, C.fire_dim)
    H.circle(img, cx, cy, 8, C.ember)
    local sh = {{-1,0},{1,0},{0,-1},{0,1}}
    local s = sh[(phase % 4) + 1]
    H.circle(img, cx + s[1], cy + s[2], 6, C.fire_outer)
    H.circle(img, cx - s[1], cy - s[2], 4, C.fire_mid)
    H.circle(img, cx + s[2], cy + s[1], 2, C.fire_inner)
    if phase >= 2 then H.px(img, cx, cy, C.fire_core) end
    H.circle_outline(img, cx, cy, 11, C.glow_wall)
  else
    -- idle: dim embers scattered in dark chamber
    H.circle(img, cx, cy, 10, C.chamber_deep)
    local em = phase == 0
      and {{cx-3,cy-2},{cx+4,cy+3},{cx+1,cy-5},{cx-5,cy+1}}
      or  {{cx+3,cy-3},{cx-4,cy+2},{cx-1,cy+5},{cx+5,cy-1}}
    for _, p in ipairs(em) do H.px(img, p[1], p[2], C.ember) end
    H.px(img, cx + (phase == 0 and -1 or 1), cy, C.fire_dim)
  end
end

local function draw_top(img, tag, phase)
  local cx, cy = 47, 15

  -- grate bars over fire pit (coal burner signature)
  local R = 10
  -- horizontal bars every 4px
  for _, yo in ipairs({-8, -4, 0, 4, 8}) do
    for x = cx - R, cx + R do
      if (x - cx) * (x - cx) + yo * yo <= R * R then
        H.px(img, x, cy + yo, C.grate)
      end
    end
  end
  -- vertical center bar
  for y = cy - R, cy + R do
    if (y - cy) * (y - cy) <= R * R then
      H.px(img, cx, y, C.grate)
    end
  end

  -- chimney cap (top-right of right tile)
  local chx, chy = 57, 6
  H.circle(img, chx, chy, 3, C.shadow)
  H.circle_outline(img, chx, chy, 3, C.rim)
  H.px(img, chx, chy, C.chamber_deep)

  -- smoke wisps (active only)
  if tag == "active" then
    local offsets = {{-1,-1},{1,-1},{0,-1},{-1,0}}
    local o = offsets[(phase % 4) + 1]
    H.px(img, chx + o[1], chy - 3 + o[2], C.smoke_dark)
    H.px(img, chx - o[1], chy - 4, C.smoke_mid)
  end

  -- hopper corner bolts
  for _, p in ipairs({{2,2},{29,2},{2,29},{29,29}}) do
    H.px(img, p[1], p[2], C.rivet)
  end
end

-- render & export
local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then draw_base(img, tag, phase)
  else draw_top(img, tag, phase) end
end)
H.save_and_export(spr,
  "/Users/gorishniymax/Repos/factor/buildings/coal_burner/sprites", "main")
print("[coal_burner] done")
