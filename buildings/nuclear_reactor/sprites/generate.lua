-- Generate Nuclear Reactor sprites (3x3 bbox = 96x96 pixels, plus/cross shaped)
-- Cells occupied: (1,0)(0,1)(1,1)(2,1)(1,2)
-- Non-occupied corners (0,0)(2,0)(0,2)(2,2) are transparent
-- 2 layers (base, top), tags: idle(2f), windup(2f), active(4f), winddown(2f)

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, HH = 96, 96
local CELL = 32

local tags = {
  {name="idle",     from=1, to=2,  duration=0.5},
  {name="windup",   from=3, to=4,  duration=0.167},
  {name="active",   from=5, to=8,  duration=0.167},
  {name="winddown", from=9, to=10, duration=0.167},
}

local spr, layers = H.new_sprite(W, HH, {"base", "top"}, tags)

-- Occupied cells: (1,0)(0,1)(1,1)(2,1)(1,2) — plus shape
local function in_shape(px, py)
  local cx = math.floor(px / CELL)
  local cy = math.floor(py / CELL)
  if cx == 1 then return true end  -- center column all 3
  if cy == 1 then return true end  -- middle row all 3
  return false
end

local function safe_rect(img, x1, y1, x2, y2, c)
  for y = math.max(0, y1), math.min(img.height - 1, y2) do
    for x = math.max(0, x1), math.min(img.width - 1, x2) do
      if in_shape(x, y) then img:drawPixel(x, y, c) end
    end
  end
end

local function safe_px(img, x, y, c)
  if x >= 0 and x < img.width and y >= 0 and y < img.height and in_shape(x, y) then
    img:drawPixel(x, y, c)
  end
end

local function safe_circle(img, cx, cy, r, c)
  for y = -r, r do
    for x = -r, r do
      if x * x + y * y <= r * r then
        safe_px(img, cx + x, cy + y, c)
      end
    end
  end
end

local function safe_circle_outline(img, cx, cy, r, c)
  local x, y = r, 0
  local err = 1 - r
  while x >= y do
    safe_px(img, cx + x, cy + y, c)
    safe_px(img, cx - x, cy + y, c)
    safe_px(img, cx + x, cy - y, c)
    safe_px(img, cx - x, cy - y, c)
    safe_px(img, cx + y, cy + x, c)
    safe_px(img, cx - y, cy + x, c)
    safe_px(img, cx + y, cy - x, c)
    safe_px(img, cx - y, cy - x, c)
    y = y + 1
    if err < 0 then
      err = err + 2 * y + 1
    else
      x = x - 1
      err = err + 2 * (y - x) + 1
    end
  end
end

-- Colors: nuclear green/gray
local body      = H.hex("#343C34")
local body_lt   = H.hex("#444C44")
local body_dk   = H.hex("#262E26")
local panel     = H.hex("#2C342C")
local panel_dk  = H.hex("#222A22")
local metal     = H.hex("#5A625A")
local metal_dk  = H.hex("#4A524A")
local contain   = H.hex("#3A4238")
local contain_dk = H.hex("#2A322A")
local contain_lt = H.hex("#4A5448")
local core      = H.hex("#1A2218")
local core_dk   = H.hex("#0E160C")
local rod       = H.hex("#4A6048")
local rod_lt    = H.hex("#5A7858")
local nuke_glow = H.hex("#66DD44")
local nuke_hot  = H.hex("#88FF66")
local nuke_dim  = H.hex("#3A6630")
local cool_blue = H.hex("#4488AA")
local cool_lt   = H.hex("#66AACC")
local dark      = H.hex("#101810")
local chamber   = H.hex("#0C140C")
local rivet     = H.hex("#5A5A50")
local glow_off  = H.hex("#2A3A28")

