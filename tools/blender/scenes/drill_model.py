"""Export drill as a 3D model (.glb) for Godot import.

Composes the drill from prefabs and bakes NLA animations.
Demonstrates the full pipeline: prefabs, materials, anim_helpers.

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/drill_model.py

    # Custom output path:
    $BLENDER --background --python tools/blender/scenes/drill_model.py -- --output path/to/drill.glb
"""

import bpy
import os
import sys
import math

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BLENDER_DIR = os.path.normpath(os.path.join(SCRIPT_DIR, ".."))
REPO_ROOT = os.path.normpath(os.path.join(BLENDER_DIR, "..", ".."))
sys.path.insert(0, BLENDER_DIR)

from render import clear_scene
from materials.pixel_art import create_flat_material, load_palette
from texture_library import apply_texture
from prefabs_src.box import generate_box
from prefabs_src.cog import generate_cog
from prefabs_src.cylinder import generate_cylinder
from prefabs_src.cone import generate_cone
from prefabs_src.piston import generate_piston
from prefabs_src.pipe import generate_pipe
from prefabs_src.bolt import generate_bolt
from anim_helpers import (
    animate_rotation, animate_translation, animate_shake, animate_static,
    FPS,
)


def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []

    output = os.path.join(REPO_ROOT, "buildings", "drill", "models", "drill.glb")

    i = 0
    while i < len(argv):
        if argv[i] == "--output" and i + 1 < len(argv):
            output = argv[i + 1]; i += 2
        else:
            i += 1

    return output


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

# Animation constants
GEAR_RATIO = 8 / 6
PISTON_STROKE = 0.15


