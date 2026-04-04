-- generate.lua -- Drill/Extractor building sprite
-- 64x72 canvas: 16px derrick above roof + 32px roof diamond + 24px walls
-- 2 layers (base, top), 10 frames:
-- idle(2) + windup(2) + active(4) + winddown(2)
--
-- The building body uses warm BROWN palette (body, body_light, panel).
-- Steel blue-gray is accent only (derrick mechanism, bore rim, bolts).

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local Box = dofile("/Users/gorishniymax/Repos/factor/tools/iso_box.lua")
local C = H.load_palette("buildings")

local W, FH = 64, 72
local OY = 16  -- vertical offset: box geometry starts 16px down
local WALL_H = 24
local box = Box.new(WALL_H)

local LAYERS = {"base", "top"}
local TAGS = {
  {name="idle",     from=1, to=2,  duration=0.5},
  {name="windup",   from=3, to=4,  duration=0.15},
  {name="active",   from=5, to=8,  duration=0.15},
  {name="winddown", from=9, to=10, duration=0.15},
}
local DIR = "/Users/gorishniymax/Repos/factor/buildings/drill/sprites"

-- Accent colors: steel for mechanical parts ONLY
local STEEL     = H.hex("#6A7080")
local STEEL_DK  = H.hex("#5E6878")
local STEEL_LT  = H.hex("#7A8898")
local BIT       = H.hex("#8090A0")
local BIT_DK    = H.hex("#607080")

-- Palette shortcuts (C values are already converted by load_palette)
local outline   = C.outline
local body      = C.body
local body_lt   = C.body_light
local panel     = C.panel
local panel_in  = C.panel_inner
local rivet_c   = C.rivet
local rim_c     = C.rim
local pipe_c    = C.pipe
local pipe_in   = C.pipe_inner
local chamber   = C.chamber
local chamber_d = C.chamber_deep
local bore_c    = C.bore
local bore_d    = C.bore_deep
local shadow_c  = C.shadow
local grate_c   = C.grate
local intake_c  = C.intake
local intake_dk = C.intake_dark

-- =========================================================================
-- HELPERS
-- =========================================================================

-- Check box geometry with Y offset
local function in_roof(x, y) return Box.in_roof(box, x, y - OY) end
local function in_left(x, y) return Box.in_left_wall(box, x, y - OY) end
local function in_right(x, y) return Box.in_right_wall(box, x, y - OY) end
local function roof_sdf(x, y) return Box.roof_sdf(box, x, y - OY) end
local function is_roof_outline(x, y) return Box.is_roof_outline(box, x, y - OY) end
local function is_left_outline(x, y) return Box.is_left_wall_outline(box, x, y - OY) end
local function is_right_outline(x, y) return Box.is_right_wall_outline(box, x, y - OY) end
local function left_top_y(px) return Box.left_wall_top_y(box, px) + OY end
local function right_top_y(px) return Box.right_wall_top_y(box, px) + OY end

local function iso_ellipse(img, cx, cy, rx, ry, c)
  for y = cy - ry, cy + ry do
    for x = cx - rx, cx + rx do
      local dx = (x - cx) / rx
      local dy = (y - cy) / ry
      if dx * dx + dy * dy <= 1.0 then
        H.px(img, x, y, c)
      end
    end
  end
end

local function iso_ellipse_outline(img, cx, cy, rx, ry, c, thickness)
  thickness = thickness or 0.35
  local inner = 1.0 - thickness
  for y = cy - ry, cy + ry do
    for x = cx - rx, cx + rx do
      local dx = (x - cx) / rx
      local dy = (y - cy) / ry
      local dist = dx * dx + dy * dy
      if dist <= 1.0 and dist > inner then
        H.px(img, x, y, c)
      end
    end
  end
end

-- =========================================================================
-- DRAW BOX STRUCTURE (brown body with offset)
-- =========================================================================

local function draw_box_structure(img)
  -- Pass 1: fill faces
  for y = 0, FH - 1 do
    for x = 0, W - 1 do
      if in_roof(x, y) then
        img:drawPixel(x, y, panel)
      elseif in_left(x, y) then
        img:drawPixel(x, y, body)
      elseif in_right(x, y) then
        img:drawPixel(x, y, body_lt)
      end
    end
  end

  -- Pass 2: outlines
  for y = 0, FH - 1 do
    for x = 0, W - 1 do
      if is_roof_outline(x, y) then
        img:drawPixel(x, y, outline)
      elseif is_left_outline(x, y) then
        img:drawPixel(x, y, outline)
      elseif is_right_outline(x, y) then
        img:drawPixel(x, y, outline)
      end
    end
  end
