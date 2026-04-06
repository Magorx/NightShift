"""Export rocket turret night-form as a 3D model (.glb) for Godot import.

Night form of smelter (larger, more imposing). Launcher platform with
a cluster of 4 tube barrels angled upward for area bombardment.

Animation states:
    idle (2s)   -- slow scan rotation, subtle hum
    active (2s) -- faster scan, recoil/fire cycle, body shake

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/rocket_turret_model.py
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
from prefabs_src.wedge import generate_wedge
from anim_helpers import (
    animate_rotation, animate_shake, animate_static, animate_translation, FPS,
)


def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []

    output = os.path.join(REPO_ROOT, "buildings", "smelter", "models",
                          "rocket_turret.glb")

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
NIGHT_SPIKE    = "#5A4858"

COPPER_DK  = "#8B5A2B"
STEEL_DK   = "#6A7888"


# ---------------------------------------------------------------------------
# Build the scene
# ---------------------------------------------------------------------------
def build_rocket_turret():
    """Build the rocket turret -- night form of smelter.

    Smelter occupies an L-shaped footprint: 3 cells.
    The rocket turret uses the same L-shape with a heavy launcher platform.
    """
    clear_scene()

    root = bpy.data.objects.new("RocketTurret", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.25
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # -- L-SHAPED BASE PLATFORM --
    # Top row: 2 cells from X=-1 to X=1, Y=0 to Y=1
    base_top = add(generate_box(w=1.9, d=0.9, h=0.06, hex_color=NIGHT_STEEL))
    base_top.name = "BasePlatformTop"
    base_top.location = (0, 0.5, 0)
    apply_texture(base_top, "metal_plate_02", resolution="1k")

    # Bottom-left: 1 cell from X=-1 to X=0, Y=-1 to Y=0
    base_left = add(generate_box(w=0.9, d=1.0, h=0.06, hex_color=NIGHT_STEEL))
    base_left.name = "BasePlatformLeft"
    base_left.location = (-0.5, -0.45, 0)
    apply_texture(base_left, "metal_plate_02", resolution="1k")

    # Corner feet
    for i, (fx, fy) in enumerate([(-0.85, 0.85), (0.85, 0.85),
                                   (-0.85, -0.85), (-0.05, -0.85),
                                   (0.85, 0.15), (-0.05, 0.15)]):
        foot = add(generate_cylinder(radius=0.05, height=0.03, segments=8,
                                     hex_color=NIGHT_DARK))
        foot.name = f"Foot_{i}"
        foot.location = (fx, fy, -0.03)

    # -- L-SHAPED MAIN HOUSING --
    body_top = add(generate_box(w=1.7, d=0.8, h=0.40, hex_color=NIGHT_BODY,
                                seam_count=2))
    body_top.name = "BodyTop"
    body_top.location = (0, 0.5, 0.06)
    apply_texture(body_top, "painted_metal_shutter", resolution="1k")

    body_left = add(generate_box(w=0.8, d=0.85, h=0.40, hex_color=NIGHT_BODY,
                                 seam_count=2))
    body_left.name = "BodyLeft"
    body_left.location = (-0.5, -0.475, 0.06)
    apply_texture(body_left, "painted_metal_shutter", resolution="1k")

    # Reinforcement bands
    band_lo_top = add(generate_box(w=1.75, d=0.85, h=0.04, hex_color=NIGHT_STEEL))
    band_lo_top.name = "BandLoTop"
    band_lo_top.location = (0, 0.5, 0.10)
    apply_texture(band_lo_top, "metal_plate", resolution="1k")

    band_lo_left = add(generate_box(w=0.85, d=0.9, h=0.04, hex_color=NIGHT_STEEL))
    band_lo_left.name = "BandLoLeft"
    band_lo_left.location = (-0.5, -0.475, 0.10)
    apply_texture(band_lo_left, "metal_plate", resolution="1k")

    band_hi_top = add(generate_box(w=1.75, d=0.85, h=0.04, hex_color=NIGHT_STEEL))
    band_hi_top.name = "BandHiTop"
    band_hi_top.location = (0, 0.5, 0.40)
    apply_texture(band_hi_top, "metal_plate", resolution="1k")

    band_hi_left = add(generate_box(w=0.85, d=0.9, h=0.04, hex_color=NIGHT_STEEL))
    band_hi_left.name = "BandHiLeft"
    band_hi_left.location = (-0.5, -0.475, 0.40)
    apply_texture(band_hi_left, "metal_plate", resolution="1k")

    # Roof plates
    roof_top = add(generate_box(w=1.75, d=0.85, h=0.05, hex_color=NIGHT_BODY_LT))
    roof_top.name = "RoofTop"
    roof_top.location = (0, 0.5, 0.46)
    apply_texture(roof_top, "metal_plate_02", resolution="1k")

    roof_left = add(generate_box(w=0.85, d=0.9, h=0.05, hex_color=NIGHT_BODY_LT))
    roof_left.name = "RoofLeft"
    roof_left.location = (-0.5, -0.475, 0.46)
    apply_texture(roof_left, "metal_plate_02", resolution="1k")

    # -- HAZARD STRIPES --
    hazard_top = add(generate_box(w=1.725, d=0.825, h=0.015, hex_color=NIGHT_ACCENT))
    hazard_top.name = "HazardStripeTop"
    hazard_top.location = (0, 0.5, 0.075)

    hazard_left = add(generate_box(w=0.825, d=0.875, h=0.015, hex_color=NIGHT_ACCENT))
    hazard_left.name = "HazardStripeLeft"
    hazard_left.location = (-0.5, -0.475, 0.075)

    # -- LAUNCHER PEDESTAL (on top-left cell: -0.5, 0.5) --
    pedestal = add(generate_cylinder(radius=0.25, height=0.08, segments=12,
                                      hex_color=NIGHT_STEEL))
    pedestal.name = "LauncherPedestal"
    pedestal.location = (-0.5, 0.5, 0.51)
    apply_texture(pedestal, "metal_plate", resolution="1k")

    # Rotation ring
    launcher_ring = add(generate_cylinder(radius=0.28, height=0.02, segments=12,
                                           hex_color=NIGHT_METAL))
    launcher_ring.name = "LauncherRing"
    launcher_ring.location = (-0.5, 0.5, 0.52)
    apply_texture(launcher_ring, "metal_plate", resolution="1k")

    # -- LAUNCHER PLATFORM (box on pedestal) --
    launcher_platform = add(generate_box(w=0.40, d=0.35, h=0.08,
                                          hex_color=NIGHT_BODY_LT))
    launcher_platform.name = "LauncherPlatform"
    launcher_platform.location = (-0.5, 0.5, 0.59)
    apply_texture(launcher_platform, "metal_plate", resolution="1k")

    # -- ROCKET TUBES (4 pipes angled upward in a 2x2 cluster) --
    TUBE_LEN = 0.40
    TUBE_R = 0.055
    TUBE_WALL = 0.012
    TUBE_ANGLE = 30  # degrees from vertical (tilted forward)
    tube_offsets = [(-0.07, -0.07), (0.07, -0.07),
                    (-0.07, 0.07), (0.07, 0.07)]
    tubes = []
    for ti, (tx, ty) in enumerate(tube_offsets):
        tube = add(generate_pipe(length=TUBE_LEN, radius=TUBE_R,
                                  wall_thickness=TUBE_WALL,
                                  hex_color=NIGHT_METAL))
        tube.name = f"RocketTube_{ti}"
        tube.location = (-0.5 + tx, 0.5 + ty, 0.67)
        tube.rotation_euler = (math.radians(TUBE_ANGLE), 0, 0)
        apply_texture(tube, "metal_plate", resolution="1k")
        tubes.append(tube)

        # Tube muzzle ring
        muzzle_ring = add(generate_cylinder(radius=TUBE_R + 0.01, height=0.015,
                                             segments=8, hex_color=NIGHT_ACCENT))
        muzzle_ring.name = f"TubeMuzzle_{ti}"
        # Position at the end of the angled tube
        mz_y_off = -TUBE_LEN * 0.5 * math.sin(math.radians(TUBE_ANGLE))
        mz_z_off = TUBE_LEN * 0.5 * math.cos(math.radians(TUBE_ANGLE))
        muzzle_ring.location = (-0.5 + tx, 0.5 + ty + mz_y_off,
                                0.67 + mz_z_off)
        muzzle_ring.rotation_euler = (math.radians(TUBE_ANGLE), 0, 0)

    # -- TUBE CLUSTER BRACE (holds the 4 tubes together) --
    brace = add(generate_box(w=0.24, d=0.24, h=0.03, hex_color=NIGHT_STEEL))
    brace.name = "TubeBrace"
    brace.location = (-0.5, 0.5, 0.72)
    apply_texture(brace, "metal_plate", resolution="1k")

    # -- AMMO FEED (from bottom-left cell to launcher) --
    ammo_vert = add(generate_pipe(length=0.20, radius=0.03, wall_thickness=0.008,
                                   hex_color=COPPER_DK))
    ammo_vert.name = "AmmoVertPipe"
    ammo_vert.location = (-0.3, 0.1, 0.35)
    apply_texture(ammo_vert, "rusty_metal_02", resolution="1k")

    ammo_horiz = add(generate_pipe(length=0.15, radius=0.025, wall_thickness=0.007,
                                    hex_color=COPPER_DK))
    ammo_horiz.name = "AmmoHorizPipe"
    ammo_horiz.rotation_euler = (0, math.radians(90), 0)
    ammo_horiz.location = (-0.35, 0.2, 0.48)
    apply_texture(ammo_horiz, "rusty_metal_02", resolution="1k")

    # -- INPUT HOPPERS (ammo intake on bottom-left and top-right cells) --
    hopper_l = add(generate_cone(radius_bottom=0.06, radius_top=0.11,
                                  height=0.18, segments=8,
                                  hex_color=NIGHT_METAL))
    hopper_l.name = "HopperLeft"
    hopper_l.location = (-0.8, -0.5, 0.28)
    apply_texture(hopper_l, "metal_plate", resolution="1k")

    hopper_l_rim = add(generate_cylinder(radius=0.12, height=0.015, segments=8,
                                          hex_color=NIGHT_STEEL))
    hopper_l_rim.name = "HopperLeftRim"
    hopper_l_rim.location = (-0.8, -0.5, 0.46)

    hopper_r = add(generate_cone(radius_bottom=0.06, radius_top=0.11,
                                  height=0.18, segments=8,
                                  hex_color=NIGHT_METAL))
    hopper_r.name = "HopperRight"
    hopper_r.location = (0.5, 0.85, 0.28)
    apply_texture(hopper_r, "metal_plate", resolution="1k")

    hopper_r_rim = add(generate_cylinder(radius=0.12, height=0.015, segments=8,
                                          hex_color=NIGHT_STEEL))
    hopper_r_rim.name = "HopperRightRim"
    hopper_r_rim.location = (0.5, 0.85, 0.46)

    # -- DRIVE GEARS (visible on the back of top row) --
    main_gear = add(generate_cog(outer_radius=0.22, inner_radius=0.15,
                                  teeth=10, thickness=0.08, hex_color=NIGHT_METAL))
    main_gear.name = "MainGear"
    main_gear.location = (0.3, 0.95, 0.28)
    apply_texture(main_gear, "metal_plate", resolution="1k")

    small_gear = add(generate_cog(outer_radius=0.14, inner_radius=0.10,
                                   teeth=6, thickness=0.08, hex_color=NIGHT_STEEL))
    small_gear.name = "SmallGear"
    small_gear.location = (0.0, 0.95, 0.28)
    apply_texture(small_gear, "metal_plate", resolution="1k")

    # -- EXHAUST CHIMNEY (bottom-left cell) --
    chimney = add(generate_cylinder(radius=0.07, height=0.25, segments=10,
                                     hex_color=NIGHT_BODY))
    chimney.name = "Chimney"
    chimney.location = (-0.75, -0.75, 0.46)
    apply_texture(chimney, "corrugated_iron", resolution="1k")

    chimney_cap = add(generate_cylinder(radius=0.09, height=0.02, segments=10,
                                         hex_color=NIGHT_STEEL))
    chimney_cap.name = "ChimneyCap"
    chimney_cap.location = (-0.75, -0.75, 0.71)
    apply_texture(chimney_cap, "rusty_metal_02", resolution="1k")

    # -- SIDE ARMOR WEDGE (adds imposing silhouette) --
    wedge = add(generate_wedge(w=0.30, d=0.40, h_front=0.0, h_back=0.15,
                                hex_color=NIGHT_METAL))
    wedge.name = "SideArmor"
    wedge.location = (0.65, 0.5, 0.46)
    apply_texture(wedge, "metal_plate", resolution="1k")

    # -- BOLTS --
    bolt_positions = [
        # Roof corners (top row)
        (-0.80, 0.85, 0.51), (0.80, 0.85, 0.51),
        (-0.80, 0.15, 0.51), (0.80, 0.15, 0.51),
        # Roof corners (left cell)
        (-0.80, -0.15, 0.51), (-0.15, -0.15, 0.51),
        (-0.80, -0.85, 0.51), (-0.15, -0.85, 0.51),
        # Launcher bolts (ring pattern)
    ]
    for i in range(6):
        angle = (i / 6) * 2 * math.pi
        bx = -0.5 + 0.26 * math.cos(angle)
        by = 0.5 + 0.26 * math.sin(angle)
        bolt_positions.append((bx, by, 0.54))

    for bi, (bx, by, bz) in enumerate(bolt_positions):
        b = add(generate_bolt(head_radius=0.018, head_height=0.012,
                              hex_color=C["rivet"]))
        b.name = f"Bolt_{bi}"
        b.location = (bx, by, bz)

    return {
        "root": root,
        "body_top": body_top,
        "body_left": body_left,
        "pedestal": pedestal,
        "launcher_ring": launcher_ring,
        "launcher_platform": launcher_platform,
        "tubes": tubes,
        "brace": brace,
        "main_gear": main_gear,
        "small_gear": small_gear,
        "base_top": base_top,
        "base_left": base_left,
    }


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------
def bake_animations(objects):
    """Bake all animation states."""
    body_top = objects["body_top"]
    body_left = objects["body_left"]
    pedestal = objects["pedestal"]
    launcher_ring = objects["launcher_ring"]
    launcher_platform = objects["launcher_platform"]
    tubes = objects["tubes"]
    brace = objects["brace"]
    mg = objects["main_gear"]
    sg = objects["small_gear"]
    base_top = objects["base_top"]
    base_left = objects["base_left"]

    GEAR_RATIO = 10 / 6

    # Launcher parts that rotate together
    launcher_parts = [pedestal, launcher_ring, launcher_platform, brace] + tubes

    # -- idle (2s): slow scan, subtle gear wobble --
    animate_static(body_top, "idle", duration=2.0)
    animate_static(body_left, "idle", duration=2.0)
    animate_static(base_top, "idle", duration=2.0)
    animate_static(base_left, "idle", duration=2.0)
    animate_rotation(mg, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.03 * math.sin(t * math.pi * 2))
    animate_rotation(sg, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: -0.03 * GEAR_RATIO * math.sin(t * math.pi * 2))
    # Slow scan rotation
    for part in launcher_parts:
        animate_rotation(part, "idle", duration=2.0, axis='Z',
                         angle_fn=lambda t: 0.2 * math.sin(t * math.pi * 2))

    # -- active (2s): faster scan, recoil, body shake --
    animate_shake(body_top, "active", duration=2.0, amplitude=0.006, frequency=10)
    animate_shake(body_left, "active", duration=2.0, amplitude=0.006, frequency=10)
    animate_static(base_top, "active", duration=2.0)
    animate_static(base_left, "active", duration=2.0)
    animate_rotation(mg, "active", duration=2.0, axis='Z',
                     total_angle=math.pi * 4)
    animate_rotation(sg, "active", duration=2.0, axis='Z',
                     total_angle=-math.pi * 4 * GEAR_RATIO)
    # Faster tracking rotation for launcher assembly
    for part in launcher_parts:
        animate_rotation(part, "active", duration=2.0, axis='Z',
                         angle_fn=lambda t: 0.5 * math.sin(t * math.pi * 4))


def main():
    output = parse_args()
    print(f"[rocket_turret_model] Building rocket turret, exporting to {output}")

    objects = build_rocket_turret()
    bake_animations(objects)
    export_glb(output)

    print(f"[rocket_turret_model] Done: {output}")


if __name__ == "__main__":
    main()
