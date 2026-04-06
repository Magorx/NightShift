# Blender Pipeline for Building Sprites

## Why

The Lua Iso library proved that 3D-rendered isometric sprites work for Night Shift. But it's a toy raytracer — no preview, blind coding, painful debugging. Blender gives us a real 3D engine with proper rendering, materials, and animation, all scriptable via Python.

## Architecture

```
tools/blender/
├── render.py      # Core: camera, materials, render settings
├── prefabs_src/                # Reusable 3D part generators
│   ├── cog.py              # Generates gear/cog meshes → cog.blend
│   ├── pipe.py             # Pipe sections, elbows, flanges
│   ├── piston.py           # Sleeve + rod assemblies
│   ├── fan.py              # N-blade fan with hub
│   ├── cylinder.py         # Industrial cylinders/silos
│   └── box.py              # Textured industrial boxes (rivets, panels, seams)
├── prefabs_out/            # Generated .blend files (gitignored, reproducible)
├── scenes/                 # Per-building scene scripts
│   └── drill.py            # Composes drill from prefabs and primitives, sets animation
└── materials/
    └── pixel_art.py        # Flat-shaded material setup, palette colors
```

## Pipeline Flow

```
1. Prefab scripts generate reusable .blend parts
   python cog.py → prefabs_out/cog.blend

2. Scene scripts compose buildings from prefabs
   python drill.py
     → links cog.blend, pipe.blend, box.blend
     → positions, scales, sets keyframes
     → renders frame sequence

3. Render output: individual frame PNGs
   buildings/blender-drill/sprites/frames/
     base_idle_0.png, top_active_0.png, ...

4. Assembly script combines into Aseprite spritesheet
   python assemble.py → main.aseprite, main.png, main.json
   (or skip Aseprite: direct spritesheet packing in Python)
```

## Render Settings

These are critical to get pixel-art output from Blender:

- **Camera**: Orthographic, isometric angle matching our 2:1 dimetric projection
  - Rotation: X=54.736°, Y=0°, Z=45° (standard isometric)
  - Ortho scale: calibrated so 1 grid unit = known pixel count
- **Resolution**: 64x72 per frame (native, no downscaling)
- **Anti-aliasing**: OFF — nearest neighbor, no filtering
- **Renderer**: EEVEE (fast) or Workbench (even faster, flat shading)
- **Materials**: Flat/toon shaded, palette-constrained colors from `tools/palettes/buildings.lua`
- **Lighting**: Single directional (upper-left, matching current convention) + ambient
- **Background**: Transparent (RGBA)
- **Output**: PNG sequence with alpha

## Prefab System

Each prefab script is a standalone generator that produces a .blend file containing one reusable 3D object. Prefabs are parameterized — the scene script controls dimensions, tooth count, etc.

### Cog (`prefabs_src/cog.py`)

```python
def generate_cog(
    outer_radius=1.0,
    inner_radius=0.7,
    teeth=8,
    thickness=0.3,
    tooth_width_ratio=0.35,  # fraction of tooth pitch
    output="prefabs_out/cog.blend"
):
    # 1. Create base cylinder at inner_radius
    # 2. Extrude teeth as rectangular protrusions
    # 3. Boolean union into single mesh
    # 4. Apply flat material with palette color
    # 5. Save .blend
```

Scene scripts link the prefab, override material color, set rotation keyframes:

```python
cog = link_prefab("prefabs_out/cog.blend", "Cog")
cog.location = (1.1, 0.2, 0.4)
cog.keyframe_insert("rotation_euler", frame=1)  # angle 0
cog.rotation_euler.z = math.radians(72)
cog.keyframe_insert("rotation_euler", frame=2)  # angle 72°
# ... etc for 4 active frames
```

### Other Prefabs

| Prefab | Parameters | Notes |
|--------|-----------|-------|
| `pipe.py` | length, radius, wall_thickness, axis | Hollow cylinder with flange caps |
| `piston.py` | sleeve_r, rod_r, sleeve_h, max_extend | Animated via rod translation keyframe |
| `fan.py` | blades, radius, blade_width, hub_r | Animated via Z rotation keyframe |
| `cylinder.py` | radius, height, segments | Corrugated variant via displacement |
| `box.py` | w, d, h, rivet_spacing | Panel seams via edge loops + material |

## Scene Script Structure (`scenes/drill.py`)

