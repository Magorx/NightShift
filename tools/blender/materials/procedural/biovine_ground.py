"""Biovine organic deposit — fractal moss with fungal networks and spores."""

from materials.procedural._base import setup_material
from materials.pixel_art import hex_to_rgba


def biovine_ground(name, hex_color, spore_color=None, rot_color=None,
                   growth_scale=4.0, spore_density=0.4,
                   moisture=0.6, bump_strength=0.9):
    """Organic biovine ground using high-detail Noise for fractal moss.

    Heavy distortion + high detail noise creates spongy, deeply layered
    organic patterns. A second noise at different scale adds fungal texture.
    No Voronoi — everything is fractal/noise-based for a soft organic feel.

    Args:
        name: Material name.
        hex_color: Base moss/organic color.
        spore_color: Bioluminescent spore color (None = bright yellow-green).
        rot_color: Decomposing underlayer color (None = dark brown-purple).
        growth_scale: Scale of organic growth.
        spore_density: How many glowing spore spots (0-1).
        moisture: Surface wetness (0=dry, 1=slimy).
        bump_strength: Bump intensity.

    Returns:
        The Blender material.
    """
    mat, nodes, links = setup_material(name)

    bsdf = nodes.get("Principled BSDF")
    base_rgba = hex_to_rgba(hex_color)

    if spore_color:
        spore_rgba = hex_to_rgba(spore_color)
    else:
        spore_rgba = (0.7, 1.0, 0.3, 1.0)

    if rot_color:
        rot_rgba = hex_to_rgba(rot_color)
    else:
        rot_rgba = (
            base_rgba[0] * 0.25 + 0.08,
            base_rgba[1] * 0.2 + 0.03,
            base_rgba[2] * 0.3 + 0.06,
            1.0,
        )

    shadow_rgba = (
        base_rgba[0] * 0.35,
        base_rgba[1] * 0.4,
        base_rgba[2] * 0.25,
        1.0,
    )
    tip_rgba = (
        min(base_rgba[0] * 1.3, 1.0),
        min(base_rgba[1] * 1.4, 1.0),
        min(base_rgba[2] * 0.8, 1.0),
        1.0,
    )

    # --- Texture coordinates ---
    tex_coord = nodes.new(type='ShaderNodeTexCoord')

    # --- Primary: High-detail noise with heavy distortion (fractal moss) ---
    noise_main = nodes.new(type='ShaderNodeTexNoise')
    noise_main.inputs['Scale'].default_value = growth_scale
    noise_main.inputs['Detail'].default_value = 15.0  # cranked HIGH for organic complexity
    noise_main.inputs['Roughness'].default_value = 0.8
    noise_main.inputs['Distortion'].default_value = 2.5  # heavy distortion = organic shapes
    links.new(tex_coord.outputs['Object'], noise_main.inputs['Vector'])

    # Color ramp: wide-range stops for high-contrast moss coloration
    moss_ramp = nodes.new(type='ShaderNodeValToRGB')
    moss_ramp.color_ramp.interpolation = 'B_SPLINE'
    # Stop 0: deep shadow / rot
    moss_ramp.color_ramp.elements[0].position = 0.0
    moss_ramp.color_ramp.elements[0].color = (
        shadow_rgba[0] * 0.6, shadow_rgba[1] * 0.6, shadow_rgba[2] * 0.5, 1.0)
    # Stop 1: dark base
    stop1 = moss_ramp.color_ramp.elements.new(0.25)
    stop1.color = shadow_rgba
    # Stop 2: base
    stop2 = moss_ramp.color_ramp.elements.new(0.45)
    stop2.color = base_rgba
    # Stop 3: bright mid
    stop3 = moss_ramp.color_ramp.elements.new(0.65)
    stop3.color = (
        min(base_rgba[0] * 1.15, 1.0),
        min(base_rgba[1] * 1.25, 1.0),
        base_rgba[2] * 0.85,
        1.0,
    )
    # Stop 4: tip highlight
    moss_ramp.color_ramp.elements[1].position = 0.85
    moss_ramp.color_ramp.elements[1].color = tip_rgba
    links.new(noise_main.outputs['Fac'], moss_ramp.inputs['Fac'])

    # --- Layer 2: Fine fungal detail (smaller scale, different distortion) ---
    noise_fungal = nodes.new(type='ShaderNodeTexNoise')
    noise_fungal.inputs['Scale'].default_value = growth_scale * 3.0
    noise_fungal.inputs['Detail'].default_value = 10.0
    noise_fungal.inputs['Roughness'].default_value = 0.65
    noise_fungal.inputs['Distortion'].default_value = 1.8
    links.new(tex_coord.outputs['Object'], noise_fungal.inputs['Vector'])

    # --- Layer 3: Broad growth front (very large scale, gentle variation) ---
    noise_broad = nodes.new(type='ShaderNodeTexNoise')
    noise_broad.inputs['Scale'].default_value = growth_scale * 0.3
    noise_broad.inputs['Detail'].default_value = 2.0
    noise_broad.inputs['Roughness'].default_value = 0.4
    links.new(tex_coord.outputs['Object'], noise_broad.inputs['Vector'])

    # --- Layer 4: Spore spots (threshold on fine noise) ---
    noise_spore = nodes.new(type='ShaderNodeTexNoise')
    noise_spore.inputs['Scale'].default_value = growth_scale * 8.0
    noise_spore.inputs['Detail'].default_value = 4.0
    noise_spore.inputs['Roughness'].default_value = 0.9
    noise_spore.inputs['Distortion'].default_value = 0.5
    links.new(tex_coord.outputs['Object'], noise_spore.inputs['Vector'])

    spore_thresh = nodes.new(type='ShaderNodeMath')
    spore_thresh.operation = 'GREATER_THAN'
    spore_thresh.inputs[1].default_value = 1.0 - spore_density * 0.12
    links.new(noise_spore.outputs['Fac'], spore_thresh.inputs[0])

    # --- Color assembly ---

    # Overlay fungal detail on moss (strong for visible texture)
    mossy = nodes.new(type='ShaderNodeMixRGB')
    mossy.blend_type = 'OVERLAY'
    mossy.inputs['Fac'].default_value = 0.6
    links.new(moss_ramp.outputs['Color'], mossy.inputs['Color1'])
    links.new(noise_fungal.outputs['Fac'], mossy.inputs['Fac'])

    # Use broad noise as the overlay color source
    broad_color = nodes.new(type='ShaderNodeMixRGB')
    broad_color.blend_type = 'MIX'
    broad_color.inputs['Color1'].default_value = base_rgba
    broad_color.inputs['Color2'].default_value = (
        min(base_rgba[0] * 0.9, 1.0),
        min(base_rgba[1] * 1.15, 1.0),
        min(base_rgba[2] * 1.1, 1.0),
        1.0,
    )
    links.new(noise_broad.outputs['Fac'], broad_color.inputs['Fac'])
    links.new(broad_color.outputs['Color'], mossy.inputs['Color2'])

    # Rot/decomposition in the darkest areas
    rot_mask = nodes.new(type='ShaderNodeMath')
    rot_mask.operation = 'LESS_THAN'
    rot_mask.inputs[1].default_value = 0.2
    links.new(noise_main.outputs['Fac'], rot_mask.inputs[0])

    rot_blend = nodes.new(type='ShaderNodeMath')
    rot_blend.operation = 'MULTIPLY'
    rot_blend.inputs[1].default_value = 0.7
    links.new(rot_mask.outputs['Value'], rot_blend.inputs[0])

    organic_rotted = nodes.new(type='ShaderNodeMixRGB')
    organic_rotted.blend_type = 'MIX'
    organic_rotted.inputs['Color2'].default_value = rot_rgba
    links.new(mossy.outputs['Color'], organic_rotted.inputs['Color1'])
    links.new(rot_blend.outputs['Value'], organic_rotted.inputs['Fac'])

    # Spore glow spots
    color_final = nodes.new(type='ShaderNodeMixRGB')
    color_final.blend_type = 'MIX'
    color_final.inputs['Color2'].default_value = spore_rgba
    links.new(organic_rotted.outputs['Color'], color_final.inputs['Color1'])
    links.new(spore_thresh.outputs['Value'], color_final.inputs['Fac'])

    links.new(color_final.outputs['Color'], bsdf.inputs['Base Color'])

    # --- Emission: faint bioluminescent glow from spores ---
    spore_emit = nodes.new(type='ShaderNodeMath')
    spore_emit.operation = 'MULTIPLY'
    spore_emit.inputs[1].default_value = 0.3
    links.new(spore_thresh.outputs['Value'], spore_emit.inputs[0])

    emit_color = nodes.new(type='ShaderNodeMixRGB')
    emit_color.blend_type = 'MIX'
    emit_color.inputs['Color1'].default_value = (0, 0, 0, 1)
    emit_color.inputs['Color2'].default_value = spore_rgba
    links.new(spore_emit.outputs['Value'], emit_color.inputs['Fac'])

    links.new(emit_color.outputs['Color'], bsdf.inputs['Emission Color'])
    bsdf.inputs['Emission Strength'].default_value = 1.0

    # --- Bump: lumpy multi-scale organic surface ---
    bump_main = nodes.new(type='ShaderNodeBump')
    bump_main.inputs['Strength'].default_value = bump_strength
    bump_main.inputs['Distance'].default_value = 0.1
    links.new(noise_main.outputs['Fac'], bump_main.inputs['Height'])

    bump_fungal = nodes.new(type='ShaderNodeBump')
    bump_fungal.inputs['Strength'].default_value = bump_strength * 0.5
    bump_fungal.inputs['Distance'].default_value = 0.05
    links.new(noise_fungal.outputs['Fac'], bump_fungal.inputs['Height'])
    links.new(bump_main.outputs['Normal'], bump_fungal.inputs['Normal'])

    bump_spore = nodes.new(type='ShaderNodeBump')
    bump_spore.inputs['Strength'].default_value = bump_strength * 0.3
    bump_spore.inputs['Distance'].default_value = 0.03
    links.new(spore_thresh.outputs['Value'], bump_spore.inputs['Height'])
    links.new(bump_fungal.outputs['Normal'], bump_spore.inputs['Normal'])

    links.new(bump_spore.outputs['Normal'], bsdf.inputs['Normal'])

    # --- Roughness: wet/slimy on moss, dry between ---
    rough_base = nodes.new(type='ShaderNodeMath')
    rough_base.operation = 'ADD'
    rough_base.use_clamp = True
    rough_base.inputs[0].default_value = 0.9 - moisture * 0.5

    rough_var = nodes.new(type='ShaderNodeMath')
    rough_var.operation = 'MULTIPLY'
    rough_var.inputs[1].default_value = moisture * 0.3
    # Use inverted main noise: thick moss = wet (smooth), thin = dry
    rough_inv = nodes.new(type='ShaderNodeMath')
    rough_inv.operation = 'SUBTRACT'
    rough_inv.inputs[0].default_value = 1.0
    links.new(noise_main.outputs['Fac'], rough_inv.inputs[1])
    links.new(rough_inv.outputs['Value'], rough_var.inputs[0])
    links.new(rough_var.outputs['Value'], rough_base.inputs[1])

    links.new(rough_base.outputs['Value'], bsdf.inputs['Roughness'])
    bsdf.inputs['Metallic'].default_value = 0.0

    # --- Height for baking ---
    height_out = nodes.new(type='ShaderNodeMath')
    height_out.operation = 'ADD'
    height_out.label = 'Height (for baking)'
    height_out.use_clamp = True

    height_main = nodes.new(type='ShaderNodeMath')
    height_main.operation = 'MULTIPLY'
    height_main.inputs[1].default_value = 0.7
    links.new(noise_main.outputs['Fac'], height_main.inputs[0])
    links.new(height_main.outputs['Value'], height_out.inputs[0])

    height_detail = nodes.new(type='ShaderNodeMath')
    height_detail.operation = 'MULTIPLY'
    height_detail.inputs[1].default_value = 0.15
    links.new(noise_fungal.outputs['Fac'], height_detail.inputs[0])
    links.new(height_detail.outputs['Value'], height_out.inputs[1])

    mat.diffuse_color = base_rgba
    return mat
