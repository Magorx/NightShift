"""Generate a sphere prefab.

Creates a UV sphere. Useful for items, projectiles, monster parts,
player heads, and any round element.

Run standalone:
    blender --background --python tools/blender/prefabs_src/sphere.py
"""

import bpy
import bmesh
import os
import sys
import math

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(__file__), "..")))
from materials.pixel_art import create_flat_material

OUTPUT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "prefabs_out"))


def generate_sphere(radius=0.5, rings=6, segments=12,
                    hex_color="#96A4B4", output=None):
    """Generate a UV sphere.

    Centered at origin. Poles are on the Z axis.

    Args:
        radius: Sphere radius.
        rings: Number of horizontal rings (latitude lines, excluding poles).
        segments: Number of vertical segments (longitude lines).
        hex_color: Material color.
        output: Output .blend path.

    Returns:
        The sphere object.
    """
    bm = bmesh.new()

    # Create vertices ring by ring from bottom pole to top pole
    bottom_pole = bm.verts.new((0, 0, -radius))
    top_pole = bm.verts.new((0, 0, radius))

    ring_verts = []  # list of lists, one per ring
    for ring_i in range(1, rings + 1):
        phi = math.pi * ring_i / (rings + 1)  # from top to bottom
        ring_z = radius * math.cos(phi)
        ring_r = radius * math.sin(phi)

        ring = []
        for seg_i in range(segments):
            theta = 2 * math.pi * seg_i / segments
            x = ring_r * math.cos(theta)
            y = ring_r * math.sin(theta)
            ring.append(bm.verts.new((x, y, ring_z)))
        ring_verts.append(ring)

    bm.verts.ensure_lookup_table()

    # Top cap: triangles from top pole to first ring
    first_ring = ring_verts[0]
    for i in range(segments):
        j = (i + 1) % segments
        bm.faces.new([top_pole, first_ring[i], first_ring[j]])

    # Middle bands: quads between adjacent rings
    for r in range(len(ring_verts) - 1):
        curr = ring_verts[r]
        next_r = ring_verts[r + 1]
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new([curr[i], next_r[i], next_r[j], curr[j]])

    # Bottom cap: triangles from last ring to bottom pole
    last_ring = ring_verts[-1]
    for i in range(segments):
        j = (i + 1) % segments
        bm.faces.new([last_ring[i], bottom_pole, last_ring[j]])

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("Sphere")
    bm.to_mesh(mesh)
    bm.free()
    mesh.validate()

    obj = bpy.data.objects.new("Sphere", mesh)
    bpy.context.scene.collection.objects.link(obj)

    mat = create_flat_material("SphereMat", hex_color)
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
    generate_sphere(output=os.path.join(OUTPUT_DIR, "sphere.blend"))
    print("[prefab] sphere.blend generated")
