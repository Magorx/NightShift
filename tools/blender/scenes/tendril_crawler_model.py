"""Generate Tendril Crawler monster model (.glb) for Godot import.

The first monster type in Night Shift. A psychedelic crawling mass of
impossible geometry -- pulsating body, whipping tendrils, unblinking eye.
NOT horror, NOT cute. Abstract, vibrant, geometry that feels WRONG.

Two versions: flat (palette only) and textured (PBR organic surfaces).
Three animation states: idle, move, attack.

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/tendril_crawler_model.py
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
from materials.pixel_art import create_flat_material
from prefabs_src.sphere import generate_sphere
from prefabs_src.hemisphere import generate_hemisphere
from prefabs_src.cylinder import generate_cylinder
from prefabs_src.cone import generate_cone
from prefabs_src.torus import generate_torus
from anim_helpers import (
    animate_rotation, animate_translation, animate_shake, animate_static,
    FPS,
)

# ---------------------------------------------------------------------------
# Psychedelic monster palette -- vivid, clashing, unnatural
# ---------------------------------------------------------------------------
BODY_MAIN    = "#CC33FF"   # vivid purple
BODY_DARK    = "#9900CC"   # dark purple
BODY_ACCENT  = "#FF66CC"   # hot magenta
TENDRIL_MAIN = "#FF3366"   # hot pink
TENDRIL_DARK = "#CC0044"   # dark pink
TENDRIL_TIP  = "#FF9900"   # vivid orange
EYE_MAIN     = "#00FF88"   # neon green
EYE_RING     = "#33FFAA"   # bright cyan-green
EYE_PUPIL    = "#330033"   # near-black purple
ACCENT_BUMP  = "#FFCC00"   # bright yellow
COLLAR_COLOR = "#FF9900"   # vivid orange
DARK_UNDER   = "#330033"   # near-black purple (underside shadows)
VEIN_COLOR   = "#FF0066"   # neon magenta (surface veins)


# ---------------------------------------------------------------------------
# Animation helpers (scale, multi-axis -- not in anim_helpers module)
# ---------------------------------------------------------------------------
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
    """Multi-axis scale animation in a single action.

    per_axis: list of (axis_idx, amplitude, frequency, phase) tuples.
    Axes not listed hold at 1.0.
    """
    frames = int(FPS * duration)

    act = bpy.data.actions.new(f"{state_name}_{obj.name}")
    _ensure_anim_data(obj).action = act

    # Build lookup: axis_idx -> (amp, freq, phase)
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


# ---------------------------------------------------------------------------
# Build the Tendril Crawler
# ---------------------------------------------------------------------------
def build_tendril_crawler():
    """Compose the tendril crawler from prefab parts."""
    clear_scene()

    root = bpy.data.objects.new("TendrilCrawler", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # ==================================================================
    # BODY: overlapping spheres forming an asymmetric, impossible core
    # ==================================================================
    # Main mass -- slightly oblate, raised so tendrils reach downward
    body_main = add(generate_sphere(radius=0.45, rings=8, segments=12,
                                     hex_color=BODY_MAIN))
    body_main.name = "BodyMain"
    body_main.location = (0, 0, 0.7)
    body_main.scale = (1.0, 1.0, 0.8)

    # Secondary lobe -- offset, slightly smaller, different shade
    body_lobe1 = add(generate_sphere(radius=0.3, rings=6, segments=10,
                                      hex_color=BODY_DARK))
    body_lobe1.name = "BodyLobe1"
    body_lobe1.location = (-0.25, 0.15, 0.75)

    # Third lobe -- protruding forward, magenta accent
    body_lobe2 = add(generate_sphere(radius=0.25, rings=6, segments=10,
                                      hex_color=BODY_ACCENT))
    body_lobe2.name = "BodyLobe2"
    body_lobe2.location = (0.2, -0.2, 0.85)

    # Upper dome -- smaller, offset upward for bulging asymmetry
    body_top = add(generate_hemisphere(radius=0.28, rings=4, segments=10,
                                        hex_color=BODY_MAIN))
    body_top.name = "BodyTop"
    body_top.location = (0.05, 0.05, 1.0)

    # Underside dark mass
    body_under = add(generate_hemisphere(radius=0.4, rings=4, segments=10,
                                          hex_color=DARK_UNDER))
    body_under.name = "BodyUnder"
    body_under.location = (0, 0, 0.5)
    body_under.rotation_euler = (math.pi, 0, 0)  # flipped upside down

    # ==================================================================
    # COLLAR: alien torus around the body equator
    # ==================================================================
    collar = add(generate_torus(major_radius=0.5, minor_radius=0.08,
                                 major_segments=16, minor_segments=6,
                                 hex_color=COLLAR_COLOR))
    collar.name = "Collar"
    collar.location = (0, 0, 0.65)
    collar.rotation_euler = (math.radians(8), math.radians(5), 0)  # slight tilt

    # ==================================================================
    # EYE: bright green sphere with dark pupil, partially embedded
    # ==================================================================
    eye_socket = add(generate_sphere(radius=0.18, rings=6, segments=10,
                                      hex_color=EYE_RING))
    eye_socket.name = "EyeSocket"
    eye_socket.location = (0.3, -0.3, 0.85)

    eye_ball = add(generate_sphere(radius=0.14, rings=6, segments=10,
                                    hex_color=EYE_MAIN))
    eye_ball.name = "EyeBall"
    eye_ball.location = (0.35, -0.35, 0.87)

    eye_pupil = add(generate_sphere(radius=0.06, rings=4, segments=8,
                                     hex_color=EYE_PUPIL))
    eye_pupil.name = "EyePupil"
    eye_pupil.location = (0.42, -0.4, 0.89)

    # Secondary smaller eye -- unsettling asymmetry
    eye_small = add(generate_sphere(radius=0.08, rings=4, segments=8,
                                     hex_color=EYE_MAIN))
    eye_small.name = "EyeSmall"
    eye_small.location = (-0.2, -0.35, 0.9)

    eye_small_pupil = add(generate_sphere(radius=0.03, rings=3, segments=6,
                                           hex_color=EYE_PUPIL))
    eye_small_pupil.name = "EyeSmallPupil"
    eye_small_pupil.location = (-0.24, -0.39, 0.92)

    # ==================================================================
    # ACCENT BUMPS: small bright hemispheres on body surface
    # ==================================================================
    bump_data = [
        (0.15, 0.35, 0.95, 0.06, ACCENT_BUMP),
        (-0.3, -0.1, 1.0, 0.05, ACCENT_BUMP),
        (0.0, 0.3, 1.05, 0.04, VEIN_COLOR),
        (-0.15, 0.25, 0.8, 0.05, ACCENT_BUMP),
        (0.35, 0.1, 0.75, 0.04, VEIN_COLOR),
        (-0.35, -0.15, 0.7, 0.05, COLLAR_COLOR),
    ]
    bumps = []
    for i, (bx, by, bz, br, bc) in enumerate(bump_data):
        bump = add(generate_hemisphere(radius=br, rings=3, segments=6,
                                        hex_color=bc))
        bump.name = f"Bump_{i}"
        bump.location = (bx, by, bz)
        bumps.append(bump)

    # ==================================================================
    # SURFACE VEINS: thin cylinders stretched across the body surface
    # ==================================================================
    vein_data = [
        {"start": (-0.1, 0.3, 0.85), "end": (0.25, 0.1, 1.0)},
        {"start": (0.1, -0.2, 0.65), "end": (-0.2, 0.15, 0.8)},
        {"start": (-0.3, 0.0, 0.75), "end": (-0.05, -0.25, 0.85)},
    ]
    for i, vein in enumerate(vein_data):
        sx, sy, sz = vein["start"]
        ex, ey, ez = vein["end"]
        dx, dy, dz = ex - sx, ey - sy, ez - sz
        length = math.sqrt(dx*dx + dy*dy + dz*dz)
        if length < 0.001:
            continue

        v = add(generate_cylinder(radius=0.015, height=length, segments=4,
                                   hex_color=VEIN_COLOR))
        v.name = f"Vein_{i}"
        v.location = (sx, sy, sz)
        pitch = math.acos(max(-1, min(1, dz / length)))
        yaw = math.atan2(dy, dx)
        v.rotation_euler = (0, pitch, yaw)

    # ==================================================================
    # TENDRILS: 5 tentacle-like appendages extending from body
    # Each tendril = tapered cone base + thin cylinder segment + cone tip
    # ==================================================================
    tendril_configs = [
        # Tendrils extend OUTWARD and DOWNWARD from the body.
        # Cones grow upward from Z=0, so we rotate ~120-150 degrees
        # to make them point outward/down, like spider legs.
        # Front-right -- reaching forward and down
        {"pos": (0.3, -0.25, 0.55), "rot": (math.radians(130), 0, math.radians(-30)),
         "base_r": 0.12, "mid_r": 0.07, "tip_r": 0.03,
         "seg1_h": 0.45, "seg2_h": 0.4, "seg3_h": 0.3},
        # Front-left -- reaching forward-left and down
        {"pos": (-0.3, -0.25, 0.55), "rot": (math.radians(130), 0, math.radians(30)),
         "base_r": 0.11, "mid_r": 0.06, "tip_r": 0.025,
         "seg1_h": 0.4, "seg2_h": 0.35, "seg3_h": 0.25},
        # Right -- reaching sideways and down
        {"pos": (0.4, 0.1, 0.55), "rot": (math.radians(120), 0, math.radians(-80)),
         "base_r": 0.10, "mid_r": 0.06, "tip_r": 0.03,
         "seg1_h": 0.4, "seg2_h": 0.35, "seg3_h": 0.3},
        # Left -- reaching sideways and down
        {"pos": (-0.4, 0.1, 0.55), "rot": (math.radians(120), 0, math.radians(80)),
         "base_r": 0.10, "mid_r": 0.06, "tip_r": 0.025,
         "seg1_h": 0.4, "seg2_h": 0.3, "seg3_h": 0.25},
        # Back -- trailing behind and down
        {"pos": (0.05, 0.35, 0.55), "rot": (math.radians(140), 0, math.radians(170)),
         "base_r": 0.13, "mid_r": 0.08, "tip_r": 0.035,
         "seg1_h": 0.5, "seg2_h": 0.4, "seg3_h": 0.35},
    ]

    tendrils = []  # list of dicts: {base, mid, tip}
    for i, tc in enumerate(tendril_configs):
        # Segment 1: thick cone (base of tendril)
        seg1 = add(generate_cone(radius_bottom=tc["base_r"],
                                  radius_top=tc["mid_r"],
                                  height=tc["seg1_h"], segments=8,
                                  hex_color=TENDRIL_MAIN))
        seg1.name = f"Tendril{i}_Base"
        seg1.location = tc["pos"]
        seg1.rotation_euler = tc["rot"]

        # Segment 2: thinner cone (mid section) -- child of seg1
        # Bend outward at the joint for organic curvature
        mid_bend = 0.2 + i * 0.08  # each tendril bends slightly differently
        seg2 = generate_cone(radius_bottom=tc["mid_r"],
                              radius_top=tc["tip_r"],
                              height=tc["seg2_h"], segments=6,
                              hex_color=TENDRIL_DARK)
        seg2.name = f"Tendril{i}_Mid"
        seg2.location = (0, 0, tc["seg1_h"])
        seg2.rotation_euler = (mid_bend, 0, 0)  # bend at joint
        seg2.parent = seg1

        # Segment 3: tip -- thin pointed cone, child of seg2
        # Curls further at the end
        tip_curl = 0.3 + i * 0.1
        seg3 = generate_cone(radius_bottom=tc["tip_r"],
                              radius_top=0.0,
                              height=tc["seg3_h"], segments=6,
                              hex_color=TENDRIL_TIP)
        seg3.name = f"Tendril{i}_Tip"
        seg3.location = (0, 0, tc["seg2_h"])
        seg3.rotation_euler = (tip_curl, 0, 0)  # curl at tip
        seg3.parent = seg2

        # Small joint bump at each segment junction
        joint1 = generate_sphere(radius=tc["mid_r"] * 1.1, rings=4, segments=6,
                                  hex_color=BODY_DARK)
        joint1.name = f"Tendril{i}_Joint1"
        joint1.location = (0, 0, tc["seg1_h"])
        joint1.parent = seg1

        joint2 = generate_sphere(radius=tc["tip_r"] * 1.3, rings=3, segments=6,
                                  hex_color=TENDRIL_DARK)
        joint2.name = f"Tendril{i}_Joint2"
        joint2.location = (0, 0, tc["seg2_h"])
        joint2.parent = seg2

        tendrils.append({"base": seg1, "mid": seg2, "tip": seg3})

    # ==================================================================
    # MOUTH-LIKE STRUCTURE: unsettling gash on the underside-front
    # ==================================================================
    mouth_rim = add(generate_torus(major_radius=0.15, minor_radius=0.035,
                                    major_segments=10, minor_segments=5,
                                    hex_color=TENDRIL_MAIN))
    mouth_rim.name = "MouthRim"
    mouth_rim.location = (0.1, -0.4, 0.6)
    mouth_rim.rotation_euler = (math.radians(70), 0, math.radians(10))

    mouth_void = add(generate_cylinder(radius=0.1, height=0.08, segments=8,
                                        hex_color=EYE_PUPIL))
    mouth_void.name = "MouthVoid"
    mouth_void.location = (0.1, -0.4, 0.59)
    mouth_void.rotation_euler = (math.radians(70), 0, math.radians(10))

    return {
        "root": root,
        "body_main": body_main,
        "body_lobe1": body_lobe1,
        "body_lobe2": body_lobe2,
        "body_top": body_top,
        "collar": collar,
        "eye_ball": eye_ball,
        "eye_pupil": eye_pupil,
        "eye_small": eye_small,
        "tendrils": tendrils,
        "bumps": bumps,
    }


# ---------------------------------------------------------------------------
# Animations -- 3 states: idle (2s), move (2s), attack (1s)
# ---------------------------------------------------------------------------
def bake_animations(obj):
    """Bake all three animation states onto the model."""
    body = obj["body_main"]
    lobe1 = obj["body_lobe1"]
    lobe2 = obj["body_lobe2"]
    top = obj["body_top"]
    collar = obj["collar"]
    eye_ball = obj["eye_ball"]
    eye_pupil = obj["eye_pupil"]
    eye_small = obj["eye_small"]
    tendrils = obj["tendrils"]
    bumps = obj["bumps"]

    # ==================================================================
    # IDLE (2s) -- gentle pulsing, lazy tendril sway, slow eye drift
    # ==================================================================

    # Body: slow breathing pulse
    animate_scale_pulse(body, "idle", duration=2.0, axis='Z',
                        amplitude=0.06, frequency=0.5)
    animate_scale_pulse(lobe1, "idle", duration=2.0, axis='Z',
                        amplitude=0.04, frequency=0.7, phase=0.5)
    animate_scale_pulse(lobe2, "idle", duration=2.0, axis='Z',
                        amplitude=0.05, frequency=0.6, phase=1.0)
    animate_scale_pulse(top, "idle", duration=2.0, axis='Z',
                        amplitude=0.08, frequency=0.4, phase=0.3)

    # Collar: gentle Z rotation drift
    animate_rotation(collar, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.15 * math.sin(t * math.pi * 2))

    # Eye: slow rotation scan
    animate_rotation(eye_ball, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.2 * math.sin(t * math.pi * 2))
    animate_rotation(eye_pupil, "idle", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.3 * math.sin(t * math.pi * 2 + 0.5))
    animate_scale_pulse(eye_small, "idle", duration=2.0, axis='Z',
                        amplitude=0.1, frequency=0.8)

    # Tendrils: lazy oscillation (each tendril slightly different)
    for i, td in enumerate(tendrils):
        phase = i * 0.8
        freq = 0.4 + i * 0.1

        # Base segment: gentle X rotation sway
        animate_rotation_oscillation(td["base"], "idle", duration=2.0,
                                      axis='X', amplitude=0.08, frequency=freq,
                                      phase=phase)
        # Mid: secondary sway (Y axis)
        animate_rotation_oscillation(td["mid"], "idle", duration=2.0,
                                      axis='Y', amplitude=0.06,
                                      frequency=freq * 1.3, phase=phase + 0.5)
        # Tip: subtle curl
        animate_rotation_oscillation(td["tip"], "idle", duration=2.0,
                                      axis='X', amplitude=0.04,
                                      frequency=freq * 1.6, phase=phase + 1.0)

    # Bumps: subtle pulse
    for i, bump in enumerate(bumps):
        animate_scale_uniform(bump, "idle", duration=2.0,
                              amplitude=0.1, frequency=0.6 + i * 0.15,
                              phase=i * 0.7)

    # ==================================================================
    # MOVE (2s) -- vigorous tendrils (walking), body bouncing, leaning
    # ==================================================================

    # Body: bouncing up/down
    animate_translation_oscillation(body, "move", duration=2.0, axis='Z',
                                     amplitude=0.08, frequency=2.0)
    # Body lobes: faster pulsing, out of phase (disturbing)
    animate_scale_pulse(lobe1, "move", duration=2.0, axis='Z',
                        amplitude=0.08, frequency=1.5, phase=0.0)
    animate_scale_pulse(lobe2, "move", duration=2.0, axis='X',
                        amplitude=0.06, frequency=1.8, phase=0.7)
    # Top: forward lean (X rotation oscillation = nodding)
    animate_rotation_oscillation(top, "move", duration=2.0, axis='X',
                                  amplitude=0.15, frequency=2.0)

    # Collar: faster spin
    animate_rotation(collar, "move", duration=2.0, axis='Z',
                     total_angle=math.pi * 2)

    # Eye: jittery tracking
    animate_shake(eye_ball, "move", duration=2.0, amplitude=0.02, frequency=12)
    animate_rotation(eye_pupil, "move", duration=2.0, axis='Z',
                     angle_fn=lambda t: 0.5 * math.sin(t * math.pi * 6))
    animate_shake(eye_small, "move", duration=2.0, amplitude=0.015, frequency=10)

    # Tendrils: vigorous crawling motion
    for i, td in enumerate(tendrils):
        phase = i * (2 * math.pi / len(tendrils))  # evenly phased like legs

        # Base: large sweeping motion (like legs pumping)
        animate_rotation_oscillation(td["base"], "move", duration=2.0,
                                      axis='X', amplitude=0.3,
                                      frequency=2.0, phase=phase)
        # Mid: counter-swing for crawling articulation
        animate_rotation_oscillation(td["mid"], "move", duration=2.0,
                                      axis='X', amplitude=0.25,
                                      frequency=2.0, phase=phase + math.pi * 0.5)
        # Tip: whipping at the end of each stroke
        animate_rotation_oscillation(td["tip"], "move", duration=2.0,
                                      axis='X', amplitude=0.4,
                                      frequency=4.0, phase=phase)

    # Bumps: rapid pulse (stressed/agitated)
    for i, bump in enumerate(bumps):
        animate_scale_uniform(bump, "move", duration=2.0,
                              amplitude=0.15, frequency=2.0 + i * 0.3,
                              phase=i * 0.5)

    # ==================================================================
    # ATTACK (1s) -- tendrils lash outward, body contracts then expands
    # ==================================================================

    # Body: sharp contraction on Z + expansion on X (single combined action)
    animate_scale_multi(body, "attack", duration=1.0, per_axis=[
        (0, 0.12, 1.0, math.pi),   # X: expand
        (2, -0.15, 1.0, 0.0),      # Z: contract
    ])
    animate_scale_pulse(lobe1, "attack", duration=1.0, axis='Z',
                        amplitude=-0.1, frequency=1.5)
    animate_scale_pulse(lobe2, "attack", duration=1.0, axis='Z',
                        amplitude=-0.1, frequency=1.5, phase=0.5)
    animate_scale_pulse(top, "attack", duration=1.0, axis='Z',
                        amplitude=0.2, frequency=1.0, phase=math.pi * 0.5)

    # Collar: violent spin
    animate_rotation(collar, "attack", duration=1.0, axis='Z',
                     total_angle=math.pi * 4)

    # Eye: rapid shake (startled/aggressive)
    animate_shake(eye_ball, "attack", duration=1.0, amplitude=0.04, frequency=20)
    animate_shake(eye_pupil, "attack", duration=1.0, amplitude=0.03, frequency=25)
    animate_shake(eye_small, "attack", duration=1.0, amplitude=0.03, frequency=18)

    # Tendrils: sharp outward lash then retract
    for i, td in enumerate(tendrils):
        phase = i * 0.3

        # Base: sharp outward thrust
        animate_rotation_oscillation(td["base"], "attack", duration=1.0,
                                      axis='X', amplitude=0.5,
                                      frequency=2.0, phase=phase)
        # Mid: violent whip
        animate_rotation_oscillation(td["mid"], "attack", duration=1.0,
                                      axis='X', amplitude=0.6,
                                      frequency=3.0, phase=phase + 0.3)
        # Tip: snap
        animate_rotation_oscillation(td["tip"], "attack", duration=1.0,
                                      axis='X', amplitude=0.8,
                                      frequency=4.0, phase=phase + 0.6)

    # Bumps: flash (rapid scale spike)
    for i, bump in enumerate(bumps):
        animate_scale_uniform(bump, "attack", duration=1.0,
                              amplitude=0.3, frequency=3.0,
                              phase=i * 0.4)


# ---------------------------------------------------------------------------
# Texture application (optional -- for textured variant)
# ---------------------------------------------------------------------------
def apply_textures(obj):
    """Try to apply organic PBR textures. Returns True on success."""
    try:
        from texture_library import apply_texture

        # Body parts -- bark_willow gives an organic, veiny surface
        for name in ["body_main", "body_lobe1", "body_lobe2", "body_top"]:
            apply_texture(obj[name], "bark_willow", resolution="1k")

        # Tendrils -- bark texture for organic feel
        for td in obj["tendrils"]:
            apply_texture(td["base"], "bark_willow", resolution="1k")
            apply_texture(td["mid"], "bark_willow", resolution="1k")
            # Tips get rock texture for a harder, alien feel
            apply_texture(td["tip"], "rock_06", resolution="1k")

        print("[tendril_crawler] Textures applied successfully")
        return True
    except Exception as e:
        print(f"[tendril_crawler] Texture application failed: {e}")
        print("[tendril_crawler] Continuing with flat materials only")
        return False


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------
def export_glb(output_path):
    """Export as .glb with NLA animations."""
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
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=output_path)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    output_dir = os.path.join(REPO_ROOT, "monsters", "tendril_crawler", "models")

    # --- FLAT version (no textures) ---
    print("[tendril_crawler] Building FLAT version...")
    objects = build_tendril_crawler()
    bake_animations(objects)

    flat_glb = os.path.join(output_dir, "tendril_crawler_flat.glb")
    export_glb(flat_glb)
    flat_blend = flat_glb.replace('.glb', '.blend')
    export_blend(flat_blend)
    print(f"[tendril_crawler] Flat: {flat_glb}")

    # --- TEXTURED version ---
    print("[tendril_crawler] Building TEXTURED version...")
    objects = build_tendril_crawler()
    textured = apply_textures(objects)
    bake_animations(objects)

    tex_glb = os.path.join(output_dir, "tendril_crawler.glb")
    export_glb(tex_glb)
    tex_blend = tex_glb.replace('.glb', '.blend')
    export_blend(tex_blend)
    print(f"[tendril_crawler] Textured: {tex_glb}")

    print("[tendril_crawler] Done!")


if __name__ == "__main__":
    main()
