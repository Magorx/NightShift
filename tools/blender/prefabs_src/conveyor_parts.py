"""Shared conveyor building parts for all conveyor variants.

Provides reusable functions for assembling conveyor models from common
parts: base plates, wall segments, belt surfaces, arrows, bolts, ribs.

Each function takes an `add` callback that parents the created object
to the variant's root empty.

Sides are identified by string: 'left' (-X), 'right' (+X), 'back' (-Y), 'front' (+Y).

Usage:
    from prefabs_src.conveyor_parts import *

    root, add = create_conveyor_root("Conveyor")
    base = add_base_plate(add)
    wall, cap, lip = add_wall(add, 'left')
    add_wall_details(add, 'left')
    belt = add_belt_surface(add, walled_sides={'left', 'right'})
    ...
"""

import bpy
import bmesh
import math
import os
import sys

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(__file__), "..")))
from materials.pixel_art import create_flat_material, load_palette
from prefabs_src.box import generate_box
from prefabs_src.bolt import generate_bolt


# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
C = load_palette("buildings")

BELT_DARK     = C["conv_dark"]
BELT_BASE     = C["conv_base"]
BELT_MID      = C["conv_mid"]
RAIL_GROOVE   = C["conv_groove"]
RAIL_LIGHT    = C["conv_light"]
ACCENT_DARK   = C["conv_accent"]
ACCENT_YELLOW = C["conv_yellow"]
BODY          = C["body"]
BODY_LIGHT    = C["body_light"]
RIVET         = C["rivet"]
SHADOW        = C["shadow"]


# ---------------------------------------------------------------------------
# Dimensions
# ---------------------------------------------------------------------------
CELL       = 1.0
HALF       = 0.5
BASE_H     = 0.03
BELT_Z     = 0.085
BELT_H     = 0.015
WALL_H     = 0.14
WALL_THICK = 0.05
CAP_H      = 0.015
LIP_H      = 0.01
LIP_W      = 0.0125
RIB_W      = 0.0075
RIB_D      = 0.01
ARROW_Z    = BELT_Z + BELT_H + 0.001
GROOVE_W   = 0.0075


