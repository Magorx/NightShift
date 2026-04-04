"""Generate a gear/cog prefab.

Creates a toothed gear mesh using bmesh. The gear lies flat in the XY plane
with teeth protruding radially. Rotation is around the Z axis.

Run standalone:
    blender --background --python tools/blender/prefabs_src/cog.py
"""

import bpy
import bmesh
import os
import sys
import math

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(__file__), "..")))
from materials.pixel_art import create_flat_material

OUTPUT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "prefabs_out"))


def generate_cog(outer_radius=1.0, inner_radius=0.7, teeth=8, thickness=0.3,
                 tooth_width_outer=0.35, tooth_width_inner=0.5,
                 valley_steps=3, hex_color="#96A4B4", output=None):
    """Generate a gear/cog mesh.

    The gear is centered at the origin, lying in the XY plane. Each tooth
    is a trapezoid: wider at the base (inner_radius), narrower at the tip
    (outer_radius), like a real involute gear profile.

    Args:
        outer_radius: Radius to tooth tips.
        inner_radius: Radius at tooth valleys.
        teeth: Number of teeth.
        thickness: Gear thickness (Z extent).
        tooth_width_outer: Tooth width at outer_radius as fraction of tooth pitch (0-1).
        tooth_width_inner: Tooth width at inner_radius as fraction of tooth pitch (0-1).
            Set > tooth_width_outer for tapered teeth (like reference image).
            Set equal for rectangular teeth.
        valley_steps: Number of arc steps along the valley floor between teeth.
        hex_color: Material color.
        output: Output .blend path.

    Returns:
        The gear object.
    """
    bm = bmesh.new()
    half_t = thickness / 2

    tooth_pitch = 2 * math.pi / teeth
    outer_half = tooth_pitch * tooth_width_outer / 2
    inner_half = tooth_pitch * tooth_width_inner / 2

    top_verts = []
    bot_verts = []

    for t in range(teeth):
        center_angle = t * tooth_pitch

        # Trapezoid tooth profile:
        #   - Inner edge (base) spans center ± inner_half at inner_radius
        #   - Outer edge (tip) spans center ± outer_half at outer_radius
        # Valley is the arc at inner_radius between adjacent teeth.

        inner_start = center_angle - inner_half
        inner_end = center_angle + inner_half
        outer_start = center_angle - outer_half
        outer_end = center_angle + outer_half
        next_inner_start = center_angle + tooth_pitch - inner_half

        points = []
        # 1. Tooth base leading edge (inner_radius)
        points.append((inner_start, inner_radius))
        # 2. Tooth tip leading edge (outer_radius)
        points.append((outer_start, outer_radius))
        # 3. Tooth tip trailing edge (outer_radius)
        points.append((outer_end, outer_radius))
        # 4. Tooth base trailing edge (inner_radius)
        points.append((inner_end, inner_radius))
        # 5. Valley floor arc at inner_radius to next tooth
        for s in range(1, valley_steps + 1):
            frac = s / (valley_steps + 1)
            valley_angle = inner_end + frac * (next_inner_start - inner_end)
            points.append((valley_angle, inner_radius))

        for angle, r in points:
            x = r * math.cos(angle)
            y = r * math.sin(angle)
            top_verts.append(bm.verts.new((x, y, half_t)))
            bot_verts.append(bm.verts.new((x, y, -half_t)))

    # Hub hole vertices (inner circle)
    hub_radius = inner_radius * 0.4
    hub_segments = max(teeth * 2, 12)
    hub_top = []
    hub_bot = []
    for i in range(hub_segments):
        angle = (i / hub_segments) * 2 * math.pi
        x = hub_radius * math.cos(angle)
        y = hub_radius * math.sin(angle)
        hub_top.append(bm.verts.new((x, y, half_t)))
        hub_bot.append(bm.verts.new((x, y, -half_t)))

    bm.verts.ensure_lookup_table()
    n = len(top_verts)
    nh = len(hub_top)

    # Top and bottom faces (outer gear profile)
    bm.faces.new(top_verts)
    bm.faces.new(list(reversed(bot_verts)))

    # Side faces connecting top and bottom around the gear profile
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([top_verts[i], top_verts[j], bot_verts[j], bot_verts[i]])

    # Hub cylinder (inner hole visual)
    bm.faces.new(list(reversed(hub_top)))
    bm.faces.new(hub_bot)
    for i in range(nh):
        j = (i + 1) % nh
        bm.faces.new([hub_top[i], hub_top[j], hub_bot[j], hub_bot[i]])

    # Finalize — recalculate normals so all faces point outward
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("Cog")
    bm.to_mesh(mesh)
    bm.free()
    mesh.validate()

    obj = bpy.data.objects.new("Cog", mesh)
    bpy.context.scene.collection.objects.link(obj)

    mat = create_flat_material("CogMat", hex_color)
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
    generate_cog(output=os.path.join(OUTPUT_DIR, "cog.blend"))
    print("[prefab] cog.blend generated")
