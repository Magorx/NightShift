"""Export terrain feature 3D models (.glb) for Godot import.

Generates three terrain features:
  - Rock: Natural boulder cluster (blocks building/pathing)
  - Chasm: Dark pit/crack in the ground (impassable gap)
  - Rubble: Scattered debris pile (left when buildings are destroyed)

Each has a flat (palette-colored) and textured (PBR) variant.

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/terrain_models.py
"""

import bpy
import os
import sys
import math
import random

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BLENDER_DIR = os.path.normpath(os.path.join(SCRIPT_DIR, ".."))
REPO_ROOT = os.path.normpath(os.path.join(BLENDER_DIR, "..", ".."))
sys.path.insert(0, BLENDER_DIR)

from export_helpers import export_glb
from render import clear_scene
from materials.pixel_art import create_flat_material
from texture_library import apply_texture
from prefabs_src.sphere import generate_sphere
from prefabs_src.hemisphere import generate_hemisphere
from prefabs_src.box import generate_box
from prefabs_src.cylinder import generate_cylinder
from prefabs_src.cone import generate_cone
from prefabs_src.bolt import generate_bolt
from prefabs_src.pipe import generate_pipe
from prefabs_src.wedge import generate_wedge
from anim_helpers import animate_static, FPS

OUTPUT_DIR = os.path.join(REPO_ROOT, "terrain", "models")

# Deterministic randomness for reproducible builds
random.seed(42)


# ---------------------------------------------------------------------------
# Rock colors
# ---------------------------------------------------------------------------
ROCK_BASE   = "#808080"
ROCK_DARK   = "#606060"
ROCK_LIGHT  = "#A0A0A0"
ROCK_SHADOW = "#505050"

# Chasm colors
CHASM_VOID    = "#1A1A1A"
CHASM_EDGE    = "#3A3A3A"
CHASM_CRUMBLE = "#5A5A5A"

# Rubble colors (building debris)
RUBBLE_BODY     = "#46372D"
RUBBLE_RIVET    = "#5A4B3C"
RUBBLE_STEEL    = "#7A8898"
RUBBLE_STEEL_DK = "#6A7888"


