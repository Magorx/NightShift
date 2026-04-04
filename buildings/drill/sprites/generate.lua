-- generate.lua -- Isometric drill/extractor using Iso 3D geometry library
-- 64x72 canvas, 2 layers (base, top), 10 frames:
-- idle(2) + windup(2) + active(4) + winddown(2)
--
-- Design: Industrial drilling rig with visible gear mechanism, derrick,
-- piston, and bore hole. The gear rotates and piston pumps during active.
--
-- Base layer: shadow footprint + bore hole interior (draws under items)
-- Top layer: full building structure (draws over items)

local REPO = "/Users/gorishniymax/Repos/factor"
local H    = dofile(REPO .. "/tools/aseprite_helper.lua")
local Iso  = dofile(REPO .. "/tools/rendering/iso/init.lua")
Iso._set_helper(H)

local C = H.load_palette("buildings")

local W, FH = 64, 72
local LAYERS = {"base", "top"}
local TAGS = {
  {name="idle",     from=1,  to=1,  duration=0.5},
  {name="windup",   from=2,  to=3,  duration=0.15},
  {name="active",   from=4,  to=7,  duration=0.15},
  {name="winddown", from=8,  to=9, duration=0.15},
}
local DIR = REPO .. "/buildings/drill/sprites"

-- Steel colors for mechanical parts
local STEEL      = H.hex("#7A8898")
local STEEL_DK   = H.hex("#6A7888")
local STEEL_LT   = H.hex("#96A4B4")

-- Brighter brown variants so the body doesn't look too dark
local BODY_MAIN  = H.hex("#5A4838")
local BODY_LIGHT = H.hex("#6E5A48")
local BODY_ROOF  = H.hex("#7A6854")

-- Scene origin: tile diamond center maps to sprite pixel (32, 55)
-- because .tscn sprite position is (0, -19) and centered=true → 36+19=55
local OX, OY = 32, 55

-- =========================================================================
-- ANIMATION PARAMETERS
-- =========================================================================
local function anim_params(tag, phase)
  local gear_angle = 0
  local piston_ext = 0
  local vibe_x, vibe_y = 0, 0

  if tag == "idle" then
    -- Idle: small alternation for visual interest
    gear_angle = phase * 0.05
    piston_ext = 0
  elseif tag == "windup" then
    gear_angle = phase * 0.5
    piston_ext = phase * 2
  elseif tag == "active" then
    gear_angle = Iso.anim_rotation(phase, 5)
    piston_ext = Iso.anim_oscillate(phase, 0, 5, 4)
    vibe_x, vibe_y = Iso.anim_shake(phase, 0.5)
  elseif tag == "winddown" then
    gear_angle = 1.0 + phase * 0.15
    piston_ext = (1 - phase) * 2.5
  end

  return gear_angle, piston_ext, vibe_x, vibe_y
end

-- =========================================================================
-- BASE LAYER: shadow + bore hole interior
-- =========================================================================
local function draw_base(img, tag, phase)
  local sc = Iso.scene(W, FH, OX, OY)

  -- Ground shadow (flat dark diamond)
  sc:add(Iso.box(24, 24, 1), {-12, -12, -1},
    { base = C.shadow, outline = C.shadow },
    { shading = { ambient = 0.85, diffuse = 0.15 } })

  sc:draw(img, false)

  -- Bore hole interior: dark pit in the center of the footprint
  local bore_cx = OX
  local bore_cy = OY - 3
  H.circle(img, bore_cx, bore_cy, 6, C.bore)
  H.circle(img, bore_cx, bore_cy, 4, C.bore_deep)
  H.circle(img, bore_cx, bore_cy, 2, C.chamber_deep)

  -- Drilling debris particles when active
  if tag == "active" then
    local offsets = {{-3,1},{1,3},{3,-1},{-1,-3}}
    local o = offsets[(phase % 4) + 1]
    H.px(img, bore_cx + o[1], bore_cy + o[2], C.iron_ore)
    H.px(img, bore_cx - o[2], bore_cy + o[1], C.copper_ore)
    H.px(img, bore_cx + o[2], bore_cy - o[1], C.iron_ore)
  elseif tag == "windup" and phase == 1 then
    H.px(img, bore_cx - 2, bore_cy + 1, C.iron_ore)
  end
end