# ---------------------------------------------------------------------------
# Root helper
# ---------------------------------------------------------------------------
def create_conveyor_root(name="Conveyor"):
    """Create a root empty and return (root, add_fn)."""
    root = bpy.data.objects.new(name, None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.25
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    return root, add


# ---------------------------------------------------------------------------
# Base plate & hazard stripe
# ---------------------------------------------------------------------------
def add_base_plate(add):
    """Full-cell base plate."""
    base = add(generate_box(w=CELL, d=CELL, h=BASE_H, hex_color=BODY))
    base.name = "BasePlate"
    return base


def add_hazard_stripe(add):
    """Thin accent stripe at base for visual grounding."""
    stripe = add(generate_box(w=CELL + 0.005, d=CELL + 0.005, h=0.005,
                              hex_color=ACCENT_DARK))
    stripe.name = "HazardStripe"
    stripe.location = (0, 0, BASE_H * 0.5)
    return stripe


# ---------------------------------------------------------------------------
# Wall segments
# ---------------------------------------------------------------------------
def _wall_params(side):
    """Return (wall_w, wall_d, cap_w, cap_d, lip_w, lip_d, px, py, lip_px, lip_py)."""
    if side == 'left':
        px = -(HALF - WALL_THICK / 2)
        lip_px = -(HALF - WALL_THICK - LIP_W / 2 + 0.005)
        return (WALL_THICK, CELL, WALL_THICK + 0.02, CELL,
                LIP_W, CELL, px, 0, lip_px, 0)
    elif side == 'right':
        px = (HALF - WALL_THICK / 2)
        lip_px = (HALF - WALL_THICK - LIP_W / 2 + 0.005)
        return (WALL_THICK, CELL, WALL_THICK + 0.02, CELL,
                LIP_W, CELL, px, 0, lip_px, 0)
    elif side == 'back':
        py = -(HALF - WALL_THICK / 2)
        lip_py = -(HALF - WALL_THICK - LIP_W / 2 + 0.005)
        return (CELL, WALL_THICK, CELL, WALL_THICK + 0.02,
                CELL, LIP_W, 0, py, 0, lip_py)
    else:  # 'front'
        py = (HALF - WALL_THICK / 2)
        lip_py = (HALF - WALL_THICK - LIP_W / 2 + 0.005)
        return (CELL, WALL_THICK, CELL, WALL_THICK + 0.02,
                CELL, LIP_W, 0, py, 0, lip_py)


def add_wall(add, side):
    """Add wall + cap + lip on one side. Returns (wall, cap, lip)."""
    ww, wd, cw, cd, lw, ld, px, py, lpx, lpy = _wall_params(side)

    wall = add(generate_box(w=ww, d=wd, h=WALL_H, hex_color=RAIL_GROOVE))
    wall.name = f"Wall_{side}"
    wall.location = (px, py, BASE_H)

    cap = add(generate_box(w=cw, d=cd, h=CAP_H, hex_color=RAIL_LIGHT))
    cap.name = f"WallCap_{side}"
    cap.location = (px, py, BASE_H + WALL_H)

    lip = add(generate_box(w=lw, d=ld, h=LIP_H, hex_color=RAIL_LIGHT))
    lip.name = f"Lip_{side}"
    lip.location = (lpx, lpy, BASE_H + WALL_H)

    return wall, cap, lip


# ---------------------------------------------------------------------------
# Wall details (ribs + bolts)
# ---------------------------------------------------------------------------
_RIB_POSITIONS = [-0.35, -0.125, 0.125, 0.35]
_BOLT_SPREAD = [-0.35, 0.35]
_BOLT_MID_SPREAD = [-0.225, 0.225]


def add_wall_ribs(add, side):
    """Vertical reinforcement ribs on outer face of a wall."""
    if side in ('left', 'right'):
        sign = -1 if side == 'left' else 1
        wall_x = sign * (HALF - WALL_THICK / 2)
        rib_x = wall_x + sign * (WALL_THICK / 2 + RIB_D / 2)
        for ry in _RIB_POSITIONS:
            rib = add(generate_box(w=RIB_D, d=RIB_W, h=WALL_H * 0.8,
                                   hex_color=BODY_LIGHT))
            rib.name = f"Rib_{side}_{ry:.1f}"
            rib.location = (rib_x, ry, BASE_H + WALL_H * 0.1)
    else:
        sign = -1 if side == 'back' else 1
        wall_y = sign * (HALF - WALL_THICK / 2)
        rib_y = wall_y + sign * (WALL_THICK / 2 + RIB_D / 2)
        for rx in _RIB_POSITIONS:
            rib = add(generate_box(w=RIB_W, d=RIB_D, h=WALL_H * 0.8,
                                   hex_color=BODY_LIGHT))
            rib.name = f"Rib_{side}_{rx:.1f}"
            rib.location = (rx, rib_y, BASE_H + WALL_H * 0.1)


def add_wall_bolts(add, side):
    """Cap bolts + mid-height bolts on a wall."""
    if side in ('left', 'right'):
        sign = -1 if side == 'left' else 1
        wx = sign * (HALF - WALL_THICK / 2)
        ox = sign * (HALF + 0.0025)
        positions = []
        for sy in _BOLT_SPREAD:
            positions.append((wx, sy, BASE_H + WALL_H + CAP_H))
        for sy in _BOLT_MID_SPREAD:
            positions.append((ox, sy, BASE_H + WALL_H * 0.35))
    else:
        sign = -1 if side == 'back' else 1
        wy = sign * (HALF - WALL_THICK / 2)
        oy = sign * (HALF + 0.0025)
        positions = []
        for sx in _BOLT_SPREAD:
            positions.append((sx, wy, BASE_H + WALL_H + CAP_H))
        for sx in _BOLT_MID_SPREAD:
            positions.append((sx, oy, BASE_H + WALL_H * 0.35))

    for bi, (bx, by, bz) in enumerate(positions):
        b = add(generate_bolt(head_radius=0.0125, head_height=0.0075,
                              hex_color=RIVET))
        b.name = f"Bolt_{side}_{bi}"
        b.location = (bx, by, bz)


def add_wall_details(add, side):
    """Add both ribs and bolts to a wall."""
    add_wall_ribs(add, side)
    add_wall_bolts(add, side)


# ---------------------------------------------------------------------------
# Belt surface
# ---------------------------------------------------------------------------
def add_belt_surface(add, walled_sides):
    """Add belt surface sized to fit between walled sides.

    Open sides extend to the cell edge; walled sides stop at the inner wall face.
    """
    x_min = -(HALF - WALL_THICK) if 'left' in walled_sides else -HALF
    x_max = (HALF - WALL_THICK) if 'right' in walled_sides else HALF
    y_min = -(HALF - WALL_THICK) if 'back' in walled_sides else -HALF
    y_max = (HALF - WALL_THICK) if 'front' in walled_sides else HALF

    w = x_max - x_min
    d = y_max - y_min
    cx = (x_min + x_max) / 2
    cy = (y_min + y_max) / 2

    belt = add(generate_box(w=w, d=d, h=BELT_H, hex_color=BELT_BASE))
    belt.name = "BeltSurface"
    belt.location = (cx, cy, BELT_Z)
    return belt


# ---------------------------------------------------------------------------
# Belt grooves
# ---------------------------------------------------------------------------
_GROOVE_OFFSETS = [-0.175, -0.06, 0.06, 0.175]


def add_belt_grooves_y(add, walled_sides):
    """Traction grooves running along Y (for flow in Y direction)."""
    y_min = -(HALF - WALL_THICK) if 'back' in walled_sides else -HALF
    y_max = (HALF - WALL_THICK) if 'front' in walled_sides else HALF
    d = y_max - y_min
    cy = (y_min + y_max) / 2

    for gi, gx in enumerate(_GROOVE_OFFSETS):
        groove = add(generate_box(w=GROOVE_W, d=d, h=0.002, hex_color=BELT_DARK))
        groove.name = f"BeltGroove_y{gi}"
        groove.location = (gx, cy, BELT_Z + BELT_H)


def add_belt_grooves_x(add, walled_sides):
    """Traction grooves running along X (for flow in X direction)."""
    x_min = -(HALF - WALL_THICK) if 'left' in walled_sides else -HALF
    x_max = (HALF - WALL_THICK) if 'right' in walled_sides else HALF
    w = x_max - x_min
    cx = (x_min + x_max) / 2

    for gi, gy in enumerate(_GROOVE_OFFSETS):
        groove = add(generate_box(w=w, d=GROOVE_W, h=0.002, hex_color=BELT_DARK))
        groove.name = f"BeltGroove_x{gi}"
        groove.location = (cx, gy, BELT_Z + BELT_H)


# ---------------------------------------------------------------------------
# Direction arrow
# ---------------------------------------------------------------------------
def generate_arrow(length=0.15, width=0.1, thickness=0.01, hex_color=None):
    """Generate a flat arrow pointing in +Y direction, sitting on Z=0."""
    if hex_color is None:
        hex_color = ACCENT_YELLOW

    bm = bmesh.new()
    hl = length / 2
    hw = width / 2
    shaft_w = width * 0.3
    t = thickness

    # Bottom verts: shaft then head
    sb_l = bm.verts.new((-shaft_w, -hl, 0))
    sb_r = bm.verts.new(( shaft_w, -hl, 0))
    sf_l = bm.verts.new((-shaft_w,   0, 0))
    sf_r = bm.verts.new(( shaft_w,   0, 0))
    hd_l = bm.verts.new((-hw,        0, 0))
    hd_r = bm.verts.new(( hw,        0, 0))
    tip  = bm.verts.new(( 0,        hl, 0))

    # Top verts
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
    bm.faces.new([sb_l, sb_lt, sf_lt, sf_l])
    bm.faces.new([sf_r, sf_rt, sb_rt, sb_r])
    bm.faces.new([sb_l, sb_r, sb_rt, sb_lt])
    # Head sides
    bm.faces.new([hd_l, hd_lt, tip_t, tip])
    bm.faces.new([tip, tip_t, hd_rt, hd_r])
    bm.faces.new([hd_r, hd_rt, hd_lt, hd_l])
    # Junction fills
    bm.faces.new([sf_l, sf_lt, hd_lt, hd_l])
    bm.faces.new([hd_r, hd_rt, sf_rt, sf_r])

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


def add_direction_arrow(add, x=0, y=0.05, rotation_deg=0,
                        length=0.55, width=0.45):
    """Add a direction arrow on the belt surface.

    Arrow is generated pointing +Y then rotated around Z.
    rotation_deg: 0=+Y, 90=-X, 180=-Y, 270=+X
    """
    arrow = add(generate_arrow(length=length, width=width, thickness=0.003,
                               hex_color=ACCENT_YELLOW))
    arrow.name = f"Arrow_{rotation_deg:.0f}"
    arrow.location = (x, y, ARROW_Z)
    if rotation_deg != 0:
        arrow.rotation_euler = (0, 0, math.radians(rotation_deg))
    return arrow


# ---------------------------------------------------------------------------
# Texturing
# ---------------------------------------------------------------------------
def apply_conveyor_textures(root):
    """Apply PBR textures to all children of root based on naming."""
    from texture_library import apply_texture

    for obj in root.children:
        name = obj.name
        if "Wall_" in name and "Cap" not in name:
            apply_texture(obj, "metal_plate", resolution="1k")
        elif "Cap" in name or "Lip" in name:
            apply_texture(obj, "metal_plate", resolution="1k")
        elif "BasePlate" in name:
            apply_texture(obj, "metal_plate_02", resolution="1k")
        elif "BeltSurface" in name:
            apply_texture(obj, "metal_plate_02", resolution="1k")
        elif "Rib" in name:
            apply_texture(obj, "rusty_metal_02", resolution="1k")
