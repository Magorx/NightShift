"""Crystalline ice deposit — shattered angular facets with frost edges."""

from materials.procedural._base import setup_material
from materials.pixel_art import hex_to_rgba


def crystalline_ground(name, hex_color, frost_color=None, deep_color=None,
                       facet_scale=4.0, frost_intensity=0.5,
                       bump_strength=1.0):
    """Frozen crystalline ground using distorted Brick Texture for shattered ice.

    Brick texture coordinates are warped by Noise to break the grid into
    irregular fractured shapes. Two brick layers at different rotations
    create complex shard patterns. Frost collects on fracture lines.

    Args:
        name: Material name.
        hex_color: Base ice surface color.
        frost_color: White frost on edges (None = near-white blue).
        deep_color: Deep ice between facets (None = dark blue).
        facet_scale: Scale of crystal facet pattern.
        frost_intensity: Amount of frost on edges (0-1).
        bump_strength: Bump intensity.

    Returns:
        The Blender material.
    """
    mat, nodes, links = setup_material(name)

    bsdf = nodes.get("Principled BSDF")
    base_rgba = hex_to_rgba(hex_color)

    if frost_color:
        frost_rgba = hex_to_rgba(frost_color)
    else:
        frost_rgba = (0.88, 0.93, 0.97, 1.0)

    if deep_color:
        deep_rgba = hex_to_rgba(deep_color)
    else:
        deep_rgba = (
            base_rgba[0] * 0.25,
            base_rgba[1] * 0.35,
            base_rgba[2] * 0.6,
            1.0,
        )

    highlight_rgba = (
        min(base_rgba[0] * 1.5, 1.0),
        min(base_rgba[1] * 1.4, 1.0),
        min(base_rgba[2] * 1.25, 1.0),
        1.0,
    )

    # --- Texture coordinates ---
    tex_coord = nodes.new(type='ShaderNodeTexCoord')

    # --- Coordinate distortion: warp the grid to look shattered ---
    # This is the key trick: Noise warps the Brick input so the
    # rectangular grid becomes irregular fractured shapes
    noise_warp = nodes.new(type='ShaderNodeTexNoise')
    noise_warp.inputs['Scale'].default_value = facet_scale * 0.8
    noise_warp.inputs['Detail'].default_value = 3.0
    noise_warp.inputs['Roughness'].default_value = 0.5
    noise_warp.inputs['Distortion'].default_value = 0.0
    links.new(tex_coord.outputs['Object'], noise_warp.inputs['Vector'])

    # Mix original coords with noise to warp the grid
    warp_mix = nodes.new(type='ShaderNodeMixRGB')
    warp_mix.blend_type = 'MIX'
    warp_mix.inputs['Fac'].default_value = 0.35  # warp strength
    links.new(tex_coord.outputs['Object'], warp_mix.inputs['Color1'])
    links.new(noise_warp.outputs['Color'], warp_mix.inputs['Color2'])

    # Rotate warped coords
    mapping = nodes.new(type='ShaderNodeMapping')
    mapping.inputs['Rotation'].default_value = (0.0, 0.35, 0.0)
    links.new(warp_mix.outputs['Color'], mapping.inputs['Vector'])

    # --- Primary: Brick Texture on warped coordinates ---
    brick = nodes.new(type='ShaderNodeTexBrick')
    brick.offset = 0.0  # no staggering
    brick.squash = 0.65
    brick.squash_frequency = 2
    brick.inputs['Scale'].default_value = facet_scale
    brick.inputs['Mortar Size'].default_value = 0.025  # wider fracture lines
    brick.inputs['Mortar Smooth'].default_value = 0.1
    brick.inputs['Bias'].default_value = -0.3
    brick.inputs['Brick Width'].default_value = 0.45
    brick.inputs['Row Height'].default_value = 0.3
    brick.inputs['Color1'].default_value = base_rgba
    brick.inputs['Color2'].default_value = highlight_rgba
    brick.inputs['Mortar'].default_value = deep_rgba
    links.new(mapping.outputs['Vector'], brick.inputs['Vector'])

    # Frost mask from mortar lines (Fac=0 at mortar, 1 at brick)
    frost_raw = nodes.new(type='ShaderNodeMath')
    frost_raw.operation = 'SUBTRACT'
    frost_raw.inputs[0].default_value = 1.0
    links.new(brick.outputs['Fac'], frost_raw.inputs[1])

    frost_scaled = nodes.new(type='ShaderNodeMath')
    frost_scaled.operation = 'MULTIPLY'
    frost_scaled.use_clamp = True
    frost_scaled.inputs[1].default_value = frost_intensity * 2.5
    links.new(frost_raw.outputs['Value'], frost_scaled.inputs[0])

    # --- Second brick layer: different rotation + scale for complexity ---
    warp_mix2 = nodes.new(type='ShaderNodeMixRGB')
    warp_mix2.blend_type = 'MIX'
    warp_mix2.inputs['Fac'].default_value = 0.25
    links.new(tex_coord.outputs['Object'], warp_mix2.inputs['Color1'])
    links.new(noise_warp.outputs['Color'], warp_mix2.inputs['Color2'])

    mapping2 = nodes.new(type='ShaderNodeMapping')
    mapping2.inputs['Rotation'].default_value = (0.0, -0.55, 0.0)  # ~-30 deg
    links.new(warp_mix2.outputs['Color'], mapping2.inputs['Vector'])

    brick2 = nodes.new(type='ShaderNodeTexBrick')
    brick2.offset = 0.25
    brick2.squash = 1.3
    brick2.squash_frequency = 3
    brick2.inputs['Scale'].default_value = facet_scale * 2.0
    brick2.inputs['Mortar Size'].default_value = 0.018
    brick2.inputs['Mortar Smooth'].default_value = 0.05
    brick2.inputs['Brick Width'].default_value = 0.55
    brick2.inputs['Row Height'].default_value = 0.4
    brick2.inputs['Color1'].default_value = (
        base_rgba[0] * 0.8, base_rgba[1] * 0.85, base_rgba[2] * 0.95, 1.0)
    brick2.inputs['Color2'].default_value = base_rgba
    brick2.inputs['Mortar'].default_value = deep_rgba
    links.new(mapping2.outputs['Vector'], brick2.inputs['Vector'])

    # --- Per-facet brightness variation (Noise at brick scale) ---
    noise_facet = nodes.new(type='ShaderNodeTexNoise')
    noise_facet.inputs['Scale'].default_value = facet_scale * 1.5
    noise_facet.inputs['Detail'].default_value = 2.0
    noise_facet.inputs['Roughness'].default_value = 0.3
    links.new(tex_coord.outputs['Object'], noise_facet.inputs['Vector'])

    # --- Sparkle spots (high frequency noise threshold) ---
    noise_sparkle = nodes.new(type='ShaderNodeTexNoise')
    noise_sparkle.inputs['Scale'].default_value = 40.0
    noise_sparkle.inputs['Detail'].default_value = 3.0
    noise_sparkle.inputs['Roughness'].default_value = 0.95
    links.new(tex_coord.outputs['Object'], noise_sparkle.inputs['Vector'])

    sparkle_thresh = nodes.new(type='ShaderNodeMath')
    sparkle_thresh.operation = 'GREATER_THAN'
    sparkle_thresh.inputs[1].default_value = 0.88
    links.new(noise_sparkle.outputs['Fac'], sparkle_thresh.inputs[0])

    # --- Color assembly ---

    # Combine both brick layers (darken blend = fracture lines stack)
    ice_combined = nodes.new(type='ShaderNodeMixRGB')
    ice_combined.blend_type = 'DARKEN'
    ice_combined.inputs['Fac'].default_value = 0.5
    links.new(brick.outputs['Color'], ice_combined.inputs['Color1'])
    links.new(brick2.outputs['Color'], ice_combined.inputs['Color2'])

    # Modulate brightness per-facet with noise
    ice_varied = nodes.new(type='ShaderNodeMixRGB')
    ice_varied.blend_type = 'OVERLAY'
    ice_varied.inputs['Fac'].default_value = 0.4
    links.new(ice_combined.outputs['Color'], ice_varied.inputs['Color1'])
    links.new(noise_facet.outputs['Fac'], ice_varied.inputs['Fac'])
    ice_varied.inputs['Color2'].default_value = highlight_rgba

    # Add frost on fracture edges
    ice_frosted = nodes.new(type='ShaderNodeMixRGB')
    ice_frosted.blend_type = 'MIX'
    ice_frosted.inputs['Color2'].default_value = frost_rgba
    links.new(ice_varied.outputs['Color'], ice_frosted.inputs['Color1'])
    links.new(frost_scaled.outputs['Value'], ice_frosted.inputs['Fac'])

    # Sparkle highlights
    ice_sparkle = nodes.new(type='ShaderNodeMixRGB')
    ice_sparkle.blend_type = 'ADD'
    ice_sparkle.inputs['Color2'].default_value = (0.8, 0.9, 1.0, 1.0)
    links.new(ice_frosted.outputs['Color'], ice_sparkle.inputs['Color1'])
    links.new(sparkle_thresh.outputs['Value'], ice_sparkle.inputs['Fac'])

    links.new(ice_sparkle.outputs['Color'], bsdf.inputs['Base Color'])

    # --- Bump: facet edges as sharp ridges ---
    bump_facet = nodes.new(type='ShaderNodeBump')
    bump_facet.inputs['Strength'].default_value = bump_strength
    bump_facet.inputs['Distance'].default_value = 0.15
    links.new(brick.outputs['Fac'], bump_facet.inputs['Height'])

    bump_sub = nodes.new(type='ShaderNodeBump')
    bump_sub.inputs['Strength'].default_value = bump_strength * 0.5
    bump_sub.inputs['Distance'].default_value = 0.08
    links.new(brick2.outputs['Fac'], bump_sub.inputs['Height'])
    links.new(bump_facet.outputs['Normal'], bump_sub.inputs['Normal'])

    links.new(bump_sub.outputs['Normal'], bsdf.inputs['Normal'])

    # --- Roughness: smooth ice, rough frost patches ---
    rough_base = nodes.new(type='ShaderNodeMath')
    rough_base.operation = 'ADD'
    rough_base.use_clamp = True
    rough_base.inputs[0].default_value = 0.08

    rough_frost = nodes.new(type='ShaderNodeMath')
    rough_frost.operation = 'MULTIPLY'
    rough_frost.inputs[1].default_value = 0.7
    links.new(frost_scaled.outputs['Value'], rough_frost.inputs[0])
    links.new(rough_frost.outputs['Value'], rough_base.inputs[1])

    links.new(rough_base.outputs['Value'], bsdf.inputs['Roughness'])
    bsdf.inputs['Metallic'].default_value = 0.0
    bsdf.inputs['IOR'].default_value = 1.31

    # --- Height for baking ---
    height_out = nodes.new(type='ShaderNodeMath')
    height_out.operation = 'ADD'
    height_out.label = 'Height (for baking)'
    height_out.use_clamp = True

    height_facet = nodes.new(type='ShaderNodeMath')
    height_facet.operation = 'MULTIPLY'
    height_facet.inputs[1].default_value = 0.7
    links.new(brick.outputs['Fac'], height_facet.inputs[0])
    links.new(height_facet.outputs['Value'], height_out.inputs[0])

    height_sub = nodes.new(type='ShaderNodeMath')
    height_sub.operation = 'MULTIPLY'
    height_sub.inputs[1].default_value = 0.3
    links.new(brick2.outputs['Fac'], height_sub.inputs[0])
    links.new(height_sub.outputs['Value'], height_out.inputs[1])

    mat.diffuse_color = base_rgba
    return mat
