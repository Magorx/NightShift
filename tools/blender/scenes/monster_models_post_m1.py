"""Generate Acid Bloom and Phase Shifter monster models (.glb) for Godot import.

Acid Bloom: A monstrous flower/fungus that corrodes everything in an area.
    Central stem, radiating petals, dripping acid, pulsing core.
    Psychedelic toxic green/pink/yellow palette.

Phase Shifter: A teleporting geometric entity that disrupts factory layout.
    Tesseract/hypercube aesthetic -- angular body, orbiting rings, floating fragments.
    Electric blue/white/void palette.

Both monsters have: idle (2s) and attack (1s) animation states.
Two versions each: flat (palette colors) and textured (PBR surfaces).

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/monster_models_post_m1.py
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
from prefabs_src.hemisphere import generate_hemisphere
from prefabs_src.cylinder import generate_cylinder
from prefabs_src.cone import generate_cone
from prefabs_src.torus import generate_torus
from prefabs_src.box import generate_box
from anim_helpers import (
    animate_rotation, animate_translation, animate_shake, animate_static,
    FPS,
)

# ===========================================================================
# Shared animation helpers (same pattern as tendril_crawler_model.py)
# ===========================================================================

def _ensure_anim_data(obj):
    if obj.animation_data is None:
        obj.animation_data_create()
    return obj.animation_data


def _set_linear(action):
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
                        amplitude=0.05, frequency=1.0, phase=0.0):
    """Scale oscillation: 1 + amplitude * sin(2pi*freq*t + phase)."""
    axis_idx = {'X': 0, 'Y': 1, 'Z': 2}[axis.upper()]
    frames = int(FPS * duration)
    act = bpy.data.actions.new(f"{state_name}_{obj.name}")
    _ensure_anim_data(obj).action = act
    for f in range(frames + 1):
        t = f / frames
        val = 1.0 + amplitude * math.sin(2 * math.pi * frequency * t + phase)
        obj.scale[axis_idx] = val
        obj.keyframe_insert(data_path="scale", index=axis_idx, frame=f + 1)
    _set_linear(act)
    _push_to_nla(obj, act, state_name)
    obj.scale[axis_idx] = 1.0


def animate_scale_uniform(obj, state_name, duration=2.0,
                          amplitude=0.05, frequency=1.0, phase=0.0):
    """Uniform XYZ scale oscillation."""
    frames = int(FPS * duration)
    act = bpy.data.actions.new(f"{state_name}_{obj.name}")
    _ensure_anim_data(obj).action = act
    for f in range(frames + 1):
        t = f / frames
        val = 1.0 + amplitude * math.sin(2 * math.pi * frequency * t + phase)
        obj.scale = (val, val, val)
        for idx in range(3):
            obj.keyframe_insert(data_path="scale", index=idx, frame=f + 1)
    _set_linear(act)
    _push_to_nla(obj, act, state_name)
    obj.scale = (1, 1, 1)


def animate_scale_multi(obj, state_name, duration=2.0, per_axis=None):
    """Multi-axis scale animation in a single action."""
    frames = int(FPS * duration)
    act = bpy.data.actions.new(f"{state_name}_{obj.name}")
    _ensure_anim_data(obj).action = act
    axis_params = {}
    for (axis_idx, amp, freq, ph) in (per_axis or []):
        axis_params[axis_idx] = (amp, freq, ph)
    for f in range(frames + 1):
        t = f / frames
        for idx in range(3):
            if idx in axis_params:
                amp, freq, ph = axis_params[idx]
                val = 1.0 + amp * math.sin(2 * math.pi * freq * t + ph)
            else:
                val = 1.0
            obj.scale[idx] = val
            obj.keyframe_insert(data_path="scale", index=idx, frame=f + 1)
    _set_linear(act)
    _push_to_nla(obj, act, state_name)
    obj.scale = (1, 1, 1)


def animate_rotation_oscillation(obj, state_name, duration=2.0, axis='X',
                                  amplitude=0.1, frequency=1.0, phase=0.0):
    """Rotation oscillation: amplitude * sin(2pi*freq*t + phase)."""
    axis_idx = {'X': 0, 'Y': 1, 'Z': 2}[axis.upper()]
    frames = int(FPS * duration)
    act = bpy.data.actions.new(f"{state_name}_{obj.name}")
    _ensure_anim_data(obj).action = act
    base_rot = obj.rotation_euler[axis_idx]
    for f in range(frames + 1):
        t = f / frames
        val = base_rot + amplitude * math.sin(2 * math.pi * frequency * t + phase)
        obj.rotation_euler[axis_idx] = val
        obj.keyframe_insert(data_path="rotation_euler", index=axis_idx, frame=f + 1)
    _set_linear(act)
    _push_to_nla(obj, act, state_name)
    obj.rotation_euler[axis_idx] = base_rot


def animate_translation_oscillation(obj, state_name, duration=2.0, axis='Z',
                                     amplitude=0.05, frequency=1.0, phase=0.0):
    """Translation oscillation around current position."""
    axis_idx = {'X': 0, 'Y': 1, 'Z': 2}[axis.upper()]
    frames = int(FPS * duration)
    act = bpy.data.actions.new(f"{state_name}_{obj.name}")
    _ensure_anim_data(obj).action = act
    base_val = obj.location[axis_idx]
    for f in range(frames + 1):
        t = f / frames
        val = base_val + amplitude * math.sin(2 * math.pi * frequency * t + phase)
        obj.location[axis_idx] = val
        obj.keyframe_insert(data_path="location", index=axis_idx, frame=f + 1)
    _set_linear(act)
    _push_to_nla(obj, act, state_name)
    obj.location[axis_idx] = base_val


def animate_scale_static(obj, state_name, duration=2.0):
    """Hold scale at (1,1,1)."""
    frames = int(FPS * duration)
    act = bpy.data.actions.new(f"{state_name}_{obj.name}")
    _ensure_anim_data(obj).action = act
    obj.scale = (1, 1, 1)
    for idx in range(3):
        obj.keyframe_insert(data_path="scale", index=idx, frame=1)
        obj.keyframe_insert(data_path="scale", index=idx, frame=frames + 1)
    _set_linear(act)
    _push_to_nla(obj, act, state_name)


def animate_combined_translate_rotate(obj, state_name, duration=2.0,
                                       trans_axis='X', trans_amplitude=0.06,
                                       trans_frequency=0.3, trans_phase=0.0,
                                       rot_axis='Z', rot_total_angle=math.pi):
    """Combined translation oscillation + rotation in a single action.

    Avoids NLA channel conflicts when both translation and rotation
    are needed on the same object in the same animation state.
    """
    trans_idx = {'X': 0, 'Y': 1, 'Z': 2}[trans_axis.upper()]
    rot_idx = {'X': 0, 'Y': 1, 'Z': 2}[rot_axis.upper()]
    frames = int(FPS * duration)

    act = bpy.data.actions.new(f"{state_name}_{obj.name}")
    _ensure_anim_data(obj).action = act

    base_trans = obj.location[trans_idx]
    base_rot = obj.rotation_euler[rot_idx]

    for f in range(frames + 1):
        t = f / frames
        # Translation oscillation
        tval = base_trans + trans_amplitude * math.sin(
            2 * math.pi * trans_frequency * t + trans_phase)
        obj.location[trans_idx] = tval
        obj.keyframe_insert(data_path="location", index=trans_idx, frame=f + 1)

        # Rotation
        rval = base_rot + t * rot_total_angle
        obj.rotation_euler[rot_idx] = rval
        obj.keyframe_insert(data_path="rotation_euler", index=rot_idx, frame=f + 1)

    _set_linear(act)
    _push_to_nla(obj, act, state_name)
    obj.location[trans_idx] = base_trans
    obj.rotation_euler[rot_idx] = base_rot


# ===========================================================================
# ===========================================================================
#
#   ACID BLOOM -- Area Corrosion Monster
#
# ===========================================================================
# ===========================================================================

# Palette: toxic green/yellow/pink
AB_STEM_MAIN   = "#228B22"  # forest green
AB_STEM_DARK   = "#006400"  # dark green
AB_PETAL_MAIN  = "#FF1493"  # deep pink
AB_PETAL_ALT   = "#FF69B4"  # hot pink
AB_ACID_DRIP   = "#ADFF2F"  # green-yellow
AB_ACID_BRIGHT = "#7FFF00"  # chartreuse
AB_CORE        = "#FFD700"  # gold
AB_CORE_HOT    = "#FF4500"  # orange-red
AB_DARK        = "#002200"  # near-black green
AB_BASE_COLOR  = "#1A3A1A"  # dark mossy green for base mound
AB_VEIN_COLOR  = "#33FF33"  # neon green veins
AB_SPORE       = "#CCFF00"  # bright yellow-green spores


def build_acid_bloom():
    """Compose the Acid Bloom from prefab parts."""
    clear_scene()

    root = bpy.data.objects.new("AcidBloom", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # ==================================================================
    # BASE MOUND: amorphous hemisphere from which the bloom grows
    # ==================================================================
    base_mound = add(generate_hemisphere(radius=0.55, rings=5, segments=12,
                                          hex_color=AB_BASE_COLOR))
    base_mound.name = "BaseMound"
    base_mound.location = (0, 0, 0)
    base_mound.scale = (1.2, 1.2, 0.5)  # wide and squat

    # Secondary base lump -- asymmetry
    base_lump = add(generate_hemisphere(radius=0.3, rings=3, segments=10,
                                         hex_color=AB_STEM_DARK))
    base_lump.name = "BaseLump"
    base_lump.location = (0.3, -0.15, 0.0)
    base_lump.scale = (1.0, 0.8, 0.4)

    # Small root-like bumps around base
    root_bumps = []
    for i in range(4):
        angle = (i / 4) * 2 * math.pi + 0.3
        rx = 0.5 * math.cos(angle)
        ry = 0.5 * math.sin(angle)
        rb = add(generate_hemisphere(radius=0.12, rings=2, segments=6,
                                      hex_color=AB_STEM_DARK))
        rb.name = f"RootBump_{i}"
        rb.location = (rx, ry, 0.0)
        rb.scale = (1.0, 1.0, 0.6)
        root_bumps.append(rb)

    # ==================================================================
    # STEM: central tapered cylinder, slightly crooked
    # ==================================================================
    # Lower stem -- thick
    stem_lower = add(generate_cone(radius_bottom=0.2, radius_top=0.15,
                                    height=0.35, segments=10,
                                    hex_color=AB_STEM_MAIN))
    stem_lower.name = "StemLower"
    stem_lower.location = (0, 0, 0.2)

    # Upper stem -- thinner, slightly tilted for organic feel
    stem_upper = add(generate_cone(radius_bottom=0.15, radius_top=0.1,
                                    height=0.3, segments=10,
                                    hex_color=AB_STEM_MAIN))
    stem_upper.name = "StemUpper"
    stem_upper.location = (0.02, -0.02, 0.55)
    stem_upper.rotation_euler = (math.radians(5), math.radians(-3), 0)

    # Stem veins -- thin cylinders wrapped around stem
    stem_veins = []
    for i in range(3):
        angle = (i / 3) * 2 * math.pi
        v = add(generate_cylinder(radius=0.012, height=0.5, segments=4,
                                   hex_color=AB_VEIN_COLOR))
        v.name = f"StemVein_{i}"
        vx = 0.12 * math.cos(angle)
        vy = 0.12 * math.sin(angle)
        v.location = (vx, vy, 0.25)
        v.rotation_euler = (math.radians(3 + i * 2), math.radians(2 - i), 0)
        stem_veins.append(v)

    # ==================================================================
    # PETAL RING: 6 cone-based petals radiating outward from stem top
    # ==================================================================
    petal_count = 6
    petals = []
    for i in range(petal_count):
        angle = (i / petal_count) * 2 * math.pi
        # Alternate between main pink and alt pink
        color = AB_PETAL_MAIN if i % 2 == 0 else AB_PETAL_ALT

        # Each petal: a flattened cone tilted outward
        petal = add(generate_cone(radius_bottom=0.18, radius_top=0.04,
                                   height=0.35, segments=8,
                                   hex_color=color))
        petal.name = f"Petal_{i}"

        # Position at top of stem, radiating outward
        px = 0.12 * math.cos(angle)
        py = 0.12 * math.sin(angle)
        petal.location = (px, py, 0.8)

        # Tilt outward: rotate away from center + flatten
        # The cone grows upward, so we tilt it ~60 degrees outward
        tilt_angle = math.radians(55 + (i % 3) * 8)  # vary tilt slightly
        petal.rotation_euler = (tilt_angle, 0, angle + math.pi / 2)
        petal.scale = (1.0, 0.5, 1.0)  # flatten for petal shape

        petals.append(petal)

    # Inner petal ring -- smaller, more upright, different shade
    inner_petals = []
    for i in range(3):
        angle = (i / 3) * 2 * math.pi + math.radians(30)
        ipetal = add(generate_cone(radius_bottom=0.1, radius_top=0.02,
                                    height=0.2, segments=6,
                                    hex_color=AB_PETAL_ALT))
        ipetal.name = f"InnerPetal_{i}"
        ipx = 0.06 * math.cos(angle)
        ipy = 0.06 * math.sin(angle)
        ipetal.location = (ipx, ipy, 0.85)
        ipetal.rotation_euler = (math.radians(35), 0, angle + math.pi / 2)
        ipetal.scale = (0.8, 0.4, 1.0)
        inner_petals.append(ipetal)

    # ==================================================================
    # CORE: bright sphere visible inside the petal ring
    # ==================================================================
    core_main = add(generate_sphere(radius=0.12, rings=6, segments=10,
                                     hex_color=AB_CORE))
    core_main.name = "CoreMain"
    core_main.location = (0, 0, 0.88)

    core_hot = add(generate_sphere(radius=0.06, rings=4, segments=8,
                                    hex_color=AB_CORE_HOT))
    core_hot.name = "CoreHot"
    core_hot.location = (0, 0, 0.92)

    # ==================================================================
    # ACID DRIPS: small spheres hanging below petals like droplets
    # ==================================================================
    drips = []
    for i in range(8):
        angle = (i / 8) * 2 * math.pi + 0.2
        dr = 0.25 + (i % 3) * 0.08  # varying distance from center
        dx = dr * math.cos(angle)
        dy = dr * math.sin(angle)
        dz = 0.55 + (i % 2) * 0.1  # varying height

        drip_size = 0.025 + (i % 3) * 0.01
        drip_color = AB_ACID_DRIP if i % 2 == 0 else AB_ACID_BRIGHT

        drip = add(generate_sphere(radius=drip_size, rings=3, segments=6,
                                    hex_color=drip_color))
        drip.name = f"AcidDrip_{i}"
        drip.location = (dx, dy, dz)
        drip.scale = (0.8, 0.8, 1.3)  # elongated droplet shape
        drips.append(drip)

    # Extra large drips -- prominent acid drops
    for i in range(3):
        angle = (i / 3) * 2 * math.pi + 0.8
        dx = 0.35 * math.cos(angle)
        dy = 0.35 * math.sin(angle)
        big_drip = add(generate_sphere(radius=0.04, rings=4, segments=6,
                                        hex_color=AB_ACID_BRIGHT))
        big_drip.name = f"BigDrip_{i}"
        big_drip.location = (dx, dy, 0.45)
        big_drip.scale = (0.7, 0.7, 1.5)
        drips.append(big_drip)

    # ==================================================================
    # SPORE BUMPS: small bright hemispheres on stem and base
    # ==================================================================
    spore_data = [
        (0.15, 0.1, 0.3, 0.04, AB_SPORE),
        (-0.1, 0.15, 0.4, 0.035, AB_ACID_BRIGHT),
        (0.0, -0.18, 0.35, 0.03, AB_SPORE),
        (-0.2, -0.05, 0.15, 0.05, AB_ACID_DRIP),
        (0.25, 0.0, 0.1, 0.04, AB_SPORE),
    ]
    spores = []
    for i, (sx, sy, sz, sr, sc) in enumerate(spore_data):
        spore = add(generate_hemisphere(radius=sr, rings=2, segments=6,
                                         hex_color=sc))
        spore.name = f"Spore_{i}"
        spore.location = (sx, sy, sz)
        spores.append(spore)

    return {
        "root": root,
        "base_mound": base_mound,
        "stem_lower": stem_lower,
        "stem_upper": stem_upper,
        "stem_veins": stem_veins,
        "petals": petals,
        "inner_petals": inner_petals,
        "core_main": core_main,
        "core_hot": core_hot,
        "drips": drips,
        "spores": spores,
        "root_bumps": root_bumps,
    }


# ---------------------------------------------------------------------------
# Acid Bloom Animations
# ---------------------------------------------------------------------------

def bake_acid_bloom_animations(obj):
    """Bake idle (2s) and attack (1s) animations for Acid Bloom."""

    stem_lower = obj["stem_lower"]
    stem_upper = obj["stem_upper"]
    petals = obj["petals"]
    inner_petals = obj["inner_petals"]
    core_main = obj["core_main"]
    core_hot = obj["core_hot"]
    drips = obj["drips"]
    spores = obj["spores"]
    base_mound = obj["base_mound"]
    root_bumps = obj["root_bumps"]
    stem_veins = obj["stem_veins"]

    # ==================================================================
    # IDLE (2s): Gentle sway, core pulse, drips tremble
    # ==================================================================

    # Stem: gentle swaying
    animate_rotation_oscillation(stem_lower, "idle", duration=2.0, axis='X',
                                  amplitude=0.04, frequency=0.4)
    animate_rotation_oscillation(stem_upper, "idle", duration=2.0, axis='X',
                                  amplitude=0.06, frequency=0.5, phase=0.3)

    # Petals: gentle Z-rotation oscillation (swaying in breeze)
    for i, petal in enumerate(petals):
        phase = i * (2 * math.pi / len(petals))
        animate_rotation_oscillation(petal, "idle", duration=2.0, axis='Z',
                                      amplitude=0.08, frequency=0.3 + i * 0.05,
                                      phase=phase)

    for i, ipetal in enumerate(inner_petals):
        animate_rotation_oscillation(ipetal, "idle", duration=2.0, axis='Z',
                                      amplitude=0.06, frequency=0.4,
                                      phase=i * 0.8)

    # Core: pulsing scale
    animate_scale_uniform(core_main, "idle", duration=2.0,
                          amplitude=0.15, frequency=0.8)
    animate_scale_uniform(core_hot, "idle", duration=2.0,
                          amplitude=0.2, frequency=1.2, phase=0.5)

    # Drips: trembling (tiny vertical oscillation)
    for i, drip in enumerate(drips):
        animate_translation_oscillation(drip, "idle", duration=2.0, axis='Z',
                                         amplitude=0.01, frequency=1.5 + i * 0.2,
                                         phase=i * 0.4)

    # Spores: subtle pulse
    for i, spore in enumerate(spores):
        animate_scale_uniform(spore, "idle", duration=2.0,
                              amplitude=0.1, frequency=0.5 + i * 0.1,
                              phase=i * 0.6)

    # Base: very subtle breathing
    animate_scale_pulse(base_mound, "idle", duration=2.0, axis='Z',
                        amplitude=0.03, frequency=0.3)

    # Root bumps: static for idle
    for rb in root_bumps:
        animate_static(rb, "idle", duration=2.0)

    # Stem veins: static
    for sv in stem_veins:
        animate_static(sv, "idle", duration=2.0)

    # ==================================================================
    # ATTACK (1s): Petals open wide, core flashes, acid sprays outward
    # ==================================================================

    # Stem: lean forward aggressively
    animate_rotation_oscillation(stem_lower, "attack", duration=1.0, axis='X',
                                  amplitude=0.12, frequency=2.0)
    animate_rotation_oscillation(stem_upper, "attack", duration=1.0, axis='X',
                                  amplitude=0.15, frequency=2.5, phase=0.5)

    # Petals: open wide (increase tilt)
    for i, petal in enumerate(petals):
        phase = i * 0.15
        # Petals splay outward with strong oscillation
        animate_rotation_oscillation(petal, "attack", duration=1.0, axis='X',
                                      amplitude=0.4, frequency=2.0, phase=phase)

    for i, ipetal in enumerate(inner_petals):
        animate_rotation_oscillation(ipetal, "attack", duration=1.0, axis='X',
                                      amplitude=0.3, frequency=2.5, phase=i * 0.3)

    # Core: violent pulsing (flash)
    animate_scale_multi(core_main, "attack", duration=1.0, per_axis=[
        (0, 0.3, 2.0, 0.0),
        (1, 0.3, 2.0, 0.0),
        (2, 0.4, 2.0, math.pi * 0.5),
    ])
    animate_scale_uniform(core_hot, "attack", duration=1.0,
                          amplitude=0.5, frequency=3.0)

    # Drips: spray outward (move away from center)
    for i, drip in enumerate(drips):
        # Radial outward motion on X and Y
        axis = 'X' if i % 2 == 0 else 'Y'
        direction = 1.0 if i % 4 < 2 else -1.0
        animate_translation_oscillation(drip, "attack", duration=1.0, axis=axis,
                                         amplitude=0.08 * direction,
                                         frequency=2.0, phase=i * 0.3)

    # Spores: rapid flash
    for i, spore in enumerate(spores):
        animate_scale_uniform(spore, "attack", duration=1.0,
                              amplitude=0.4, frequency=3.0, phase=i * 0.5)

    # Base: shudder
    animate_shake(base_mound, "attack", duration=1.0, amplitude=0.02, frequency=15)

    # Root bumps: pulse outward
    for i, rb in enumerate(root_bumps):
        animate_scale_uniform(rb, "attack", duration=1.0,
                              amplitude=0.3, frequency=2.0, phase=i * 0.5)

    # Stem veins: pulse
    for i, sv in enumerate(stem_veins):
        animate_scale_pulse(sv, "attack", duration=1.0, axis='X',
                            amplitude=0.3, frequency=3.0, phase=i * 0.4)


# ===========================================================================
# ===========================================================================
#
#   PHASE SHIFTER -- Teleporting Monster
#
# ===========================================================================
# ===========================================================================

# Palette: electric blue/white with void accents
PS_BODY_MAIN   = "#4169E1"  # royal blue
PS_BODY_ALT    = "#1E90FF"  # dodger blue
PS_RING_MAIN   = "#00FFFF"  # cyan
PS_RING_ALT    = "#E0FFFF"  # light cyan
PS_CORE        = "#FFFFFF"  # white
PS_CORE_GHOST  = "#F0F8FF"  # ghost white
PS_VOID_MAIN   = "#191970"  # midnight blue
PS_VOID_DARK   = "#000033"  # near-black blue
PS_ACCENT      = "#FF00FF"  # magenta phase-shift highlights
PS_ANTENNA     = "#6A5ACD"  # slate blue
PS_FRAGMENT    = "#87CEEB"  # sky blue


def build_phase_shifter():
    """Compose the Phase Shifter from prefab parts."""
    clear_scene()

    root = bpy.data.objects.new("PhaseShifter", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # ==================================================================
    # CENTRAL BODY: Elongated box rotated 45 degrees (diamond shape)
    # ==================================================================
    # Main diamond body -- tall, angular, otherworldly
    body_main = add(generate_box(w=0.45, d=0.45, h=0.8,
                                  hex_color=PS_BODY_MAIN))
    body_main.name = "BodyMain"
    body_main.location = (0, 0, 0.5)
    body_main.rotation_euler = (0, 0, math.radians(45))

    # Inner body -- slightly smaller, different shade, rotated differently
    body_inner = add(generate_box(w=0.35, d=0.35, h=0.6,
                                   hex_color=PS_BODY_ALT))
    body_inner.name = "BodyInner"
    body_inner.location = (0, 0, 0.6)
    body_inner.rotation_euler = (math.radians(10), math.radians(10), math.radians(22.5))

    # Void core housing -- dark center
    body_void = add(generate_box(w=0.2, d=0.2, h=0.4,
                                  hex_color=PS_VOID_MAIN))
    body_void.name = "BodyVoid"
    body_void.location = (0, 0, 0.6)
    body_void.rotation_euler = (0, 0, 0)

    # ==================================================================
    # CORE: Bright white sphere at the center
    # ==================================================================
    core = add(generate_sphere(radius=0.12, rings=6, segments=10,
                                hex_color=PS_CORE))
    core.name = "Core"
    core.location = (0, 0, 0.75)

    core_glow = add(generate_sphere(radius=0.08, rings=4, segments=8,
                                     hex_color=PS_CORE_GHOST))
    core_glow.name = "CoreGlow"
    core_glow.location = (0, 0, 0.75)

    # ==================================================================
    # PHASE RINGS: 3 torus rings at different angles around the body
    # ==================================================================
    # Ring 1: XY plane (horizontal), tilted slightly
    ring1 = add(generate_torus(major_radius=0.5, minor_radius=0.03,
                                major_segments=20, minor_segments=6,
                                hex_color=PS_RING_MAIN))
    ring1.name = "PhaseRing1"
    ring1.location = (0, 0, 0.7)
    ring1.rotation_euler = (math.radians(15), math.radians(5), 0)

    # Ring 2: tilted ~60 degrees, different axis
    ring2 = add(generate_torus(major_radius=0.45, minor_radius=0.025,
                                major_segments=18, minor_segments=6,
                                hex_color=PS_RING_ALT))
    ring2.name = "PhaseRing2"
    ring2.location = (0, 0, 0.75)
    ring2.rotation_euler = (math.radians(60), math.radians(20), math.radians(30))

    # Ring 3: nearly vertical, perpendicular feel
    ring3 = add(generate_torus(major_radius=0.4, minor_radius=0.02,
                                major_segments=16, minor_segments=6,
                                hex_color=PS_ACCENT))
    ring3.name = "PhaseRing3"
    ring3.location = (0, 0, 0.8)
    ring3.rotation_euler = (math.radians(80), math.radians(-10), math.radians(70))

    # ==================================================================
    # ANGULAR ANTENNAE: Thin boxes extending from top at various angles
    # ==================================================================
    antennae = []
    antenna_configs = [
        # (position_offset, rotation, length, width)
        ((0, 0, 1.1), (math.radians(10), math.radians(15), 0), 0.35, 0.04),
        ((0.05, -0.05, 1.05), (math.radians(-20), math.radians(30), math.radians(15)), 0.3, 0.035),
        ((-0.05, 0.03, 1.08), (math.radians(25), math.radians(-20), math.radians(-10)), 0.25, 0.03),
        ((0.03, 0.05, 1.12), (math.radians(-5), math.radians(-35), math.radians(40)), 0.2, 0.025),
    ]
    for i, (pos, rot, length, width) in enumerate(antenna_configs):
        # Alternate colors between antenna and accent
        color = PS_ANTENNA if i % 2 == 0 else PS_ACCENT
        ant = add(generate_box(w=width, d=width, h=length,
                                hex_color=color))
        ant.name = f"Antenna_{i}"
        ant.location = pos
        ant.rotation_euler = rot
        antennae.append(ant)

    # Antenna tips: tiny bright spheres at each tip
    antenna_tips = []
    for i, (pos, rot, length, width) in enumerate(antenna_configs):
        tip = add(generate_sphere(radius=0.025, rings=3, segments=6,
                                   hex_color=PS_CORE))
        tip.name = f"AntennaTip_{i}"
        # Approximate tip position (along the antenna's up direction)
        # Since antenna grows upward (Z), the tip is at local Z=length
        # We approximate the world position
        tip_x = pos[0] + length * math.sin(rot[1])
        tip_y = pos[1] - length * math.sin(rot[0]) * math.cos(rot[1])
        tip_z = pos[2] + length * math.cos(rot[0]) * math.cos(rot[1])
        tip.location = (tip_x, tip_y, tip_z)
        antenna_tips.append(tip)

    # ==================================================================
    # FLOATING FRAGMENTS: Small boxes orbiting at different heights
    # ==================================================================
    fragments = []
    fragment_configs = [
        # (angle, distance, height, size, color)
        (0, 0.55, 0.4, 0.06, PS_FRAGMENT),
        (math.pi * 0.4, 0.5, 0.9, 0.05, PS_BODY_ALT),
        (math.pi * 0.8, 0.6, 0.6, 0.07, PS_RING_MAIN),
        (math.pi * 1.2, 0.45, 1.0, 0.04, PS_ACCENT),
        (math.pi * 1.6, 0.55, 0.5, 0.055, PS_FRAGMENT),
        (math.pi * 0.2, 0.4, 1.1, 0.035, PS_CORE),
    ]
    for i, (angle, dist, height, size, color) in enumerate(fragment_configs):
        fx = dist * math.cos(angle)
        fy = dist * math.sin(angle)
        frag = add(generate_box(w=size, d=size, h=size,
                                 hex_color=color))
        frag.name = f"Fragment_{i}"
        frag.location = (fx, fy, height)
        # Each fragment has a unique rotation for visual variety
        frag.rotation_euler = (math.radians(20 + i * 15),
                               math.radians(10 + i * 20),
                               math.radians(45 * i))
        fragments.append(frag)

    # ==================================================================
    # BASE: subtle void disc anchoring the entity to the ground
    # ==================================================================
    base_disc = add(generate_cylinder(radius=0.3, height=0.05, segments=12,
                                       hex_color=PS_VOID_DARK))
    base_disc.name = "BaseDisc"
    base_disc.location = (0, 0, 0.0)

    # Void tendrils: thin cylinders reaching down from body
    void_wisps = []
    for i in range(3):
        angle = (i / 3) * 2 * math.pi + 0.5
        vx = 0.15 * math.cos(angle)
        vy = 0.15 * math.sin(angle)
        wisp = add(generate_cylinder(radius=0.015, height=0.35, segments=4,
                                      hex_color=PS_VOID_MAIN))
        wisp.name = f"VoidWisp_{i}"
        wisp.location = (vx, vy, 0.05)
        wisp.rotation_euler = (math.radians(5 + i * 3), math.radians(-3 + i * 2), 0)
        void_wisps.append(wisp)

    return {
        "root": root,
        "body_main": body_main,
        "body_inner": body_inner,
        "body_void": body_void,
        "core": core,
        "core_glow": core_glow,
        "ring1": ring1,
        "ring2": ring2,
        "ring3": ring3,
        "antennae": antennae,
        "antenna_tips": antenna_tips,
        "fragments": fragments,
        "base_disc": base_disc,
        "void_wisps": void_wisps,
    }


# ---------------------------------------------------------------------------
# Phase Shifter Animations
# ---------------------------------------------------------------------------

def bake_phase_shifter_animations(obj):
    """Bake idle (2s) and attack (1s) animations for Phase Shifter."""

    body_main = obj["body_main"]
    body_inner = obj["body_inner"]
    body_void = obj["body_void"]
    core = obj["core"]
    core_glow = obj["core_glow"]
    ring1 = obj["ring1"]
    ring2 = obj["ring2"]
    ring3 = obj["ring3"]
    antennae = obj["antennae"]
    antenna_tips = obj["antenna_tips"]
    fragments = obj["fragments"]
    base_disc = obj["base_disc"]
    void_wisps = obj["void_wisps"]

    # ==================================================================
    # IDLE (2s): Rings rotating at different speeds, fragments orbiting,
    #            gentle body bob, core pulsing
    # ==================================================================

    # Body: gentle vertical bob
    animate_translation_oscillation(body_main, "idle", duration=2.0, axis='Z',
                                     amplitude=0.04, frequency=0.5)
    # Inner body: counter-rotation for dimensional instability feel
    animate_rotation(body_inner, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.15 * math.sin(t * math.pi * 2))
    # Void core: subtle pulsing
    animate_scale_pulse(body_void, "idle", duration=2.0, axis='Z',
                        amplitude=0.05, frequency=0.6)

    # Core: breathing pulse
    animate_scale_uniform(core, "idle", duration=2.0,
                          amplitude=0.1, frequency=0.7)
    animate_scale_uniform(core_glow, "idle", duration=2.0,
                          amplitude=0.15, frequency=1.0, phase=0.5)

    # Phase rings: each rotates on its own axis at different speeds
    # Ring 1: slow horizontal spin
    animate_rotation(ring1, "idle", duration=2.0, axis='Z',
                     total_angle=math.pi * 1.0)
    # Ring 2: medium speed on tilted axis
    animate_rotation(ring2, "idle", duration=2.0, axis='Z',
                     total_angle=math.pi * -1.5)
    # Ring 3: faster spin, perpendicular
    animate_rotation(ring3, "idle", duration=2.0, axis='Z',
                     total_angle=math.pi * 2.0)

    # Antennae: gentle sway
    for i, ant in enumerate(antennae):
        animate_rotation_oscillation(ant, "idle", duration=2.0, axis='X',
                                      amplitude=0.06, frequency=0.4 + i * 0.1,
                                      phase=i * 0.7)

    # Antenna tips: pulsing
    for i, tip in enumerate(antenna_tips):
        animate_scale_uniform(tip, "idle", duration=2.0,
                              amplitude=0.2, frequency=0.8 + i * 0.15,
                              phase=i * 0.5)

    # Fragments: orbiting motion (combined translate + rotate in single action)
    for i, frag in enumerate(fragments):
        phase = i * (2 * math.pi / len(fragments))
        animate_combined_translate_rotate(
            frag, "idle", duration=2.0,
            trans_axis='X', trans_amplitude=0.06,
            trans_frequency=0.3 + i * 0.05, trans_phase=phase,
            rot_axis='Z', rot_total_angle=math.pi * (0.5 + i * 0.2))

    # Base disc: very subtle pulse
    animate_scale_pulse(base_disc, "idle", duration=2.0, axis='X',
                        amplitude=0.03, frequency=0.4)

    # Void wisps: gentle sway
    for i, wisp in enumerate(void_wisps):
        animate_rotation_oscillation(wisp, "idle", duration=2.0, axis='X',
                                      amplitude=0.05, frequency=0.5,
                                      phase=i * 0.8)

    # ==================================================================
    # ATTACK (1s): Rapid ring spin, body shake, fragments pull in then burst
    # ==================================================================

    # Body: violent shake (teleport wind-up)
    animate_shake(body_main, "attack", duration=1.0, amplitude=0.04, frequency=20)
    # Inner body: rapid counter-spin
    animate_rotation(body_inner, "attack", duration=1.0, axis='Z',
                     total_angle=math.pi * 6)
    # Void: expand then contract (phase shift pulse)
    animate_scale_multi(body_void, "attack", duration=1.0, per_axis=[
        (0, 0.2, 2.0, 0.0),
        (1, 0.2, 2.0, 0.0),
        (2, 0.3, 2.0, math.pi),
    ])

    # Core: intense flash
    animate_scale_uniform(core, "attack", duration=1.0,
                          amplitude=0.4, frequency=3.0)
    animate_scale_uniform(core_glow, "attack", duration=1.0,
                          amplitude=0.5, frequency=4.0, phase=0.5)

    # Phase rings: rapid spin (dimensional tear)
    animate_rotation(ring1, "attack", duration=1.0, axis='Z',
                     total_angle=math.pi * 6)
    animate_rotation(ring2, "attack", duration=1.0, axis='Z',
                     total_angle=math.pi * -8)
    animate_rotation(ring3, "attack", duration=1.0, axis='Z',
                     total_angle=math.pi * 10)

    # Antennae: violent jitter
    for i, ant in enumerate(antennae):
        animate_shake(ant, "attack", duration=1.0, amplitude=0.03, frequency=18 + i * 2)

    # Antenna tips: rapid flash
    for i, tip in enumerate(antenna_tips):
        animate_scale_uniform(tip, "attack", duration=1.0,
                              amplitude=0.5, frequency=4.0, phase=i * 0.3)

    # Fragments: pull inward then burst outward (teleport wind-up) + violent spin
    for i, frag in enumerate(fragments):
        phase = i * 0.2
        animate_combined_translate_rotate(
            frag, "attack", duration=1.0,
            trans_axis='X', trans_amplitude=0.15,
            trans_frequency=2.0, trans_phase=phase,
            rot_axis='Z', rot_total_angle=math.pi * (4 + i))

    # Base disc: shudder
    animate_shake(base_disc, "attack", duration=1.0, amplitude=0.02, frequency=15)

    # Void wisps: violent whip
    for i, wisp in enumerate(void_wisps):
        animate_rotation_oscillation(wisp, "attack", duration=1.0, axis='X',
                                      amplitude=0.3, frequency=3.0, phase=i * 0.5)


# ===========================================================================
# Texture application (optional -- for textured variants)
# ===========================================================================

def apply_acid_bloom_textures(obj):
    """Try to apply organic PBR textures to Acid Bloom."""
    try:
        from texture_library import apply_texture
        # Stem: bark for organic feel
        for name in ["stem_lower", "stem_upper"]:
            apply_texture(obj[name], "bark_willow", resolution="1k")
        # Base: rock texture for ground mass
        apply_texture(obj["base_mound"], "rock_06", resolution="1k")
        # Petals: fabric-like softness
        for petal in obj["petals"]:
            apply_texture(petal, "bark_willow", resolution="1k")
        print("[acid_bloom] Textures applied successfully")
        return True
    except Exception as e:
        print(f"[acid_bloom] Texture application failed: {e}")
        return False


def apply_phase_shifter_textures(obj):
    """Try to apply PBR textures to Phase Shifter."""
    try:
        from texture_library import apply_texture
        # Body: metallic/crystalline
        for name in ["body_main", "body_inner"]:
            apply_texture(obj[name], "rock_06", resolution="1k")
        print("[phase_shifter] Textures applied successfully")
        return True
    except Exception as e:
        print(f"[phase_shifter] Texture application failed: {e}")
        return False


# ===========================================================================
# Main
# ===========================================================================

def main():
    # -----------------------------------------------------------------------
    # ACID BLOOM
    # -----------------------------------------------------------------------
    ab_output_dir = os.path.join(REPO_ROOT, "monsters", "acid_bloom", "models")

    # --- FLAT version ---
    print("\n[acid_bloom] Building FLAT version...")
    ab_objects = build_acid_bloom()
    bake_acid_bloom_animations(ab_objects)

    ab_flat_glb = os.path.join(ab_output_dir, "acid_bloom_flat.glb")
    export_glb(ab_flat_glb)
    print(f"[acid_bloom] Flat: {ab_flat_glb}")

    # --- TEXTURED version ---
    print("[acid_bloom] Building TEXTURED version...")
    ab_objects = build_acid_bloom()
    apply_acid_bloom_textures(ab_objects)
    bake_acid_bloom_animations(ab_objects)

    ab_tex_glb = os.path.join(ab_output_dir, "acid_bloom.glb")
    export_glb(ab_tex_glb)
    print(f"[acid_bloom] Textured: {ab_tex_glb}")

    # -----------------------------------------------------------------------
    # PHASE SHIFTER
    # -----------------------------------------------------------------------
    ps_output_dir = os.path.join(REPO_ROOT, "monsters", "phase_shifter", "models")

    # --- FLAT version ---
    print("\n[phase_shifter] Building FLAT version...")
    ps_objects = build_phase_shifter()
    bake_phase_shifter_animations(ps_objects)

    ps_flat_glb = os.path.join(ps_output_dir, "phase_shifter_flat.glb")
    export_glb(ps_flat_glb)
    print(f"[phase_shifter] Flat: {ps_flat_glb}")

    # --- TEXTURED version ---
    print("[phase_shifter] Building TEXTURED version...")
    ps_objects = build_phase_shifter()
    apply_phase_shifter_textures(ps_objects)
    bake_phase_shifter_animations(ps_objects)

    ps_tex_glb = os.path.join(ps_output_dir, "phase_shifter.glb")
    export_glb(ps_tex_glb)
    print(f"[phase_shifter] Textured: {ps_tex_glb}")

    print("\n[monster_models_post_m1] Done! Both monsters generated.")


if __name__ == "__main__":
    main()
