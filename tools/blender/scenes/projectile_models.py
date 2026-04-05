"""Generate 6 elemental projectile models for Night Shift turrets.

Each projectile is a tiny energy bolt (~0.2 Blender units) with element-specific
geometry and color. Exported as .glb with a spinning "idle" animation.

Elements:
    Fire (Pyromite)     -- elongated teardrop/flame
    Ice (Crystalline)   -- angular crystal shard
    Nature (Biovine)    -- round spore with bumps
    Lightning (Voltite) -- jagged bolt shape
    Shadow (Umbrite)    -- dark orb with glow ring
    Force (Resonite)    -- geometric diamond

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/projectile_models.py
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
from prefabs_src.sphere import generate_sphere
from prefabs_src.cone import generate_cone
from prefabs_src.cylinder import generate_cylinder
from prefabs_src.box import generate_box
from prefabs_src.hemisphere import generate_hemisphere
from prefabs_src.crystal import generate_crystal
from prefabs_src.torus import generate_torus
from anim_helpers import animate_rotation, FPS

OUTPUT_DIR = os.path.join(REPO_ROOT, "effects", "projectiles", "models")


def export_projectile(name):
    """Export a projectile as .glb and _flat.glb."""
    base = os.path.join(OUTPUT_DIR, name)
    export_glb(base + ".glb")
    # Flat version is identical for objects this small
    export_glb(base + "_flat.glb")
    print(f"  [projectile] Exported {name}")


# ---------------------------------------------------------------------------
# Animation: spinning idle (1 second, Z rotation)
# ---------------------------------------------------------------------------
def bake_idle_spin(root):
    """Give the root empty a 1-second full Z rotation as 'idle'."""
    animate_rotation(root, "idle", duration=1.0, axis='Z',
                     total_angle=math.pi * 2)


# ---------------------------------------------------------------------------
# Projectile builders
# ---------------------------------------------------------------------------

def build_fire():
    """Fire projectile: cone (tip) + sphere (glow trailing)."""
    clear_scene()

    root = bpy.data.objects.new("FireProjectile", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.1
    bpy.context.scene.collection.objects.link(root)

    # Core flame: pointed cone, tip facing +Y (forward)
    core = generate_cone(radius_bottom=0.06, radius_top=0.0, height=0.18,
                         segments=8, hex_color="#F24D19")
    core.name = "FlameCore"
    core.rotation_euler = (math.radians(-90), 0, 0)  # tip points +Y
    core.location = (0, 0.03, 0)
    core.parent = root

    # Highlight inner flame, slightly smaller
    inner = generate_cone(radius_bottom=0.035, radius_top=0.0, height=0.12,
                          segments=6, hex_color="#FFB830")
    inner.name = "FlameInner"
    inner.rotation_euler = (math.radians(-90), 0, 0)
    inner.location = (0, 0.01, 0)
    inner.parent = root

    # Glow sphere trailing behind
    glow = generate_sphere(radius=0.07, rings=4, segments=8,
                           hex_color="#FFD866")
    glow.name = "FlameGlow"
    glow.location = (0, -0.06, 0)
    glow.parent = root

    bake_idle_spin(root)
    export_projectile("fire_projectile")


def build_ice():
    """Ice projectile: single crystal shard, angular."""
    clear_scene()

    root = bpy.data.objects.new("IceProjectile", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.1
    bpy.context.scene.collection.objects.link(root)

    # Single crystal shard -- 1 crystal, no spread, small size
    shard = generate_crystal(num_crystals=1, base_radius=0.04, base_height=0.14,
                             tip_ratio=0.5, spread=0.0, seed=7,
                             hex_color="#4DB3F2")
    shard.name = "IceShard"
    # Tilt forward so crystal points along +Y (flight direction)
    shard.rotation_euler = (math.radians(-70), 0, math.radians(15))
    shard.location = (0, 0.02, 0)
    shard.parent = root

    # Glow aura behind
    glow = generate_sphere(radius=0.06, rings=4, segments=8,
                           hex_color="#DDEFFF")
    glow.name = "IceGlow"
    glow.location = (0, -0.05, 0)
    glow.parent = root

    # Highlight facet -- small hemisphere accent
    highlight = generate_hemisphere(radius=0.025, rings=2, segments=6,
                                   hex_color="#B8E5FF")
    highlight.name = "IceHighlight"
    highlight.location = (0.02, 0.04, 0.02)
    highlight.parent = root

    bake_idle_spin(root)
    export_projectile("ice_projectile")


def build_nature():
    """Nature projectile: round spore/seed with bumps."""
    clear_scene()

    root = bpy.data.objects.new("NatureProjectile", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.1
    bpy.context.scene.collection.objects.link(root)

    # Main spore body
    body = generate_sphere(radius=0.08, rings=5, segments=8,
                           hex_color="#33D94D")
    body.name = "SporeBody"
    body.parent = root

    # Hemisphere bumps around the surface (organic spore nodes)
    bump_positions = [
        (0.07, 0.0, 0.04),
        (-0.05, 0.06, 0.03),
        (0.0, -0.06, 0.05),
        (-0.04, -0.03, -0.06),
        (0.03, 0.05, -0.04),
        (0.0, 0.0, 0.08),
    ]
    for i, (bx, by, bz) in enumerate(bump_positions):
        bump = generate_hemisphere(radius=0.025, rings=2, segments=6,
                                   hex_color="#8FFF66")
        bump.name = f"Bump_{i}"
        bump.location = (bx, by, bz)
        # Orient bump outward from center
        bump.rotation_euler = (
            math.atan2(-bz, math.sqrt(bx*bx + by*by)) + math.radians(90),
            0,
            math.atan2(by, bx)
        )
        bump.parent = root

    # Glow aura
    glow = generate_sphere(radius=0.10, rings=3, segments=8,
                           hex_color="#B8FF99")
    glow.name = "NatureGlow"
    glow.location = (0, 0, 0)
    glow.parent = root

    bake_idle_spin(root)
    export_projectile("nature_projectile")


def build_lightning():
    """Lightning projectile: jagged bolt from thin boxes at angles."""
    clear_scene()

    root = bpy.data.objects.new("LightningProjectile", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.1
    bpy.context.scene.collection.objects.link(root)

    # Main bolt segment -- thin elongated box
    seg1 = generate_box(w=0.03, d=0.12, h=0.03, hex_color="#C8A82A")
    seg1.name = "BoltSeg1"
    seg1.location = (0, 0.0, 0)
    seg1.parent = root

    # Second segment -- angled
    seg2 = generate_box(w=0.025, d=0.10, h=0.025, hex_color="#FFE066")
    seg2.name = "BoltSeg2"
    seg2.rotation_euler = (0, 0, math.radians(35))
    seg2.location = (0.03, 0.08, 0.01)
    seg2.parent = root

    # Third segment -- angled opposite
    seg3 = generate_box(w=0.025, d=0.08, h=0.025, hex_color="#C8A82A")
    seg3.name = "BoltSeg3"
    seg3.rotation_euler = (0, 0, math.radians(-30))
    seg3.location = (-0.02, -0.07, -0.01)
    seg3.parent = root

    # Bright tip point
    tip = generate_cone(radius_bottom=0.025, radius_top=0.0, height=0.05,
                        segments=6, hex_color="#FFE066")
    tip.name = "BoltTip"
    tip.rotation_euler = (math.radians(-90), 0, math.radians(35))
    tip.location = (0.05, 0.14, 0.01)
    tip.parent = root

    # Glow core
    glow = generate_sphere(radius=0.05, rings=3, segments=6,
                           hex_color="#FFE066")
    glow.name = "LightningGlow"
    glow.location = (0, 0, 0)
    glow.parent = root

    bake_idle_spin(root)
    export_projectile("lightning_projectile")


def build_shadow():
    """Shadow projectile: dark orb with glowing torus ring."""
    clear_scene()

    root = bpy.data.objects.new("ShadowProjectile", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.1
    bpy.context.scene.collection.objects.link(root)

    # Dark core orb
    core = generate_sphere(radius=0.07, rings=5, segments=8,
                           hex_color="#4A2D6B")
    core.name = "ShadowCore"
    core.parent = root

    # Glowing ring around the orb
    ring = generate_torus(major_radius=0.10, minor_radius=0.018,
                          major_segments=12, minor_segments=6,
                          hex_color="#9B6FCF")
    ring.name = "ShadowRing"
    ring.parent = root

    # Highlight accent sphere
    highlight = generate_sphere(radius=0.03, rings=3, segments=6,
                                hex_color="#7B52A3")
    highlight.name = "ShadowHighlight"
    highlight.location = (0.03, 0.03, 0.04)
    highlight.parent = root

    # Outer glow sphere
    glow = generate_sphere(radius=0.11, rings=3, segments=8,
                           hex_color="#9B6FCF")
    glow.name = "ShadowGlow"
    glow.parent = root

    bake_idle_spin(root)
    export_projectile("shadow_projectile")


def build_force():
    """Force projectile: two cones tip-to-tip forming a diamond/octahedron."""
    clear_scene()

    root = bpy.data.objects.new("ForceProjectile", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.1
    bpy.context.scene.collection.objects.link(root)

    # Upper cone (tip pointing up)
    upper = generate_cone(radius_bottom=0.07, radius_top=0.0, height=0.10,
                          segments=4, hex_color="#C0C0C8")
    upper.name = "DiamondUpper"
    upper.parent = root

    # Lower cone (tip pointing down) -- flip the cone
    lower = generate_cone(radius_bottom=0.07, radius_top=0.0, height=0.10,
                          segments=4, hex_color="#E8E8F0")
    lower.name = "DiamondLower"
    lower.rotation_euler = (math.radians(180), 0, 0)
    lower.parent = root

    # Glow sphere
    glow = generate_sphere(radius=0.09, rings=3, segments=8,
                           hex_color="#F0F0FF")
    glow.name = "ForceGlow"
    glow.parent = root

    bake_idle_spin(root)
    export_projectile("force_projectile")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    print("[projectile_models] Building 6 elemental projectiles...")

    builders = [
        ("Fire", build_fire),
        ("Ice", build_ice),
        ("Nature", build_nature),
        ("Lightning", build_lightning),
        ("Shadow", build_shadow),
        ("Force", build_force),
    ]

    for name, builder in builders:
        print(f"  Building {name}...")
        builder()

    print(f"[projectile_models] Done. Output: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
