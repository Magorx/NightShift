"""Export smelter as a 3D model (.glb) for Godot import.

The smelter is the primary converter building: multiple inputs, 1 output.
Design: L-shaped (2x2 grid with bottom-right cell missing for output),
wide, low, hot, industrial — distinct from the tall drill.
Features: L-shaped housing, open furnace crucible, two input hoppers,
output chute facing the gap, chimney, gears, pipes, bolts, control panel.

Blender coordinate mapping (1 BU = 1 Godot unit, root_scale=1.0):
  Blender X -> Godot X
  Blender Y -> Godot -Z
  Blender Z -> Godot Y (up)

Model node in Godot is at (1, 0, 1) — center of the 2x2 bounding box.
Cell centers in Blender XY:
  (0,0) -> (-0.5,  0.5)  top-left
  (1,0) -> ( 0.5,  0.5)  top-right
  (0,1) -> (-0.5, -0.5)  bottom-left
  (1,1) -> ( 0.5, -0.5)  MISSING — output gap

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/smelter_model.py
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
from prefabs_src.cog import generate_cog
from prefabs_src.cylinder import generate_cylinder
from prefabs_src.cone import generate_cone
from prefabs_src.piston import generate_piston
from prefabs_src.pipe import generate_pipe
from prefabs_src.bolt import generate_bolt
from prefabs_src.hemisphere import generate_hemisphere
from prefabs_src.wedge import generate_wedge
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

    output = os.path.join(REPO_ROOT, "buildings", "smelter", "models", "smelter.glb")

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

# Structural
STEEL      = "#7A8898"
STEEL_DK   = "#6A7888"
STEEL_LT   = "#96A4B4"
BODY_MAIN  = "#5A4838"
BODY_LIGHT = "#6E5A48"
BODY_ROOF  = "#7A6854"
COPPER     = "#B87333"
COPPER_DK  = "#8B5A2B"
RUST       = "#6B4226"
CABLE      = "#2A2A2A"
YELLOW     = "#C8A82A"
RED_WARN   = "#A03030"
GAUGE_FACE = "#D8D0C0"

# Fire / heat specific to smelter
FIRE_OUTER = C["fire_outer"]
FIRE_MID   = C["fire_mid"]
FIRE_INNER = C["fire_inner"]
FIRE_CORE  = C["fire_core"]
GLOW_WALL  = C["glow_wall"]
EMBER      = C["ember"]
SOOT       = C["soot"]

# Animation constants
GEAR_RATIO = 10 / 6   # main gear has 10 teeth, small has 6
SHAKE_AMP  = 0.006    # body vibration amplitude


# ---------------------------------------------------------------------------
# Build the scene
# ---------------------------------------------------------------------------
def build_smelter():
    """Build the full L-shaped smelter under a root empty.

    L-shape layout in Blender XY (Z is up):
        (-0.95, 0.95) -------- (0.95, 0.95)
             |    cell(0,0)   |  cell(1,0)  |
        (-0.95, 0.05) ---------(0.95, 0.05)
             |    cell(0,1)   |
        (-0.95,-0.95) -- (0.05,-0.95)
    Missing corner: X > 0, Y < 0 = output gap.
    """
    clear_scene()

    root = bpy.data.objects.new("Smelter", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.25
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # ── L-SHAPED BASE PLATFORM ────────────────────────────────────────
    # Two overlapping bars forming an L, slight overlap at junction
    base_top = add(generate_box(w=1.9, d=0.9, h=0.06, hex_color=STEEL_DK))
    base_top.name = "BasePlatformTop"
    base_top.location = (0, 0.5, 0)

    base_left = add(generate_box(w=0.9, d=1.0, h=0.06, hex_color=STEEL_DK))
    base_left.name = "BasePlatformLeft"
    base_left.location = (-0.5, -0.45, 0)

    # Corner feet at L extremities
    foot_positions = [
        (-0.85, 0.85),   # top-left
        (0.85, 0.85),    # top-right
        (-0.85, -0.85),  # bottom-left
        (-0.05, -0.85),  # bottom-left inner corner
        (0.85, 0.15),    # right edge bottom
        (-0.05, 0.15),   # inner corner
    ]
    for i, (fx, fy) in enumerate(foot_positions):
        foot = add(generate_cylinder(radius=0.05, height=0.03, segments=8,
                                     hex_color=STEEL_DK))
        foot.name = f"Foot_{i}"
        foot.location = (fx, fy, -0.03)

    # ── L-SHAPED MAIN HOUSING ─────────────────────────────────────────
    body_top = add(generate_box(w=1.7, d=0.8, h=0.45, hex_color=BODY_MAIN,
                                seam_count=2))
    body_top.name = "BodyTop"
    body_top.location = (0, 0.5, 0.06)

    body_left = add(generate_box(w=0.8, d=0.85, h=0.45, hex_color=BODY_MAIN,
                                 seam_count=2))
    body_left.name = "BodyLeft"
    body_left.location = (-0.5, -0.475, 0.06)

    # Lower reinforcement bands (L-shaped)
    band_lo_top = add(generate_box(w=1.75, d=0.85, h=0.04, hex_color=STEEL_DK))
    band_lo_top.name = "BandLoTop"
    band_lo_top.location = (0, 0.5, 0.1)

    band_lo_left = add(generate_box(w=0.85, d=0.9, h=0.04, hex_color=STEEL_DK))
    band_lo_left.name = "BandLoLeft"
    band_lo_left.location = (-0.5, -0.475, 0.1)

    # Upper reinforcement bands (L-shaped)
    band_hi_top = add(generate_box(w=1.75, d=0.85, h=0.04, hex_color=STEEL_DK))
    band_hi_top.name = "BandHiTop"
    band_hi_top.location = (0, 0.5, 0.44)

    band_hi_left = add(generate_box(w=0.85, d=0.9, h=0.04, hex_color=STEEL_DK))
    band_hi_left.name = "BandHiLeft"
    band_hi_left.location = (-0.5, -0.475, 0.44)

    # Hazard stripes near base
    hazard_top = add(generate_box(w=1.725, d=0.825, h=0.02, hex_color=YELLOW))
    hazard_top.name = "HazardStripeTop"
    hazard_top.location = (0, 0.5, 0.075)

    hazard_left = add(generate_box(w=0.825, d=0.875, h=0.02, hex_color=YELLOW))
    hazard_left.name = "HazardStripeLeft"
    hazard_left.location = (-0.5, -0.475, 0.075)

    # ── FURNACE CRUCIBLE ──────────────────────────────────────────────
    # Centered on cell (0,0) — the top-left cell, heart of the L
    crucible_outer = add(generate_cone(radius_bottom=0.25, radius_top=0.3,
                                       height=0.2, segments=12,
                                       hex_color=BODY_LIGHT))
    crucible_outer.name = "CrucibleOuter"
    crucible_outer.location = (-0.5, 0.5, 0.51)

    crucible_rim = add(generate_cylinder(radius=0.32, height=0.025, segments=12,
                                         hex_color=STEEL_DK))
    crucible_rim.name = "CrucibleRim"
    crucible_rim.location = (-0.5, 0.5, 0.71)

    fire_glow = add(generate_cylinder(radius=0.22, height=0.02, segments=10,
                                      hex_color=FIRE_MID))
    fire_glow.name = "FireGlow"
    fire_glow.location = (-0.5, 0.5, 0.56)

    fire_core = add(generate_cylinder(radius=0.12, height=0.025, segments=8,
                                      hex_color=FIRE_CORE))
    fire_core.name = "FireCore"
    fire_core.location = (-0.5, 0.5, 0.565)

    heat_band = add(generate_cylinder(radius=0.27, height=0.06, segments=12,
                                      hex_color=GLOW_WALL))
    heat_band.name = "HeatBand"
    heat_band.location = (-0.5, 0.5, 0.52)

    # Crucible reinforcement rivets
    for i in range(6):
        angle = (i / 6) * 2 * math.pi
        rx = -0.5 + 0.31 * math.cos(angle)
        ry = 0.5 + 0.31 * math.sin(angle)
        rivet = add(generate_bolt(head_radius=0.015, head_height=0.008,
                                   hex_color=C["rivet"]))
        rivet.name = f"CrucibleRivet_{i}"
        rivet.location = (rx, ry, 0.715)

    # ── INPUT HOPPERS ─────────────────────────────────────────────────
    # Hopper on the top edge (feeds from +Y / Godot -Z direction)
    hopper_top = add(generate_cone(radius_bottom=0.07, radius_top=0.13,
                                    height=0.2, segments=8, hex_color=STEEL))
    hopper_top.name = "HopperTop"
    hopper_top.location = (0.5, 0.85, 0.275)

    hopper_top_rim = add(generate_cylinder(radius=0.14, height=0.015, segments=8,
                                            hex_color=STEEL_DK))
    hopper_top_rim.name = "HopperTopRim"
    hopper_top_rim.location = (0.5, 0.85, 0.475)

    hopper_top_bracket = add(generate_wedge(w=0.1, d=0.08, h_front=0.0,
                                             h_back=0.07, hex_color=STEEL_DK))
    hopper_top_bracket.name = "HopperTopBracket"
    hopper_top_bracket.location = (0.5, 0.75, 0.275)

    # Hopper on the left edge (feeds from -X)
    hopper_left = add(generate_cone(radius_bottom=0.07, radius_top=0.13,
                                     height=0.2, segments=8, hex_color=STEEL))
    hopper_left.name = "HopperLeft"
    hopper_left.location = (-0.85, -0.5, 0.275)

    hopper_left_rim = add(generate_cylinder(radius=0.14, height=0.015, segments=8,
                                             hex_color=STEEL_DK))
    hopper_left_rim.name = "HopperLeftRim"
    hopper_left_rim.location = (-0.85, -0.5, 0.475)

    hopper_left_bracket = add(generate_wedge(w=0.1, d=0.08, h_front=0.0,
                                              h_back=0.07, hex_color=STEEL_DK))
    hopper_left_bracket.name = "HopperLeftBracket"
    hopper_left_bracket.location = (-0.75, -0.5, 0.275)
    hopper_left_bracket.rotation_euler = (0, 0, math.radians(90))

    # ── OUTPUT CHUTE (toward missing cell: +X, -Y) ───────────────────
    chute_pipe = add(generate_pipe(length=0.3, radius=0.06, wall_thickness=0.015,
                                   hex_color=C["pipe"]))
    chute_pipe.name = "OutputChute"
    chute_pipe.rotation_euler = (math.radians(-35), 0, math.radians(-45))
    chute_pipe.location = (0.15, -0.15, 0.3)

    chute_mount = add(generate_box(w=0.15, d=0.04, h=0.15, hex_color=STEEL_DK))
    chute_mount.name = "ChuteMountPlate"
    chute_mount.rotation_euler = (0, 0, math.radians(-45))
    chute_mount.location = (0.05, -0.05, 0.3)

    chute_funnel = add(generate_cone(radius_bottom=0.045, radius_top=0.075,
                                      height=0.05, segments=8, hex_color=STEEL))
    chute_funnel.name = "ChuteFunnel"
    chute_funnel.rotation_euler = (math.radians(-35), 0, math.radians(-45))
    chute_funnel.location = (0.05, -0.05, 0.35)

    # ── CHIMNEY (back-left corner, cell 0,1) ──────────────────────────
    chimney = add(generate_cylinder(radius=0.08, height=0.3, segments=10,
                                    hex_color=C["pipe"]))
    chimney.name = "Chimney"
    chimney.location = (-0.75, -0.75, 0.51)

    chimney_cap = add(generate_cylinder(radius=0.1, height=0.025, segments=10,
                                         hex_color=STEEL_DK))
    chimney_cap.name = "ChimneyCap"
    chimney_cap.location = (-0.75, -0.75, 0.81)

    chimney_hood = add(generate_cone(radius_bottom=0.09, radius_top=0.025,
                                      height=0.05, segments=8, hex_color=RUST))
    chimney_hood.name = "ChimneyHood"
    chimney_hood.location = (-0.75, -0.75, 0.86)

    soot_ring = add(generate_cylinder(radius=0.09, height=0.015, segments=10,
                                       hex_color=SOOT))
    soot_ring.name = "SootRing"
    soot_ring.location = (-0.75, -0.75, 0.51)

    chimney_bracket = add(generate_wedge(w=0.09, d=0.09, h_front=0.0,
                                          h_back=0.08, hex_color=STEEL_DK))
    chimney_bracket.name = "ChimneyBracket"
    chimney_bracket.location = (-0.75, -0.65, 0.51)

    # ── GEARS (visible on back face of top row) ──────────────────────
    main_gear = add(generate_cog(outer_radius=0.25, inner_radius=0.16,
                                 teeth=10, thickness=0.1, hex_color=STEEL_LT))
    main_gear.name = "MainGear"
    main_gear.location = (0.1, 0.95, 0.3)

    small_gear = add(generate_cog(outer_radius=0.15, inner_radius=0.1,
                                  teeth=6, thickness=0.1, hex_color=STEEL))
    small_gear.name = "SmallGear"
    small_gear.location = (-0.25, 0.95, 0.3)

    # Gear axle caps
    for name, pos in [("MainAxle", (0.1, 0.95, 0.36)),
                      ("SmallAxle", (-0.25, 0.95, 0.36))]:
        axle = add(generate_cylinder(radius=0.025, height=0.02, segments=8,
                                     hex_color=STEEL_DK))
        axle.name = name
        axle.location = pos

    # ── PLUMBING ──────────────────────────────────────────────────────
    # Vertical pipe on right face of top-right cell
    vert_pipe = add(generate_pipe(length=0.25, radius=0.025, wall_thickness=0.006,
                                  hex_color=COPPER))
    vert_pipe.name = "VertPipe"
    vert_pipe.location = (0.8, 0.35, 0.2)

    h_pipe = add(generate_pipe(length=0.1, radius=0.02, wall_thickness=0.005,
                               hex_color=COPPER))
    h_pipe.name = "HPipe"
    h_pipe.rotation_euler = (0, math.radians(90), 0)
    h_pipe.location = (0.7, 0.35, 0.35)

    # Heat transfer pipe from crucible area
    heat_pipe = add(generate_pipe(length=0.15, radius=0.03, wall_thickness=0.008,
                                  hex_color=COPPER_DK))
    heat_pipe.name = "HeatPipe"
    heat_pipe.location = (-0.2, 0.5, 0.3)

    # Pipe on bottom-left cell
    elbow_v = add(generate_pipe(length=0.12, radius=0.02, wall_thickness=0.005,
                                hex_color=COPPER_DK))
    elbow_v.name = "ElbowV"
    elbow_v.location = (-0.2, -0.8, 0.2)

    # ── CONTROL PANEL (front of top-right cell) ──────────────────────
    panel = add(generate_box(w=0.2, d=0.03, h=0.14, hex_color=BODY_LIGHT))
    panel.name = "ControlPanel"
    panel.location = (0.5, 0.1, 0.25)

    gauge = add(generate_cylinder(radius=0.035, height=0.012, segments=10,
                                  hex_color=GAUGE_FACE))
    gauge.name = "Gauge"
    gauge.rotation_euler = (math.radians(90), 0, 0)
    gauge.location = (0.45, 0.07, 0.3)

    gauge_rim = add(generate_cylinder(radius=0.042, height=0.008, segments=10,
                                      hex_color=COPPER))
    gauge_rim.name = "GaugeRim"
    gauge_rim.rotation_euler = (math.radians(90), 0, 0)
    gauge_rim.location = (0.45, 0.065, 0.3)

    for ki, kx in enumerate([0.52, 0.56]):
        knob = add(generate_cylinder(radius=0.012, height=0.015, segments=6,
                                     hex_color=RED_WARN if ki == 0 else YELLOW))
        knob.name = f"Knob_{ki}"
        knob.rotation_euler = (math.radians(90), 0, 0)
        knob.location = (kx, 0.065, 0.26)

    temp_bar = add(generate_box(w=0.015, d=0.012, h=0.08, hex_color=FIRE_OUTER))
    temp_bar.name = "TempIndicator"
    temp_bar.location = (0.58, 0.08, 0.28)

    # ── VALVE WHEEL (left face of bottom-left cell) ──────────────────
    valve = add(generate_cog(outer_radius=0.05, inner_radius=0.035,
                             teeth=5, thickness=0.015, hex_color=RED_WARN))
    valve.name = "ValveWheel"
    valve.rotation_euler = (0, math.radians(90), 0)
    valve.location = (-0.95, -0.35, 0.3)

    valve_stem = add(generate_cylinder(radius=0.01, height=0.03, segments=6,
                                       hex_color=STEEL_DK))
    valve_stem.name = "ValveStem"
    valve_stem.rotation_euler = (0, math.radians(90), 0)
    valve_stem.location = (-0.96, -0.35, 0.3)

    # ── SIDE TANK (on bottom-left cell, front face) ──────────────────
    tank = add(generate_cylinder(radius=0.06, height=0.18, segments=10,
                                 hex_color=BODY_LIGHT))
    tank.name = "SideTank"
    tank.location = (-0.25, -0.9, 0.06)

    tank_cap = add(generate_hemisphere(radius=0.06, rings=3, segments=10,
                                        hex_color=BODY_ROOF))
    tank_cap.name = "TankCap"
    tank_cap.location = (-0.25, -0.9, 0.24)

    for ti, tz in enumerate([0.1, 0.18]):
        tband = add(generate_cylinder(radius=0.068, height=0.012, segments=10,
                                      hex_color=STEEL_DK))
        tband.name = f"TankBand_{ti}"
        tband.location = (-0.25, -0.9, tz)

    tank_pipe = add(generate_pipe(length=0.08, radius=0.015, wall_thickness=0.004,
                                  hex_color=COPPER))
    tank_pipe.name = "TankPipe"
    tank_pipe.rotation_euler = (0, math.radians(90), math.radians(25))
    tank_pipe.location = (-0.25, -0.8, 0.15)

    # ── CABLES ────────────────────────────────────────────────────────
    cable_runs = [
        {"start": (-0.3, 0.85, 0.5), "end": (-0.25, 0.95, 0.3), "name": "Cable_0"},
        {"start": (0.35, 0.1, 0.5), "end": (0.5, 0.08, 0.35), "name": "Cable_1"},
        {"start": (-0.75, -0.6, 0.55), "end": (-0.5, -0.3, 0.51), "name": "Cable_2"},
    ]
    for ci, run in enumerate(cable_runs):
        sx, sy, sz = run["start"]
        ex, ey, ez = run["end"]
        dx, dy, dz = ex - sx, ey - sy, ez - sz
        length = math.sqrt(dx*dx + dy*dy + dz*dz)
        cable = add(generate_cylinder(radius=0.008, height=length, segments=6,
                                      hex_color=CABLE))
        cable.name = run["name"]
        cable.location = (sx, sy, sz)
        pitch = math.acos(max(-1, min(1, dz / length))) if length > 0 else 0
        yaw = math.atan2(dy, dx)
        cable.rotation_euler = (0, pitch, yaw)

    # ── BOLTS ─────────────────────────────────────────────────────────
    # Roof bolts — around crucible and on body top
    bolt_positions = [
        # Around crucible on body top
        (-0.15, 0.85, 0.51), (-0.85, 0.85, 0.51),
        (-0.85, 0.15, 0.51), (-0.15, 0.15, 0.51),
        # Top-right cell roof
        (0.15, 0.85, 0.51), (0.85, 0.85, 0.51),
        (0.85, 0.15, 0.51), (0.15, 0.15, 0.51),
        # Bottom-left cell roof
        (-0.15, -0.15, 0.51), (-0.85, -0.15, 0.51),
        (-0.85, -0.85, 0.51), (-0.15, -0.85, 0.51),
    ]
    for i, (bx, by, bz) in enumerate(bolt_positions):
        b = add(generate_bolt(head_radius=0.018, head_height=0.012,
                               hex_color=C["rivet"]))
        b.name = f"Bolt_{i}"
        b.location = (bx, by, bz)

    # Side bolts on body faces
    side_bolt_positions = [
        # Top-right cell front face (Y ~ 0.1)
        (0.3, 0.1, 0.2), (0.7, 0.1, 0.2),
        (0.3, 0.1, 0.4), (0.7, 0.1, 0.4),
        # Top-right cell right face (X ~ 0.85)
        (0.85, 0.3, 0.2), (0.85, 0.7, 0.2),
        # Bottom-left cell front face (Y ~ -0.9)
        (-0.7, -0.9, 0.2), (-0.3, -0.9, 0.2),
        # Bottom-left cell left face (X ~ -0.95)
        (-0.95, -0.7, 0.2), (-0.95, -0.3, 0.2),
        # Top-left cell left face
        (-0.95, 0.3, 0.2), (-0.95, 0.7, 0.2),
    ]
    for i, (bx, by, bz) in enumerate(side_bolt_positions):
        sb = add(generate_bolt(head_radius=0.015, head_height=0.01,
                                hex_color=C["rivet"]))
        sb.name = f"SideBolt_{i}"
        sb.location = (bx, by, bz)

    return {
        "root": root,
        "main_gear": main_gear,
        "small_gear": small_gear,
        "body_top": body_top,
        "body_left": body_left,
        "band_lo_top": band_lo_top,
        "band_lo_left": band_lo_left,
        "band_hi_top": band_hi_top,
        "band_hi_left": band_hi_left,
        "crucible_outer": crucible_outer,
        "fire_glow": fire_glow,
        "fire_core": fire_core,
        "valve": valve,
    }


# ---------------------------------------------------------------------------
# Animation — using anim_helpers
# ---------------------------------------------------------------------------
def bake_animations(objects):
    """Bake all animation states using high-level helpers."""
    mg = objects["main_gear"]
    sg = objects["small_gear"]
    body_top = objects["body_top"]
    body_left = objects["body_left"]
    blt = objects["band_lo_top"]
    bll = objects["band_lo_left"]
    bht = objects["band_hi_top"]
    bhl = objects["band_hi_left"]
    crucible = objects["crucible_outer"]
    fire_glow = objects["fire_glow"]
    fire_core = objects["fire_core"]
    valve = objects["valve"]

    # ── idle (2 sec): very subtle heat shimmer ────────────────────────
    animate_shake(body_top, "idle", duration=2.0, amplitude=0.002, frequency=3)
    animate_shake(body_left, "idle", duration=2.0, amplitude=0.002, frequency=3)
    animate_shake(crucible, "idle", duration=2.0, amplitude=0.0012, frequency=4)
    animate_rotation(mg, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.02 * math.sin(t * math.pi * 2))
    animate_rotation(sg, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: -0.02 * GEAR_RATIO * math.sin(t * math.pi * 2))
    animate_static(fire_glow, "idle", duration=2.0)
    animate_static(fire_core, "idle", duration=2.0)
    animate_static(valve, "idle", duration=2.0)

    # ── windup (1 sec): furnace warming up ────────────────────────────
    animate_rotation(mg, "windup", duration=1.0, axis='Z',
                     angle_fn=lambda t: t * t * math.pi * 2)
    animate_rotation(sg, "windup", duration=1.0, axis='Z',
                     angle_fn=lambda t: -t * t * math.pi * 2 * GEAR_RATIO)
    animate_shake(body_top, "windup", duration=1.0, amplitude=SHAKE_AMP * 0.5, frequency=5)
    animate_shake(body_left, "windup", duration=1.0, amplitude=SHAKE_AMP * 0.5, frequency=5)
    animate_shake(crucible, "windup", duration=1.0, amplitude=0.002, frequency=6)
    animate_rotation(valve, "windup", duration=1.0, axis='Y',
                     total_angle=math.pi)
    animate_static(fire_glow, "windup", duration=1.0)
    animate_static(fire_core, "windup", duration=1.0)

    # ── active (2 sec): full operation ────────────────────────────────
    animate_rotation(mg, "active", duration=2.0, axis='Z',
                     total_angle=math.pi * 4)
    animate_rotation(sg, "active", duration=2.0, axis='Z',
                     total_angle=-math.pi * 4 * GEAR_RATIO)
    animate_shake(body_top, "active", duration=2.0, amplitude=SHAKE_AMP, frequency=10)
    animate_shake(body_left, "active", duration=2.0, amplitude=SHAKE_AMP, frequency=10)
    animate_shake(blt, "active", duration=2.0, amplitude=SHAKE_AMP, frequency=10)
    animate_shake(bll, "active", duration=2.0, amplitude=SHAKE_AMP, frequency=10)
    animate_shake(bht, "active", duration=2.0, amplitude=SHAKE_AMP, frequency=10)
    animate_shake(bhl, "active", duration=2.0, amplitude=SHAKE_AMP, frequency=10)
    animate_shake(crucible, "active", duration=2.0, amplitude=0.003, frequency=12)
    fire_base_z = fire_glow.location.z
    animate_translation(fire_glow, "active", duration=2.0, axis='Z',
                        value_fn=lambda t: fire_base_z + 0.008 * math.sin(t * math.pi * 8))
    core_base_z = fire_core.location.z
    animate_translation(fire_core, "active", duration=2.0, axis='Z',
                        value_fn=lambda t: core_base_z + 0.012 * math.sin(t * math.pi * 6 + 0.5))
    animate_static(valve, "active", duration=2.0)

    # ── winddown (1 sec): decelerating, cooling ──────────────────────
    animate_rotation(mg, "winddown", duration=1.0, axis='Z',
                     angle_fn=lambda t: (2 * t - t * t) * math.pi * 2)
    animate_rotation(sg, "winddown", duration=1.0, axis='Z',
                     angle_fn=lambda t: -(2 * t - t * t) * math.pi * 2 * GEAR_RATIO)
    animate_shake(body_top, "winddown", duration=1.0, amplitude=SHAKE_AMP, frequency=10, decay=1.0)
    animate_shake(body_left, "winddown", duration=1.0, amplitude=SHAKE_AMP, frequency=10, decay=1.0)
    animate_shake(blt, "winddown", duration=1.0, amplitude=SHAKE_AMP, frequency=10, decay=1.0)
    animate_shake(bll, "winddown", duration=1.0, amplitude=SHAKE_AMP, frequency=10, decay=1.0)
    animate_shake(bht, "winddown", duration=1.0, amplitude=SHAKE_AMP, frequency=10, decay=1.0)
    animate_shake(bhl, "winddown", duration=1.0, amplitude=SHAKE_AMP, frequency=10, decay=1.0)
    animate_shake(crucible, "winddown", duration=1.0, amplitude=0.003, frequency=12, decay=1.0)
    animate_translation(fire_glow, "winddown", duration=1.0, axis='Z',
                        value_fn=lambda t: fire_base_z + 0.008 * (1 - t) * math.sin(t * math.pi * 4))
    animate_translation(fire_core, "winddown", duration=1.0, axis='Z',
                        value_fn=lambda t: core_base_z + 0.012 * (1 - t) * math.sin(t * math.pi * 3))
    animate_rotation(valve, "winddown", duration=1.0, axis='Y',
                     angle_fn=lambda t: (1 - t) * math.pi)


# ---------------------------------------------------------------------------
# Texture application
# ---------------------------------------------------------------------------
def apply_textures():
    """Apply PBR textures to named objects for the textured export."""
    texture_map = {
        "BasePlatformTop": "metal_plate_02",
        "BasePlatformLeft": "metal_plate_02",
        "BodyTop": "painted_metal_shutter",
        "BodyLeft": "painted_metal_shutter",
        "BandLoTop": "metal_plate",
        "BandLoLeft": "metal_plate",
        "BandHiTop": "metal_plate",
        "BandHiLeft": "metal_plate",
        "CrucibleOuter": "rusty_metal_02",
        "CrucibleRim": "metal_plate",
        "Chimney": "corrugated_iron",
        "ChimneyCap": "rusty_metal_02",
        "ChimneyHood": "rusty_metal_02",
        "HopperTop": "metal_plate",
        "HopperLeft": "metal_plate",
        "HopperTopRim": "metal_plate",
        "HopperLeftRim": "metal_plate",
        "OutputChute": "rusty_metal_02",
        "ChuteMountPlate": "metal_plate",
        "MainGear": "metal_plate",
        "SmallGear": "metal_plate",
        "ControlPanel": "painted_metal_shutter",
        "SideTank": "painted_metal_shutter",
        "VertPipe": "rusty_metal_02",
        "HPipe": "rusty_metal_02",
        "HeatPipe": "rusty_metal_02",
        "ElbowV": "rusty_metal_02",
    }
    for i in range(6):
        texture_map[f"Foot_{i}"] = "metal_plate"

    for obj_name, tex_id in texture_map.items():
        obj = bpy.data.objects.get(obj_name)
        if obj and obj.type == 'MESH':
            try:
                apply_texture(obj, tex_id, resolution="1k")
            except Exception as e:
                print(f"[smelter_model] Warning: texture '{tex_id}' failed for {obj_name}: {e}")


def main():
    output = parse_args()
    print(f"[smelter_model] Building L-shaped smelter, exporting to {output}")

    # -- Build geometry --
    objects = build_smelter()

    # -- Bake animations --
    bake_animations(objects)

    # -- Export FLAT version (no PBR textures) --
    flat_glb = output.replace(".glb", "_flat.glb")
    export_glb(flat_glb)
    print(f"[smelter_model] Flat: {flat_glb}")

    # -- Apply PBR textures and export TEXTURED version --
    apply_textures()
    export_glb(output)

    print(f"[smelter_model] Textured: {output}")
    print("[smelter_model] Done!")


if __name__ == "__main__":
    main()
