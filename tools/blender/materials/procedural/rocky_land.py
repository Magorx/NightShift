"""Rocky terrain surface with layered stone detail."""

from materials.procedural._base import setup_material
from materials.pixel_art import hex_to_rgba


def rocky_land(name, hex_color, crack_color=None, roughness_var=0.15,
               rock_scale=4.0, crack_scale=8.0, bump_strength=1.0):
    """Rocky terrain with layered stone cracks and surface variation.

    Combines Voronoi (cracked rock structure) with Noise (surface
    roughness variation) for a natural stone/land appearance.
    Bump mapping gives depth to cracks and ridges.

    Args:
        name: Material name.
        hex_color: Base rock color.
        crack_color: Color inside cracks (None = 40% darker base).
        roughness_var: How much the surface roughness varies (0-1).
        rock_scale: Scale of the large rock cell pattern.
        crack_scale: Scale of fine crack detail.
        bump_strength: Bump map intensity (0-1).

    Returns:
        The Blender material.
    """
    mat, nodes, links = setup_material(name)

    bsdf = nodes.get("Principled BSDF")
    base_rgba = hex_to_rgba(hex_color)

    if crack_color:
        crack_rgba = hex_to_rgba(crack_color)
    else:
        crack_rgba = (
            base_rgba[0] * 0.35,
            base_rgba[1] * 0.32,
            base_rgba[2] * 0.28,
            1.0,
        )

    # --- Texture coordinates ---
    tex_coord = nodes.new(type='ShaderNodeTexCoord')

    # --- Layer 1: Large rock cells (Voronoi) ---
    voronoi_big = nodes.new(type='ShaderNodeTexVoronoi')
    voronoi_big.feature = 'DISTANCE_TO_EDGE'
    voronoi_big.inputs['Scale'].default_value = rock_scale
    voronoi_big.inputs['Randomness'].default_value = 0.8
    links.new(tex_coord.outputs['Object'], voronoi_big.inputs['Vector'])

    # Ramp: sharp crack edges from Voronoi distance
    crack_ramp = nodes.new(type='ShaderNodeValToRGB')
    crack_ramp.color_ramp.interpolation = 'EASE'
    crack_ramp.color_ramp.elements[0].position = 0.0
    crack_ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    crack_ramp.color_ramp.elements[1].position = 0.08
    crack_ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    links.new(voronoi_big.outputs['Distance'], crack_ramp.inputs['Fac'])

    # --- Layer 2: Fine cracks (higher-frequency Voronoi) ---
    voronoi_fine = nodes.new(type='ShaderNodeTexVoronoi')
    voronoi_fine.feature = 'DISTANCE_TO_EDGE'
    voronoi_fine.inputs['Scale'].default_value = crack_scale
    voronoi_fine.inputs['Randomness'].default_value = 1.0
    links.new(tex_coord.outputs['Object'], voronoi_fine.inputs['Vector'])

    fine_ramp = nodes.new(type='ShaderNodeValToRGB')
    fine_ramp.color_ramp.interpolation = 'EASE'
    fine_ramp.color_ramp.elements[0].position = 0.0
    fine_ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    fine_ramp.color_ramp.elements[1].position = 0.06
    fine_ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    links.new(voronoi_fine.outputs['Distance'], fine_ramp.inputs['Fac'])

    # Multiply the two crack masks together (both must be "rock" to be rock)
    crack_combine = nodes.new(type='ShaderNodeMath')
    crack_combine.operation = 'MULTIPLY'
    links.new(crack_ramp.outputs['Color'], crack_combine.inputs[0])
    links.new(fine_ramp.outputs['Color'], crack_combine.inputs[1])

    # --- Layer 3: Surface noise for color variation ---
    noise = nodes.new(type='ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = rock_scale * 3.0
    noise.inputs['Detail'].default_value = 6.0
    noise.inputs['Roughness'].default_value = 0.7
    links.new(tex_coord.outputs['Object'], noise.inputs['Vector'])

    # Color variation across rock faces
    color_bright = (
        min(base_rgba[0] * 1.25, 1.0),
        min(base_rgba[1] * 1.2, 1.0),
        min(base_rgba[2] * 1.15, 1.0),
        1.0,
    )
    color_var = nodes.new(type='ShaderNodeMixRGB')
    color_var.blend_type = 'MIX'
    color_var.inputs['Color1'].default_value = base_rgba
    color_var.inputs['Color2'].default_value = color_bright
    links.new(noise.outputs['Fac'], color_var.inputs['Fac'])

    # --- Combine: rock surface vs crack color ---
    color_final = nodes.new(type='ShaderNodeMixRGB')
    color_final.blend_type = 'MIX'
    color_final.inputs['Color1'].default_value = crack_rgba
    color_final.inputs['Color2'].default_value = base_rgba
    links.new(crack_combine.outputs['Value'], color_final.inputs['Fac'])

    # Overlay the surface noise on top
    color_overlay = nodes.new(type='ShaderNodeMixRGB')
    color_overlay.blend_type = 'OVERLAY'
    color_overlay.inputs['Fac'].default_value = 0.6
    links.new(color_final.outputs['Color'], color_overlay.inputs['Color1'])
    links.new(color_var.outputs['Color'], color_overlay.inputs['Color2'])

    links.new(color_overlay.outputs['Color'], bsdf.inputs['Base Color'])

    # --- Bump: combine both crack layers for geometry ---
    # Large cracks are deeper
    bump_big = nodes.new(type='ShaderNodeBump')
    bump_big.inputs['Strength'].default_value = bump_strength
    bump_big.inputs['Distance'].default_value = 0.15
    bump_big.invert = True  # cracks go inward
    links.new(voronoi_big.outputs['Distance'], bump_big.inputs['Height'])

    # Fine cracks layered on top
    bump_fine = nodes.new(type='ShaderNodeBump')
    bump_fine.inputs['Strength'].default_value = bump_strength * 0.5
    bump_fine.inputs['Distance'].default_value = 0.08
    bump_fine.invert = True
    links.new(voronoi_fine.outputs['Distance'], bump_fine.inputs['Height'])
    links.new(bump_big.outputs['Normal'], bump_fine.inputs['Normal'])

    # Surface noise as micro-roughness
    bump_noise = nodes.new(type='ShaderNodeBump')
    bump_noise.inputs['Strength'].default_value = bump_strength * 0.3
    bump_noise.inputs['Distance'].default_value = 0.05
    links.new(noise.outputs['Fac'], bump_noise.inputs['Height'])
    links.new(bump_fine.outputs['Normal'], bump_noise.inputs['Normal'])

    links.new(bump_noise.outputs['Normal'], bsdf.inputs['Normal'])

    # --- Roughness: cracks are slightly rougher ---
    rough_mix = nodes.new(type='ShaderNodeMath')
    rough_mix.operation = 'ADD'
    rough_mix.use_clamp = True
    rough_mix.inputs[0].default_value = 0.85

    rough_var = nodes.new(type='ShaderNodeMath')
    rough_var.operation = 'MULTIPLY'
    rough_var.inputs[1].default_value = roughness_var
    links.new(noise.outputs['Fac'], rough_var.inputs[0])
    links.new(rough_var.outputs['Value'], rough_mix.inputs[1])

    links.new(rough_mix.outputs['Value'], bsdf.inputs['Roughness'])

    bsdf.inputs['Metallic'].default_value = 0.0

    # --- Height output: combined crack depth + noise for baking ---
    # This node group produces the height field used by bump mapping.
    # The preview script can reconnect it to bake a height/normal map.
    height_combine = nodes.new(type='ShaderNodeMath')
    height_combine.operation = 'ADD'
    height_combine.label = 'Height (for baking)'
    height_combine.use_clamp = True

    # Crack depth (inverted: cracks are low, rock surface is high)
    links.new(crack_combine.outputs['Value'], height_combine.inputs[0])

    # Noise adds surface variation
    height_noise = nodes.new(type='ShaderNodeMath')
    height_noise.operation = 'MULTIPLY'
    height_noise.label = 'Height Noise'
    height_noise.inputs[1].default_value = 0.15
    links.new(noise.outputs['Fac'], height_noise.inputs[0])
    links.new(height_noise.outputs['Value'], height_combine.inputs[1])

    mat.diffuse_color = base_rgba
    return mat
