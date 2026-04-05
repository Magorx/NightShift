"""Generate a torus prefab.

Creates a ring/donut shape. Useful for resonance effects, rings,
portals, halos, and decorative elements.

Run standalone:
    blender --background --python tools/blender/prefabs_src/torus.py
"""

import bpy
import bmesh
import os
import sys
import math

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(__file__), "..")))
from materials.pixel_art import create_flat_material

OUTPUT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "prefabs_out"))


def generate_torus(major_radius=0.5, minor_radius=0.15,
                   major_segments=16, minor_segments=8,
                   hex_color="#96A4B4", output=None):
    """Generate a torus (donut/ring shape).

    Centered at origin, lying in the XY plane. The hole runs
    along the Z axis.

    Args:
        major_radius: Distance from center of torus to center of tube.
        minor_radius: Radius of the tube cross-section.
        major_segments: Number of segments around the ring.
        minor_segments: Number of segments around the tube.
        hex_color: Material color.
        output: Output .blend path.

    Returns:
        The torus object.
    """
    bm = bmesh.new()

    # Generate vertices
    vert_rings = []
    for i in range(major_segments):
        theta = (i / major_segments) * 2 * math.pi
        # Center of the tube cross-section
        cx = major_radius * math.cos(theta)
        cy = major_radius * math.sin(theta)

        ring = []
        for j in range(minor_segments):
            phi = (j / minor_segments) * 2 * math.pi
            # Point on the tube surface
            x = cx + minor_radius * math.cos(phi) * math.cos(theta)
            y = cy + minor_radius * math.cos(phi) * math.sin(theta)
            z = minor_radius * math.sin(phi)
            ring.append(bm.verts.new((x, y, z)))
        vert_rings.append(ring)

    bm.verts.ensure_lookup_table()

    # Create faces: quads connecting adjacent rings
    for i in range(major_segments):
        next_i = (i + 1) % major_segments
        for j in range(minor_segments):
            next_j = (j + 1) % minor_segments
            bm.faces.new([
                vert_rings[i][j],
                vert_rings[next_i][j],
                vert_rings[next_i][next_j],
                vert_rings[i][next_j],
            ])

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("Torus")
    bm.to_mesh(mesh)
    bm.free()
    mesh.validate()

    obj = bpy.data.objects.new("Torus", mesh)
    bpy.context.scene.collection.objects.link(obj)

    mat = create_flat_material("TorusMat", hex_color)
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
    generate_torus(output=os.path.join(OUTPUT_DIR, "torus.blend"))
    print("[prefab] torus.blend generated")
