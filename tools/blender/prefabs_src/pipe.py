"""Generate a pipe section prefab.

Creates a hollow cylinder with optional flange caps at each end.
The pipe runs along a configurable axis.

Run standalone:
    blender --background --python tools/blender/prefabs_src/pipe.py
"""

import bpy
import bmesh
import os
import sys
import math

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(__file__), "..")))
from materials.pixel_art import create_flat_material

OUTPUT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "prefabs_out"))


def _make_ring(bm, radius, segments, z):
    """Create a ring of vertices at height z."""
    verts = []
    for i in range(segments):
        angle = (i / segments) * 2 * math.pi
        x = radius * math.cos(angle)
        y = radius * math.sin(angle)
        verts.append(bm.verts.new((x, y, z)))
    return verts


def generate_pipe(length=2.0, radius=0.3, wall_thickness=0.08, segments=12,
                  flange_radius=None, flange_thickness=0.06,
                  hex_color="#372A23", hex_flange="#413428", output=None):
    """Generate a hollow pipe with flange caps.

    The pipe runs along the Z axis, centered at origin. Rotate after
    placement to align with desired direction.

    Args:
        length: Pipe length.
        radius: Outer radius.
        wall_thickness: Thickness of the pipe wall.
        segments: Number of circular segments.
        flange_radius: Flange outer radius (None = radius * 1.3).
        flange_thickness: Height of each flange cap.
        hex_color: Pipe body color.
        hex_flange: Flange cap color.
        output: Output .blend path.

    Returns:
        The pipe object.
    """
    if flange_radius is None:
        flange_radius = radius * 1.3

    inner_radius = radius - wall_thickness
    half_len = length / 2
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")

    circumference = 2 * math.pi * radius
    max_dim = max(2 * flange_radius, length)

    def _cylindrical_uv(face, r, z_offset=0):
        """Assign cylindrical UVs to a side face."""
        for loop in face.loops:
            angle = math.atan2(loop.vert.co.y, loop.vert.co.x)
            if angle < 0:
                angle += 2 * math.pi
            loop[uv_layer].uv = (angle * r / max_dim,
                                  (loop.vert.co.z + half_len) / max_dim)

    def _planar_uv(face):
        """Assign planar XY UVs to a cap face."""
        for loop in face.loops:
            loop[uv_layer].uv = (loop.vert.co.x / max_dim + 0.5,
                                  loop.vert.co.y / max_dim + 0.5)

    # Outer cylinder
    outer_bot = _make_ring(bm, radius, segments, -half_len)
    outer_top = _make_ring(bm, radius, segments, half_len)

    # Inner cylinder (hole)
    inner_bot = _make_ring(bm, inner_radius, segments, -half_len)
    inner_top = _make_ring(bm, inner_radius, segments, half_len)

    bm.verts.ensure_lookup_table()

    # Outer side faces
    for i in range(segments):
        j = (i + 1) % segments
        face = bm.faces.new([outer_bot[i], outer_bot[j], outer_top[j], outer_top[i]])
        u0 = (i / segments) * circumference / max_dim
        u1 = ((i + 1) / segments) * circumference / max_dim
        uvs = [(u0, 0), (u1, 0), (u1, length / max_dim), (u0, length / max_dim)]
        for loop, uv in zip(face.loops, uvs):
            loop[uv_layer].uv = uv

    # Inner side faces (reversed winding for inward-facing normals)
    inner_circ = 2 * math.pi * inner_radius
    for i in range(segments):
        j = (i + 1) % segments
        face = bm.faces.new([inner_bot[j], inner_bot[i], inner_top[i], inner_top[j]])
        u0 = (i / segments) * inner_circ / max_dim
        u1 = ((i + 1) / segments) * inner_circ / max_dim
        uvs = [(u1, 0), (u0, 0), (u0, length / max_dim), (u1, length / max_dim)]
        for loop, uv in zip(face.loops, uvs):
            loop[uv_layer].uv = uv

    # Top and bottom annular caps
    for i in range(segments):
        j = (i + 1) % segments
        top_cap = bm.faces.new([outer_top[i], outer_top[j], inner_top[j], inner_top[i]])
        _planar_uv(top_cap)
        bot_cap = bm.faces.new([outer_bot[j], outer_bot[i], inner_bot[i], inner_bot[j]])
        _planar_uv(bot_cap)

    # Flanges: wider discs at each end
    for z_pos in [-half_len, half_len]:
        fl_outer = _make_ring(bm, flange_radius, segments, z_pos)
        fl_inner = _make_ring(bm, radius, segments, z_pos)
        fh = flange_thickness if z_pos < 0 else -flange_thickness
        fl_outer2 = _make_ring(bm, flange_radius, segments, z_pos + fh)
        fl_inner2 = _make_ring(bm, radius, segments, z_pos + fh)

        bm.verts.ensure_lookup_table()

        fl_circ = 2 * math.pi * flange_radius
        for i in range(segments):
            j = (i + 1) % segments
            u0 = (i / segments) * fl_circ / max_dim
            u1 = ((i + 1) / segments) * fl_circ / max_dim
            fh_uv = abs(flange_thickness) / max_dim
            # Outer face of flange
            face = bm.faces.new([fl_outer[i], fl_outer[j], fl_outer2[j], fl_outer2[i]])
            uvs = [(u0, 0), (u1, 0), (u1, fh_uv), (u0, fh_uv)]
            for loop, uv in zip(face.loops, uvs):
                loop[uv_layer].uv = uv
            # Inner face (connects to pipe body)
            face = bm.faces.new([fl_inner[j], fl_inner[i], fl_inner2[i], fl_inner2[j]])
            for loop, uv in zip(face.loops, uvs):
                loop[uv_layer].uv = uv
            # Front/back cap of flange
            face = bm.faces.new([fl_outer[i], fl_outer[j], fl_inner[j], fl_inner[i]])
            _planar_uv(face)
            face = bm.faces.new([fl_outer2[j], fl_outer2[i], fl_inner2[i], fl_inner2[j]])
            _planar_uv(face)

    # Finalize — recalculate normals so all faces point outward
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("Pipe")
    bm.to_mesh(mesh)
    bm.free()
    mesh.validate()

    obj = bpy.data.objects.new("Pipe", mesh)
    bpy.context.scene.collection.objects.link(obj)

    mat_body = create_flat_material("PipeMat", hex_color)
    obj.data.materials.append(mat_body)

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
    generate_pipe(output=os.path.join(OUTPUT_DIR, "pipe.blend"))
    print("[prefab] pipe.blend generated")