end

-- =========================================================================
-- ROOF DETAILS
-- =========================================================================

-- Bore hole position (centered on roof diamond, offset by OY)
local BORE_CX, BORE_CY = 31, OY + 16
local BORE_RX, BORE_RY = 10, 5

local function draw_roof_details(img)
  -- Panel seam lines following iso axes (2 diagonal seams)
  -- Seam along top-left to bottom-right direction
  for x = 4, W - 5 do
    local by = math.floor(OY + 15.5 + (15.5 / 31.5) * (x - 31.5) - 6)
    if roof_sdf(x, by) > 0.12 then
      H.px(img, x, by, rim_c)
    end
    local by2 = math.floor(OY + 15.5 + (15.5 / 31.5) * (x - 31.5) + 6)
    if roof_sdf(x, by2) > 0.12 then
      H.px(img, x, by2, rim_c)
    end
  end

  -- Corner rivets at 4 cardinal points of roof
  local rivet_spots = {
    {31, OY + 3}, {31, OY + 28},
    {5, OY + 15}, {58, OY + 15},
  }
  for _, rp in ipairs(rivet_spots) do
    if roof_sdf(rp[1], rp[2]) > 0.1 then
      H.px(img, rp[1], rp[2], rivet_c)
    end
  end

  -- Steel rim around bore opening
  iso_ellipse_outline(img, BORE_CX, BORE_CY, BORE_RX + 2, BORE_RY + 1, STEEL, 0.35)
  iso_ellipse_outline(img, BORE_CX, BORE_CY, BORE_RX + 1, BORE_RY + 1, outline, 0.3)

  -- Cut out bore hole (transparent so base layer shows through)
  iso_ellipse(img, BORE_CX, BORE_CY, BORE_RX, BORE_RY, H.TRANSPARENT)
end

-- =========================================================================
-- DERRICK / CRANE STRUCTURE (extends above roof into y=0..OY+8)
-- =========================================================================

local function draw_derrick(img, tag, phase)
  -- Derrick apex (motor/pulley housing) position
  local apex_x, apex_y = 31, 1
  local apex_hw, apex_hh = 3, 3  -- half-size of housing (7x7)

  -- A-frame legs: THICK 3px-wide beams from roof surface up to apex
  -- Left leg base on roof surface
  local leg_l_bx, leg_l_by = 16, OY + 12
  local leg_l_tx, leg_l_ty = apex_x - 3, apex_y + apex_hh + 1
  -- Draw 3px wide leg
  for dx = -1, 1 do
    H.line(img, leg_l_bx + dx, leg_l_by, leg_l_tx + dx, leg_l_ty, STEEL)
  end
  -- Outline edges
  H.line(img, leg_l_bx - 1, leg_l_by, leg_l_tx - 1, leg_l_ty, outline)
  H.line(img, leg_l_bx + 2, leg_l_by, leg_l_tx + 2, leg_l_ty, outline)

  -- Right leg base on roof surface
  local leg_r_bx, leg_r_by = 46, OY + 12
  local leg_r_tx, leg_r_ty = apex_x + 3, apex_y + apex_hh + 1
  for dx = -1, 1 do
    H.line(img, leg_r_bx + dx, leg_r_by, leg_r_tx + dx, leg_r_ty, STEEL)
  end
  H.line(img, leg_r_bx - 2, leg_r_by, leg_r_tx - 2, leg_r_ty, outline)
  H.line(img, leg_r_bx + 1, leg_r_by, leg_r_tx + 1, leg_r_ty, outline)

  -- Cross-braces between legs (two horizontal bars + X-brace)
  local function leg_x_at_y(base_x, base_y, top_x, top_y, target_y)
    local t = (target_y - base_y) / (top_y - base_y)
    return math.floor(base_x + (top_x - base_x) * t + 0.5)
  end

  -- Lower horizontal brace
  local brace_y1 = OY + 5
  local bl1 = leg_x_at_y(leg_l_bx, leg_l_by, leg_l_tx, leg_l_ty, brace_y1)
  local br1 = leg_x_at_y(leg_r_bx, leg_r_by, leg_r_tx, leg_r_ty, brace_y1)
  H.line(img, bl1, brace_y1, br1, brace_y1, STEEL_DK)
  H.line(img, bl1, brace_y1 + 1, br1, brace_y1 + 1, outline)

  -- Upper horizontal brace
  local brace_y2 = OY - 1
  local bl2 = leg_x_at_y(leg_l_bx, leg_l_by, leg_l_tx, leg_l_ty, brace_y2)
  local br2 = leg_x_at_y(leg_r_bx, leg_r_by, leg_r_tx, leg_r_ty, brace_y2)
  H.line(img, bl2, brace_y2, br2, brace_y2, STEEL_DK)

  -- X-brace between the two horizontal braces
  H.line(img, bl2, brace_y2, br1, brace_y1, STEEL_DK)
  H.line(img, br2, brace_y2, bl1, brace_y1, STEEL_DK)

  -- Motor/pulley housing at apex (7x7 box with detail)
  H.rect(img, apex_x - apex_hw, apex_y, apex_x + apex_hw, apex_y + 2 * apex_hh, STEEL)
  H.rect_outline(img, apex_x - apex_hw, apex_y, apex_x + apex_hw, apex_y + 2 * apex_hh, outline)
  -- Motor detail: pulley wheel indicator
  H.px(img, apex_x, apex_y + 1, STEEL_LT)
  H.px(img, apex_x - 1, apex_y + 1, STEEL_DK)
  H.px(img, apex_x + 1, apex_y + 1, STEEL_DK)
  H.px(img, apex_x, apex_y + 3, STEEL_LT)
  H.px(img, apex_x - 1, apex_y + 3, STEEL_DK)
  H.px(img, apex_x + 1, apex_y + 3, STEEL_DK)
  H.px(img, apex_x, apex_y + 5, STEEL_LT)
  -- Exhaust nub on top
  H.px(img, apex_x, apex_y - 1, STEEL_DK)
  H.px(img, apex_x, apex_y - 2, outline)

  -- Active state: motor highlight oscillates
  if tag == "active" then
    local vib = (phase % 2 == 0) and 0 or 1
    H.px(img, apex_x + vib, apex_y + 2, STEEL_LT)
    H.px(img, apex_x - vib, apex_y + 4, STEEL_LT)
  elseif tag == "windup" then
    if phase == 1 then
      H.px(img, apex_x, apex_y + 2, STEEL_LT)
    end
  end

  -- Cable from apex down to bore hole
  local cable_top = apex_y + 2 * apex_hh + 1
  local cable_bot = BORE_CY - BORE_RY - 1
  for y = cable_top, cable_bot do
    H.px(img, BORE_CX, y, STEEL_DK)
  end
  -- Cable outline on sides
  H.px(img, BORE_CX - 1, cable_top, outline)
  H.px(img, BORE_CX + 1, cable_top, outline)

  -- Foot plates where legs meet roof
  for dx = -2, 2 do
    H.px(img, leg_l_bx + dx, leg_l_by + 1, outline)
    H.px(img, leg_r_bx + dx, leg_r_by + 1, outline)
  end
