# iso_geo Examples

Visual reference for every feature in the library. Regenerate with:

```bash
aseprite -b --script tools/rendering/iso/examples/generate_examples.lua
```

## 01_primitives.png

4×3 grid of all shape primitives:
- Row 1: Box, Cylinder, Cone, Sphere
- Row 2: Hemisphere, Wedge, Prism, Torus
- Row 3: Arch, Wide Box, Tall Cylinder, Flat Cone

## 02_shading.png

Same box with 8 different shading configurations:
- Row 1: Brown, Metal, Copper, Red (auto-shade from base color)
- Row 2: Manual face colors, Specular highlights, High ambient, Dramatic lighting

## 03_gear_rotation.png

8-frame spritesheet of a rotating gear (8 teeth, 5px thick).
Each frame advances the rotation by 1/8 of a tooth pitch.

## 04_mechanical.png

4×2 grid of compound mechanical parts:
- Row 1: Pipe (X axis), Pipe (Y axis), Gear, Fan
- Row 2: Piston, Axle, Pipe Elbow, Valve Wheel

## 05_textures.png

4×3 grid of the same box with different surface textures:
- Row 1: Plain, Noise, Brick, Metal Plate
- Row 2: Grate, Wood Grain, Corrugated, Diamond Plate
- Row 3: Hex Mesh, Noisy Brick (composed), Worn Metal (composed), Rivets

## 06_scene.png

Composite scene demonstrating multi-shape rendering:
- Base box with metal plate texture
- Cylindrical chimney on top
- Copper dome on roof
- Gear on the side
- Small detail box

## 07_projections.png

Same box rendered in 5 different projection presets:
2:1 Dimetric, True Isometric, Steep (1:1), Flat (3:1), Military

Shows that projection is fully configurable — not hardcoded.

## 08_csg.png

Boolean operations on a box and cylinder:
- Union (combined)
- Subtract (cylinder carved out of box)
- Intersect (only the overlap)