-- =========================================================================
-- TOP LAYER: full building structure using Iso shapes
-- =========================================================================
local function draw_top(img, tag, phase)
  local gear_angle, piston_ext, vibe_x, vibe_y = anim_params(tag, phase)

  local vox = math.floor(OX)
  local voy = math.floor(OY)
  local sc = Iso.scene(W, FH, vox, voy)

  -- High ambient shading so brown colors stay warm/visible
  local body_shade  = { ambient = 0.55, diffuse = 0.45, specular = 0.05, spec_pow = 4 }
  local steel_shade = { ambient = 0.45, diffuse = 0.45, specular = 0.15, spec_pow = 8 }
  local pipe_shade  = { ambient = 0.5, diffuse = 0.4, specular = 0.1, spec_pow = 6 }

  -- ── Main housing: base box ──────────────────────────────────────────
  -- 20x20 footprint, 8 units tall -- the sturdy base
  sc:add(Iso.box(20, 20, 8), {-10, -10, 0},
    { base = BODY_MAIN, outline = C.outline },
    { texture = Iso.tex_noise(0.05), shading = body_shade })

  -- ── Metal reinforcement band at mid-height ──────────────────────────
  sc:add(Iso.box(21, 21, 2), {-10.5, -10.5, 3},
    { base = STEEL_DK, outline = C.outline },
    { shading = steel_shade })

  -- ── Top platform / roof plate with overhang ─────────────────────────
  sc:add(Iso.box(22, 22, 2), {-11, -11, 8},
    { base = BODY_ROOF, outline = C.outline },
    { texture = Iso.tex_metal_plate(7, 7, C.rivet), shading = body_shade })

  -- ── Gear mechanism (front-right, prominent) ─────────────────────────
  -- Main gear: large, visible, with teeth
  local gear = Iso.gear(9, 5, 3, 8, 3, gear_angle/10)
  sc:add(gear, {11, 2, 4},
    { base = STEEL_LT, outline = C.outline },
    { shading = { ambient = 0.5, diffuse = 0.4, specular = 0.2, spec_pow = 10 } })

  -- Secondary gear: smaller, counter-rotating, interlocked
  local gear2_angle = -gear_angle * (9/5) + 0.4  -- gear ratio for meshing
  local small_gear = Iso.gear(5, 3.5, 0, 6, 3, gear2_angle)
  sc:add(small_gear, {11, -8, 4},
    { base = STEEL, outline = C.outline },
    { shading = { ambient = 0.45, diffuse = 0.4, specular = 0.2, spec_pow = 8 } })

  -- ── Derrick / drill column ──────────────────────────────────────────
  -- Tall central column rising from the roof -- the visual anchor
  sc:add(Iso.cylinder(3.5, 24), {0, 0, 10},
    { base = STEEL, outline = C.outline },
    { texture = Iso.tex_rivets(5, true, STEEL_DK), shading = steel_shade })

  -- ── Derrick cap / A-frame top ───────────────────────────────────────
  -- Wider cap at the top of the derrick for visual weight
  sc:add(Iso.box(8, 8, 4), {-4, -4, 34},
    { base = BODY_LIGHT, outline = C.outline },
    { texture = Iso.tex_metal_plate(6, 6, C.rivet), shading = body_shade })

  -- Small cone tip on top
  sc:add(Iso.cone(3, 4), {0, 0, 38},
    { base = STEEL_LT, outline = C.outline },
    { shading = steel_shade })

  -- ── Piston assembly (left-front side) ───────────────────────────────
  -- Visible piston that pumps during active
  sc:add(Iso.piston(3.5, 1.5, 7, piston_ext), {-12, -6, 8},
    { base = STEEL_DK, outline = C.outline },
    { shading = steel_shade })

  -- ── Connecting pipe from body to piston ─────────────────────────────
  sc:add(Iso.pipe("x", 6, 2, 0.5), {-12, -6, 11},
    { base = C.pipe, outline = C.outline },
    { shading = pipe_shade })

  -- ── Exhaust stack (back side) ───────────────────────────────────────
  sc:add(Iso.cylinder(2.5, 8), {-4, 10, 8},
    { base = C.pipe, outline = C.outline },
    { shading = pipe_shade })

  -- Exhaust cap
  sc:add(Iso.cylinder(3, 1), {-4, 10, 16},
    { base = STEEL_DK, outline = C.outline },
    { shading = steel_shade })

  -- ── Render the 3D scene ─────────────────────────────────────────────
  sc:draw(img, C.outline)

  -- ── Bore hole (transparent opening in the roof) ─────────────────────
  -- Cut a circle through the top layer so the base layer bore shows
  -- local bore_cx = vox
  -- local bore_cy = voy - 3
  -- for dy = -5, 5 do
  --   for dx = -5, 5 do
  --     if dx*dx + dy*dy <= 20 then
  --       H.px(img, bore_cx + dx, bore_cy + dy, H.TRANSPARENT)
  --     end
  --   end
  -- end
  -- -- Bore hole rim outline
  -- H.circle_outline(img, bore_cx, bore_cy, 5, C.outline)
  -- -- Inner rim highlight
  -- for dy = -4, 4 do
  --   for dx = -4, 4 do
  --     local d = dx*dx + dy*dy
  --     if d >= 12 and d <= 16 then
  --       H.px(img, bore_cx + dx, bore_cy + dy, C.bore)
  --     end
  --   end
  -- end

  -- ── Smoke/steam from exhaust when active ────────────────────────────
  if tag == "active" or (tag == "windup" and phase == 1) then
    local ex_sx, ex_sy = Iso.project(-4, 10, 17)
    ex_sx = ex_sx + vox
    ex_sy = ex_sy + voy
    local smoke_offsets = {{0,-1},{-1,-2},{1,-3},{0,-2}}
    local o = smoke_offsets[(phase % 4) + 1]
    H.px(img, math.floor(ex_sx + o[1]), math.floor(ex_sy + o[2]), C.smoke_light)
    H.px(img, math.floor(ex_sx - o[1]), math.floor(ex_sy + o[2] - 1), C.smoke_mid)
    if phase >= 2 then
      H.px(img, math.floor(ex_sx), math.floor(ex_sy - 3), C.smoke_dark)
    end
  end

  -- ── Status indicator LED on front face ──────────────────────────────
  -- local led_color
  -- if tag == "active" then
  --   led_color = C.active_green
  -- elseif tag == "windup" or tag == "winddown" then
  --   led_color = phase == 0 and C.warning_red or C.active_green
  -- else
  --   led_color = C.idle_gray
  -- end
  -- local led_sx, led_sy = Iso.project(10, -6, 6)
  -- led_sx = led_sx + vox
  -- led_sy = led_sy + voy
  -- H.px(img, math.floor(led_sx), math.floor(led_sy), led_color)
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
