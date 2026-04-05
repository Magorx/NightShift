"""Export player character as a 3D model (.glb) for Godot import.

Composes a chunky, low-poly industrial worker from prefab primitives.
Bakes 4 NLA animation states: idle, walk, run, build.

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/player_model.py

    # Custom output path:
    $BLENDER --background --python tools/blender/scenes/player_model.py -- --output path/to/player.glb
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
from materials.pixel_art import create_flat_material
from prefabs_src.box import generate_box
from prefabs_src.cylinder import generate_cylinder
from prefabs_src.sphere import generate_sphere
from prefabs_src.hemisphere import generate_hemisphere
from prefabs_src.bolt import generate_bolt
from anim_helpers import (
    animate_rotation, animate_translation, animate_scale,
    animate_shake, animate_static, FPS,
)


def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []

    output = os.path.join(REPO_ROOT, "player", "models", "player.glb")

    i = 0
    while i < len(argv):
        if argv[i] == "--output" and i + 1 < len(argv):
            output = argv[i + 1]; i += 2
        else:
            i += 1

    return output


# ---------------------------------------------------------------------------
# Colors -- industrial worker palette
# ---------------------------------------------------------------------------
HARDHAT    = "#F5A01E"   # safety yellow-orange
JUMPSUIT   = "#3C5A78"   # dark blue-gray work clothes
BOOTS      = "#3A2820"   # dark brown
SKIN       = "#D4A574"   # warm skin tone
VISOR      = "#88CCEE"   # light blue, reflective
BACKPACK   = "#5A4838"   # matches building body color
GLOVES     = "#6A5A4A"   # leather brown
BELT_COL   = "#2A2420"   # dark belt
BUCKLE     = "#B8A040"   # brass buckle


# ---------------------------------------------------------------------------
# Build the player
# ---------------------------------------------------------------------------
def build_player():
    """Build the player character as a parented hierarchy under a root empty."""
    clear_scene()

    root = bpy.data.objects.new("Player", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # ── TORSO ─────────────────────────────────────────────────────────
    torso = add(generate_box(w=0.40, d=0.25, h=0.45, hex_color=JUMPSUIT))
    torso.name = "Torso"
    torso.location = (0, 0, 0.50)  # legs below, head above

    # Belt around waist (thin box)
    belt = add(generate_box(w=0.42, d=0.27, h=0.06, hex_color=BELT_COL))
    belt.name = "Belt"
    belt.location = (0, 0, 0.50)

    # Belt buckle (small bolt detail on front)
    buckle = add(generate_bolt(head_radius=0.03, head_height=0.02,
                               shaft_radius=0.015, shaft_length=0.01,
                               hex_color=BUCKLE))
    buckle.name = "Buckle"
    buckle.location = (0, -0.14, 0.53)

    # ── HEAD ──────────────────────────────────────────────────────────
    head = add(generate_sphere(radius=0.16, rings=5, segments=10,
                               hex_color=SKIN))
    head.name = "Head"
    head.location = (0, 0, 1.12)

    # Hardhat (hemisphere on top of head)
    hardhat = add(generate_hemisphere(radius=0.19, rings=3, segments=10,
                                      hex_color=HARDHAT))
    hardhat.name = "Hardhat"
    hardhat.location = (0, 0, 1.16)

    # Hardhat brim -- very thin, wider cylinder under the hat
    brim = add(generate_cylinder(radius=0.22, height=0.025, segments=10,
                                 hex_color=HARDHAT))
    brim.name = "HardhatBrim"
    brim.location = (0, 0, 1.14)

    # Visor / goggles on the face
    visor = add(generate_box(w=0.18, d=0.04, h=0.06, hex_color=VISOR))
    visor.name = "Visor"
    visor.location = (0, -0.15, 1.14)

    # Visor strap (thin box wrapping around head)
    strap = add(generate_box(w=0.30, d=0.30, h=0.025, hex_color=BELT_COL))
    strap.name = "VisorStrap"
    strap.location = (0, 0, 1.15)

    # ── LEFT ARM ──────────────────────────────────────────────────────
    left_arm = add(generate_cylinder(radius=0.055, height=0.38, segments=8,
                                     hex_color=JUMPSUIT))
    left_arm.name = "LeftArm"
    left_arm.location = (-0.26, 0, 0.60)

    # Left glove (hand)
    left_glove = add(generate_box(w=0.08, d=0.08, h=0.07, hex_color=GLOVES))
    left_glove.name = "LeftGlove"
    left_glove.location = (-0.26, 0, 0.55)

    # ── RIGHT ARM ─────────────────────────────────────────────────────
    right_arm = add(generate_cylinder(radius=0.055, height=0.38, segments=8,
                                      hex_color=JUMPSUIT))
    right_arm.name = "RightArm"
    right_arm.location = (0.26, 0, 0.60)

    # Right glove (hand)
    right_glove = add(generate_box(w=0.08, d=0.08, h=0.07, hex_color=GLOVES))
    right_glove.name = "RightGlove"
    right_glove.location = (0.26, 0, 0.55)

    # ── LEFT LEG ──────────────────────────────────────────────────────
    left_leg = add(generate_cylinder(radius=0.065, height=0.35, segments=8,
                                     hex_color=JUMPSUIT))
    left_leg.name = "LeftLeg"
    left_leg.location = (-0.10, 0, 0.15)

    # Left boot
    left_boot = add(generate_box(w=0.12, d=0.16, h=0.08, hex_color=BOOTS))
    left_boot.name = "LeftBoot"
    left_boot.location = (-0.10, -0.02, 0.04)

    # ── RIGHT LEG ─────────────────────────────────────────────────────
    right_leg = add(generate_cylinder(radius=0.065, height=0.35, segments=8,
                                      hex_color=JUMPSUIT))
    right_leg.name = "RightLeg"
    right_leg.location = (0.10, 0, 0.15)

    # Right boot
    right_boot = add(generate_box(w=0.12, d=0.16, h=0.08, hex_color=BOOTS))
    right_boot.name = "RightBoot"
    right_boot.location = (0.10, -0.02, 0.04)

    # ── BACKPACK ──────────────────────────────────────────────────────
    backpack = add(generate_box(w=0.26, d=0.12, h=0.30, hex_color=BACKPACK))
    backpack.name = "Backpack"
    backpack.location = (0, 0.18, 0.65)

    # Backpack straps (thin boxes from top of backpack over shoulders)
    for side, sx in [("L", -0.08), ("R", 0.08)]:
        strap_obj = add(generate_box(w=0.03, d=0.30, h=0.03, hex_color=BELT_COL))
        strap_obj.name = f"BackpackStrap_{side}"
        strap_obj.location = (sx, 0.05, 0.90)

    # Backpack detail -- small bolt on center
    bp_bolt = add(generate_bolt(head_radius=0.025, head_height=0.015,
                                shaft_radius=0.012, shaft_length=0.005,
                                hex_color=BUCKLE))
    bp_bolt.name = "BackpackBolt"
    bp_bolt.location = (0, 0.25, 0.75)

    return {
        "root": root,
        "torso": torso,
        "head": head,
        "hardhat": hardhat,
        "brim": brim,
        "visor": visor,
        "left_arm": left_arm,
        "right_arm": right_arm,
        "left_glove": left_glove,
        "right_glove": right_glove,
        "left_leg": left_leg,
        "right_leg": right_leg,
        "left_boot": left_boot,
        "right_boot": right_boot,
        "backpack": backpack,
        "belt": belt,
    }


# ---------------------------------------------------------------------------
# Animations
# ---------------------------------------------------------------------------
def bake_animations(obj):
    """Bake 4 animation states: idle, walk, run, build."""
    torso = obj["torso"]
    head = obj["head"]
    hardhat = obj["hardhat"]
    brim = obj["brim"]
    visor = obj["visor"]
    left_arm = obj["left_arm"]
    right_arm = obj["right_arm"]
    left_glove = obj["left_glove"]
    right_glove = obj["right_glove"]
    left_leg = obj["left_leg"]
    right_leg = obj["right_leg"]
    left_boot = obj["left_boot"]
    right_boot = obj["right_boot"]
    backpack = obj["backpack"]
    belt = obj["belt"]

    # Base positions for animated parts
    torso_z = torso.location.z
    la_y = left_arm.location.y
    ra_y = right_arm.location.y
    la_z = left_arm.location.z
    ra_z = right_arm.location.z
    lg_y = left_glove.location.y
    rg_y = right_glove.location.y
    lg_z = left_glove.location.z
    rg_z = right_glove.location.z
    ll_y = left_leg.location.y
    rl_y = right_leg.location.y
    lb_y = left_boot.location.y
    rb_y = right_boot.location.y

    # ── IDLE (2s): Breathing, subtle sway ─────────────────────────────
    # Torso slight Z bob (breathing)
    animate_translation(torso, "idle", duration=2.0, axis='Z',
                        value_fn=lambda t: torso_z + 0.008 * math.sin(t * math.pi * 2))

    # Arms gentle sway (Y axis, very subtle)
    animate_translation(left_arm, "idle", duration=2.0, axis='Y',
                        value_fn=lambda t: la_y + 0.01 * math.sin(t * math.pi * 2))
    animate_translation(right_arm, "idle", duration=2.0, axis='Y',
                        value_fn=lambda t: ra_y - 0.01 * math.sin(t * math.pi * 2))
    # Gloves follow arms
    animate_translation(left_glove, "idle", duration=2.0, axis='Y',
                        value_fn=lambda t: lg_y + 0.01 * math.sin(t * math.pi * 2))
    animate_translation(right_glove, "idle", duration=2.0, axis='Y',
                        value_fn=lambda t: rg_y - 0.01 * math.sin(t * math.pi * 2))

    # Keep legs, boots, head, hat static during idle
    for part in [left_leg, right_leg, left_boot, right_boot,
                 head, hardhat, brim, visor, backpack, belt]:
        animate_static(part, "idle", duration=2.0)

    # ── WALK (1s): Leg + arm swing ────────────────────────────────────
    walk_leg_amp = 0.08    # forward/back leg swing
    walk_arm_amp = 0.06    # arm swing (opposite to legs)
    walk_bob = 0.015       # torso vertical bob

    # Torso bob (double frequency -- bob once per step)
    animate_translation(torso, "walk", duration=1.0, axis='Z',
                        value_fn=lambda t: torso_z + walk_bob * abs(math.sin(t * math.pi * 2)))

    # Left leg forward, right leg back (then swap)
    animate_translation(left_leg, "walk", duration=1.0, axis='Y',
                        value_fn=lambda t: ll_y + walk_leg_amp * math.sin(t * math.pi * 2))
    animate_translation(right_leg, "walk", duration=1.0, axis='Y',
                        value_fn=lambda t: rl_y - walk_leg_amp * math.sin(t * math.pi * 2))

    # Boots follow legs
    animate_translation(left_boot, "walk", duration=1.0, axis='Y',
                        value_fn=lambda t: lb_y + walk_leg_amp * math.sin(t * math.pi * 2))
    animate_translation(right_boot, "walk", duration=1.0, axis='Y',
                        value_fn=lambda t: rb_y - walk_leg_amp * math.sin(t * math.pi * 2))

    # Arms swing opposite to legs
    animate_translation(left_arm, "walk", duration=1.0, axis='Y',
                        value_fn=lambda t: la_y - walk_arm_amp * math.sin(t * math.pi * 2))
    animate_translation(right_arm, "walk", duration=1.0, axis='Y',
                        value_fn=lambda t: ra_y + walk_arm_amp * math.sin(t * math.pi * 2))
    animate_translation(left_glove, "walk", duration=1.0, axis='Y',
                        value_fn=lambda t: lg_y - walk_arm_amp * math.sin(t * math.pi * 2))
    animate_translation(right_glove, "walk", duration=1.0, axis='Y',
                        value_fn=lambda t: rg_y + walk_arm_amp * math.sin(t * math.pi * 2))

    # Static parts during walk
    for part in [head, hardhat, brim, visor, backpack, belt]:
        animate_static(part, "walk", duration=1.0)

    # ── RUN (0.5s): Faster, more exaggerated ──────────────────────────
    run_leg_amp = 0.12
    run_arm_amp = 0.10
    run_bob = 0.025

    animate_translation(torso, "run", duration=0.5, axis='Z',
                        value_fn=lambda t: torso_z + run_bob * abs(math.sin(t * math.pi * 2)))

    animate_translation(left_leg, "run", duration=0.5, axis='Y',
                        value_fn=lambda t: ll_y + run_leg_amp * math.sin(t * math.pi * 2))
    animate_translation(right_leg, "run", duration=0.5, axis='Y',
                        value_fn=lambda t: rl_y - run_leg_amp * math.sin(t * math.pi * 2))
    animate_translation(left_boot, "run", duration=0.5, axis='Y',
                        value_fn=lambda t: lb_y + run_leg_amp * math.sin(t * math.pi * 2))
    animate_translation(right_boot, "run", duration=0.5, axis='Y',
                        value_fn=lambda t: rb_y - run_leg_amp * math.sin(t * math.pi * 2))

    animate_translation(left_arm, "run", duration=0.5, axis='Y',
                        value_fn=lambda t: la_y - run_arm_amp * math.sin(t * math.pi * 2))
    animate_translation(right_arm, "run", duration=0.5, axis='Y',
                        value_fn=lambda t: ra_y + run_arm_amp * math.sin(t * math.pi * 2))
    animate_translation(left_glove, "run", duration=0.5, axis='Y',
                        value_fn=lambda t: lg_y - run_arm_amp * math.sin(t * math.pi * 2))
    animate_translation(right_glove, "run", duration=0.5, axis='Y',
                        value_fn=lambda t: rg_y + run_arm_amp * math.sin(t * math.pi * 2))

    # Slight forward lean during run (torso tilt)
    animate_rotation(torso, "run", duration=0.5, axis='X',
                     angle_fn=lambda t: math.radians(-5))

    for part in [head, hardhat, brim, visor, backpack, belt]:
        animate_static(part, "run", duration=0.5)

    # ── BUILD (1s): Right arm raises, places, returns ─────────────────
    # Torso stays mostly still with slight lean
    animate_static(torso, "build", duration=1.0)

    # Right arm raises up then comes back down
    # Phase: 0-0.4 raise, 0.4-0.6 hold, 0.6-1.0 lower
    def build_arm_z(t):
        raise_amount = 0.25
        if t < 0.4:
            # Ease-in raise
            p = t / 0.4
            return ra_z + raise_amount * (p * p)
        elif t < 0.6:
            return ra_z + raise_amount
        else:
            # Ease-out lower
            p = (t - 0.6) / 0.4
            return ra_z + raise_amount * (1 - p * p)

    animate_translation(right_arm, "build", duration=1.0, axis='Z',
                        value_fn=build_arm_z)

    # Right glove follows
    def build_glove_z(t):
        raise_amount = 0.25
        if t < 0.4:
            p = t / 0.4
            return rg_z + raise_amount * (p * p)
        elif t < 0.6:
            return rg_z + raise_amount
        else:
            p = (t - 0.6) / 0.4
            return rg_z + raise_amount * (1 - p * p)

    animate_translation(right_glove, "build", duration=1.0, axis='Z',
                        value_fn=build_glove_z)

    # Right arm also moves forward during build
    def build_arm_y(t):
        fwd = -0.08
        if t < 0.4:
            p = t / 0.4
            return ra_y + fwd * (p * p)
        elif t < 0.6:
            return ra_y + fwd
        else:
            p = (t - 0.6) / 0.4
            return ra_y + fwd * (1 - p * p)

    animate_translation(right_arm, "build", duration=1.0, axis='Y',
                        value_fn=build_arm_y)
    animate_translation(right_glove, "build", duration=1.0, axis='Y',
                        value_fn=lambda t: build_arm_y(t) - (ra_y - rg_y))

    # Left arm static during build
    animate_static(left_arm, "build", duration=1.0)
    animate_static(left_glove, "build", duration=1.0)

    # Legs, head, etc. static during build
    for part in [left_leg, right_leg, left_boot, right_boot,
                 head, hardhat, brim, visor, backpack, belt]:
        animate_static(part, "build", duration=1.0)


def main():
    output = parse_args()
    print(f"[player_model] Building player, exporting to {output}")

    objects = build_player()
    bake_animations(objects)

    # Export textured version (same as flat for this stylized character)
    export_glb(output)

    # Also export flat version (identical for this character)
    flat_output = output.replace(".glb", "_flat.glb")
    export_glb(flat_output)

    print(f"[player_model] Done: {output}")
    print(f"[player_model] Flat: {flat_output}")


if __name__ == "__main__":
    main()
