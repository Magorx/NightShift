"""Generate a wedge/ramp prefab.

Creates a triangular prism (wedge shape). Useful for ramps, angled
supports, hopper bases, and roof peaks.

Run standalone:
    blender --background --python tools/blender/prefabs_src/wedge.py
"""

import bpy
import bmesh
import os
import sys
import math

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(__file__), "..")))
from materials.pixel_art import create_flat_material

OUTPUT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "prefabs_out"))


def generate_wedge(w=1.0, d=1.0, h_front=0.0, h_back=1.0,
                   hex_color="#5A4838", output=None):
    """Generate a wedge (triangular prism).

    The wedge runs along the Y axis. Front face (Y=-d/2) has height
    h_front, back face (Y=+d/2) has height h_back. This creates a
    ramp from front to back.

    Args:
        w: Width (X axis).
        d: Depth (Y axis).
        h_front: Height at front edge (0 = pointed ramp).
        h_back: Height at back edge.
        hex_color: Material color.
        output: Output .blend path.

    Returns:
        The wedge object.
    """
    bm = bmesh.new()
    hw, hd = w / 2, d / 2

    # Front vertices (Y = -hd)
    fl = bm.verts.new((-hw, -hd, 0))
    fr = bm.verts.new((hw, -hd, 0))
    if h_front > 0.001:
        ftl = bm.verts.new((-hw, -hd, h_front))
        ftr = bm.verts.new((hw, -hd, h_front))
    else:
        ftl = fl
        ftr = fr

    # Back vertices (Y = +hd)
    bl = bm.verts.new((-hw, hd, 0))
    br = bm.verts.new((hw, hd, 0))
    btl = bm.verts.new((-hw, hd, h_back))
    btr = bm.verts.new((hw, hd, h_back))

    bm.verts.ensure_lookup_table()

    # Bottom face
    bm.faces.new([fl, fr, br, bl])

    # Back face
    bm.faces.new([br, btr, btl, bl])

    # Top face (ramp)
    if h_front > 0.001:
        bm.faces.new([ftl, ftr, btr, btl])
    else:
        bm.faces.new([fl, fr, btr, btl])

    # Left side
    if h_front > 0.001:
        bm.faces.new([fl, bl, btl, ftl])
    else:
        bm.faces.new([fl, bl, btl])

    # Right side
    if h_front > 0.001:
        bm.faces.new([fr, ftr, btr, br])
    else:
        bm.faces.new([fr, btr, br])

    # Front face (only if h_front > 0)
    if h_front > 0.001:
        bm.faces.new([fl, ftl, ftr, fr])

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("Wedge")
    bm.to_mesh(mesh)
    bm.free()
    mesh.validate()

    obj = bpy.data.objects.new("Wedge", mesh)
    bpy.context.scene.collection.objects.link(obj)

    mat = create_flat_material("WedgeMat", hex_color)
    obj.data.materials.append(mat)

    for poly in obj.data.polygons:
        poly.use_smooth = False

    if output:
        os.makedirs(os.path.dirname(output), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=output)

    return obj


if __name__ == "__main__":
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for m in bpy.data.meshes:
        bpy.data.meshes.remove(m)

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    generate_wedge(output=os.path.join(OUTPUT_DIR, "wedge.blend"))
    print("[prefab] wedge.blend generated")