end

-- =========================================================================
-- LEFT WALL DETAILS
-- =========================================================================

local function draw_left_wall_details(img)
  -- Large access panel: ~10x12 px, centered on wall face
  -- Panel center roughly at x=14, about 40% down the wall
  local panel_x1 = 8
  local panel_x2 = 18
  -- Compute Y from wall top at center of panel
  local panel_cx = math.floor((panel_x1 + panel_x2) / 2)
  local wall_top = left_top_y(panel_cx)
  local panel_y1 = math.floor(wall_top + WALL_H * 0.15)
  local panel_y2 = math.floor(wall_top + WALL_H * 0.72)

  -- Fill panel area (checking bounds)
  for y = panel_y1, panel_y2 do
    for x = panel_x1, panel_x2 do
      if in_left(x, y) then
        H.px(img, x, y, panel_in)
      end
    end
  end
  -- Panel border
  for x = panel_x1, panel_x2 do
    if in_left(x, panel_y1) then H.px(img, x, panel_y1, rim_c) end
    if in_left(x, panel_y2) then H.px(img, x, panel_y2, rim_c) end
  end
  for y = panel_y1, panel_y2 do
    if in_left(panel_x1, y) then H.px(img, panel_x1, y, rim_c) end
    if in_left(panel_x2, y) then H.px(img, panel_x2, y, rim_c) end
  end
  -- Panel handle
  H.px(img, panel_x2 - 1, math.floor((panel_y1 + panel_y2) / 2), rivet_c)
  H.px(img, panel_x2 - 1, math.floor((panel_y1 + panel_y2) / 2) + 1, rivet_c)

  -- Two horizontal pipe runs across the wall
  local pipe_x1, pipe_x2 = 4, 26
  for _, frac in ipairs({0.35, 0.75}) do
    for x = pipe_x1, pipe_x2 do
      local wt = left_top_y(x)
      local py = math.floor(wt + WALL_H * frac)
      if in_left(x, py) and not (x >= panel_x1 and x <= panel_x2 and py >= panel_y1 and py <= panel_y2) then
        H.px(img, x, py, pipe_c)
        if in_left(x, py + 1) then
          H.px(img, x, py + 1, pipe_in)
        end
      end
    end
    -- Pipe flanges at endpoints
    for _, fx in ipairs({pipe_x1 + 1, pipe_x2 - 1}) do
      local wt = left_top_y(fx)
      local py = math.floor(wt + WALL_H * frac)
      if in_left(fx, py - 1) then H.px(img, fx, py - 1, rivet_c) end
      if in_left(fx, py + 2) then H.px(img, fx, py + 2, rivet_c) end
    end
  end

  -- Structural bolts at corners
  for _, bx in ipairs({3, 25}) do
    for _, frac in ipairs({0.1, 0.88}) do
      local wt = left_top_y(bx)
      local by = math.floor(wt + WALL_H * frac)
      if in_left(bx, by) then
        H.px(img, bx, by, rivet_c)
      end
    end
  end
