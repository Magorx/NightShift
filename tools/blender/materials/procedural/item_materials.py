"""Procedural materials for the 6 elemental resource items.

Each material uses a UNIQUE node combination to give each resource
a distinct visual identity. These are baked to image textures before
glTF export since Blender shader nodes don't survive in .glb files.

Node strategy per element (deliberately avoiding Voronoi-everywhere):
  - Pyromite:    Wave (bands) + Noise distortion → flowing magma veins
  - Crystalline: Brick (warped) → angular ice facets with frost
  - Biovine:     Noise (high distortion) → fractal organic cells
  - Voltite:     Wave (rings) + threshold → electric crackling arcs
  - Umbrite:     Gradient (spherical) + Checker (distorted) → swirling void
  - Resonite:    Magic Texture → geometric force-field chrome

Usage:
    from materials.procedural.item_materials import pyromite_item, crystalline_item, ...
    mat = pyromite_item("PyroMat", "#F24D19")
"""

from materials.procedural._base import setup_material
from materials.pixel_art import hex_to_rgba


# ---------------------------------------------------------------------------
# 1. Pyromite (fire) — Wave bands + Noise = flowing magma veins
# ---------------------------------------------------------------------------
def pyromite_item(name, hex_color, glow_color=None, vein_scale=6.0):
    """Flowing magma surface: Wave Texture distorted by Noise creates
    organic lava veins. Bright emission in vein centers fading to
    dark cooled rock on the surface.
    """
    mat, nodes, links = setup_material(name)
    bsdf = nodes.get("Principled BSDF")
    base_rgba = hex_to_rgba(hex_color)

    if glow_color:
        glow_rgba = hex_to_rgba(glow_color)
    else:
        glow_rgba = (1.0, 0.75, 0.15, 1.0)

    dark_rgba = (base_rgba[0] * 0.3, base_rgba[1] * 0.2, base_rgba[2] * 0.15, 1.0)

    tex_coord = nodes.new(type='ShaderNodeTexCoord')

    # Noise to distort wave coordinates → organic vein shapes
    noise_warp = nodes.new(type='ShaderNodeTexNoise')
    noise_warp.inputs['Scale'].default_value = vein_scale * 1.5
    noise_warp.inputs['Detail'].default_value = 6.0
    noise_warp.inputs['Roughness'].default_value = 0.7
    noise_warp.inputs['Distortion'].default_value = 2.0
    links.new(tex_coord.outputs['Object'], noise_warp.inputs['Vector'])

    # Mix original coords with noise for warped input
    warp_mix = nodes.new(type='ShaderNodeMixRGB')
    warp_mix.blend_type = 'MIX'
    warp_mix.inputs['Fac'].default_value = 0.5
    links.new(tex_coord.outputs['Object'], warp_mix.inputs['Color1'])
    links.new(noise_warp.outputs['Color'], warp_mix.inputs['Color2'])

    # Wave Texture — bands type for flowing vein pattern
    wave = nodes.new(type='ShaderNodeTexWave')
    wave.wave_type = 'BANDS'
    wave.bands_direction = 'DIAGONAL'
    wave.wave_profile = 'SAW'
    wave.inputs['Scale'].default_value = vein_scale
    wave.inputs['Distortion'].default_value = 8.0
    wave.inputs['Detail'].default_value = 4.0
    wave.inputs['Detail Scale'].default_value = 1.5
    wave.inputs['Detail Roughness'].default_value = 0.6
    links.new(warp_mix.outputs['Color'], wave.inputs['Vector'])

    # ColorRamp: dark rock → hot base → bright glow
    vein_ramp = nodes.new(type='ShaderNodeValToRGB')
    vein_ramp.color_ramp.interpolation = 'EASE'
    vein_ramp.color_ramp.elements[0].position = 0.0
    vein_ramp.color_ramp.elements[0].color = dark_rgba
    e1 = vein_ramp.color_ramp.elements.new(0.35)
    e1.color = (base_rgba[0] * 0.6, base_rgba[1] * 0.4, base_rgba[2] * 0.3, 1.0)
    e2 = vein_ramp.color_ramp.elements.new(0.6)
    e2.color = base_rgba
    vein_ramp.color_ramp.elements[1].position = 0.85
    vein_ramp.color_ramp.elements[1].color = glow_rgba
    links.new(wave.outputs['Fac'], vein_ramp.inputs['Fac'])

    links.new(vein_ramp.outputs['Color'], bsdf.inputs['Base Color'])

    # Emission: glow in bright vein areas
    emit_mask = nodes.new(type='ShaderNodeMath')
    emit_mask.operation = 'GREATER_THAN'
    emit_mask.inputs[1].default_value = 0.6
    links.new(wave.outputs['Fac'], emit_mask.inputs[0])

    emit_strength = nodes.new(type='ShaderNodeMath')
    emit_strength.operation = 'MULTIPLY'
    emit_strength.inputs[1].default_value = 0.5
    links.new(emit_mask.outputs['Value'], emit_strength.inputs[0])

    emit_color = nodes.new(type='ShaderNodeMixRGB')
    emit_color.blend_type = 'MIX'
    emit_color.inputs['Color1'].default_value = (0, 0, 0, 1)
    emit_color.inputs['Color2'].default_value = glow_rgba
    links.new(emit_strength.outputs['Value'], emit_color.inputs['Fac'])
    links.new(emit_color.outputs['Color'], bsdf.inputs['Emission Color'])
    bsdf.inputs['Emission Strength'].default_value = 1.0

    # Roughness: smooth in hot veins, rough on cooled rock
    rough_inv = nodes.new(type='ShaderNodeMath')
    rough_inv.operation = 'SUBTRACT'
    rough_inv.inputs[0].default_value = 1.0
    rough_inv.use_clamp = True
    links.new(wave.outputs['Fac'], rough_inv.inputs[1])

    rough_final = nodes.new(type='ShaderNodeMath')
    rough_final.operation = 'ADD'
    rough_final.use_clamp = True
    rough_final.inputs[0].default_value = 0.3
    links.new(rough_inv.outputs['Value'], rough_final.inputs[1])
    links.new(rough_final.outputs['Value'], bsdf.inputs['Roughness'])
    bsdf.inputs['Metallic'].default_value = 0.0

    # Bump from wave pattern
    bump = nodes.new(type='ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.8
    bump.inputs['Distance'].default_value = 0.1
    links.new(wave.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])

    mat.diffuse_color = base_rgba
    return mat


