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

    Applies a 0.5x scale at export time so Blender's 2-unit-per-cell
    convention maps to Godot's 1-unit-per-cell grid. Scenes use scale 1.0.
    """
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    # Scale everything to match Godot grid (2 Blender units → 1 Godot unit)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.transform.resize(value=(0.5, 0.5, 0.5))
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_animation_mode='NLA_TRACKS',
        export_merge_animation='NLA_TRACK',
        export_animations=True,
    )
