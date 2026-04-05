"""Generate 3D item models for the 15 combination resources.

Each combo item blends the shapes and colors of its two parent elements.
Items are tiny (0.2-0.3 Blender units) and carried on conveyor belts.

M1 combos (priority):
  1. Steam Burst     (Pyromite + Crystalline) - swirling pink/mauve
  2. Verdant Compound (Crystalline + Biovine) - teal crystal seed
  3. Frozen Flame    (Pyromite + Biovine)     - purple flame orb

Post-M1 combos (12 more):
  4. Pyro-Volt   (Pyromite + Voltite)     - molten gold
  5. Pyro-Umb    (Pyromite + Umbrite)     - deep crimson
  6. Pyro-Res    (Pyromite + Resonite)    - bright copper
  7. Cryst-Volt  (Crystalline + Voltite)  - electric teal
  8. Cryst-Umb   (Crystalline + Umbrite)  - deep indigo
  9. Cryst-Res   (Crystalline + Resonite) - ice chrome
  10. Bio-Volt   (Biovine + Voltite)      - acid yellow-green
  11. Bio-Umb    (Biovine + Umbrite)      - toxic plum
  12. Bio-Res    (Biovine + Resonite)     - mint chrome
  13. Volt-Umb   (Voltite + Umbrite)      - storm violet
  14. Volt-Res   (Voltite + Resonite)     - charged platinum
  15. Umb-Res    (Umbrite + Resonite)     - void chrome

Each has a slow idle rotation animation (1 full Z rotation over 2 seconds).

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/combo_item_models.py
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
from prefabs_src.cone import generate_cone
from prefabs_src.cylinder import generate_cylinder
from prefabs_src.sphere import generate_sphere
from prefabs_src.hemisphere import generate_hemisphere
from prefabs_src.crystal import generate_crystal
from prefabs_src.box import generate_box
from prefabs_src.torus import generate_torus
from prefabs_src.wedge import generate_wedge
from anim_helpers import animate_rotation, FPS

# Load element palette
E = load_palette("elements")

OUTPUT_DIR = os.path.join(REPO_ROOT, "resources", "items", "models")


# ---------------------------------------------------------------------------
# Export helpers (same as item_models.py)
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


def export_item(name):
    """Export both textured and flat versions plus .blend."""
    base_path = os.path.join(OUTPUT_DIR, f"{name}_item")
    export_glb(base_path + ".glb")
    export_blend(base_path + ".blend")
    export_glb(base_path + "_flat.glb")
    print(f"[combo_items] Exported: {name}")


# ---------------------------------------------------------------------------
# Animation helper
# ---------------------------------------------------------------------------
def add_idle_rotation(obj):
    """Add slow Z-axis rotation: 1 full turn over 2 seconds."""
    animate_rotation(obj, "idle", duration=2.0, axis='Z',
                     total_angle=math.pi * 2)


# ---------------------------------------------------------------------------
# Helper: create root empty + parenting utility
# ---------------------------------------------------------------------------
def _make_root(name):
    """Create and return (root, add_fn) for building an item."""
    root = bpy.data.objects.new(name, None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.1
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    return root, add


# ===========================================================================
# M1 COMBO ITEMS (hand-crafted, unique designs)
# ===========================================================================

# ---------------------------------------------------------------------------
# 1. Steam Burst (Pyromite + Crystalline)
#    Concept: swirling steam cloud with crystal shards poking out.
#    Hemisphere base (cloud), small crystal shards, cone wisps.
# ---------------------------------------------------------------------------
def build_steam_burst():
    clear_scene()
    root, add = _make_root("SteamBurst")

    # Cloud body - puffy hemisphere
    cloud = add(generate_hemisphere(radius=0.1, rings=4, segments=10,
                                    hex_color=E["steam_base"]))
    cloud.name = "CloudBody"
    cloud.location = (0, 0, 0)

    # Top puff sphere
    puff = add(generate_sphere(radius=0.07, rings=4, segments=8,
                               hex_color=E["steam_hi"]))
    puff.name = "TopPuff"
    puff.location = (0, 0, 0.08)

    # Small crystal shard poking through - angular, from Crystalline parent
    shard1 = add(generate_crystal(
        num_crystals=1, base_radius=0.025, base_height=0.08,
        tip_ratio=0.5, spread=0.0, seed=42,
        hex_color=E["cryst_base"]))
    shard1.name = "CrystShard1"
    shard1.location = (0.04, -0.02, 0.04)
    shard1.rotation_euler = (0.2, 0.3, 0)

    # Second small shard
    shard2 = add(generate_crystal(
        num_crystals=1, base_radius=0.02, base_height=0.06,
        tip_ratio=0.4, spread=0.0, seed=13,
        hex_color=E["cryst_hi"]))
    shard2.name = "CrystShard2"
    shard2.location = (-0.03, 0.03, 0.03)
    shard2.rotation_euler = (-0.2, -0.25, 0.1)

    # Small flame wisp on top - from Pyromite parent
    wisp = add(generate_cone(radius_bottom=0.025, radius_top=0.0,
                             height=0.06, segments=5,
                             hex_color=E["steam_glow"]))
    wisp.name = "SteamWisp"
    wisp.location = (0.01, 0.01, 0.13)
    wisp.rotation_euler = (0.15, -0.1, 0)

    # Dark base disc
    base = add(generate_cylinder(radius=0.06, height=0.01, segments=8,
                                 hex_color=E["steam_dark"]))
    base.name = "SteamBase"

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# 2. Verdant Compound (Crystalline + Biovine)
#    Concept: a crystalline seed sprouting organic tendrils.
#    Faceted crystal base with organic sphere and sprout on top.
# ---------------------------------------------------------------------------
def build_verdant_compound():
    clear_scene()
    root, add = _make_root("VerdantCompound")

    # Crystal base - small faceted prism
    base_crystal = add(generate_crystal(
        num_crystals=1, base_radius=0.06, base_height=0.08,
        tip_ratio=0.3, spread=0.0, seed=77,
        hex_color=E["verd_dark"]))
    base_crystal.name = "CrystalBase"

    # Organic body growing from the crystal
    body = add(generate_sphere(radius=0.07, rings=4, segments=8,
                               hex_color=E["verd_base"]))
    body.name = "OrganicBody"
    body.location = (0, 0, 0.09)

    # Bright sprout/tendril on top
    sprout = add(generate_cone(radius_bottom=0.02, radius_top=0.005,
                               height=0.07, segments=5,
                               hex_color=E["verd_hi"]))
    sprout.name = "Sprout"
    sprout.location = (0.01, 0, 0.14)
    sprout.rotation_euler = (0.15, 0.1, 0)

    # Side tendril
    tendril = add(generate_cone(radius_bottom=0.015, radius_top=0.003,
                                height=0.05, segments=4,
                                hex_color=E["verd_hi"]))
    tendril.name = "SideTendril"
    tendril.location = (-0.05, 0.02, 0.07)
    tendril.rotation_euler = (-0.4, -0.6, 0)

    # Small crystal accent shard
    accent = add(generate_crystal(
        num_crystals=1, base_radius=0.02, base_height=0.04,
        tip_ratio=0.5, spread=0.0, seed=33,
        hex_color=E["cryst_hi"]))
    accent.name = "CrystAccent"
    accent.location = (0.04, -0.03, 0.02)
    accent.rotation_euler = (0.1, 0.4, 0)

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# 3. Frozen Flame (Pyromite + Biovine)
#    Concept: a purple flame-orb with organic veins.
#    Sphere core with flame cones and organic bumps.
# ---------------------------------------------------------------------------
def build_frozen_flame():
    clear_scene()
    root, add = _make_root("FrozenFlame")

    # Central orb
    orb = add(generate_sphere(radius=0.08, rings=5, segments=10,
                              hex_color=E["frozen_base"]))
    orb.name = "FlameOrb"
    orb.location = (0, 0, 0.08)

    # Flame cone pointing up (from Pyromite)
    flame1 = add(generate_cone(radius_bottom=0.04, radius_top=0.0,
                               height=0.12, segments=6,
                               hex_color=E["frozen_hi"]))
    flame1.name = "FlameTop"
    flame1.location = (0, 0, 0.14)

    # Secondary flame tilted
    flame2 = add(generate_cone(radius_bottom=0.03, radius_top=0.0,
                               height=0.08, segments=5,
                               hex_color=E["frozen_glow"]))
    flame2.name = "FlameSide"
    flame2.location = (0.04, -0.02, 0.1)
    flame2.rotation_euler = (0.2, 0.4, 0)

    # Organic bump (from Biovine)
    bump = add(generate_hemisphere(radius=0.04, rings=3, segments=6,
                                   hex_color=E["frozen_dark"]))
    bump.name = "OrganicBump"
    bump.location = (-0.04, 0.03, 0.05)
    bump.rotation_euler = (-0.3, -0.4, 0)

    # Small sprout tendril
    sprout = add(generate_cone(radius_bottom=0.012, radius_top=0.003,
                               height=0.04, segments=4,
                               hex_color=E["bio_hi"]))
    sprout.name = "VineSprout"
    sprout.location = (-0.02, -0.04, 0.06)
    sprout.rotation_euler = (0.3, -0.3, 0)

    # Dark base
    base = add(generate_cylinder(radius=0.05, height=0.01, segments=8,
                                 hex_color=E["frozen_deep"]))
    base.name = "FrozenBase"

    add_idle_rotation(root)
    return root


# ===========================================================================
# POST-M1 COMBO ITEMS (systematic approach)
# Each uses the primary parent's shape as base + secondary accent
# ===========================================================================

# ---------------------------------------------------------------------------
# 4. Pyro-Volt (Pyromite + Voltite) - molten gold
#    Base: flame cones (Pyromite) + bolt shard accent (Voltite)
# ---------------------------------------------------------------------------
def build_pyro_volt():
    clear_scene()
    root, add = _make_root("PyroVolt")

    # Flame base - central cone
    flame = add(generate_cone(radius_bottom=0.05, radius_top=0.0,
                              height=0.18, segments=6,
                              hex_color=E["pyrovolt_base"]))
    flame.name = "FlameCore"
    flame.location = (0, 0, 0.02)

    # Secondary flame
    flame2 = add(generate_cone(radius_bottom=0.035, radius_top=0.0,
                               height=0.12, segments=5,
                               hex_color=E["pyrovolt_hi"]))
    flame2.name = "FlameSide"
    flame2.location = (-0.03, 0.01, 0.02)
    flame2.rotation_euler = (0.15, -0.2, 0)

    # Lightning bolt accent - angular box shard
    bolt = add(generate_box(w=0.03, d=0.02, h=0.1,
                            hex_color=E["volt_hi"]))
    bolt.name = "BoltAccent"
    bolt.location = (0.04, -0.02, 0.06)
    bolt.rotation_euler = (0.1, 0.3, math.radians(20))

    # Base disc
    base = add(generate_cylinder(radius=0.06, height=0.015, segments=8,
                                 hex_color=E["pyrovolt_dark"]))
    base.name = "Base"

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# 5. Pyro-Umb (Pyromite + Umbrite) - deep crimson
#    Base: flame cones (Pyromite) + dark orb accent (Umbrite)
# ---------------------------------------------------------------------------
def build_pyro_umb():
    clear_scene()
    root, add = _make_root("PyroUmb")

    # Dark sphere core (Umbrite influence)
    orb = add(generate_sphere(radius=0.07, rings=4, segments=8,
                              hex_color=E["pyroumb_dark"]))
    orb.name = "DarkCore"
    orb.location = (0, 0, 0.07)

    # Crimson flame rising from the orb
    flame = add(generate_cone(radius_bottom=0.045, radius_top=0.0,
                              height=0.14, segments=6,
                              hex_color=E["pyroumb_base"]))
    flame.name = "CrimsonFlame"
    flame.location = (0, 0, 0.1)

    # Secondary flame
    flame2 = add(generate_cone(radius_bottom=0.03, radius_top=0.0,
                               height=0.09, segments=5,
                               hex_color=E["pyroumb_hi"]))
    flame2.name = "FlameWisp"
    flame2.location = (0.035, -0.02, 0.08)
    flame2.rotation_euler = (0.2, 0.3, 0)

    # Shadow ring (Umbrite accent)
    ring = add(generate_cylinder(radius=0.08, height=0.012, segments=10,
                                 hex_color=E["umb_hi"]))
    ring.name = "ShadowRing"
    ring.location = (0, 0, 0.07)

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# 6. Pyro-Res (Pyromite + Resonite) - bright copper
#    Base: flame cones (Pyromite) + diamond accent (Resonite)
# ---------------------------------------------------------------------------
def build_pyro_res():
    clear_scene()
    root, add = _make_root("PyroRes")

    # Flame cones
    flame = add(generate_cone(radius_bottom=0.05, radius_top=0.0,
                              height=0.15, segments=6,
                              hex_color=E["pyrores_base"]))
    flame.name = "CopperFlame"
    flame.location = (0, 0, 0.03)

    flame2 = add(generate_cone(radius_bottom=0.035, radius_top=0.0,
                               height=0.1, segments=5,
                               hex_color=E["pyrores_hi"]))
    flame2.name = "FlameSecondary"
    flame2.location = (-0.03, 0.02, 0.03)
    flame2.rotation_euler = (0.2, -0.25, 0)

    # Diamond accent (Resonite) - small octahedron (two cones tip-to-tip)
    diamond_top = add(generate_cone(radius_bottom=0.03, radius_top=0.0,
                                    height=0.04, segments=4,
                                    hex_color=E["res_hi"]))
    diamond_top.name = "DiamondTop"
    diamond_top.location = (0.04, -0.03, 0.08)

    diamond_bot = add(generate_cone(radius_bottom=0.03, radius_top=0.0,
                                    height=0.03, segments=4,
                                    hex_color=E["res_base"]))
    diamond_bot.name = "DiamondBot"
    diamond_bot.location = (0.04, -0.03, 0.08)
    diamond_bot.rotation_euler = (math.pi, 0, 0)

    # Base disc
    base = add(generate_cylinder(radius=0.06, height=0.015, segments=8,
                                 hex_color=E["pyrores_dark"]))
    base.name = "Base"

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# 7. Cryst-Volt (Crystalline + Voltite) - electric teal
#    Base: crystal prism (Crystalline) + bolt shard (Voltite)
# ---------------------------------------------------------------------------
def build_cryst_volt():
    clear_scene()
    root, add = _make_root("CrystVolt")

    # Main crystal
    crystal = add(generate_crystal(
        num_crystals=1, base_radius=0.05, base_height=0.12,
        tip_ratio=0.4, spread=0.0, seed=42,
        hex_color=E["crystvolt_base"]))
    crystal.name = "TealCrystal"

    # Secondary crystal
    crystal2 = add(generate_crystal(
        num_crystals=1, base_radius=0.03, base_height=0.07,
        tip_ratio=0.3, spread=0.0, seed=21,
        hex_color=E["crystvolt_hi"]))
    crystal2.name = "SmallCrystal"
    crystal2.location = (0.04, -0.02, 0)
    crystal2.rotation_euler = (0.1, 0.25, 0)

    # Bolt shard accent (Voltite)
    bolt = add(generate_box(w=0.025, d=0.018, h=0.08,
                            hex_color=E["volt_hi"]))
    bolt.name = "BoltShard"
    bolt.location = (-0.03, 0.03, 0.04)
    bolt.rotation_euler = (-0.2, -0.3, math.radians(30))

    # Energy tip
    tip = add(generate_cone(radius_bottom=0.015, radius_top=0.0,
                            height=0.03, segments=4,
                            hex_color=E["volt_base"]))
    tip.name = "SparkTip"
    tip.location = (-0.03, 0.03, 0.12)

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# 8. Cryst-Umb (Crystalline + Umbrite) - deep indigo
#    Base: crystal prism (Crystalline) + shadow orb (Umbrite)
# ---------------------------------------------------------------------------
def build_cryst_umb():
    clear_scene()
    root, add = _make_root("CrystUmb")

    # Shadow orb base (Umbrite influence)
    orb = add(generate_sphere(radius=0.07, rings=4, segments=8,
                              hex_color=E["crystumb_dark"]))
    orb.name = "IndigoOrb"
    orb.location = (0, 0, 0.07)

    # Crystal shards growing from orb
    shard1 = add(generate_crystal(
        num_crystals=1, base_radius=0.03, base_height=0.1,
        tip_ratio=0.5, spread=0.0, seed=42,
        hex_color=E["crystumb_base"]))
    shard1.name = "IndigoCrystal1"
    shard1.location = (0, 0, 0.08)

    shard2 = add(generate_crystal(
        num_crystals=1, base_radius=0.022, base_height=0.06,
        tip_ratio=0.4, spread=0.0, seed=19,
        hex_color=E["crystumb_hi"]))
    shard2.name = "IndigoCrystal2"
    shard2.location = (0.04, -0.02, 0.06)
    shard2.rotation_euler = (0.15, 0.3, 0)

    # Shadow wisp accent
    wisp = add(generate_cone(radius_bottom=0.02, radius_top=0.005,
                             height=0.04, segments=5,
                             hex_color=E["umb_glow"]))
    wisp.name = "ShadowWisp"
    wisp.location = (-0.03, 0.02, 0.12)

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# 9. Cryst-Res (Crystalline + Resonite) - ice chrome
#    Base: crystal prism (Crystalline) + diamond band (Resonite)
# ---------------------------------------------------------------------------
def build_cryst_res():
    clear_scene()
    root, add = _make_root("CrystRes")

    # Hemisphere base for cohesion (ice chrome foundation)
    base = add(generate_hemisphere(radius=0.08, rings=3, segments=8,
                                   hex_color=E["crystres_dark"]))
    base.name = "IceChrBase"

    # Main crystal growing from hemisphere center
    crystal = add(generate_crystal(
        num_crystals=1, base_radius=0.04, base_height=0.12,
        tip_ratio=0.45, spread=0.0, seed=55,
        hex_color=E["crystres_base"]))
    crystal.name = "IceChrCrystal"
    crystal.location = (0, 0, 0.03)

    # Chrome band ring around crystal midsection (Resonite influence)
    band = add(generate_cylinder(radius=0.045, height=0.012, segments=4,
                                 hex_color=E["res_hi"]))
    band.name = "ChromeBand"
    band.location = (0, 0, 0.08)

    # Small secondary crystal leaning against main
    crystal2 = add(generate_crystal(
        num_crystals=1, base_radius=0.022, base_height=0.05,
        tip_ratio=0.35, spread=0.0, seed=88,
        hex_color=E["crystres_hi"]))
    crystal2.name = "SmallIceChr"
    crystal2.location = (0.04, -0.01, 0.02)
    crystal2.rotation_euler = (0.1, 0.25, 0)

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# 10. Bio-Volt (Biovine + Voltite) - acid yellow-green
#     Base: organic seed (Biovine) + bolt shard (Voltite)
# ---------------------------------------------------------------------------
def build_bio_volt():
    clear_scene()
    root, add = _make_root("BioVolt")

    # Organic hemisphere base
    base_hemi = add(generate_hemisphere(radius=0.08, rings=3, segments=8,
                                        hex_color=E["biovolt_dark"]))
    base_hemi.name = "AcidBase"

    # Main body sphere
    body = add(generate_sphere(radius=0.07, rings=4, segments=8,
                               hex_color=E["biovolt_base"]))
    body.name = "AcidBody"
    body.location = (0, 0, 0.06)

    # Electric sprout (bolt-like)
    bolt = add(generate_box(w=0.025, d=0.015, h=0.09,
                            hex_color=E["volt_hi"]))
    bolt.name = "ElectricSprout"
    bolt.location = (0.02, 0, 0.1)
    bolt.rotation_euler = (0.1, 0.15, math.radians(10))

    # Organic bump
    bump = add(generate_sphere(radius=0.03, rings=3, segments=6,
                               hex_color=E["biovolt_hi"]))
    bump.name = "AcidBump"
    bump.location = (-0.03, 0.02, 0.1)

    # Tiny energy tip
    tip = add(generate_cone(radius_bottom=0.012, radius_top=0.0,
                            height=0.03, segments=4,
                            hex_color=E["volt_base"]))
    tip.name = "SparkTip"
    tip.location = (0.02, 0, 0.19)

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# 11. Bio-Umb (Biovine + Umbrite) - toxic plum
#     Base: organic seed (Biovine) + shadow orb (Umbrite)
# ---------------------------------------------------------------------------
def build_bio_umb():
    clear_scene()
    root, add = _make_root("BioUmb")

    # Dark hemisphere base (Umbrite influence)
    base_hemi = add(generate_hemisphere(radius=0.08, rings=3, segments=8,
                                        hex_color=E["umb_dark"]))
    base_hemi.name = "ToxicBase"

    # Plum body sphere
    body = add(generate_sphere(radius=0.08, rings=4, segments=8,
                               hex_color=E["bioumb_base"]))
    body.name = "PlumBody"
    body.location = (0, 0, 0.06)

    # Organic tendril sprouts
    sprout1 = add(generate_cone(radius_bottom=0.018, radius_top=0.004,
                                height=0.07, segments=5,
                                hex_color=E["bioumb_hi"]))
    sprout1.name = "ToxicSprout"
    sprout1.location = (0, 0, 0.12)
    sprout1.rotation_euler = (0.1, 0.05, 0)

    sprout2 = add(generate_cone(radius_bottom=0.013, radius_top=0.003,
                                height=0.05, segments=4,
                                hex_color=E["bio_hi"]))
    sprout2.name = "VineSprout"
    sprout2.location = (-0.04, 0.02, 0.08)
    sprout2.rotation_euler = (-0.35, -0.4, 0)

    # Shadow wisp
    wisp = add(generate_cone(radius_bottom=0.015, radius_top=0.004,
                             height=0.035, segments=5,
                             hex_color=E["umb_glow"]))
    wisp.name = "ShadowWisp"
    wisp.location = (0.03, -0.03, 0.1)
    wisp.rotation_euler = (0.25, 0.3, 0)

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# 12. Bio-Res (Biovine + Resonite) - mint chrome
#     Base: organic seed (Biovine) + diamond accent (Resonite)
# ---------------------------------------------------------------------------
def build_bio_res():
    clear_scene()
    root, add = _make_root("BioRes")

    # Organic hemisphere base
    base_hemi = add(generate_hemisphere(radius=0.08, rings=3, segments=8,
                                        hex_color=E["biores_dark"]))
    base_hemi.name = "MintBase"

    # Mint body sphere
    body = add(generate_sphere(radius=0.07, rings=4, segments=8,
                               hex_color=E["biores_base"]))
    body.name = "MintBody"
    body.location = (0, 0, 0.06)

    # Organic sprout
    sprout = add(generate_cone(radius_bottom=0.015, radius_top=0.004,
                               height=0.06, segments=5,
                               hex_color=E["biores_hi"]))
    sprout.name = "MintSprout"
    sprout.location = (0.01, 0, 0.12)
    sprout.rotation_euler = (0.1, 0.08, 0)

    # Diamond accent (Resonite)
    dtop = add(generate_cone(radius_bottom=0.025, radius_top=0.0,
                             height=0.035, segments=4,
                             hex_color=E["res_hi"]))
    dtop.name = "DiamondTop"
    dtop.location = (-0.04, 0.02, 0.06)

    dbot = add(generate_cone(radius_bottom=0.025, radius_top=0.0,
                             height=0.025, segments=4,
                             hex_color=E["res_base"]))
    dbot.name = "DiamondBot"
    dbot.location = (-0.04, 0.02, 0.06)
    dbot.rotation_euler = (math.pi, 0, 0)

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# 13. Volt-Umb (Voltite + Umbrite) - storm violet
#     Base: bolt shards (Voltite) + dark orb (Umbrite)
# ---------------------------------------------------------------------------
def build_volt_umb():
    clear_scene()
    root, add = _make_root("VoltUmb")

    # Shadow orb core (Umbrite)
    orb = add(generate_sphere(radius=0.07, rings=4, segments=8,
                              hex_color=E["voltumb_dark"]))
    orb.name = "StormOrb"
    orb.location = (0, 0, 0.07)

    # Lightning bolt shards around orb (Voltite)
    bolt1 = add(generate_box(w=0.03, d=0.02, h=0.12,
                             hex_color=E["voltumb_base"]))
    bolt1.name = "StormBolt1"
    bolt1.location = (0.02, 0, 0.07)
    bolt1.rotation_euler = (0, 0.2, math.radians(20))

    bolt2 = add(generate_box(w=0.025, d=0.018, h=0.09,
                             hex_color=E["voltumb_hi"]))
    bolt2.name = "StormBolt2"
    bolt2.location = (-0.03, 0.02, 0.05)
    bolt2.rotation_euler = (-0.15, -0.25, math.radians(-25))

    # Shadow ring
    ring = add(generate_cylinder(radius=0.08, height=0.01, segments=10,
                                 hex_color=E["umb_hi"]))
    ring.name = "StormRing"
    ring.location = (0, 0, 0.07)

    # Energy tip on top
    tip = add(generate_cone(radius_bottom=0.018, radius_top=0.0,
                            height=0.04, segments=4,
                            hex_color=E["volt_hi"]))
    tip.name = "StormTip"
    tip.location = (0, 0, 0.14)

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# 14. Volt-Res (Voltite + Resonite) - charged platinum
#     Base: bolt shards (Voltite) + diamond shape (Resonite)
# ---------------------------------------------------------------------------
def build_volt_res():
    clear_scene()
    root, add = _make_root("VoltRes")

    # Diamond core (Resonite) - two cones, compact
    dtop = add(generate_cone(radius_bottom=0.055, radius_top=0.0,
                             height=0.08, segments=4,
                             hex_color=E["voltres_base"]))
    dtop.name = "PlatDiamondTop"
    dtop.location = (0, 0, 0.07)

    dbot = add(generate_cone(radius_bottom=0.055, radius_top=0.0,
                             height=0.05, segments=4,
                             hex_color=E["voltres_dark"]))
    dbot.name = "PlatDiamondBot"
    dbot.location = (0, 0, 0.07)
    dbot.rotation_euler = (math.pi, 0, 0)

    # Equator band
    band = add(generate_cylinder(radius=0.058, height=0.01, segments=4,
                                 hex_color=E["voltres_hi"]))
    band.name = "PlatBand"
    band.location = (0, 0, 0.07)

    # Bolt shard accent (Voltite) - close to body
    bolt = add(generate_box(w=0.02, d=0.014, h=0.08,
                            hex_color=E["volt_hi"]))
    bolt.name = "ChargeBolt"
    bolt.location = (0.04, -0.01, 0.05)
    bolt.rotation_euler = (0.1, 0.25, math.radians(15))

    # Small energy tip on top of diamond
    tip = add(generate_cone(radius_bottom=0.015, radius_top=0.0,
                            height=0.03, segments=4,
                            hex_color=E["volt_base"]))
    tip.name = "ChargeTip"
    tip.location = (0, 0, 0.15)

    add_idle_rotation(root)
    return root


# ---------------------------------------------------------------------------
# 15. Umb-Res (Umbrite + Resonite) - void chrome
#     Base: dark orb (Umbrite) + diamond facets (Resonite)
# ---------------------------------------------------------------------------
def build_umb_res():
    clear_scene()
    root, add = _make_root("UmbRes")

    # Central void orb (Umbrite)
    orb = add(generate_sphere(radius=0.08, rings=5, segments=10,
                              hex_color=E["umbres_dark"]))
    orb.name = "VoidOrb"
    orb.location = (0, 0, 0.08)

    # Chrome equator band (Resonite influence)
    band = add(generate_cylinder(radius=0.085, height=0.012, segments=4,
                                 hex_color=E["umbres_hi"]))
    band.name = "ChromeBand"
    band.location = (0, 0, 0.08)

    # Small diamond accent on top
    dtop = add(generate_cone(radius_bottom=0.025, radius_top=0.0,
                             height=0.04, segments=4,
                             hex_color=E["res_hi"]))
    dtop.name = "VoidDiamondTop"
    dtop.location = (0, 0, 0.16)

    # Shadow wisp rising
    wisp = add(generate_cone(radius_bottom=0.018, radius_top=0.004,
                             height=0.04, segments=5,
                             hex_color=E["umb_glow"]))
    wisp.name = "VoidWisp"
    wisp.location = (0.04, -0.02, 0.13)
    wisp.rotation_euler = (0.2, 0.3, 0)

    # Dark base
    base = add(generate_cylinder(radius=0.05, height=0.01, segments=8,
                                 hex_color=E["umbres_dark"]))
    base.name = "VoidBase"

    add_idle_rotation(root)
    return root


# ===========================================================================
# Main: build all 15 combo items
# ===========================================================================
ITEMS = [
    # M1 (priority)
    ("steam_burst",        build_steam_burst),
    ("verdant_compound",   build_verdant_compound),
    ("frozen_flame",       build_frozen_flame),
    # Post-M1
    ("pyro_volt",          build_pyro_volt),
    ("pyro_umb",           build_pyro_umb),
    ("pyro_res",           build_pyro_res),
    ("cryst_volt",         build_cryst_volt),
    ("cryst_umb",          build_cryst_umb),
    ("cryst_res",          build_cryst_res),
    ("bio_volt",           build_bio_volt),
    ("bio_umb",            build_bio_umb),
    ("bio_res",            build_bio_res),
    ("volt_umb",           build_volt_umb),
    ("volt_res",           build_volt_res),
    ("umb_res",            build_umb_res),
]


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"[combo_items] Output directory: {OUTPUT_DIR}")

    for name, build_fn in ITEMS:
        print(f"\n[combo_items] Building {name}...")
        build_fn()
        export_item(name)

    print(f"\n[combo_items] All 15 combo items exported to {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
