# Isometric 3D Geometry Library (`iso_geo`)

A Lua library for rendering 3D shapes as pixel-art isometric sprites via Aseprite scripting. Replaces hand-coded perspective math with a proper 3D→2D projection pipeline.

## Quick Start

```lua
local H   = dofile("tools/aseprite_helper.lua")
local Iso = dofile("tools/rendering/iso/init.lua")
Iso._set_helper(H)

-- Create a shape
local box = Iso.box(16, 16, 12)  -- width, depth, height

-- Render onto an Aseprite image
local img = Image(64, 64, ColorMode.RGB)
Iso.render_shape(img, box, 32, 48, {
  base = H.hex("#8B7355"),
  outline = H.hex("#191412"),
})
```

## Projection Configuration

The projection is **not hardcoded to 2:1**. Configure it with presets or raw values:

```lua
-- Presets
Iso.preset_2_1()        -- 2:1 dimetric (default, 64×32 diamonds)
Iso.preset_true_iso()   -- true isometric (≈30°)
Iso.preset_steep()      -- 1:1 diamonds (45° angle)
Iso.preset_flat()       -- 3:1 diamonds (shallow)
Iso.preset_military()   -- top-down oblique

-- Custom ratio
Iso.configure({ tile_ratio = 2.5, z_scale = 1.2 })

-- Raw matrix (full control)
Iso.configure({ XX=1, XY=0.5, YX=-1, YY=0.5, ZX=0, ZY=-1 })
```

**Important**: Shapes must be created *after* configuring the projection (they cache screen bounds).

## Model Space

- **+X** = east (right on screen)
- **+Y** = south (left on screen, into the scene)
- **+Z** = up (straight up on screen)
- **1 model unit ≈ 1 screen pixel** along a single axis (at default scale)

## Primitives

| Function | Parameters | Description |
|----------|-----------|-------------|
| `Iso.box(w, d, h)` | width, depth, height | Rectangular solid |
| `Iso.cylinder(r, h)` | radius, height | Vertical cylinder |
| `Iso.cone(r, h)` | base radius, height | Cone (apex at top) |
| `Iso.sphere(r)` | radius | Sphere sitting on ground |
| `Iso.hemisphere(r)` | radius | Dome (half-sphere) |
| `Iso.wedge(w, d, hf, hb)` | width, depth, front height, back height | Sloped box |
| `Iso.prism(w, d, h)` | width, depth, height | Triangular cross-section |
| `Iso.torus(R, r)` | major radius, minor radius | Ring/donut |
| `Iso.arch(w, d, h, ar)` | width, depth, height, arch radius | Box with arch cutout |

Each returns a shape with `:hit(sx, sy)` and screen bbox fields `.x1,.y1,.x2,.y2`.

## CSG (Boolean Operations)

```lua
local result = Iso.union(box, cylinder)      -- combine
local result = Iso.subtract(box, cylinder)   -- cut hole
local result = Iso.intersect(box, cylinder)  -- keep overlap only
```

## Transform

```lua
local moved = Iso.translate(shape, dx, dy, dz)
local turned = Iso.rotate_shape(shape, "z", math.pi/4)  -- expensive
```

## Mechanical Parts

| Function | Description |
|----------|-------------|
| `Iso.gear(outer_r, inner_r, hole_r, teeth, thickness, angle)` | Toothed gear |
| `Iso.pipe(axis, length, outer_r, wall)` | Hollow pipe along "x" or "y" |
| `Iso.pipe_elbow(bend_r, pipe_r)` | 90° pipe bend |
| `Iso.piston(sleeve_r, rod_r, sleeve_h, rod_extend)` | Piston assembly |
| `Iso.axle(axis, length, radius)` | Solid rod |
| `Iso.fan(blades, radius, blade_width, thickness, hub_r, angle)` | Propeller |
| `Iso.valve_wheel(radius, spokes, thickness, angle)` | Spoked wheel |

## Shading

Auto-shading from surface normals:

```lua
-- Base color + auto-shade (simple)
{ base = H.hex("#8B7355"), outline = H.hex("#191412") }

-- Manual colors per face (artistic control)
{ top = H.hex("#A0906D"), front_left = H.hex("#6B5535"),
  front_right = H.hex("#7B6545"), outline = H.hex("#191412") }

-- Shading options
opts = { shading = { ambient=0.35, diffuse=0.65, specular=0.3, spec_pow=8 } }

-- Change light direction
Iso.set_light(-1, -1, 1)  -- auto-normalized
```