H.render_frames(spr, layers, tags, function(img, layer, fi, tag, phase)
  if layer == "base" then
    -- Top arm (1,0)
    H.shaded_rect(img, 33, 1, 62, 30, body, body_lt, body_dk)
    H.rect_outline(img, 32, 0, 63, 31, dark)

    -- Middle row (0,1)(1,1)(2,1)
    H.shaded_rect(img, 1, 33, 94, 62, body, body_lt, body_dk)
    H.rect_outline(img, 0, 32, 95, 63, dark)

    -- Bottom arm (1,2)
    H.shaded_rect(img, 33, 64, 62, 94, body, body_lt, body_dk)
    H.rect_outline(img, 32, 64, 63, 95, dark)

    -- Fix edge connections
    safe_px(img, 32, 31, dark)
    safe_px(img, 63, 31, dark)
    safe_px(img, 32, 63, dark)
    safe_px(img, 63, 63, dark)

    -- Containment vessel (center cell, large circle)
    safe_circle(img, 48, 48, 14, contain)
    safe_circle(img, 48, 48, 12, contain_dk)
    safe_circle(img, 48, 48, 8, core)
    safe_circle(img, 48, 48, 5, core_dk)

    -- Fuel rod slots (cross pattern in core)
    safe_rect(img, 46, 40, 50, 56, rod)
    safe_rect(img, 40, 46, 56, 50, rod)

    -- Cooling towers on arms
    -- Top arm cooling
    safe_rect(img, 40, 4, 56, 26, contain_dk)
    safe_rect(img, 42, 6, 54, 24, contain)
    safe_circle(img, 48, 15, 6, cool_blue)

    -- Left arm cooling
    safe_rect(img, 4, 40, 26, 56, contain_dk)
    safe_rect(img, 6, 42, 24, 54, contain)
    safe_circle(img, 15, 48, 6, cool_blue)

    -- Right arm cooling
    safe_rect(img, 70, 40, 92, 56, contain_dk)
    safe_rect(img, 72, 42, 90, 54, contain)
    safe_circle(img, 81, 48, 6, cool_blue)

    -- Bottom arm cooling
    safe_rect(img, 40, 70, 56, 92, contain_dk)
    safe_rect(img, 42, 72, 54, 90, contain)
    safe_circle(img, 48, 81, 6, cool_blue)

    -- IO openings
    safe_rect(img, 44, 0, 52, 3, chamber)    -- top
    safe_rect(img, 0, 44, 3, 52, chamber)    -- left
    safe_rect(img, 92, 44, 95, 52, chamber)  -- right
    safe_rect(img, 44, 92, 52, 95, chamber)  -- bottom

    -- Rivets
    safe_px(img, 34, 2, rivet)
    safe_px(img, 61, 2, rivet)
    safe_px(img, 2, 34, rivet)
    safe_px(img, 93, 34, rivet)
    safe_px(img, 2, 61, rivet)
    safe_px(img, 93, 61, rivet)
    safe_px(img, 34, 93, rivet)
    safe_px(img, 61, 93, rivet)

  elseif layer == "top" then
    -- Frame borders for each arm
    -- Top arm
    safe_rect(img, 32, 0, 63, 1, metal_dk)
    safe_rect(img, 32, 0, 33, 31, metal_dk)
    safe_rect(img, 62, 0, 63, 31, metal_dk)
    -- Middle row
    safe_rect(img, 0, 32, 95, 33, metal_dk)
    safe_rect(img, 0, 62, 95, 63, metal_dk)
    safe_rect(img, 0, 32, 1, 63, metal_dk)
    safe_rect(img, 94, 32, 95, 63, metal_dk)
    -- Bottom arm
    safe_rect(img, 32, 94, 63, 95, metal_dk)
    safe_rect(img, 32, 64, 33, 95, metal_dk)
    safe_rect(img, 62, 64, 63, 95, metal_dk)

    -- Containment dome (center)
    safe_circle(img, 48, 48, 13, contain_lt)
    safe_circle_outline(img, 48, 48, 13, metal_dk)
    safe_circle(img, 48, 48, 9, contain)
    safe_circle_outline(img, 48, 48, 9, contain_dk)

    -- Viewing port in center
    safe_circle(img, 48, 48, 4, core)

    -- Cooling tower caps on arms
    safe_circle(img, 48, 15, 5, contain_lt)
    safe_circle_outline(img, 48, 15, 5, metal_dk)
    safe_circle(img, 15, 48, 5, contain_lt)
    safe_circle_outline(img, 15, 48, 5, metal_dk)
    safe_circle(img, 81, 48, 5, contain_lt)
    safe_circle_outline(img, 81, 48, 5, metal_dk)
    safe_circle(img, 48, 81, 5, contain_lt)
    safe_circle_outline(img, 48, 81, 5, metal_dk)

    -- Cooling pipe connections from center to arms
    safe_rect(img, 36, 46, 40, 50, metal_dk)
    safe_rect(img, 56, 46, 60, 50, metal_dk)
    safe_rect(img, 46, 36, 50, 40, metal_dk)
    safe_rect(img, 46, 56, 50, 60, metal_dk)

    -- Gate openings
    safe_rect(img, 44, 0, 52, 1, chamber)
    safe_rect(img, 0, 44, 1, 52, chamber)
    safe_rect(img, 94, 44, 95, 52, chamber)
    safe_rect(img, 44, 94, 52, 95, chamber)

    -- Nuclear glow animation
    if tag == "idle" then
      safe_px(img, 48, 48, nuke_dim)
      local bob = phase == 0 and 0 or 0

    elseif tag == "windup" then
      local t = phase * 0.5
      safe_px(img, 48, 48, H.lerp_color(nuke_dim, nuke_glow, t))
      if phase == 1 then
        safe_px(img, 47, 47, nuke_dim)
        safe_px(img, 49, 49, nuke_dim)
      end

    elseif tag == "active" then
      -- Pulsing core glow
      safe_circle(img, 48, 48, 3, nuke_glow)
      if phase == 0 or phase == 2 then
        safe_px(img, 48, 48, nuke_hot)
        safe_px(img, 47, 48, nuke_glow)
        safe_px(img, 49, 48, nuke_glow)
        safe_px(img, 48, 47, nuke_glow)
        safe_px(img, 48, 49, nuke_glow)
      end
      if phase == 1 or phase == 3 then
        safe_circle(img, 48, 48, 2, nuke_hot)
      end

      -- Cooling tower activity (steam hint)
      local steam_offsets = {0, 1, 0, -1}
      local so = steam_offsets[phase + 1]
      safe_px(img, 48 + so, 12, cool_lt)
      safe_px(img, 12 + so, 48, cool_lt)
      safe_px(img, 81 + so, 45, cool_lt)
      safe_px(img, 45 + so, 81, cool_lt)

    elseif tag == "winddown" then
      local t = phase * 0.5
      safe_px(img, 48, 48, H.lerp_color(nuke_glow, nuke_dim, t))
      if phase == 0 then
        safe_px(img, 47, 47, nuke_dim)
      end
    end

    -- Rivets
    safe_px(img, 35, 3, rivet)
    safe_px(img, 60, 3, rivet)
    safe_px(img, 3, 35, rivet)
    safe_px(img, 92, 35, rivet)
    safe_px(img, 3, 60, rivet)
    safe_px(img, 92, 60, rivet)
    safe_px(img, 35, 92, rivet)
    safe_px(img, 60, 92, rivet)
  end
end)

local dir = "/Users/gorishniymax/Repos/factor/buildings/nuclear_reactor/sprites"
H.save_and_export(spr, dir, "main")
print("[nuclear_reactor] done")
