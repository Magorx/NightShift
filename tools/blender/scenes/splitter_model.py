"""Export splitter as a 3D model (.glb) for Godot import.

The splitter divides one input stream into multiple outputs. During the day
it distributes items; at night it becomes a multi-target turret.
Design: low, wide, round base with a rotating distributor hub on top and
three output chutes radiating at 120-degree intervals. One input hopper.
More steel/gray tones than the warm brown smelter, with yellow directional
accents on output chutes.

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/splitter_model.py

    # Custom output path:
    $BLENDER --background --python tools/blender/scenes/splitter_model.py -- --output path/to/splitter.glb
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
from prefabs_src.pipe import generate_pipe
from prefabs_src.bolt import generate_bolt
from prefabs_src.hemisphere import generate_hemisphere
from prefabs_src.wedge import generate_wedge
from prefabs_src.fan import generate_fan
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

    output = os.path.join(REPO_ROOT, "buildings", "splitter", "models", "splitter.glb")

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

# Steel tones (primary palette for splitter -- more metallic than smelter/drill)
STEEL      = "#7A8898"
STEEL_DK   = "#6A7888"
STEEL_LT   = "#96A4B4"
BODY_MAIN  = "#5A5A68"   # Bluer gray body (not warm brown like drill)
BODY_LIGHT = "#6E6E7A"
BODY_ROOF  = "#7A7A88"
COPPER     = "#B87333"
COPPER_DK  = "#8B5A2B"
RUST       = "#6B4226"
CABLE      = "#2A2A2A"
YELLOW     = "#C8A82A"   # Directional marker accent
RED_WARN   = "#A03030"
GAUGE_FACE = "#D8D0C0"

# Hub (distinctive rotating element) -- lighter, shinier steel
HUB_MAIN   = "#8A96A8"
HUB_ACCENT = "#A0ACB8"

# Animation constants
HUB_ACTIVE_RPM = 3       # Revolutions in 2 seconds active state
SHAKE_AMP      = 0.005


# ---------------------------------------------------------------------------
# Build the scene
# ---------------------------------------------------------------------------
def build_splitter():
    """Build the full splitter as a parented hierarchy under a root empty."""
    clear_scene()

    root = bpy.data.objects.new("Splitter", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.25
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # ── BASE PLATFORM ─────────────────────────────────────────────────
    # Round base platform to distinguish from drill/smelter square bases
    base = add(generate_cylinder(radius=0.65, height=0.05, segments=16,
                                  hex_color=STEEL_DK))
    base.name = "BasePlatform"

    # Corner/edge support feet -- 6 pads in hexagonal arrangement
    for i in range(6):
        angle = (i / 6) * 2 * math.pi
        fx = 0.55 * math.cos(angle)
        fy = 0.55 * math.sin(angle)
        foot = add(generate_cylinder(radius=0.05, height=0.03, segments=8,
                                     hex_color=STEEL_DK))
        foot.name = f"Foot_{i}"
        foot.location = (fx, fy, -0.03)

    # ── MAIN HOUSING (octagonal feel via 16-segment cylinder) ─────────
    # Low, wide cylinder body -- the splitter is squat, hub-shaped
    body = add(generate_cylinder(radius=0.55, height=0.275, segments=16,
                                  hex_color=BODY_MAIN))
    body.name = "Body"
    body.location = (0, 0, 0.05)

    # Lower reinforcement ring
    ring_lo = add(generate_cylinder(radius=0.575, height=0.04, segments=16,
                                     hex_color=STEEL_DK))
    ring_lo.name = "RingLo"
    ring_lo.location = (0, 0, 0.07)

    # Upper reinforcement ring
    ring_hi = add(generate_cylinder(radius=0.575, height=0.04, segments=16,
                                     hex_color=STEEL_DK))
    ring_hi.name = "RingHi"
    ring_hi.location = (0, 0, 0.26)

    # Roof plate -- slightly wider, flat disc on top of body
    roof = add(generate_cylinder(radius=0.59, height=0.04, segments=16,
                                  hex_color=BODY_ROOF))
    roof.name = "Roof"
    roof.location = (0, 0, 0.325)

    # Hazard stripe ring near base
    hazard = add(generate_cylinder(radius=0.56, height=0.015, segments=16,
                                    hex_color=YELLOW))
    hazard.name = "HazardStripe"
    hazard.location = (0, 0, 0.065)

    # ── CENTRAL HUB / DISTRIBUTOR (rotating element) ──────────────────
    # This is the visual signature -- a raised turntable/carousel on top

    # Hub pedestal -- short cylinder raising the hub above the roof
    hub_pedestal = add(generate_cylinder(radius=0.225, height=0.075, segments=12,
                                          hex_color=STEEL_DK))
    hub_pedestal.name = "HubPedestal"
    hub_pedestal.location = (0, 0, 0.365)

    # Hub body -- the main rotating disc
    hub = add(generate_cylinder(radius=0.275, height=0.10, segments=12,
                                 hex_color=HUB_MAIN))
    hub.name = "Hub"
    hub.location = (0, 0, 0.44)

    # Hub dome cap -- hemisphere on top for a polished look
    hub_dome = add(generate_hemisphere(radius=0.15, rings=3, segments=10,
                                        hex_color=HUB_ACCENT))
    hub_dome.name = "HubDome"
    hub_dome.location = (0, 0, 0.54)

    # Hub rim ring -- decorative ring around the spinning disc
    hub_rim = add(generate_cylinder(radius=0.29, height=0.02, segments=12,
                                     hex_color=STEEL_LT))
    hub_rim.name = "HubRim"
    hub_rim.location = (0, 0, 0.46)

    # Hub gear ring (decorative, visible between pedestal and hub)
    hub_gear = add(generate_cog(outer_radius=0.25, inner_radius=0.19,
                                teeth=12, thickness=0.04, hex_color=STEEL))
    hub_gear.name = "HubGear"
    hub_gear.location = (0, 0, 0.40)

    # Distributor arms -- 3 prominent radial fins on the hub (rotate with it)
    # These are paddle/vanes that visually "push" items to outputs
    for i in range(3):
        angle = (i / 3) * 2 * math.pi
        arm = add(generate_box(w=0.05, d=0.275, h=0.09, hex_color=HUB_ACCENT))
        arm.name = f"DistArm_{i}"
        # Position at hub edge, rotated around center
        ax = 0.16 * math.cos(angle)
        ay = 0.16 * math.sin(angle)
        arm.location = (ax, ay, 0.46)
        arm.rotation_euler = (0, 0, angle)

    # Arm tip markers -- yellow dots at the end of each arm
    for i in range(3):
        angle = (i / 3) * 2 * math.pi
        tip = add(generate_cylinder(radius=0.02, height=0.03, segments=6,
                                     hex_color=YELLOW))
        tip.name = f"ArmTip_{i}"
        tip.location = (0.275 * math.cos(angle), 0.275 * math.sin(angle), 0.48)
        tip.rotation_euler = (0, 0, angle)

    # ── OUTPUT CHUTES (3 at 120-degree intervals) ─────────────────────
    # Each chute: a pipe angled downward + yellow directional marker
    chute_angles = [0, 2 * math.pi / 3, 4 * math.pi / 3]  # 0, 120, 240 degrees
    chute_objects = []

    for ci, angle in enumerate(chute_angles):
        cos_a = math.cos(angle)
        sin_a = math.sin(angle)

        # Chute pipe -- angled downward from body edge
        chute = add(generate_pipe(length=0.3, radius=0.06, wall_thickness=0.015,
                                  hex_color=C["pipe"]))
        chute.name = f"OutputChute_{ci}"
        # Position at body edge, tilted outward and down
        chute.location = (cos_a * 0.475, sin_a * 0.475, 0.20)
        # Tilt outward: rotate around the perpendicular axis
        # The pipe runs along Z, so we tilt it outward
        chute.rotation_euler = (
            math.radians(50) * sin_a,   # tilt in X based on Y direction
            -math.radians(50) * cos_a,  # tilt in Y based on X direction
            angle                        # face outward
        )
        chute_objects.append(chute)

        # Chute mounting plate (where chute meets body)
        mount = add(generate_cylinder(radius=0.08, height=0.025, segments=8,
                                       hex_color=STEEL_DK))
        mount.name = f"ChuteMountPlate_{ci}"
        mount.location = (cos_a * 0.54, sin_a * 0.54, 0.20)

        # Yellow directional marker arrow/band on each chute
        marker = add(generate_cylinder(radius=0.07, height=0.015, segments=8,
                                        hex_color=YELLOW))
        marker.name = f"ChuteMarker_{ci}"
        # Place along chute pipe, offset outward
        marker.location = (cos_a * 0.625, sin_a * 0.625, 0.11)

        # Chute tip flare -- wider exit
        tip = add(generate_cone(radius_bottom=0.05, radius_top=0.08,
                                 height=0.04, segments=8, hex_color=STEEL))
        tip.name = f"ChuteTip_{ci}"
        tip.location = (cos_a * 0.675, sin_a * 0.675, 0.06)

    # ── INPUT HOPPER (single, on one side -- between two output chutes) ──
    # Positioned at 180 degrees (opposite from the 0-degree chute)
    # This is a truncated cone funnel that items enter through
    hopper_angle = math.pi  # 180 degrees -- back of the splitter
    hx = math.cos(hopper_angle) * 0.425
    hy = math.sin(hopper_angle) * 0.425

    # Hopper funnel -- wider at top, narrows into body. Taller and more prominent.
    hopper = add(generate_cone(radius_bottom=0.09, radius_top=0.175,
                                height=0.275, segments=8, hex_color=STEEL))
    hopper.name = "InputHopper"
    hopper.location = (hx, hy, 0.26)

    # Hopper rim -- wide ring at top
    hopper_rim = add(generate_cylinder(radius=0.19, height=0.025, segments=8,
                                        hex_color=STEEL_DK))
    hopper_rim.name = "HopperRim"
    hopper_rim.location = (hx, hy, 0.535)

    # Hopper interior darkness (visible from above)
    hopper_dark = add(generate_cylinder(radius=0.125, height=0.015, segments=8,
                                         hex_color=C["intake_dark"]))
    hopper_dark.name = "HopperDark"
    hopper_dark.location = (hx, hy, 0.52)

    # Hopper support bracket -- wedge connecting to body
    hopper_bracket = add(generate_wedge(w=0.125, d=0.10, h_front=0.0, h_back=0.09,
                                         hex_color=STEEL_DK))
    hopper_bracket.name = "HopperBracket"
    hopper_bracket.location = (hx * 0.75, hy * 0.75, 0.275)
    hopper_bracket.rotation_euler = (0, 0, hopper_angle + math.radians(90))

    # ── GEAR MECHANISM (visible on one side, pushed outward for visibility) ──
    # Drive gear -- connects to the hub rotation mechanism
    main_gear = add(generate_cog(outer_radius=0.25, inner_radius=0.175,
                                 teeth=10, thickness=0.10, hex_color=STEEL_LT))
    main_gear.name = "MainGear"
    main_gear.location = (0.45, 0.40, 0.26)

    small_gear = add(generate_cog(outer_radius=0.15, inner_radius=0.11,
                                  teeth=6, thickness=0.10, hex_color=STEEL))
    small_gear.name = "SmallGear"
    small_gear.location = (0.225, 0.575, 0.26)

    # Gear axle caps
    for name, pos in [("MainAxle", (0.45, 0.40, 0.315)),
                      ("SmallAxle", (0.225, 0.575, 0.315))]:
        axle = add(generate_cylinder(radius=0.03, height=0.02, segments=8,
                                     hex_color=STEEL_DK))
        axle.name = name
        axle.location = pos

    # ── PLUMBING -- pipes along body ──────────────────────────────────
    # Vertical pipe on one side
    vert_pipe = add(generate_pipe(length=0.25, radius=0.025, wall_thickness=0.006,
                                  hex_color=COPPER))
    vert_pipe.name = "VertPipe"
    vert_pipe.location = (0.375, -0.375, 0.125)

    # Horizontal connecting pipe
    h_pipe = add(generate_pipe(length=0.11, radius=0.02, wall_thickness=0.005,
                               hex_color=COPPER))
    h_pipe.name = "HPipe"
    h_pipe.rotation_euler = (0, math.radians(90), 0)
    h_pipe.location = (0.31, -0.375, 0.25)

    # Small pipe on back
    back_pipe = add(generate_pipe(length=0.15, radius=0.025, wall_thickness=0.006,
                                  hex_color=COPPER_DK))
    back_pipe.name = "BackPipe"
    back_pipe.location = (-0.35, 0.35, 0.125)

    # ── CONTROL PANEL (front face area) ───────────────────────────────
    panel = add(generate_box(w=0.225, d=0.035, h=0.14, hex_color=BODY_LIGHT))
    panel.name = "ControlPanel"
    panel.location = (0.175, -0.525, 0.175)

    # Gauge
    gauge = add(generate_cylinder(radius=0.04, height=0.015, segments=10,
                                  hex_color=GAUGE_FACE))
    gauge.name = "Gauge"
    gauge.rotation_euler = (math.radians(90), 0, 0)
    gauge.location = (0.125, -0.545, 0.225)

    # Gauge rim
    gauge_rim = add(generate_cylinder(radius=0.05, height=0.01, segments=10,
                                      hex_color=COPPER))
    gauge_rim.name = "GaugeRim"
    gauge_rim.rotation_euler = (math.radians(90), 0, 0)
    gauge_rim.location = (0.125, -0.55, 0.225)

    # Toggle knobs
    for ki, kx in enumerate([0.20, 0.24]):
        knob = add(generate_cylinder(radius=0.0125, height=0.0175, segments=6,
                                     hex_color=RED_WARN if ki == 0 else YELLOW))
        knob.name = f"Knob_{ki}"
        knob.rotation_euler = (math.radians(90), 0, 0)
        knob.location = (kx, -0.545, 0.19)

    # ── VALVE WHEEL (on pipe) ─────────────────────────────────────────
    valve = add(generate_cog(outer_radius=0.06, inner_radius=0.04,
                             teeth=5, thickness=0.015, hex_color=RED_WARN))
    valve.name = "ValveWheel"
    valve.rotation_euler = (math.radians(90), 0, 0)
    valve.location = (-0.275, -0.475, 0.20)

    valve_stem = add(generate_cylinder(radius=0.01, height=0.035, segments=6,
                                       hex_color=STEEL_DK))
    valve_stem.name = "ValveStem"
    valve_stem.rotation_euler = (math.radians(90), 0, 0)
    valve_stem.location = (-0.275, -0.485, 0.20)

    # ── WIRING / CABLES ──────────────────────────────────────────────
    cable_runs = [
        # From panel area to body top
        {"start": (0.175, -0.45, 0.30), "end": (0.10, -0.20, 0.35), "name": "Cable_0"},
        # From gear area to hub pedestal
        {"start": (0.325, 0.30, 0.325), "end": (0.125, 0.10, 0.375), "name": "Cable_1"},
        # Along body side
        {"start": (-0.30, -0.30, 0.25), "end": (-0.35, 0.20, 0.25), "name": "Cable_2"},
    ]
    for ci, run in enumerate(cable_runs):
        sx, sy, sz = run["start"]
        ex, ey, ez = run["end"]
        dx, dy, dz = ex - sx, ey - sy, ez - sz
        length = math.sqrt(dx*dx + dy*dy + dz*dz)

        cable = add(generate_cylinder(radius=0.009, height=length, segments=6,
                                      hex_color=CABLE))
        cable.name = run["name"]
        cable.location = (sx, sy, sz)
        pitch = math.acos(max(-1, min(1, dz / length))) if length > 0 else 0
        yaw = math.atan2(dy, dx)
        cable.rotation_euler = (0, pitch, yaw)

    # ── BOLTS — scattered on roof and body ────────────────────────────
    # Roof bolts (around the edge of the roof disc)
    for i in range(8):
        angle = (i / 8) * 2 * math.pi
        bx = 0.525 * math.cos(angle)
        by = 0.525 * math.sin(angle)
        b = add(generate_bolt(head_radius=0.02, head_height=0.0125, hex_color=C["rivet"]))
        b.name = f"RoofBolt_{i}"
        b.location = (bx, by, 0.37)

    # Ring bolts on lower and upper rings
    for ri, rz in enumerate([0.09, 0.28]):
        for i in range(6):
            angle = (i / 6) * 2 * math.pi + (ri * math.pi / 6)  # stagger
            bx = 0.57 * math.cos(angle)
            by = 0.57 * math.sin(angle)
            b = add(generate_bolt(head_radius=0.0175, head_height=0.01, hex_color=C["rivet"]))
            b.name = f"RingBolt_{ri}_{i}"
            b.location = (bx, by, rz)

    # Hub pedestal bolts (around the pedestal)
    for i in range(4):
        angle = (i / 4) * 2 * math.pi + math.pi / 8
        bx = 0.21 * math.cos(angle)
        by = 0.21 * math.sin(angle)
        b = add(generate_bolt(head_radius=0.015, head_height=0.01, hex_color=C["rivet"]))
        b.name = f"PedestalBolt_{i}"
        b.location = (bx, by, 0.445)

    return {
        "root": root,
        "hub": hub,
        "hub_dome": hub_dome,
        "hub_rim": hub_rim,
        "hub_gear": hub_gear,
        "dist_arms": [bpy.data.objects.get(f"DistArm_{i}") for i in range(3)],
        "arm_tips": [bpy.data.objects.get(f"ArmTip_{i}") for i in range(3)],
        "main_gear": main_gear,
        "small_gear": small_gear,
        "body": body,
        "ring_lo": ring_lo,
        "ring_hi": ring_hi,
        "roof": roof,
        "chute_objects": chute_objects,
    }


# ---------------------------------------------------------------------------
# Animation — using anim_helpers
# ---------------------------------------------------------------------------
GEAR_RATIO = 10 / 6  # main gear teeth / small gear teeth


def bake_animations(objects):
    """Bake all animation states using high-level helpers."""
    hub = objects["hub"]
    hub_dome = objects["hub_dome"]
    hub_rim = objects["hub_rim"]
    hub_gear = objects["hub_gear"]
    dist_arms = objects["dist_arms"]
    arm_tips = objects["arm_tips"]
    mg = objects["main_gear"]
    sg = objects["small_gear"]
    body = objects["body"]
    ring_lo = objects["ring_lo"]
    ring_hi = objects["ring_hi"]
    roof = objects["roof"]
    chutes = objects["chute_objects"]

    # -- All hub parts: hub, dome, rim, arms, arm tips rotate together --
    hub_parts = [hub, hub_dome, hub_rim] + dist_arms + arm_tips

    # ── idle (2 sec): hub barely rotating, subtle ─────────────────────
    for part in hub_parts:
        animate_rotation(part, "idle", duration=2.0, axis='Z',
                         angle_fn=lambda t: 0.05 * math.sin(t * math.pi * 2))
    animate_rotation(hub_gear, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: -0.05 * math.sin(t * math.pi * 2))
    animate_rotation(mg, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.03 * math.sin(t * math.pi * 2))
    animate_rotation(sg, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: -0.03 * GEAR_RATIO * math.sin(t * math.pi * 2))
    animate_static(body, "idle", duration=2.0)
    # Static chutes in idle
    for chute in chutes:
        animate_static(chute, "idle", duration=2.0)

    # ── windup (1 sec): hub accelerating ──────────────────────────────
    for part in hub_parts:
        animate_rotation(part, "windup", duration=1.0, axis='Z',
                         angle_fn=lambda t: t * t * math.pi * 2)
    animate_rotation(hub_gear, "windup", duration=1.0, axis='Z',
                     angle_fn=lambda t: -t * t * math.pi * 2)
    animate_rotation(mg, "windup", duration=1.0, axis='Z',
                     angle_fn=lambda t: t * t * math.pi * 2)
    animate_rotation(sg, "windup", duration=1.0, axis='Z',
                     angle_fn=lambda t: -t * t * math.pi * 2 * GEAR_RATIO)
    animate_shake(body, "windup", duration=1.0, amplitude=SHAKE_AMP * 0.3, frequency=4)
    for chute in chutes:
        animate_static(chute, "windup", duration=1.0)

    # ── active (2 sec): full speed hub spinning, body vibration ───────
    total_hub_angle = math.pi * 2 * HUB_ACTIVE_RPM  # 3 full rotations in 2s
    for part in hub_parts:
        animate_rotation(part, "active", duration=2.0, axis='Z',
                         total_angle=total_hub_angle)
    animate_rotation(hub_gear, "active", duration=2.0, axis='Z',
                     total_angle=-total_hub_angle)
    animate_rotation(mg, "active", duration=2.0, axis='Z',
                     total_angle=math.pi * 4)
    animate_rotation(sg, "active", duration=2.0, axis='Z',
                     total_angle=-math.pi * 4 * GEAR_RATIO)
    animate_shake(body, "active", duration=2.0, amplitude=SHAKE_AMP, frequency=8)
    animate_shake(ring_lo, "active", duration=2.0, amplitude=SHAKE_AMP, frequency=8)
    animate_shake(ring_hi, "active", duration=2.0, amplitude=SHAKE_AMP, frequency=8)
    animate_shake(roof, "active", duration=2.0, amplitude=SHAKE_AMP * 0.5, frequency=8)
    # Chutes pulse -- subtle Z oscillation simulating item ejection
    for ci, chute in enumerate(chutes):
        base_z = chute.location.z
        phase_offset = ci * 2 * math.pi / 3
        animate_translation(chute, "active", duration=2.0, axis='Z',
                            value_fn=lambda t, bz=base_z, po=phase_offset:
                                bz + 0.0075 * math.sin(t * math.pi * 12 + po))

    # ── winddown (1 sec): hub decelerating ────────────────────────────
    decel_hub_angle = math.pi * 2 * 1.5  # 1.5 rotations, decelerating
    for part in hub_parts:
        animate_rotation(part, "winddown", duration=1.0, axis='Z',
                         angle_fn=lambda t: (2 * t - t * t) * decel_hub_angle)
    animate_rotation(hub_gear, "winddown", duration=1.0, axis='Z',
                     angle_fn=lambda t: -(2 * t - t * t) * decel_hub_angle)
    animate_rotation(mg, "winddown", duration=1.0, axis='Z',
                     angle_fn=lambda t: (2 * t - t * t) * math.pi * 2)
    animate_rotation(sg, "winddown", duration=1.0, axis='Z',
                     angle_fn=lambda t: -(2 * t - t * t) * math.pi * 2 * GEAR_RATIO)
    animate_shake(body, "winddown", duration=1.0, amplitude=SHAKE_AMP, frequency=8, decay=1.0)
    animate_shake(ring_lo, "winddown", duration=1.0, amplitude=SHAKE_AMP, frequency=8, decay=1.0)
    animate_shake(ring_hi, "winddown", duration=1.0, amplitude=SHAKE_AMP, frequency=8, decay=1.0)
    animate_shake(roof, "winddown", duration=1.0, amplitude=SHAKE_AMP * 0.5, frequency=8, decay=1.0)
    for ci, chute in enumerate(chutes):
        base_z = chute.location.z
        phase_offset = ci * 2 * math.pi / 3
        animate_translation(chute, "winddown", duration=1.0, axis='Z',
                            value_fn=lambda t, bz=base_z, po=phase_offset:
                                bz + 0.0075 * (1 - t) * math.sin(t * math.pi * 6 + po))


# ---------------------------------------------------------------------------
# Texture application
# ---------------------------------------------------------------------------
def apply_textures():
    """Apply PBR textures to all named objects for the textured export."""
    texture_map = {
        "BasePlatform": "metal_plate_02",
        "Body": "metal_plate",
        "RingLo": "metal_plate",
        "RingHi": "metal_plate",
        "Roof": "metal_plate_02",
        "HubPedestal": "metal_plate",
        "Hub": "metal_plate",
        "HubRim": "metal_plate",
        "MainGear": "metal_plate",
        "SmallGear": "metal_plate",
        "ControlPanel": "painted_metal_shutter",
        "InputHopper": "metal_plate",
        "HopperRim": "metal_plate",
        "VertPipe": "rusty_metal_02",
        "HPipe": "rusty_metal_02",
        "BackPipe": "rusty_metal_02",
    }
    # Feet
    for i in range(6):
        texture_map[f"Foot_{i}"] = "metal_plate"
    # Output chutes and mounts
    for i in range(3):
        texture_map[f"OutputChute_{i}"] = "rusty_metal_02"
        texture_map[f"ChuteMountPlate_{i}"] = "metal_plate"

    for obj_name, tex_id in texture_map.items():
        obj = bpy.data.objects.get(obj_name)
        if obj and obj.type == 'MESH':
            try:
                apply_texture(obj, tex_id, resolution="1k")
            except Exception as e:
                print(f"[splitter_model] Warning: texture '{tex_id}' failed for {obj_name}: {e}")


def main():
    output = parse_args()
    print(f"[splitter_model] Building splitter, exporting to {output}")

    # -- Build geometry --
    objects = build_splitter()

    # -- Bake animations --
    bake_animations(objects)

    # -- Export FLAT version (no PBR textures) --
    flat_glb = output.replace(".glb", "_flat.glb")
    export_glb(flat_glb)
    print(f"[splitter_model] Flat: {flat_glb}")

    # -- Apply PBR textures and export TEXTURED version --
    apply_textures()
    export_glb(output)

    print(f"[splitter_model] Textured: {output}")
    print("[splitter_model] Done!")


if __name__ == "__main__":
    main()
