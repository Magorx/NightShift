"""Generate 3D item models for the 6 elemental resources.

Each item is tiny (0.2-0.3 Blender units) and carried on conveyor belts.
Differentiated primarily by color, secondarily by silhouette.

Items:
  1. Pyromite (fire)    - jagged flame cones, orange/red
  2. Crystalline (ice)  - hexagonal prism, blue
  3. Biovine (nature)   - rounded blob/seed, green
  4. Voltite (lightning) - angular bolt/shard, yellow
  5. Umbrite (shadow)   - dark orb, purple
  6. Resonite (force)   - octahedron/diamond, silver

Each has a slow idle rotation animation (1 full Z rotation over 2 seconds).

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/item_models.py
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
from prefabs_src.cone import generate_cone
from prefabs_src.cylinder import generate_cylinder
from prefabs_src.sphere import generate_sphere
from prefabs_src.hemisphere import generate_hemisphere
from prefabs_src.crystal import generate_crystal
from prefabs_src.box import generate_box
from anim_helpers import animate_rotation, FPS

# Load element palette
E = load_palette("elements")

OUTPUT_DIR = os.path.join(REPO_ROOT, "resources", "items", "models")


def export_item(name):
    """Export both textured and flat versions."""
    base_path = os.path.join(OUTPUT_DIR, f"{name}_item")
    # For tiny items, flat and textured are identical
    export_glb(base_path + ".glb")
    # Re-export as flat (same thing for items this small)
    export_glb(base_path + "_flat.glb")
    print(f"[item_models] Exported: {name}")


# ---------------------------------------------------------------------------
# Animation helper
# ---------------------------------------------------------------------------
def add_idle_rotation(obj):
    """Add slow Z-axis rotation: 1 full turn over 2 seconds."""
    animate_rotation(obj, "idle", duration=2.0, axis='Z',
                     total_angle=math.pi * 2)


# ---------------------------------------------------------------------------
# 1. Pyromite (fire) - jagged flame cones
# ---------------------------------------------------------------------------
def build_pyromite():
    """Cluster of small upward-pointing flame cones on a disc base."""
    clear_scene()

    root = bpy.data.objects.new("Pyromite", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.1
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # Base disc
    base = add(generate_cylinder(radius=0.09, height=0.03, segments=8,
                                 hex_color=E["pyro_dark"]))
    base.name = "PyroBase"

    # Central large flame cone
    c1 = add(generate_cone(radius_bottom=0.06, radius_top=0.0, height=0.2,
                           segments=6, hex_color=E["pyro_base"]))
    c1.name = "FlameMain"
    c1.location = (0, 0, 0.03)

    # Secondary flame - tilted left
    c2 = add(generate_cone(radius_bottom=0.04, radius_top=0.0, height=0.15,
                           segments=6, hex_color=E["pyro_hi"]))
    c2.name = "FlameLeft"
    c2.location = (-0.04, 0.01, 0.03)
    c2.rotation_euler = (0.2, -0.25, 0)

    # Tertiary flame - tilted right
    c3 = add(generate_cone(radius_bottom=0.035, radius_top=0.0, height=0.12,
                           segments=6, hex_color=E["pyro_hi"]))
    c3.name = "FlameRight"
    c3.location = (0.035, -0.02, 0.03)
    c3.rotation_euler = (-0.15, 0.3, 0)

    # Small accent flame behind
    c4 = add(generate_cone(radius_bottom=0.03, radius_top=0.0, height=0.1,
                           segments=5, hex_color=E["pyro_glow"]))
    c4.name = "FlameBack"
    c4.location = (0.01, 0.04, 0.03)
    c4.rotation_euler = (0.3, 0.1, 0)

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# 2. Crystalline (ice) - hexagonal prism
# ---------------------------------------------------------------------------
def build_crystalline():
    """Single hexagonal crystal with a pointed tip."""
    clear_scene()

    root = bpy.data.objects.new("Crystalline", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.1
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # Main crystal - single tall hex prism with tip
    crystal = add(generate_crystal(
        num_crystals=1,
        base_radius=0.06,
        base_height=0.12,
        tip_ratio=0.5,
        spread=0.0,
        seed=42,
        hex_color=E["cryst_base"],
    ))
    crystal.name = "CrystalMain"

    # Smaller secondary crystal leaning out
    crystal2 = add(generate_crystal(
        num_crystals=1,
        base_radius=0.035,
        base_height=0.08,
        tip_ratio=0.4,
        spread=0.0,
        seed=7,
        hex_color=E["cryst_hi"],
    ))
    crystal2.name = "CrystalSmall"
    crystal2.location = (0.05, -0.02, 0)
    crystal2.rotation_euler = (0.1, 0.3, 0)

    # Tiny accent crystal
    crystal3 = add(generate_crystal(
        num_crystals=1,
        base_radius=0.025,
        base_height=0.05,
        tip_ratio=0.3,
        spread=0.0,
        seed=13,
        hex_color=E["cryst_dark"],
    ))
    crystal3.name = "CrystalTiny"
    crystal3.location = (-0.04, 0.03, 0)
    crystal3.rotation_euler = (-0.15, -0.2, 0)

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# 3. Biovine (nature) - rounded blob/seed
# ---------------------------------------------------------------------------
def build_biovine():
    """Organic seed shape: hemisphere base with a sphere top."""
    clear_scene()

    root = bpy.data.objects.new("Biovine", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.1
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # Fat base hemisphere
    base = add(generate_hemisphere(radius=0.1, rings=4, segments=10,
                                   hex_color=E["bio_dark"]))
    base.name = "SeedBase"

    # Main body sphere sitting on the hemisphere
    body = add(generate_sphere(radius=0.09, rings=5, segments=10,
                               hex_color=E["bio_base"]))
    body.name = "SeedBody"
    body.location = (0, 0, 0.06)

    # Small highlight bump on top
    bump = add(generate_sphere(radius=0.04, rings=3, segments=8,
                               hex_color=E["bio_hi"]))
    bump.name = "SeedBump"
    bump.location = (0.02, -0.01, 0.13)

    # Tiny tendril/sprout using a thin cone
    sprout = add(generate_cone(radius_bottom=0.015, radius_top=0.005,
                               height=0.06, segments=5,
                               hex_color=E["bio_hi"]))
    sprout.name = "Sprout"
    sprout.location = (0, 0, 0.14)
    sprout.rotation_euler = (0.2, 0.1, 0)

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# 4. Voltite (lightning) - angular bolt/shard
# ---------------------------------------------------------------------------
def build_voltite():
    """Jagged lightning bolt shard: thin angular box at 45 degrees."""
    clear_scene()

    root = bpy.data.objects.new("Voltite", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.1
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # Main shard - tall thin box at an angle
    shard = add(generate_box(w=0.06, d=0.04, h=0.18,
                             hex_color=E["volt_base"]))
    shard.name = "ShardMain"
    shard.location = (0, 0, 0.0)
    shard.rotation_euler = (0, 0.15, math.radians(15))

    # Secondary shard crossing the main one
    shard2 = add(generate_box(w=0.04, d=0.03, h=0.12,
                              hex_color=E["volt_hi"]))
    shard2.name = "ShardCross"
    shard2.location = (0.03, -0.01, 0.04)
    shard2.rotation_euler = (0.1, -0.3, math.radians(-30))

    # Small accent shard
    shard3 = add(generate_box(w=0.03, d=0.025, h=0.07,
                              hex_color=E["volt_dark"]))
    shard3.name = "ShardSmall"
    shard3.location = (-0.02, 0.02, 0.06)
    shard3.rotation_euler = (-0.2, 0.2, math.radians(45))

    # Tiny energy point on top (cone tip)
    tip = add(generate_cone(radius_bottom=0.02, radius_top=0.0, height=0.05,
                            segments=4, hex_color=E["volt_hi"]))
    tip.name = "EnergyTip"
    tip.location = (0.01, 0, 0.18)

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# 5. Umbrite (shadow) - dark orb
# ---------------------------------------------------------------------------
def build_umbrite():
    """Dark shadow orb with a faint inner glow ring."""
    clear_scene()

    root = bpy.data.objects.new("Umbrite", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.1
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # Main orb
    orb = add(generate_sphere(radius=0.1, rings=6, segments=12,
                              hex_color=E["umb_base"]))
    orb.name = "ShadowOrb"
    orb.location = (0, 0, 0.1)

    # Inner glow ring around the equator
    ring = add(generate_cylinder(radius=0.11, height=0.015, segments=12,
                                 hex_color=E["umb_hi"]))
    ring.name = "GlowRing"
    ring.location = (0, 0, 0.1)

    # Small wispy accent on top
    wisp = add(generate_cone(radius_bottom=0.03, radius_top=0.005,
                             height=0.05, segments=5,
                             hex_color=E["umb_glow"]))
    wisp.name = "Wisp"
    wisp.location = (0, 0, 0.2)

    # Dark base shadow disc
    shadow = add(generate_cylinder(radius=0.06, height=0.01, segments=8,
                                   hex_color=E["umb_deep"]))
    shadow.name = "ShadowBase"
    shadow.location = (0, 0, 0)

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# 6. Resonite (force) - octahedron/diamond shape
# ---------------------------------------------------------------------------
def build_resonite():
    """Geometric diamond: two cones tip-to-tip forming an octahedron."""
    clear_scene()

    root = bpy.data.objects.new("Resonite", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.1
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # Bottom cone (pointing down)
    bottom = add(generate_cone(radius_bottom=0.08, radius_top=0.0,
                               height=0.1, segments=4,
                               hex_color=E["res_dark"]))
    bottom.name = "DiamondBottom"
    bottom.location = (0, 0, 0.1)
    bottom.rotation_euler = (math.pi, 0, 0)  # Flip upside down

    # Top cone (pointing up)
    top = add(generate_cone(radius_bottom=0.08, radius_top=0.0,
                            height=0.12, segments=4,
                            hex_color=E["res_base"]))
    top.name = "DiamondTop"
    top.location = (0, 0, 0.1)

    # Central band ring at the equator — match cone's 4 segments, aligned
    band = add(generate_cylinder(radius=0.082, height=0.012, segments=4,
                                 hex_color=E["res_hi"]))
    band.name = "EquatorBand"
    band.location = (0, 0, 0.1)

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# Main: build all 6 items
# ---------------------------------------------------------------------------
ITEMS = [
    ("pyromite", build_pyromite),
    ("crystalline", build_crystalline),
    ("biovine", build_biovine),
    ("voltite", build_voltite),
    ("umbrite", build_umbrite),
    ("resonite", build_resonite),
]


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"[item_models] Output directory: {OUTPUT_DIR}")

    for name, build_fn in ITEMS:
        print(f"\n[item_models] Building {name}...")
        build_fn()
        export_item(name)

    print(f"\n[item_models] All 6 items exported to {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
