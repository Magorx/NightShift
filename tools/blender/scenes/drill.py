"""Drill/extractor building scene.

Composes a drill from prefabs and primitives, matching the Lua generate.lua
layout: 64x72 canvas, 2 layers (base, top), 9 frames:
  idle(1) + windup(2) + active(4) + winddown(2)

The gear rotates and piston pumps during active animation.

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/drill.py

    # Custom resolution:
    $BLENDER --background --python tools/blender/scenes/drill.py -- --width 128 --height 144
"""

import bpy
import os
import sys
import math

# Setup path for imports
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BLENDER_DIR = os.path.normpath(os.path.join(SCRIPT_DIR, ".."))
REPO_ROOT = os.path.normpath(os.path.join(BLENDER_DIR, "..", ".."))
sys.path.insert(0, BLENDER_DIR)

from render import setup_scene, render_frames, set_object_visibility
from materials.pixel_art import create_flat_material, load_palette
from prefabs_src.box import generate_box
from prefabs_src.cog import generate_cog
from prefabs_src.cylinder import generate_cylinder
from prefabs_src.piston import generate_piston
from prefabs_src.pipe import generate_pipe

# ---------------------------------------------------------------------------
# Parse CLI arguments (after --)
# ---------------------------------------------------------------------------
def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []

    width = 64
    height = 72
    output_dir = os.path.join(REPO_ROOT, "buildings", "blender-drill", "sprites", "frames")

    i = 0
    while i < len(argv):
        if argv[i] == "--width" and i + 1 < len(argv):
            width = int(argv[i + 1]); i += 2
        elif argv[i] == "--height" and i + 1 < len(argv):
            height = int(argv[i + 1]); i += 2
        elif argv[i] == "--output" and i + 1 < len(argv):
            output_dir = argv[i + 1]; i += 2
        else:
            i += 1

    return width, height, output_dir


# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
C = load_palette("buildings")

STEEL      = "#7A8898"
STEEL_DK   = "#6A7888"
STEEL_LT   = "#96A4B4"
BODY_MAIN  = "#5A4838"
BODY_LIGHT = "#6E5A48"
BODY_ROOF  = "#7A6854"

# ---------------------------------------------------------------------------
# Animation tags — matches the Lua drill exactly
# ---------------------------------------------------------------------------
TAGS = {
    "idle":     {"frames": 1},
    "windup":   {"frames": 2},
    "active":   {"frames": 4},
    "winddown": {"frames": 2},
}

# ---------------------------------------------------------------------------
# Animation parameters per tag
# ---------------------------------------------------------------------------
def anim_params(tag, frame_idx):
    """Return (gear_angle_rad, piston_extend, shake_x, shake_y)."""
    total = TAGS[tag]["frames"]
    phase = frame_idx / max(total - 1, 1)  # 0..1

    gear_angle = 0.0
    piston_ext = 0.0
    shake_x = 0.0
    shake_y = 0.0

    if tag == "idle":
        gear_angle = phase * 0.05
    elif tag == "windup":
        gear_angle = phase * 0.5
        piston_ext = phase * 0.15
    elif tag == "active":
        # Full rotation over 4 frames: each frame = 90°
        gear_angle = (frame_idx / 4) * 2 * math.pi
        # Oscillating piston
        piston_ext = 0.3 * math.sin(frame_idx * math.pi / 2)
        # Subtle shake
        shake_x = 0.02 * math.sin(frame_idx * math.pi)
        shake_y = 0.01 * math.cos(frame_idx * math.pi * 1.5)
    elif tag == "winddown":
        gear_angle = math.pi + phase * 0.15
        piston_ext = (1 - phase) * 0.15

    return gear_angle, piston_ext, shake_x, shake_y


