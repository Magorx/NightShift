"""Texture baking utilities.

Bakes procedural shader node materials to image textures so they
survive glTF export. After baking, each material's node tree is
replaced with a simple Principled BSDF reading from the baked image.

Usage:
    from bake import bake_all_materials
    # After building scene, before export:
    bake_all_materials(texture_size=256)
"""

import bpy
import os


def _uv_unwrap_object(obj):
    """Smart UV project an object if it has no UVs."""
    if obj.type != 'MESH':
        return
    if len(obj.data.uv_layers) > 0:
        return

    # Must be active and selected for UV ops
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

    # Remember the output node
    output = None
    for node in nodes:
        if node.type == 'OUTPUT_MATERIAL':
            output = node
            break

    # Clear all nodes except output
    for node in list(nodes):
        if node != output:
            nodes.remove(node)

    # New Principled BSDF
    bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    bsdf.inputs['Roughness'].default_value = 1.0
    bsdf.inputs['Metallic'].default_value = 0.0

    # Image texture node
    img_node = nodes.new(type='ShaderNodeTexImage')
    img_node.image = image

    links.new(img_node.outputs['Color'], bsdf.inputs['Base Color'])
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])


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

    # Collect all mesh objects and their procedural materials
    bake_tasks = []  # (obj, mat, mat_slot_index)
    for obj in scene.objects:
        if obj.type != 'MESH':
            continue
        for i, slot in enumerate(obj.material_slots):
            if slot.material and _is_procedural(slot.material):
                bake_tasks.append((obj, slot.material, i))

    if not bake_tasks:
        return

    # UV unwrap all objects that need it
    bpy.ops.object.select_all(action='DESELECT')
    seen_objects = set()
    for obj, mat, _ in bake_tasks:
        if obj.name not in seen_objects:
            _uv_unwrap_object(obj)
            seen_objects.add(obj.name)

    # Switch to Cycles for baking
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 1
    scene.cycles.bake_type = 'DIFFUSE'
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True

    # Bake each unique material once
    baked_materials = {}  # mat.name -> baked image
    for obj, mat, slot_idx in bake_tasks:
        if mat.name in baked_materials:
            continue

        print(f"[bake] Baking {mat.name} on {obj.name} ({texture_size}x{texture_size})")

        # Create bake target image
        img_name = f"bake_{mat.name}"
        img = bpy.data.images.new(img_name, texture_size, texture_size, alpha=True)

        # Add image texture node to material (must be active/selected for bake)
        nodes = mat.node_tree.nodes
        img_node = nodes.new(type='ShaderNodeTexImage')
        img_node.image = img
        img_node.select = True
        nodes.active = img_node

        # Select only this object and make it active
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj

        # Set the material slot as active
        obj.active_material_index = slot_idx

        # Bake
        bpy.ops.object.bake(type='DIFFUSE')

        # Save image to disk if requested
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)
            img.filepath_raw = os.path.join(output_dir, f"{img_name}.png")
            img.file_format = 'PNG'
            img.save()

        # Pack image into blend file so it embeds in .glb
        img.pack()

        baked_materials[mat.name] = img

        # Remove the temporary image node
        nodes.remove(img_node)

    # Replace all procedural materials with baked image textures
    for mat_name, img in baked_materials.items():
        mat = bpy.data.materials.get(mat_name)
        if mat:
            _replace_with_baked(mat, img)

    # Switch back to original engine
    scene.render.engine = original_engine

    print(f"[bake] Done. Baked {len(baked_materials)} materials.")
