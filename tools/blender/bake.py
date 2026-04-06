"""Texture baking utilities.

Bakes procedural shader node materials to image textures so they
survive glTF export. Supports single-map baking (diffuse only for glTF)
and full PBR texture set baking (diffuse + normal + height).

Usage:
    from bake import bake_all_materials, bake_texture_set

    # For glTF export (replaces node trees with image textures):
    bake_all_materials(texture_size=256)

    # For PBR texture set (saves PNGs, preserves node tree):
    bake_texture_set(obj, mat, output_dir="textures/", texture_size=1024)
"""

import bpy
import os
import numpy as np


def _uv_unwrap_object(obj):
    """Smart UV project an object if it has no UVs."""
    if obj.type != 'MESH':
        return
    if len(obj.data.uv_layers) > 0:
        return

    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=66, margin_method='SCALED', island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.select_set(False)


def _is_procedural(mat):
    """Check if a material uses procedural nodes (not just Principled BSDF with constants)."""
    if not mat or not mat.use_nodes:
        return False
    nodes = mat.node_tree.nodes
    procedural_types = {
        'ShaderNodeTexNoise', 'ShaderNodeTexVoronoi', 'ShaderNodeTexWave',
        'ShaderNodeTexBrick', 'ShaderNodeTexChecker', 'ShaderNodeTexGradient',
        'ShaderNodeTexMagic', 'ShaderNodeTexMusgrave', 'ShaderNodeTexImage',
        'ShaderNodeValToRGB', 'ShaderNodeBump', 'ShaderNodeNormalMap',
        'ShaderNodeMixRGB', 'ShaderNodeMapRange', 'ShaderNodeSeparateXYZ',
        'ShaderNodeTexCoord',
    }
    for node in nodes:
        if node.bl_idname in procedural_types:
            return True
    return False


def _replace_with_baked(mat, image):
    """Replace a material's node tree with a simple image texture setup."""
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    output = None
    for node in nodes:
        if node.type == 'OUTPUT_MATERIAL':
            output = node
            break

    for node in list(nodes):
        if node != output:
            nodes.remove(node)

    bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    bsdf.inputs['Roughness'].default_value = 1.0
    bsdf.inputs['Metallic'].default_value = 0.0

    img_node = nodes.new(type='ShaderNodeTexImage')
    img_node.image = image

    links.new(img_node.outputs['Color'], bsdf.inputs['Base Color'])
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])


def _height_to_normal(height_img, output_path, size, strength=2.0):
    """Convert a baked height map to a tangent-space normal map via Sobel filter."""
    # Read height pixels into numpy array
    pixels = np.array(height_img.pixels[:], dtype=np.float32)
    # Image pixels are RGBA flat array
    pixels = pixels.reshape((size, size, 4))
    # Use red channel as height (grayscale)
    h = pixels[:, :, 0]

    # Sobel gradients (wrapped edges for tileability)
    dx = np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)
    dy = np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)

    dx *= strength
    dy *= strength

    # Build normal vectors: (-dx, -dy, 1), then normalize
    nx = -dx
    ny = dy  # flip Y for tangent space (image Y is top-down)
    nz = np.ones_like(nx)

    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx /= length
    ny /= length
    nz /= length

    # Encode to 0-1 range (tangent space: 0.5, 0.5, 1.0 = flat)
    nx = nx * 0.5 + 0.5
    ny = ny * 0.5 + 0.5
    nz = nz * 0.5 + 0.5

    # Write to new image
    normal_img = bpy.data.images.new(
        os.path.basename(output_path).replace('.png', ''),
        size, size, alpha=False)
    normal_img.colorspace_settings.name = 'Non-Color'

    out = np.zeros((size, size, 4), dtype=np.float32)
    out[:, :, 0] = nx
    out[:, :, 1] = ny
    out[:, :, 2] = nz
    out[:, :, 3] = 1.0
    normal_img.pixels[:] = out.flatten()

    normal_img.filepath_raw = output_path
    normal_img.file_format = 'PNG'
    normal_img.save()


