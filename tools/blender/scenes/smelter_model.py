"""Export smelter as a 3D model (.glb) for Godot import.

The smelter is the primary converter building: 2 inputs, 1 output.
Design: wide, low, hot, industrial — distinct from the tall drill.
Features: main housing, open furnace crucible, two input hoppers,
output chute, chimney, gears, pipes, bolts, control panel.

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/smelter_model.py

    # Custom output path:
    $BLENDER --background --python tools/blender/scenes/smelter_model.py -- --output path/to/smelter.glb
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
SHAKE_AMP  = 0.012    # body vibration amplitude


# ---------------------------------------------------------------------------
# Build the scene
# ---------------------------------------------------------------------------
def build_smelter():
    """Build the full smelter as a parented hierarchy under a root empty."""
    clear_scene()

    root = bpy.data.objects.new("Smelter", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.5
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # ── BASE PLATFORM ─────────────────────────────────────────────────
    # Wide, low foundation slab
    base = add(generate_box(w=2.6, d=2.6, h=0.12, hex_color=STEEL_DK))
    base.name = "BasePlatform"

    # Corner feet — squat pads
    for i, (fx, fy) in enumerate([(-1.1, -1.1), (1.1, -1.1), (1.1, 1.1), (-1.1, 1.1)]):
        foot = add(generate_cylinder(radius=0.14, height=0.06, segments=8,
                                     hex_color=STEEL_DK))
        foot.name = f"Foot_{i}"
        foot.location = (fx, fy, -0.06)

    # ── MAIN HOUSING ──────────────────────────────────────────────────
    # Wider and lower than drill body (2.2x2.2x0.8)
    body = add(generate_box(w=2.2, d=2.2, h=0.8, hex_color=BODY_MAIN, seam_count=2))
    body.name = "Body"
    body.location = (0, 0, 0.12)

    # Lower reinforcement band
    band_lo = add(generate_box(w=2.3, d=2.3, h=0.1, hex_color=STEEL_DK))
    band_lo.name = "BandLo"
    band_lo.location = (0, 0, 0.18)

    # Upper reinforcement band
    band_hi = add(generate_box(w=2.3, d=2.3, h=0.1, hex_color=STEEL_DK))
    band_hi.name = "BandHi"
    band_hi.location = (0, 0, 0.75)

    # Hazard stripe near base
    hazard = add(generate_box(w=2.25, d=2.25, h=0.04, hex_color=YELLOW))
    hazard.name = "HazardStripe"
    hazard.location = (0, 0, 0.15)

    # ── FURNACE CRUCIBLE ──────────────────────────────────────────────
    # Open-top chamber sitting on the body — the hot core of the smelter
    # Outer wall: truncated cone (wider at top = crucible shape)
    crucible_outer = add(generate_cone(radius_bottom=0.7, radius_top=0.85,
                                       height=0.55, segments=12,
                                       hex_color=BODY_LIGHT))
    crucible_outer.name = "CrucibleOuter"
    crucible_outer.location = (0, 0, 0.92)

    # Crucible rim — a ring at the top showing the opening
    crucible_rim = add(generate_cylinder(radius=0.9, height=0.06, segments=12,
                                         hex_color=STEEL_DK))
    crucible_rim.name = "CrucibleRim"
    crucible_rim.location = (0, 0, 1.47)

    # Fire glow interior — a glowing disc visible from above
    fire_glow = add(generate_cylinder(radius=0.65, height=0.04, segments=10,
                                      hex_color=FIRE_MID))
    fire_glow.name = "FireGlow"
    fire_glow.location = (0, 0, 1.05)

    # Inner fire core — brighter center
    fire_core = add(generate_cylinder(radius=0.35, height=0.05, segments=8,
                                      hex_color=FIRE_CORE))
    fire_core.name = "FireCore"
    fire_core.location = (0, 0, 1.06)

    # Heat-discolored walls around crucible (darker, soot-stained bands)
    heat_band = add(generate_cylinder(radius=0.76, height=0.15, segments=12,
                                      hex_color=GLOW_WALL))
    heat_band.name = "HeatBand"
    heat_band.location = (0, 0, 0.95)

    # ── INPUT HOPPERS (two truncated cones on opposite sides) ─────────
    # Left hopper (negative X side)
    hopper_l_base = add(generate_cone(radius_bottom=0.18, radius_top=0.35,
                                       height=0.5, segments=8,
                                       hex_color=STEEL))
    hopper_l_base.name = "HopperLeft"
    hopper_l_base.location = (-1.15, 0, 0.52)

    # Hopper rim
    hopper_l_rim = add(generate_cylinder(radius=0.37, height=0.04, segments=8,
                                          hex_color=STEEL_DK))
    hopper_l_rim.name = "HopperLeftRim"
    hopper_l_rim.location = (-1.15, 0, 1.02)

    # Hopper support bracket — wedge connecting to body
    hopper_l_bracket = add(generate_wedge(w=0.3, d=0.25, h_front=0.0, h_back=0.2,
                                           hex_color=STEEL_DK))
    hopper_l_bracket.name = "HopperLeftBracket"
    hopper_l_bracket.location = (-1.0, 0, 0.52)
    hopper_l_bracket.rotation_euler = (0, 0, math.radians(90))

    # Right hopper (positive X side)
    hopper_r_base = add(generate_cone(radius_bottom=0.18, radius_top=0.35,
                                       height=0.5, segments=8,
                                       hex_color=STEEL))
    hopper_r_base.name = "HopperRight"
    hopper_r_base.location = (1.15, 0, 0.52)

    hopper_r_rim = add(generate_cylinder(radius=0.37, height=0.04, segments=8,
                                          hex_color=STEEL_DK))
    hopper_r_rim.name = "HopperRightRim"
    hopper_r_rim.location = (1.15, 0, 1.02)

    hopper_r_bracket = add(generate_wedge(w=0.3, d=0.25, h_front=0.0, h_back=0.2,
                                           hex_color=STEEL_DK))
    hopper_r_bracket.name = "HopperRightBracket"
    hopper_r_bracket.location = (1.0, 0, 0.52)
    hopper_r_bracket.rotation_euler = (0, 0, math.radians(-90))

    # ── OUTPUT CHUTE (front, negative Y) ──────────────────────────────
    # A tilted pipe/channel where product exits
    chute_pipe = add(generate_pipe(length=0.7, radius=0.15, wall_thickness=0.04,
                                   hex_color=C["pipe"]))
    chute_pipe.name = "OutputChute"
    # Tilt downward toward front
    chute_pipe.rotation_euler = (math.radians(55), 0, 0)
    chute_pipe.location = (0, -1.0, 0.45)

    # Chute mounting plate on body face
    chute_mount = add(generate_box(w=0.45, d=0.08, h=0.45, hex_color=STEEL_DK))
    chute_mount.name = "ChuteMountPlate"
    chute_mount.location = (0, -1.12, 0.52)

    # Small funnel at chute entrance (where it meets the body)
    chute_funnel = add(generate_cone(radius_bottom=0.12, radius_top=0.2,
                                      height=0.12, segments=8,
                                      hex_color=STEEL))
    chute_funnel.name = "ChuteFunnel"
    chute_funnel.rotation_euler = (math.radians(55), 0, 0)
    chute_funnel.location = (0, -0.85, 0.6)

    # ── CHIMNEY / EXHAUST STACK ───────────────────────────────────────
    # Shorter and wider than drill's exhaust — squat industrial chimney
    chimney = add(generate_cylinder(radius=0.22, height=0.7, segments=10,
                                    hex_color=C["pipe"]))
    chimney.name = "Chimney"
    chimney.location = (-0.55, 0.65, 0.92)

    # Chimney cap — wider disc
    chimney_cap = add(generate_cylinder(radius=0.28, height=0.06, segments=10,
                                         hex_color=STEEL_DK))
    chimney_cap.name = "ChimneyCap"
    chimney_cap.location = (-0.55, 0.65, 1.62)

    # Chimney rain hood — small cone with gap
    chimney_hood = add(generate_cone(radius_bottom=0.26, radius_top=0.06,
                                      height=0.12, segments=8,
                                      hex_color=RUST))
    chimney_hood.name = "ChimneyHood"
    chimney_hood.location = (-0.55, 0.65, 1.73)

    # Soot ring at chimney base
    soot_ring = add(generate_cylinder(radius=0.26, height=0.04, segments=10,
                                       hex_color=SOOT))
    soot_ring.name = "SootRing"
    soot_ring.location = (-0.55, 0.65, 0.92)

    # Chimney bracket wedge
    chimney_bracket = add(generate_wedge(w=0.25, d=0.25, h_front=0.0, h_back=0.2,
                                          hex_color=STEEL_DK))
    chimney_bracket.name = "ChimneyBracket"
    chimney_bracket.location = (-0.55, 0.45, 0.92)

    # ── GEARS (side-mounted, visible on back-right) ──────────────────
    main_gear = add(generate_cog(outer_radius=0.7, inner_radius=0.45,
                                 teeth=10, thickness=0.25, hex_color=STEEL_LT))
    main_gear.name = "MainGear"
    main_gear.location = (0.4, 1.15, 0.55)

    small_gear = add(generate_cog(outer_radius=0.4, inner_radius=0.28,
                                  teeth=6, thickness=0.25, hex_color=STEEL))
    small_gear.name = "SmallGear"
    small_gear.location = (-0.35, 1.15, 0.55)

    # Gear axle caps
    for name, pos in [("MainAxle", (0.4, 1.15, 0.69)),
                      ("SmallAxle", (-0.35, 1.15, 0.69))]:
        axle = add(generate_cylinder(radius=0.07, height=0.05, segments=8,
                                     hex_color=STEEL_DK))
        axle.name = name
        axle.location = pos

    # ── PLUMBING — pipes along body ───────────────────────────────────
    # Vertical pipe on back-left corner
    vert_pipe = add(generate_pipe(length=0.6, radius=0.06, wall_thickness=0.015,
                                  hex_color=COPPER))
    vert_pipe.name = "VertPipe"
    vert_pipe.location = (0.9, 0.9, 0.35)

    # Horizontal connecting pipe from body to vertical pipe
    h_pipe = add(generate_pipe(length=0.25, radius=0.05, wall_thickness=0.012,
                               hex_color=COPPER))
    h_pipe.name = "HPipe"
    h_pipe.rotation_euler = (0, math.radians(90), 0)
    h_pipe.location = (0.75, 0.9, 0.6)

    # Pipe from crucible area down to body (heat transfer pipe)
    heat_pipe = add(generate_pipe(length=0.35, radius=0.07, wall_thickness=0.018,
                                  hex_color=COPPER_DK))
    heat_pipe.name = "HeatPipe"
    heat_pipe.location = (0.7, -0.5, 0.55)

    # Pipe elbow on left side
    elbow_v = add(generate_pipe(length=0.3, radius=0.05, wall_thickness=0.012,
                                hex_color=COPPER_DK))
    elbow_v.name = "ElbowV"
    elbow_v.location = (-0.9, -0.7, 0.35)

    # ── CONTROL PANEL (front-right face) ──────────────────────────────
    panel = add(generate_box(w=0.55, d=0.08, h=0.35, hex_color=BODY_LIGHT))
    panel.name = "ControlPanel"
    panel.location = (0.55, -1.12, 0.45)

    # Gauge — flat cylinder on panel
    gauge = add(generate_cylinder(radius=0.1, height=0.03, segments=10,
                                  hex_color=GAUGE_FACE))
    gauge.name = "Gauge"
    gauge.rotation_euler = (math.radians(90), 0, 0)
    gauge.location = (0.45, -1.17, 0.55)

    # Gauge rim
    gauge_rim = add(generate_cylinder(radius=0.12, height=0.02, segments=10,
                                      hex_color=COPPER))
    gauge_rim.name = "GaugeRim"
    gauge_rim.rotation_euler = (math.radians(90), 0, 0)
    gauge_rim.location = (0.45, -1.18, 0.55)

    # Toggle knobs
    for ki, kx in enumerate([0.6, 0.7]):
        knob = add(generate_cylinder(radius=0.03, height=0.04, segments=6,
                                     hex_color=RED_WARN if ki == 0 else YELLOW))
        knob.name = f"Knob_{ki}"
        knob.rotation_euler = (math.radians(90), 0, 0)
        knob.location = (kx, -1.17, 0.47)

    # Temperature indicator — a small bar on the panel
    temp_bar = add(generate_box(w=0.04, d=0.03, h=0.2, hex_color=FIRE_OUTER))
    temp_bar.name = "TempIndicator"
    temp_bar.location = (0.75, -1.15, 0.52)

    # ── VALVE WHEEL (on pipe, left side) ──────────────────────────────
    valve = add(generate_cog(outer_radius=0.14, inner_radius=0.09,
                             teeth=5, thickness=0.04, hex_color=RED_WARN))
    valve.name = "ValveWheel"
    valve.rotation_euler = (0, math.radians(90), 0)
    valve.location = (-1.12, -0.45, 0.5)

    valve_stem = add(generate_cylinder(radius=0.025, height=0.08, segments=6,
                                       hex_color=STEEL_DK))
    valve_stem.name = "ValveStem"
    valve_stem.rotation_euler = (0, math.radians(90), 0)
    valve_stem.location = (-1.14, -0.45, 0.5)

    # ── SIDE TANK (coolant canister, front-left) ──────────────────────
    tank = add(generate_cylinder(radius=0.16, height=0.45, segments=10,
                                 hex_color=BODY_LIGHT))
    tank.name = "SideTank"
    tank.location = (-0.9, -0.7, 0.12)

    tank_cap = add(generate_hemisphere(radius=0.16, rings=3, segments=10,
                                        hex_color=BODY_ROOF))
    tank_cap.name = "TankCap"
    tank_cap.location = (-0.9, -0.7, 0.57)

    # Tank bands
    for ti, tz in enumerate([0.22, 0.42]):
        tband = add(generate_cylinder(radius=0.18, height=0.03, segments=10,
                                      hex_color=STEEL_DK))
        tband.name = f"TankBand_{ti}"
        tband.location = (-0.9, -0.7, tz)

    # Tank feed pipe to body
    tank_pipe = add(generate_pipe(length=0.2, radius=0.04, wall_thickness=0.01,
                                  hex_color=COPPER))
    tank_pipe.name = "TankPipe"
    tank_pipe.rotation_euler = (0, math.radians(90), math.radians(30))
    tank_pipe.location = (-0.72, -0.7, 0.35)

    # ── WIRING / CABLES ──────────────────────────────────────────────
    cable_runs = [
        {"start": (-0.3, 1.0, 0.9), "end": (-0.35, 1.15, 0.55), "name": "Cable_0"},
        {"start": (0.5, -0.8, 0.9), "end": (0.55, -1.1, 0.6), "name": "Cable_1"},
        {"start": (-0.55, 0.65, 1.3), "end": (-0.3, 0.2, 1.0), "name": "Cable_2"},
    ]
    for ci, run in enumerate(cable_runs):
        sx, sy, sz = run["start"]
        ex, ey, ez = run["end"]
        dx, dy, dz = ex - sx, ey - sy, ez - sz
        length = math.sqrt(dx*dx + dy*dy + dz*dz)

        cable = add(generate_cylinder(radius=0.02, height=length, segments=6,
                                      hex_color=CABLE))
        cable.name = run["name"]
        cable.location = (sx, sy, sz)
        pitch = math.acos(max(-1, min(1, dz / length))) if length > 0 else 0
        yaw = math.atan2(dy, dx)
        cable.rotation_euler = (0, pitch, yaw)

    # ── BOLTS — scattered on roof, bands, and sides ───────────────────
    bolt_positions = [
        # Body top corners (around crucible)
        (0.85, 0.85, 0.93), (-0.85, 0.85, 0.93),
        (0.85, -0.85, 0.93), (-0.85, -0.85, 0.93),
        # Body top mid-edges
        (0.0, 0.95, 0.93), (0.0, -0.95, 0.93),
        (0.95, 0.0, 0.93), (-0.95, 0.0, 0.93),
        # Band bolts (lower band)
        (1.15, 0.7, 0.22), (1.15, -0.7, 0.22),
        (-1.15, 0.7, 0.22), (-1.15, -0.7, 0.22),
        # Band bolts (upper band)
        (1.15, 0.7, 0.78), (1.15, -0.7, 0.78),
        (-1.15, 0.7, 0.78), (-1.15, -0.7, 0.78),
    ]
    for i, (bx, by, bz) in enumerate(bolt_positions):
        b = add(generate_bolt(head_radius=0.05, head_height=0.03, hex_color=C["rivet"]))
        b.name = f"Bolt_{i}"
        b.location = (bx, by, bz)

    # Side bolts on body faces
    side_bolt_positions = [
        # Front face
        (-0.6, -1.11, 0.35), (0.6, -1.11, 0.35),
        (-0.6, -1.11, 0.72), (0.6, -1.11, 0.72),
        # Right face
        (1.11, -0.6, 0.35), (1.11, 0.6, 0.35),
        (1.11, -0.6, 0.72), (1.11, 0.6, 0.72),
        # Left face
        (-1.11, -0.3, 0.35), (-1.11, 0.3, 0.35),
        # Back face
        (0.7, 1.11, 0.35), (-0.7, 1.11, 0.35),
    ]
    for i, (bx, by, bz) in enumerate(side_bolt_positions):
        sb = add(generate_bolt(head_radius=0.04, head_height=0.025, hex_color=C["rivet"]))
        sb.name = f"SideBolt_{i}"
        sb.location = (bx, by, bz)

    # ── CRUCIBLE REINFORCEMENT RIVETS (around the crucible rim) ───────
    for i in range(8):
        angle = (i / 8) * 2 * math.pi
        rx = 0.88 * math.cos(angle)
        ry = 0.88 * math.sin(angle)
        rivet = add(generate_bolt(head_radius=0.04, head_height=0.02,
                                   hex_color=C["rivet"]))
        rivet.name = f"CrucibleRivet_{i}"
        rivet.location = (rx, ry, 1.48)

    return {
        "root": root,
        "main_gear": main_gear,
        "small_gear": small_gear,
        "body": body,
        "band_lo": band_lo,
        "band_hi": band_hi,
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
    body = objects["body"]
    band_lo = objects["band_lo"]
    band_hi = objects["band_hi"]
    crucible = objects["crucible_outer"]
    fire_glow = objects["fire_glow"]
    fire_core = objects["fire_core"]
    valve = objects["valve"]

    # ── idle (2 sec): very subtle heat shimmer ────────────────────────
    animate_shake(body, "idle", duration=2.0, amplitude=0.005, frequency=3)
    animate_shake(crucible, "idle", duration=2.0, amplitude=0.003, frequency=4)
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
    animate_shake(body, "windup", duration=1.0, amplitude=SHAKE_AMP * 0.5, frequency=5)
    animate_shake(crucible, "windup", duration=1.0, amplitude=0.005, frequency=6)
    # Valve wheel turns during windup
    animate_rotation(valve, "windup", duration=1.0, axis='Y',
                     total_angle=math.pi)
    animate_static(fire_glow, "windup", duration=1.0)
    animate_static(fire_core, "windup", duration=1.0)

    # ── active (2 sec): full operation — gears spinning, heat maxed ──
    animate_rotation(mg, "active", duration=2.0, axis='Z',
                     total_angle=math.pi * 4)
    animate_rotation(sg, "active", duration=2.0, axis='Z',
                     total_angle=-math.pi * 4 * GEAR_RATIO)
    animate_shake(body, "active", duration=2.0, amplitude=SHAKE_AMP, frequency=10)
    animate_shake(band_lo, "active", duration=2.0, amplitude=SHAKE_AMP, frequency=10)
    animate_shake(band_hi, "active", duration=2.0, amplitude=SHAKE_AMP, frequency=10)
    animate_shake(crucible, "active", duration=2.0, amplitude=0.008, frequency=12)
    # Fire glow pulsation (subtle Z oscillation to simulate heat shimmer)
    fire_base_z = fire_glow.location.z
    animate_translation(fire_glow, "active", duration=2.0, axis='Z',
                        value_fn=lambda t: fire_base_z + 0.02 * math.sin(t * math.pi * 8))
    core_base_z = fire_core.location.z
    animate_translation(fire_core, "active", duration=2.0, axis='Z',
                        value_fn=lambda t: core_base_z + 0.03 * math.sin(t * math.pi * 6 + 0.5))
    animate_static(valve, "active", duration=2.0)

    # ── winddown (1 sec): decelerating, cooling ──────────────────────
    animate_rotation(mg, "winddown", duration=1.0, axis='Z',
                     angle_fn=lambda t: (2 * t - t * t) * math.pi * 2)
    animate_rotation(sg, "winddown", duration=1.0, axis='Z',
                     angle_fn=lambda t: -(2 * t - t * t) * math.pi * 2 * GEAR_RATIO)
    animate_shake(body, "winddown", duration=1.0, amplitude=SHAKE_AMP, frequency=10, decay=1.0)
    animate_shake(band_lo, "winddown", duration=1.0, amplitude=SHAKE_AMP, frequency=10, decay=1.0)
    animate_shake(band_hi, "winddown", duration=1.0, amplitude=SHAKE_AMP, frequency=10, decay=1.0)
    animate_shake(crucible, "winddown", duration=1.0, amplitude=0.008, frequency=12, decay=1.0)
    animate_translation(fire_glow, "winddown", duration=1.0, axis='Z',
                        value_fn=lambda t: fire_base_z + 0.02 * (1 - t) * math.sin(t * math.pi * 4))
    animate_translation(fire_core, "winddown", duration=1.0, axis='Z',
                        value_fn=lambda t: core_base_z + 0.03 * (1 - t) * math.sin(t * math.pi * 3))
    # Valve turns back
    animate_rotation(valve, "winddown", duration=1.0, axis='Y',
                     angle_fn=lambda t: (1 - t) * math.pi)


# ---------------------------------------------------------------------------
# Texture application
# ---------------------------------------------------------------------------
def apply_textures():
    """Apply PBR textures to all named objects for the textured export."""
    texture_map = {
        "BasePlatform": "metal_plate_02",
        "Body": "painted_metal_shutter",
        "BandLo": "metal_plate",
        "BandHi": "metal_plate",
        "CrucibleOuter": "rusty_metal_02",
        "CrucibleRim": "metal_plate",
        "Chimney": "corrugated_iron",
        "ChimneyCap": "rusty_metal_02",
        "ChimneyHood": "rusty_metal_02",
        "HopperLeft": "metal_plate",
        "HopperRight": "metal_plate",
        "HopperLeftRim": "metal_plate",
        "HopperRightRim": "metal_plate",
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
    # Also apply to feet
    for i in range(4):
        texture_map[f"Foot_{i}"] = "metal_plate"

    for obj_name, tex_id in texture_map.items():
        obj = bpy.data.objects.get(obj_name)
        if obj and obj.type == 'MESH':
            try:
                apply_texture(obj, tex_id, resolution="1k")
            except Exception as e:
                print(f"[smelter_model] Warning: texture '{tex_id}' failed for {obj_name}: {e}")


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
    print(f"[smelter_model] Building smelter, exporting to {output}")

    # -- Build geometry --
    objects = build_smelter()

    # -- Bake animations --
    bake_animations(objects)

    # -- Export FLAT version (no PBR textures) --
    flat_glb = output.replace(".glb", "_flat.glb")
    flat_blend = output.replace(".glb", "_flat.blend")
    export_glb(flat_glb)
    export_blend(flat_blend)
    print(f"[smelter_model] Flat: {flat_glb}")

    # -- Apply PBR textures and export TEXTURED version --
    apply_textures()
    export_glb(output)
    blend_path = os.path.splitext(output)[0] + ".blend"
    export_blend(blend_path)

    print(f"[smelter_model] Textured: {output}")
    print(f"[smelter_model] Blend: {blend_path}")
    print("[smelter_model] Done!")


if __name__ == "__main__":
    main()