# ---------------------------------------------------------------------------
# 2. Crystalline (ice) — Brick Texture (warped) for angular facets
# ---------------------------------------------------------------------------
def crystalline_item(name, hex_color, frost_color=None, facet_scale=5.0):
    """Shattered ice facets: Brick Texture with noise-warped coordinates
    creates irregular angular shard patterns. Frost collects on edges,
    sparkle spots add ice glint.
    """
    mat, nodes, links = setup_material(name)
    bsdf = nodes.get("Principled BSDF")
    base_rgba = hex_to_rgba(hex_color)

    if frost_color:
        frost_rgba = hex_to_rgba(frost_color)
    else:
        frost_rgba = (0.88, 0.93, 0.97, 1.0)

    deep_rgba = (base_rgba[0] * 0.3, base_rgba[1] * 0.4, base_rgba[2] * 0.7, 1.0)
    highlight_rgba = (
        min(base_rgba[0] * 1.5, 1.0),
        min(base_rgba[1] * 1.4, 1.0),
        min(base_rgba[2] * 1.2, 1.0),
        1.0,
    )

    tex_coord = nodes.new(type='ShaderNodeTexCoord')

    # Noise warp to shatter the brick grid
    noise_warp = nodes.new(type='ShaderNodeTexNoise')
    noise_warp.inputs['Scale'].default_value = facet_scale * 0.7
    noise_warp.inputs['Detail'].default_value = 3.0
    noise_warp.inputs['Roughness'].default_value = 0.5
    links.new(tex_coord.outputs['Object'], noise_warp.inputs['Vector'])

    warp_mix = nodes.new(type='ShaderNodeMixRGB')
    warp_mix.blend_type = 'MIX'
    warp_mix.inputs['Fac'].default_value = 0.35
    links.new(tex_coord.outputs['Object'], warp_mix.inputs['Color1'])
    links.new(noise_warp.outputs['Color'], warp_mix.inputs['Color2'])

    # Rotate coordinates for diagonal shatter pattern
    mapping = nodes.new(type='ShaderNodeMapping')
    mapping.inputs['Rotation'].default_value = (0.0, 0.35, 0.0)
    links.new(warp_mix.outputs['Color'], mapping.inputs['Vector'])

    # Primary Brick Texture — angular ice facets
    brick = nodes.new(type='ShaderNodeTexBrick')
    brick.offset = 0.0
    brick.squash = 0.65
    brick.squash_frequency = 2
    brick.inputs['Scale'].default_value = facet_scale
    brick.inputs['Mortar Size'].default_value = 0.025
    brick.inputs['Mortar Smooth'].default_value = 0.1
    brick.inputs['Bias'].default_value = -0.3
    brick.inputs['Brick Width'].default_value = 0.45
    brick.inputs['Row Height'].default_value = 0.3
    brick.inputs['Color1'].default_value = base_rgba
    brick.inputs['Color2'].default_value = highlight_rgba
    brick.inputs['Mortar'].default_value = deep_rgba
    links.new(mapping.outputs['Vector'], brick.inputs['Vector'])

    # Frost on mortar lines
    frost_raw = nodes.new(type='ShaderNodeMath')
    frost_raw.operation = 'SUBTRACT'
    frost_raw.inputs[0].default_value = 1.0
    links.new(brick.outputs['Fac'], frost_raw.inputs[1])

    frost_scaled = nodes.new(type='ShaderNodeMath')
    frost_scaled.operation = 'MULTIPLY'
    frost_scaled.use_clamp = True
    frost_scaled.inputs[1].default_value = 1.2
    links.new(frost_raw.outputs['Value'], frost_scaled.inputs[0])

    # Sparkle spots (high frequency noise threshold)
    noise_sparkle = nodes.new(type='ShaderNodeTexNoise')
    noise_sparkle.inputs['Scale'].default_value = 40.0
    noise_sparkle.inputs['Detail'].default_value = 3.0
    noise_sparkle.inputs['Roughness'].default_value = 0.95
    links.new(tex_coord.outputs['Object'], noise_sparkle.inputs['Vector'])

    sparkle_thresh = nodes.new(type='ShaderNodeMath')
    sparkle_thresh.operation = 'GREATER_THAN'
    sparkle_thresh.inputs[1].default_value = 0.88
    links.new(noise_sparkle.outputs['Fac'], sparkle_thresh.inputs[0])

    # Color assembly: brick + frost + sparkle
    ice_frosted = nodes.new(type='ShaderNodeMixRGB')
    ice_frosted.blend_type = 'MIX'
    ice_frosted.inputs['Color2'].default_value = frost_rgba
    links.new(brick.outputs['Color'], ice_frosted.inputs['Color1'])
    links.new(frost_scaled.outputs['Value'], ice_frosted.inputs['Fac'])

    ice_sparkle = nodes.new(type='ShaderNodeMixRGB')
    ice_sparkle.blend_type = 'ADD'
    ice_sparkle.inputs['Color2'].default_value = (0.8, 0.9, 1.0, 1.0)
    links.new(ice_frosted.outputs['Color'], ice_sparkle.inputs['Color1'])
    links.new(sparkle_thresh.outputs['Value'], ice_sparkle.inputs['Fac'])

    links.new(ice_sparkle.outputs['Color'], bsdf.inputs['Base Color'])

    # Low roughness for glossy ice look
    rough_base = nodes.new(type='ShaderNodeMath')
    rough_base.operation = 'ADD'
    rough_base.use_clamp = True
    rough_base.inputs[0].default_value = 0.08
    rough_frost = nodes.new(type='ShaderNodeMath')
    rough_frost.operation = 'MULTIPLY'
    rough_frost.inputs[1].default_value = 0.5
    links.new(frost_scaled.outputs['Value'], rough_frost.inputs[0])
    links.new(rough_frost.outputs['Value'], rough_base.inputs[1])
    links.new(rough_base.outputs['Value'], bsdf.inputs['Roughness'])
    bsdf.inputs['Metallic'].default_value = 0.0

    # Bump from facet edges
    bump = nodes.new(type='ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.7
    bump.inputs['Distance'].default_value = 0.12
    links.new(brick.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])

    mat.diffuse_color = base_rgba
    return mat


