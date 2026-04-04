"""Generate a cone prefab.

Creates a cone or truncated cone (frustum). Useful for tips, hoppers,
funnels, and tapered columns.

Run standalone:
    blender --background --python tools/blender/prefabs_src/cone.py
"""

import bpy
import bmesh
import os
import sys
import math

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(__file__), "..")))
from materials.pixel_art import create_flat_material

OUTPUT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "prefabs_out"))


def generate_cone(radius_bottom=0.5, radius_top=0.0, height=1.0,
                  segments=12, hex_color="#96A4B4", output=None):
    """Generate a cone or frustum.

    Args:
        radius_bottom: Base radius.
        radius_top: Top radius (0 = pointed cone, >0 = truncated frustum).
        height: Height (extends upward from Z=0).
        segments: Number of circular segments.
        hex_color: Material color.
        output: Output .blend path.

    Returns:
        The cone object.
    """
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")

    circumference = 2 * math.pi * radius_bottom
    max_dim = max(2 * radius_bottom, height)

    bot_verts = []
    for i in range(segments):
        angle = (i / segments) * 2 * math.pi
        x = radius_bottom * math.cos(angle)
        y = radius_bottom * math.sin(angle)
        bot_verts.append(bm.verts.new((x, y, 0)))

    if radius_top > 0.001:
        # Frustum: has a top ring
        top_verts = []
        for i in range(segments):
            angle = (i / segments) * 2 * math.pi
            x = radius_top * math.cos(angle)
            y = radius_top * math.sin(angle)
            top_verts.append(bm.verts.new((x, y, height)))

        bm.verts.ensure_lookup_table()

        # Bottom cap
        bot_face = bm.faces.new(list(reversed(bot_verts)))
        for loop in bot_face.loops:
            loop[uv_layer].uv = (loop.vert.co.x / max_dim + 0.5,
                                  loop.vert.co.y / max_dim + 0.5)
        # Top cap
        top_face = bm.faces.new(top_verts)
        for loop in top_face.loops:
            loop[uv_layer].uv = (loop.vert.co.x / max_dim + 0.5,
                                  loop.vert.co.y / max_dim + 0.5)
        # Side faces
        for i in range(segments):
            j = (i + 1) % segments
            u0 = (i / segments) * circumference / max_dim
            u1 = ((i + 1) / segments) * circumference / max_dim
            face = bm.faces.new([bot_verts[i], bot_verts[j], top_verts[j], top_verts[i]])
            uvs = [(u0, 0), (u1, 0), (u1, height / max_dim), (u0, height / max_dim)]
            for loop, uv in zip(face.loops, uvs):
                loop[uv_layer].uv = uv
    else:
        # Pointed cone: single apex vertex
        apex = bm.verts.new((0, 0, height))
        bm.verts.ensure_lookup_table()

        # Bottom cap
        bot_face = bm.faces.new(list(reversed(bot_verts)))
        for loop in bot_face.loops:
            loop[uv_layer].uv = (loop.vert.co.x / max_dim + 0.5,
                                  loop.vert.co.y / max_dim + 0.5)
        # Side triangles
        for i in range(segments):
            j = (i + 1) % segments
            u0 = (i / segments) * circumference / max_dim
            u1 = ((i + 1) / segments) * circumference / max_dim
            face = bm.faces.new([bot_verts[i], bot_verts[j], apex])
            uvs = [(u0, 0), (u1, 0), ((u0 + u1) / 2, height / max_dim)]
            for loop, uv in zip(face.loops, uvs):
                loop[uv_layer].uv = uv

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("Cone")
    bm.to_mesh(mesh)
    bm.free()
    mesh.validate()

    obj = bpy.data.objects.new("Cone", mesh)
    bpy.context.scene.collection.objects.link(obj)

    mat = create_flat_material("ConeMat", hex_color)
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
    generate_cone(output=os.path.join(OUTPUT_DIR, "cone.blend"))
    print("[prefab] cone.blend generated")
