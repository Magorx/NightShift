"""Export Junction and Tunnel utility buildings as 3D models (.glb) for Godot.

Junction: 4-way crossover where items cross over each other.
- Square platform with crossed channels/tracks
- Raised center hub where items cross
- Low profile (~0.3 height)

Tunnel: Underground passage that monsters can't cross.
- Two arch-shaped entrance/exit portals facing opposite directions
- Flat cover plate connecting them
- Sturdy, reinforced look

Both are 1.0x1.0 footprint utility buildings, simpler than the main
production buildings.

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/junction_tunnel_model.py
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

from export_helpers import export_glb
from render import clear_scene
from materials.pixel_art import create_flat_material, load_palette
from texture_library import apply_texture
from prefabs_src.box import generate_box
from prefabs_src.cylinder import generate_cylinder
from prefabs_src.cone import generate_cone
from prefabs_src.bolt import generate_bolt
from prefabs_src.pipe import generate_pipe
from prefabs_src.wedge import generate_wedge
from anim_helpers import (
    animate_rotation, animate_translation, animate_shake, animate_static,
    FPS,
)


# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
C = load_palette("buildings")

STEEL      = "#7A8898"
STEEL_DK   = "#6A7888"
STEEL_LT   = "#96A4B4"
BODY_MAIN  = C["body"]         # #46372D
BODY_LIGHT = C["body_light"]   # #524134
RIVET_COL  = C["rivet"]        # #5A4B3C

# Conveyor-like track colors
CONV_BASE  = C["conv_base"]    # #3D3D43
CONV_MID   = C["conv_mid"]     # #505256
CONV_GROOVE = C["conv_groove"] # #5A5C62
CONV_LIGHT = C["conv_light"]   # #6C6D6F

# Dark interior
CHAMBER      = C["chamber"]       # #160F0C
CHAMBER_DEEP = C["chamber_deep"]  # #0F0A08

# Accents
ACCENT_YELLOW = C["conv_yellow"]  # #D2B937
SHADOW        = C["shadow"]       # #231C16


# ---------------------------------------------------------------------------
# Custom mesh: generate_arch_portal
# ---------------------------------------------------------------------------
def generate_arch_portal(width=0.4, depth=0.075, height=0.25, arch_segments=8,
                         wall_thickness=0.04, hex_outer="#7A8898",
                         hex_inner="#0F0A08"):
    """Generate an arch-shaped portal frame (like a tunnel entrance).

    The arch faces along the Y axis. The opening is on the -Y side.
    Origin is at bottom center.

    Uses a simple approach: build outer and inner profile rings, then
    connect them with quads for the frame's front/back/outer/inner surfaces.

    Args:
        width: Total width of the arch.
        depth: Depth (thickness) of the arch frame.
        height: Height of the straight walls before the arch curves.
        arch_segments: Number of segments in the semicircular arch.
        wall_thickness: Thickness of the arch frame walls.
        hex_outer: Color of the outer frame.
        hex_inner: Color of the dark interior void.

    Returns:
        Tuple of (frame_obj, void_obj).
    """
    bm = bmesh.new()
    hw = width / 2
    hd = depth / 2
    arch_radius = hw

    inner_hw = hw - wall_thickness
    inner_radius = inner_hw

    # Build profile points for the outer and inner arch outlines.
    # These trace the arch shape as (x, z) pairs from left-bottom,
    # up the left wall, across the arch, down the right wall.
    def make_profile(half_w, radius, h):
        pts = []
        pts.append((-half_w, 0))
        pts.append((-half_w, h))
        for i in range(arch_segments + 1):
            angle = math.pi - (i / arch_segments) * math.pi
            x = radius * math.cos(angle)
            z = h + radius * math.sin(angle)
            pts.append((x, z))
        pts.append((half_w, 0))
        return pts

    outer_pts = make_profile(hw, arch_radius, height)
    inner_pts = make_profile(inner_hw, inner_radius, height)
    n = len(outer_pts)  # same count for both

    # Create 4 vertex rings: outer-front, outer-back, inner-front, inner-back
    of = [bm.verts.new((x, -hd, z)) for x, z in outer_pts]
    ob = [bm.verts.new((x,  hd, z)) for x, z in outer_pts]
    inf_ = [bm.verts.new((x, -hd, z)) for x, z in inner_pts]
    inb = [bm.verts.new((x,  hd, z)) for x, z in inner_pts]
    bm.verts.ensure_lookup_table()

    # Outer surface quads (of[i] -> of[i+1] -> ob[i+1] -> ob[i])
    for i in range(n - 1):
        bm.faces.new([of[i], of[i+1], ob[i+1], ob[i]])

    # Inner surface quads (reversed winding)
    for i in range(n - 1):
        bm.faces.new([inf_[i], inb[i], inb[i+1], inf_[i+1]])

    # Front cap: connect outer-front to inner-front with quads
    for i in range(n - 1):
        bm.faces.new([of[i+1], of[i], inf_[i], inf_[i+1]])

    # Back cap: connect outer-back to inner-back (reversed winding)
    for i in range(n - 1):
        bm.faces.new([ob[i], ob[i+1], inb[i+1], inb[i]])

    # Bottom face (floor between the two bottom edges)
    bm.faces.new([of[0], ob[0], inb[0], inf_[0]])      # left bottom
    bm.faces.new([of[-1], inf_[-1], inb[-1], ob[-1]])   # right bottom

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("ArchPortal")
    bm.to_mesh(mesh)
    bm.free()
    mesh.validate()

    frame = bpy.data.objects.new("ArchPortal", mesh)
    bpy.context.scene.collection.objects.link(frame)

    mat = create_flat_material("ArchFrameMat", hex_outer)
    frame.data.materials.append(mat)

    for poly in frame.data.polygons:
        poly.use_smooth = False

    # Create a dark void plane inside the arch to show the "tunnel interior"
    # Simple flat polygon at Y=0 using the inner profile shape
    bm2 = bmesh.new()
    void_verts = [bm2.verts.new((x, 0, z)) for x, z in inner_pts]
    bm2.verts.ensure_lookup_table()
    if len(void_verts) >= 3:
        try:
            bm2.faces.new(void_verts)
        except ValueError:
            # Fall back: create a simple rectangle for the void
            bm2.free()
            bm2 = bmesh.new()
            v0 = bm2.verts.new((-inner_hw, 0, 0))
            v1 = bm2.verts.new((inner_hw, 0, 0))
            v2 = bm2.verts.new((inner_hw, 0, height + inner_radius))
            v3 = bm2.verts.new((-inner_hw, 0, height + inner_radius))
            bm2.verts.ensure_lookup_table()
            bm2.faces.new([v0, v1, v2, v3])

    bmesh.ops.recalc_face_normals(bm2, faces=bm2.faces[:])
    void_mesh = bpy.data.meshes.new("ArchVoid")
    bm2.to_mesh(void_mesh)
    bm2.free()
    void_mesh.validate()

    void_obj = bpy.data.objects.new("ArchVoid", void_mesh)
    bpy.context.scene.collection.objects.link(void_obj)

    void_mat = create_flat_material("ArchVoidMat", hex_inner)
    void_obj.data.materials.append(void_mat)

    for poly in void_obj.data.polygons:
        poly.use_smooth = False

    return frame, void_obj


# ---------------------------------------------------------------------------
# Generate a cross-channel track (for junction)
# ---------------------------------------------------------------------------
def generate_channel_track(length=1.0, width=0.2, depth=0.03,
                           hex_base="#3D3D43", hex_rail="#5A5C62"):
    """Generate a recessed channel track for items to travel along.

    The track runs along the Y axis centered at origin.
    It has a recessed base and raised rail edges.

    Args:
        length: Track length (Y axis).
        width: Track width (X axis).
        depth: How deep the channel is recessed.
        hex_base: Channel floor color.
        hex_rail: Rail edge color.

    Returns:
        Tuple of (channel_base, rail_left, rail_right).
    """
    rail_width = 0.03
    rail_height = 0.02

    # Channel base (recessed surface)
    channel = generate_box(w=width - rail_width * 2, d=length, h=depth,
                           hex_color=hex_base)
    channel.name = "ChannelBase"

    # Left rail
    rail_l = generate_box(w=rail_width, d=length, h=depth + rail_height,
                          hex_color=hex_rail)
    rail_l.name = "RailLeft"
    rail_l.location = (-(width / 2 - rail_width / 2), 0, 0)

    # Right rail
    rail_r = generate_box(w=rail_width, d=length, h=depth + rail_height,
                          hex_color=hex_rail)
    rail_r.name = "RailRight"
    rail_r.location = ((width / 2 - rail_width / 2), 0, 0)

    return channel, rail_l, rail_r


# ===========================================================================
# JUNCTION
# ===========================================================================
def build_junction():
    """Build the Junction 4-way crossover building."""
    clear_scene()

    root = bpy.data.objects.new("Junction", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.25
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # ── BASE PLATFORM ─────────────────────────────────────────────────
    # Low profile square platform
    base = add(generate_box(w=1.0, d=1.0, h=0.04, hex_color=STEEL_DK))
    base.name = "BasePlatform"

    # Slightly raised edge frame around the platform
    for side_i, (sx, sy, sw, sd) in enumerate([
        (0, -0.475, 1.0, 0.05),   # front edge
        (0, 0.475, 1.0, 0.05),    # back edge
        (-0.475, 0, 0.05, 0.9),   # left edge
        (0.475, 0, 0.05, 0.9),    # right edge
    ]):
        edge = add(generate_box(w=sw, d=sd, h=0.07, hex_color=STEEL))
        edge.name = f"PlatformEdge_{side_i}"
        edge.location = (sx, sy, 0)

    # ── CHANNEL TRACKS (X-shaped crossing) ────────────────────────────
    # Track running along Y axis (north-south)
    track_ns_base = add(generate_box(w=0.18, d=1.0, h=0.02, hex_color=CONV_BASE))
    track_ns_base.name = "TrackNS_Base"
    track_ns_base.location = (0, 0, 0.04)

    # Rails for NS track
    for ri, rx in enumerate([-0.105, 0.105]):
        rail = add(generate_box(w=0.03, d=1.0, h=0.04, hex_color=CONV_GROOVE))
        rail.name = f"TrackNS_Rail_{ri}"
        rail.location = (rx, 0, 0.04)

    # Track running along X axis (east-west)
    track_ew_base = add(generate_box(w=1.0, d=0.18, h=0.02, hex_color=CONV_BASE))
    track_ew_base.name = "TrackEW_Base"
    track_ew_base.location = (0, 0, 0.04)

    # Rails for EW track
    for ri, ry in enumerate([-0.105, 0.105]):
        rail = add(generate_box(w=1.0, d=0.03, h=0.04, hex_color=CONV_GROOVE))
        rail.name = f"TrackEW_Rail_{ri}"
        rail.location = (0, ry, 0.04)

    # ── CENTER HUB ────────────────────────────────────────────────────
    # Raised octagonal-ish hub where tracks cross
    hub = add(generate_cylinder(radius=0.14, height=0.06, segments=8,
                                hex_color=STEEL_LT))
    hub.name = "CenterHub"
    hub.location = (0, 0, 0.04)

    # Hub cap - slightly smaller, darker
    hub_cap = add(generate_cylinder(radius=0.11, height=0.02, segments=8,
                                    hex_color=CONV_MID))
    hub_cap.name = "HubCap"
    hub_cap.location = (0, 0, 0.10)

    # Small center bolt on hub
    center_bolt = add(generate_bolt(head_radius=0.03, head_height=0.015,
                                    hex_color=RIVET_COL))
    center_bolt.name = "CenterBolt"
    center_bolt.location = (0, 0, 0.12)

    # ── CORNER REINFORCEMENT PLATES ───────────────────────────────────
    for ci, (cx, cy) in enumerate([(-0.35, -0.35), (0.35, -0.35),
                                    (0.35, 0.35), (-0.35, 0.35)]):
        plate = add(generate_box(w=0.175, d=0.175, h=0.05, hex_color=BODY_MAIN))
        plate.name = f"CornerPlate_{ci}"
        plate.location = (cx, cy, 0.04)

        # Corner bolt
        bolt = add(generate_bolt(head_radius=0.02, head_height=0.0125,
                                 hex_color=RIVET_COL))
        bolt.name = f"CornerBolt_{ci}"
        bolt.location = (cx, cy, 0.09)

    # ── DIRECTIONAL ARROWS (subtle accent marks on tracks) ────────────
    # Small yellow accent marks near track ends to show direction
    for ai, (ax, ay, rot) in enumerate([
        (0, -0.375, 0),           # south arrow (NS track)
        (0, 0.375, math.pi),      # north arrow (NS track)
        (-0.375, 0, math.pi/2),   # west arrow (EW track)
        (0.375, 0, -math.pi/2),   # east arrow (EW track)
    ]):
        arrow = add(generate_box(w=0.04, d=0.06, h=0.01, hex_color=ACCENT_YELLOW))
        arrow.name = f"Arrow_{ai}"
        arrow.location = (ax, ay, 0.06)
        arrow.rotation_euler = (0, 0, rot)

    # ── EDGE BOLTS ────────────────────────────────────────────────────
    bolt_positions = [
        (-0.425, -0.425, 0.07), (0.425, -0.425, 0.07),
        (-0.425, 0.425, 0.07), (0.425, 0.425, 0.07),
        (0, -0.46, 0.07), (0, 0.46, 0.07),
        (-0.46, 0, 0.07), (0.46, 0, 0.07),
    ]
    for bi, (bx, by, bz) in enumerate(bolt_positions):
        b = add(generate_bolt(head_radius=0.0175, head_height=0.01,
                              hex_color=RIVET_COL))
        b.name = f"EdgeBolt_{bi}"
        b.location = (bx, by, bz)

    # ── RAISED GUIDE ARCHES (vertical profile for silhouette) ────────
    # Two crossing arch frames over the tracks to make the junction
    # visually distinctive from a flat floor tile
    arch_h = 0.25  # total arch height above platform
    arch_w = 0.05  # arch beam width
    arch_d = 0.04  # arch beam depth

    # NS arch: two uprights + crossbar along Y axis
    for ui, ux in enumerate([-0.15, 0.15]):
        upright = add(generate_box(w=arch_w, d=arch_d, h=arch_h,
                                   hex_color=STEEL))
        upright.name = f"ArchNS_Upright_{ui}"
        upright.location = (ux, 0, 0.07)

    crossbar_ns = add(generate_box(w=0.35, d=arch_d, h=arch_w,
                                   hex_color=STEEL_LT))
    crossbar_ns.name = "ArchNS_Crossbar"
    crossbar_ns.location = (0, 0, 0.07 + arch_h)

    # EW arch: two uprights + crossbar along X axis
    for ui, uy in enumerate([-0.15, 0.15]):
        upright = add(generate_box(w=arch_d, d=arch_w, h=arch_h,
                                   hex_color=STEEL))
        upright.name = f"ArchEW_Upright_{ui}"
        upright.location = (0, uy, 0.07)

    crossbar_ew = add(generate_box(w=arch_d, d=0.35, h=arch_w,
                                   hex_color=STEEL_LT))
    crossbar_ew.name = "ArchEW_Crossbar"
    crossbar_ew.location = (0, 0, 0.07 + arch_h)

    # Top cap where the two arches cross
    arch_cap = add(generate_cylinder(radius=0.06, height=0.03, segments=8,
                                     hex_color=ACCENT_YELLOW))
    arch_cap.name = "ArchCap"
    arch_cap.location = (0, 0, 0.07 + arch_h + arch_w)

    return {
        "root": root,
        "hub": hub,
        "hub_cap": hub_cap,
        "arch_cap": arch_cap,
    }


def bake_junction_animations(objects):
    """Bake NLA animations for the junction."""
    hub = objects["hub"]
    hub_cap = objects["hub_cap"]
    arch_cap = objects["arch_cap"]

    # idle (2s): Static
    animate_static(hub, "idle", duration=2.0)
    animate_static(hub_cap, "idle", duration=2.0)
    animate_static(arch_cap, "idle", duration=2.0)

    # active (2s): Center hub vibrates to show items crossing
    animate_shake(hub, "active", duration=2.0, amplitude=0.004, frequency=10)
    animate_shake(hub_cap, "active", duration=2.0, amplitude=0.004, frequency=10)
    animate_shake(arch_cap, "active", duration=2.0, amplitude=0.0025, frequency=10)


def apply_junction_textures():
    """Apply PBR textures to junction objects."""
    for obj in bpy.data.objects:
        name = obj.name
        if name == "BasePlatform":
            apply_texture(obj, "metal_plate_02", resolution="1k")
        elif name.startswith("PlatformEdge_"):
            apply_texture(obj, "metal_plate", resolution="1k")
        elif name.startswith("TrackNS_Base") or name.startswith("TrackEW_Base"):
            apply_texture(obj, "metal_plate_02", resolution="1k")
        elif name.startswith("CornerPlate_"):
            apply_texture(obj, "painted_metal_shutter", resolution="1k")
        elif name == "CenterHub":
            apply_texture(obj, "metal_plate", resolution="1k")


# ===========================================================================
# TUNNEL
# ===========================================================================
def build_tunnel():
    """Build the Tunnel underground passage building."""
    clear_scene()

    root = bpy.data.objects.new("Tunnel", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.25
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # ── BASE PLATFORM ─────────────────────────────────────────────────
    # Sturdy ground-level slab
    base = add(generate_box(w=1.0, d=1.0, h=0.05, hex_color=STEEL_DK))
    base.name = "BasePlatform"

    # ── COVER PLATE (center) ──────────────────────────────────────────
    # The flat plate that covers the underground passage
    # Runs between the two portals
    cover = add(generate_box(w=0.7, d=0.6, h=0.04, hex_color=STEEL))
    cover.name = "CoverPlate"
    cover.location = (0, 0, 0.05)

    # Reinforcement strips across the cover plate
    for si, sy in enumerate([-0.15, 0.0, 0.15]):
        strip = add(generate_box(w=0.75, d=0.04, h=0.02, hex_color=STEEL_LT))
        strip.name = f"CoverStrip_{si}"
        strip.location = (0, sy, 0.09)

    # ── ENTRANCE PORTAL (front, -Y) ──────────────────────────────────
    # Arch frame -- taller walls (0.125) for more dramatic openings
    portal_front, void_front = generate_arch_portal(
        width=0.5, depth=0.10, height=0.125, arch_segments=8,
        wall_thickness=0.05, hex_outer=STEEL, hex_inner=CHAMBER_DEEP)
    portal_front.name = "PortalFront"
    void_front.name = "VoidFront"
    portal_front.location = (0, -0.35, 0.05)
    void_front.location = (0, -0.35, 0.05)
    add(portal_front)
    add(void_front)

    # Front portal reinforcement - heavy frame pieces on sides
    for ri, rx in enumerate([-0.275, 0.275]):
        post = add(generate_box(w=0.07, d=0.11, h=0.30, hex_color=BODY_MAIN))
        post.name = f"FrontPost_{ri}"
        post.location = (rx, -0.35, 0.05)

    # Front portal top beam
    top_beam_f = add(generate_box(w=0.6, d=0.11, h=0.06, hex_color=BODY_LIGHT))
    top_beam_f.name = "FrontTopBeam"
    top_beam_f.location = (0, -0.35, 0.325)

    # ── EXIT PORTAL (back, +Y) ───────────────────────────────────────
    portal_back, void_back = generate_arch_portal(
        width=0.5, depth=0.10, height=0.125, arch_segments=8,
        wall_thickness=0.05, hex_outer=STEEL, hex_inner=CHAMBER_DEEP)
    portal_back.name = "PortalBack"
    void_back.name = "VoidBack"
    portal_back.location = (0, 0.35, 0.05)
    portal_back.rotation_euler = (0, 0, math.pi)  # face opposite direction
    void_back.location = (0, 0.35, 0.05)
    void_back.rotation_euler = (0, 0, math.pi)
    add(portal_back)
    add(void_back)

    # Back portal reinforcement posts
    for ri, rx in enumerate([-0.275, 0.275]):
        post = add(generate_box(w=0.07, d=0.11, h=0.30, hex_color=BODY_MAIN))
        post.name = f"BackPost_{ri}"
        post.location = (rx, 0.35, 0.05)

    # Back portal top beam
    top_beam_b = add(generate_box(w=0.6, d=0.11, h=0.06, hex_color=BODY_LIGHT))
    top_beam_b.name = "BackTopBeam"
    top_beam_b.location = (0, 0.35, 0.325)

    # ── SIDE WALLS ────────────────────────────────────────────────────
    # Low walls connecting the two portals (makes it look solid/protective)
    for wi, wx in enumerate([-0.375, 0.375]):
        wall = add(generate_box(w=0.05, d=0.6, h=0.175, hex_color=BODY_MAIN))
        wall.name = f"SideWall_{wi}"
        wall.location = (wx, 0, 0.05)

    # ── HAZARD STRIPES on portal tops ─────────────────────────────────
    for hi, hy in enumerate([-0.35, 0.35]):
        stripe = add(generate_box(w=0.55, d=0.03, h=0.015, hex_color=ACCENT_YELLOW))
        stripe.name = f"HazardStripe_{hi}"
        stripe.location = (0, hy, 0.385)

    # ── BOLTS scattered for industrial detail ─────────────────────────
    bolt_positions = [
        # Cover plate bolts
        (-0.275, -0.15, 0.11), (0.275, -0.15, 0.11),
        (-0.275, 0.15, 0.11), (0.275, 0.15, 0.11),
        # Front portal bolts
        (-0.275, -0.42, 0.20), (0.275, -0.42, 0.20),
        # Back portal bolts
        (-0.275, 0.42, 0.20), (0.275, 0.42, 0.20),
        # Side wall bolts
        (-0.40, -0.2, 0.15), (-0.40, 0.2, 0.15),
        (0.40, -0.2, 0.15), (0.40, 0.2, 0.15),
    ]
    for bi, (bx, by, bz) in enumerate(bolt_positions):
        b = add(generate_bolt(head_radius=0.02, head_height=0.0125,
                              hex_color=RIVET_COL))
        b.name = f"Bolt_{bi}"
        b.location = (bx, by, bz)

    # ── GRATE DETAIL on cover plate ───────────────────────────────────
    # Small grate strips to suggest ventilation / underground visibility
    for gi, gx in enumerate([-0.15, 0.0, 0.15]):
        grate = add(generate_box(w=0.03, d=0.4, h=0.01, hex_color=C["grate"]))
        grate.name = f"Grate_{gi}"
        grate.location = (gx, 0, 0.09)

    return {
        "root": root,
        "portal_front": portal_front,
        "portal_back": portal_back,
        "top_beam_f": top_beam_f,
        "top_beam_b": top_beam_b,
    }


def bake_tunnel_animations(objects):
    """Bake NLA animations for the tunnel."""
    portal_f = objects["portal_front"]
    portal_b = objects["portal_back"]
    beam_f = objects["top_beam_f"]
    beam_b = objects["top_beam_b"]

    # idle (2s): Static
    animate_static(portal_f, "idle", duration=2.0)
    animate_static(portal_b, "idle", duration=2.0)
    animate_static(beam_f, "idle", duration=2.0)
    animate_static(beam_b, "idle", duration=2.0)

    # active (2s): Subtle portal frame vibration (items moving through)
    animate_shake(portal_f, "active", duration=2.0, amplitude=0.003, frequency=12)
    animate_shake(portal_b, "active", duration=2.0, amplitude=0.003, frequency=12)
    animate_shake(beam_f, "active", duration=2.0, amplitude=0.003, frequency=12)
    animate_shake(beam_b, "active", duration=2.0, amplitude=0.003, frequency=12)


def apply_tunnel_textures():
    """Apply PBR textures to tunnel objects."""
    for obj in bpy.data.objects:
        name = obj.name
        if name == "BasePlatform":
            apply_texture(obj, "metal_plate_02", resolution="1k")
        elif name == "CoverPlate":
            apply_texture(obj, "metal_plate", resolution="1k")
        elif name.startswith("CoverStrip_"):
            apply_texture(obj, "metal_plate", resolution="1k")
        elif name.startswith("Portal"):
            apply_texture(obj, "metal_plate", resolution="1k")
        elif name.startswith("FrontPost_") or name.startswith("BackPost_"):
            apply_texture(obj, "painted_metal_shutter", resolution="1k")
        elif name.startswith("SideWall_"):
            apply_texture(obj, "painted_metal_shutter", resolution="1k")
        elif name.startswith("FrontTopBeam") or name.startswith("BackTopBeam"):
            apply_texture(obj, "metal_plate_02", resolution="1k")


# ===========================================================================
# Main
# ===========================================================================
def main():
    # ── JUNCTION ──────────────────────────────────────────────────────
    junction_dir = os.path.join(REPO_ROOT, "buildings", "junction", "models")

    print("[junction_tunnel] Building Junction...")
    objects = build_junction()
    bake_junction_animations(objects)

    # Export flat version
    flat_glb = os.path.join(junction_dir, "junction_flat.glb")
    export_glb(flat_glb)
    print(f"[junction_tunnel] Junction flat: {flat_glb}")

    # Apply textures and export textured version
    apply_junction_textures()
    tex_glb = os.path.join(junction_dir, "junction.glb")
    export_glb(tex_glb)
    print(f"[junction_tunnel] Junction textured: {tex_glb}")

    # ── TUNNEL ────────────────────────────────────────────────────────
    tunnel_dir = os.path.join(REPO_ROOT, "buildings", "tunnel", "models")

    print("[junction_tunnel] Building Tunnel...")
    objects = build_tunnel()
    bake_tunnel_animations(objects)

    # Export flat version
    flat_glb = os.path.join(tunnel_dir, "tunnel_flat.glb")
    export_glb(flat_glb)
    print(f"[junction_tunnel] Tunnel flat: {flat_glb}")

    # Apply textures and export textured version
    apply_tunnel_textures()
    tex_glb = os.path.join(tunnel_dir, "tunnel.glb")
    export_glb(tex_glb)
    print(f"[junction_tunnel] Tunnel textured: {tex_glb}")

    print("[junction_tunnel] Done!")


if __name__ == "__main__":
    main()
