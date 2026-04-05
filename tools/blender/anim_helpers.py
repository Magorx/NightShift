"""High-level animation helpers for building NLA animations.

Reduces the boilerplate of creating keyframed NLA strips.
Each helper creates an action, inserts keyframes, sets linear
interpolation, and pushes to an NLA track with the given state name.

Usage:
    from anim_helpers import animate_rotation, animate_translation, animate_shake

    # Gear spinning continuously during "active" state (2 seconds)
    animate_rotation(gear_obj, "active", duration=2.0, axis='Z',
                     angle_fn=lambda t: t * math.pi * 4)

    # Piston pumping during "active" state
    animate_translation(rod_obj, "active", duration=2.0, axis='Z',
                        value_fn=lambda t: base_z - 0.15 * abs(math.sin(t * math.pi * 4)))

    # Body shaking during "active" state
    animate_shake(body_obj, "active", duration=2.0, amplitude=0.015, frequency=8)
"""

import bpy
import math

FPS = 30


def _ensure_anim_data(obj):
    if obj.animation_data is None:
        obj.animation_data_create()
    return obj.animation_data


def _set_linear(action):
    """Set all keyframe points in an action to linear interpolation.
    Handles Blender 5.x layered action API.
    """
    for layer in action.layers:
        for strip in layer.strips:
            if hasattr(strip, 'channelbags'):
                for cb in strip.channelbags:
                    for fc in cb.fcurves:
                        for kp in fc.keyframe_points:
                            kp.interpolation = 'LINEAR'


def _push_to_nla(obj, action, state_name):
    """Push an action onto a new NLA track with the given state name.
    All objects using the same state_name will be merged into one
    animation in the exported glTF.
    """
    anim = _ensure_anim_data(obj)
    track = anim.nla_tracks.new()
    track.name = state_name
    track.strips.new(state_name, int(action.frame_range[0]), action)
    anim.action = None


def animate_rotation(obj, state_name, duration=2.0, axis='Z',
                     angle_fn=None, total_angle=None):
    """Animate rotation around an axis.

    Provide either angle_fn or total_angle:
    - angle_fn(t): function from normalized time (0-1) to angle in radians
    - total_angle: shorthand for constant-speed rotation to this angle

    Args:
        obj: Blender object to animate.
        state_name: NLA track name (e.g. "active", "idle").
        duration: Animation duration in seconds.
        axis: 'X', 'Y', or 'Z'.
        angle_fn: Callable(t: float) -> float. t goes from 0 to 1.
        total_angle: If set, creates a linear rotation from 0 to this angle.
    """
    axis_idx = {'X': 0, 'Y': 1, 'Z': 2}[axis.upper()]
    frames = int(FPS * duration)

    if angle_fn is None and total_angle is not None:
        angle_fn = lambda t: t * total_angle
    elif angle_fn is None:
        angle_fn = lambda t: t * math.pi * 2

    action_name = f"{state_name}_{obj.name}"
    act = bpy.data.actions.new(action_name)
    _ensure_anim_data(obj).action = act

    for f in range(frames + 1):
        t = f / frames
        obj.rotation_euler[axis_idx] = angle_fn(t)
        obj.keyframe_insert(data_path="rotation_euler", index=axis_idx, frame=f + 1)

    _set_linear(act)
    _push_to_nla(obj, act, state_name)


def animate_translation(obj, state_name, duration=2.0, axis='Z',
                        value_fn=None, base_value=None):
    """Animate translation along an axis.

    Args:
        obj: Blender object to animate.
        state_name: NLA track name.
        duration: Animation duration in seconds.
        axis: 'X', 'Y', or 'Z'.
        value_fn: Callable(t: float) -> float. Returns the absolute position.
            t goes from 0 to 1.
        base_value: If None, uses obj's current position on that axis.
    """
    axis_idx = {'X': 0, 'Y': 1, 'Z': 2}[axis.upper()]
    frames = int(FPS * duration)

    if base_value is None:
        base_value = obj.location[axis_idx]

    if value_fn is None:
        value_fn = lambda t: base_value

    action_name = f"{state_name}_{obj.name}"
    act = bpy.data.actions.new(action_name)
    _ensure_anim_data(obj).action = act

    for f in range(frames + 1):
        t = f / frames
        obj.location[axis_idx] = value_fn(t)
        obj.keyframe_insert(data_path="location", index=axis_idx, frame=f + 1)

    _set_linear(act)
    _push_to_nla(obj, act, state_name)


