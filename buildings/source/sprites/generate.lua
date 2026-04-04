-- generate.lua -- Source building sprite (item dispenser/generator)
-- 64x72 canvas, 2 layers (base=shadow, top=building), 4 frames
-- Uses Iso 3D geometry library for proper isometric rendering.
--
-- Design: industrial item generator with spinning fan on top,
-- output pipe on the side, cylindrical silo column, green accents.
-- The fan spins across 4 frames, green indicators pulse.

local H   = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local Iso = dofile("/Users/gorishniymax/Repos/factor/tools/rendering/iso/init.lua")
Iso._set_helper(H)
local C   = H.load_palette("buildings")

local W, FH = 64, 72
local LAYERS = {"base", "top"}
local TAGS = {
  {name="default", from=1, to=4, duration=0.3},
}
local DIR = "/Users/gorishniymax/Repos/factor/buildings/source/sprites"

-- Green accent palette
local GREEN    = H.hex("#3A8A4A")
local GREEN_DK = H.hex("#2D6B3F")
local GREEN_LT = H.hex("#4CAF50")
local GREEN_BR = H.hex("#5DC060")

-- Palette shortcuts
local outline  = C.outline
local body     = C.body
local body_lt  = C.body_light
local panel    = C.panel
local rivet_c  = C.rivet
local rim_c    = C.rim
local pipe_c   = C.pipe
local shadow_c = C.shadow

-- Scene origin: tile diamond center maps to sprite pixel (32, 55)
-- because .tscn sprite position is (0, -19) and centered=true → 36+19=55
local OX, OY = 32, 55

-- =========================================================================
-- BUILD THE SCENE FOR A GIVEN FRAME
-- =========================================================================

local function build_scene(frame_idx)
  local sc = Iso.scene(W, FH, OX, OY)

  -- Fan rotation: 4 frames = full revolution
  local fan_angle = Iso.anim_rotation(frame_idx - 1, 4)

  -- Green indicator pulse pattern
  local glow_cycle = {GREEN_BR, GREEN_LT, GREEN, GREEN_DK}
  local glow_color = glow_cycle[((frame_idx - 1) % 4) + 1]

  -- ── Main housing box ───────────────────────────────────────────────
  sc:add(Iso.box(22, 22, 10), {-11, -11, 0},
    { base = body, outline = outline },
    { texture = Iso.tex_metal_plate(8, 6, rivet_c) })

  -- ── Central cylindrical silo / energy column ──────────────────────
  sc:add(Iso.cylinder(7, 26), {0, 0, 0},
    { base = body_lt, outline = outline },
    { texture = Iso.tex_corrugated(3) })

  -- ── Green energy band around cylinder (upper) ─────────────────────
  sc:add(Iso.cylinder(7.5, 3), {0, 0, 10},
    { base = GREEN, outline = outline },
    { texture = Iso.tex_noise(0.06) })

  -- ── Green energy band (lower) ─────────────────────────────────────
  sc:add(Iso.cylinder(7.5, 2), {0, 0, 4},
    { base = GREEN_DK, outline = outline },
    { texture = Iso.tex_noise(0.06) })

  -- ── Fan hub platform (flat disc under the fan) ────────────────────
  sc:add(Iso.cylinder(5, 2), {0, 0, 26},
    { base = rim_c, outline = outline })

  -- ── Spinning fan on top (animated) ────────────────────────────────
  sc:add(Iso.fan(3, 12, 0.5, 2, 3, fan_angle), {0, 0, 28},
    { base = GREEN_LT, outline = outline },
    { shading = { ambient = 0.35, diffuse = 0.65, specular = 0.25, spec_pow = 6 } })

  -- Fan center hub cap
  sc:add(Iso.cylinder(2.5, 2), {0, 0, 28},
    { base = panel, outline = outline })

  -- ── Output pipe (extends along +X axis, front-right) ─────────────
  sc:add(Iso.pipe("x", 10, 3, 0.8), {9, 0, 5},
    { base = pipe_c, outline = outline },
    { texture = Iso.tex_noise(0.05) })

  -- Pipe exit flange
  sc:add(Iso.cylinder(4, 2), {19, 0, 5},
    { base = rim_c, outline = outline })

  -- ── Intake pipe (extends along -Y, back-left) ────────────────────
  sc:add(Iso.pipe("y", 8, 2.5, 0.8), {0, -16, 7},
    { base = pipe_c, outline = outline },
    { texture = Iso.tex_noise(0.05) })

  -- ── Green indicator lights (pulsing with frame) ───────────────────
  sc:add(Iso.sphere(2), {-12, -4, 10},
    { base = glow_color, outline = GREEN_DK })

  sc:add(Iso.sphere(2), {-4, -12, 10},
    { base = glow_color, outline = GREEN_DK })

  -- ── Vent grate on front-left face ─────────────────────────────────
  sc:add(Iso.box(2, 6, 5), {-12, -3, 1},
    { base = shadow_c, outline = outline },
    { texture = Iso.tex_grate(2, 1, "h") })

  -- ── Small hemisphere dome detail on box roof ──────────────────────
  sc:add(Iso.hemisphere(3), {7, -7, 10},
    { base = body_lt, outline = outline })

  return sc
end

-- =========================================================================
-- BASE LAYER: ground shadow
-- =========================================================================

local function draw_base(img, frame_idx)
  local shadow_col = H.with_alpha(H.hex("#000000"), 28)
  local cx, cy = 32, 57
  local rx, ry = 24, 8
  for y = cy - ry, cy + ry do
    for x = cx - rx, cx + rx do
      local dx = (x - cx) / rx
      local dy = (y - cy) / ry
      if dx * dx + dy * dy <= 1.0 then
        H.px(img, x, y, shadow_col)
      end
    end
  end
end

-- =========================================================================
-- TOP LAYER: full building via Iso scene
-- =========================================================================

local function draw_top(img, frame_idx)
  local sc = build_scene(frame_idx)
  sc:draw(img, outline)
end

-- =========================================================================
-- GENERATE SPRITE
-- =========================================================================

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  if layer == "base" then
    draw_base(img, fi)
  else
    draw_top(img, fi)
  end
end)
H.save_and_export(spr, DIR, "main")
print("[source] done")