# ---------------------------------------------------------------------------
# Build the scene
# ---------------------------------------------------------------------------
def build_drill(width, height):
    """Construct the drill scene. Returns dict of named objects for animation."""
    # Ortho scale tuned so the drill fills ~64x72 viewport
    # Scale proportionally if resolution differs from 64x72
    base_ortho = 4.0
    scale_factor = max(width / 64, height / 72)
    ortho_scale = base_ortho * scale_factor

    cam = setup_scene(width=width, height=height, ortho_scale=ortho_scale)

    objects = {}

    # -- Ground shadow (base layer only) --
    shadow = generate_box(w=2.4, d=2.4, h=0.05, hex_color=C["shadow"])
    shadow.name = "Shadow"
    shadow.location = (0, 0, -0.05)
    objects["shadow"] = shadow

    # -- Bore hole disc (base layer only) --
    bore = generate_cylinder(radius=0.3, height=0.02, segments=12,
                             hex_color=C["bore_deep"])
    bore.name = "BoreHole"
    bore.location = (0, 0, -0.02)
    objects["bore"] = bore

    # -- Main housing --
    body = generate_box(w=2.0, d=2.0, h=0.8, hex_color=BODY_MAIN, seam_count=1)
    body.name = "Body"
    body.location = (0, 0, 0)
    objects["body"] = body

    # -- Metal reinforcement band --
    band = generate_box(w=2.1, d=2.1, h=0.2, hex_color=STEEL_DK)
    band.name = "Band"
    band.location = (0, 0, 0.3)
    objects["band"] = band

    # -- Roof plate --
    roof = generate_box(w=2.2, d=2.2, h=0.2, hex_color=BODY_ROOF)
    roof.name = "Roof"
    roof.location = (0, 0, 0.8)
    objects["roof"] = roof

    # -- Main gear (front-right) --
    main_gear = generate_cog(outer_radius=0.9, inner_radius=0.5,
                             teeth=8, thickness=0.3, hex_color=STEEL_LT)
    main_gear.name = "MainGear"
    main_gear.location = (1.1, 0.2, 0.4)
    objects["main_gear"] = main_gear

    # -- Secondary gear (smaller, interlocked) --
    small_gear = generate_cog(outer_radius=0.5, inner_radius=0.35,
                              teeth=6, thickness=0.3, hex_color=STEEL)
    small_gear.name = "SmallGear"
    small_gear.location = (1.1, -0.8, 0.4)
    objects["small_gear"] = small_gear

    # -- Derrick column --
    derrick = generate_cylinder(radius=0.35, height=2.4, segments=12,
                                hex_color=STEEL)
    derrick.name = "Derrick"
    derrick.location = (0, 0, 1.0)
    objects["derrick"] = derrick

    # -- Derrick cap --
    cap = generate_box(w=0.8, d=0.8, h=0.4, hex_color=BODY_LIGHT)
    cap.name = "DerrickCap"
    cap.location = (0, 0, 3.4)
    objects["derrick_cap"] = cap

    # -- Cone tip --
    bpy.ops.mesh.primitive_cone_add(radius1=0.3, radius2=0, depth=0.4,
                                    vertices=8, location=(0, 0, 4.0))
    cone = bpy.context.active_object
    cone.name = "ConeTip"
    mat_cone = create_flat_material("ConeMat", STEEL_LT)
    cone.data.materials.append(mat_cone)
    for poly in cone.data.polygons:
        poly.use_smooth = False
    objects["cone"] = cone

    # -- Piston (left-front) --
    sleeve, rod = generate_piston(sleeve_r=0.35, rod_r=0.15, sleeve_h=0.7,
                                  hex_sleeve=STEEL_DK, hex_rod=STEEL_LT)
    sleeve.name = "PistonSleeve"
    rod.name = "PistonRod"
    sleeve.location = (-1.2, -0.6, 0.8)
    objects["piston_sleeve"] = sleeve
    objects["piston_rod"] = rod

    # -- Connecting pipe --
    pipe = generate_pipe(length=0.6, radius=0.12, wall_thickness=0.03,
                         hex_color=C["pipe"])
    pipe.name = "ConnectPipe"
    # Rotate to lie along X axis
    pipe.rotation_euler = (0, math.radians(90), 0)
    pipe.location = (-1.2, -0.6, 1.1)
    objects["pipe"] = pipe

    # -- Exhaust stack --
    exhaust = generate_cylinder(radius=0.25, height=0.8, segments=10,
                                hex_color=C["pipe"])
    exhaust.name = "ExhaustStack"
    exhaust.location = (-0.4, 1.0, 0.8)
    objects["exhaust"] = exhaust

    # -- Exhaust cap --
    exhaust_cap = generate_cylinder(radius=0.3, height=0.1, segments=10,
                                    hex_color=STEEL_DK)
    exhaust_cap.name = "ExhaustCap"
    exhaust_cap.location = (-0.4, 1.0, 1.6)
    objects["exhaust_cap"] = exhaust_cap

    # Classify objects into layers
    objects["_base_objects"] = ["shadow", "bore"]
    objects["_top_objects"] = [k for k in objects if k not in ("shadow", "bore")
                               and not k.startswith("_")]

    return objects


# ---------------------------------------------------------------------------
# Frame callback: animation + layer visibility
# ---------------------------------------------------------------------------
def make_frame_callback(objects):
    """Create a callback for render_frames that handles animation and visibility."""

    base_names = objects["_base_objects"]
    top_names = objects["_top_objects"]
    all_names = base_names + top_names

    # Store original rod Z for piston animation
    rod = objects["piston_rod"]
    rod_base_z = rod.location.z

    def callback(tag, frame_idx, layer):
        gear_angle, piston_ext, shake_x, shake_y = anim_params(tag, frame_idx)

        # Animate gear rotation
        objects["main_gear"].rotation_euler.z = gear_angle
        # Counter-rotating small gear (gear ratio 9:5 approximation)
        objects["small_gear"].rotation_euler.z = -gear_angle * (9.0 / 6.0) + 0.4

        # Animate piston
        rod.location.z = rod_base_z + piston_ext

        # Apply shake to body group
        for name in ["body", "band", "roof"]:
            obj = objects[name]
            obj.location.x = shake_x
            obj.location.y = shake_y

        # Layer visibility
        if layer == "base":
            for name in all_names:
                obj = objects.get(name)
                if obj:
                    set_object_visibility(obj, name in base_names)
        elif layer == "top":
            for name in all_names:
                obj = objects.get(name)
                if obj:
                    set_object_visibility(obj, name in top_names)

    return callback


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    width, height, output_dir = parse_args()
    print(f"[drill] Rendering {width}x{height} to {output_dir}")

    objects = build_drill(width, height)
    callback = make_frame_callback(objects)

    render_frames(
        output_dir=output_dir,
        tags=TAGS,
        layers=["base", "top"],
        frame_callback=callback,
    )

    print(f"[drill] Done. Frames written to {output_dir}")


if __name__ == "__main__":
    main()
