"""Generate a hex bolt prefab.

Creates a small hexagonal bolt head with a short cylindrical shaft.
Scatter these on surfaces for industrial detail.

Run standalone:
    blender --background --python tools/blender/prefabs_src/bolt.py
"""

import bpy
import bmesh
import os
import sys
import math

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(__file__), "..")))
from materials.pixel_art import create_flat_material

OUTPUT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "prefabs_out"))


def generate_bolt(head_radius=0.06, head_height=0.03, shaft_radius=0.03,
                  shaft_length=0.05, hex_color="#5A4B3C", output=None):
    """Generate a hex bolt (hexagonal head + cylindrical shaft).

    Origin is at the base of the head (where it meets the surface).
    Shaft extends downward (negative Z). Head extends upward.

    Args:
        head_radius: Hex head outer radius.
        head_height: Height of the hex head.
        shaft_radius: Shaft cylinder radius.
        shaft_length: Length of shaft below the head.
        hex_color: Material color.
        output: Output .blend path.

    Returns:
        The bolt object.
    """
    bm = bmesh.new()

    # Hex head: 6-sided prism
    head_top = []
    head_bot = []
    for i in range(6):
        angle = (i / 6) * 2 * math.pi
        x = head_radius * math.cos(angle)
        y = head_radius * math.sin(angle)
        head_top.append(bm.verts.new((x, y, head_height)))
        head_bot.append(bm.verts.new((x, y, 0)))

    bm.verts.ensure_lookup_table()
    bm.faces.new(head_top)
    bm.faces.new(list(reversed(head_bot)))
    for i in range(6):
        j = (i + 1) % 6
        bm.faces.new([head_bot[i], head_bot[j], head_top[j], head_top[i]])

    # Shaft: cylinder extending downward
    shaft_segments = 8
    shaft_top = []
    shaft_bot = []
    for i in range(shaft_segments):
        angle = (i / shaft_segments) * 2 * math.pi
        x = shaft_radius * math.cos(angle)
        y = shaft_radius * math.sin(angle)
        shaft_top.append(bm.verts.new((x, y, 0)))
        shaft_bot.append(bm.verts.new((x, y, -shaft_length)))

    bm.verts.ensure_lookup_table()
    bm.faces.new(list(reversed(shaft_bot)))
    for i in range(shaft_segments):
        j = (i + 1) % shaft_segments
        bm.faces.new([shaft_top[i], shaft_top[j], shaft_bot[j], shaft_bot[i]])

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("Bolt")
    bm.to_mesh(mesh)
    bm.free()
    mesh.validate()

    obj = bpy.data.objects.new("Bolt", mesh)
    bpy.context.scene.collection.objects.link(obj)

    mat = create_flat_material("BoltMat", hex_color)
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
    generate_bolt(output=os.path.join(OUTPUT_DIR, "bolt.blend"))
    print("[prefab] bolt.blend generated")