end

-- =========================================================================
-- RIGHT WALL DETAILS
-- =========================================================================

local function draw_right_wall_details(img)
  -- Output chute opening: 8x8 with dark interior and steel frame
  local chute_x1 = 42
  local chute_x2 = 50
  local chute_cx = math.floor((chute_x1 + chute_x2) / 2)
  local wt = right_top_y(chute_cx)
  local chute_y1 = math.floor(wt + WALL_H * 0.2)
  local chute_y2 = math.floor(wt + WALL_H * 0.55)

  -- Dark chute interior
  for y = chute_y1, chute_y2 do
    for x = chute_x1, chute_x2 do
      if in_right(x, y) then
        H.px(img, x, y, chamber)
      end
    end
  end
  -- Inner depth
  for y = chute_y1 + 1, chute_y2 - 1 do
    for x = chute_x1 + 1, chute_x2 - 1 do
      if in_right(x, y) then
        H.px(img, x, y, chamber_d)
      end
    end
  end
  -- Steel frame around chute
  for x = chute_x1, chute_x2 do
    if in_right(x, chute_y1) then H.px(img, x, chute_y1, STEEL_DK) end
    if in_right(x, chute_y2) then H.px(img, x, chute_y2, STEEL_DK) end
  end
  for y = chute_y1, chute_y2 do
    if in_right(chute_x1, y) then H.px(img, chute_x1, y, STEEL_DK) end
    if in_right(chute_x2, y) then H.px(img, chute_x2, y, STEEL_DK) end
  end
  -- Outline the chute
  for x = chute_x1 - 1, chute_x2 + 1 do
    if in_right(x, chute_y1 - 1) then H.px(img, x, chute_y1 - 1, outline) end
    if in_right(x, chute_y2 + 1) then H.px(img, x, chute_y2 + 1, outline) end
  end

  -- Exhaust vent: 6x4 with grate pattern
  local vent_x1 = 38
  local vent_x2 = 44
  local vent_cx = math.floor((vent_x1 + vent_x2) / 2)
  local vwt = right_top_y(vent_cx)
  local vent_y1 = math.floor(vwt + WALL_H * 0.65)
  local vent_y2 = vent_y1 + 4

  for y = vent_y1, vent_y2 do
    for x = vent_x1, vent_x2 do
      if in_right(x, y) then
        -- Grate pattern: alternating dark/body rows
        if (y - vent_y1) % 2 == 0 then
          H.px(img, x, y, grate_c)
        else
          H.px(img, x, y, intake_dk)
        end
      end
    end
  end
  -- Vent border
  for x = vent_x1, vent_x2 do
    if in_right(x, vent_y1 - 1) then H.px(img, x, vent_y1 - 1, rim_c) end
    if in_right(x, vent_y2 + 1) then H.px(img, x, vent_y2 + 1, rim_c) end
  end

  -- Panel seam line (diagonal, following iso direction)
  for x = 34, 58 do
    local swt = right_top_y(x)
    local sy = math.floor(swt + WALL_H * 0.85)
    if in_right(x, sy) then
      H.px(img, x, sy, rim_c)
    end
  end

  -- Structural bolts
  for _, bx in ipairs({37, 55}) do
    for _, frac in ipairs({0.1, 0.88}) do
      local bwt = right_top_y(bx)
      local by = math.floor(bwt + WALL_H * frac)
      if in_right(bx, by) then
        H.px(img, bx, by, rivet_c)
      end
    end
  end
end

-- =========================================================================
-- BASE LAYER: shadow + bore hole interior + drill animation
-- =========================================================================

