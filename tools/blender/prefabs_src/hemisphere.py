"""Generate a hemisphere prefab.

Creates a half-sphere dome. Useful for dome caps, tank ends, and
rounded tops on industrial equipment.

Run standalone:
    blender --background --python tools/blender/prefabs_src/hemisphere.py
"""

import bpy
import bmesh
import os
import sys
import math

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(__file__), "..")))
from materials.pixel_art import create_flat_material

OUTPUT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "prefabs_out"))


def generate_hemisphere(radius=0.5, rings=4, segments=12,
                        hex_color="#96A4B4", output=None):
    """Generate a hemisphere (half-sphere).

    Sits flat on the XY plane at Z=0, dome extending upward to Z=radius.

    Args:
        radius: Hemisphere radius.
        rings: Number of horizontal rings (more = smoother).
        segments: Number of vertical segments.
        hex_color: Material color.
        output: Output .blend path.

    Returns:
        The hemisphere object.
    """
    bm = bmesh.new()

    # Base ring at Z=0
    base_verts = []
    for i in range(segments):
        angle = (i / segments) * 2 * math.pi
        x = radius * math.cos(angle)
        y = radius * math.sin(angle)
        base_verts.append(bm.verts.new((x, y, 0)))

    # Intermediate rings
    prev_ring = base_verts
    for ring_i in range(1, rings):
        phi = (ring_i / rings) * (math.pi / 2)  # 0 to 90 degrees
        ring_r = radius * math.cos(phi)
        ring_z = radius * math.sin(phi)

        curr_ring = []
        for i in range(segments):
            angle = (i / segments) * 2 * math.pi
            x = ring_r * math.cos(angle)
            y = ring_r * math.sin(angle)
            curr_ring.append(bm.verts.new((x, y, ring_z)))

        bm.verts.ensure_lookup_table()
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new([prev_ring[i], prev_ring[j], curr_ring[j], curr_ring[i]])

        prev_ring = curr_ring

    # Apex: close with triangles to top point
    apex = bm.verts.new((0, 0, radius))
    bm.verts.ensure_lookup_table()
    for i in range(segments):
        j = (i + 1) % segments
        bm.faces.new([prev_ring[i], prev_ring[j], apex])

    # Bottom cap (flat base)
    bm.faces.new(list(reversed(base_verts)))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("Hemisphere")
    bm.to_mesh(mesh)
    bm.free()
    mesh.validate()

    obj = bpy.data.objects.new("Hemisphere", mesh)
    bpy.context.scene.collection.objects.link(obj)

    mat = create_flat_material("HemisphereMat", hex_color)
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
    generate_hemisphere(output=os.path.join(OUTPUT_DIR, "hemisphere.blend"))
    print("[prefab] hemisphere.blend generated")
