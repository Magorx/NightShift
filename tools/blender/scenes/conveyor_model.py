"""Export conveyor belt as a 3D model (.glb) for Godot import.

The conveyor is a low, ground-level track that transports items between
buildings. At night, its side walls become defensive barriers against
monsters. This is the most-placed building in the game.

Design:
- 1x1 grid cell = 2.0x2.0 Blender units footprint
- Very low height (~0.3 for belt surface, walls ~0.3 above that)
- Open at Y ends for seamless tiling with adjacent conveyors
- Side walls (X) are solid — these become the night barrier
- Visible rollers under the belt surface
- Yellow directional arrow showing flow (+Y direction)

Animations (3 NLA states):
- idle (2s):  Everything stationary, subtle roller vibration
- active (2s): Rollers spin, belt surface vibrates suggesting movement
- wall (2s):  Static wall mode

Exports flat + textured versions.

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/conveyor_model.py

    # Custom output path:
    $BLENDER --background --python tools/blender/scenes/conveyor_model.py -- --output path/to/conveyor.glb
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
from prefabs_src.bolt import generate_bolt
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

    output = os.path.join(REPO_ROOT, "buildings", "conveyor", "models", "conveyor.glb")

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

# Belt surface colors
BELT_DARK    = C["conv_dark"]     # #3C3C42
BELT_BASE    = C["conv_base"]     # #3D3D43
BELT_MID     = C["conv_mid"]      # #505256

# Rail / structure colors
RAIL_GROOVE  = C["conv_groove"]   # #5A5C62
RAIL_LIGHT   = C["conv_light"]    # #6C6D6F
ACCENT_DARK  = C["conv_accent"]   # #B59C18
ACCENT_YELLOW = C["conv_yellow"]  # #D2B937

# Structure
BODY         = C["body"]          # #46372D
BODY_LIGHT   = C["body_light"]    # #524134
RIVET        = C["rivet"]         # #5A4B3C
SHADOW       = C["shadow"]        # #231C16


# ---------------------------------------------------------------------------
# Custom mesh generators
# ---------------------------------------------------------------------------
def generate_roller(radius=0.06, length=1.0, segments=8, hex_color="#505256"):
    """Generate a cylinder lying along the X axis, centered at origin.

    Unlike generate_cylinder (which builds along Z), this creates a roller
    oriented along X from -length/2 to +length/2, centered at the origin.
    This avoids rotation issues with glTF export_apply.
    """
    bm = bmesh.new()
    half_l = length / 2

    # Create rings at each end
    left_verts = []
    right_verts = []
    for i in range(segments):
        angle = (i / segments) * 2 * math.pi
        y = radius * math.cos(angle)
        z = radius * math.sin(angle)
        left_verts.append(bm.verts.new((-half_l, y, z)))
        right_verts.append(bm.verts.new((half_l, y, z)))

    bm.verts.ensure_lookup_table()

    # End caps
    bm.faces.new(list(reversed(left_verts)))   # left cap (faces -X)
    bm.faces.new(right_verts)                   # right cap (faces +X)

    # Side faces
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


def generate_arrow(length=0.3, width=0.2, thickness=0.02, hex_color="#D2B937"):
    """Generate a flat arrow pointing in +Y direction, sitting on Z=0."""
    bm = bmesh.new()
    hl = length / 2
    hw = width / 2
    shaft_w = width * 0.3

    # Bottom verts: shaft (-hl to 0) + head (0 to +hl)
    sb_l = bm.verts.new((-shaft_w, -hl, 0))
    sb_r = bm.verts.new(( shaft_w, -hl, 0))
    sf_l = bm.verts.new((-shaft_w,   0, 0))
    sf_r = bm.verts.new(( shaft_w,   0, 0))
    hd_l = bm.verts.new((-hw,        0, 0))
    hd_r = bm.verts.new(( hw,        0, 0))
    tip  = bm.verts.new(( 0,        hl, 0))

    # Top verts (extruded by thickness)
    t = thickness
    sb_lt = bm.verts.new((-shaft_w, -hl, t))
    sb_rt = bm.verts.new(( shaft_w, -hl, t))
    sf_lt = bm.verts.new((-shaft_w,   0, t))
    sf_rt = bm.verts.new(( shaft_w,   0, t))
    hd_lt = bm.verts.new((-hw,        0, t))
    hd_rt = bm.verts.new(( hw,        0, t))
    tip_t = bm.verts.new(( 0,        hl, t))

    bm.verts.ensure_lookup_table()

    # Bottom faces
    bm.faces.new([sb_r, sb_l, sf_l, sf_r])
    bm.faces.new([hd_r, hd_l, tip])

    # Top faces
    bm.faces.new([sb_lt, sb_rt, sf_rt, sf_lt])
    bm.faces.new([hd_lt, hd_rt, tip_t])

    # Shaft sides
    bm.faces.new([sb_l, sb_lt, sf_lt, sf_l])    # left
    bm.faces.new([sf_r, sf_rt, sb_rt, sb_r])    # right
    bm.faces.new([sb_l, sb_r, sb_rt, sb_lt])    # back

    # Head sides
    bm.faces.new([hd_l, hd_lt, tip_t, tip])     # left edge
    bm.faces.new([tip, tip_t, hd_rt, hd_r])     # right edge
    bm.faces.new([hd_r, hd_rt, hd_lt, hd_l])    # back of head

    # Junction fills (shaft front to head back)
    bm.faces.new([sf_l, sf_lt, hd_lt, hd_l])    # left
    bm.faces.new([hd_r, hd_rt, sf_rt, sf_r])    # right

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("Arrow")
    bm.to_mesh(mesh)
    bm.free()
    mesh.validate()

    obj = bpy.data.objects.new("Arrow", mesh)
    bpy.context.scene.collection.objects.link(obj)

    mat = create_flat_material("ArrowMat", hex_color)
    obj.data.materials.append(mat)

    for poly in obj.data.polygons:
        poly.use_smooth = False

    return obj


# ---------------------------------------------------------------------------
# Build the scene
# ---------------------------------------------------------------------------
def build_conveyor():
    """Build the full conveyor as a parented hierarchy under a root empty."""
    clear_scene()

    root = bpy.data.objects.new("Conveyor", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.5
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # ── DIMENSIONS ────────────────────────────────────────────────────
    CELL = 2.0
    HALF = CELL / 2  # 1.0

    # Heights — conveyor is LOW, like a track / road surface
    BASE_H     = 0.06     # thin base plate
    ROLLER_R   = 0.05     # roller radius
    ROLLER_Z   = BASE_H   # rollers sit on the base
    BELT_Z     = BASE_H + ROLLER_R * 2 + 0.01  # belt on rollers (~0.17)
    BELT_H     = 0.03     # belt surface thickness
    WALL_H     = 0.28     # side wall height (night barrier)
    WALL_THICK = 0.10     # wall thickness

    # Belt track width (between inner wall faces)
    BELT_W     = CELL - WALL_THICK * 2  # 1.8
    HALF_BW    = BELT_W / 2             # 0.9
    # Roller length (slightly shorter than belt width for clearance)
    ROLLER_LEN = BELT_W - 0.10          # 1.7

    # ── BASE PLATE ────────────────────────────────────────────────────
    base = add(generate_box(w=CELL, d=CELL, h=BASE_H, hex_color=BODY))
    base.name = "BasePlate"

    # ── SIDE WALLS ────────────────────────────────────────────────────
    # Left wall (-X)
    wall_l = add(generate_box(w=WALL_THICK, d=CELL, h=WALL_H, hex_color=RAIL_GROOVE))
    wall_l.name = "WallLeft"
    wall_l.location = (-(HALF - WALL_THICK / 2), 0, BASE_H)

    # Right wall (+X)
    wall_r = add(generate_box(w=WALL_THICK, d=CELL, h=WALL_H, hex_color=RAIL_GROOVE))
    wall_r.name = "WallRight"
    wall_r.location = ((HALF - WALL_THICK / 2), 0, BASE_H)

    # ── WALL CAPS (top rails) ────────────────────────────────────────
    CAP_H = 0.03
    cap_l = add(generate_box(w=WALL_THICK + 0.04, d=CELL, h=CAP_H, hex_color=RAIL_LIGHT))
    cap_l.name = "WallCapLeft"
    cap_l.location = (-(HALF - WALL_THICK / 2), 0, BASE_H + WALL_H)

    cap_r = add(generate_box(w=WALL_THICK + 0.04, d=CELL, h=CAP_H, hex_color=RAIL_LIGHT))
    cap_r.name = "WallCapRight"
    cap_r.location = ((HALF - WALL_THICK / 2), 0, BASE_H + WALL_H)

    # ── INNER RAIL LIPS ──────────────────────────────────────────────
    # Small overhanging edges along the inner wall top to guide items
    LIP_H = 0.02
    LIP_W = 0.025
    lip_l = add(generate_box(w=LIP_W, d=CELL, h=LIP_H, hex_color=RAIL_LIGHT))
    lip_l.name = "LipLeft"
    lip_l.location = (-(HALF_BW - LIP_W / 2 + 0.01), 0, BASE_H + WALL_H)

    lip_r = add(generate_box(w=LIP_W, d=CELL, h=LIP_H, hex_color=RAIL_LIGHT))
    lip_r.name = "LipRight"
    lip_r.location = ((HALF_BW - LIP_W / 2 + 0.01), 0, BASE_H + WALL_H)

    # ── ROLLERS ──────────────────────────────────────────────────────
    # Cylinders lying along X axis, spaced evenly along Y
    ROLLER_SPACING = 0.30
    NUM_ROLLERS = int(CELL / ROLLER_SPACING)
    rollers = []

    for i in range(NUM_ROLLERS):
        y_pos = -HALF + ROLLER_SPACING * (i + 0.5)
        roller = add(generate_roller(radius=ROLLER_R, length=ROLLER_LEN,
                                     segments=8, hex_color=BELT_MID))
        roller.name = f"Roller_{i}"
        roller.location = (0, y_pos, ROLLER_Z + ROLLER_R)
        rollers.append(roller)

    # ── ROLLER AXLE ENDCAPS ──────────────────────────────────────────
    # Tiny discs at each end of first, middle, and last roller for detail
    ENDCAP_R = ROLLER_R * 0.6
    highlight_indices = [0, NUM_ROLLERS // 2, NUM_ROLLERS - 1]
    for ri in highlight_indices:
        y_pos = -HALF + ROLLER_SPACING * (ri + 0.5)
        for sx in [-ROLLER_LEN / 2 - 0.005, ROLLER_LEN / 2 + 0.005]:
            ec = add(generate_roller(radius=ENDCAP_R, length=0.01,
                                     segments=6, hex_color=BODY_LIGHT))
            ec.name = f"Endcap_{ri}_{'+' if sx > 0 else '-'}"
            ec.location = (sx, y_pos, ROLLER_Z + ROLLER_R)

    # ── BELT SURFACE ─────────────────────────────────────────────────
    belt = add(generate_box(w=BELT_W, d=CELL, h=BELT_H, hex_color=BELT_BASE))
    belt.name = "BeltSurface"
    belt.location = (0, 0, BELT_Z)

    # Traction grooves — thin lines running along Y on belt surface
    GROOVE_W = 0.015
    for gi, gx in enumerate([-0.35, -0.12, 0.12, 0.35]):
        groove = add(generate_box(w=GROOVE_W, d=CELL, h=0.004,
                                  hex_color=BELT_DARK))
        groove.name = f"BeltGroove_{gi}"
        groove.location = (gx, 0, BELT_Z + BELT_H)

    # ── DIRECTIONAL ARROWS ────────────────────────────────────────────
    arrow_z = BELT_Z + BELT_H + 0.002
    # Main arrow (bright yellow)
    arrow = add(generate_arrow(length=0.40, width=0.28, thickness=0.006,
                               hex_color=ACCENT_YELLOW))
    arrow.name = "DirectionArrow"
    arrow.location = (0, 0.0, arrow_z)

    # Trailing arrow (darker, smaller)
    arrow2 = add(generate_arrow(length=0.22, width=0.16, thickness=0.006,
                                hex_color=ACCENT_DARK))
    arrow2.name = "DirectionArrow2"
    arrow2.location = (0, -0.45, arrow_z)

    # ── STRUCTURAL CROSS-MEMBERS ─────────────────────────────────────
    # Beams running across under the belt (visible from side)
    for cy in [-0.65, 0.0, 0.65]:
        cross = add(generate_box(w=BELT_W * 0.8, d=0.05, h=0.035,
                                 hex_color=SHADOW))
        cross.name = f"CrossMember_{cy:.1f}"
        cross.location = (0, cy, BASE_H)

    # ── WALL REINFORCEMENT RIBS ──────────────────────────────────────
    # Vertical ribs on outer wall faces for structural look
    RIB_W = 0.015
    RIB_D = 0.02
    rib_y_positions = [-0.7, -0.25, 0.25, 0.7]
    for side in [-1, 1]:
        wall_x = side * (HALF - WALL_THICK / 2)
        rib_x = wall_x + side * (WALL_THICK / 2 + RIB_D / 2)
        for ry in rib_y_positions:
            rib = add(generate_box(w=RIB_D, d=RIB_W, h=WALL_H * 0.8,
                                   hex_color=BODY_LIGHT))
            rib.name = f"Rib_{side}_{ry:.1f}"
            rib.location = (rib_x, ry, BASE_H + WALL_H * 0.1)

    # ── BOLTS ─────────────────────────────────────────────────────────
    bolt_positions = [
        # Wall cap bolts
        (-(HALF - WALL_THICK / 2), -0.70, BASE_H + WALL_H + CAP_H),
        (-(HALF - WALL_THICK / 2),  0.70, BASE_H + WALL_H + CAP_H),
        ( (HALF - WALL_THICK / 2), -0.70, BASE_H + WALL_H + CAP_H),
        ( (HALF - WALL_THICK / 2),  0.70, BASE_H + WALL_H + CAP_H),
        # Wall mid-height bolts (outer face)
        (-(HALF + 0.005), -0.45, BASE_H + WALL_H * 0.35),
        (-(HALF + 0.005),  0.45, BASE_H + WALL_H * 0.35),
        ( (HALF + 0.005), -0.45, BASE_H + WALL_H * 0.35),
        ( (HALF + 0.005),  0.45, BASE_H + WALL_H * 0.35),
    ]
    for bi, (bx, by, bz) in enumerate(bolt_positions):
        b = add(generate_bolt(head_radius=0.025, head_height=0.015,
                              hex_color=RIVET))
        b.name = f"Bolt_{bi}"
        b.location = (bx, by, bz)

    # ── HAZARD STRIPE ─────────────────────────────────────────────────
    # Thin accent stripe at the base for visual grounding
    stripe = add(generate_box(w=CELL + 0.01, d=CELL + 0.01, h=0.01,
                              hex_color=ACCENT_DARK))
    stripe.name = "HazardStripe"
    stripe.location = (0, 0, BASE_H * 0.5)

    return {
        "root": root,
        "rollers": rollers,
        "belt": belt,
        "wall_l": wall_l,
        "wall_r": wall_r,
        "cap_l": cap_l,
        "cap_r": cap_r,
        "base": base,
    }


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------
def bake_animations(objects):
    """Bake all animation states using high-level helpers."""
    rollers = objects["rollers"]
    belt = objects["belt"]
    wall_l = objects["wall_l"]
    wall_r = objects["wall_r"]
    base = objects["base"]

    # ── idle (2s): everything still, subtle roller vibration ──────────
    for roller in rollers:
        # Rollers are along X, they spin around X axis
        animate_rotation(roller, "idle", duration=2.0, axis='X',
                         angle_fn=lambda t: 0.03 * math.sin(t * math.pi * 2))
    animate_static(belt, "idle", duration=2.0)
    animate_static(wall_l, "idle", duration=2.0)
    animate_static(wall_r, "idle", duration=2.0)
    animate_static(base, "idle", duration=2.0)

    # ── active (2s): rollers spin, belt vibrates ──────────────────────
    for roller in rollers:
        # Full spin around X (the roller's long axis)
        animate_rotation(roller, "active", duration=2.0, axis='X',
                         total_angle=math.pi * 8)
    # Belt surface vibrates slightly to suggest movement
    animate_shake(belt, "active", duration=2.0, amplitude=0.004, frequency=10)
    animate_static(wall_l, "active", duration=2.0)
    animate_static(wall_r, "active", duration=2.0)
    animate_static(base, "active", duration=2.0)

    # ── wall (2s): static reinforced mode ─────────────────────────────
    for roller in rollers:
        animate_static(roller, "wall", duration=2.0)
    animate_static(belt, "wall", duration=2.0)
    animate_static(wall_l, "wall", duration=2.0)
    animate_static(wall_r, "wall", duration=2.0)
    animate_static(base, "wall", duration=2.0)


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


# ---------------------------------------------------------------------------
# Texturing pass
# ---------------------------------------------------------------------------
def apply_textures(objects):
    """Apply PBR textures to the flat-colored model."""
    root = objects["root"]

    for obj in root.children:
        name = obj.name

        if "Wall" in name and "Cap" not in name:
            apply_texture(obj, "metal_plate", resolution="1k")
        elif "Cap" in name or "Lip" in name:
            apply_texture(obj, "metal_plate", resolution="1k")
        elif "BasePlate" in name:
            apply_texture(obj, "metal_plate_02", resolution="1k")
        elif name.startswith("Roller_"):
            apply_texture(obj, "metal_plate", resolution="1k")
        elif "BeltSurface" in name:
            apply_texture(obj, "metal_plate_02", resolution="1k")
        elif "Rib" in name or "CrossMember" in name:
            apply_texture(obj, "rusty_metal_02", resolution="1k")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    output = parse_args()
    print(f"[conveyor_model] Building conveyor, exporting to {output}")

    # --- Pass 1: Flat version ---
    objects = build_conveyor()
    bake_animations(objects)

    flat_output = output.replace("conveyor.glb", "conveyor_flat.glb")
    export_glb(flat_output)
    flat_blend = os.path.splitext(flat_output)[0] + ".blend"
    export_blend(flat_blend)
    print(f"[conveyor_model] Flat: {flat_output}")

    # --- Pass 2: Textured version ---
    objects = build_conveyor()
    bake_animations(objects)
    apply_textures(objects)

    export_glb(output)
    blend_path = os.path.splitext(output)[0] + ".blend"
    export_blend(blend_path)

    print(f"[conveyor_model] Textured: {output}")
    print(f"[conveyor_model] Blend: {blend_path}")
    print(f"[conveyor_model] Done.")


if __name__ == "__main__":
    main()