local function draw_base(img, tag, phase)
  -- Shadow ellipse at ground level
  local shadow = H.with_alpha(H.hex("#000000"), 30)
  local shadow_cy = OY + 15 + WALL_H + 4  -- below the box
  for y = 0, FH - 1 do
    for x = 0, W - 1 do
      local dx = math.abs(x - 31.5) / 33
      local dy = math.abs(y - shadow_cy) / 11
      local d = 1.0 - dx - dy
      if d > 0 and d < 0.5 then
        H.px(img, x, y, shadow)
      end
    end
  end

  -- Bore hole interior (visible through roof cutout)
  iso_ellipse(img, BORE_CX, BORE_CY, BORE_RX, BORE_RY, chamber)
  iso_ellipse(img, BORE_CX, BORE_CY, BORE_RX - 3, BORE_RY - 2, bore_c)
  iso_ellipse(img, BORE_CX, BORE_CY, BORE_RX - 6, BORE_RY - 3, bore_d)

  if tag == "active" then
    -- Rotating drill bit visible in bore hole
    local angles = {{1,0},{0,1},{-1,0},{0,-1}}
    local a = angles[(phase % 4) + 1]
    -- Drill bit arms
    H.px(img, BORE_CX + a[1]*4, BORE_CY + a[2]*2, BIT)
    H.px(img, BORE_CX + a[1]*3, BORE_CY + a[2]*1, BIT)
    H.px(img, BORE_CX + a[1]*2, BORE_CY + a[2]*1, BIT_DK)
    H.px(img, BORE_CX - a[1]*4, BORE_CY - a[2]*2, BIT)
    H.px(img, BORE_CX - a[1]*3, BORE_CY - a[2]*1, BIT)
    H.px(img, BORE_CX - a[1]*2, BORE_CY - a[2]*1, BIT_DK)
    -- Center hub
    H.px(img, BORE_CX, BORE_CY, BIT)
    H.px(img, BORE_CX + 1, BORE_CY, BIT_DK)
    H.px(img, BORE_CX - 1, BORE_CY, BIT_DK)
    -- Debris particles flying out
    local ore_c = C.iron_ore
    local copper = C.copper_ore
    H.px(img, BORE_CX + a[2]*3, BORE_CY - a[1]*2, ore_c)
    H.px(img, BORE_CX - a[2]*4, BORE_CY + a[1]*2, copper)
    H.px(img, BORE_CX + a[2]*2 + a[1], BORE_CY - a[1]*3, ore_c)
  elseif tag == "windup" then
    -- Bit starting to engage
    H.px(img, BORE_CX, BORE_CY, BIT)
    H.px(img, BORE_CX + 2, BORE_CY, BIT_DK)
    H.px(img, BORE_CX - 2, BORE_CY, BIT_DK)
    H.px(img, BORE_CX, BORE_CY + 1, BIT_DK)
    H.px(img, BORE_CX, BORE_CY - 1, BIT_DK)
    if phase == 1 then
      -- Slight rotation hint
      H.px(img, BORE_CX + 3, BORE_CY + 1, BIT)
      H.px(img, BORE_CX - 3, BORE_CY - 1, BIT)
    end
  elseif tag == "winddown" then
    -- Slowing down
    H.px(img, BORE_CX, BORE_CY, BIT)
    H.px(img, BORE_CX + 2, BORE_CY, BIT_DK)
    H.px(img, BORE_CX - 2, BORE_CY, BIT_DK)
    if phase == 0 then
      -- Last debris
      local ore_c = C.iron_ore
      H.px(img, BORE_CX + 2, BORE_CY + 2, ore_c)
    end
  else
    -- Idle: static bit, no movement
    H.px(img, BORE_CX, BORE_CY, BIT)
    H.px(img, BORE_CX + 2, BORE_CY, BIT_DK)
    H.px(img, BORE_CX - 2, BORE_CY, BIT_DK)
    H.px(img, BORE_CX, BORE_CY + 1, BIT_DK)
    H.px(img, BORE_CX, BORE_CY - 1, BIT_DK)
  end
end

-- =========================================================================
-- TOP LAYER: box structure + derrick + details
-- =========================================================================

local function draw_top(img, tag, phase)
  -- Draw 3D box (brown body)
  draw_box_structure(img)

  -- Wall details
  draw_left_wall_details(img)
  draw_right_wall_details(img)

  -- Roof details + bore cutout
  draw_roof_details(img)

  -- Derrick structure above roof
  draw_derrick(img, tag, phase)
end

-- =========================================================================
-- GENERATE SPRITE
-- =========================================================================

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then
    draw_base(img, tag, phase)
  else
    draw_top(img, tag, phase)
  end
end)
H.save_and_export(spr, DIR, "main")
print("[drill] done")
