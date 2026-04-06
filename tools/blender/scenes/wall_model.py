"""Export wall night-form as a 3D model (.glb) for Godot import.

Night form of straight conveyors. Solid 1-tile-height barrier with
horizontal reinforcement bars. Sturdy, defensive appearance.

Animation states:
    idle (2s)   -- subtle vibration, combat ready
    active (2s) -- stronger shake (being hit / blocking)

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/wall_model.py
"""

import bpy
import os
import sys
import math

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BLENDER_DIR = os.path.normpath(os.path.join(SCRIPT_DIR, ".."))
REPO_ROOT = os.path.normpath(os.path.join(BLENDER_DIR, "..", ".."))
sys.path.insert(0, BLENDER_DIR)

from export_helpers import export_glb
from render import clear_scene
from materials.pixel_art import create_flat_material, load_palette
from texture_library import apply_texture
from prefabs_src.box import generate_box
from prefabs_src.cylinder import generate_cylinder
from prefabs_src.bolt import generate_bolt
from prefabs_src.cone import generate_cone
from anim_helpers import (
    animate_shake, animate_static, FPS,
)


def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []

    output = os.path.join(REPO_ROOT, "buildings", "conveyor", "models", "wall.glb")

    i = 0
    while i < len(argv):
        if argv[i] == "--output" and i + 1 < len(argv):
            output = argv[i + 1]; i += 2
        else:
            i += 1

    return output


# ---------------------------------------------------------------------------
# Colors -- night-mode darker, more aggressive palette
# ---------------------------------------------------------------------------
C = load_palette("buildings")

NIGHT_STEEL    = "#3A3040"
NIGHT_DARK     = "#2A2030"
NIGHT_METAL    = "#4A4050"
NIGHT_BODY     = "#3D2E38"
NIGHT_BODY_LT  = "#4E3E48"
NIGHT_ACCENT   = "#8B0000"
NIGHT_SPIKE    = "#5A4858"


