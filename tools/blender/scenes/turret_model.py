"""Export basic turret night-form as a 3D model (.glb) for Godot import.

Night form of 1x1 buildings like drills. Small gun/cannon on a rotating
cylindrical base. Scans for enemies and fires.

Animation states:
    idle (2s)   -- slow rotation (scanning for targets)
    active (2s) -- faster rotation, barrel recoil

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/turret_model.py
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
from prefabs_src.pipe import generate_pipe
from prefabs_src.bolt import generate_bolt
from prefabs_src.cog import generate_cog
from anim_helpers import (
    animate_rotation, animate_shake, animate_static, animate_translation, FPS,
)


def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []

    output = os.path.join(REPO_ROOT, "buildings", "drill", "models", "turret.glb")

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
NIGHT_GLOW     = "#CC4400"

STEEL_DK = "#6A7888"


# ---------------------------------------------------------------------------
# Build the scene
# ---------------------------------------------------------------------------
def build_turret():
    """Build a 1-tile basic turret -- night form of drills."""
    clear_scene()

    root = bpy.data.objects.new("Turret", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.25
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    CELL = 1.0
    BASE_H = 0.05
    HOUSING_H = 0.30
    TURRET_BASE_H = 0.06
    GUN_OFFSET_Z = BASE_H + HOUSING_H + TURRET_BASE_H

    # -- BASE PLATFORM --
    base = add(generate_box(w=1.1, d=1.1, h=BASE_H, hex_color=NIGHT_DARK))
    base.name = "BasePlatform"
    apply_texture(base, "metal_plate_02", resolution="1k")

    # Corner feet
    for i, (fx, fy) in enumerate([(-0.45, -0.45), (0.45, -0.45),
                                   (0.45, 0.45), (-0.45, 0.45)]):
        foot = add(generate_cylinder(radius=0.05, height=0.03, segments=8,
                                     hex_color=NIGHT_DARK))
        foot.name = f"Foot_{i}"
        foot.location = (fx, fy, -0.03)

    # -- MAIN HOUSING (short box body) --
    body = add(generate_box(w=0.90, d=0.90, h=HOUSING_H,
                            hex_color=NIGHT_BODY, seam_count=1))
    body.name = "Body"
    body.location = (0, 0, BASE_H)
    apply_texture(body, "painted_metal_shutter", resolution="1k")

    # Reinforcement band
    band = add(generate_box(w=0.95, d=0.95, h=0.04, hex_color=NIGHT_STEEL))
    band.name = "Band"
    band.location = (0, 0, BASE_H + 0.12)
    apply_texture(band, "metal_plate", resolution="1k")

    # Roof plate
    roof = add(generate_box(w=0.95, d=0.95, h=0.04, hex_color=NIGHT_BODY_LT))
    roof.name = "Roof"
    roof.location = (0, 0, BASE_H + HOUSING_H)
    apply_texture(roof, "metal_plate_02", resolution="1k")

    # -- ROTATING TURRET BASE (cylinder) --
    turret_base = add(generate_cylinder(radius=0.30, height=TURRET_BASE_H,
                                         segments=12, hex_color=NIGHT_STEEL))
    turret_base.name = "TurretBase"
    turret_base.location = (0, 0, BASE_H + HOUSING_H + 0.04)
    apply_texture(turret_base, "metal_plate", resolution="1k")

    # Turret rotation ring (decorative)
    turret_ring = add(generate_cylinder(radius=0.33, height=0.02,
                                         segments=12, hex_color=NIGHT_METAL))
    turret_ring.name = "TurretRing"
    turret_ring.location = (0, 0, BASE_H + HOUSING_H + 0.04)
    apply_texture(turret_ring, "metal_plate", resolution="1k")

    # -- GUN ASSEMBLY --
    # Gun cradle (small box that the pipe sits on)
    cradle = add(generate_box(w=0.14, d=0.20, h=0.10, hex_color=NIGHT_METAL))
    cradle.name = "GunCradle"
    cradle.location = (0, -0.05, GUN_OFFSET_Z)
    apply_texture(cradle, "metal_plate", resolution="1k")

    # Gun barrel (pipe pointing outward, slightly elevated)
    barrel = add(generate_pipe(length=0.50, radius=0.045, wall_thickness=0.012,
                               hex_color=NIGHT_METAL))
    barrel.name = "GunBarrel"
    barrel.rotation_euler = (math.radians(80), 0, 0)  # slightly upward
    barrel.location = (0, -0.20, GUN_OFFSET_Z + 0.05)
    apply_texture(barrel, "metal_plate", resolution="1k")

    # Muzzle ring (dark red accent)
    muzzle = add(generate_cylinder(radius=0.055, height=0.02, segments=10,
                                    hex_color=NIGHT_ACCENT))
    muzzle.name = "Muzzle"
    muzzle.rotation_euler = (math.radians(80), 0, 0)
    muzzle.location = (0, -0.69, GUN_OFFSET_Z + 0.135)

    # Muzzle glow
    muzzle_glow = add(generate_cylinder(radius=0.035, height=0.01, segments=8,
                                         hex_color=NIGHT_GLOW))
    muzzle_glow.name = "MuzzleGlow"
    muzzle_glow.rotation_euler = (math.radians(80), 0, 0)
    muzzle_glow.location = (0, -0.70, GUN_OFFSET_Z + 0.138)

    # -- AMMO BOX (on the side of turret base) --
    ammo_box = add(generate_box(w=0.15, d=0.12, h=0.10, hex_color=NIGHT_BODY))
    ammo_box.name = "AmmoBox"
    ammo_box.location = (0.20, 0.05, GUN_OFFSET_Z - 0.02)
    apply_texture(ammo_box, "painted_metal_shutter", resolution="1k")

    # -- SIDE GEAR (drive mechanism visible on body) --
    gear = add(generate_cog(outer_radius=0.18, inner_radius=0.12,
                            teeth=8, thickness=0.06, hex_color=NIGHT_METAL))
    gear.name = "DriveGear"
    gear.location = (0.48, 0, BASE_H + 0.18)
    apply_texture(gear, "metal_plate", resolution="1k")

    # Gear axle cap
    axle = add(generate_cylinder(radius=0.03, height=0.02, segments=8,
                                  hex_color=STEEL_DK))
    axle.name = "GearAxle"
    axle.location = (0.48, 0, BASE_H + 0.215)

    # -- BOLTS --
    bolt_positions = [
        # Roof corners
        (0.38, 0.38, BASE_H + HOUSING_H + 0.04),
        (-0.38, 0.38, BASE_H + HOUSING_H + 0.04),
        (0.38, -0.38, BASE_H + HOUSING_H + 0.04),
        (-0.38, -0.38, BASE_H + HOUSING_H + 0.04),
        # Band bolts
        (0.475, 0.30, BASE_H + 0.14),
        (0.475, -0.30, BASE_H + 0.14),
        (-0.475, 0.30, BASE_H + 0.14),
        (-0.475, -0.30, BASE_H + 0.14),
        # Turret ring bolts
    ]
    for i in range(6):
        angle = (i / 6) * 2 * math.pi
        bx = 0.31 * math.cos(angle)
        by = 0.31 * math.sin(angle)
        bolt_positions.append((bx, by, BASE_H + HOUSING_H + 0.06))

    for bi, (bx, by, bz) in enumerate(bolt_positions):
        b = add(generate_bolt(head_radius=0.015, head_height=0.01,
                              hex_color=C["rivet"]))
        b.name = f"Bolt_{bi}"
        b.location = (bx, by, bz)

    # -- HAZARD STRIPE --
    hazard = add(generate_box(w=0.92, d=0.92, h=0.012, hex_color=NIGHT_ACCENT))
    hazard.name = "HazardStripe"
    hazard.location = (0, 0, BASE_H + 0.01)

    return {
        "root": root,
        "body": body,
        "band": band,
        "roof": roof,
        "turret_base": turret_base,
        "turret_ring": turret_ring,
        "cradle": cradle,
        "barrel": barrel,
        "muzzle": muzzle,
        "muzzle_glow": muzzle_glow,
        "ammo_box": ammo_box,
        "gear": gear,
        "base": base,
    }


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------
def bake_animations(objects):
    """Bake all animation states."""
    body = objects["body"]
    band = objects["band"]
    roof = objects["roof"]
    turret_base = objects["turret_base"]
    turret_ring = objects["turret_ring"]
    cradle = objects["cradle"]
    barrel = objects["barrel"]
    muzzle = objects["muzzle"]
    muzzle_glow = objects["muzzle_glow"]
    ammo_box = objects["ammo_box"]
    gear = objects["gear"]
    base = objects["base"]

    # Group: turret top parts that rotate together
    turret_parts = [turret_base, turret_ring, cradle, barrel, muzzle,
                    muzzle_glow, ammo_box]

    # -- idle (2s): slow scanning rotation --
    animate_static(body, "idle", duration=2.0)
    animate_static(band, "idle", duration=2.0)
    animate_static(roof, "idle", duration=2.0)
    animate_static(base, "idle", duration=2.0)
    animate_rotation(gear, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.05 * math.sin(t * math.pi * 2))
    # Slow scan
    for part in turret_parts:
        animate_rotation(part, "idle", duration=2.0, axis='Z',
                         angle_fn=lambda t: 0.3 * math.sin(t * math.pi * 2))

    # -- active (2s): faster rotation + body shake from firing --
    animate_shake(body, "active", duration=2.0, amplitude=0.004, frequency=8)
    animate_shake(band, "active", duration=2.0, amplitude=0.003, frequency=8)
    animate_shake(roof, "active", duration=2.0, amplitude=0.003, frequency=8)
    animate_static(base, "active", duration=2.0)
    animate_rotation(gear, "active", duration=2.0, axis='Z',
                     total_angle=math.pi * 3)
    # Faster rotation (tracking targets)
    for part in turret_parts:
        animate_rotation(part, "active", duration=2.0, axis='Z',
                         angle_fn=lambda t: 0.6 * math.sin(t * math.pi * 4))


def main():
    output = parse_args()
    print(f"[turret_model] Building turret, exporting to {output}")

    objects = build_turret()
    bake_animations(objects)
    export_glb(output)

    print(f"[turret_model] Done: {output}")


if __name__ == "__main__":
    main()