# ---------------------------------------------------------------------------
# 3. Biovine (nature) — Noise with heavy distortion for organic cells
# ---------------------------------------------------------------------------
def biovine_item(name, hex_color, spore_color=None, growth_scale=5.0):
    """Fractal organic surface: High-detail Noise with heavy distortion
    creates spongy, deeply layered organic patterns. Spore spots glow
    faintly with bioluminescence.
    """
    mat, nodes, links = setup_material(name)
    bsdf = nodes.get("Principled BSDF")
    base_rgba = hex_to_rgba(hex_color)

    if spore_color:
        spore_rgba = hex_to_rgba(spore_color)
    else:
        spore_rgba = (0.7, 1.0, 0.3, 1.0)

    shadow_rgba = (base_rgba[0] * 0.35, base_rgba[1] * 0.4, base_rgba[2] * 0.25, 1.0)
    tip_rgba = (
        min(base_rgba[0] * 1.3, 1.0),
        min(base_rgba[1] * 1.4, 1.0),
        min(base_rgba[2] * 0.8, 1.0),
        1.0,
    )

    tex_coord = nodes.new(type='ShaderNodeTexCoord')

    # Primary: High-detail noise with heavy distortion (fractal organic)
    noise_main = nodes.new(type='ShaderNodeTexNoise')
    noise_main.inputs['Scale'].default_value = growth_scale
    noise_main.inputs['Detail'].default_value = 15.0
    noise_main.inputs['Roughness'].default_value = 0.8
    noise_main.inputs['Distortion'].default_value = 2.5
    links.new(tex_coord.outputs['Object'], noise_main.inputs['Vector'])

    # ColorRamp: rich organic gradient
    moss_ramp = nodes.new(type='ShaderNodeValToRGB')
    moss_ramp.color_ramp.interpolation = 'B_SPLINE'
    moss_ramp.color_ramp.elements[0].position = 0.0
    moss_ramp.color_ramp.elements[0].color = (
        shadow_rgba[0] * 0.6, shadow_rgba[1] * 0.6, shadow_rgba[2] * 0.5, 1.0)
    s1 = moss_ramp.color_ramp.elements.new(0.25)
    s1.color = shadow_rgba
    s2 = moss_ramp.color_ramp.elements.new(0.5)
    s2.color = base_rgba
    s3 = moss_ramp.color_ramp.elements.new(0.7)
    s3.color = (
        min(base_rgba[0] * 1.15, 1.0),
        min(base_rgba[1] * 1.25, 1.0),
        base_rgba[2] * 0.85, 1.0)
    moss_ramp.color_ramp.elements[1].position = 0.9
    moss_ramp.color_ramp.elements[1].color = tip_rgba
    links.new(noise_main.outputs['Fac'], moss_ramp.inputs['Fac'])

    # Fine fungal detail layer
    noise_fungal = nodes.new(type='ShaderNodeTexNoise')
    noise_fungal.inputs['Scale'].default_value = growth_scale * 3.0
    noise_fungal.inputs['Detail'].default_value = 10.0
    noise_fungal.inputs['Roughness'].default_value = 0.65
    noise_fungal.inputs['Distortion'].default_value = 1.8
    links.new(tex_coord.outputs['Object'], noise_fungal.inputs['Vector'])

    # Overlay fungal detail on moss
    mossy = nodes.new(type='ShaderNodeMixRGB')
    mossy.blend_type = 'OVERLAY'
    mossy.inputs['Fac'].default_value = 0.5
    links.new(moss_ramp.outputs['Color'], mossy.inputs['Color1'])
    links.new(noise_fungal.outputs['Fac'], mossy.inputs['Fac'])
    mossy.inputs['Color2'].default_value = tip_rgba

    # Spore glow spots (threshold on fine noise)
    noise_spore = nodes.new(type='ShaderNodeTexNoise')
    noise_spore.inputs['Scale'].default_value = growth_scale * 8.0
    noise_spore.inputs['Detail'].default_value = 4.0
    noise_spore.inputs['Roughness'].default_value = 0.9
    noise_spore.inputs['Distortion'].default_value = 0.5
    links.new(tex_coord.outputs['Object'], noise_spore.inputs['Vector'])

    spore_thresh = nodes.new(type='ShaderNodeMath')
    spore_thresh.operation = 'GREATER_THAN'
    spore_thresh.inputs[1].default_value = 0.92
    links.new(noise_spore.outputs['Fac'], spore_thresh.inputs[0])

    # Final color: mossy + spore spots
    color_final = nodes.new(type='ShaderNodeMixRGB')
    color_final.blend_type = 'MIX'
    color_final.inputs['Color2'].default_value = spore_rgba
    links.new(mossy.outputs['Color'], color_final.inputs['Color1'])
    links.new(spore_thresh.outputs['Value'], color_final.inputs['Fac'])

    links.new(color_final.outputs['Color'], bsdf.inputs['Base Color'])

    # Faint bioluminescent emission from spores
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

    # Roughness: wet organic
    bsdf.inputs['Roughness'].default_value = 0.55
    bsdf.inputs['Metallic'].default_value = 0.0

    # Bump from organic surface
    bump = nodes.new(type='ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.7
    bump.inputs['Distance'].default_value = 0.08
    links.new(noise_main.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])

    mat.diffuse_color = base_rgba
    return mat