# ---------------------------------------------------------------------------
# Build the scene
# ---------------------------------------------------------------------------
def build_wall():
    """Build a 1-tile defensive wall -- night form of straight conveyors."""
    clear_scene()

    root = bpy.data.objects.new("Wall", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.25
    # Root at origin — geometry centered on cell, matching conveyor model convention.
    root.location = (0, 0, 0)
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # Dimensions: 1 cell = 1.0 Blender units (scaled 0.5x in Godot)
    CELL = 1.0
    HALF = CELL / 2
    WALL_H = 0.50     # substantial wall height
    BASE_H = 0.05

    # -- BASE SLAB --
    base = add(generate_box(w=CELL, d=CELL, h=BASE_H, hex_color=NIGHT_DARK))
    base.name = "BaseSlab"
    apply_texture(base, "metal_plate_02", resolution="1k")

    # Corner feet
    for i, (fx, fy) in enumerate([(-0.4, -0.4), (0.4, -0.4),
                                   (0.4, 0.4), (-0.4, 0.4)]):
        foot = add(generate_cylinder(radius=0.05, height=0.03, segments=8,
                                     hex_color=NIGHT_DARK))
        foot.name = f"Foot_{i}"
        foot.location = (fx, fy, -0.03)

    # -- MAIN WALL BODY --
    # Solid box filling most of the cell
    body = add(generate_box(w=CELL * 0.90, d=CELL * 0.90, h=WALL_H,
                            hex_color=NIGHT_BODY, seam_count=2))
    body.name = "Body"
    body.location = (0, 0, BASE_H)
    apply_texture(body, "painted_metal_shutter", resolution="1k")

    # -- TOP CAP (reinforced ledge) --
    cap = add(generate_box(w=CELL * 0.95, d=CELL * 0.95, h=0.04,
                           hex_color=NIGHT_STEEL))
    cap.name = "TopCap"
    cap.location = (0, 0, BASE_H + WALL_H)
    apply_texture(cap, "metal_plate", resolution="1k")

    # -- LOWER REINFORCEMENT BAND --
    band_lo = add(generate_box(w=CELL * 0.925, d=CELL * 0.925, h=0.05,
                               hex_color=NIGHT_STEEL))
    band_lo.name = "BandLo"
    band_lo.location = (0, 0, BASE_H + 0.10)
    apply_texture(band_lo, "metal_plate", resolution="1k")

    # -- UPPER REINFORCEMENT BAND --
    band_hi = add(generate_box(w=CELL * 0.925, d=CELL * 0.925, h=0.05,
                               hex_color=NIGHT_STEEL))
    band_hi.name = "BandHi"
    band_hi.location = (0, 0, BASE_H + WALL_H - 0.10)
    apply_texture(band_hi, "metal_plate", resolution="1k")

    # -- CORNER POSTS (vertical pillars at corners) --
    POST_R = 0.035
    for i, (px, py) in enumerate([(-0.40, -0.40), (0.40, -0.40),
                                   (0.40, 0.40), (-0.40, 0.40)]):
        post = add(generate_cylinder(radius=POST_R, height=WALL_H + 0.04,
                                      segments=8, hex_color=NIGHT_STEEL))
        post.name = f"CornerPost_{i}"
        post.location = (px, py, BASE_H)
        apply_texture(post, "metal_plate", resolution="1k")

    # -- SPIKES (along top edge, 4 per side) --
    SPIKE_H = 0.065
    SPIKE_R = 0.018
    spike_y_pos = [-0.30, -0.10, 0.10, 0.30]
    for side_i, (sx_base, sy_base, axis) in enumerate([
        (0, -HALF * 0.95, 'x'),     # front
        (0, HALF * 0.95, 'x'),      # back
        (-HALF * 0.95, 0, 'y'),     # left
        (HALF * 0.95, 0, 'y'),      # right
    ]):
        for sp_i, sp_offset in enumerate(spike_y_pos):
            if axis == 'x':
                sx = sp_offset
                sy = sy_base
            else:
                sx = sx_base
                sy = sp_offset
            spike = add(generate_cone(radius_bottom=SPIKE_R, radius_top=0,
                                       height=SPIKE_H, segments=6,
                                       hex_color=NIGHT_SPIKE))
            spike.name = f"Spike_{side_i}_{sp_i}"
            spike.location = (sx, sy, BASE_H + WALL_H + 0.04)

    # -- BOLTS --
    bolt_positions = [
        # Top cap corners
        (0.35, 0.35, BASE_H + WALL_H + 0.04),
        (-0.35, 0.35, BASE_H + WALL_H + 0.04),
        (0.35, -0.35, BASE_H + WALL_H + 0.04),
        (-0.35, -0.35, BASE_H + WALL_H + 0.04),
        # Mid-wall bolts on front/back
        (-0.30, -0.46, BASE_H + 0.25),
        (0.30, -0.46, BASE_H + 0.25),
        (-0.30, 0.46, BASE_H + 0.25),
        (0.30, 0.46, BASE_H + 0.25),
        # Mid-wall bolts on sides
        (-0.46, -0.30, BASE_H + 0.25),
        (-0.46, 0.30, BASE_H + 0.25),
        (0.46, -0.30, BASE_H + 0.25),
        (0.46, 0.30, BASE_H + 0.25),
    ]
    for bi, (bx, by, bz) in enumerate(bolt_positions):
        b = add(generate_bolt(head_radius=0.018, head_height=0.012,
                              hex_color=C["rivet"]))
        b.name = f"Bolt_{bi}"
        b.location = (bx, by, bz)

    # -- HAZARD STRIPE --
    hazard = add(generate_box(w=CELL * 0.915, d=CELL * 0.915, h=0.015,
                              hex_color=NIGHT_ACCENT))
    hazard.name = "HazardStripe"
    hazard.location = (0, 0, BASE_H + 0.01)

    return {
        "root": root,
        "body": body,
        "cap": cap,
        "band_lo": band_lo,
        "band_hi": band_hi,
        "base": base,
    }


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------
def bake_animations(objects):
    """Bake all animation states."""
    body = objects["body"]
    cap = objects["cap"]
    band_lo = objects["band_lo"]
    band_hi = objects["band_hi"]
    base = objects["base"]

    # -- idle (2s): barely perceptible vibration --
    animate_shake(body, "idle", duration=2.0, amplitude=0.001, frequency=2)
    animate_shake(cap, "idle", duration=2.0, amplitude=0.001, frequency=2)
    animate_static(band_lo, "idle", duration=2.0)
    animate_static(band_hi, "idle", duration=2.0)
    animate_static(base, "idle", duration=2.0)

    # -- active (2s): stronger shake (taking hits) --
    animate_shake(body, "active", duration=2.0, amplitude=0.005, frequency=8)
    animate_shake(cap, "active", duration=2.0, amplitude=0.005, frequency=8)
    animate_shake(band_lo, "active", duration=2.0, amplitude=0.003, frequency=8)
    animate_shake(band_hi, "active", duration=2.0, amplitude=0.003, frequency=8)
    animate_static(base, "active", duration=2.0)


def main():
    output = parse_args()
    print(f"[wall_model] Building wall, exporting to {output}")

    objects = build_wall()
    bake_animations(objects)
    export_glb(output)

    print(f"[wall_model] Done: {output}")


if __name__ == "__main__":
    main()
