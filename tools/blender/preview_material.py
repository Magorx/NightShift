"""Generate a .blend preview scene for a procedural material.

Creates a scene with a sphere and a cube side by side, both assigned
the requested material. The .blend file is saved with the full node
graph intact so you can open it in Blender and tweak parameters.

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"

    # Preview a built-in texture (name must match a function in materials.procedural)
    $BLENDER --background --python tools/blender/preview_material.py -- rocky_land "#7A6B5A"

    # With extra kwargs (key=value after the hex color)
    $BLENDER --background --python tools/blender/preview_material.py -- rocky_land "#7A6B5A" bump_strength=0.8

    # Custom output path
    $BLENDER --background --python tools/blender/preview_material.py -- rocky_land "#7A6B5A" --output /tmp/preview.blend

    # Bake PBR texture set (diffuse + normal + height PNGs)
    $BLENDER --background --python tools/blender/preview_material.py -- rocky_land "#7A6B5A" --bake
    $BLENDER --background --python tools/blender/preview_material.py -- rocky_land "#7A6B5A" --bake --bake-size 2048

    Then open the .blend in Blender to see the objects + tweak the shader graph.
"""

import bpy
import sys
import os
from math import radians

# Ensure tools/blender/ is on the path
sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(__file__))))


def _clear_scene():
    """Remove all default objects."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for block in [bpy.data.meshes, bpy.data.materials, bpy.data.cameras,
                  bpy.data.lights]:
        for item in block:
            block.remove(item)


def _create_preview_objects(material):
    """Create a sphere, cube, and a hidden bake plane with the material applied."""
    # Sphere (left)
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=1.0, segments=64, ring_count=32, location=(-1.5, 0, 0))
    sphere = bpy.context.active_object
    sphere.name = "Preview_Sphere"
    bpy.ops.object.shade_smooth()
    sphere.data.materials.append(material)

    # Cube (right)
    bpy.ops.mesh.primitive_cube_add(size=1.8, location=(1.5, 0, 0))
    cube = bpy.context.active_object
    cube.name = "Preview_Cube"
    cube.data.materials.append(material)

    # Flat plane for baking (hidden from render, gives clean UV-space maps)
    bpy.ops.mesh.primitive_plane_add(size=2.0, location=(0, 0, -10))
    plane = bpy.context.active_object
    plane.name = "Bake_Plane"
    plane.hide_render = True
    plane.hide_viewport = True
    plane.data.materials.append(material)

    return sphere, cube, plane


def _setup_camera():
    """Orthographic camera looking at both objects."""
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 6.0

    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.scene.collection.objects.link(cam)

    cam.location = (0, -5, 3)
    cam.rotation_euler = (radians(60), 0, 0)

    bpy.context.scene.camera = cam
    return cam


def _setup_lighting():
    """3-point lighting for material preview."""
    # Key light
    key_data = bpy.data.lights.new("Key", type='SUN')
    key_data.energy = 3.0
    key = bpy.data.objects.new("Key", key_data)
    key.rotation_euler = (radians(50), radians(10), radians(-30))
    bpy.context.scene.collection.objects.link(key)

    # Fill light
    fill_data = bpy.data.lights.new("Fill", type='SUN')
    fill_data.energy = 1.0
    fill = bpy.data.objects.new("Fill", fill_data)
    fill.rotation_euler = (radians(40), radians(-10), radians(150))
    bpy.context.scene.collection.objects.link(fill)

    # Rim light
    rim_data = bpy.data.lights.new("Rim", type='SUN')
    rim_data.energy = 1.5
    rim = bpy.data.objects.new("Rim", rim_data)
    rim.rotation_euler = (radians(10), radians(0), radians(90))
    bpy.context.scene.collection.objects.link(rim)


def _setup_render():
    """Configure EEVEE render settings."""
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 768
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs['Color'].default_value = (0.15, 0.15, 0.17, 1.0)
        bg.inputs['Strength'].default_value = 0.5


def _layout_nodes(material):
    """Auto-arrange shader nodes left-to-right for readability."""
    nodes = material.node_tree.nodes
    # Find the output node and position from there
    output = None
    for n in nodes:
        if n.type == 'OUTPUT_MATERIAL':
            output = n
            break
    if not output:
        return

    # Simple column-based layout: BFS from output backwards
    visited = set()
    columns = {}  # col_index -> [nodes]

    def _walk(node, col):
        if node.name in visited:
            return
        visited.add(node.name)
        columns.setdefault(col, []).append(node)
        for inp in node.inputs:
            for link in inp.links:
                _walk(link.from_node, col + 1)

    _walk(output, 0)

    # Position columns right-to-left
    x = 0
    for col_idx in sorted(columns.keys()):
        col_nodes = columns[col_idx]
        y = 0
        for n in col_nodes:
            n.location = (-col_idx * 300, y)
            y -= n.height + 50
        x -= 300


def main():
    # Parse args after "--"
    argv = sys.argv
    sep = argv.index("--") if "--" in argv else len(argv)
    args = argv[sep + 1:]

    if len(args) < 2:
        print("Usage: preview_material.py -- <texture_name> <hex_color> [key=value ...] [--output path.blend]")
        print("\nAvailable textures:")
        import materials.procedural as proc
        for name in proc.__all__:
            print(f"  {name}")
        sys.exit(1)

    texture_name = args[0]
    hex_color = args[1]

    # Parse flags
    output_path = None
    do_bake = False
    bake_size = 1024
    kwargs = {}
    i = 2
    while i < len(args):
        if args[i] == "--output" and i + 1 < len(args):
            output_path = args[i + 1]
            i += 2
        elif args[i] == "--bake":
            do_bake = True
            i += 1
        elif args[i] == "--bake-size" and i + 1 < len(args):
            bake_size = int(args[i + 1])
            i += 2
        elif "=" in args[i]:
            key, val = args[i].split("=", 1)
            try:
                val = float(val)
            except ValueError:
                pass
            kwargs[key] = val
            i += 1
        else:
            i += 1

    # Default output path
    if not output_path:
        preview_dir = os.path.join(
            os.path.dirname(__file__), "materials", "procedural", "previews")
        os.makedirs(preview_dir, exist_ok=True)
        output_path = os.path.join(preview_dir, f"{texture_name}.blend")

    # Import the texture function
    import materials.procedural as proc
    if not hasattr(proc, texture_name):
        print(f"Error: unknown texture '{texture_name}'")
        print(f"Available: {', '.join(proc.__all__)}")
        sys.exit(1)

    texture_fn = getattr(proc, texture_name)

    # Build scene
    _clear_scene()
    _setup_render()
    _setup_camera()
    _setup_lighting()

    # Use output filename stem as the variant name (allows multiple variants
    # of the same texture without bake collisions, e.g. grassland_dark.blend)
    variant_name = os.path.splitext(os.path.basename(output_path))[0]
    mat = texture_fn(f"preview_{variant_name}", hex_color, **kwargs)
    sphere, cube, bake_plane = _create_preview_objects(mat)
    _layout_nodes(mat)

    # Save .blend
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(output_path))
    print(f"[preview] Saved: {output_path}")
    print(f"[preview] Open in Blender to see the node graph and tweak parameters.")

    # Bake PBR texture set if requested
    if do_bake:
        from bake import bake_texture_set
        bake_dir = os.path.join(os.path.dirname(os.path.abspath(output_path)), f"{variant_name}_maps")
        results = bake_texture_set(bake_plane, mat, bake_dir, texture_size=bake_size)
        for map_name, path in results.items():
            print(f"[preview] Baked {map_name}: {path}")


if __name__ == "__main__":
    main()
