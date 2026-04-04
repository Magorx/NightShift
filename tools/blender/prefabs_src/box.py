"""Generate an industrial box prefab.

Creates a rectangular box with optional panel seams via edge loops
and rivet details via a material. Parameterized for reuse across buildings.

Run standalone:
    blender --background --python tools/blender/prefabs_src/box.py
"""

import bpy
import bmesh
import os
import sys
import math

# Allow imports from tools/blender/
sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(__file__), "..")))
from materials.pixel_art import create_flat_material

OUTPUT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "prefabs_out"))


def generate_box(w=2.0, d=2.0, h=1.0, hex_color="#5A4838",
                 seam_count=0, output=None):
    """Generate a box mesh with optional horizontal panel seams.

    Args:
        w: Width (X axis).
        d: Depth (Y axis).
        h: Height (Z axis).
        hex_color: Base material color.
        seam_count: Number of horizontal edge loops for panel seam detail.
        output: Output .blend path. None = don't save.

    Returns:
        The box object.
    """
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")

    max_dim = max(w, d, h)

    # Create box vertices: bottom face then top face
    hw, hd = w / 2, d / 2
    verts_bot = [
        bm.verts.new((-hw, -hd, 0)),
        bm.verts.new((hw, -hd, 0)),
        bm.verts.new((hw, hd, 0)),
        bm.verts.new((-hw, hd, 0)),
    ]
    verts_top = [
        bm.verts.new((-hw, -hd, h)),
        bm.verts.new((hw, -hd, h)),
        bm.verts.new((hw, hd, h)),
        bm.verts.new((-hw, hd, h)),
    ]

    # Bottom and top faces — planar XY projection
    bot_face = bm.faces.new(list(reversed(verts_bot)))
    for loop in bot_face.loops:
        loop[uv_layer].uv = (loop.vert.co.x / max_dim + 0.5,
                              loop.vert.co.y / max_dim + 0.5)
    top_face = bm.faces.new(verts_top)
    for loop in top_face.loops:
        loop[uv_layer].uv = (loop.vert.co.x / max_dim + 0.5,
                              loop.vert.co.y / max_dim + 0.5)

    # Side faces — project along dominant horizontal axis
    # Sides: 0=front(-Y), 1=right(+X), 2=back(+Y), 3=left(-X)
    for i in range(4):
        j = (i + 1) % 4
        face = bm.faces.new([verts_bot[i], verts_bot[j], verts_top[j], verts_top[i]])
        for loop in face.loops:
            co = loop.vert.co
            # Use the axis with more variation as U, Z as V
            dx = abs(verts_bot[j].co.x - verts_bot[i].co.x)
            dy = abs(verts_bot[j].co.y - verts_bot[i].co.y)
            if dx >= dy:
                loop[uv_layer].uv = (co.x / max_dim + 0.5, co.z / max_dim)
            else:
                loop[uv_layer].uv = (co.y / max_dim + 0.5, co.z / max_dim)

    # Add horizontal seam loops by subdividing side edges
    if seam_count > 0:
        bm.edges.ensure_lookup_table()
        # Find vertical edges (connecting bottom to top)
        vertical_edges = []
        for edge in bm.edges:
            v0, v1 = edge.verts
            if abs(v0.co.x - v1.co.x) < 0.001 and abs(v0.co.y - v1.co.y) < 0.001:
                if abs(v0.co.z - v1.co.z) > 0.001:
                    vertical_edges.append(edge)
        if vertical_edges:
            for cut_i in range(seam_count):
                frac = (cut_i + 1) / (seam_count + 1)
                bmesh.ops.bisect_plane(
                    bm, geom=bm.faces[:] + bm.edges[:] + bm.verts[:],
                    plane_co=(0, 0, h * frac),
                    plane_no=(0, 0, 1),
                )

    # Finalize mesh — recalculate normals so all faces point outward
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("Box")
    bm.to_mesh(mesh)
    bm.free()
    mesh.validate()

    obj = bpy.data.objects.new("Box", mesh)
    bpy.context.scene.collection.objects.link(obj)

    # Apply material
    mat = create_flat_material("BoxMat", hex_color)
    obj.data.materials.append(mat)

    # Flat shading
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
    generate_box(output=os.path.join(OUTPUT_DIR, "box.blend"))
    print("[prefab] box.blend generated")