# ---------------------------------------------------------------------------
# 4. Voltite (lightning) — Wave Texture (rings) + threshold for electric arcs
# ---------------------------------------------------------------------------
def voltite_item(name, hex_color, spark_color=None, arc_scale=4.0):
    """Electric crackling surface: Wave Texture in ring mode creates
    concentric energy patterns. Threshold math isolates bright arc lines.
    Sharp emission on arc edges for electric glow.
    """
    mat, nodes, links = setup_material(name)
    bsdf = nodes.get("Principled BSDF")
    base_rgba = hex_to_rgba(hex_color)

    if spark_color:
        spark_rgba = hex_to_rgba(spark_color)
    else:
        spark_rgba = (1.0, 0.95, 0.5, 1.0)

    dark_rgba = (base_rgba[0] * 0.25, base_rgba[1] * 0.2, base_rgba[2] * 0.15, 1.0)

    tex_coord = nodes.new(type='ShaderNodeTexCoord')

    # Wave Texture — rings for concentric energy pattern
    wave = nodes.new(type='ShaderNodeTexWave')
    wave.wave_type = 'RINGS'
    wave.rings_direction = 'SPHERICAL'
    wave.wave_profile = 'SAW'
    wave.inputs['Scale'].default_value = arc_scale
    wave.inputs['Distortion'].default_value = 12.0  # high for chaotic arcs
    wave.inputs['Detail'].default_value = 5.0
    wave.inputs['Detail Scale'].default_value = 2.0
    wave.inputs['Detail Roughness'].default_value = 0.8
    links.new(tex_coord.outputs['Object'], wave.inputs['Vector'])

    # Second wave layer at different scale for complexity
    wave2 = nodes.new(type='ShaderNodeTexWave')
    wave2.wave_type = 'RINGS'
    wave2.rings_direction = 'SPHERICAL'
    wave2.wave_profile = 'TRI'
    wave2.inputs['Scale'].default_value = arc_scale * 2.5
    wave2.inputs['Distortion'].default_value = 8.0
    wave2.inputs['Detail'].default_value = 3.0
    wave2.inputs['Detail Scale'].default_value = 1.0
    wave2.inputs['Detail Roughness'].default_value = 0.7
    links.new(tex_coord.outputs['Object'], wave2.inputs['Vector'])

    # Threshold: isolate bright arc lines from wave
    arc_thresh = nodes.new(type='ShaderNodeMath')
    arc_thresh.operation = 'GREATER_THAN'
    arc_thresh.inputs[1].default_value = 0.7
    links.new(wave.outputs['Fac'], arc_thresh.inputs[0])

    arc_thresh2 = nodes.new(type='ShaderNodeMath')
    arc_thresh2.operation = 'GREATER_THAN'
    arc_thresh2.inputs[1].default_value = 0.75
    links.new(wave2.outputs['Fac'], arc_thresh2.inputs[0])

    # Combine arcs (either wave produces a spark)
    arc_combined = nodes.new(type='ShaderNodeMath')
    arc_combined.operation = 'MAXIMUM'
    links.new(arc_thresh.outputs['Value'], arc_combined.inputs[0])
    links.new(arc_thresh2.outputs['Value'], arc_combined.inputs[1])

    # Smooth wave for base color gradient
    base_ramp = nodes.new(type='ShaderNodeValToRGB')
    base_ramp.color_ramp.interpolation = 'EASE'
    base_ramp.color_ramp.elements[0].position = 0.0
    base_ramp.color_ramp.elements[0].color = dark_rgba
    base_ramp.color_ramp.elements[1].position = 1.0
    base_ramp.color_ramp.elements[1].color = base_rgba
    links.new(wave.outputs['Fac'], base_ramp.inputs['Fac'])

    # Final color: base + bright arcs
    color_final = nodes.new(type='ShaderNodeMixRGB')
    color_final.blend_type = 'MIX'
    color_final.inputs['Color2'].default_value = spark_rgba
    links.new(base_ramp.outputs['Color'], color_final.inputs['Color1'])
    links.new(arc_combined.outputs['Value'], color_final.inputs['Fac'])

    links.new(color_final.outputs['Color'], bsdf.inputs['Base Color'])

    # Strong emission on arc lines
    emit_strength = nodes.new(type='ShaderNodeMath')
    emit_strength.operation = 'MULTIPLY'
    emit_strength.inputs[1].default_value = 0.8
    links.new(arc_combined.outputs['Value'], emit_strength.inputs[0])

    emit_color = nodes.new(type='ShaderNodeMixRGB')
    emit_color.blend_type = 'MIX'
    emit_color.inputs['Color1'].default_value = (0, 0, 0, 1)
    emit_color.inputs['Color2'].default_value = spark_rgba
    links.new(emit_strength.outputs['Value'], emit_color.inputs['Fac'])
    links.new(emit_color.outputs['Color'], bsdf.inputs['Emission Color'])
    bsdf.inputs['Emission Strength'].default_value = 1.0

    # Roughness: smooth where arcs, rough elsewhere
    rough_val = nodes.new(type='ShaderNodeMath')
    rough_val.operation = 'SUBTRACT'
    rough_val.inputs[0].default_value = 0.85
    rough_val.use_clamp = True
    rough_mul = nodes.new(type='ShaderNodeMath')
    rough_mul.operation = 'MULTIPLY'
    rough_mul.inputs[1].default_value = 0.6
    links.new(arc_combined.outputs['Value'], rough_mul.inputs[0])
    links.new(rough_mul.outputs['Value'], rough_val.inputs[1])
    links.new(rough_val.outputs['Value'], bsdf.inputs['Roughness'])
    bsdf.inputs['Metallic'].default_value = 0.1

    # Bump from wave pattern
    bump = nodes.new(type='ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.6
    bump.inputs['Distance'].default_value = 0.08
    links.new(wave.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])

    mat.diffuse_color = base_rgba
    return mat


