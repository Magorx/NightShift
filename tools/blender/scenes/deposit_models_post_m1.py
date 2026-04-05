"""Generate 3D models for post-M1 elemental deposits: Voltite, Umbrite, Resonite.

Each deposit is a distinct mineral formation with a unique silhouette:
- Voltite (lightning): jagged angular spikes like crystallized electricity
- Umbrite (shadow): amorphous blobby mass with faint inner glow spots
- Resonite (force): clean crystal formation with resonance torus rings

Two versions per deposit (flat palette + textured PBR), same as M1 deposits.

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/deposit_models_post_m1.py
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
from prefabs_src.torus import generate_torus
from prefabs_src.wedge import generate_wedge
from anim_helpers import animate_rotation, animate_static, animate_shake, FPS

# Load elemental palette
E = load_palette("elements")


# ---------------------------------------------------------------------------
# Animation helpers (same as deposit_models.py)
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
    """Animate a subtle scale pulse on one axis (breathing effect)."""
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
    obj.scale[axis_idx] = 1.0


def animate_scale_static(obj, state_name, duration=2.0):
    """Hold scale at (1,1,1) for a state."""
    frames = int(FPS * duration)

    action_name = f"{state_name}_{obj.name}"
    act = bpy.data.actions.new(action_name)
    _ensure_anim_data(obj).action = act

    obj.scale = (1, 1, 1)
    obj.keyframe_insert(data_path="scale", frame=1)
    obj.keyframe_insert(data_path="scale", frame=frames + 1)

    _set_linear(act)
    _push_to_nla(obj, act, state_name)


def animate_translation_oscillate(obj, state_name, duration=2.0, axis='Z',
                                  amplitude=0.02, frequency=1.0, base_value=None):
    """Animate a position oscillation on one axis."""
    axis_idx = {'X': 0, 'Y': 1, 'Z': 2}[axis.upper()]
    frames = int(FPS * duration)

    if base_value is None:
        base_value = obj.location[axis_idx]

    action_name = f"{state_name}_{obj.name}"
    act = bpy.data.actions.new(action_name)
    _ensure_anim_data(obj).action = act

    for f in range(frames + 1):
        t = f / frames
        val = base_value + amplitude * math.sin(2 * math.pi * frequency * t)
        obj.location[axis_idx] = val
        obj.keyframe_insert(data_path="location", index=axis_idx, frame=f + 1)

    _set_linear(act)
    _push_to_nla(obj, act, state_name)
    obj.location[axis_idx] = base_value


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
# VOLTITE -- Jagged angular lightning-bolt spikes
# ===========================================================================
def build_voltite():
    """Build a jagged, angular deposit of crystallized electricity.

    Uses thin wedges and boxes at sharp angles to create zig-zag
    lightning-bolt geometry. Thicker base rocks anchor the formation.
    Purple accent pieces add electric contrast.
    """
    clear_scene()

    root = bpy.data.objects.new("Voltite", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # -- Ground base: rough angular slab --
    base = add(generate_box(w=1.3, d=1.2, h=0.1, hex_color=E["volt_deep"]))
    base.name = "VoltBase"
    base.location = (0, 0, 0)

    # Irregular second base layer
    base2 = add(generate_box(w=1.0, d=0.9, h=0.08, hex_color=E["volt_dark"]))
    base2.name = "VoltBase2"
    base2.location = (0.08, -0.06, 0.06)
    base2.rotation_euler = (0, 0, math.radians(20))

    # -- Central lightning bolt: tall zig-zag spike --
    # Lower segment (thick, leaning right)
    bolt_lo = add(generate_box(w=0.18, d=0.12, h=0.5, hex_color=E["volt_base"]))
    bolt_lo.name = "Bolt_Lo"
    bolt_lo.location = (-0.05, 0.0, 0.1)
    bolt_lo.rotation_euler = (0, math.radians(12), math.radians(-8))

    # Upper segment (thinner, leaning opposite direction = zig-zag)
    bolt_hi = add(generate_box(w=0.14, d=0.10, h=0.55, hex_color=E["volt_hi"]))
    bolt_hi.name = "Bolt_Hi"
    bolt_hi.location = (0.08, 0.02, 0.55)
    bolt_hi.rotation_euler = (0, math.radians(-15), math.radians(10))

    # Pointed tip wedge on top
    bolt_tip = add(generate_wedge(w=0.12, d=0.10, h_front=0.0, h_back=0.35,
                                  hex_color=E["volt_hi"]))
    bolt_tip.name = "Bolt_Tip"
    bolt_tip.location = (0.12, 0.0, 1.0)
    bolt_tip.rotation_euler = (math.radians(-80), math.radians(8), math.radians(5))

    # -- Second spike: shorter, to the right, sharp angle --
    spike1_lo = add(generate_box(w=0.14, d=0.10, h=0.35, hex_color=E["volt_dark"]))
    spike1_lo.name = "Spike1_Lo"
    spike1_lo.location = (0.35, 0.15, 0.08)
    spike1_lo.rotation_euler = (math.radians(8), math.radians(18), math.radians(-12))

    spike1_hi = add(generate_box(w=0.10, d=0.08, h=0.3, hex_color=E["volt_base"]))
    spike1_hi.name = "Spike1_Hi"
    spike1_hi.location = (0.42, 0.2, 0.4)
    spike1_hi.rotation_euler = (math.radians(-5), math.radians(-20), math.radians(15))

    # -- Third spike: front-left, short and wide --
    spike2 = add(generate_box(w=0.20, d=0.08, h=0.4, hex_color=E["volt_base"]))
    spike2.name = "Spike2"
    spike2.location = (-0.3, -0.25, 0.06)
    spike2.rotation_euler = (math.radians(-10), math.radians(22), math.radians(5))

    # -- Fourth spike: back, thin and sharp --
    spike3 = add(generate_wedge(w=0.10, d=0.08, h_front=0.0, h_back=0.5,
                                hex_color=E["volt_hi"]))
    spike3.name = "Spike3"
    spike3.location = (-0.2, 0.35, 0.1)
    spike3.rotation_euler = (math.radians(-75), math.radians(-10), math.radians(20))

    # -- Purple accent bolts: small diagonal shards for electric contrast --
    purp0 = add(generate_box(w=0.06, d=0.05, h=0.3, hex_color=E["volt_purple"]))
    purp0.name = "Purple_0"
    purp0.location = (0.15, -0.15, 0.15)
    purp0.rotation_euler = (math.radians(20), math.radians(-30), math.radians(45))

    purp1 = add(generate_box(w=0.05, d=0.04, h=0.25, hex_color=E["volt_purple"]))
    purp1.name = "Purple_1"
    purp1.location = (-0.1, 0.2, 0.2)
    purp1.rotation_euler = (math.radians(-15), math.radians(25), math.radians(-35))

    purp2 = add(generate_box(w=0.05, d=0.04, h=0.2, hex_color=E["volt_purple"]))
    purp2.name = "Purple_2"
    purp2.location = (0.3, -0.1, 0.3)
    purp2.rotation_euler = (math.radians(25), math.radians(15), math.radians(60))

    # -- Electric fissure lines at base (bright yellow cracks) --
    fiss0 = add(generate_box(w=0.45, d=0.03, h=0.025, hex_color=E["volt_hi"]))
    fiss0.name = "VoltFissure_0"
    fiss0.location = (0.05, 0.0, 0.12)
    fiss0.rotation_euler = (0, 0, math.radians(25))

    fiss1 = add(generate_box(w=0.3, d=0.03, h=0.025, hex_color=E["volt_hi"]))
    fiss1.name = "VoltFissure_1"
    fiss1.location = (-0.1, 0.15, 0.11)
    fiss1.rotation_euler = (0, 0, math.radians(-50))

    # -- Rubble chunks --
    rub0 = add(generate_box(w=0.18, d=0.15, h=0.1, hex_color=E["volt_deep"]))
    rub0.name = "VoltRubble_0"
    rub0.location = (0.45, -0.2, 0.04)
    rub0.rotation_euler = (0, 0, math.radians(35))

    rub1 = add(generate_box(w=0.12, d=0.10, h=0.08, hex_color=E["volt_dark"]))
    rub1.name = "VoltRubble_1"
    rub1.location = (-0.4, -0.15, 0.03)
    rub1.rotation_euler = (0, 0, math.radians(-20))

    return {
        "root": root,
        "spikes": [bolt_lo, bolt_hi, bolt_tip, spike1_lo, spike1_hi, spike2, spike3],
        "purples": [purp0, purp1, purp2],
        "base": base,
    }


def bake_voltite_animations(objects):
    """Voltite idle: rapid tiny shake on spikes (electric crackle)."""
    # Spikes get a rapid, small shake (crackling electricity)
    for spike in objects["spikes"]:
        animate_shake(spike, "idle", duration=2.0, amplitude=0.006, frequency=12)

    # Purple accents get an even faster, subtler shake
    for purp in objects["purples"]:
        animate_shake(purp, "idle", duration=2.0, amplitude=0.004, frequency=16)

    # Base stays still
    animate_static(objects["base"], "idle", duration=2.0)


# ===========================================================================
# UMBRITE -- Amorphous shadowy blob mass
# ===========================================================================
def build_umbrite():
    """Build an amorphous, blobby shadow deposit.

    Uses hemispheres and spheres merged together to form a dark,
    unsettling mass. Small glowing spheres partially embedded suggest
    faint inner light. Smooth, organic, unlike the angular deposits.
    """
    clear_scene()

    root = bpy.data.objects.new("Umbrite", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # -- Ground shadow pool: very flat dark hemisphere --
    pool = add(generate_hemisphere(radius=0.8, rings=3, segments=12,
                                   hex_color=E["umb_deep"]))
    pool.name = "UmbPool"
    pool.location = (0, 0, 0)
    pool.scale = (1.0, 0.95, 0.1)  # Very flat shadow pool

    # -- Central mass: large dark hemisphere --
    mass_main = add(generate_hemisphere(radius=0.45, rings=4, segments=10,
                                        hex_color=E["umb_base"]))
    mass_main.name = "UmbMass_Main"
    mass_main.location = (0.0, 0.0, 0.05)
    mass_main.scale = (1.0, 0.85, 1.0)  # Slightly squished for irregularity

    # -- Secondary blob: large sphere partially buried --
    blob1 = add(generate_sphere(radius=0.32, rings=5, segments=10,
                                hex_color=E["umb_dark"]))
    blob1.name = "UmbBlob_1"
    blob1.location = (0.3, 0.15, 0.1)

    # -- Third blob: hemisphere to the left --
    blob2 = add(generate_hemisphere(radius=0.28, rings=3, segments=8,
                                    hex_color=E["umb_base"]))
    blob2.name = "UmbBlob_2"
    blob2.location = (-0.3, -0.1, 0.06)
    blob2.scale = (1.1, 0.9, 0.8)

    # -- Fourth blob: small, back --
    blob3 = add(generate_sphere(radius=0.2, rings=4, segments=8,
                                hex_color=E["umb_hi"]))
    blob3.name = "UmbBlob_3"
    blob3.location = (-0.15, 0.35, 0.08)

    # -- Fifth blob: tiny tendril bump, front-right --
    blob4 = add(generate_hemisphere(radius=0.15, rings=2, segments=6,
                                    hex_color=E["umb_dark"]))
    blob4.name = "UmbBlob_4"
    blob4.location = (0.4, -0.25, 0.04)

    # -- Sixth blob: small dark lump on top of main mass --
    blob5 = add(generate_hemisphere(radius=0.18, rings=3, segments=8,
                                    hex_color=E["umb_dark"]))
    blob5.name = "UmbBlob_5"
    blob5.location = (0.05, -0.05, 0.42)

    # -- Wispy tendril protrusions: elongated hemispheres reaching outward --
    tendril0 = add(generate_hemisphere(radius=0.12, rings=2, segments=6,
                                       hex_color=E["umb_base"]))
    tendril0.name = "UmbTendril_0"
    tendril0.location = (0.55, 0.0, 0.05)
    tendril0.scale = (1.8, 0.6, 0.4)  # Elongated

    tendril1 = add(generate_hemisphere(radius=0.10, rings=2, segments=6,
                                       hex_color=E["umb_base"]))
    tendril1.name = "UmbTendril_1"
    tendril1.location = (-0.5, 0.15, 0.04)
    tendril1.scale = (1.5, 0.5, 0.35)
    tendril1.rotation_euler = (0, 0, math.radians(30))

    tendril2 = add(generate_hemisphere(radius=0.09, rings=2, segments=6,
                                       hex_color=E["umb_dark"]))
    tendril2.name = "UmbTendril_2"
    tendril2.location = (0.1, -0.45, 0.03)
    tendril2.scale = (0.6, 1.6, 0.3)

    # -- Glow spots: small bright spheres partially embedded (inner glow) --
    glow0 = add(generate_sphere(radius=0.06, rings=3, segments=6,
                                hex_color=E["umb_glow"]))
    glow0.name = "UmbGlow_0"
    glow0.location = (0.1, 0.08, 0.38)

    glow1 = add(generate_sphere(radius=0.045, rings=3, segments=6,
                                hex_color=E["umb_glow"]))
    glow1.name = "UmbGlow_1"
    glow1.location = (0.32, 0.18, 0.28)

    glow2 = add(generate_sphere(radius=0.05, rings=3, segments=6,
                                hex_color=E["umb_glow"]))
    glow2.name = "UmbGlow_2"
    glow2.location = (-0.22, -0.05, 0.22)

    glow3 = add(generate_sphere(radius=0.035, rings=2, segments=6,
                                hex_color=E["umb_glow"]))
    glow3.name = "UmbGlow_3"
    glow3.location = (-0.1, 0.3, 0.18)

    glow4 = add(generate_sphere(radius=0.04, rings=2, segments=6,
                                hex_color=E["umb_hi"]))
    glow4.name = "UmbGlow_4"
    glow4.location = (0.15, -0.15, 0.15)

    return {
        "root": root,
        "blobs": [mass_main, blob1, blob2, blob3, blob4, blob5],
        "tendrils": [tendril0, tendril1, tendril2],
        "glows": [glow0, glow1, glow2, glow3, glow4],
        "base": pool,
    }


def bake_umbrite_animations(objects):
    """Umbrite idle: slow pulsing (shadow breathing) on blobs and tendrils."""
    # Main blobs get a slow Z-scale pulse (breathing)
    for i, blob in enumerate(objects["blobs"]):
        freq = 0.4 + 0.1 * i  # Slightly offset for organic feel
        animate_scale_pulse(blob, "idle", duration=2.0, axis='Z',
                            amplitude=0.04, frequency=freq)

    # Tendrils get a subtle X-scale pulse (reaching/retracting)
    for tendril in objects["tendrils"]:
        animate_scale_pulse(tendril, "idle", duration=2.0, axis='X',
                            amplitude=0.06, frequency=0.5)

    # Glow spots oscillate in Y position (floating within the mass)
    for glow in objects["glows"]:
        animate_translation_oscillate(glow, "idle", duration=2.0, axis='Z',
                                      amplitude=0.015, frequency=0.7)

    # Base stays still
    animate_static(objects["base"], "idle", duration=2.0)


# ===========================================================================
# RESONITE -- Geometric crystal formation with resonance torus rings
# ===========================================================================
def build_resonite():
    """Build a clean, geometric crystal formation with floating torus rings.

    Central crystal cluster (silver/white) with torus rings at various
    angles suggesting resonance vibration. The shape should feel precise
    and engineered, like a tuning fork meets quartz.
    """
    clear_scene()

    root = bpy.data.objects.new("Resonite", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # -- Ground base: clean geometric slab --
    base = add(generate_box(w=1.2, d=1.1, h=0.1, hex_color=E["res_deep"]))
    base.name = "ResBase"
    base.location = (0, 0, 0)

    base2 = add(generate_box(w=0.85, d=0.8, h=0.07, hex_color=E["res_dark"]))
    base2.name = "ResBase2"
    base2.location = (0.03, -0.02, 0.06)
    base2.rotation_euler = (0, 0, math.radians(10))

    # -- Central crystal cluster (tall, precise hexagonal prisms) --
    cluster_main = add(generate_crystal(
        num_crystals=5, base_radius=0.14, base_height=0.8,
        tip_ratio=0.4, spread=0.3, seed=200,
        hex_color=E["res_base"]
    ))
    cluster_main.name = "ResCluster_Main"
    cluster_main.location = (0, 0, 0.1)

    # -- Tall single crystal (dominant, taller than M1 crystalline for distinction) --
    tall = add(generate_crystal(
        num_crystals=1, base_radius=0.11, base_height=1.0,
        tip_ratio=0.35, spread=0.0, seed=210,
        hex_color=E["res_hi"]
    ))
    tall.name = "ResTall"
    tall.location = (0.05, 0.05, 0.1)

    # -- Small crystal group (front-right) --
    small_fr = add(generate_crystal(
        num_crystals=3, base_radius=0.09, base_height=0.4,
        tip_ratio=0.5, spread=0.18, seed=220,
        hex_color=E["res_base"]
    ))
    small_fr.name = "ResSmallFR"
    small_fr.location = (0.3, -0.2, 0.07)

    # -- Small crystal group (back-left) --
    small_bl = add(generate_crystal(
        num_crystals=2, base_radius=0.07, base_height=0.3,
        tip_ratio=0.45, spread=0.12, seed=230,
        hex_color=E["res_dark"]
    ))
    small_bl.name = "ResSmallBL"
    small_bl.location = (-0.25, 0.25, 0.06)

    # -- Torus ring 1: large, around the base of the central cluster --
    ring0 = add(generate_torus(major_radius=0.35, minor_radius=0.04,
                               major_segments=16, minor_segments=6,
                               hex_color=E["res_glow"]))
    ring0.name = "ResRing_0"
    ring0.location = (0.0, 0.0, 0.35)
    ring0.rotation_euler = (math.radians(5), math.radians(-3), 0)

    # -- Torus ring 2: medium, tilted at mid-height --
    ring1 = add(generate_torus(major_radius=0.22, minor_radius=0.03,
                               major_segments=14, minor_segments=6,
                               hex_color=E["res_hi"]))
    ring1.name = "ResRing_1"
    ring1.location = (0.05, 0.03, 0.65)
    ring1.rotation_euler = (math.radians(12), math.radians(-8), math.radians(15))

    # -- Torus ring 3: small, near the top, more tilted --
    ring2 = add(generate_torus(major_radius=0.15, minor_radius=0.025,
                               major_segments=12, minor_segments=6,
                               hex_color=E["res_glow"]))
    ring2.name = "ResRing_2"
    ring2.location = (0.03, 0.05, 0.9)
    ring2.rotation_euler = (math.radians(-10), math.radians(15), math.radians(-20))

    # -- Torus ring 4: tiny, at ground level around small cluster --
    ring3 = add(generate_torus(major_radius=0.18, minor_radius=0.02,
                               major_segments=12, minor_segments=6,
                               hex_color=E["res_hi"]))
    ring3.name = "ResRing_3"
    ring3.location = (0.3, -0.2, 0.2)
    ring3.rotation_euler = (math.radians(8), math.radians(5), 0)

    # -- Glow accent hemispheres at base (resonance ground effects) --
    glow0 = add(generate_hemisphere(radius=0.08, rings=2, segments=6,
                                    hex_color=E["res_glow"]))
    glow0.name = "ResGlow_0"
    glow0.location = (0.2, 0.15, 0.08)

    glow1 = add(generate_hemisphere(radius=0.06, rings=2, segments=6,
                                    hex_color=E["res_glow"]))
    glow1.name = "ResGlow_1"
    glow1.location = (-0.15, -0.12, 0.07)

    return {
        "root": root,
        "crystals": [cluster_main, tall, small_fr, small_bl],
        "rings": [ring0, ring1, ring2, ring3],
        "base": base,
    }


def bake_resonite_animations(objects):
    """Resonite idle: torus rings oscillate (resonance vibration) + crystals pulse subtly."""
    # Rings oscillate in Z position (floating/vibrating)
    for i, ring in enumerate(objects["rings"]):
        freq = 0.8 + 0.2 * i  # Each ring at slightly different frequency
        amp = 0.025 - 0.004 * i  # Larger rings move more
        animate_translation_oscillate(ring, "idle", duration=2.0, axis='Z',
                                      amplitude=amp, frequency=freq)

    # Crystals get a very subtle Z-scale pulse (resonant hum)
    for crystal in objects["crystals"]:
        animate_scale_pulse(crystal, "idle", duration=2.0, axis='Z',
                            amplitude=0.015, frequency=0.6)

    # Base stays still
    animate_static(objects["base"], "idle", duration=2.0)


# ===========================================================================
# Texture application (same pattern as M1)
# ===========================================================================
def _apply_voltite_textures(objects):
    """Apply rocky textures to Voltite base/rubble. Spikes keep flat colors."""
    root = objects["root"]
    success = True
    for child in root.children:
        if child.type != 'MESH':
            continue
        name = child.name.lower()
        if "base" in name or "rubble" in name:
            if not try_apply_texture(child, "rock_ground_02", resolution="1k"):
                success = False
    return success


def _apply_umbrite_textures(objects):
    """Apply organic textures to Umbrite base. Blobs/glows keep flat colors."""
    root = objects["root"]
    success = True
    for child in root.children:
        if child.type != 'MESH':
            continue
        name = child.name.lower()
        if "pool" in name:
            if not try_apply_texture(child, "rock_ground_02", resolution="1k"):
                success = False
    return success


def _apply_resonite_textures(objects):
    """Apply mineral textures to Resonite base. Crystals/rings keep flat colors."""
    root = objects["root"]
    success = True
    for child in root.children:
        if child.type != 'MESH':
            continue
        name = child.name.lower()
        if "base" in name:
            if not try_apply_texture(child, "rock_ground_02", resolution="1k"):
                success = False
    return success


# ===========================================================================
# Main -- build all 3 post-M1 deposits
# ===========================================================================
OUTPUT_DIR = os.path.join(REPO_ROOT, "resources", "deposits", "models")


def build_and_export(name, build_fn, anim_fn, texture_fn):
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
    objects = build_fn()
    anim_fn(objects)
    texture_fn(objects)

    tex_path = os.path.join(OUTPUT_DIR, f"{name}.glb")
    export_glb(tex_path)
    print(f"[deposit] Exported textured: {tex_path}")


def main():
    print("[deposit] Starting post-M1 deposit model generation...")
    print(f"[deposit] Output directory: {OUTPUT_DIR}")

    build_and_export("voltite", build_voltite, bake_voltite_animations,
                     _apply_voltite_textures)
    build_and_export("umbrite", build_umbrite, bake_umbrite_animations,
                     _apply_umbrite_textures)
    build_and_export("resonite", build_resonite, bake_resonite_animations,
                     _apply_resonite_textures)

    print("\n[deposit] All post-M1 deposits complete!")
    print(f"[deposit] Files in: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
