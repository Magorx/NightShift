"""Volcanic pyromite deposit — cracked basalt with glowing lava in fissures."""

from materials.procedural._base import setup_material
from materials.pixel_art import hex_to_rgba


def pyromite_ground(name, hex_color, glow_color=None, lava_color=None,
                    crack_threshold=0.06, glow_intensity=0.8,
                    rock_scale=5.0, bump_strength=1.0):
    """Volcanic ground: Voronoi crack network with emissive lava glow.

    Uses Voronoi Distance-to-Edge for the crack pattern (it's the right
    tool for cracks). Binary crack mask + power falloff create sharp
    bright-core-to-dim-edge lava glow. Two Voronoi scales for multi-level
    cracking. Noise roughens the basalt plate surfaces.

    Args:
        name: Material name.
        hex_color: Base basalt color (dark volcanic).
        glow_color: Lava glow color (None = bright orange-yellow).
        lava_color: Cooled lava edge color (None = deep red).
        crack_threshold: Crack width (lower = thinner cracks).
        glow_intensity: Emission strength for lava glow.
        rock_scale: Scale of the crack pattern.
        bump_strength: Bump intensity.

    Returns:
        The Blender material.
    """
    mat, nodes, links = setup_material(name)

    bsdf = nodes.get("Principled BSDF")
    base_rgba = hex_to_rgba(hex_color)

    if glow_color:
        glow_rgba = hex_to_rgba(glow_color)
    else:
        glow_rgba = (1.0, 0.72, 0.12, 1.0)

    if lava_color:
        lava_rgba = hex_to_rgba(lava_color)
    else:
        lava_rgba = (0.7, 0.12, 0.02, 1.0)

    # --- Texture coordinates ---
    tex_coord = nodes.new(type='ShaderNodeTexCoord')

    # --- Layer 1: Large basalt plate cracks ---
    voronoi_big = nodes.new(type='ShaderNodeTexVoronoi')
    voronoi_big.feature = 'DISTANCE_TO_EDGE'
    voronoi_big.inputs['Scale'].default_value = rock_scale
    voronoi_big.inputs['Randomness'].default_value = 0.7
    links.new(tex_coord.outputs['Object'], voronoi_big.inputs['Vector'])

    # Binary crack mask: sharp threshold
    crack_big = nodes.new(type='ShaderNodeMath')
    crack_big.operation = 'LESS_THAN'
    crack_big.inputs[1].default_value = crack_threshold
    links.new(voronoi_big.outputs['Distance'], crack_big.inputs[0])

    # --- Layer 2: Fine secondary cracks (higher frequency) ---
    voronoi_fine = nodes.new(type='ShaderNodeTexVoronoi')
    voronoi_fine.feature = 'DISTANCE_TO_EDGE'
    voronoi_fine.inputs['Scale'].default_value = rock_scale * 2.5
    voronoi_fine.inputs['Randomness'].default_value = 0.9
    links.new(tex_coord.outputs['Object'], voronoi_fine.inputs['Vector'])

    crack_fine = nodes.new(type='ShaderNodeMath')
    crack_fine.operation = 'LESS_THAN'
    crack_fine.inputs[1].default_value = crack_threshold * 0.5
    links.new(voronoi_fine.outputs['Distance'], crack_fine.inputs[0])

    # Combined crack mask (either = crack)
    crack_mask = nodes.new(type='ShaderNodeMath')
    crack_mask.operation = 'MAXIMUM'
    links.new(crack_big.outputs['Value'], crack_mask.inputs[0])
    links.new(crack_fine.outputs['Value'], crack_mask.inputs[1])

    # --- Glow falloff: bright core fading to dim edges ---
    # Use distance directly (not binary) for smooth glow gradient
    glow_raw = nodes.new(type='ShaderNodeMath')
    glow_raw.operation = 'SUBTRACT'
    glow_raw.inputs[0].default_value = crack_threshold * 1.5
    glow_raw.use_clamp = True
    links.new(voronoi_big.outputs['Distance'], glow_raw.inputs[1])

    # Power falloff: concentrates brightness at crack centers
    glow_power = nodes.new(type='ShaderNodeMath')
    glow_power.operation = 'POWER'
    glow_power.inputs[1].default_value = 0.4  # < 1 = wider glow, > 1 = tighter
    links.new(glow_raw.outputs['Value'], glow_power.inputs[0])

    # --- Rock surface detail noise ---
    noise_rock = nodes.new(type='ShaderNodeTexNoise')
    noise_rock.inputs['Scale'].default_value = rock_scale * 4.0
    noise_rock.inputs['Detail'].default_value = 8.0
    noise_rock.inputs['Roughness'].default_value = 0.7
    links.new(tex_coord.outputs['Object'], noise_rock.inputs['Vector'])

    # --- Color assembly ---

    # Rock surface: base + noise variation
    scorch_rgba = (
        min(base_rgba[0] * 1.3, 1.0),
        base_rgba[1] * 0.85,
        base_rgba[2] * 0.7,
        1.0,
    )
    rock_color = nodes.new(type='ShaderNodeMixRGB')
    rock_color.blend_type = 'MIX'
    rock_color.inputs['Color1'].default_value = base_rgba
    rock_color.inputs['Color2'].default_value = scorch_rgba
    links.new(noise_rock.outputs['Fac'], rock_color.inputs['Fac'])

    # Lava color: gradient from hot center to cooled edge
    lava_gradient = nodes.new(type='ShaderNodeMixRGB')
    lava_gradient.blend_type = 'MIX'
    lava_gradient.inputs['Color1'].default_value = lava_rgba
    lava_gradient.inputs['Color2'].default_value = glow_rgba
    links.new(glow_power.outputs['Value'], lava_gradient.inputs['Fac'])

    # Final: rock where solid, lava where cracked
    color_final = nodes.new(type='ShaderNodeMixRGB')
    color_final.blend_type = 'MIX'
    links.new(rock_color.outputs['Color'], color_final.inputs['Color1'])
    links.new(lava_gradient.outputs['Color'], color_final.inputs['Color2'])
    links.new(crack_mask.outputs['Value'], color_final.inputs['Fac'])

    links.new(color_final.outputs['Color'], bsdf.inputs['Base Color'])

    # --- Emission: lava glow with power falloff ---
    emit_strength = nodes.new(type='ShaderNodeMath')
    emit_strength.operation = 'MULTIPLY'
    emit_strength.inputs[1].default_value = glow_intensity
    links.new(glow_power.outputs['Value'], emit_strength.inputs[0])

    emit_color = nodes.new(type='ShaderNodeMixRGB')
    emit_color.blend_type = 'MIX'
    emit_color.inputs['Color1'].default_value = (0, 0, 0, 1)
    emit_color.inputs['Color2'].default_value = glow_rgba
    links.new(emit_strength.outputs['Value'], emit_color.inputs['Fac'])

    links.new(emit_color.outputs['Color'], bsdf.inputs['Emission Color'])
    bsdf.inputs['Emission Strength'].default_value = 1.0

    # --- Bump: deep crack valleys, rough rock surface ---
    bump_crack = nodes.new(type='ShaderNodeBump')
    bump_crack.inputs['Strength'].default_value = bump_strength
    bump_crack.inputs['Distance'].default_value = 0.25
    bump_crack.invert = True
    links.new(crack_mask.outputs['Value'], bump_crack.inputs['Height'])

    bump_rock = nodes.new(type='ShaderNodeBump')
    bump_rock.inputs['Strength'].default_value = bump_strength * 0.4
    bump_rock.inputs['Distance'].default_value = 0.06
    links.new(noise_rock.outputs['Fac'], bump_rock.inputs['Height'])
    links.new(bump_crack.outputs['Normal'], bump_rock.inputs['Normal'])

    links.new(bump_rock.outputs['Normal'], bsdf.inputs['Normal'])

    # --- Roughness: rough rock, glossy lava ---
    rough_lerp = nodes.new(type='ShaderNodeMath')
    rough_lerp.operation = 'ADD'
    rough_lerp.use_clamp = True
    rough_lerp.inputs[0].default_value = 0.25  # lava smoothness

    crack_invert = nodes.new(type='ShaderNodeMath')
    crack_invert.operation = 'SUBTRACT'
    crack_invert.inputs[0].default_value = 1.0
    links.new(crack_mask.outputs['Value'], crack_invert.inputs[1])

    rough_rock = nodes.new(type='ShaderNodeMath')
    rough_rock.operation = 'MULTIPLY'
    rough_rock.inputs[1].default_value = 0.65
    links.new(crack_invert.outputs['Value'], rough_rock.inputs[0])
    links.new(rough_rock.outputs['Value'], rough_lerp.inputs[1])

    links.new(rough_lerp.outputs['Value'], bsdf.inputs['Roughness'])
    bsdf.inputs['Metallic'].default_value = 0.0

    # --- Height for baking ---
    height_out = nodes.new(type='ShaderNodeMath')
    height_out.operation = 'SUBTRACT'
    height_out.label = 'Height (for baking)'
    height_out.use_clamp = True
    height_out.inputs[0].default_value = 1.0
    links.new(crack_mask.outputs['Value'], height_out.inputs[1])

    mat.diffuse_color = base_rgba
    return mat