## Textures

Textures are functions applied per-pixel after shading:

```lua
-- Apply a texture
Iso.render_shape(img, box, x, y, colors, { texture = Iso.tex_brick(4, 3) })

-- Available textures
Iso.tex_noise(amount)                    -- random brightness
Iso.tex_brick(bw, bh, mortar_color)      -- staggered bricks
Iso.tex_metal_plate(pw, ph, rivet_color) -- panels with corner rivets
Iso.tex_grate(spacing, bar_width, dir)   -- parallel bars
Iso.tex_rivets(spacing, strip_v, color)  -- dot strip
Iso.tex_wood_grain(spacing)              -- horizontal streaks
Iso.tex_corrugated(period)               -- wavy metal siding
Iso.tex_diamond_plate(spacing)           -- offset dot grid
Iso.tex_hex_mesh(size)                   -- hexagonal pattern
Iso.tex_dither(param_fn, color_a, color_b)  -- Bayer-dithered blend

-- Compose multiple textures
Iso.tex_compose(Iso.tex_noise(0.1), Iso.tex_brick(5, 3))
```

## Animation

```lua
-- Rotation angle for frame f (for gears, fans)
local angle = Iso.anim_rotation(frame, frames_per_rev)

-- Convenience: create animated gear/fan for a frame
local gear = Iso.anim_gear(14, 10, 3, 8, 5, frame, 8)

-- Oscillation (sinusoidal)
local val = Iso.anim_oscillate(frame, 0, 10, 16)  -- lo, hi, period

-- Shake (for vibration effects)
local dx, dy = Iso.anim_shake(frame, 1.5)

-- Particles (smoke, sparks)
local emitter = Iso.particle_emitter({
  origin = {0, 0, 20},
  velocity = {0, 0, 1},
  spread = 15,
  lifetime = 8,
  count = 2,
})
local particles = Iso.particle_positions(emitter, frame, ox, oy)
Iso.draw_particles(img, particles, {smoke_dark, smoke_mid, smoke_light})
```

## Scene Builder

For multi-shape compositions with automatic depth sorting:

```lua
local sc = Iso.scene(128, 128, 64, 96)  -- width, height, origin_x, origin_y

sc:add(Iso.box(24, 24, 16), {0, 0, 0},
  { base = brown, outline = outline },
  { texture = Iso.tex_metal_plate(8, 8) })

sc:add(Iso.cylinder(4, 12), {4, 4, 16},
  { base = stone, outline = outline })

sc:add(Iso.gear(6, 4, 1.5, 6, 3, 0.3), {24, 12, 8},
  { base = metal, outline = outline })

-- Render everything (shapes + outlines)
sc:draw(img, outline_color)

-- Or render in two steps for more control
local zbuf = sc:render(img)
sc:draw_outlines(img, zbuf, outline_color)
```

## Quick Render

For simple single-shape renders without a scene:

```lua
Iso.render_shape(img, shape, screen_x, screen_y, colors, opts)
```

## Depth Buffer

Manual depth buffer control for advanced compositing:

```lua
local zbuf = Iso.zbuffer(w, h)
Iso.ztest(zbuf, x, y, depth)   -- test-and-set, returns bool
Iso.zread(zbuf, x, y)          -- read current depth
Iso.zfilled(zbuf, x, y)        -- has anything been drawn?
Iso.zclear(zbuf)               -- reset to empty
```

## File Structure

```
tools/rendering/iso/
├── init.lua          Entry point (load this)
├── config.lua        Projection constants and presets
├── projection.lua    3D↔2D math, rotation
├── zbuffer.lua       Per-pixel depth buffer
├── shading.lua       Lighting, auto-shade, outlines
├── primitives.lua    9 shape primitives + CSG + transforms
├── mechanical.lua    Gears, pipes, pistons, fans
├── texture.lua       12 procedural surface textures
├── animation.lua     Rotation, oscillation, particles
├── scene.lua         Multi-shape composition
└── examples/
    ├── generate_examples.lua
    └── *.png          Visual reference for each feature
```

## Examples

See `examples/README.md` for visual reference of each feature. Regenerate with:

```bash
aseprite -b --script tools/rendering/iso/examples/generate_examples.lua
```