# ---------------------------------------------------------------------------
# Rock
# ---------------------------------------------------------------------------
def build_rock():
    """Build a natural-looking boulder cluster.

    2-3 rocks of varying sizes using hemispheres and spheres,
    plus angular box shapes for faceted look.
    Footprint ~1.5x1.5, height 0.8-1.2.
    """
    clear_scene()

    root = bpy.data.objects.new("Rock", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # -- Main boulder (large hemisphere) --
    main = add(generate_hemisphere(radius=0.55, rings=4, segments=10,
                                    hex_color=ROCK_BASE))
    main.name = "MainBoulder"
    main.location = (0.0, 0.0, 0.0)
    # Slight tilt for natural look
    main.rotation_euler = (math.radians(8), math.radians(-5), math.radians(15))

    # -- Secondary boulder (medium sphere, partially embedded) --
    sec = add(generate_sphere(radius=0.38, rings=5, segments=8,
                               hex_color=ROCK_DARK))
    sec.name = "SecondBoulder"
    sec.location = (0.45, -0.25, -0.05)
    sec.rotation_euler = (math.radians(20), math.radians(10), math.radians(-30))

    # -- Small rock (hemisphere) --
    small = add(generate_hemisphere(radius=0.22, rings=3, segments=8,
                                     hex_color=ROCK_LIGHT))
    small.name = "SmallRock"
    small.location = (-0.35, 0.35, -0.02)
    small.rotation_euler = (math.radians(-10), math.radians(25), math.radians(45))

    # -- Angular facet blocks for variety --
    facet1 = add(generate_box(w=0.3, d=0.25, h=0.35, hex_color=ROCK_SHADOW))
    facet1.name = "Facet1"
    facet1.location = (0.25, 0.4, -0.05)
    facet1.rotation_euler = (math.radians(15), math.radians(-20), math.radians(35))

    facet2 = add(generate_box(w=0.2, d=0.18, h=0.22, hex_color=ROCK_DARK))
    facet2.name = "Facet2"
    facet2.location = (-0.42, -0.2, 0.0)
    facet2.rotation_euler = (math.radians(-12), math.radians(30), math.radians(-20))

    # -- Tiny pebbles around the base --
    pebble_positions = [
        (0.55, 0.15, -0.02),
        (-0.15, -0.5, -0.02),
        (0.3, -0.5, -0.02),
        (-0.55, 0.05, -0.02),
        (0.0, 0.55, -0.02),
    ]
    for i, (px, py, pz) in enumerate(pebble_positions):
        peb = add(generate_hemisphere(radius=0.08 + random.uniform(-0.02, 0.03),
                                       rings=2, segments=6, hex_color=ROCK_SHADOW))
        peb.name = f"Pebble_{i}"
        peb.location = (px, py, pz)
        peb.rotation_euler = (random.uniform(-0.3, 0.3),
                              random.uniform(-0.3, 0.3),
                              random.uniform(0, math.pi))

    # -- Wedge shard leaning against main boulder --
    shard = add(generate_wedge(w=0.18, d=0.25, h_front=0.0, h_back=0.3,
                                hex_color=ROCK_LIGHT))
    shard.name = "Shard"
    shard.location = (-0.2, -0.35, 0.0)
    shard.rotation_euler = (math.radians(10), math.radians(-15), math.radians(60))

    # -- Ground shadow disc (very flat, dark) --
    ground = add(generate_cylinder(radius=0.75, height=0.02, segments=12,
                                    hex_color=ROCK_SHADOW))
    ground.name = "GroundShadow"
    ground.location = (0.0, 0.0, -0.04)

    # Animate idle (static)
    for obj in root.children:
        animate_static(obj, "idle", duration=2.0)

    return root


# ---------------------------------------------------------------------------
# Chasm
# ---------------------------------------------------------------------------
def build_chasm():
    """Build a dark pit/crack in the ground.

    Rectangular opening with crumbling edges.
    Footprint 2.0x2.0, very low profile.
    """
    clear_scene()

    root = bpy.data.objects.new("Chasm", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # -- The void: a dark recessed flat surface --
    void = add(generate_box(w=1.5, d=1.5, h=0.04, hex_color=CHASM_VOID))
    void.name = "Void"
    void.location = (0, 0, -0.25)

    # -- Frame edges (4 sides) forming the rim --
    # North edge
    n_edge = add(generate_box(w=2.0, d=0.25, h=0.12, hex_color=CHASM_EDGE))
    n_edge.name = "EdgeN"
    n_edge.location = (0, 0.875, -0.06)

    # South edge
    s_edge = add(generate_box(w=2.0, d=0.25, h=0.12, hex_color=CHASM_EDGE))
    s_edge.name = "EdgeS"
    s_edge.location = (0, -0.875, -0.06)

    # East edge
    e_edge = add(generate_box(w=0.25, d=1.5, h=0.12, hex_color=CHASM_EDGE))
    e_edge.name = "EdgeE"
    e_edge.location = (0.875, 0, -0.06)

    # West edge
    w_edge = add(generate_box(w=0.25, d=1.5, h=0.12, hex_color=CHASM_EDGE))
    w_edge.name = "EdgeW"
    w_edge.location = (-0.875, 0, -0.06)

    # -- Crumbling edge debris: irregular small boxes along the rim --
    crumble_positions = [
        # Along north edge
        (-0.5, 0.65, -0.1), (0.2, 0.7, -0.08), (0.6, 0.6, -0.12),
        # Along south edge
        (-0.3, -0.65, -0.1), (0.4, -0.7, -0.08),
        # Along east edge
        (0.65, 0.3, -0.1), (0.7, -0.2, -0.12),
        # Along west edge
        (-0.7, 0.1, -0.1), (-0.65, -0.4, -0.08),
    ]
    for i, (cx, cy, cz) in enumerate(crumble_positions):
        w_size = random.uniform(0.1, 0.2)
        d_size = random.uniform(0.1, 0.2)
        h_size = random.uniform(0.06, 0.12)
        crumb = add(generate_box(w=w_size, d=d_size, h=h_size,
                                  hex_color=CHASM_CRUMBLE))
        crumb.name = f"Crumble_{i}"
        crumb.location = (cx, cy, cz)
        crumb.rotation_euler = (random.uniform(-0.2, 0.2),
                                random.uniform(-0.2, 0.2),
                                random.uniform(0, math.pi))

    # -- Deeper void layers for depth illusion --
    deep1 = add(generate_box(w=1.2, d=1.2, h=0.03, hex_color="#0D0D0D"))
    deep1.name = "DeepVoid1"
    deep1.location = (0, 0, -0.35)

    deep2 = add(generate_box(w=0.8, d=0.8, h=0.03, hex_color="#050505"))
    deep2.name = "DeepVoid2"
    deep2.location = (0, 0, -0.45)

    # -- Wedge ramps on edges (crumbling inward) --
    ramp_data = [
        # (pos, rot, size)
        ((0.55, 0.5, -0.15), (0, 0, math.radians(45)), (0.25, 0.3, 0.15)),
        ((-0.5, -0.55, -0.15), (0, 0, math.radians(-135)), (0.2, 0.25, 0.12)),
        ((0.4, -0.5, -0.13), (0, 0, math.radians(-45)), (0.2, 0.2, 0.1)),
        ((-0.55, 0.3, -0.14), (0, 0, math.radians(135)), (0.22, 0.28, 0.13)),
    ]
    for i, (pos, rot, size) in enumerate(ramp_data):
        ramp = add(generate_wedge(w=size[0], d=size[1], h_front=0.0, h_back=size[2],
                                   hex_color=CHASM_EDGE))
        ramp.name = f"Ramp_{i}"
        ramp.location = pos
        ramp.rotation_euler = rot

    # -- Small rocks teetering on edge --
    for i in range(4):
        angle = i * math.pi / 2 + random.uniform(-0.3, 0.3)
        dist = random.uniform(0.55, 0.7)
        rock = add(generate_hemisphere(radius=random.uniform(0.05, 0.1),
                                        rings=2, segments=6,
                                        hex_color=CHASM_CRUMBLE))
        rock.name = f"EdgeRock_{i}"
        rock.location = (math.cos(angle) * dist, math.sin(angle) * dist,
                         -0.05)
        rock.rotation_euler = (random.uniform(-0.3, 0.3),
                               random.uniform(-0.3, 0.3),
                               random.uniform(0, math.pi))

    # Animate idle (static)
    for obj in root.children:
        animate_static(obj, "idle", duration=2.0)

    return root


# ---------------------------------------------------------------------------
# Rubble
# ---------------------------------------------------------------------------
def build_rubble():
    """Build a scattered debris pile from destroyed buildings.

    Broken boxes, bent pipes, scattered bolts.
    Footprint ~1.5x1.5, height 0.3-0.5 (low pile).
    """
    clear_scene()

    root = bpy.data.objects.new("Rubble", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # -- Ground base (low flat debris bed) --
    base = add(generate_box(w=1.4, d=1.4, h=0.06, hex_color=RUBBLE_BODY))
    base.name = "DebrisBase"
    base.location = (0, 0, 0)

    # -- Broken wall panels (tilted boxes) --
    panel_data = [
        # (w, d, h, color, pos, rot)
        (0.5, 0.08, 0.35, RUBBLE_BODY,
         (0.15, -0.2, 0.08), (math.radians(55), 0, math.radians(20))),
        (0.4, 0.07, 0.25, RUBBLE_RIVET,
         (-0.3, 0.15, 0.05), (math.radians(70), math.radians(10), math.radians(-35))),
        (0.35, 0.06, 0.2, RUBBLE_BODY,
         (0.35, 0.3, 0.04), (math.radians(80), math.radians(-5), math.radians(50))),
    ]
    for i, (pw, pd, ph, pc, pos, rot) in enumerate(panel_data):
        panel = add(generate_box(w=pw, d=pd, h=ph, hex_color=pc, seam_count=1))
        panel.name = f"BrokenPanel_{i}"
        panel.location = pos
        panel.rotation_euler = rot

    # -- Steel beam fragments --
    beam_data = [
        # (w, d, h, color, pos, rot)
        (0.08, 0.08, 0.5, RUBBLE_STEEL,
         (-0.1, -0.35, 0.06), (math.radians(5), math.radians(75), math.radians(15))),
        (0.06, 0.06, 0.35, RUBBLE_STEEL_DK,
         (0.4, -0.1, 0.04), (math.radians(-10), math.radians(80), math.radians(-40))),
        (0.07, 0.07, 0.3, RUBBLE_STEEL,
         (-0.35, -0.15, 0.08), (math.radians(15), math.radians(60), math.radians(70))),
    ]
    for i, (bw, bd, bh, bc, pos, rot) in enumerate(beam_data):
        beam = add(generate_box(w=bw, d=bd, h=bh, hex_color=bc))
        beam.name = f"Beam_{i}"
        beam.location = pos
        beam.rotation_euler = rot

    # -- Bent pipe sections --
    pipe1 = add(generate_pipe(length=0.35, radius=0.06, wall_thickness=0.015,
                               hex_color=RUBBLE_STEEL))
    pipe1.name = "BentPipe_0"
    pipe1.location = (0.25, 0.25, 0.1)
    pipe1.rotation_euler = (math.radians(30), math.radians(45), math.radians(-15))

    pipe2 = add(generate_pipe(length=0.25, radius=0.05, wall_thickness=0.012,
                               hex_color=RUBBLE_STEEL_DK))
    pipe2.name = "BentPipe_1"
    pipe2.location = (-0.4, 0.35, 0.06)
    pipe2.rotation_euler = (math.radians(-20), math.radians(60), math.radians(40))

    # -- Cylinder fragments (broken column sections) --
    cyl1 = add(generate_cylinder(radius=0.1, height=0.2, segments=8,
                                  hex_color=RUBBLE_RIVET))
    cyl1.name = "CylFrag_0"
    cyl1.location = (-0.2, 0.4, 0.04)
    cyl1.rotation_euler = (math.radians(80), 0, math.radians(25))

    cyl2 = add(generate_cylinder(radius=0.08, height=0.15, segments=8,
                                  hex_color=RUBBLE_STEEL))
    cyl2.name = "CylFrag_1"
    cyl2.location = (0.45, 0.0, 0.03)
    cyl2.rotation_euler = (math.radians(85), math.radians(10), math.radians(-60))

    # -- Scattered bolts --
    bolt_positions = [
        (0.0, -0.45, 0.07),
        (-0.45, -0.3, 0.06),
        (0.35, 0.45, 0.06),
        (0.5, -0.35, 0.07),
        (-0.1, 0.5, 0.06),
        (0.2, -0.5, 0.06),
    ]
    for i, (bx, by, bz) in enumerate(bolt_positions):
        bolt = add(generate_bolt(head_radius=0.04, head_height=0.025,
                                  hex_color=RUBBLE_RIVET))
        bolt.name = f"Bolt_{i}"
        bolt.location = (bx, by, bz)
        bolt.rotation_euler = (random.uniform(-0.5, 0.5),
                               random.uniform(-0.5, 0.5),
                               random.uniform(0, math.pi * 2))

    # -- Small debris chunks (tiny boxes at random angles) --
    chunk_data = [
        ((-0.5, 0.1, 0.04), RUBBLE_BODY),
        ((0.1, 0.45, 0.04), RUBBLE_RIVET),
        ((-0.15, -0.5, 0.04), RUBBLE_STEEL_DK),
        ((0.5, 0.2, 0.03), RUBBLE_BODY),
        ((-0.4, -0.45, 0.03), RUBBLE_RIVET),
        ((0.0, 0.0, 0.08), RUBBLE_STEEL),
        ((0.2, 0.15, 0.1), RUBBLE_BODY),
    ]
    for i, (pos, color) in enumerate(chunk_data):
        size = random.uniform(0.06, 0.14)
        chunk = add(generate_box(w=size, d=size * random.uniform(0.6, 1.4),
                                  h=size * random.uniform(0.5, 1.0),
                                  hex_color=color))
        chunk.name = f"Chunk_{i}"
        chunk.location = pos
        chunk.rotation_euler = (random.uniform(-0.4, 0.4),
                                random.uniform(-0.4, 0.4),
                                random.uniform(0, math.pi * 2))

    # -- Cone tip (broken exhaust) --
    cone = add(generate_cone(radius_bottom=0.1, radius_top=0.03, height=0.18,
                              segments=6, hex_color=RUBBLE_STEEL_DK))
    cone.name = "BrokenCone"
    cone.location = (-0.3, -0.05, 0.06)
    cone.rotation_euler = (math.radians(70), math.radians(15), math.radians(-50))

    # -- Wedge fragment (broken ramp/bracket) --
    wedge = add(generate_wedge(w=0.2, d=0.15, h_front=0.0, h_back=0.12,
                                hex_color=RUBBLE_STEEL))
    wedge.name = "WedgeFrag"
    wedge.location = (0.3, -0.35, 0.05)
    wedge.rotation_euler = (math.radians(5), math.radians(10), math.radians(-25))

    # Animate idle (static)
    for obj in root.children:
        animate_static(obj, "idle", duration=2.0)

    return root


# ---------------------------------------------------------------------------
# Apply textures to all children of a root object
# ---------------------------------------------------------------------------
def apply_textures_to_model(root, texture_map):
    """Apply PBR textures to objects by name prefix.

    Args:
        root: Root empty object.
        texture_map: List of (name_prefix, texture_id) tuples.
    """
    for obj in root.children:
        for prefix, tex_id in texture_map:
            if obj.name.startswith(prefix):
                try:
                    apply_texture(obj, tex_id, resolution="1k")
                except Exception as e:
                    print(f"[terrain] Warning: texture '{tex_id}' failed "
                          f"for {obj.name}: {e}")
                break


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    print("[terrain_models] Starting terrain feature generation...")

    # ======================================================================
    # ROCK
    # ======================================================================
    random.seed(42)

    # -- Flat version --
    print("[terrain_models] Building rock (flat)...")
    build_rock()
    flat_path = os.path.join(OUTPUT_DIR, "rock_flat.glb")
    export_glb(flat_path)

    print(f"[terrain_models] Exported: {flat_path}")

    # -- Textured version --
    print("[terrain_models] Building rock (textured)...")
    random.seed(42)  # Reset seed for identical geometry
    root = build_rock()
    rock_textures = [
        ("MainBoulder", "rock_06"),
        ("SecondBoulder", "rock_06"),
        ("SmallRock", "rock_06"),
        ("Facet", "rock_06"),
        ("Pebble", "rock_06"),
        ("Shard", "rock_06"),
        ("GroundShadow", "brown_mud"),
    ]
    apply_textures_to_model(root, rock_textures)
    tex_path = os.path.join(OUTPUT_DIR, "rock.glb")
    export_glb(tex_path)

    print(f"[terrain_models] Exported: {tex_path}")

    # ======================================================================
    # CHASM
    # ======================================================================
    random.seed(123)

    # -- Flat version --
    print("[terrain_models] Building chasm (flat)...")
    build_chasm()
    flat_path = os.path.join(OUTPUT_DIR, "chasm_flat.glb")
    export_glb(flat_path)

    print(f"[terrain_models] Exported: {flat_path}")

    # -- Textured version --
    print("[terrain_models] Building chasm (textured)...")
    random.seed(123)
    root = build_chasm()
    chasm_textures = [
        ("Void", "rock_06"),
        ("Edge", "rock_06"),
        ("Crumble", "rock_06"),
        ("DeepVoid", "rock_06"),
        ("Ramp", "rock_06"),
        ("EdgeRock", "rock_06"),
    ]
    apply_textures_to_model(root, chasm_textures)
    tex_path = os.path.join(OUTPUT_DIR, "chasm.glb")
    export_glb(tex_path)

    print(f"[terrain_models] Exported: {tex_path}")

    # ======================================================================
    # RUBBLE
    # ======================================================================
    random.seed(456)

    # -- Flat version --
    print("[terrain_models] Building rubble (flat)...")
    build_rubble()
    flat_path = os.path.join(OUTPUT_DIR, "rubble_flat.glb")
    export_glb(flat_path)

    print(f"[terrain_models] Exported: {flat_path}")

    # -- Textured version --
    print("[terrain_models] Building rubble (textured)...")
    random.seed(456)
    root = build_rubble()
    rubble_textures = [
        ("DebrisBase", "brown_mud"),
        ("BrokenPanel", "painted_metal_shutter"),
        ("Beam", "metal_plate"),
        ("BentPipe", "rusty_metal_02"),
        ("CylFrag", "metal_plate"),
        ("Bolt", "metal_plate"),
        ("Chunk", "rusty_metal_02"),
        ("BrokenCone", "corrugated_iron"),
        ("WedgeFrag", "metal_plate"),
    ]
    apply_textures_to_model(root, rubble_textures)
    tex_path = os.path.join(OUTPUT_DIR, "rubble.glb")
    export_glb(tex_path)

    print(f"[terrain_models] Exported: {tex_path}")

    print("[terrain_models] All terrain features complete!")


if __name__ == "__main__":
    main()