def _find_height_source(mat):
    """Find the height output node in a material (labeled 'Height').

    Returns the output socket to use for height baking, or None.
    """
    for node in mat.node_tree.nodes:
        if 'height' in node.label.lower() and '(for baking)' in node.label.lower():
            # Return the first output
            if node.outputs:
                return node.outputs[0]

    # Fallback: look for any node with 'Height' in label
    for node in mat.node_tree.nodes:
        if 'height' in node.label.lower():
            if node.outputs:
                return node.outputs[0]

    # Last resort: find the Bump node chain and use its Height input source
    for node in mat.node_tree.nodes:
        if node.bl_idname == 'ShaderNodeBump':
            for link in node.inputs['Height'].links:
                return link.from_socket

    return None


def _bake_pass(obj, mat, image, bake_type='DIFFUSE'):
    """Bake a single pass into an image."""
    nodes = mat.node_tree.nodes

    # Add temporary bake target
    img_node = nodes.new(type='ShaderNodeTexImage')
    img_node.image = image
    img_node.select = True
    nodes.active = img_node

    bpy.ops.object.select_all(action='DESELECT')
    # Temporarily unhide if needed (bake requires visible object)
    was_hidden = obj.hide_viewport
    was_hidden_render = obj.hide_render
    obj.hide_viewport = False
    obj.hide_render = False
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    if bake_type == 'DIFFUSE':
        bpy.context.scene.cycles.bake_type = 'DIFFUSE'
        bpy.context.scene.render.bake.use_pass_direct = False
        bpy.context.scene.render.bake.use_pass_indirect = False
        bpy.context.scene.render.bake.use_pass_color = True
        bpy.ops.object.bake(type='DIFFUSE')
    elif bake_type == 'NORMAL':
        bpy.context.scene.cycles.bake_type = 'NORMAL'
        bpy.ops.object.bake(type='NORMAL')
    elif bake_type == 'EMIT':
        bpy.context.scene.cycles.bake_type = 'EMIT'
        bpy.ops.object.bake(type='EMIT')

    nodes.remove(img_node)
    obj.hide_viewport = was_hidden
    obj.hide_render = was_hidden_render


def bake_texture_set(obj, mat, output_dir, texture_size=1024, maps=None):
    """Bake a full PBR texture set from a procedural material.

    Saves diffuse, normal, and height maps as PNGs. Does NOT replace
    the material's node tree — the procedural graph stays intact.

    For the height map, looks for a node labeled "Height (for baking)"
    in the material. If not found, falls back to the first Bump input source.

    Args:
        obj: Mesh object to bake on.
        mat: Material with procedural nodes.
        output_dir: Directory for output PNGs.
        texture_size: Resolution (square).
        maps: List of maps to bake. Default: ['diffuse', 'normal', 'height'].

    Returns:
        Dict of map_name -> file_path for each baked map.
    """
    if maps is None:
        maps = ['diffuse', 'normal', 'height']

    scene = bpy.context.scene
    original_engine = scene.render.engine

    os.makedirs(output_dir, exist_ok=True)

    # UV unwrap if needed
    _uv_unwrap_object(obj)

    # Switch to Cycles for baking
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 1

    base_name = mat.name.replace("preview_", "")
    results = {}
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    # --- Diffuse ---
    if 'diffuse' in maps:
        print(f"[bake] Baking diffuse for {mat.name} ({texture_size}x{texture_size})")
        img = bpy.data.images.new(f"{base_name}_diffuse", texture_size, texture_size, alpha=False)
        _bake_pass(obj, mat, img, 'DIFFUSE')
        path = os.path.join(output_dir, f"{base_name}_diffuse.png")
        img.filepath_raw = path
        img.file_format = 'PNG'
        img.save()
        results['diffuse'] = path
        print(f"[bake]   -> {path}")

    # --- Height (via Emission trick) — bake before normal so we can derive normal from it ---
    if 'height' in maps:
        height_source = _find_height_source(mat)
        if height_source:
            print(f"[bake] Baking height for {mat.name} ({texture_size}x{texture_size})")

            # Save existing connections to Material Output
            output_node = nodes.get("Material Output")
            old_surface_link = None
            for link in output_node.inputs['Surface'].links:
                old_surface_link = (link.from_socket, link.to_socket)
                break

            # Temporarily wire: height -> Emission -> Output
            emit = nodes.new(type='ShaderNodeEmission')
            emit.name = '_bake_temp_emit'
            links.new(height_source, emit.inputs['Color'])
            links.new(emit.outputs['Emission'], output_node.inputs['Surface'])

            img = bpy.data.images.new(f"{base_name}_height", texture_size, texture_size, alpha=False)
            img.colorspace_settings.name = 'Non-Color'
            _bake_pass(obj, mat, img, 'EMIT')
            path = os.path.join(output_dir, f"{base_name}_height.png")
            img.filepath_raw = path
            img.file_format = 'PNG'
            img.save()
            results['height'] = path
            print(f"[bake]   -> {path}")

            # Restore original connection
            nodes.remove(emit)
            if old_surface_link:
                links.new(old_surface_link[0], old_surface_link[1])
        else:
            print(f"[bake] No height source found in {mat.name}, skipping height map")

    # --- Normal (derived from height map) ---
    if 'normal' in maps and 'height' in results:
        print(f"[bake] Generating normal from height map ({texture_size}x{texture_size})")
        height_img = bpy.data.images.get(f"{base_name}_height")
        normal_path = os.path.join(output_dir, f"{base_name}_normal.png")
        _height_to_normal(height_img, normal_path, texture_size)
        results['normal'] = normal_path
        print(f"[bake]   -> {normal_path}")
    elif 'normal' in maps:
        print(f"[bake] No height map available, skipping normal map")

    scene.render.engine = original_engine
    print(f"[bake] Done. Baked {len(results)} maps.")
    return results


