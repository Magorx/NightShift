"""Shared export helpers for all Blender scene scripts.

Centralizes the GLB and Blend export functions so they don't need
to be copy-pasted into every scene script.

Usage:
    from export_helpers import export_glb, export_blend
"""

import bpy
import os


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
