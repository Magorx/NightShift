-- generate_conveyor.lua — Isometric conveyor belt atlas (flat surface, depth via shading)
-- Grid: 4 columns (anim frames) x 6 rows (variants)
-- Cell: 64x32 pixels (isometric diamond)
-- Total: 256x192 px
--
-- Rows: straight, turn, dual_side_input, side_input, crossroad, start
-- Animation: belt ridges slide along movement direction across 4 frames

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")

-- Colors
local BELT_DARK    = H.hex("#44444C")
local BELT_MID     = H.hex("#515158")
local BELT_LIGHT   = H.hex("#5E5E66")
local EDGE_OUTER   = H.hex("#2E2E32")
local EDGE_RAIL    = H.hex("#3A3A3E")
local EDGE_HI      = H.hex("#50505A")
local RIDGE_DIM    = H.hex("#C8A028")
local RIDGE_BRT    = H.hex("#E8C040")
local ROLLER_COL   = H.hex("#72727A")
local ROLLER_DARK  = H.hex("#585860")
local RAIL_INNER   = H.hex("#38383E")
local TRANS        = H.TRANSPARENT

-- Dimensions
local CW, CH = 64, 32
local COLS, ROWS = 4, 6
local W, HTOT = CW * COLS, CH * ROWS

-- Diamond center in local coords
local CX, CY = 31.5, 15.5
local HX, HY = 31, 15

-- ═══════════════════════════════════════════════════════════════════════════
-- DIAMOND GEOMETRY
-- ═══════════════════════════════════════════════════════════════════════════

-- Signed distance from diamond center, normalized so edge = 0, inside > 0
local function diamond_sdf(px, py)
  local dx = math.abs(px - CX) / (HX + 0.5)
  local dy = math.abs(py - CY) / (HY + 0.5)
  return 1.0 - dx - dy
end

-- Classify pixel into zones: outside, outline, rail, surface
local function classify(px, py)
  local d = diamond_sdf(px, py)
  if d < 0 then return "outside", d end
  if d < 0.06 then return "outline", d end
  if d < 0.14 then return "rail", d end
  return "surface", d
end

-- ═══════════════════════════════════════════════════════════════════════════
-- BASE TILE DRAWING (flat surface, depth via shading)
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_base_tile(img, ox, oy)
  for y = 0, CH - 1 do
    for x = 0, CW - 1 do
      local zone, d = classify(x, y)
      if zone == "outline" then
        if y <= CY then
          H.px(img, ox + x, oy + y, EDGE_HI)
        else
          H.px(img, ox + x, oy + y, EDGE_OUTER)
        end
      elseif zone == "rail" then
        H.px(img, ox + x, oy + y, EDGE_RAIL)
      elseif zone == "surface" then
        local t = y / (CH - 1)
        local c = H.lerp_color(BELT_MID, BELT_DARK, t)
        H.px(img, ox + x, oy + y, c)
      end
    end
  end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ROLLERS: mechanical components along the rail edges
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_rollers(img, ox, oy)
  -- Place rollers along each of the 4 edges of the diamond
  local corners = {
    {CX, CY - HY + 2},    -- top
    {CX + HX - 2, CY},    -- right
    {CX, CY + HY - 2},    -- bottom
    {CX - HX + 2, CY},    -- left
  }

  local edges = {{1,2},{2,3},{3,4},{4,1}}
  for ei, e in ipairs(edges) do
    local ax, ay = corners[e[1]][1], corners[e[1]][2]
    local bx, by = corners[e[2]][1], corners[e[2]][2]
    local num_rollers = 3
    for i = 1, num_rollers do
      local t = i / (num_rollers + 1)
      local rx = math.floor(ax + (bx - ax) * t + 0.5)
      local ry = math.floor(ay + (by - ay) * t + 0.5)
      -- Offset inward toward surface center
      local inx = 0
      local iny = 0
      if rx > CX + 2 then inx = -1 elseif rx < CX - 2 then inx = 1 end
      if ry > CY + 1 then iny = -1 elseif ry < CY - 1 then iny = 1 end
      local rpx = rx + inx
      local rpy = ry + iny
      -- Only draw if within bounds
      if rpx >= 0 and rpx < CW and rpy >= 0 and rpy < CH then
        -- Roller: bright center with dark sides
        H.px(img, ox + rpx, oy + rpy, ROLLER_COL)
        H.px(img, ox + rpx - 1, oy + rpy, ROLLER_DARK)
        H.px(img, ox + rpx + 1, oy + rpy, ROLLER_DARK)
      end
    end
  end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- RIDGE PATTERNS PER VARIANT
-- ═══════════════════════════════════════════════════════════════════════════

-- Movement direction in pixel space: grid +X = screen down-right = (2, 1) in iso
local MX, MY = 0.894, 0.447

local RIDGE_SPACING = 7
local RIDGE_WIDTH = 2.0  -- slightly wider for visibility

