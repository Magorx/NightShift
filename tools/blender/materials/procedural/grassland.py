"""Grassland terrain — directional blade-like grass with patchy variation."""

from materials.procedural._base import setup_material
from materials.pixel_art import hex_to_rgba


def grassland(name, hex_color, soil_color=None, blade_scale=20.0,
              blade_distortion=4.0, soil_exposure=0.25, bump_strength=0.6):
    """Grassland terrain using Wave Texture for directional grass blades.

    Two Wave textures at slightly different angles create interlocking
    blade patterns. Noise distorts the waves for organic bending.
    Broad noise patches add color variation across the field.

    Args:
        name: Material name.
        hex_color: Base grass color.
        soil_color: Exposed soil color (None = warm brown).
        blade_scale: Frequency of grass blade lines.
        blade_distortion: How much blades bend/wave.
        soil_exposure: How much soil shows in gaps (0-1).
        bump_strength: Bump map intensity.

    Returns:
        The Blender material.
    """
    mat, nodes, links = setup_material(name)

    bsdf = nodes.get("Principled BSDF")
    base_rgba = hex_to_rgba(hex_color)

    if soil_color:
        soil_rgba = hex_to_rgba(soil_color)
    else:
        soil_rgba = (
            min(base_rgba[0] * 1.1 + 0.12, 1.0),
            base_rgba[1] * 0.55 + 0.08,
            base_rgba[2] * 0.35 + 0.04,
            1.0,
        )

    # Dark between-blade shadows
    shadow_rgba = (
        base_rgba[0] * 0.4,
        base_rgba[1] * 0.45,
        base_rgba[2] * 0.3,
        1.0,
    )
    # Bright blade tips
    tip_rgba = (
        min(base_rgba[0] * 1.15, 1.0),
        min(base_rgba[1] * 1.35, 1.0),
        min(base_rgba[2] * 0.85, 1.0),
        1.0,
    )

    # --- Texture coordinates ---
    tex_coord = nodes.new(type='ShaderNodeTexCoord')

    # --- Primary: Wave Texture (directional grass blades) ---
    wave1 = nodes.new(type='ShaderNodeTexWave')
    wave1.wave_type = 'BANDS'
    wave1.bands_direction = 'X'
    wave1.wave_profile = 'SAW'  # asymmetric = blade-like
    wave1.inputs['Scale'].default_value = blade_scale
    wave1.inputs['Distortion'].default_value = blade_distortion
    wave1.inputs['Detail'].default_value = 4.0
    wave1.inputs['Detail Scale'].default_value = 2.0
    wave1.inputs['Detail Roughness'].default_value = 0.6
    links.new(tex_coord.outputs['Object'], wave1.inputs['Vector'])

    # Second wave at ~15 degrees for cross-hatching (no "perfect comb" look)
    mapping_rot = nodes.new(type='ShaderNodeMapping')
    mapping_rot.inputs['Rotation'].default_value = (0.0, 0.26, 0.0)  # ~15 deg around Y
    links.new(tex_coord.outputs['Object'], mapping_rot.inputs['Vector'])

    wave2 = nodes.new(type='ShaderNodeTexWave')
    wave2.wave_type = 'BANDS'
    wave2.bands_direction = 'X'
    wave2.wave_profile = 'SAW'
    wave2.inputs['Scale'].default_value = blade_scale * 0.7
    wave2.inputs['Distortion'].default_value = blade_distortion * 1.3
    wave2.inputs['Detail'].default_value = 3.0
    wave2.inputs['Detail Scale'].default_value = 1.5
    wave2.inputs['Detail Roughness'].default_value = 0.5
    links.new(mapping_rot.outputs['Vector'], wave2.inputs['Vector'])

    # Combine both wave patterns (screen blend = interlocking blades)
    blade_combine = nodes.new(type='ShaderNodeMixRGB')
    blade_combine.blend_type = 'SCREEN'
    blade_combine.inputs['Fac'].default_value = 0.5
    links.new(wave1.outputs['Fac'], blade_combine.inputs['Color1'])
    links.new(wave2.outputs['Fac'], blade_combine.inputs['Color2'])

    # --- Broad color variation (low-freq noise for clumps) ---
    noise_broad = nodes.new(type='ShaderNodeTexNoise')
    noise_broad.inputs['Scale'].default_value = 2.5
    noise_broad.inputs['Detail'].default_value = 3.0
    noise_broad.inputs['Roughness'].default_value = 0.5
    links.new(tex_coord.outputs['Object'], noise_broad.inputs['Vector'])

    # --- Soil exposure mask (noise-based patchy gaps) ---
    noise_soil = nodes.new(type='ShaderNodeTexNoise')
    noise_soil.inputs['Scale'].default_value = 5.0
    noise_soil.inputs['Detail'].default_value = 6.0
    noise_soil.inputs['Roughness'].default_value = 0.7
    noise_soil.inputs['Distortion'].default_value = 0.5
    links.new(tex_coord.outputs['Object'], noise_soil.inputs['Vector'])

    soil_ramp = nodes.new(type='ShaderNodeValToRGB')
    soil_ramp.color_ramp.interpolation = 'EASE'
    soil_ramp.color_ramp.elements[0].position = 1.0 - soil_exposure
    soil_ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    soil_ramp.color_ramp.elements[1].position = min(1.0 - soil_exposure + 0.1, 1.0)
    soil_ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    links.new(noise_soil.outputs['Fac'], soil_ramp.inputs['Fac'])

    # --- Color assembly ---

    # Blade color gradient: shadow → tip based on wave pattern
    blade_ramp = nodes.new(type='ShaderNodeValToRGB')
    blade_ramp.color_ramp.interpolation = 'EASE'
    blade_ramp.color_ramp.elements[0].position = 0.0
    blade_ramp.color_ramp.elements[0].color = shadow_rgba
    # Add middle stop for base color
    mid = blade_ramp.color_ramp.elements.new(0.4)
    mid.color = base_rgba
    blade_ramp.color_ramp.elements[1].position = 1.0
    blade_ramp.color_ramp.elements[1].color = tip_rgba
    links.new(blade_combine.outputs['Color'], blade_ramp.inputs['Fac'])

    # Overlay broad variation for patchy color shifts
    grass_varied = nodes.new(type='ShaderNodeMixRGB')
    grass_varied.blend_type = 'OVERLAY'
    grass_varied.inputs['Fac'].default_value = 0.35
    links.new(blade_ramp.outputs['Color'], grass_varied.inputs['Color1'])

    warm_variant = (
        min(base_rgba[0] * 1.2, 1.0),
        min(base_rgba[1] * 1.05, 1.0),
        base_rgba[2] * 0.75,
        1.0,
    )
    broad_color = nodes.new(type='ShaderNodeMixRGB')
    broad_color.blend_type = 'MIX'
    broad_color.inputs['Color1'].default_value = base_rgba
    broad_color.inputs['Color2'].default_value = warm_variant
    links.new(noise_broad.outputs['Fac'], broad_color.inputs['Fac'])
    links.new(broad_color.outputs['Color'], grass_varied.inputs['Color2'])

    # Mix grass with soil where exposed
    color_final = nodes.new(type='ShaderNodeMixRGB')
    color_final.blend_type = 'MIX'
    color_final.inputs['Color2'].default_value = soil_rgba
    links.new(grass_varied.outputs['Color'], color_final.inputs['Color1'])
    links.new(soil_ramp.outputs['Color'], color_final.inputs['Fac'])

    links.new(color_final.outputs['Color'], bsdf.inputs['Base Color'])

    # --- Bump: parallel blade grooves ---
    bump_blade = nodes.new(type='ShaderNodeBump')
    bump_blade.inputs['Strength'].default_value = bump_strength
    bump_blade.inputs['Distance'].default_value = 0.06
    links.new(blade_combine.outputs['Color'], bump_blade.inputs['Height'])

    # Soil dips
    bump_soil = nodes.new(type='ShaderNodeBump')
    bump_soil.inputs['Strength'].default_value = bump_strength * 0.5
    bump_soil.inputs['Distance'].default_value = 0.08
    bump_soil.invert = True
    links.new(soil_ramp.outputs['Color'], bump_soil.inputs['Height'])
    links.new(bump_blade.outputs['Normal'], bump_soil.inputs['Normal'])

    links.new(bump_soil.outputs['Normal'], bsdf.inputs['Normal'])

    # --- Roughness ---
    bsdf.inputs['Roughness'].default_value = 0.88
    bsdf.inputs['Metallic'].default_value = 0.0

    # --- Height output for baking ---
    height_combine = nodes.new(type='ShaderNodeMath')
    height_combine.operation = 'ADD'
    height_combine.label = 'Height (for baking)'
    height_combine.use_clamp = True

    links.new(blade_combine.outputs['Color'], height_combine.inputs[0])

    height_soil = nodes.new(type='ShaderNodeMath')
    height_soil.operation = 'MULTIPLY'
    height_soil.inputs[1].default_value = -0.3
    links.new(soil_ramp.outputs['Color'], height_soil.inputs[0])
    links.new(height_soil.outputs['Value'], height_combine.inputs[1])

    mat.diffuse_color = base_rgba
    return mat
