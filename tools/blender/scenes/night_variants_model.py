"""Export night-mode building variants as 3D models (.glb) for Godot import.

When night falls in Night Shift, factory buildings visually transform:
- Conveyor -> Wall (raised barriers, reinforcement plates, spikes)
- Smelter -> Turret (weapon barrel, targeting platform, ammo feed)
- Splitter -> Multi-Turret (3 barrels, targeting swivels, ammo distributor)
- Drill -> Cache (armor plating, retracted derrick, resource glow)

Each variant uses the same footprint as its day counterpart but adds combat
elements. Three animation states per variant:
  idle (2s)       — minimal movement, combat ready
  active (2s)     — full combat mode (tracking, pulsing, etc.)
  transition (1s) — transformation from day to night

Exports flat + textured versions of each.

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/night_variants_model.py
"""

import bpy
import bmesh
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
from prefabs_src.pipe import generate_pipe
from prefabs_src.bolt import generate_bolt
from prefabs_src.hemisphere import generate_hemisphere
from prefabs_src.wedge import generate_wedge
from prefabs_src.sphere import generate_sphere
from prefabs_src.piston import generate_piston
from anim_helpers import (
    animate_rotation, animate_translation, animate_shake, animate_static,
    animate_scale, FPS,
)


# ---------------------------------------------------------------------------
# Palettes
# ---------------------------------------------------------------------------
C = load_palette("buildings")

# Night-mode darker, more aggressive palette
NIGHT_STEEL    = "#3A3040"   # dark purple-gray
NIGHT_DARK     = "#2A2030"   # very dark
NIGHT_METAL    = "#4A4050"   # medium dark
NIGHT_BODY     = "#3D2E38"   # dark warm-purple body
NIGHT_BODY_LT  = "#4E3E48"   # lighter night body
NIGHT_ACCENT   = "#8B0000"   # dark red for weapon accents
NIGHT_GLOW     = "#CC4400"   # orange for fire glow / energy
NIGHT_SPIKE    = "#5A4858"   # spike color (dark purple-gray)

# Re-use some day palette colors for recognizability
STEEL      = "#7A8898"
STEEL_DK   = "#6A7888"
STEEL_LT   = "#96A4B4"
COPPER     = "#B87333"
COPPER_DK  = "#8B5A2B"
CABLE      = "#2A2A2A"
YELLOW     = "#C8A82A"
RED_WARN   = "#A03030"


# ---------------------------------------------------------------------------
# Export helpers
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


# ═══════════════════════════════════════════════════════════════════════════
# 1. CONVEYOR WALL
# ═══════════════════════════════════════════════════════════════════════════