-- Check if pixel is on the belt surface
local function is_surface(px, py)
  local zone = classify(px, py)
  return zone == "surface"
end

-- Project pixel onto movement axis (relative to diamond center)
local function proj_move(px, py)
  return (px - CX) * MX + (py - CY) * MY
end

-- ROW 0: STRAIGHT
local function draw_straight(img, ox, oy, phase)
  local shift = phase * (RIDGE_SPACING / 4)
  for y = 0, CH - 1 do
    for x = 0, CW - 1 do
      if is_surface(x, y) then
        local p = proj_move(x, y) + shift
        local m = p % RIDGE_SPACING
        if m < 0 then m = m + RIDGE_SPACING end
        if m < RIDGE_WIDTH then
          local bright = (math.floor(p / RIDGE_SPACING) % 2 == 0)
          H.px(img, ox + x, oy + y, bright and RIDGE_BRT or RIDGE_DIM)
        end
      end
    end
  end
end

-- ROW 1: TURN (from grid-left entry to grid-down exit)
local function draw_turn(img, ox, oy, phase)
  local pvx, pvy = 6, CY  -- pivot near left corner
  local shift = phase * (math.pi / 2 / 4)

  for y = 0, CH - 1 do
    for x = 0, CW - 1 do
      if is_surface(x, y) then
        local dx = x - pvx
        local dy = (y - pvy) * 2
        local dist = math.sqrt(dx * dx + dy * dy)
        local p = dist + shift * 12
        local m = p % RIDGE_SPACING
        if m < 0 then m = m + RIDGE_SPACING end
        if m < RIDGE_WIDTH then
          local bright = (math.floor(p / RIDGE_SPACING) % 2 == 0)
          H.px(img, ox + x, oy + y, bright and RIDGE_BRT or RIDGE_DIM)
        end
      end
    end
  end
end

-- ROW 2: DUAL SIDE INPUT (T-junction: left + right merge to forward)
local function draw_dual_side(img, ox, oy, phase)
  local shift = phase * (RIDGE_SPACING / 4)

  for y = 0, CH - 1 do
    for x = 0, CW - 1 do
      if is_surface(x, y) then
        local dx = x - CX
        local dy = y - CY
        local proj_fwd = proj_move(x, y)

        if proj_fwd > 2 then
          local p = proj_fwd + shift
          local m = p % RIDGE_SPACING
          if m < 0 then m = m + RIDGE_SPACING end
          if m < RIDGE_WIDTH then
            local bright = (math.floor(p / RIDGE_SPACING) % 2 == 0)
            H.px(img, ox + x, oy + y, bright and RIDGE_BRT or RIDGE_DIM)
          end
        else
          local dist_to_center = math.abs(dx) * 0.6 + math.abs(dy) * 0.3
          local p = dist_to_center - shift
          local m = p % 6
          if m < 0 then m = m + 6 end
          if m < RIDGE_WIDTH then
            H.px(img, ox + x, oy + y, RIDGE_DIM)
          end
        end

        -- Center divider line
        if math.abs(proj_fwd) < 1 and math.abs(dx) < 16 then
          H.px(img, ox + x, oy + y, RAIL_INNER)
        end
      end
    end
  end
end

-- ROW 3: SIDE INPUT (right side merge with straight path)
local function draw_side_input(img, ox, oy, phase)
  local shift = phase * (RIDGE_SPACING / 4)

  for y = 0, CH - 1 do
    for x = 0, CW - 1 do
      if is_surface(x, y) then
        local p = proj_move(x, y) + shift
        local m = p % RIDGE_SPACING
        if m < 0 then m = m + RIDGE_SPACING end

        local dx = x - CX
        local dy = y - CY
        local in_merge_zone = (dx > 0 and dy < -2)

        if in_merge_zone then
          local merge_proj = -dx * 0.447 + dy * 0.894
          local mp = merge_proj + shift
          local mm = mp % 6
          if mm < 0 then mm = mm + 6 end
          if mm < RIDGE_WIDTH then
            H.px(img, ox + x, oy + y, RIDGE_DIM)
          elseif m < RIDGE_WIDTH then
            H.px(img, ox + x, oy + y, H.brighten(RIDGE_DIM, 0.7))
          end
        else
          if m < RIDGE_WIDTH then
            local bright = (math.floor(p / RIDGE_SPACING) % 2 == 0)
            H.px(img, ox + x, oy + y, bright and RIDGE_BRT or RIDGE_DIM)
          end
        end
      end
    end
  end

  -- Merge seam line
  for y = 0, CH - 1 do
    for x = 0, CW - 1 do
      if is_surface(x, y) then
        local dx = x - CX
        local dy = y - CY
        if dx > 0 and math.abs(dy + dx * 0.5) < 1.0 and dy < 0 then
          H.px(img, ox + x, oy + y, RAIL_INNER)
        end
      end
    end
  end
end

