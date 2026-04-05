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
COPPER     = "#B87333"
COPPER_DK  = "#8B5A2B"
RUST       = "#6B4226"
CABLE      = "#2A2A2A"
YELLOW     = "#C8A82A"
RED_WARN   = "#A03030"
GAUGE_FACE = "#D8D0C0"

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

    # ── BASE PLATFORM ─────────────────────────────────────────────────
    # Wider base slab under the body for a sturdier look
    base = add(generate_box(w=2.4, d=2.4, h=0.15, hex_color=STEEL_DK))
    base.name = "BasePlatform"
    apply_texture(base, "metal_plate_02", resolution="1k")

    # Corner feet — small cylinders at each corner
    for i, (fx, fy) in enumerate([(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)]):
        foot = add(generate_cylinder(radius=0.12, height=0.08, segments=8,
                                     hex_color=STEEL_DK))
        foot.name = f"Foot_{i}"
        foot.location = (fx, fy, -0.08)
        apply_texture(foot, "metal_plate", resolution="1k")

    # ── MAIN HOUSING ──────────────────────────────────────────────────
    body = add(generate_box(w=2.0, d=2.0, h=0.8, hex_color=BODY_MAIN, seam_count=2))
    body.name = "Body"
    body.location = (0, 0, 0.15)
    apply_texture(body, "painted_metal_shutter", resolution="1k")

    # Metal reinforcement band
    band = add(generate_box(w=2.1, d=2.1, h=0.15, hex_color=STEEL_DK))
    band.name = "Band"
    band.location = (0, 0, 0.45)
    apply_texture(band, "metal_plate", resolution="1k")

    # Roof plate
    roof = add(generate_box(w=2.2, d=2.2, h=0.15, hex_color=BODY_ROOF))
    roof.name = "Roof"
    roof.location = (0, 0, 0.95)
    apply_texture(roof, "metal_plate_02", resolution="1k")

    # ── BOLTS — scattered across roof and band ────────────────────────
    bolt_positions = [
        # Roof corners
        (0.9, 0.9, 1.1), (-0.9, 0.9, 1.1), (0.9, -0.9, 1.1), (-0.9, -0.9, 1.1),
        # Roof mid-edges
        (0.0, 0.95, 1.1), (0.0, -0.95, 1.1), (0.95, 0.0, 1.1), (-0.95, 0.0, 1.1),
        # Band bolts
        (1.05, 0.7, 0.6), (1.05, -0.7, 0.6), (-1.05, 0.7, 0.6), (-1.05, -0.7, 0.6),
        (0.7, 1.05, 0.6), (-0.7, 1.05, 0.6), (0.7, -1.05, 0.6), (-0.7, -1.05, 0.6),
    ]
    for i, (bx, by, bz) in enumerate(bolt_positions):
        b = add(generate_bolt(head_radius=0.05, head_height=0.03, hex_color=C["rivet"]))
        b.name = f"Bolt_{i}"
        b.location = (bx, by, bz)

    # ── GEARS ─────────────────────────────────────────────────────────
    main_gear = add(generate_cog(outer_radius=0.9, inner_radius=0.5,
                                 teeth=8, thickness=0.3, hex_color=STEEL_LT))
    main_gear.name = "MainGear"
    main_gear.location = (1.1, 0.2, 0.55)
    apply_texture(main_gear, "metal_plate", resolution="1k")

    small_gear = add(generate_cog(outer_radius=0.5, inner_radius=0.35,
                                  teeth=6, thickness=0.3, hex_color=STEEL))
    small_gear.name = "SmallGear"
    small_gear.location = (1.1, -0.8, 0.55)
    apply_texture(small_gear, "metal_plate", resolution="1k")

    # Gear axle caps — small cylinders on gear centers
    for name, pos in [("MainAxle", (1.1, 0.2, 0.72)), ("SmallAxle", (1.1, -0.8, 0.72))]:
        axle = add(generate_cylinder(radius=0.08, height=0.06, segments=8,
                                     hex_color=STEEL_DK))
        axle.name = name
        axle.location = pos

    # ── DERRICK COLUMN ────────────────────────────────────────────────
    derrick = add(generate_cylinder(radius=0.35, height=2.4, segments=12,
                                    hex_color=STEEL))
    derrick.name = "Derrick"
    derrick.location = (0, 0, 1.1)
    apply_texture(derrick, "metal_plate", resolution="1k")

    # Reinforcement rings on derrick at intervals
    for ri, rz in enumerate([0.6, 1.3, 2.0]):
        ring = add(generate_cylinder(radius=0.40, height=0.06, segments=12,
                                     hex_color=STEEL_DK))
        ring.name = f"DerrickRing_{ri}"
        ring.location = (0, 0, 1.1 + rz)
        apply_texture(ring, "metal_plate", resolution="1k")

    # Derrick cap
    cap = add(generate_box(w=0.8, d=0.8, h=0.35, hex_color=BODY_LIGHT, seam_count=1))
    cap.name = "DerrickCap"
    cap.location = (0, 0, 3.5)
    apply_texture(cap, "painted_metal_shutter", resolution="1k")

    # Cone tip
    cone = add(generate_cone(radius_bottom=0.3, radius_top=0, height=0.4,
                             segments=8, hex_color=STEEL_LT))
    cone.name = "ConeTip"
    cone.location = (0, 0, 3.85)
    apply_texture(cone, "metal_plate", resolution="1k")

    # ── DERRICK SUPPORT BRACES ────────────────────────────────────────
    # Diagonal struts from body corners to mid-derrick
    for si, (sx, sy) in enumerate([(0.5, 0.5), (-0.5, 0.5), (0.5, -0.5), (-0.5, -0.5)]):
        strut = add(generate_box(w=0.08, d=0.08, h=1.0, hex_color=STEEL_DK))
        strut.name = f"Strut_{si}"
        # Angle the strut inward toward the derrick
        strut.location = (sx * 0.65, sy * 0.65, 1.1)
        angle_x = math.atan2(sy, 1.0) * 0.35
        angle_y = math.atan2(-sx, 1.0) * 0.35
        strut.rotation_euler = (angle_x, angle_y, 0)
        apply_texture(strut, "metal_plate", resolution="1k")

    # ── PISTON ASSEMBLY ───────────────────────────────────────────────
    sleeve, rod = generate_piston(sleeve_r=0.35, rod_r=0.15, sleeve_h=1.5,
                                  hex_sleeve=STEEL, hex_rod=STEEL_DK)
    sleeve.name = "PistonSleeve"
    rod.name = "PistonRod"
    sleeve.location = (-1.2, -0.6, 0.15)
    add(sleeve)
    apply_texture(sleeve, "metal_plate", resolution="1k")
    apply_texture(rod, "metal_plate", resolution="1k")

    piston_head = generate_cylinder(radius=0.25, height=0.08, segments=12,
                                    hex_color=STEEL_DK)
    piston_head.name = "PistonHead"
    piston_head.location = (0, 0, 1.2)
    piston_head.parent = rod
    apply_texture(piston_head, "metal_plate", resolution="1k")

    # Piston connecting pipe
    pipe = add(generate_pipe(length=0.6, radius=0.12, wall_thickness=0.03,
                             hex_color=C["pipe"]))
    pipe.name = "ConnectPipe"
    pipe.rotation_euler = (0, math.radians(90), 0)
    pipe.location = (-1.2, -0.6, 1.25)
    apply_texture(pipe, "rusty_metal_02", resolution="1k")

    # ── PLUMBING — pipes running along the body ───────────────────────
    # Vertical pipe on front-left corner
    vert_pipe = add(generate_pipe(length=0.7, radius=0.06, wall_thickness=0.015,
                                  hex_color=COPPER))
    vert_pipe.name = "VertPipe"
    vert_pipe.location = (-0.85, -0.85, 0.5)
    apply_texture(vert_pipe, "rusty_metal_02", resolution="1k")

    # Small horizontal pipe connecting vert pipe to body
    h_pipe = add(generate_pipe(length=0.3, radius=0.05, wall_thickness=0.012,
                               hex_color=COPPER))
    h_pipe.name = "HPipe"
    h_pipe.rotation_euler = (0, math.radians(90), 0)
    h_pipe.location = (-0.7, -0.85, 0.7)
    apply_texture(h_pipe, "rusty_metal_02", resolution="1k")

    # Pipe elbow on back-right — vertical stub
    elbow_v = add(generate_pipe(length=0.35, radius=0.06, wall_thickness=0.015,
                                hex_color=COPPER_DK))
    elbow_v.name = "ElbowV"
    elbow_v.location = (0.85, 0.85, 0.3)
    apply_texture(elbow_v, "rusty_metal_02", resolution="1k")

    # ── WIRING / CABLES ──────────────────────────────────────────────
    # Cables represented as very thin cylinders draped between points
    cable_runs = [
        # From body top to piston top
        {"start": (-0.5, -0.3, 1.1), "end": (-1.2, -0.6, 1.4), "name": "Cable_0"},
        # Along derrick
        {"start": (0.2, 0.2, 1.3), "end": (0.2, 0.2, 3.2), "name": "Cable_1"},
        # From exhaust to body
        {"start": (-0.4, 0.7, 1.0), "end": (-0.1, 0.3, 1.1), "name": "Cable_2"},
    ]
    for ci, run in enumerate(cable_runs):
        sx, sy, sz = run["start"]
        ex, ey, ez = run["end"]
        dx, dy, dz = ex - sx, ey - sy, ez - sz
        length = math.sqrt(dx*dx + dy*dy + dz*dz)
        cx, cy, cz = (sx + ex) / 2, (sy + ey) / 2, (sz + ez) / 2

        cable = add(generate_cylinder(radius=0.02, height=length, segments=6,
                                      hex_color=CABLE))
        cable.name = run["name"]
        # Orient cable along the direction vector
        cable.location = (sx, sy, sz)
        pitch = math.acos(max(-1, min(1, dz / length))) if length > 0 else 0
        yaw = math.atan2(dy, dx)
        cable.rotation_euler = (0, pitch, yaw)

    # ── CONTROL PANEL (front face) ────────────────────────────────────
    # Panel box
    panel = add(generate_box(w=0.5, d=0.08, h=0.35, hex_color=BODY_LIGHT))
    panel.name = "ControlPanel"
    panel.location = (0.3, -1.05, 0.45)
    apply_texture(panel, "painted_metal_shutter", resolution="1k")

    # Gauge — flat cylinder on panel face
    gauge = add(generate_cylinder(radius=0.1, height=0.03, segments=10,
                                  hex_color=GAUGE_FACE))
    gauge.name = "Gauge"
    gauge.rotation_euler = (math.radians(90), 0, 0)
    gauge.location = (0.2, -1.1, 0.55)

    # Gauge rim
    gauge_rim = add(generate_cylinder(radius=0.12, height=0.02, segments=10,
                                      hex_color=COPPER))
    gauge_rim.name = "GaugeRim"
    gauge_rim.rotation_euler = (math.radians(90), 0, 0)
    gauge_rim.location = (0.2, -1.11, 0.55)

    # Toggle switches / knobs on panel
    for ki, kx in enumerate([0.35, 0.45]):
        knob = add(generate_cylinder(radius=0.03, height=0.04, segments=6,
                                     hex_color=RED_WARN if ki == 0 else YELLOW))
        knob.name = f"Knob_{ki}"
        knob.rotation_euler = (math.radians(90), 0, 0)
        knob.location = (kx, -1.1, 0.47)

    # ── VALVE WHEEL (on back pipe) ────────────────────────────────────
    valve = add(generate_cog(outer_radius=0.15, inner_radius=0.1,
                             teeth=5, thickness=0.04, hex_color=RED_WARN))
    valve.name = "ValveWheel"
    valve.rotation_euler = (math.radians(90), 0, 0)
    valve.location = (0.6, 0.98, 0.5)

    # Valve stem
    valve_stem = add(generate_cylinder(radius=0.025, height=0.1, segments=6,
                                       hex_color=STEEL_DK))
    valve_stem.name = "ValveStem"
    valve_stem.rotation_euler = (math.radians(90), 0, 0)
    valve_stem.location = (0.6, 1.0, 0.5)

    # ── EXHAUST STACK ─────────────────────────────────────────────────
    exhaust = add(generate_cylinder(radius=0.25, height=0.9, segments=10,
                                    hex_color=C["pipe"]))
    exhaust.name = "ExhaustStack"
    exhaust.location = (-0.4, 0.75, 0.95)
    apply_texture(exhaust, "corrugated_iron", resolution="1k")

    # Exhaust cap — wider disc
    exhaust_cap = add(generate_cylinder(radius=0.3, height=0.08, segments=10,
                                        hex_color=STEEL_DK))
    exhaust_cap.name = "ExhaustCap"
    exhaust_cap.location = (-0.4, 0.75, 1.85)
    apply_texture(exhaust_cap, "rusty_metal_02", resolution="1k")

    # Exhaust rain cap — cone above cap with gap
    rain_cap = add(generate_cone(radius_bottom=0.28, radius_top=0.05, height=0.15,
                                 segments=8, hex_color=RUST))
    rain_cap.name = "RainCap"
    rain_cap.location = (-0.4, 0.75, 1.98)
    apply_texture(rain_cap, "rusty_metal_02", resolution="1k")

    # Exhaust mounting bracket — wedge at base
    bracket = add(generate_wedge(w=0.3, d=0.3, h_front=0.0, h_back=0.25,
                                 hex_color=STEEL_DK))
    bracket.name = "ExhaustBracket"
    bracket.location = (-0.4, 0.55, 0.95)
    apply_texture(bracket, "metal_plate", resolution="1k")

    # ── SIDE TANK / CANISTER ──────────────────────────────────────────
    tank = add(generate_cylinder(radius=0.18, height=0.5, segments=10,
                                 hex_color=BODY_LIGHT))
    tank.name = "SideTank"
    tank.rotation_euler = (0, 0, 0)
    tank.location = (0.85, -0.65, 0.15)
    apply_texture(tank, "painted_metal_shutter", resolution="1k")

    # Tank cap
    tank_cap = add(generate_hemisphere(radius=0.18, rings=3, segments=10,
                                       hex_color=BODY_ROOF))
    tank_cap.name = "TankCap"
    tank_cap.location = (0.85, -0.65, 0.65)

    # Tank bands
    for ti, tz in enumerate([0.25, 0.45]):
        tband = add(generate_cylinder(radius=0.20, height=0.03, segments=10,
                                      hex_color=STEEL_DK))
        tband.name = f"TankBand_{ti}"
        tband.location = (0.85, -0.65, tz)

    # Tank feed pipe — connects to body
    tank_pipe = add(generate_pipe(length=0.25, radius=0.04, wall_thickness=0.01,
                                  hex_color=COPPER))
    tank_pipe.name = "TankPipe"
    tank_pipe.rotation_euler = (0, math.radians(90), math.radians(30))
    tank_pipe.location = (0.65, -0.65, 0.4)

    # ── WARNING DETAILS ───────────────────────────────────────────────
    # Hazard stripe band near base
    hazard = add(generate_box(w=2.05, d=2.05, h=0.04, hex_color=YELLOW))
    hazard.name = "HazardStripe"
    hazard.location = (0, 0, 0.18)

    # ── EXTRA BOLTS on body sides ─────────────────────────────────────
    side_bolt_positions = [
        # Front face
        (-0.6, -1.01, 0.35), (0.6, -1.01, 0.35),
        (-0.6, -1.01, 0.75), (0.6, -1.01, 0.75),
        # Left face
        (-1.01, -0.6, 0.35), (-1.01, 0.6, 0.35),
        (-1.01, -0.6, 0.75), (-1.01, 0.6, 0.75),
    ]
    for i, (bx, by, bz) in enumerate(side_bolt_positions):
        sb = add(generate_bolt(head_radius=0.04, head_height=0.025, hex_color=C["rivet"]))
        sb.name = f"SideBolt_{i}"
        sb.location = (bx, by, bz)

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


def main():
    output = parse_args()
    print(f"[drill_model] Building drill, exporting to {output}")

    objects = build_drill()
    bake_animations(objects)
    export_glb(output)

    print(f"[drill_model] Done: {output}")


if __name__ == "__main__":
    main()
