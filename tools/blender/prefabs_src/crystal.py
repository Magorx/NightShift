"""Generate a crystal/mineral cluster prefab.

Creates angular crystalline formations for resource deposits.
Each crystal is a hexagonal prism with a pointed tip, clustered
at slightly random angles for a natural look.

Run standalone:
    blender --background --python tools/blender/prefabs_src/crystal.py
"""

import bpy
import bmesh
import os
import sys
import math
import random

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(__file__), "..")))
from materials.pixel_art import create_flat_material

OUTPUT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "prefabs_out"))


def _make_hex_prism(bm, radius, height, tip_height, base_z=0):
    """Create a single hexagonal crystal with a pointed tip.

    Returns list of created verts for reference.
    """
    sides = 6
    bot_verts = []
    top_verts = []
    for i in range(sides):
        angle = (i / sides) * 2 * math.pi
        x = radius * math.cos(angle)
        y = radius * math.sin(angle)
        bot_verts.append(bm.verts.new((x, y, base_z)))
        top_verts.append(bm.verts.new((x, y, base_z + height)))

    # Tip vertex
    tip = bm.verts.new((0, 0, base_z + height + tip_height))

    bm.verts.ensure_lookup_table()

    # Bottom cap
    bm.faces.new(list(reversed(bot_verts)))

    # Side faces
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new([bot_verts[i], bot_verts[j], top_verts[j], top_verts[i]])

    # Tip faces (triangles from top ring to tip)
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new([top_verts[i], top_verts[j], tip])

    return bot_verts + top_verts + [tip]


def generate_crystal(num_crystals=5, base_radius=0.3, base_height=0.8,
                     tip_ratio=0.4, spread=0.6, seed=42,
                     hex_color="#96A4B4", output=None):
    """Generate a cluster of hexagonal crystals.

    Creates a natural-looking mineral formation by placing multiple
    crystals with random size variation and slight tilts.

    Args:
        num_crystals: Number of crystals in the cluster.
        base_radius: Average crystal radius.
        base_height: Average crystal height.
        tip_ratio: Tip height as fraction of crystal height.
        spread: How far crystals spread from center (0=all centered).
        seed: Random seed for reproducible formations.
        hex_color: Crystal material color.
        output: Output .blend path.

    Returns:
        The crystal cluster object.
    """
    rng = random.Random(seed)
    bm = bmesh.new()

    for i in range(num_crystals):
        # Random variation
        scale = rng.uniform(0.5, 1.5)
        r = base_radius * scale * rng.uniform(0.7, 1.0)
        h = base_height * scale
        tip_h = h * tip_ratio * rng.uniform(0.6, 1.2)

        # Random offset from center
        if i == 0:
            ox, oy = 0, 0  # Center crystal
        else:
            angle = rng.uniform(0, 2 * math.pi)
            dist = rng.uniform(0.1, spread)
            ox = dist * math.cos(angle)
            oy = dist * math.sin(angle)

        # Build crystal in a temporary bmesh, then merge
        temp_bm = bmesh.new()
        _make_hex_prism(temp_bm, r, h, tip_h, base_z=0)

        # Apply slight random tilt
        tilt_x = rng.uniform(-0.15, 0.15)
        tilt_y = rng.uniform(-0.15, 0.15)

        # Transform verts: tilt then translate
        for v in temp_bm.verts:
            # Simple rotation approximation for small angles
            z = v.co.z
            v.co.x += z * math.sin(tilt_x) + ox
            v.co.y += z * math.sin(tilt_y) + oy

        # Merge into main bmesh
        temp_mesh = bpy.data.meshes.new(f"TempCrystal_{i}")
        temp_bm.to_mesh(temp_mesh)
        temp_bm.free()

        # Read verts/faces from temp mesh into main bm
        vert_map = {}
        for v in temp_mesh.vertices:
            new_v = bm.verts.new(v.co)
            vert_map[v.index] = new_v

        bm.verts.ensure_lookup_table()
        for poly in temp_mesh.polygons:
            face_verts = [vert_map[vi] for vi in poly.vertices]
            try:
                bm.faces.new(face_verts)
            except ValueError:
                pass  # Skip duplicate faces

        bpy.data.meshes.remove(temp_mesh)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("Crystal")
    bm.to_mesh(mesh)
    bm.free()
    mesh.validate()

    obj = bpy.data.objects.new("Crystal", mesh)
    bpy.context.scene.collection.objects.link(obj)

    mat = create_flat_material("CrystalMat", hex_color)
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
    generate_crystal(output=os.path.join(OUTPUT_DIR, "crystal.blend"))
    print("[prefab] crystal.blend generated")