# ---------------------------------------------------------------------------
# 5. Umbrite (shadow) — Gradient (spherical) + Checker (distorted) for void
# ---------------------------------------------------------------------------
def umbrite_item(name, hex_color, corona_color=None, void_scale=4.0):
    """Swirling void surface: Spherical Gradient creates a dark-core orb
    effect. Distorted Checker Texture adds dimensional fracture patterns.
    Faint purple corona emission around the edges.
    """
    mat, nodes, links = setup_material(name)
    bsdf = nodes.get("Principled BSDF")
    base_rgba = hex_to_rgba(hex_color)

    if corona_color:
        corona_rgba = hex_to_rgba(corona_color)
    else:
        corona_rgba = (0.6, 0.44, 0.8, 1.0)

    deep_rgba = (base_rgba[0] * 0.2, base_rgba[1] * 0.15, base_rgba[2] * 0.25, 1.0)
    void_rgba = (0.05, 0.02, 0.08, 1.0)

    tex_coord = nodes.new(type='ShaderNodeTexCoord')

    # Gradient Texture — spherical for dark-core orb
    gradient = nodes.new(type='ShaderNodeTexGradient')
    gradient.gradient_type = 'SPHERICAL'
    links.new(tex_coord.outputs['Object'], gradient.inputs['Vector'])

    # Invert: center is dark, edges are bright
    grad_invert = nodes.new(type='ShaderNodeMath')
    grad_invert.operation = 'SUBTRACT'
    grad_invert.inputs[0].default_value = 1.0
    links.new(gradient.outputs['Fac'], grad_invert.inputs[1])

    # Power curve: concentrate darkness at center
    grad_power = nodes.new(type='ShaderNodeMath')
    grad_power.operation = 'POWER'
    grad_power.inputs[1].default_value = 2.0
    links.new(grad_invert.outputs['Value'], grad_power.inputs[0])

    # Noise to distort checker coordinates → dimensional fractures
    noise_warp = nodes.new(type='ShaderNodeTexNoise')
    noise_warp.inputs['Scale'].default_value = void_scale * 0.8
    noise_warp.inputs['Detail'].default_value = 5.0
    noise_warp.inputs['Roughness'].default_value = 0.7
    noise_warp.inputs['Distortion'].default_value = 3.0
    links.new(tex_coord.outputs['Object'], noise_warp.inputs['Vector'])

    warp_mix = nodes.new(type='ShaderNodeMixRGB')
    warp_mix.blend_type = 'MIX'
    warp_mix.inputs['Fac'].default_value = 0.6
    links.new(tex_coord.outputs['Object'], warp_mix.inputs['Color1'])
    links.new(noise_warp.outputs['Color'], warp_mix.inputs['Color2'])

    # Checker Texture — distorted for dimensional fracture pattern
    checker = nodes.new(type='ShaderNodeTexChecker')
    checker.inputs['Scale'].default_value = void_scale * 2.0
    checker.inputs['Color1'].default_value = base_rgba
    checker.inputs['Color2'].default_value = deep_rgba
    links.new(warp_mix.outputs['Color'], checker.inputs['Vector'])

    # Combine: gradient darkness × checker fractures
    void_mix = nodes.new(type='ShaderNodeMixRGB')
    void_mix.blend_type = 'MULTIPLY'
    void_mix.inputs['Fac'].default_value = 0.7
    links.new(checker.outputs['Color'], void_mix.inputs['Color1'])
    links.new(grad_power.outputs['Value'], void_mix.inputs['Fac'])
    void_mix.inputs['Color2'].default_value = void_rgba

    # Darken the center more with gradient
    color_final = nodes.new(type='ShaderNodeMixRGB')
    color_final.blend_type = 'MIX'
    links.new(checker.outputs['Color'], color_final.inputs['Color1'])
    links.new(void_mix.outputs['Color'], color_final.inputs['Color2'])
    links.new(grad_power.outputs['Value'], color_final.inputs['Fac'])

    links.new(color_final.outputs['Color'], bsdf.inputs['Base Color'])

    # Corona emission at edges (inverted gradient = edge glow)
    edge_mask = nodes.new(type='ShaderNodeMath')
    edge_mask.operation = 'POWER'
    edge_mask.inputs[1].default_value = 3.0
    links.new(gradient.outputs['Fac'], edge_mask.inputs[0])

    emit_strength = nodes.new(type='ShaderNodeMath')
    emit_strength.operation = 'MULTIPLY'
    emit_strength.inputs[1].default_value = 0.4
    links.new(edge_mask.outputs['Value'], emit_strength.inputs[0])

    emit_color = nodes.new(type='ShaderNodeMixRGB')
    emit_color.blend_type = 'MIX'
    emit_color.inputs['Color1'].default_value = (0, 0, 0, 1)
    emit_color.inputs['Color2'].default_value = corona_rgba
    links.new(emit_strength.outputs['Value'], emit_color.inputs['Fac'])
    links.new(emit_color.outputs['Color'], bsdf.inputs['Emission Color'])
    bsdf.inputs['Emission Strength'].default_value = 1.0

    # Dark, slightly glossy
    bsdf.inputs['Roughness'].default_value = 0.4
    bsdf.inputs['Metallic'].default_value = 0.1

    # Bump from checker fractures
    bump = nodes.new(type='ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.5
    bump.inputs['Distance'].default_value = 0.06
    links.new(checker.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])

    mat.diffuse_color = base_rgba
    return mat


