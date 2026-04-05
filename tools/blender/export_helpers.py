"""Shared export helpers for all Blender scene scripts.

Centralizes the GLB export function so it doesn't need
to be copy-pasted into every scene script.

Usage:
    from export_helpers import export_glb
"""

import bpy
import os


def export_glb(output_path):
    """Select all and export as .glb with NLA animations.

    Models are authored at 2 Blender units per grid cell. The 0.5x scale
    is applied at Godot import time via nodes/root_scale=0.5 in .glb.import
    files, NOT here. This keeps the Blender pipeline clean.
    """
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
