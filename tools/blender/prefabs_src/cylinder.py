"""Generate an industrial cylinder/silo prefab.

Creates a solid cylinder with optional top cap detail. Useful for
derrick columns, exhaust stacks, and storage silos.

Run standalone:
    blender --background --python tools/blender/prefabs_src/cylinder.py
"""

import bpy
import bmesh
import os
import sys
import math

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(__file__), "..")))
from materials.pixel_art import create_flat_material

OUTPUT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "prefabs_out"))


def generate_cylinder(radius=0.5, height=1.0, segments=16,
                      cap_style="flat", hex_color="#7A8898", output=None):
    """Generate a solid cylinder.

    Args:
        radius: Cylinder radius.
        height: Cylinder height (extends upward from Z=0).
        segments: Number of circular segments.
        cap_style: "flat" for flat top, "dome" for hemisphere cap.
        hex_color: Material color.
        output: Output .blend path.

    Returns:
        The cylinder object.
    """
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")

    # Normalizer for world-space UVs (matches texture_library mapping scale)
    circumference = 2 * math.pi * radius
    max_dim = max(2 * radius, height)

    bot_verts = []
    top_verts = []
    for i in range(segments):
        angle = (i / segments) * 2 * math.pi
        x = radius * math.cos(angle)
        y = radius * math.sin(angle)
        bot_verts.append(bm.verts.new((x, y, 0)))
        top_verts.append(bm.verts.new((x, y, height)))

    bm.verts.ensure_lookup_table()

    # Bottom cap
    bot_face = bm.faces.new(list(reversed(bot_verts)))
    for loop in bot_face.loops:
        loop[uv_layer].uv = (loop.vert.co.x / max_dim + 0.5,
                              loop.vert.co.y / max_dim + 0.5)

    # Side faces with cylindrical UVs
    for i in range(segments):
        j = (i + 1) % segments
        u0 = (i / segments) * circumference / max_dim
        u1 = ((i + 1) / segments) * circumference / max_dim
        face = bm.faces.new([bot_verts[i], bot_verts[j], top_verts[j], top_verts[i]])
        uvs = [(u0, 0), (u1, 0), (u1, height / max_dim), (u0, height / max_dim)]
        for loop, uv in zip(face.loops, uvs):
            loop[uv_layer].uv = uv

    if cap_style == "dome":
        # Simple hemisphere approximation: 3 rings converging to apex
        rings = 3
        prev_ring = top_verts
        for ring_i in range(1, rings + 1):
            t = ring_i / rings
            ring_angle = t * (math.pi / 2)
            ring_r = radius * math.cos(ring_angle)
            ring_z = height + radius * math.sin(ring_angle)

            if ring_i == rings:
                # Apex point
                apex = bm.verts.new((0, 0, height + radius))
                bm.verts.ensure_lookup_table()
                for i in range(segments):
                    j = (i + 1) % segments
                    face = bm.faces.new([prev_ring[i], prev_ring[j], apex])
                    for loop in face.loops:
                        loop[uv_layer].uv = (loop.vert.co.x / max_dim + 0.5,
                                              loop.vert.co.y / max_dim + 0.5)
            else:
                curr_ring = []
                for i in range(segments):
                    angle = (i / segments) * 2 * math.pi
                    x = ring_r * math.cos(angle)
                    y = ring_r * math.sin(angle)
                    curr_ring.append(bm.verts.new((x, y, ring_z)))
                bm.verts.ensure_lookup_table()

                for i in range(segments):
                    j = (i + 1) % segments
                    face = bm.faces.new([prev_ring[i], prev_ring[j],
                                  curr_ring[j], curr_ring[i]])
                    for loop in face.loops:
                        loop[uv_layer].uv = (loop.vert.co.x / max_dim + 0.5,
                                              loop.vert.co.y / max_dim + 0.5)
                prev_ring = curr_ring
    else:
        # Flat top cap
        top_face = bm.faces.new(top_verts)
        for loop in top_face.loops:
            loop[uv_layer].uv = (loop.vert.co.x / max_dim + 0.5,
                                  loop.vert.co.y / max_dim + 0.5)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("Cylinder")
    bm.to_mesh(mesh)
    bm.free()
    mesh.validate()

    obj = bpy.data.objects.new("Cylinder", mesh)
    bpy.context.scene.collection.objects.link(obj)

    mat = create_flat_material("CylinderMat", hex_color)
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
    generate_cylinder(output=os.path.join(OUTPUT_DIR, "cylinder.blend"))
    print("[prefab] cylinder.blend generated")
