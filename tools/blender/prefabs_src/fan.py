"""Generate an N-blade fan prefab.

Creates a fan with a central hub and flat rectangular blades.
Rotation is animated around the Z axis.

Run standalone:
    blender --background --python tools/blender/prefabs_src/fan.py
"""

import bpy
import bmesh
import os
import sys
import math

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(__file__), "..")))
from materials.pixel_art import create_flat_material

OUTPUT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "prefabs_out"))


def generate_fan(blades=4, radius=1.0, blade_width=0.2, hub_r=0.2,
                 thickness=0.06, segments=12, hex_blade="#7A8898",
                 hex_hub="#6A7888", output=None):
    """Generate a fan with N blades around a central hub.

    Fan lies in the XY plane, centered at origin. Animate via Z rotation.

    Args:
        blades: Number of blades.
        radius: Blade tip radius from center.
        blade_width: Width of each blade (tangential extent).
        hub_r: Hub radius.
        thickness: Blade thickness (Z extent).
        segments: Hub circle segments.
        hex_blade: Blade material color.
        hex_hub: Hub material color.
        output: Output .blend path.

    Returns:
        The fan object (hub + blades as single mesh).
    """
    bm = bmesh.new()
    half_t = thickness / 2

    # Hub cylinder
    hub_top = []
    hub_bot = []
    for i in range(segments):
        angle = (i / segments) * 2 * math.pi
        x = hub_r * math.cos(angle)
        y = hub_r * math.sin(angle)
        hub_top.append(bm.verts.new((x, y, half_t)))
        hub_bot.append(bm.verts.new((x, y, -half_t)))

    bm.verts.ensure_lookup_table()
    bm.faces.new(hub_top)
    bm.faces.new(list(reversed(hub_bot)))
    for i in range(segments):
        j = (i + 1) % segments
        bm.faces.new([hub_bot[i], hub_bot[j], hub_top[j], hub_top[i]])

    # Blades: flat rectangular paddles extending from hub
    half_w = blade_width / 2
    for b in range(blades):
        angle = (b / blades) * 2 * math.pi
        cos_a = math.cos(angle)
        sin_a = math.sin(angle)

        # Blade extends from hub_r to radius along the angle direction
        # Width is perpendicular to the radial direction
        perp_x = -sin_a * half_w
        perp_y = cos_a * half_w

        inner_r = hub_r * 0.9
        # Four corners of the blade rectangle (inner-left, inner-right, outer-right, outer-left)
        pts = [
            (cos_a * inner_r + perp_x, sin_a * inner_r + perp_y),
            (cos_a * inner_r - perp_x, sin_a * inner_r - perp_y),
            (cos_a * radius - perp_x, sin_a * radius - perp_y),
            (cos_a * radius + perp_x, sin_a * radius + perp_y),
        ]

        blade_top = [bm.verts.new((p[0], p[1], half_t)) for p in pts]
        blade_bot = [bm.verts.new((p[0], p[1], -half_t)) for p in pts]
        bm.verts.ensure_lookup_table()

        bm.faces.new(blade_top)
        bm.faces.new(list(reversed(blade_bot)))
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new([blade_bot[i], blade_bot[j], blade_top[j], blade_top[i]])

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("Fan")
    bm.to_mesh(mesh)
    bm.free()
    mesh.validate()

    obj = bpy.data.objects.new("Fan", mesh)
    bpy.context.scene.collection.objects.link(obj)

    mat = create_flat_material("FanMat", hex_blade)
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
    generate_fan(output=os.path.join(OUTPUT_DIR, "fan.blend"))
    print("[prefab] fan.blend generated")
