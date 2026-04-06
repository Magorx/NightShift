"""Export tower night-form as a 3D model (.glb) for Godot import.

Night form of turn conveyors. 2-tile height watchtower with observation
platform at the top and crenellations at the corners.

Animation states:
    idle (2s)   -- subtle observation platform rotation (slow scan)
    active (2s) -- faster scan, body shake (spotting enemies)

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/tower_model.py
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
from prefabs_src.cone import generate_cone
from prefabs_src.bolt import generate_bolt
from anim_helpers import (
    animate_rotation, animate_shake, animate_static, FPS,
)


def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []

    output = os.path.join(REPO_ROOT, "buildings", "conveyor", "models", "tower.glb")

    i = 0
    while i < len(argv):
        if argv[i] == "--output" and i + 1 < len(argv):
            output = argv[i + 1]; i += 2
        else:
            i += 1

    return output


# ---------------------------------------------------------------------------
# Colors -- night-mode palette
# ---------------------------------------------------------------------------
C = load_palette("buildings")

NIGHT_STEEL    = "#3A3040"
NIGHT_DARK     = "#2A2030"
NIGHT_METAL    = "#4A4050"
NIGHT_BODY     = "#3D2E38"
NIGHT_BODY_LT  = "#4E3E48"
NIGHT_ACCENT   = "#8B0000"
NIGHT_SPIKE    = "#5A4858"
NIGHT_GLOW     = "#CC4400"


# ---------------------------------------------------------------------------
# Build the scene
# ---------------------------------------------------------------------------
def build_tower():
    """Build a 1-tile watchtower -- night form of turn conveyors."""
    clear_scene()

    root = bpy.data.objects.new("Tower", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.25
    # Root at origin — geometry centered on cell, matching conveyor model convention.
    root.location = (0, 0, 0)
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    CELL = 1.0
    HALF = CELL / 2
    BASE_H = 0.05
    TOWER_BODY_H = 0.70   # tall tower body (roughly 2 tile-heights of visual)
    PLATFORM_H = 0.06
    CREN_H = 0.12         # crenellation height

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

    # -- TOWER BODY (slightly tapered: wider at base, narrower at top) --
    # Lower section (wider)
    body_lower = add(generate_box(w=0.85, d=0.85, h=TOWER_BODY_H * 0.5,
                                   hex_color=NIGHT_BODY, seam_count=2))
    body_lower.name = "BodyLower"
    body_lower.location = (0, 0, BASE_H)
    apply_texture(body_lower, "painted_metal_shutter", resolution="1k")

    # Upper section (narrower for tapered look)
    body_upper = add(generate_box(w=0.75, d=0.75, h=TOWER_BODY_H * 0.5,
                                   hex_color=NIGHT_BODY_LT, seam_count=1))
    body_upper.name = "BodyUpper"
    body_upper.location = (0, 0, BASE_H + TOWER_BODY_H * 0.5)
    apply_texture(body_upper, "painted_metal_shutter", resolution="1k")

    # -- REINFORCEMENT BANDS --
    # Low band
    band_lo = add(generate_box(w=0.875, d=0.875, h=0.04, hex_color=NIGHT_STEEL))
    band_lo.name = "BandLo"
    band_lo.location = (0, 0, BASE_H + 0.08)
    apply_texture(band_lo, "metal_plate", resolution="1k")

    # Mid band (at the taper junction)
    band_mid = add(generate_box(w=0.80, d=0.80, h=0.05, hex_color=NIGHT_STEEL))
    band_mid.name = "BandMid"
    band_mid.location = (0, 0, BASE_H + TOWER_BODY_H * 0.5)
    apply_texture(band_mid, "metal_plate", resolution="1k")

    # Upper band
    band_hi = add(generate_box(w=0.775, d=0.775, h=0.04, hex_color=NIGHT_STEEL))
    band_hi.name = "BandHi"
    band_hi.location = (0, 0, BASE_H + TOWER_BODY_H - 0.06)
    apply_texture(band_hi, "metal_plate", resolution="1k")

    # -- OBSERVATION PLATFORM (rotating) --
    platform_z = BASE_H + TOWER_BODY_H
    platform = add(generate_box(w=0.90, d=0.90, h=PLATFORM_H,
                                hex_color=NIGHT_METAL))
    platform.name = "Platform"
    platform.location = (0, 0, platform_z)
    apply_texture(platform, "metal_plate_02", resolution="1k")

    # -- CRENELLATIONS (4 corner pillars on top of platform) --
    cren_w = 0.10
    cren_positions = [
        (-0.375, -0.375), (0.375, -0.375),
        (0.375, 0.375), (-0.375, 0.375),
    ]
    for ci, (cx, cy) in enumerate(cren_positions):
        cren = add(generate_box(w=cren_w, d=cren_w, h=CREN_H,
                                hex_color=NIGHT_STEEL))
        cren.name = f"Cren_{ci}"
        cren.location = (cx, cy, platform_z + PLATFORM_H)
        apply_texture(cren, "metal_plate", resolution="1k")

        # Spike on top of each crenellation
        spike = add(generate_cone(radius_bottom=0.025, radius_top=0,
                                   height=0.05, segments=6,
                                   hex_color=NIGHT_SPIKE))
        spike.name = f"CrenSpike_{ci}"
        spike.location = (cx, cy, platform_z + PLATFORM_H + CREN_H)

    # -- LOW WALLS between crenellations (battlement look) --
    low_wall_h = CREN_H * 0.5
    for lw_i, (x1, y1, x2, y2) in enumerate([
        (-0.375, -0.375, 0.375, -0.375),  # front
        (0.375, -0.375, 0.375, 0.375),    # right
        (0.375, 0.375, -0.375, 0.375),    # back
        (-0.375, 0.375, -0.375, -0.375),  # left
    ]):
        mx = (x1 + x2) / 2
        my = (y1 + y2) / 2
        lw_w = abs(x2 - x1) if abs(x2 - x1) > 0.01 else 0.04
        lw_d = abs(y2 - y1) if abs(y2 - y1) > 0.01 else 0.04
        # Adjust to not overlap with crenellations
        if lw_w > 0.5:
            lw_w -= cren_w * 2
        if lw_d > 0.5:
            lw_d -= cren_w * 2
        low_wall = add(generate_box(w=lw_w, d=lw_d, h=low_wall_h,
                                     hex_color=NIGHT_BODY_LT))
        low_wall.name = f"LowWall_{lw_i}"
        low_wall.location = (mx, my, platform_z + PLATFORM_H)

    # -- CENTRAL LOOKOUT POST (on platform) --
    lookout = add(generate_cylinder(radius=0.10, height=0.12, segments=8,
                                     hex_color=NIGHT_METAL))
    lookout.name = "Lookout"
    lookout.location = (0, 0, platform_z + PLATFORM_H)
    apply_texture(lookout, "metal_plate", resolution="1k")

    # Lookout dome
    lookout_dome = add(generate_cone(radius_bottom=0.12, radius_top=0.04,
                                      height=0.08, segments=8,
                                      hex_color=NIGHT_BODY_LT))
    lookout_dome.name = "LookoutDome"
    lookout_dome.location = (0, 0, platform_z + PLATFORM_H + 0.12)

    # Searchlight lens (small glowing disc facing outward)
    lens = add(generate_cylinder(radius=0.03, height=0.015, segments=8,
                                  hex_color=NIGHT_GLOW))
    lens.name = "SearchlightLens"
    lens.rotation_euler = (math.radians(90), 0, 0)
    lens.location = (0, -0.13, platform_z + PLATFORM_H + 0.08)

    # -- VERTICAL SUPPORT RIBS on tower body --
    RIB_D = 0.015
    rib_x_pos = [-0.30, 0.30]
    for side_i, (face_x, face_y, orient) in enumerate([
        (0, -0.43, 'x'),   # front
        (0, 0.43, 'x'),    # back
        (-0.43, 0, 'y'),   # left
        (0.43, 0, 'y'),    # right
    ]):
        for ri, offset in enumerate(rib_x_pos):
            if orient == 'x':
                rx = offset
                ry = face_y
            else:
                rx = face_x
                ry = offset
            rib = add(generate_box(w=RIB_D, d=RIB_D, h=TOWER_BODY_H * 0.45,
                                    hex_color=NIGHT_STEEL))
            rib.name = f"Rib_{side_i}_{ri}"
            rib.location = (rx, ry, BASE_H + TOWER_BODY_H * 0.02)

    # -- BOLTS --
    bolt_positions = [
        # Band bolts (lower)
        (-0.38, -0.44, BASE_H + 0.10),
        (0.38, -0.44, BASE_H + 0.10),
        (-0.38, 0.44, BASE_H + 0.10),
        (0.38, 0.44, BASE_H + 0.10),
        # Mid band bolts
        (-0.35, -0.41, BASE_H + TOWER_BODY_H * 0.5),
        (0.35, -0.41, BASE_H + TOWER_BODY_H * 0.5),
        (-0.35, 0.41, BASE_H + TOWER_BODY_H * 0.5),
        (0.35, 0.41, BASE_H + TOWER_BODY_H * 0.5),
        # Platform bolts
        (-0.38, -0.38, platform_z + PLATFORM_H),
        (0.38, -0.38, platform_z + PLATFORM_H),
        (-0.38, 0.38, platform_z + PLATFORM_H),
        (0.38, 0.38, platform_z + PLATFORM_H),
    ]
    for bi, (bx, by, bz) in enumerate(bolt_positions):
        b = add(generate_bolt(head_radius=0.016, head_height=0.01,
                              hex_color=C["rivet"]))
        b.name = f"Bolt_{bi}"
        b.location = (bx, by, bz)

    # -- HAZARD STRIPE --
    hazard = add(generate_box(w=0.86, d=0.86, h=0.012, hex_color=NIGHT_ACCENT))
    hazard.name = "HazardStripe"
    hazard.location = (0, 0, BASE_H + 0.01)

    return {
        "root": root,
        "body_lower": body_lower,
        "body_upper": body_upper,
        "platform": platform,
        "lookout": lookout,
        "lookout_dome": lookout_dome,
        "lens": lens,
        "band_lo": band_lo,
        "band_mid": band_mid,
        "base": base,
    }


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------
def bake_animations(objects):
    """Bake all animation states."""
    body_lower = objects["body_lower"]
    body_upper = objects["body_upper"]
    platform = objects["platform"]
    lookout = objects["lookout"]
    lookout_dome = objects["lookout_dome"]
    lens = objects["lens"]
    band_lo = objects["band_lo"]
    band_mid = objects["band_mid"]
    base = objects["base"]

    # -- idle (2s): slow observation scan --
    animate_static(body_lower, "idle", duration=2.0)
    animate_static(body_upper, "idle", duration=2.0)
    animate_static(base, "idle", duration=2.0)
    animate_static(band_lo, "idle", duration=2.0)
    animate_static(band_mid, "idle", duration=2.0)
    # Platform rotates slowly back and forth (scanning)
    animate_rotation(platform, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.15 * math.sin(t * math.pi * 2))
    animate_rotation(lookout, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.15 * math.sin(t * math.pi * 2))
    animate_rotation(lookout_dome, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.15 * math.sin(t * math.pi * 2))
    animate_rotation(lens, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.15 * math.sin(t * math.pi * 2))

    # -- active (2s): faster scan, tower vibrates (alert) --
    animate_shake(body_lower, "active", duration=2.0, amplitude=0.003, frequency=6)
    animate_shake(body_upper, "active", duration=2.0, amplitude=0.004, frequency=6)
    animate_static(base, "active", duration=2.0)
    animate_shake(band_lo, "active", duration=2.0, amplitude=0.002, frequency=6)
    animate_shake(band_mid, "active", duration=2.0, amplitude=0.002, frequency=6)
    # Faster platform rotation (actively tracking)
    animate_rotation(platform, "active", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.4 * math.sin(t * math.pi * 4))
    animate_rotation(lookout, "active", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.4 * math.sin(t * math.pi * 4))
    animate_rotation(lookout_dome, "active", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.4 * math.sin(t * math.pi * 4))
    animate_rotation(lens, "active", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.4 * math.sin(t * math.pi * 4))


def main():
    output = parse_args()
    print(f"[tower_model] Building tower, exporting to {output}")

    objects = build_tower()
    bake_animations(objects)
    export_glb(output)

    print(f"[tower_model] Done: {output}")


if __name__ == "__main__":
    main()
