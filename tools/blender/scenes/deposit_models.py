"""Generate 3D models for elemental deposit types: Pyromite, Crystalline, Biovine.

Each deposit is a distinct mineral formation players drill on the map.
Built from prefabs with subtle idle animations (breathing/pulsing).

Two versions per deposit:
- Flat: palette-only flat materials (no textures)
- Textured: PBR textures for surface detail (falls back to flat on download failure)

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/deposit_models.py
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
from prefabs_src.box import generate_box
from prefabs_src.cone import generate_cone
from prefabs_src.cylinder import generate_cylinder
from prefabs_src.hemisphere import generate_hemisphere
from prefabs_src.crystal import generate_crystal
from prefabs_src.sphere import generate_sphere
from anim_helpers import animate_rotation, animate_static, animate_shake, FPS

# Load elemental palette
E = load_palette("elements")


# ---------------------------------------------------------------------------
# Animation: scale oscillation (not in anim_helpers, so we define it here)
# ---------------------------------------------------------------------------
def _ensure_anim_data(obj):
    if obj.animation_data is None:
        obj.animation_data_create()
    return obj.animation_data


def _set_linear(action):
    """Set all keyframe points to linear interpolation (Blender 5.x layered API)."""
    for layer in action.layers:
        for strip in layer.strips:
            if hasattr(strip, 'channelbags'):
                for cb in strip.channelbags:
                    for fc in cb.fcurves:
                        for kp in fc.keyframe_points:
                            kp.interpolation = 'LINEAR'


def _push_to_nla(obj, action, state_name):
    anim = _ensure_anim_data(obj)
    track = anim.nla_tracks.new()
    track.name = state_name
    track.strips.new(state_name, int(action.frame_range[0]), action)
    anim.action = None


def animate_scale_pulse(obj, state_name, duration=2.0, axis='Z',
                        amplitude=0.03, frequency=1.0):
    """Animate a subtle scale pulse on one axis (breathing effect).

    Scale oscillates as 1.0 + amplitude * sin(2pi * freq * t).
    """
    axis_idx = {'X': 0, 'Y': 1, 'Z': 2}[axis.upper()]
    frames = int(FPS * duration)

    action_name = f"{state_name}_{obj.name}"
    act = bpy.data.actions.new(action_name)
    _ensure_anim_data(obj).action = act

    for f in range(frames + 1):
        t = f / frames
        val = 1.0 + amplitude * math.sin(2 * math.pi * frequency * t)
        obj.scale[axis_idx] = val
        obj.keyframe_insert(data_path="scale", index=axis_idx, frame=f + 1)

    _set_linear(act)
    _push_to_nla(obj, act, state_name)
    # Reset
    obj.scale[axis_idx] = 1.0


def animate_scale_static(obj, state_name, duration=2.0):
    """Hold scale at (1,1,1) for a state -- prevents inheritance from other tracks."""
    frames = int(FPS * duration)

    action_name = f"{state_name}_{obj.name}"
    act = bpy.data.actions.new(action_name)
    _ensure_anim_data(obj).action = act

    obj.scale = (1, 1, 1)
    obj.keyframe_insert(data_path="scale", frame=1)
    obj.keyframe_insert(data_path="scale", frame=frames + 1)

    _set_linear(act)
    _push_to_nla(obj, act, state_name)


# ---------------------------------------------------------------------------
# Try to apply texture, gracefully fall back on failure
# ---------------------------------------------------------------------------
def try_apply_texture(obj, asset_id, resolution="1k"):
    """Attempt to apply a PBR texture. Returns True on success, False on failure."""
    try:
        from texture_library import apply_texture
        apply_texture(obj, asset_id, resolution=resolution)
        return True
    except Exception as e:
        print(f"[deposit] Texture '{asset_id}' failed: {e}")
        return False


# ===========================================================================
# PYROMITE -- Jagged volcanic formation with sharp peaks
# ===========================================================================
def build_pyromite():
    """Build a jagged volcanic deposit from cones and irregular rock shapes."""
    clear_scene()

    root = bpy.data.objects.new("Pyromite", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # -- Ground base: rough irregular slab --
    base = add(generate_box(w=1.4, d=1.3, h=0.12, hex_color=E["pyro_deep"]))
    base.name = "PyroBase"
    base.location = (0, 0, 0)

    # Slightly rotated second base layer for irregular outline
    base2 = add(generate_box(w=1.1, d=1.0, h=0.1, hex_color=E["pyro_dark"]))
    base2.name = "PyroBase2"
    base2.location = (0.1, -0.05, 0.08)
    base2.rotation_euler = (0, 0, math.radians(25))

    # -- Central tall peak --
    peak0 = add(generate_cone(radius_bottom=0.35, radius_top=0.0, height=1.2,
                              segments=6, hex_color=E["pyro_base"]))
    peak0.name = "PyroPeak_0"
    peak0.location = (0.0, 0.0, 0.1)

    # -- Secondary peak (shorter, tilted) --
    peak1 = add(generate_cone(radius_bottom=0.28, radius_top=0.0, height=0.85,
                              segments=5, hex_color=E["pyro_dark"]))
    peak1.name = "PyroPeak_1"
    peak1.location = (0.35, 0.2, 0.08)
    peak1.rotation_euler = (math.radians(12), math.radians(-8), 0)

    # -- Third peak (front, shorter and wider) --
    peak2 = add(generate_cone(radius_bottom=0.22, radius_top=0.0, height=0.65,
                              segments=5, hex_color=E["pyro_hi"]))
    peak2.name = "PyroPeak_2"
    peak2.location = (-0.3, -0.25, 0.06)
    peak2.rotation_euler = (math.radians(-10), math.radians(15), 0)

    # -- Fourth peak (back right, thin and tall) --
    peak3 = add(generate_cone(radius_bottom=0.18, radius_top=0.0, height=0.95,
                              segments=5, hex_color=E["pyro_base"]))
    peak3.name = "PyroPeak_3"
    peak3.location = (-0.25, 0.35, 0.1)
    peak3.rotation_euler = (math.radians(8), math.radians(6), 0)

    # -- Small shard (tiny, sharp) --
    shard0 = add(generate_cone(radius_bottom=0.1, radius_top=0.0, height=0.45,
                               segments=4, hex_color=E["pyro_hi"]))
    shard0.name = "PyroShard_0"
    shard0.location = (0.45, -0.3, 0.05)
    shard0.rotation_euler = (math.radians(-15), math.radians(20), 0)

    # -- Another small shard --
    shard1 = add(generate_cone(radius_bottom=0.12, radius_top=0.0, height=0.5,
                               segments=4, hex_color=E["pyro_dark"]))
    shard1.name = "PyroShard_1"
    shard1.location = (0.15, -0.4, 0.05)
    shard1.rotation_euler = (math.radians(10), math.radians(-12), 0)

    # -- Glow fissure accents: small flat boxes at base representing cracks --
    fiss0 = add(generate_box(w=0.5, d=0.04, h=0.03, hex_color=E["pyro_glow"]))
    fiss0.name = "Fissure_0"
    fiss0.location = (0.1, 0.0, 0.15)
    fiss0.rotation_euler = (0, 0, math.radians(30))

    fiss1 = add(generate_box(w=0.35, d=0.04, h=0.03, hex_color=E["pyro_glow"]))
    fiss1.name = "Fissure_1"
    fiss1.location = (-0.15, 0.15, 0.13)
    fiss1.rotation_euler = (0, 0, math.radians(-45))

    fiss2 = add(generate_box(w=0.3, d=0.04, h=0.03, hex_color=E["pyro_glow"]))
    fiss2.name = "Fissure_2"
    fiss2.location = (0.2, -0.2, 0.12)
    fiss2.rotation_euler = (0, 0, math.radians(70))

    # -- Rubble chunks at base --
    rub0 = add(generate_box(w=0.2, d=0.18, h=0.12, hex_color=E["pyro_deep"]))
    rub0.name = "Rubble_0"
    rub0.location = (0.5, 0.15, 0.04)
    rub0.rotation_euler = (0, 0, math.radians(40))

    rub1 = add(generate_box(w=0.15, d=0.12, h=0.1, hex_color=E["pyro_dark"]))
    rub1.name = "Rubble_1"
    rub1.location = (-0.45, -0.1, 0.03)
    rub1.rotation_euler = (0, 0, math.radians(-30))

    return {
        "root": root,
        "peaks": [peak0, peak1, peak2, peak3],
        "shards": [shard0, shard1],
        "base": base,
    }


def bake_pyromite_animations(objects):
    """Pyromite idle: subtle flicker-like shake on peaks + scale pulse."""
    peaks = objects["peaks"]
    shards = objects["shards"]

    # Main peaks get a tiny shake (volcanic tremor)
    for peak in peaks:
        animate_shake(peak, "idle", duration=2.0, amplitude=0.008, frequency=6)

    # Shards get a scale pulse (heat shimmer)
    for shard in shards:
        animate_scale_pulse(shard, "idle", duration=2.0, axis='Z',
                            amplitude=0.04, frequency=1.5)

    # Base stays still
    animate_static(objects["base"], "idle", duration=2.0)


# ===========================================================================
# CRYSTALLINE -- Clean geometric hexagonal prisms
# ===========================================================================
def build_crystalline():
    """Build a crystal cluster deposit using the crystal prefab."""
    clear_scene()

    root = bpy.data.objects.new("Crystalline", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # -- Ground base slab (icy stone) --
    base = add(generate_box(w=1.3, d=1.2, h=0.1, hex_color=E["cryst_deep"]))
    base.name = "CrystBase"
    base.location = (0, 0, 0)

    # Second base layer, lighter
    base2 = add(generate_box(w=0.9, d=0.85, h=0.08, hex_color=E["cryst_dark"]))
    base2.name = "CrystBase2"
    base2.location = (0.05, -0.03, 0.06)
    base2.rotation_euler = (0, 0, math.radians(15))

    # -- Main crystal cluster (center) --
    cluster = add(generate_crystal(
        num_crystals=7, base_radius=0.15, base_height=0.7,
        tip_ratio=0.5, spread=0.35, seed=42,
        hex_color=E["cryst_base"]
    ))
    cluster.name = "CrystCluster_Main"
    cluster.location = (0, 0, 0.1)

    # -- Tall single crystal on the side --
    tall = add(generate_crystal(
        num_crystals=1, base_radius=0.12, base_height=1.1,
        tip_ratio=0.45, spread=0.0, seed=100,
        hex_color=E["cryst_hi"]
    ))
    tall.name = "CrystTall"
    tall.location = (0.3, -0.2, 0.08)
    tall.rotation_euler = (math.radians(-6), math.radians(8), 0)

    # -- Small crystal group (front) --
    small_front = add(generate_crystal(
        num_crystals=3, base_radius=0.1, base_height=0.45,
        tip_ratio=0.5, spread=0.2, seed=77,
        hex_color=E["cryst_base"]
    ))
    small_front.name = "CrystSmallFront"
    small_front.location = (-0.35, -0.25, 0.06)

    # -- Small crystal group (back right) --
    small_back = add(generate_crystal(
        num_crystals=2, base_radius=0.08, base_height=0.35,
        tip_ratio=0.6, spread=0.15, seed=55,
        hex_color=E["cryst_dark"]
    ))
    small_back.name = "CrystSmallBack"
    small_back.location = (0.15, 0.35, 0.06)

    # -- Tiny shard cluster (left) --
    tiny = add(generate_crystal(
        num_crystals=2, base_radius=0.06, base_height=0.25,
        tip_ratio=0.4, spread=0.1, seed=33,
        hex_color=E["cryst_hi"]
    ))
    tiny.name = "CrystTiny"
    tiny.location = (-0.4, 0.2, 0.04)

    # -- Glow accents: small flat hemispheres at base (frost patches) --
    frost0 = add(generate_hemisphere(radius=0.12, rings=2, segments=6,
                                     hex_color=E["cryst_glow"]))
    frost0.name = "Frost_0"
    frost0.location = (0.3, 0.15, 0.08)

    frost1 = add(generate_hemisphere(radius=0.08, rings=2, segments=6,
                                     hex_color=E["cryst_glow"]))
    frost1.name = "Frost_1"
    frost1.location = (-0.2, -0.1, 0.07)

    return {
        "root": root,
        "cluster": cluster,
        "tall": tall,
        "small_front": small_front,
        "small_back": small_back,
        "base": base,
    }


def bake_crystalline_animations(objects):
    """Crystalline idle: subtle scale pulse (resonant hum)."""
    # All crystal groups get a gentle Z-scale pulse
    for key in ["cluster", "tall", "small_front", "small_back"]:
        obj = objects[key]
        animate_scale_pulse(obj, "idle", duration=2.0, axis='Z',
                            amplitude=0.02, frequency=0.8)

    # Base stays still
    animate_static(objects["base"], "idle", duration=2.0)


# ===========================================================================
# BIOVINE -- Organic bulbous mushroom/coral formations
# ===========================================================================
def build_biovine():
    """Build an organic deposit from hemispheres, spheres, and cylinders."""
    clear_scene()

    root = bpy.data.objects.new("Biovine", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # -- Ground base: organic mound --
    base = add(generate_hemisphere(radius=0.7, rings=3, segments=10,
                                   hex_color=E["bio_deep"]))
    base.name = "BioBase"
    base.location = (0, 0, 0)
    base.scale = (1.0, 0.9, 0.2)  # Flatten into a mound

    # -- Central large mushroom cap --
    stem0 = add(generate_cylinder(radius=0.12, height=0.6, segments=8,
                                  hex_color=E["bio_dark"]))
    stem0.name = "Stem_0"
    stem0.location = (0, 0, 0.1)

    cap0 = add(generate_hemisphere(radius=0.35, rings=4, segments=10,
                                   hex_color=E["bio_base"]))
    cap0.name = "Cap_0"
    cap0.location = (0, 0, 0.65)

    # -- Second mushroom (shorter, tilted, to the right) --
    stem1 = add(generate_cylinder(radius=0.1, height=0.45, segments=8,
                                  hex_color=E["bio_dark"]))
    stem1.name = "Stem_1"
    stem1.location = (0.35, 0.1, 0.08)
    stem1.rotation_euler = (math.radians(10), math.radians(-8), 0)

    cap1 = add(generate_hemisphere(radius=0.28, rings=3, segments=10,
                                   hex_color=E["bio_hi"]))
    cap1.name = "Cap_1"
    cap1.location = (0.38, 0.07, 0.5)

    # -- Third mushroom (small, front-left) --
    stem2 = add(generate_cylinder(radius=0.07, height=0.35, segments=6,
                                  hex_color=E["bio_deep"]))
    stem2.name = "Stem_2"
    stem2.location = (-0.3, -0.25, 0.06)
    stem2.rotation_euler = (math.radians(-8), math.radians(12), 0)

    cap2 = add(generate_hemisphere(radius=0.2, rings=3, segments=8,
                                   hex_color=E["bio_base"]))
    cap2.name = "Cap_2"
    cap2.location = (-0.32, -0.27, 0.38)

    # -- Bulb cluster (back left) -- spherical growths --
    bulb0 = add(generate_sphere(radius=0.18, rings=4, segments=8,
                                hex_color=E["bio_hi"]))
    bulb0.name = "Bulb_0"
    bulb0.location = (-0.25, 0.3, 0.15)

    bulb1 = add(generate_sphere(radius=0.12, rings=3, segments=6,
                                hex_color=E["bio_base"]))
    bulb1.name = "Bulb_1"
    bulb1.location = (-0.15, 0.4, 0.08)

    # -- Small tendril bumps at ground level --
    bump0 = add(generate_hemisphere(radius=0.1, rings=2, segments=6,
                                    hex_color=E["bio_dark"]))
    bump0.name = "Bump_0"
    bump0.location = (0.4, -0.3, 0.04)

    bump1 = add(generate_hemisphere(radius=0.08, rings=2, segments=6,
                                    hex_color=E["bio_dark"]))
    bump1.name = "Bump_1"
    bump1.location = (-0.4, -0.05, 0.03)

    # -- Glow spots: tiny bright spheres on cap surfaces --
    glow0 = add(generate_sphere(radius=0.04, rings=2, segments=6,
                                hex_color=E["bio_glow"]))
    glow0.name = "Glow_0"
    glow0.location = (0.08, 0.05, 0.98)

    glow1 = add(generate_sphere(radius=0.03, rings=2, segments=6,
                                hex_color=E["bio_glow"]))
    glow1.name = "Glow_1"
    glow1.location = (0.42, 0.08, 0.76)

    glow2 = add(generate_sphere(radius=0.035, rings=2, segments=6,
                                hex_color=E["bio_glow"]))
    glow2.name = "Glow_2"
    glow2.location = (-0.28, -0.22, 0.56)

    return {
        "root": root,
        "caps": [cap0, cap1, cap2],
        "bulbs": [bulb0, bulb1],
        "base": base,
    }


def bake_biovine_animations(objects):
    """Biovine idle: organic breathing pulse on caps and bulbs."""
    # Caps breathe (Z-scale pulse, slow)
    for i, cap in enumerate(objects["caps"]):
        # Slightly offset frequency per cap for organic feel
        freq = 0.6 + 0.15 * i
        animate_scale_pulse(cap, "idle", duration=2.0, axis='Z',
                            amplitude=0.05, frequency=freq)

    # Bulbs pulse slightly
    for bulb in objects["bulbs"]:
        animate_scale_pulse(bulb, "idle", duration=2.0, axis='Z',
                            amplitude=0.03, frequency=0.9)

    # Base stays still
    animate_static(objects["base"], "idle", duration=2.0)


# ===========================================================================
# Main — build all 3 deposits
# ===========================================================================
OUTPUT_DIR = os.path.join(REPO_ROOT, "resources", "deposits", "models")


def build_and_export(name, build_fn, anim_fn):
    """Build a deposit, bake animations, and export flat + textured versions."""
    print(f"\n{'='*60}")
    print(f"[deposit] Building {name}...")
    print(f"{'='*60}")

    # -- FLAT version (palette colors only) --
    objects = build_fn()
    anim_fn(objects)

    flat_path = os.path.join(OUTPUT_DIR, f"{name}_flat.glb")
    export_glb(flat_path)
    print(f"[deposit] Exported flat: {flat_path}")

    # -- TEXTURED version --
    # Rebuild from scratch to get clean materials
    objects = build_fn()
    anim_fn(objects)

    # Apply textures based on deposit type
    textured_ok = False
    if name == "pyromite":
        textured_ok = _apply_pyromite_textures(objects)
    elif name == "crystalline":
        textured_ok = _apply_crystalline_textures(objects)
    elif name == "biovine":
        textured_ok = _apply_biovine_textures(objects)

    tex_path = os.path.join(OUTPUT_DIR, f"{name}.glb")
    export_glb(tex_path)
    print(f"[deposit] Exported textured: {tex_path}")


def _apply_pyromite_textures(objects):
    """Try to apply rocky textures to pyromite base/rubble only.

    Peaks and shards keep their flat palette colors so the fire-element
    identity reads clearly. Only the ground base gets a rock texture.
    """
    root = objects["root"]
    success = True
    for child in root.children:
        if child.type != 'MESH':
            continue
        name = child.name.lower()
        # Peaks and shards keep flat palette colors for strong color identity
        if "peak" in name or "shard" in name or "fissure" in name:
            pass
        elif "base" in name or "rubble" in name:
            if not try_apply_texture(child, "rock_ground_02", resolution="1k"):
                success = False
    return success


def _apply_crystalline_textures(objects):
    """Try to apply ice/mineral textures to crystalline pieces."""
    root = objects["root"]
    success = True
    for child in root.children:
        if child.type != 'MESH':
            continue
        name = child.name.lower()
        if "cryst" in name and "base" not in name:
            # Crystals look best with flat colors -- skip textures
            pass
        elif "base" in name:
            if not try_apply_texture(child, "rock_ground_02", resolution="1k"):
                success = False
        # Frost patches keep their glow color
    return success


def _apply_biovine_textures(objects):
    """Try to apply organic textures to biovine pieces."""
    root = objects["root"]
    success = True
    for child in root.children:
        if child.type != 'MESH':
            continue
        name = child.name.lower()
        if "cap" in name or "bulb" in name:
            # Organic surfaces -- keep flat for stylistic consistency
            pass
        elif "stem" in name:
            if not try_apply_texture(child, "bark_willow", resolution="1k"):
                success = False
        elif "base" in name:
            if not try_apply_texture(child, "forested_ground_01", resolution="1k"):
                success = False
    return success


def main():
    print("[deposit] Starting deposit model generation...")
    print(f"[deposit] Output directory: {OUTPUT_DIR}")

    build_and_export("pyromite", build_pyromite, bake_pyromite_animations)
    build_and_export("crystalline", build_crystalline, bake_crystalline_animations)
    build_and_export("biovine", build_biovine, bake_biovine_animations)

    print("\n[deposit] All deposits complete!")
    print(f"[deposit] Files in: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