def bake_all_materials(texture_size=256, output_dir=None):
    """Bake all procedural materials in the scene to image textures.

    This:
    1. UV-unwraps any mesh objects that lack UVs
    2. For each procedural material, creates a bake target image
    3. Switches to Cycles, bakes DIFFUSE color (no lighting)
    4. Replaces the material's node tree with a simple image texture
    5. Switches back to EEVEE

    Args:
        texture_size: Bake image resolution (square).
        output_dir: Directory to save baked PNGs. None = don't save to disk
            (images stay packed in the .blend/.glb).
    """
    scene = bpy.context.scene
    original_engine = scene.render.engine

    bake_tasks = []
    for obj in scene.objects:
        if obj.type != 'MESH':
            continue
        for i, slot in enumerate(obj.material_slots):
            if slot.material and _is_procedural(slot.material):
                bake_tasks.append((obj, slot.material, i))

    if not bake_tasks:
        return

    bpy.ops.object.select_all(action='DESELECT')
    seen_objects = set()
    for obj, mat, _ in bake_tasks:
        if obj.name not in seen_objects:
            _uv_unwrap_object(obj)
            seen_objects.add(obj.name)

    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 1
    scene.cycles.bake_type = 'DIFFUSE'
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True

    baked_materials = {}
    for obj, mat, slot_idx in bake_tasks:
        if mat.name in baked_materials:
            continue

        print(f"[bake] Baking {mat.name} on {obj.name} ({texture_size}x{texture_size})")

        img_name = f"bake_{mat.name}"
        img = bpy.data.images.new(img_name, texture_size, texture_size, alpha=True)

        nodes = mat.node_tree.nodes
        img_node = nodes.new(type='ShaderNodeTexImage')
        img_node.image = img
        img_node.select = True
        nodes.active = img_node

        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        obj.active_material_index = slot_idx

        bpy.ops.object.bake(type='DIFFUSE')

        if output_dir:
            os.makedirs(output_dir, exist_ok=True)
            img.filepath_raw = os.path.join(output_dir, f"{img_name}.png")
            img.file_format = 'PNG'
            img.save()

        img.pack()
        baked_materials[mat.name] = img
        nodes.remove(img_node)

    for mat_name, img in baked_materials.items():
        mat = bpy.data.materials.get(mat_name)
        if mat:
            _replace_with_baked(mat, img)

    scene.render.engine = original_engine
    print(f"[bake] Done. Baked {len(baked_materials)} materials.")