```python
import bpy
import sys
sys.path.insert(0, "tools/blender")
from render import setup_scene, render_spritesheet
from prefabs import link_prefab

# Scene setup (camera, lights, render settings)
setup_scene(canvas=(64, 72), origin=(32, 55))

# Compose building from prefabs
body = link_prefab("box", w=2.0, d=2.0, h=0.8)
body.location = (0, 0, 0)

main_gear = link_prefab("cog", outer_radius=0.9, teeth=8)
main_gear.location = (1.1, 0.2, 0.4)

derrick = link_prefab("cylinder", radius=0.35, height=2.4)
derrick.location = (0, 0, 1.0)

piston = link_prefab("piston", sleeve_r=0.35, rod_r=0.15, sleeve_h=0.7)
piston.location = (-1.2, -0.6, 0.8)

# Animation keyframes for "active" tag (4 frames)
for frame_idx in range(4):
    bpy.context.scene.frame_set(frame_idx + 1)
    main_gear.rotation_euler.z = math.radians(72 * frame_idx)
    main_gear.keyframe_insert("rotation_euler", frame=frame_idx + 1)
    piston.pose_extend = oscillate(frame_idx, 0, 0.5, 4)
    piston.keyframe_insert("pose_extend", frame=frame_idx + 1)

# Render all frames for all tags and layers
render_spritesheet(
    output_dir="buildings/blender-drill/sprites",
    tags={
        "idle": {"frames": 1},
        "windup": {"frames": 2},
        "active": {"frames": 4},
        "winddown": {"frames": 2},
    },
    layers=["base", "top"],  # separate renders with different object visibility
)
```

## Layer Separation

Buildings need two layers (base draws under conveyor items, top draws over). In Blender:

- **Base layer render**: Only shadow catcher plane + bore hole interior objects visible
- **Top layer render**: Full building structure visible, shadow catcher hidden
- Two render passes per frame, output as separate PNGs
- Assembly script interleaves them into the spritesheet

## Palette Enforcement

All materials pull colors from `tools/palettes/buildings.lua`. A Python helper reads the Lua palette file and creates Blender materials:

```python
palette = load_palette("tools/palettes/buildings.lua")
mat_body = create_flat_material("body", palette["body"])       # #46372D
mat_steel = create_flat_material("steel", hex="#7A8898")
mat_outline = create_flat_material("outline", palette["outline"])  # #191412
```

Materials are emission-only (no Blender lighting influence) OR use a toon shader with 2-3 discrete shading steps to maintain pixel-art feel.

## Outline Rendering

Two options:

1. **Freestyle**: Blender's built-in edge rendering. Slow but accurate.
2. **Post-process**: Render Z-depth pass, detect edges in Python, draw outline color. Matches current Iso library approach.
3. **Inverted hull**: Duplicate mesh, flip normals, scale slightly, assign outline material. Fast, game-engine standard.

Start with option 2 (post-process) since it matches what we already do.

## Proof of Concept: `blender-drill`

Set up as a separate building to validate the pipeline without breaking the existing drill:

```
buildings/blender-drill/
├── blender-drill.tscn      # Same structure as drill.tscn
├── blender-drill.tres       # BuildingDef copy
├── blender_drill_logic.gd   # Extends extractor.gd (or reuses it)
└── sprites/
    ├── generate.py          # Blender scene script
    └── main.png             # Rendered spritesheet
```

### Validation Criteria

The blender-drill passes when:
1. Spritesheet has identical layout to Lua drill (same atlas regions, same tags)
2. Visual quality is equal or better (side-by-side comparison)
3. Gear rotation is clearly visible across active frames
4. Grid alignment matches (building centered on tile diamond)
5. All simulations pass with blender-drill substituted for drill
6. Generation time is under 30 seconds (Lua version is ~2s, some slowdown acceptable)

## Migration Plan

1. **Phase 1**: Core infrastructure (`render.py`, `materials/pixel_art.py`, 2 prefabs: box + cog)
2. **Phase 2**: blender-drill proof of concept, validate against Lua drill
3. **Phase 3**: If validated, migrate remaining buildings one by one
4. **Phase 4**: Deprecate Lua Iso library (keep as reference, stop using for new art)

## CLI Usage

```bash
BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"

# Generate a prefab
$BLENDER --background --python tools/blender/prefabs_src/cog.py

# Render a building
$BLENDER --background --python tools/blender/scenes/drill.py

# Render all buildings
python tools/blender/render_all.py
```

## What We Keep from Lua

- `tools/palettes/*.lua` — palette definitions (read by Python too)
- `tools/aseprite_helper.lua` — still useful for non-building sprites (items, UI, terrain)
- `tools/rendering/iso/` — reference implementation, not actively used for new buildings