-- ROW 4: CROSSROAD (3 inputs merge to 1 output)
local function draw_crossroad(img, ox, oy, phase)
  local shift = phase * (RIDGE_SPACING / 4)

  for y = 0, CH - 1 do
    for x = 0, CW - 1 do
      if is_surface(x, y) then
        local dx = x - CX
        local dy = y - CY
        local proj_fwd = proj_move(x, y)

        if proj_fwd > 3 then
          local p = proj_fwd + shift
          local m = p % RIDGE_SPACING
          if m < 0 then m = m + RIDGE_SPACING end
          if m < RIDGE_WIDTH then
            local bright = (math.floor(p / RIDGE_SPACING) % 2 == 0)
            H.px(img, ox + x, oy + y, bright and RIDGE_BRT or RIDGE_DIM)
          end
        else
          local dist = math.sqrt(dx * dx + (dy * 2) * (dy * 2))
          local p = dist - shift
          local m = p % 6
          if m < 0 then m = m + 6 end
          if m < RIDGE_WIDTH then
            H.px(img, ox + x, oy + y, RIDGE_DIM)
          end
        end
      end
    end
  end

  -- Cross divider lines
  for y = 0, CH - 1 do
    for x = 0, CW - 1 do
      if is_surface(x, y) then
        local dx = x - CX
        local dy = y - CY
        local proj_fwd = proj_move(x, y)
        if proj_fwd <= 3 then
          local perp_proj = -dx * MY + dy * MX
          if math.abs(perp_proj) < 0.8 and proj_fwd < -2 then
            H.px(img, ox + x, oy + y, RAIL_INNER)
          end
          if math.abs(dx + dy * 0.5) < 0.8 and dy < 0 and proj_fwd <= 3 then
            H.px(img, ox + x, oy + y, RAIL_INNER)
          end
          if math.abs(dx - dy * 0.5) < 0.8 and dy > 0 and proj_fwd <= 3 then
            H.px(img, ox + x, oy + y, RAIL_INNER)
          end
        end
      end
    end
  end
end

-- ROW 5: START (no back input, forward from middle)
local function draw_start(img, ox, oy, phase)
  local shift = phase * (RIDGE_SPACING / 4)

  for y = 0, CH - 1 do
    for x = 0, CW - 1 do
      if is_surface(x, y) then
        local proj_fwd = proj_move(x, y)

        if proj_fwd > -2 then
          local p = proj_fwd + shift
          local m = p % RIDGE_SPACING
          if m < 0 then m = m + RIDGE_SPACING end
          if m < RIDGE_WIDTH then
            local intensity = math.min(1.0, (proj_fwd + 2) / 8)
            local bright = (math.floor(p / RIDGE_SPACING) % 2 == 0)
            local base_c = bright and RIDGE_BRT or RIDGE_DIM
            local c = H.lerp_color(BELT_MID, base_c, intensity)
            H.px(img, ox + x, oy + y, c)
          end
        end
      end
    end
  end

  -- Start cap
  for y = 0, CH - 1 do
    for x = 0, CW - 1 do
      if is_surface(x, y) then
        local proj_fwd = proj_move(x, y)
        if math.abs(proj_fwd + 2) < 1.0 then
          H.px(img, ox + x, oy + y, EDGE_HI)
        end
        if math.abs(proj_fwd + 2) < 0.5 then
          H.px(img, ox + x, oy + y, ROLLER_COL)
        end
      end
    end
  end

  -- Forward arrow
  local acx, acy = 38, CY + 3
  H.px(img, ox + acx, oy + acy, RIDGE_BRT)
  H.px(img, ox + acx - 1, oy + acy - 1, RIDGE_BRT)
  H.px(img, ox + acx - 1, oy + acy + 1, RIDGE_BRT)
  H.px(img, ox + acx - 2, oy + acy - 2, RIDGE_DIM)
  H.px(img, ox + acx - 2, oy + acy + 2, RIDGE_DIM)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MAIN: Generate the atlas
-- ═══════════════════════════════════════════════════════════════════════════

local spr = Sprite(W, HTOT, ColorMode.RGB)
app.activeSprite = spr
local img = spr.cels[1].image
H.clear(img)

local variant_fn = {
  [0] = draw_straight,
  [1] = draw_turn,
  [2] = draw_dual_side,
  [3] = draw_side_input,
  [4] = draw_crossroad,
  [5] = draw_start,
}

for row = 0, ROWS - 1 do
  for col = 0, COLS - 1 do
    local ox = col * CW
    local oy = row * CH

    -- Base tile (edges, rails, belt surface)
    draw_base_tile(img, ox, oy)

    -- Rollers along diamond edges
    draw_rollers(img, ox, oy)

    -- Variant-specific ridges
    local fn = variant_fn[row]
    if fn then
      fn(img, ox, oy, col)
    end
  end
end

-- Export
local out_path = "/Users/gorishniymax/Repos/factor/buildings/conveyor/sprites/straight.png"
spr:saveCopyAs(out_path)
print("Saved: " .. out_path)
spr:close()
