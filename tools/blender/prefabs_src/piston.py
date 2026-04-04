"""Generate a piston assembly prefab.

Creates a sleeve (outer cylinder) with a rod (inner cylinder) that
extends/retracts. The rod's extension is controlled via a custom
property for keyframe animation.

Run standalone:
    blender --background --python tools/blender/prefabs_src/piston.py
"""

import bpy
import bmesh
import os
import sys
import math

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(__file__), "..")))
from materials.pixel_art import create_flat_material

OUTPUT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "prefabs_out"))


def _make_cylinder_mesh(name, radius, height, segments=12):
    """Create a simple solid cylinder mesh centered at origin, extending upward."""
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")

    circumference = 2 * math.pi * radius
    max_dim = max(2 * radius, height)

    top_verts = []
    bot_verts = []
    for i in range(segments):
        angle = (i / segments) * 2 * math.pi
        x = radius * math.cos(angle)
        y = radius * math.sin(angle)
        bot_verts.append(bm.verts.new((x, y, 0)))
        top_verts.append(bm.verts.new((x, y, height)))

    bm.verts.ensure_lookup_table()

    # Top and bottom caps
    top_face = bm.faces.new(top_verts)
    for loop in top_face.loops:
        loop[uv_layer].uv = (loop.vert.co.x / max_dim + 0.5,
                              loop.vert.co.y / max_dim + 0.5)
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

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.validate()
    return mesh


def generate_piston(sleeve_r=0.35, rod_r=0.15, sleeve_h=0.7, max_extend=0.5,
                    segments=12, hex_sleeve="#6A7888", hex_rod="#96A4B4",
                    output=None):
    """Generate a piston assembly: sleeve + rod.

    The sleeve is a hollow-looking cylinder. The rod sits inside and
    translates along Z to animate extension.

    Args:
        sleeve_r: Sleeve outer radius.
        rod_r: Rod radius (must be < sleeve_r).
        sleeve_h: Sleeve height.
        max_extend: Maximum rod extension distance (for reference).
        segments: Circular segments.
        hex_sleeve: Sleeve material color.
        hex_rod: Rod material color.
        output: Output .blend path.

    Returns:
        Tuple of (sleeve_obj, rod_obj). The rod is parented to the sleeve.
    """
    # Sleeve (outer cylinder)
    sleeve_mesh = _make_cylinder_mesh("Sleeve", sleeve_r, sleeve_h, segments)
    sleeve_obj = bpy.data.objects.new("PistonSleeve", sleeve_mesh)
    bpy.context.scene.collection.objects.link(sleeve_obj)

    mat_sleeve = create_flat_material("SleeveMat", hex_sleeve)
    sleeve_obj.data.materials.append(mat_sleeve)

    # Rod (inner cylinder, extends above sleeve)
    rod_h = sleeve_h * 0.8
    rod_mesh = _make_cylinder_mesh("Rod", rod_r, rod_h, segments)
    rod_obj = bpy.data.objects.new("PistonRod", rod_mesh)
    bpy.context.scene.collection.objects.link(rod_obj)

    mat_rod = create_flat_material("RodMat", hex_rod)
    rod_obj.data.materials.append(mat_rod)

    # Rod starts at top of sleeve
    rod_obj.location = (0, 0, sleeve_h * 0.3)

    # Parent rod to sleeve so they move together
    rod_obj.parent = sleeve_obj

    # Add custom property for extension amount (0 to max_extend)
    sleeve_obj["extend"] = 0.0

    # Flat shading
    for obj in [sleeve_obj, rod_obj]:
        for poly in obj.data.polygons:
            poly.use_smooth = False

    if output:
        os.makedirs(os.path.dirname(output), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=output)

    return sleeve_obj, rod_obj


def animate_piston_extend(rod_obj, extend_value, frame):
    """Set the rod extension at a given frame.

    Args:
        rod_obj: The PistonRod object.
        extend_value: How far to extend (added to Z location).
        frame: Keyframe number.
    """
    rod_obj.location.z = rod_obj.location.z + extend_value
    rod_obj.keyframe_insert(data_path="location", index=2, frame=frame)


if __name__ == "__main__":
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for m in bpy.data.meshes:
        bpy.data.meshes.remove(m)

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    generate_piston(output=os.path.join(OUTPUT_DIR, "piston.blend"))
    print("[prefab] piston.blend generated")