# ---------------------------------------------------------------------------
# 6. Resonite (force) — Magic Texture for geometric force-field
# ---------------------------------------------------------------------------
def resonite_item(name, hex_color, energy_color=None, field_scale=3.0):
    """Geometric force-field surface: Magic Texture creates complex
    self-similar geometric patterns. Chrome metallic base with spectral
    energy highlights. Concentric energy rings from the Magic Texture
    turbulence.
    """
    mat, nodes, links = setup_material(name)
    bsdf = nodes.get("Principled BSDF")
    base_rgba = hex_to_rgba(hex_color)

    if energy_color:
        energy_rgba = hex_to_rgba(energy_color)
    else:
        energy_rgba = (0.94, 0.94, 1.0, 1.0)

    dark_rgba = (base_rgba[0] * 0.5, base_rgba[1] * 0.5, base_rgba[2] * 0.55, 1.0)

    tex_coord = nodes.new(type='ShaderNodeTexCoord')

    # Magic Texture — psychedelic geometric patterns
    magic = nodes.new(type='ShaderNodeTexMagic')
    magic.turbulence_depth = 4
    magic.inputs['Scale'].default_value = field_scale
    magic.inputs['Distortion'].default_value = 2.0
    links.new(tex_coord.outputs['Object'], magic.inputs['Vector'])

    # Second Magic at different scale for layered complexity
    magic2 = nodes.new(type='ShaderNodeTexMagic')
    magic2.turbulence_depth = 3
    magic2.inputs['Scale'].default_value = field_scale * 2.5
    magic2.inputs['Distortion'].default_value = 1.5
    links.new(tex_coord.outputs['Object'], magic2.inputs['Vector'])

    # Extract luminance from Magic color for pattern intensity
    # Use the Fac output (grayscale) of magic texture
    magic_ramp = nodes.new(type='ShaderNodeValToRGB')
    magic_ramp.color_ramp.interpolation = 'EASE'
    magic_ramp.color_ramp.elements[0].position = 0.0
    magic_ramp.color_ramp.elements[0].color = dark_rgba
    e1 = magic_ramp.color_ramp.elements.new(0.4)
    e1.color = base_rgba
    magic_ramp.color_ramp.elements[1].position = 0.8
    magic_ramp.color_ramp.elements[1].color = energy_rgba
    links.new(magic.outputs['Fac'], magic_ramp.inputs['Fac'])

    # Overlay second magic layer for depth
    color_overlay = nodes.new(type='ShaderNodeMixRGB')
    color_overlay.blend_type = 'OVERLAY'
    color_overlay.inputs['Fac'].default_value = 0.35
    links.new(magic_ramp.outputs['Color'], color_overlay.inputs['Color1'])
    links.new(magic2.outputs['Color'], color_overlay.inputs['Color2'])

    links.new(color_overlay.outputs['Color'], bsdf.inputs['Base Color'])

    # Energy line emission (bright geometric lines from magic)
    emit_mask = nodes.new(type='ShaderNodeMath')
    emit_mask.operation = 'GREATER_THAN'
    emit_mask.inputs[1].default_value = 0.65
    links.new(magic.outputs['Fac'], emit_mask.inputs[0])

    emit_strength = nodes.new(type='ShaderNodeMath')
    emit_strength.operation = 'MULTIPLY'
    emit_strength.inputs[1].default_value = 0.25
    links.new(emit_mask.outputs['Value'], emit_strength.inputs[0])

    emit_color = nodes.new(type='ShaderNodeMixRGB')
    emit_color.blend_type = 'MIX'
    emit_color.inputs['Color1'].default_value = (0, 0, 0, 1)
    emit_color.inputs['Color2'].default_value = energy_rgba
    links.new(emit_strength.outputs['Value'], emit_color.inputs['Fac'])
    links.new(emit_color.outputs['Color'], bsdf.inputs['Emission Color'])
    bsdf.inputs['Emission Strength'].default_value = 1.0

    # Chrome metallic surface
    bsdf.inputs['Metallic'].default_value = 0.6
    bsdf.inputs['Roughness'].default_value = 0.25

    # Bump from magic pattern
    bump = nodes.new(type='ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.5
    bump.inputs['Distance'].default_value = 0.06
    links.new(magic.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])

    mat.diffuse_color = base_rgba
    return mat