# ---------------------------------------------------------------------------
# Build the scene
# ---------------------------------------------------------------------------
def build_drill():
    """Build the full drill as a parented hierarchy under a root empty."""
    clear_scene()

    root = bpy.data.objects.new("Drill", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.5
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # -- Main housing: painted industrial panels --
    body = add(generate_box(w=2.0, d=2.0, h=0.8, hex_color=BODY_MAIN, seam_count=1))
    body.name = "Body"
    apply_texture(body, "painted_metal_shutter", resolution="1k")

    # -- Metal reinforcement band: clean plate --
    band = add(generate_box(w=2.1, d=2.1, h=0.2, hex_color=STEEL_DK))
    band.name = "Band"
    band.location = (0, 0, 0.3)
    apply_texture(band, "metal_plate", resolution="1k")

    # -- Roof plate: different metal for contrast --
    roof = add(generate_box(w=2.2, d=2.2, h=0.2, hex_color=BODY_ROOF))
    roof.name = "Roof"
    roof.location = (0, 0, 0.8)
    apply_texture(roof, "metal_plate_02", resolution="1k")

    # -- Bolts on roof corners --
    bolt_positions = [(0.9, 0.9), (-0.9, 0.9), (0.9, -0.9), (-0.9, -0.9)]
    for i, (bx, by) in enumerate(bolt_positions):
        b = generate_bolt(head_radius=0.06, head_height=0.04, hex_color=C["rivet"])
        b.name = f"Bolt_{i}"
        b.location = (bx, by, 1.0)
        add(b)

    # -- Main gear: machined steel --
    main_gear = add(generate_cog(outer_radius=0.9, inner_radius=0.5,
                                 teeth=8, thickness=0.3, hex_color=STEEL_LT))
    main_gear.name = "MainGear"
    main_gear.location = (1.1, 0.2, 0.4)
    apply_texture(main_gear, "metal_plate", resolution="1k")

    # -- Secondary gear --
    small_gear = add(generate_cog(outer_radius=0.5, inner_radius=0.35,
                                  teeth=6, thickness=0.3, hex_color=STEEL))
    small_gear.name = "SmallGear"
    small_gear.location = (1.1, -0.8, 0.4)
    apply_texture(small_gear, "metal_plate", resolution="1k")

    # -- Derrick column: tall steel column --
    derrick = add(generate_cylinder(radius=0.35, height=2.4, segments=12,
                                    hex_color=STEEL))
    derrick.name = "Derrick"
    derrick.location = (0, 0, 1.0)
    apply_texture(derrick, "metal_plate", resolution="1k")

    # -- Derrick cap --
    cap = add(generate_box(w=0.8, d=0.8, h=0.4, hex_color=BODY_LIGHT))
    cap.name = "DerrickCap"
    cap.location = (0, 0, 3.4)
    apply_texture(cap, "painted_metal_shutter", resolution="1k")

    # -- Cone tip --
    cone = add(generate_cone(radius_bottom=0.3, radius_top=0, height=0.4,
                             segments=8, hex_color=STEEL_LT))
    cone.name = "ConeTip"
    cone.location = (0, 0, 3.8)
    apply_texture(cone, "metal_plate", resolution="1k")

    # -- Piston assembly: machined parts --
    sleeve, rod = generate_piston(sleeve_r=0.35, rod_r=0.15, sleeve_h=1.5,
                                  hex_sleeve=STEEL, hex_rod=STEEL_DK)
    sleeve.name = "PistonSleeve"
    rod.name = "PistonRod"
    sleeve.location = (-1.2, -0.6, 0)
    add(sleeve)
    apply_texture(sleeve, "metal_plate", resolution="1k")
    apply_texture(rod, "metal_plate", resolution="1k")

    piston_head = generate_cylinder(radius=0.25, height=0.08, segments=12,
                                    hex_color=STEEL_DK)
    piston_head.name = "PistonHead"
    piston_head.location = (0, 0, 1.2)
    piston_head.parent = rod
    apply_texture(piston_head, "metal_plate", resolution="1k")

    # -- Connecting pipe: older, grimier --
    pipe = add(generate_pipe(length=0.6, radius=0.12, wall_thickness=0.03,
                             hex_color=C["pipe"]))
    pipe.name = "ConnectPipe"
    pipe.rotation_euler = (0, math.radians(90), 0)
    pipe.location = (-1.2, -0.6, 1.1)
    apply_texture(pipe, "rusty_metal_02", resolution="1k")

    # -- Exhaust stack: corrugated iron --
    exhaust = add(generate_cylinder(radius=0.25, height=0.8, segments=10,
                                    hex_color=C["pipe"]))
    exhaust.name = "ExhaustStack"
    exhaust.location = (-0.4, 1.0, 0.8)
    apply_texture(exhaust, "corrugated_iron", resolution="1k")

    # -- Exhaust cap: rusty top --
    exhaust_cap = add(generate_cylinder(radius=0.3, height=0.1, segments=10,
                                        hex_color=STEEL_DK))
    exhaust_cap.name = "ExhaustCap"
    exhaust_cap.location = (-0.4, 1.0, 1.6)
    apply_texture(exhaust_cap, "rusty_metal_02", resolution="1k")

    return {
        "root": root,
        "main_gear": main_gear,
        "small_gear": small_gear,
        "piston_rod": rod,
        "body": body,
        "band": band,
    }


# ---------------------------------------------------------------------------
# Animation — using anim_helpers
# ---------------------------------------------------------------------------
def bake_animations(objects):
    """Bake all animation states using high-level helpers."""
    mg = objects["main_gear"]
    sg = objects["small_gear"]
    rod = objects["piston_rod"]
    body = objects["body"]
    band = objects["band"]
    rod_base_z = rod.location.z

    # ── idle (2 sec): subtle gear wobble ──────────────────────────────
    animate_rotation(mg, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.03 * math.sin(t * math.pi * 2))
    animate_rotation(sg, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: -0.03 * GEAR_RATIO * math.sin(t * math.pi * 2))
    animate_static(rod, "idle", duration=2.0)

    # ── windup (1 sec): accelerating ──────────────────────────────────
    animate_rotation(mg, "windup", duration=1.0, axis='Z',
                     angle_fn=lambda t: t * t * math.pi * 2)
    animate_rotation(sg, "windup", duration=1.0, axis='Z',
                     angle_fn=lambda t: -t * t * math.pi * 2 * GEAR_RATIO)
    animate_translation(rod, "windup", duration=1.0, axis='Z',
                        value_fn=lambda t: rod_base_z - t * PISTON_STROKE)

    # ── active (2 sec): full speed, loops ─────────────────────────────
    animate_rotation(mg, "active", duration=2.0, axis='Z',
                     total_angle=math.pi * 4)
    animate_rotation(sg, "active", duration=2.0, axis='Z',
                     total_angle=-math.pi * 4 * GEAR_RATIO)
    animate_translation(rod, "active", duration=2.0, axis='Z',
                        value_fn=lambda t: rod_base_z - PISTON_STROKE * abs(math.sin(t * math.pi * 4)))
    animate_shake(body, "active", duration=2.0, amplitude=0.015, frequency=8)
    animate_shake(band, "active", duration=2.0, amplitude=0.015, frequency=8)

    # ── winddown (1 sec): decelerating ────────────────────────────────
    animate_rotation(mg, "winddown", duration=1.0, axis='Z',
                     angle_fn=lambda t: (2 * t - t * t) * math.pi * 2)
    animate_rotation(sg, "winddown", duration=1.0, axis='Z',
                     angle_fn=lambda t: -(2 * t - t * t) * math.pi * 2 * GEAR_RATIO)
    animate_translation(rod, "winddown", duration=1.0, axis='Z',
                        value_fn=lambda t: rod_base_z - PISTON_STROKE * (1 - t))
    animate_shake(body, "winddown", duration=1.0, amplitude=0.015, frequency=8, decay=1.0)
    animate_shake(band, "winddown", duration=1.0, amplitude=0.015, frequency=8, decay=1.0)


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------
def export_glb(output_path):
    """Select all and export as .glb with NLA animations."""
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_animation_mode='NLA_TRACKS',
        export_merge_animation='NLA_TRACK',
        export_animations=True,
    )


def export_blend(output_path):
    """Save the current scene as a .blend file."""
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=output_path)


def main():
    output = parse_args()
    print(f"[drill_model] Building drill, exporting to {output}")

    objects = build_drill()
    bake_animations(objects)
    export_glb(output)

    blend_path = os.path.splitext(output)[0] + ".blend"
    export_blend(blend_path)

    print(f"[drill_model] Done: {output}")
    print(f"[drill_model] Blend: {blend_path}")


if __name__ == "__main__":
    main()