def animate_shake(obj, state_name, duration=2.0, amplitude=0.015,
                  frequency=8, decay=0.0):
    """Animate XY position shake (vibration).

    Args:
        obj: Blender object to animate.
        state_name: NLA track name.
        duration: Animation duration in seconds.
        amplitude: Maximum displacement in world units.
        frequency: Oscillation frequency (cycles per second).
        decay: If > 0, amplitude decays linearly over time (1.0 = full decay by end).
    """
    frames = int(FPS * duration)
    base_x = obj.location.x
    base_y = obj.location.y

    action_name = f"{state_name}_{obj.name}"
    act = bpy.data.actions.new(action_name)
    _ensure_anim_data(obj).action = act

    for f in range(frames + 1):
        t = f / frames
        env = 1.0 - decay * t  # amplitude envelope
        obj.location.x = base_x + env * amplitude * math.sin(f / FPS * math.pi * frequency)
        obj.location.y = base_y + env * amplitude * 0.7 * math.cos(f / FPS * math.pi * frequency * 1.3)
        obj.keyframe_insert(data_path="location", index=0, frame=f + 1)
        obj.keyframe_insert(data_path="location", index=1, frame=f + 1)

    _set_linear(act)
    _push_to_nla(obj, act, state_name)

    # Reset position
    obj.location.x = base_x
    obj.location.y = base_y


def animate_scale(obj, state_name, duration=2.0, axis='Z',
                   scale_fn=None, base_scale=1.0):
    """Animate scale along an axis.

    Args:
        obj: Blender object to animate.
        state_name: NLA track name.
        duration: Animation duration in seconds.
        axis: 'X', 'Y', or 'Z'.
        scale_fn: Callable(t: float) -> float. Returns the absolute scale value.
            t goes from 0 to 1.
        base_scale: Default scale if scale_fn is None.
    """
    axis_idx = {'X': 0, 'Y': 1, 'Z': 2}[axis.upper()]
    frames = int(FPS * duration)

    if scale_fn is None:
        scale_fn = lambda t: base_scale

    action_name = f"{state_name}_{obj.name}"
    act = bpy.data.actions.new(action_name)
    _ensure_anim_data(obj).action = act

    for f in range(frames + 1):
        t = f / frames
        obj.scale[axis_idx] = scale_fn(t)
        obj.keyframe_insert(data_path="scale", index=axis_idx, frame=f + 1)

    _set_linear(act)
    _push_to_nla(obj, act, state_name)

    # Reset scale
    obj.scale[axis_idx] = 1.0


def animate_static(obj, state_name, duration=2.0):
    """Create a static (no-motion) animation for a state.

    Useful to explicitly hold an object still during a state
    so it doesn't inherit motion from other states.

    Args:
        obj: Blender object.
        state_name: NLA track name.
        duration: Duration in seconds.
    """
    frames = int(FPS * duration)

    action_name = f"{state_name}_{obj.name}"
    act = bpy.data.actions.new(action_name)
    _ensure_anim_data(obj).action = act

    obj.keyframe_insert(data_path="location", frame=1)
    obj.keyframe_insert(data_path="location", frame=frames + 1)
    obj.keyframe_insert(data_path="rotation_euler", frame=1)
    obj.keyframe_insert(data_path="rotation_euler", frame=frames + 1)

    _set_linear(act)
    _push_to_nla(obj, act, state_name)
