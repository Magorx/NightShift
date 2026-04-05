"""Shared export helpers for all Blender scene scripts.

Centralizes the GLB export function so it doesn't need
to be copy-pasted into every scene script.

Usage:
    from export_helpers import export_glb
"""

import bpy
import os


LOOP_ANIMS = ("idle", "active")

def _build_subresources():
    entries = []
    for name in LOOP_ANIMS:
        entries.append(f'"animations/{name}": {{\n"settings/loop_mode": 1\n}}')
    return "_subresources={\n" + ",\n".join(entries) + "\n}"


def _find_subresources_span(text):
    """Find the start and end of _subresources={...} with balanced braces."""
    start = text.find("_subresources={")
    if start == -1:
        return None
    depth = 0
    for i in range(start + len("_subresources="), len(text)):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                return (start, i + 1)
    return None


def _patch_import_loop(glb_path):
    """Ensure idle/active animations loop in the Godot .import file."""
    import_path = glb_path + ".import"
    if not os.path.isfile(import_path):
        return
    text = open(import_path, "r").read()
    new_sub = _build_subresources()
    span = _find_subresources_span(text)
    if span:
        text = text[:span[0]] + new_sub + text[span[1]:]
    else:
        text = text.rstrip() + "\n" + new_sub + "\n"
    open(import_path, "w").write(text)


def export_glb(output_path):
    """Select all and export as .glb with NLA animations.

    Models are authored at 2 Blender units per grid cell. The 0.5x scale
    is applied at Godot import time via nodes/root_scale=0.5 in .glb.import
    files, NOT here. This keeps the Blender pipeline clean.

    After export, patches the .glb.import file (if present) to set
    loop_mode=1 on idle and active animations.
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
    _patch_import_loop(output_path)