def generate_roller(radius=0.06, length=1.0, segments=8, hex_color="#505256"):
    """Generate a cylinder lying along the X axis (from conveyor_model.py)."""
    bm = bmesh.new()
    half_l = length / 2
    left_verts = []
    right_verts = []
    for i in range(segments):
        angle = (i / segments) * 2 * math.pi
        y = radius * math.cos(angle)
        z = radius * math.sin(angle)
        left_verts.append(bm.verts.new((-half_l, y, z)))
        right_verts.append(bm.verts.new((half_l, y, z)))
    bm.verts.ensure_lookup_table()
    bm.faces.new(list(reversed(left_verts)))
    bm.faces.new(right_verts)
    for i in range(segments):
        j = (i + 1) % segments
        bm.faces.new([left_verts[i], left_verts[j],
                       right_verts[j], right_verts[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("Roller")
    bm.to_mesh(mesh)
    bm.free()
    mesh.validate()
    obj = bpy.data.objects.new("Roller", mesh)
    bpy.context.scene.collection.objects.link(obj)
    mat = create_flat_material("RollerMat", hex_color)
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def build_conveyor_wall():
    """Build the conveyor wall variant -- fortified defensive barrier."""
    clear_scene()

    root = bpy.data.objects.new("ConveyorWall", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.5
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # ── DIMENSIONS (same footprint as conveyor) ──────────────────────
    CELL = 2.0
    HALF = CELL / 2

    BASE_H     = 0.08
    WALL_H     = 0.60     # double the day wall height (~0.28 -> 0.60)
    WALL_THICK = 0.14     # thicker walls for fortification
    BELT_W     = CELL - WALL_THICK * 2
    HALF_BW    = BELT_W / 2

    # ── BASE PLATE (darker, heavier) ─────────────────────────────────
    base = add(generate_box(w=CELL, d=CELL, h=BASE_H, hex_color=NIGHT_BODY))
    base.name = "BasePlate"

    # ── SIDE WALLS (tall, fortified) ─────────────────────────────────
    wall_l = add(generate_box(w=WALL_THICK, d=CELL, h=WALL_H, hex_color=NIGHT_STEEL))
    wall_l.name = "WallLeft"
    wall_l.location = (-(HALF - WALL_THICK / 2), 0, BASE_H)

    wall_r = add(generate_box(w=WALL_THICK, d=CELL, h=WALL_H, hex_color=NIGHT_STEEL))
    wall_r.name = "WallRight"
    wall_r.location = ((HALF - WALL_THICK / 2), 0, BASE_H)

    # ── WALL CAPS (reinforced top rails) ─────────────────────────────
    CAP_H = 0.05
    cap_l = add(generate_box(w=WALL_THICK + 0.06, d=CELL, h=CAP_H, hex_color=NIGHT_METAL))
    cap_l.name = "WallCapLeft"
    cap_l.location = (-(HALF - WALL_THICK / 2), 0, BASE_H + WALL_H)

    cap_r = add(generate_box(w=WALL_THICK + 0.06, d=CELL, h=CAP_H, hex_color=NIGHT_METAL))
    cap_r.name = "WallCapRight"
    cap_r.location = ((HALF - WALL_THICK / 2), 0, BASE_H + WALL_H)

    # ── REINFORCEMENT PLATES (armor on walls) ────────────────────────
    PLATE_H = 0.28
    PLATE_W = 0.06
    plate_positions_y = [-0.55, 0.0, 0.55]
    for side in [-1, 1]:
        wall_x = side * (HALF - WALL_THICK / 2)
        plate_x = wall_x + side * (WALL_THICK / 2 + PLATE_W / 2)
        for pi, py in enumerate(plate_positions_y):
            plate = add(generate_box(w=PLATE_W, d=0.5, h=PLATE_H, hex_color=NIGHT_METAL))
            plate.name = f"ArmorPlate_{side}_{pi}"
            plate.location = (plate_x, py, BASE_H + WALL_H * 0.3)

    # ── SPIKES along top edge ────────────────────────────────────────
    SPIKE_H = 0.15
    SPIKE_R = 0.04
    spike_y_positions = [-0.8, -0.4, 0.0, 0.4, 0.8]
    for side in [-1, 1]:
        wall_x = side * (HALF - WALL_THICK / 2)
        for sy in spike_y_positions:
            spike = add(generate_cone(radius_bottom=SPIKE_R, radius_top=0,
                                       height=SPIKE_H, segments=6,
                                       hex_color=NIGHT_SPIKE))
            spike.name = f"Spike_{side}_{sy:.1f}"
            spike.location = (wall_x, sy, BASE_H + WALL_H + CAP_H)

    # ── CROSS BEAMS (reinforcement across corridor) ──────────────────
    for cy in [-0.65, 0.0, 0.65]:
        cross = add(generate_box(w=BELT_W * 0.9, d=0.06, h=0.05,
                                 hex_color=NIGHT_DARK))
        cross.name = f"CrossBeam_{cy:.1f}"
        cross.location = (0, cy, BASE_H + WALL_H * 0.85)

    # ── BELT SURFACE (deactivated, darker) ───────────────────────────
    belt = add(generate_box(w=BELT_W, d=CELL, h=0.03, hex_color=NIGHT_DARK))
    belt.name = "BeltSurface"
    belt.location = (0, 0, BASE_H + 0.10)

    # ── ROLLERS (frozen/stopped) ─────────────────────────────────────
    ROLLER_R = 0.05
    ROLLER_LEN = BELT_W - 0.10
    ROLLER_SPACING = 0.40
    NUM_ROLLERS = int(CELL / ROLLER_SPACING)
    rollers = []
    for i in range(NUM_ROLLERS):
        y_pos = -HALF + ROLLER_SPACING * (i + 0.5)
        roller = add(generate_roller(radius=ROLLER_R, length=ROLLER_LEN,
                                     segments=8, hex_color=NIGHT_METAL))
        roller.name = f"Roller_{i}"
        roller.location = (0, y_pos, BASE_H + ROLLER_R)
        rollers.append(roller)

    # ── VERTICAL REINFORCEMENT RIBS (outer walls) ────────────────────
    RIB_W = 0.02
    RIB_D = 0.03
    rib_y_positions = [-0.7, -0.25, 0.25, 0.7]
    for side in [-1, 1]:
        wall_x = side * (HALF - WALL_THICK / 2)
        rib_x = wall_x + side * (WALL_THICK / 2 + RIB_D / 2)
        for ry in rib_y_positions:
            rib = add(generate_box(w=RIB_D, d=RIB_W, h=WALL_H * 0.9,
                                   hex_color=NIGHT_BODY_LT))
            rib.name = f"Rib_{side}_{ry:.1f}"
            rib.location = (rib_x, ry, BASE_H + WALL_H * 0.05)

    # ── BOLTS (heavier, more numerous) ───────────────────────────────
    bolt_positions = [
        # Wall cap bolts
        (-(HALF - WALL_THICK / 2), -0.70, BASE_H + WALL_H + CAP_H),
        (-(HALF - WALL_THICK / 2),  0.00, BASE_H + WALL_H + CAP_H),
        (-(HALF - WALL_THICK / 2),  0.70, BASE_H + WALL_H + CAP_H),
        ( (HALF - WALL_THICK / 2), -0.70, BASE_H + WALL_H + CAP_H),
        ( (HALF - WALL_THICK / 2),  0.00, BASE_H + WALL_H + CAP_H),
        ( (HALF - WALL_THICK / 2),  0.70, BASE_H + WALL_H + CAP_H),
        # Wall mid bolts
        (-(HALF + 0.01), -0.45, BASE_H + WALL_H * 0.4),
        (-(HALF + 0.01),  0.45, BASE_H + WALL_H * 0.4),
        ( (HALF + 0.01), -0.45, BASE_H + WALL_H * 0.4),
        ( (HALF + 0.01),  0.45, BASE_H + WALL_H * 0.4),
        # Lower bolts
        (-(HALF + 0.01), -0.45, BASE_H + WALL_H * 0.15),
        (-(HALF + 0.01),  0.45, BASE_H + WALL_H * 0.15),
        ( (HALF + 0.01), -0.45, BASE_H + WALL_H * 0.15),
        ( (HALF + 0.01),  0.45, BASE_H + WALL_H * 0.15),
    ]
    for bi, (bx, by, bz) in enumerate(bolt_positions):
        b = add(generate_bolt(head_radius=0.03, head_height=0.018,
                              hex_color=C["rivet"]))
        b.name = f"Bolt_{bi}"
        b.location = (bx, by, bz)

    # ── HAZARD STRIPE (dark red warning) ─────────────────────────────
    stripe = add(generate_box(w=CELL + 0.01, d=CELL + 0.01, h=0.012,
                              hex_color=NIGHT_ACCENT))
    stripe.name = "HazardStripe"
    stripe.location = (0, 0, BASE_H * 0.5)

    return {
        "root": root,
        "wall_l": wall_l,
        "wall_r": wall_r,
        "cap_l": cap_l,
        "cap_r": cap_r,
        "base": base,
        "belt": belt,
        "rollers": rollers,
    }


def bake_conveyor_wall_animations(objects):
    """Bake animations for the conveyor wall variant."""
    wall_l = objects["wall_l"]
    wall_r = objects["wall_r"]
    base = objects["base"]
    belt = objects["belt"]
    rollers = objects["rollers"]

    # ── idle (2s): static, barely perceptible vibration ──────────────
    animate_shake(wall_l, "idle", duration=2.0, amplitude=0.003, frequency=2)
    animate_shake(wall_r, "idle", duration=2.0, amplitude=0.003, frequency=2)
    animate_static(base, "idle", duration=2.0)
    animate_static(belt, "idle", duration=2.0)
    for roller in rollers:
        animate_static(roller, "idle", duration=2.0)

    # ── active (2s): walls pulse outward slightly (threatening) ──────
    animate_shake(wall_l, "active", duration=2.0, amplitude=0.008, frequency=4)
    animate_shake(wall_r, "active", duration=2.0, amplitude=0.008, frequency=4)
    animate_shake(base, "active", duration=2.0, amplitude=0.004, frequency=6)
    animate_static(belt, "active", duration=2.0)
    for roller in rollers:
        animate_static(roller, "active", duration=2.0)

    # ── transition (1s): walls rise and slam into position ───────────
    # Walls expand outward slightly during transformation
    wall_l_x = wall_l.location.x
    wall_r_x = wall_r.location.x
    animate_translation(wall_l, "transition", duration=1.0, axis='X',
                        value_fn=lambda t: wall_l_x + 0.02 * math.sin(t * math.pi))
    animate_translation(wall_r, "transition", duration=1.0, axis='X',
                        value_fn=lambda t: wall_r_x - 0.02 * math.sin(t * math.pi))
    animate_shake(base, "transition", duration=1.0, amplitude=0.015, frequency=12, decay=0.5)
    animate_static(belt, "transition", duration=1.0)
    for roller in rollers:
        animate_static(roller, "transition", duration=1.0)


def apply_conveyor_wall_textures(objects):
    """Apply PBR textures to conveyor wall."""
    root = objects["root"]
    for obj in root.children:
        if not obj.type == 'MESH':
            continue
        name = obj.name
        if "Wall" in name and "Cap" not in name:
            apply_texture(obj, "metal_plate", resolution="1k")
        elif "Cap" in name:
            apply_texture(obj, "metal_plate", resolution="1k")
        elif "BasePlate" in name:
            apply_texture(obj, "metal_plate_02", resolution="1k")
        elif "ArmorPlate" in name:
            apply_texture(obj, "metal_plate", resolution="1k")
        elif "CrossBeam" in name:
            apply_texture(obj, "rusty_metal_02", resolution="1k")
        elif "Rib" in name:
            apply_texture(obj, "rusty_metal_02", resolution="1k")


# ═══════════════════════════════════════════════════════════════════════════
# 2. SMELTER TURRET
# ═══════════════════════════════════════════════════════════════════════════

def build_smelter_turret():
    """Build the smelter turret variant -- weapon barrel from crucible."""
    clear_scene()

    root = bpy.data.objects.new("SmelterTurret", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.5
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # ── BASE PLATFORM (same as smelter) ──────────────────────────────
    base = add(generate_box(w=2.6, d=2.6, h=0.12, hex_color=NIGHT_STEEL))
    base.name = "BasePlatform"

    # Corner feet
    for i, (fx, fy) in enumerate([(-1.1, -1.1), (1.1, -1.1),
                                   (1.1, 1.1), (-1.1, 1.1)]):
        foot = add(generate_cylinder(radius=0.14, height=0.06, segments=8,
                                     hex_color=NIGHT_DARK))
        foot.name = f"Foot_{i}"
        foot.location = (fx, fy, -0.06)

    # ── MAIN HOUSING (darker version of smelter body) ────────────────
    body = add(generate_box(w=2.2, d=2.2, h=0.8, hex_color=NIGHT_BODY, seam_count=2))
    body.name = "Body"
    body.location = (0, 0, 0.12)

    # Reinforcement bands
    band_lo = add(generate_box(w=2.3, d=2.3, h=0.1, hex_color=NIGHT_STEEL))
    band_lo.name = "BandLo"
    band_lo.location = (0, 0, 0.18)

    band_hi = add(generate_box(w=2.3, d=2.3, h=0.1, hex_color=NIGHT_STEEL))
    band_hi.name = "BandHi"
    band_hi.location = (0, 0, 0.75)

    # Dark red hazard stripe (combat warning)
    hazard = add(generate_box(w=2.25, d=2.25, h=0.04, hex_color=NIGHT_ACCENT))
    hazard.name = "HazardStripe"
    hazard.location = (0, 0, 0.15)

    # ── FIRING CHAMBER (repurposed crucible) ─────────────────────────
    # The crucible is now a sealed firing chamber
    chamber = add(generate_cone(radius_bottom=0.7, radius_top=0.75,
                                 height=0.4, segments=12,
                                 hex_color=NIGHT_BODY_LT))
    chamber.name = "FiringChamber"
    chamber.location = (0, 0, 0.92)

    # Chamber lid (sealed, no longer open-top)
    chamber_lid = add(generate_cylinder(radius=0.78, height=0.08, segments=12,
                                         hex_color=NIGHT_STEEL))
    chamber_lid.name = "ChamberLid"
    chamber_lid.location = (0, 0, 1.32)

    # Fire glow visible through seams (energy buildup)
    fire_glow = add(generate_cylinder(radius=0.72, height=0.03, segments=12,
                                       hex_color=NIGHT_GLOW))
    fire_glow.name = "FireGlow"
    fire_glow.location = (0, 0, 1.30)

    # ── TARGETING PLATFORM (rotating base under barrel) ──────────────
    turret_base = add(generate_cylinder(radius=0.50, height=0.15, segments=12,
                                         hex_color=NIGHT_METAL))
    turret_base.name = "TurretBase"
    turret_base.location = (0, 0, 1.40)

    turret_ring = add(generate_cylinder(radius=0.55, height=0.04, segments=12,
                                         hex_color=NIGHT_STEEL))
    turret_ring.name = "TurretRing"
    turret_ring.location = (0, 0, 1.42)

    # ── WEAPON BARREL (main cannon) ──────────────────────────────────
    # A pipe extending upward at an angle from the turret platform
    barrel = add(generate_pipe(length=1.2, radius=0.18, wall_thickness=0.05,
                               hex_color=NIGHT_METAL))
    barrel.name = "WeaponBarrel"
    barrel.location = (0, 0, 1.55)
    # Tilted slightly (not straight up -- angled for targeting)
    barrel.rotation_euler = (math.radians(25), 0, 0)

    # Barrel tip -- muzzle flare ring
    muzzle = add(generate_cylinder(radius=0.22, height=0.06, segments=10,
                                    hex_color=NIGHT_ACCENT))
    muzzle.name = "Muzzle"
    muzzle.location = (0, -0.50, 2.60)

    # Muzzle inner glow
    muzzle_glow = add(generate_cylinder(radius=0.14, height=0.03, segments=10,
                                         hex_color=NIGHT_GLOW))
    muzzle_glow.name = "MuzzleGlow"
    muzzle_glow.location = (0, -0.50, 2.62)

    # Barrel reinforcement rings
    for ri, rz_off in enumerate([0.3, 0.7]):
        ring = add(generate_cylinder(radius=0.21, height=0.04, segments=10,
                                      hex_color=NIGHT_STEEL))
        ring.name = f"BarrelRing_{ri}"
        # Approximate position along tilted barrel
        ring.location = (0, -rz_off * 0.42, 1.55 + rz_off * 0.9)
        ring.rotation_euler = (math.radians(25), 0, 0)

    # ── AMMO FEED PIPE (from body to firing chamber) ─────────────────
    # Visible pipe connecting the furnace internals to the barrel
    ammo_pipe = add(generate_pipe(length=0.5, radius=0.08, wall_thickness=0.02,
                                   hex_color=COPPER_DK))
    ammo_pipe.name = "AmmoFeed"
    ammo_pipe.location = (0.6, 0, 0.80)

    # Horizontal ammo pipe connecting hopper to chamber
    ammo_h_pipe = add(generate_pipe(length=0.4, radius=0.07, wall_thickness=0.018,
                                     hex_color=COPPER_DK))
    ammo_h_pipe.name = "AmmoHPipe"
    ammo_h_pipe.rotation_euler = (0, math.radians(90), 0)
    ammo_h_pipe.location = (0.45, 0, 1.0)

    # ── INPUT HOPPERS (retained from smelter -- ammo input) ──────────
    # Left hopper (now ammo feeder)
    hopper_l = add(generate_cone(radius_bottom=0.18, radius_top=0.30,
                                  height=0.45, segments=8,
                                  hex_color=NIGHT_METAL))
    hopper_l.name = "HopperLeft"
    hopper_l.location = (-1.15, 0, 0.52)

    hopper_l_rim = add(generate_cylinder(radius=0.33, height=0.04, segments=8,
                                          hex_color=NIGHT_STEEL))
    hopper_l_rim.name = "HopperLeftRim"
    hopper_l_rim.location = (-1.15, 0, 0.97)

    # Right hopper
    hopper_r = add(generate_cone(radius_bottom=0.18, radius_top=0.30,
                                  height=0.45, segments=8,
                                  hex_color=NIGHT_METAL))
    hopper_r.name = "HopperRight"
    hopper_r.location = (1.15, 0, 0.52)

    hopper_r_rim = add(generate_cylinder(radius=0.33, height=0.04, segments=8,
                                          hex_color=NIGHT_STEEL))
    hopper_r_rim.name = "HopperRightRim"
    hopper_r_rim.location = (1.15, 0, 0.97)

    # ── GEARS (same position as smelter, darker) ─────────────────────
    main_gear = add(generate_cog(outer_radius=0.7, inner_radius=0.45,
                                 teeth=10, thickness=0.25, hex_color=NIGHT_METAL))
    main_gear.name = "MainGear"
    main_gear.location = (0.4, 1.15, 0.55)

    small_gear = add(generate_cog(outer_radius=0.4, inner_radius=0.28,
                                  teeth=6, thickness=0.25, hex_color=NIGHT_STEEL))
    small_gear.name = "SmallGear"
    small_gear.location = (-0.35, 1.15, 0.55)

    # ── CHIMNEY (retained, with soot) ────────────────────────────────
    chimney = add(generate_cylinder(radius=0.22, height=0.7, segments=10,
                                    hex_color=NIGHT_BODY))
    chimney.name = "Chimney"
    chimney.location = (-0.55, 0.65, 0.92)

    chimney_cap = add(generate_cylinder(radius=0.28, height=0.06, segments=10,
                                         hex_color=NIGHT_STEEL))
    chimney_cap.name = "ChimneyCap"
    chimney_cap.location = (-0.55, 0.65, 1.62)

    # ── BOLTS ────────────────────────────────────────────────────────
    bolt_positions = [
        (0.85, 0.85, 0.93), (-0.85, 0.85, 0.93),
        (0.85, -0.85, 0.93), (-0.85, -0.85, 0.93),
        (1.15, 0.7, 0.22), (1.15, -0.7, 0.22),
        (-1.15, 0.7, 0.22), (-1.15, -0.7, 0.22),
        (1.15, 0.7, 0.78), (1.15, -0.7, 0.78),
        (-1.15, 0.7, 0.78), (-1.15, -0.7, 0.78),
    ]
    for i, (bx, by, bz) in enumerate(bolt_positions):
        b = add(generate_bolt(head_radius=0.05, head_height=0.03,
                              hex_color=C["rivet"]))
        b.name = f"Bolt_{i}"
        b.location = (bx, by, bz)

    # Turret bolts (around turret base)
    for i in range(6):
        angle = (i / 6) * 2 * math.pi
        bx = 0.48 * math.cos(angle)
        by = 0.48 * math.sin(angle)
        b = add(generate_bolt(head_radius=0.04, head_height=0.025,
                              hex_color=C["rivet"]))
        b.name = f"TurretBolt_{i}"
        b.location = (bx, by, 1.56)

    return {
        "root": root,
        "body": body,
        "band_lo": band_lo,
        "band_hi": band_hi,
        "barrel": barrel,
        "turret_base": turret_base,
        "turret_ring": turret_ring,
        "muzzle": muzzle,
        "muzzle_glow": muzzle_glow,
        "fire_glow": fire_glow,
        "main_gear": main_gear,
        "small_gear": small_gear,
        "chamber": chamber,
    }


def bake_smelter_turret_animations(objects):
    """Bake animations for the smelter turret variant."""
    body = objects["body"]
    barrel = objects["barrel"]
    turret_base = objects["turret_base"]
    turret_ring = objects["turret_ring"]
    muzzle = objects["muzzle"]
    muzzle_glow = objects["muzzle_glow"]
    fire_glow = objects["fire_glow"]
    mg = objects["main_gear"]
    sg = objects["small_gear"]
    chamber = objects["chamber"]

    GEAR_RATIO = 10 / 6

    # ── idle (2s): subtle turret scan, minimal gear movement ─────────
    animate_rotation(turret_base, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.15 * math.sin(t * math.pi * 2))
    animate_rotation(turret_ring, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.15 * math.sin(t * math.pi * 2))
    # Barrel tracks with turret
    animate_rotation(barrel, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.15 * math.sin(t * math.pi * 2))
    animate_static(body, "idle", duration=2.0)
    animate_rotation(mg, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.03 * math.sin(t * math.pi * 2))
    animate_rotation(sg, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: -0.03 * GEAR_RATIO * math.sin(t * math.pi * 2))
    animate_static(fire_glow, "idle", duration=2.0)
    animate_static(muzzle, "idle", duration=2.0)
    animate_static(muzzle_glow, "idle", duration=2.0)
    animate_static(chamber, "idle", duration=2.0)

    # ── active (2s): turret tracking, barrel recoil, glow pulsing ────
    # Turret sweeps back and forth (targeting)
    animate_rotation(turret_base, "active", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.5 * math.sin(t * math.pi * 4))
    animate_rotation(turret_ring, "active", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.5 * math.sin(t * math.pi * 4))
    animate_rotation(barrel, "active", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.5 * math.sin(t * math.pi * 4))
    # Body shakes from recoil
    animate_shake(body, "active", duration=2.0, amplitude=0.015, frequency=10)
    # Gears spin for ammo feed
    animate_rotation(mg, "active", duration=2.0, axis='Z',
                     total_angle=math.pi * 4)
    animate_rotation(sg, "active", duration=2.0, axis='Z',
                     total_angle=-math.pi * 4 * GEAR_RATIO)
    # Fire glow pulses (energy buildup / release)
    fire_z = fire_glow.location.z
    animate_translation(fire_glow, "active", duration=2.0, axis='Z',
                        value_fn=lambda t: fire_z + 0.03 * math.sin(t * math.pi * 8))
    # Muzzle flash pulse
    animate_shake(muzzle, "active", duration=2.0, amplitude=0.006, frequency=12)
    animate_shake(muzzle_glow, "active", duration=2.0, amplitude=0.006, frequency=12)
    animate_shake(chamber, "active", duration=2.0, amplitude=0.008, frequency=10)

    # ── transition (1s): barrel rises into position ──────────────────
    animate_shake(body, "transition", duration=1.0, amplitude=0.02, frequency=15, decay=0.5)
    # Turret spins once during transformation
    animate_rotation(turret_base, "transition", duration=1.0, axis='Z',
                     total_angle=math.pi * 2)
    animate_rotation(turret_ring, "transition", duration=1.0, axis='Z',
                     total_angle=math.pi * 2)
    animate_rotation(barrel, "transition", duration=1.0, axis='Z',
                     total_angle=math.pi * 2)
    animate_rotation(mg, "transition", duration=1.0, axis='Z',
                     total_angle=math.pi * 2)
    animate_rotation(sg, "transition", duration=1.0, axis='Z',
                     total_angle=-math.pi * 2 * GEAR_RATIO)
    animate_static(fire_glow, "transition", duration=1.0)
    animate_static(muzzle, "transition", duration=1.0)
    animate_static(muzzle_glow, "transition", duration=1.0)
    animate_static(chamber, "transition", duration=1.0)


def apply_smelter_turret_textures(objects):
    """Apply PBR textures to smelter turret."""
    texture_map = {
        "BasePlatform": "metal_plate_02",
        "Body": "painted_metal_shutter",
        "BandLo": "metal_plate",
        "BandHi": "metal_plate",
        "FiringChamber": "rusty_metal_02",
        "ChamberLid": "metal_plate",
        "TurretBase": "metal_plate",
        "TurretRing": "metal_plate",
        "WeaponBarrel": "metal_plate",
        "Chimney": "corrugated_iron",
        "ChimneyCap": "rusty_metal_02",
        "HopperLeft": "metal_plate",
        "HopperRight": "metal_plate",
        "MainGear": "metal_plate",
        "SmallGear": "metal_plate",
        "AmmoFeed": "rusty_metal_02",
        "AmmoHPipe": "rusty_metal_02",
    }
    for i in range(4):
        texture_map[f"Foot_{i}"] = "metal_plate"

    for obj_name, tex_id in texture_map.items():
        obj = bpy.data.objects.get(obj_name)
        if obj and obj.type == 'MESH':
            try:
                apply_texture(obj, tex_id, resolution="1k")
            except Exception as e:
                print(f"[night_variants] Warning: texture '{tex_id}' failed for {obj_name}: {e}")


# ═══════════════════════════════════════════════════════════════════════════
# 3. SPLITTER MULTI-TURRET
# ═══════════════════════════════════════════════════════════════════════════

def build_splitter_turret():
    """Build the splitter multi-turret variant -- 3 barrels from hub."""
    clear_scene()

    root = bpy.data.objects.new("SplitterTurret", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.5
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # ── BASE PLATFORM (round, same as splitter) ──────────────────────
    base = add(generate_cylinder(radius=1.3, height=0.10, segments=16,
                                  hex_color=NIGHT_STEEL))
    base.name = "BasePlatform"

    # Hex feet
    for i in range(6):
        angle = (i / 6) * 2 * math.pi
        fx = 1.1 * math.cos(angle)
        fy = 1.1 * math.sin(angle)
        foot = add(generate_cylinder(radius=0.10, height=0.06, segments=8,
                                     hex_color=NIGHT_DARK))
        foot.name = f"Foot_{i}"
        foot.location = (fx, fy, -0.06)

    # ── MAIN HOUSING (dark cylindrical body) ─────────────────────────
    body = add(generate_cylinder(radius=1.1, height=0.55, segments=16,
                                  hex_color=NIGHT_BODY))
    body.name = "Body"
    body.location = (0, 0, 0.10)

    # Reinforcement rings
    ring_lo = add(generate_cylinder(radius=1.15, height=0.08, segments=16,
                                     hex_color=NIGHT_STEEL))
    ring_lo.name = "RingLo"
    ring_lo.location = (0, 0, 0.14)

    ring_hi = add(generate_cylinder(radius=1.15, height=0.08, segments=16,
                                     hex_color=NIGHT_STEEL))
    ring_hi.name = "RingHi"
    ring_hi.location = (0, 0, 0.52)

    # Roof plate
    roof = add(generate_cylinder(radius=1.18, height=0.08, segments=16,
                                  hex_color=NIGHT_BODY_LT))
    roof.name = "Roof"
    roof.location = (0, 0, 0.65)

    # Combat hazard stripe (red)
    hazard = add(generate_cylinder(radius=1.12, height=0.03, segments=16,
                                    hex_color=NIGHT_ACCENT))
    hazard.name = "HazardStripe"
    hazard.location = (0, 0, 0.13)

    # ── CENTRAL AMMO DISTRIBUTOR (replaces spinning hub) ─────────────
    # The hub is now an ammo distribution node
    hub_pedestal = add(generate_cylinder(radius=0.45, height=0.15, segments=12,
                                          hex_color=NIGHT_STEEL))
    hub_pedestal.name = "HubPedestal"
    hub_pedestal.location = (0, 0, 0.73)

    hub = add(generate_cylinder(radius=0.55, height=0.20, segments=12,
                                 hex_color=NIGHT_METAL))
    hub.name = "Hub"
    hub.location = (0, 0, 0.88)

    # Ammo core glow (visible energy in the hub)
    hub_glow = add(generate_cylinder(radius=0.30, height=0.10, segments=10,
                                      hex_color=NIGHT_GLOW))
    hub_glow.name = "HubGlow"
    hub_glow.location = (0, 0, 1.08)

    # Hub gear ring (ammo feed mechanism)
    hub_gear = add(generate_cog(outer_radius=0.50, inner_radius=0.38,
                                teeth=12, thickness=0.08, hex_color=NIGHT_STEEL))
    hub_gear.name = "HubGear"
    hub_gear.location = (0, 0, 0.80)

    # Hub rim
    hub_rim = add(generate_cylinder(radius=0.58, height=0.04, segments=12,
                                     hex_color=NIGHT_METAL))
    hub_rim.name = "HubRim"
    hub_rim.location = (0, 0, 0.92)

    # ── THREE BARREL ASSEMBLIES (at 120-degree intervals) ────────────
    barrel_angles = [0, 2 * math.pi / 3, 4 * math.pi / 3]
    barrels = []
    barrel_mounts = []

    for bi, angle in enumerate(barrel_angles):
        cos_a = math.cos(angle)
        sin_a = math.sin(angle)

        # Targeting swivel mount (small rotating platform)
        mount = add(generate_cylinder(radius=0.22, height=0.12, segments=10,
                                       hex_color=NIGHT_STEEL))
        mount.name = f"BarrelMount_{bi}"
        mount.location = (cos_a * 0.78, sin_a * 0.78, 0.68)
        barrel_mounts.append(mount)

        # Barrel pipe -- extending outward and slightly upward
        barrel_pipe = add(generate_pipe(length=0.7, radius=0.10, wall_thickness=0.025,
                                         hex_color=NIGHT_METAL))
        barrel_pipe.name = f"Barrel_{bi}"
        barrel_pipe.location = (cos_a * 0.95, sin_a * 0.95, 0.75)
        # Tilt outward and slightly up
        barrel_pipe.rotation_euler = (
            math.radians(40) * sin_a,
            -math.radians(40) * cos_a,
            angle
        )
        barrels.append(barrel_pipe)

        # Barrel muzzle ring
        muzzle_ring = add(generate_cylinder(radius=0.13, height=0.04, segments=8,
                                             hex_color=NIGHT_ACCENT))
        muzzle_ring.name = f"Muzzle_{bi}"
        muzzle_ring.location = (cos_a * 1.40, sin_a * 1.40, 0.52)

        # Muzzle glow
        muzzle_glow = add(generate_cylinder(radius=0.08, height=0.02, segments=8,
                                             hex_color=NIGHT_GLOW))
        muzzle_glow.name = f"MuzzleGlow_{bi}"
        muzzle_glow.location = (cos_a * 1.42, sin_a * 1.42, 0.53)

        # Ammo feed arm from hub to barrel mount
        arm = add(generate_box(w=0.08, d=0.50, h=0.10, hex_color=NIGHT_BODY_LT))
        arm.name = f"AmmoArm_{bi}"
        arm.location = (cos_a * 0.42, sin_a * 0.42, 0.92)
        arm.rotation_euler = (0, 0, angle)

        # Barrel reinforcement collar
        collar = add(generate_cylinder(radius=0.12, height=0.03, segments=8,
                                        hex_color=NIGHT_STEEL))
        collar.name = f"BarrelCollar_{bi}"
        collar.location = (cos_a * 1.10, sin_a * 1.10, 0.65)

    # ── DRIVE GEARS ──────────────────────────────────────────────────
    main_gear = add(generate_cog(outer_radius=0.50, inner_radius=0.35,
                                 teeth=10, thickness=0.20, hex_color=NIGHT_METAL))
    main_gear.name = "MainGear"
    main_gear.location = (0.90, 0.80, 0.52)

    small_gear = add(generate_cog(outer_radius=0.30, inner_radius=0.22,
                                  teeth=6, thickness=0.20, hex_color=NIGHT_STEEL))
    small_gear.name = "SmallGear"
    small_gear.location = (0.45, 1.15, 0.52)

    # ── INPUT HOPPER (ammo intake) ───────────────────────────────────
    hx = math.cos(math.pi) * 0.85
    hy = math.sin(math.pi) * 0.85
    hopper = add(generate_cone(radius_bottom=0.18, radius_top=0.35,
                                height=0.55, segments=8, hex_color=NIGHT_METAL))
    hopper.name = "InputHopper"
    hopper.location = (hx, hy, 0.52)

    hopper_rim = add(generate_cylinder(radius=0.38, height=0.05, segments=8,
                                        hex_color=NIGHT_STEEL))
    hopper_rim.name = "HopperRim"
    hopper_rim.location = (hx, hy, 1.07)

    # ── BOLTS ────────────────────────────────────────────────────────
    for i in range(8):
        angle = (i / 8) * 2 * math.pi
        bx = 1.05 * math.cos(angle)
        by = 1.05 * math.sin(angle)
        b = add(generate_bolt(head_radius=0.04, head_height=0.025,
                              hex_color=C["rivet"]))
        b.name = f"RoofBolt_{i}"
        b.location = (bx, by, 0.74)

    for ri, rz in enumerate([0.18, 0.56]):
        for i in range(6):
            angle = (i / 6) * 2 * math.pi + (ri * math.pi / 6)
            bx = 1.14 * math.cos(angle)
            by = 1.14 * math.sin(angle)
            b = add(generate_bolt(head_radius=0.035, head_height=0.02,
                                  hex_color=C["rivet"]))
            b.name = f"RingBolt_{ri}_{i}"
            b.location = (bx, by, rz)

    return {
        "root": root,
        "hub": hub,
        "hub_glow": hub_glow,
        "hub_gear": hub_gear,
        "hub_rim": hub_rim,
        "barrels": barrels,
        "barrel_mounts": barrel_mounts,
        "main_gear": main_gear,
        "small_gear": small_gear,
        "body": body,
        "ring_lo": ring_lo,
        "ring_hi": ring_hi,
        "roof": roof,
        "base": base,
    }


def bake_splitter_turret_animations(objects):
    """Bake animations for the splitter multi-turret."""
    hub = objects["hub"]
    hub_glow = objects["hub_glow"]
    hub_gear = objects["hub_gear"]
    hub_rim = objects["hub_rim"]
    barrels = objects["barrels"]
    barrel_mounts = objects["barrel_mounts"]
    mg = objects["main_gear"]
    sg = objects["small_gear"]
    body = objects["body"]
    ring_lo = objects["ring_lo"]
    ring_hi = objects["ring_hi"]
    roof = objects["roof"]

    GEAR_RATIO = 10 / 6
    hub_parts = [hub, hub_glow, hub_rim]

    # ── idle (2s): hub slowly rotates, barrels at rest ───────────────
    for part in hub_parts:
        animate_rotation(part, "idle", duration=2.0, axis='Z',
                         angle_fn=lambda t: 0.08 * math.sin(t * math.pi * 2))
    animate_rotation(hub_gear, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: -0.08 * math.sin(t * math.pi * 2))
    animate_rotation(mg, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.03 * math.sin(t * math.pi * 2))
    animate_rotation(sg, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: -0.03 * GEAR_RATIO * math.sin(t * math.pi * 2))
    animate_static(body, "idle", duration=2.0)
    for barrel in barrels:
        animate_static(barrel, "idle", duration=2.0)
    for mount in barrel_mounts:
        animate_static(mount, "idle", duration=2.0)

    # ── active (2s): hub spins fast distributing ammo, barrels recoil ─
    total_hub_angle = math.pi * 2 * 3
    for part in hub_parts:
        animate_rotation(part, "active", duration=2.0, axis='Z',
                         total_angle=total_hub_angle)
    animate_rotation(hub_gear, "active", duration=2.0, axis='Z',
                     total_angle=-total_hub_angle)
    animate_rotation(mg, "active", duration=2.0, axis='Z',
                     total_angle=math.pi * 4)
    animate_rotation(sg, "active", duration=2.0, axis='Z',
                     total_angle=-math.pi * 4 * GEAR_RATIO)
    animate_shake(body, "active", duration=2.0, amplitude=0.010, frequency=10)
    animate_shake(ring_lo, "active", duration=2.0, amplitude=0.010, frequency=10)
    animate_shake(ring_hi, "active", duration=2.0, amplitude=0.010, frequency=10)
    animate_shake(roof, "active", duration=2.0, amplitude=0.006, frequency=10)
    # Barrels shake from firing recoil
    for ci, barrel in enumerate(barrels):
        phase_offset = ci * 2 * math.pi / 3
        base_z = barrel.location.z
        animate_translation(barrel, "active", duration=2.0, axis='Z',
                            value_fn=lambda t, bz=base_z, po=phase_offset:
                                bz + 0.02 * math.sin(t * math.pi * 12 + po))
    for ci, mount in enumerate(barrel_mounts):
        phase_offset = ci * 2 * math.pi / 3
        animate_shake(mount, "active", duration=2.0, amplitude=0.005, frequency=12)

    # ── transition (1s): hub spins up, barrels extend ────────────────
    for part in hub_parts:
        animate_rotation(part, "transition", duration=1.0, axis='Z',
                         angle_fn=lambda t: t * t * math.pi * 4)
    animate_rotation(hub_gear, "transition", duration=1.0, axis='Z',
                     angle_fn=lambda t: -t * t * math.pi * 4)
    animate_rotation(mg, "transition", duration=1.0, axis='Z',
                     angle_fn=lambda t: t * t * math.pi * 2)
    animate_rotation(sg, "transition", duration=1.0, axis='Z',
                     angle_fn=lambda t: -t * t * math.pi * 2 * GEAR_RATIO)
    animate_shake(body, "transition", duration=1.0, amplitude=0.015, frequency=12, decay=0.5)
    for barrel in barrels:
        animate_static(barrel, "transition", duration=1.0)
    for mount in barrel_mounts:
        animate_static(mount, "transition", duration=1.0)


def apply_splitter_turret_textures(objects):
    """Apply PBR textures to splitter turret."""
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
        "InputHopper": "metal_plate",
        "HopperRim": "metal_plate",
    }
    for i in range(6):
        texture_map[f"Foot_{i}"] = "metal_plate"
    for i in range(3):
        texture_map[f"Barrel_{i}"] = "metal_plate"
        texture_map[f"BarrelMount_{i}"] = "metal_plate"
        texture_map[f"BarrelCollar_{i}"] = "metal_plate"

    for obj_name, tex_id in texture_map.items():
        obj = bpy.data.objects.get(obj_name)
        if obj and obj.type == 'MESH':
            try:
                apply_texture(obj, tex_id, resolution="1k")
            except Exception as e:
                print(f"[night_variants] Warning: texture '{tex_id}' failed for {obj_name}: {e}")


# ═══════════════════════════════════════════════════════════════════════════
# 4. DRILL CACHE
# ═══════════════════════════════════════════════════════════════════════════

def build_drill_cache():
    """Build the drill cache variant -- armored, inert, resource vault."""
    clear_scene()

    root = bpy.data.objects.new("DrillCache", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.5
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # ── BASE PLATFORM (heavier, wider) ───────────────────────────────
    base = add(generate_box(w=2.4, d=2.4, h=0.15, hex_color=NIGHT_STEEL))
    base.name = "BasePlatform"

    # Corner feet
    for i, (fx, fy) in enumerate([(-1.0, -1.0), (1.0, -1.0),
                                   (1.0, 1.0), (-1.0, 1.0)]):
        foot = add(generate_cylinder(radius=0.12, height=0.08, segments=8,
                                     hex_color=NIGHT_DARK))
        foot.name = f"Foot_{i}"
        foot.location = (fx, fy, -0.08)

    # ── MAIN HOUSING (same as drill, darker) ─────────────────────────
    body = add(generate_box(w=2.0, d=2.0, h=0.8, hex_color=NIGHT_BODY, seam_count=2))
    body.name = "Body"
    body.location = (0, 0, 0.15)

    # Reinforcement band (heavier)
    band = add(generate_box(w=2.1, d=2.1, h=0.18, hex_color=NIGHT_STEEL))
    band.name = "Band"
    band.location = (0, 0, 0.45)

    # Second reinforcement band (extra armor)
    band_hi = add(generate_box(w=2.1, d=2.1, h=0.12, hex_color=NIGHT_STEEL))
    band_hi.name = "BandHi"
    band_hi.location = (0, 0, 0.80)

    # Roof plate (armored, sealed)
    roof = add(generate_box(w=2.2, d=2.2, h=0.18, hex_color=NIGHT_BODY_LT))
    roof.name = "Roof"
    roof.location = (0, 0, 0.95)

    # ── ARMOR PLATING over gear/piston areas ─────────────────────────
    # Front armor panel
    armor_front = add(generate_box(w=1.6, d=0.10, h=0.5, hex_color=NIGHT_METAL))
    armor_front.name = "ArmorFront"
    armor_front.location = (0, -1.05, 0.40)

    # Back armor panel
    armor_back = add(generate_box(w=1.6, d=0.10, h=0.5, hex_color=NIGHT_METAL))
    armor_back.name = "ArmorBack"
    armor_back.location = (0, 1.05, 0.40)

    # Left armor panel
    armor_left = add(generate_box(w=0.10, d=1.6, h=0.5, hex_color=NIGHT_METAL))
    armor_left.name = "ArmorLeft"
    armor_left.location = (-1.05, 0, 0.40)

    # Right armor panel (where gears were visible)
    armor_right = add(generate_box(w=0.10, d=1.6, h=0.5, hex_color=NIGHT_METAL))
    armor_right.name = "ArmorRight"
    armor_right.location = (1.05, 0, 0.40)

    # ── RETRACTED DERRICK (folded down instead of tall) ──────────────
    # Short stub where derrick was -- retracted position
    derrick_stub = add(generate_cylinder(radius=0.35, height=0.5, segments=12,
                                          hex_color=NIGHT_STEEL))
    derrick_stub.name = "DerrickStub"
    derrick_stub.location = (0, 0, 1.13)

    # Folded derrick cap (low profile)
    derrick_cap = add(generate_box(w=0.8, d=0.8, h=0.20, hex_color=NIGHT_BODY_LT,
                                    seam_count=1))
    derrick_cap.name = "DerrickCap"
    derrick_cap.location = (0, 0, 1.63)

    # Dome seal on top
    dome_seal = add(generate_hemisphere(radius=0.35, rings=3, segments=10,
                                         hex_color=NIGHT_METAL))
    dome_seal.name = "DomeSeal"
    dome_seal.location = (0, 0, 1.83)

    # ── RESOURCE GLOW (visible through armor slits) ──────────────────
    # Glowing sphere inside showing stored resources
    resource_glow = add(generate_sphere(radius=0.40, rings=6, segments=10,
                                         hex_color=NIGHT_GLOW))
    resource_glow.name = "ResourceGlow"
    resource_glow.location = (0, 0, 0.65)

    # Glow slits -- thin bright boxes on each armor panel face
    slit_positions = [
        (0, -1.11, 0.55, 0.80, 0.02, 0.12),   # front slit
        (0,  1.11, 0.55, 0.80, 0.02, 0.12),   # back slit
        (-1.11, 0, 0.55, 0.02, 0.80, 0.12),   # left slit
        ( 1.11, 0, 0.55, 0.02, 0.80, 0.12),   # right slit
    ]
    for si, (sx, sy, sz, sw, sd, sh) in enumerate(slit_positions):
        slit = add(generate_box(w=sw, d=sd, h=sh, hex_color=NIGHT_GLOW))
        slit.name = f"GlowSlit_{si}"
        slit.location = (sx, sy, sz)

    # ── LOCK-DOWN BANDS (horizontal straps around the body) ──────────
    for li, lz in enumerate([0.28, 0.68]):
        lock_band = add(generate_box(w=2.15, d=2.15, h=0.04, hex_color=NIGHT_ACCENT))
        lock_band.name = f"LockBand_{li}"
        lock_band.location = (0, 0, lz)

    # ── BOLTS (extra heavy, everywhere) ──────────────────────────────
    bolt_positions = [
        # Roof corners
        (0.9, 0.9, 1.14), (-0.9, 0.9, 1.14),
        (0.9, -0.9, 1.14), (-0.9, -0.9, 1.14),
        # Roof mid-edges
        (0.0, 0.95, 1.14), (0.0, -0.95, 1.14),
        (0.95, 0.0, 1.14), (-0.95, 0.0, 1.14),
        # Band bolts
        (1.05, 0.7, 0.50), (1.05, -0.7, 0.50),
        (-1.05, 0.7, 0.50), (-1.05, -0.7, 0.50),
        (0.7, 1.05, 0.50), (-0.7, 1.05, 0.50),
        (0.7, -1.05, 0.50), (-0.7, -1.05, 0.50),
        # Armor panel bolts (front)
        (-0.5, -1.11, 0.35), (0.5, -1.11, 0.35),
        (-0.5, -1.11, 0.65), (0.5, -1.11, 0.65),
        # Armor panel bolts (back)
        (-0.5, 1.11, 0.35), (0.5, 1.11, 0.35),
        (-0.5, 1.11, 0.65), (0.5, 1.11, 0.65),
        # Armor panel bolts (sides)
        (-1.11, -0.5, 0.35), (-1.11, 0.5, 0.35),
        (1.11, -0.5, 0.35), (1.11, 0.5, 0.35),
        (-1.11, -0.5, 0.65), (-1.11, 0.5, 0.65),
        (1.11, -0.5, 0.65), (1.11, 0.5, 0.65),
    ]
    for i, (bx, by, bz) in enumerate(bolt_positions):
        b = add(generate_bolt(head_radius=0.05, head_height=0.03,
                              hex_color=C["rivet"]))
        b.name = f"Bolt_{i}"
        b.location = (bx, by, bz)

    # ── PISTON AREA (covered but visible struts) ─────────────────────
    # Where the piston was -- now shows support struts for the cache
    for si, (sx, sy) in enumerate([(0.5, 0.5), (-0.5, 0.5),
                                    (0.5, -0.5), (-0.5, -0.5)]):
        strut = add(generate_box(w=0.10, d=0.10, h=0.45, hex_color=NIGHT_STEEL))
        strut.name = f"CacheStrut_{si}"
        strut.location = (sx * 0.65, sy * 0.65, 1.13)
        angle_x = math.atan2(sy, 1.0) * 0.2
        angle_y = math.atan2(-sx, 1.0) * 0.2
        strut.rotation_euler = (angle_x, angle_y, 0)

    # ── HAZARD STRIPE ────────────────────────────────────────────────
    hazard = add(generate_box(w=2.05, d=2.05, h=0.04, hex_color=NIGHT_ACCENT))
    hazard.name = "HazardStripe"
    hazard.location = (0, 0, 0.18)

    return {
        "root": root,
        "body": body,
        "band": band,
        "band_hi": band_hi,
        "roof": roof,
        "resource_glow": resource_glow,
        "dome_seal": dome_seal,
        "derrick_stub": derrick_stub,
        "derrick_cap": derrick_cap,
        "base": base,
    }


def bake_drill_cache_animations(objects):
    """Bake animations for the drill cache variant."""
    body = objects["body"]
    band = objects["band"]
    band_hi = objects["band_hi"]
    resource_glow = objects["resource_glow"]
    dome_seal = objects["dome_seal"]
    derrick_stub = objects["derrick_stub"]
    derrick_cap = objects["derrick_cap"]
    roof = objects["roof"]
    base = objects["base"]

    glow_base_z = resource_glow.location.z

    # ── idle (2s): subtle glow pulsation, everything still ───────────
    animate_static(body, "idle", duration=2.0)
    animate_static(band, "idle", duration=2.0)
    animate_static(band_hi, "idle", duration=2.0)
    animate_static(roof, "idle", duration=2.0)
    animate_static(base, "idle", duration=2.0)
    animate_static(dome_seal, "idle", duration=2.0)
    animate_static(derrick_stub, "idle", duration=2.0)
    animate_static(derrick_cap, "idle", duration=2.0)
    # Glow pulses gently
    animate_translation(resource_glow, "idle", duration=2.0, axis='Z',
                        value_fn=lambda t: glow_base_z + 0.015 * math.sin(t * math.pi * 4))

    # ── active (2s): glow intensifies, building hums ─────────────────
    animate_shake(body, "active", duration=2.0, amplitude=0.005, frequency=6)
    animate_shake(band, "active", duration=2.0, amplitude=0.005, frequency=6)
    animate_shake(band_hi, "active", duration=2.0, amplitude=0.005, frequency=6)
    animate_shake(roof, "active", duration=2.0, amplitude=0.003, frequency=6)
    animate_static(base, "active", duration=2.0)
    animate_static(dome_seal, "active", duration=2.0)
    animate_static(derrick_stub, "active", duration=2.0)
    animate_static(derrick_cap, "active", duration=2.0)
    # Stronger glow pulsation with scale
    animate_translation(resource_glow, "active", duration=2.0, axis='Z',
                        value_fn=lambda t: glow_base_z + 0.03 * math.sin(t * math.pi * 6))

    # ── transition (1s): derrick retracts, armor slams shut ──────────
    animate_shake(body, "transition", duration=1.0, amplitude=0.02, frequency=15, decay=0.5)
    animate_shake(band, "transition", duration=1.0, amplitude=0.02, frequency=15, decay=0.5)
    animate_shake(band_hi, "transition", duration=1.0, amplitude=0.02, frequency=15, decay=0.5)
    animate_shake(roof, "transition", duration=1.0, amplitude=0.015, frequency=15, decay=0.5)
    animate_static(base, "transition", duration=1.0)
    # Derrick stub drops down (retracting)
    stub_z = derrick_stub.location.z
    animate_translation(derrick_stub, "transition", duration=1.0, axis='Z',
                        value_fn=lambda t: stub_z + 0.3 * (1 - t))
    cap_z = derrick_cap.location.z
    animate_translation(derrick_cap, "transition", duration=1.0, axis='Z',
                        value_fn=lambda t: cap_z + 0.3 * (1 - t))
    seal_z = dome_seal.location.z
    animate_translation(dome_seal, "transition", duration=1.0, axis='Z',
                        value_fn=lambda t: seal_z + 0.3 * (1 - t))
    # Glow starts dim, brightens
    animate_translation(resource_glow, "transition", duration=1.0, axis='Z',
                        value_fn=lambda t: glow_base_z + 0.02 * t * math.sin(t * math.pi * 4))


def apply_drill_cache_textures(objects):
    """Apply PBR textures to drill cache."""
    texture_map = {
        "BasePlatform": "metal_plate_02",
        "Body": "painted_metal_shutter",
        "Band": "metal_plate",
        "BandHi": "metal_plate",
        "Roof": "metal_plate_02",
        "DerrickStub": "metal_plate",
        "DerrickCap": "painted_metal_shutter",
        "DomeSeal": "metal_plate",
        "ArmorFront": "metal_plate",
        "ArmorBack": "metal_plate",
        "ArmorLeft": "metal_plate",
        "ArmorRight": "metal_plate",
    }
    for i in range(4):
        texture_map[f"Foot_{i}"] = "metal_plate"
        texture_map[f"CacheStrut_{i}"] = "metal_plate"

    for obj_name, tex_id in texture_map.items():
        obj = bpy.data.objects.get(obj_name)
        if obj and obj.type == 'MESH':
            try:
                apply_texture(obj, tex_id, resolution="1k")
            except Exception as e:
                print(f"[night_variants] Warning: texture '{tex_id}' failed for {obj_name}: {e}")


# ═══════════════════════════════════════════════════════════════════════════
# Main — build all 4 variants in sequence
# ═══════════════════════════════════════════════════════════════════════════

def build_and_export(name, build_fn, anim_fn, texture_fn, output_dir):
    """Build, animate, and export a variant (flat + textured)."""
    print(f"\n[night_variants] === Building {name} ===")

    # --- Pass 1: Flat version ---
    objects = build_fn()
    anim_fn(objects)

    flat_glb = os.path.join(output_dir, f"{name}_flat.glb")
    export_glb(flat_glb)
    flat_blend = os.path.join(output_dir, f"{name}_flat.blend")
    export_blend(flat_blend)
    print(f"[night_variants] Flat: {flat_glb}")

    # --- Pass 2: Textured version ---
    objects = build_fn()
    anim_fn(objects)
    texture_fn(objects)

    textured_glb = os.path.join(output_dir, f"{name}.glb")
    export_glb(textured_glb)
    textured_blend = os.path.join(output_dir, f"{name}.blend")
    export_blend(textured_blend)
    print(f"[night_variants] Textured: {textured_glb}")


def main():
    print("[night_variants] Building all night-mode variants...")

    # 1. Conveyor Wall
    build_and_export(
        "conveyor_wall",
        build_conveyor_wall,
        bake_conveyor_wall_animations,
        apply_conveyor_wall_textures,
        os.path.join(REPO_ROOT, "buildings", "conveyor", "models"),
    )

    # 2. Smelter Turret
    build_and_export(
        "smelter_turret",
        build_smelter_turret,
        bake_smelter_turret_animations,
        apply_smelter_turret_textures,
        os.path.join(REPO_ROOT, "buildings", "smelter", "models"),
    )

    # 3. Splitter Multi-Turret
    build_and_export(
        "splitter_turret",
        build_splitter_turret,
        bake_splitter_turret_animations,
        apply_splitter_turret_textures,
        os.path.join(REPO_ROOT, "buildings", "splitter", "models"),
    )

    # 4. Drill Cache
    build_and_export(
        "drill_cache",
        build_drill_cache,
        bake_drill_cache_animations,
        apply_drill_cache_textures,
        os.path.join(REPO_ROOT, "buildings", "drill", "models"),
    )

    print("\n[night_variants] All 4 night variants exported successfully!")


if __name__ == "__main__":
    main()
