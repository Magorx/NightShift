# iso_geo — Isometric 3D Geometry Library

## What This Is

A Lua library that renders 3D shapes as pixel-art isometric sprites. Used by the artist agent to create building sprites programmatically, replacing hand-coded perspective math.

## Architecture

- **Entry point**: `init.lua` — loads all modules into a single `Iso` table
- **Dependency**: Requires `aseprite_helper.lua` (set via `Iso._set_helper(H)`)
- **Runs in**: Aseprite Lua scripting environment (not Godot)

## Module Map

| File | What it does | Key functions |
|------|-------------|---------------|
| `config.lua` | Projection constants | `Iso.configure()`, `Iso.preset_*()` |
| `projection.lua` | 3D↔2D math | `Iso.project()`, `Iso.unproject()`, `Iso.rotate()` |
| `zbuffer.lua` | Depth buffer | `Iso.zbuffer()`, `Iso.ztest()` |
| `shading.lua` | Legacy shading + outlines | `Iso.shade_color()`, `Iso.draw_outlines()` |
| `lighting.lua` | Scene lights | `Iso.light_ambient()`, `Iso.light_directional()`, `Iso.light_point()` |
| `primitives.lua` | 9 shapes + CSG | `Iso.box()`, `Iso.cylinder()`, `Iso.union()`, etc. |
| `mechanical.lua` | Compound parts | `Iso.gear()`, `Iso.pipe()`, `Iso.piston()` |
| `texture.lua` | Surface patterns | `Iso.tex_brick()`, `Iso.tex_metal_plate()`, etc. |
| `animation.lua` | Motion helpers | `Iso.anim_gear()`, `Iso.particle_emitter()` |
| `scene.lua` | Composition | `Iso.scene()`, `Iso.render_shape()` |

## How Shapes Work

Every shape has a `:hit(screen_x, screen_y)` method that returns:
```lua
{ depth, face, nx, ny, nz, mx, my, mz }  -- or nil
```
- `depth`: for z-buffer sorting (lower = closer to camera)
- `face`: string like "top", "front_left", "body"
- `nx,ny,nz`: surface normal for shading
- `mx,my,mz`: 3D model-space hit point (for textures)

The renderer iterates screen pixels, calls `:hit()` on each shape, keeps the closest hit per pixel, applies shading/textures, and draws outlines.

## Projection

The projection is a 2×3 matrix mapping model (x,y,z) → screen (sx,sy):
```
sx = x * XX + y * YX + z * ZX
sy = x * XY + y * YY + z * ZY
```

Default (2:1 dimetric): XX=1, XY=0.5, YX=-1, YY=0.5, ZX=0, ZY=-1

**Shapes must be created AFTER configuring projection** — they cache screen bounds from the matrix at creation time.

## Using in Building Generate Scripts

```lua
local H   = dofile(REPO .. "/tools/aseprite_helper.lua")
local Iso = dofile(REPO .. "/tools/rendering/iso/init.lua")
Iso._set_helper(H)

-- Create a scene for a 64×72 building sprite
local sc = Iso.scene(64, 72, 32, 56)

-- Add shapes with 3D positions
sc:add(Iso.box(24, 24, 16), {0,0,0}, { base = pal.body, outline = pal.outline })
sc:add(Iso.cylinder(4, 10), {4, 4, 16}, { base = pal.pipe, outline = pal.outline })

-- Add lights (optional — default is ambient 0.35 + directional 0.65)
sc:add_light(Iso.light_ambient(0.2))
sc:add_light(Iso.light_directional(-0.5, -0.5, 0.7, 0.7))
sc:add_light(Iso.light_point(12, 12, 30, 1.2, 40, {1.0, 0.8, 0.6}))

-- Render
sc:draw(img, pal.outline)
```

## Lighting System

Lights are scene-level objects added via `scene:add_light()`. Three types:

| Type | Constructor | What it does |
|------|------------|--------------|
| Ambient | `Iso.light_ambient(intensity, color)` | Flat uniform brightness, no direction |
| Directional | `Iso.light_directional(dx,dy,dz, intensity, color)` | Parallel rays (sun-like), auto-normalized |
| Point | `Iso.light_point(x,y,z, intensity, radius, color)` | Positional with smooth quadratic falloff |

- `color` is optional `{r, g, b}` normalized 0..1 (default white `{1,1,1}`)
- If no lights are added to a scene, defaults to `ambient(0.35) + directional(0.65)` (matches old behavior)
- `Iso.render_shape()` (quick render) still uses the legacy `Iso.shade_color()` path — use scenes for lit rendering
- Point light `radius` is the distance at which light reaches zero (default 30)
- Specular highlights are supported via `opts.shading = { specular = 0.5, spec_pow = 8 }`

## Relationship to iso_box.lua

The old `tools/iso_box.lua` provides hardcoded 2:1 box geometry with SDF-based rendering. This library (`iso_geo`) generalizes and replaces it:
- Configurable projection (not just 2:1)
- 9 primitives (not just box)
- Automatic shading from normals
- CSG boolean operations
- Mechanical parts (gears, pipes)
- Textures and animation

Building scripts can use either. New scripts should prefer `iso_geo`.
