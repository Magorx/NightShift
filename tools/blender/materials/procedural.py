"""Procedural shader-based textures for industrial buildings.

Creates Principled BSDF materials with shader-node procedural
textures. No image textures — everything is generated from hex
colors and Blender's built-in noise/pattern nodes.

These materials are palette-constrained: you provide hex colors
and the textures create subtle variation within that palette.
"""

import bpy
import os
import sys

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(__file__), "..")))
from materials.pixel_art import hex_to_rgba


def _setup_material(name):
    """Create a new material with nodes enabled, return (mat, nodes, links)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = False
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    return mat, nodes, links


def metal_scratched(name, hex_color, scratch_amount=0.3, scratch_scale=20.0):
    """Metal surface with subtle scratches.

    Base color darkened by noise-driven scratches. Still reads as a
    solid color from distance but has surface detail up close.

    Args:
        name: Material name.
        hex_color: Base color.
        scratch_amount: How visible scratches are (0-1).
        scratch_scale: Noise scale (higher = finer scratches).

    Returns:
        The Blender material.
    """
    mat, nodes, links = _setup_material(name)

    bsdf = nodes.get("Principled BSDF")
    base_rgba = hex_to_rgba(hex_color)

    # Noise texture for scratch pattern
    noise = nodes.new(type='ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = scratch_scale
    noise.inputs['Detail'].default_value = 8.0
    noise.inputs['Roughness'].default_value = 0.7

    # Map noise to a subtle darkening range
    ramp = nodes.new(type='ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.4
    ramp.color_ramp.elements[0].color = (
        base_rgba[0] * (1.0 - scratch_amount),
        base_rgba[1] * (1.0 - scratch_amount),
        base_rgba[2] * (1.0 - scratch_amount),
        1.0,
    )
    ramp.color_ramp.elements[1].position = 0.6
    ramp.color_ramp.elements[1].color = base_rgba

    links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
    links.new(ramp.outputs['Color'], bsdf.inputs['Base Color'])

    bsdf.inputs['Roughness'].default_value = 0.85
    bsdf.inputs['Metallic'].default_value = 0.3

    mat.diffuse_color = base_rgba
    return mat


def riveted_plate(name, hex_color, rivet_color=None, rivet_spacing=0.3,
                  rivet_size=0.08):
    """Flat metal plate with a grid of rivet bumps.

    Uses Voronoi texture to create a regular dot pattern that
    simulates rivets via normal map displacement.

    Args:
        name: Material name.
        hex_color: Plate base color.
        rivet_color: Rivet dot color (None = slightly brighter base).
        rivet_spacing: Distance between rivets.
        rivet_size: Rivet dot size relative to spacing.

    Returns:
        The Blender material.
    """
    mat, nodes, links = _setup_material(name)

    bsdf = nodes.get("Principled BSDF")
    base_rgba = hex_to_rgba(hex_color)

    if rivet_color:
        rivet_rgba = hex_to_rgba(rivet_color)
    else:
        rivet_rgba = (
            min(base_rgba[0] * 1.2, 1.0),
            min(base_rgba[1] * 1.2, 1.0),
            min(base_rgba[2] * 1.2, 1.0),
            1.0,
        )

    # Voronoi for rivet dot pattern
    voronoi = nodes.new(type='ShaderNodeTexVoronoi')
    voronoi.feature = 'DISTANCE_TO_EDGE'
    voronoi.inputs['Scale'].default_value = 1.0 / rivet_spacing

    # Threshold to create dots
    math_node = nodes.new(type='ShaderNodeMath')
    math_node.operation = 'LESS_THAN'
    math_node.inputs[1].default_value = rivet_size

    links.new(voronoi.outputs['Distance'], math_node.inputs[0])

    # Mix base color and rivet color
    mix = nodes.new(type='ShaderNodeMixRGB')
    mix.inputs['Color1'].default_value = base_rgba
    mix.inputs['Color2'].default_value = rivet_rgba

    links.new(math_node.outputs['Value'], mix.inputs['Fac'])
    links.new(mix.outputs['Color'], bsdf.inputs['Base Color'])

    # Rivet bumps via normal
    bump = nodes.new(type='ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.3
    links.new(math_node.outputs['Value'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])

    bsdf.inputs['Roughness'].default_value = 0.9
    bsdf.inputs['Metallic'].default_value = 0.1

    mat.diffuse_color = base_rgba
    return mat


def panel_seams(name, hex_color, seam_color=None, panel_size=0.5,
                seam_width=0.02):
    """Flat color with visible panel seam lines.

    Uses Brick Texture node to create a grid of panel seams
    that darken the surface along the edges.

    Args:
        name: Material name.
        hex_color: Panel base color.
        seam_color: Seam line color (None = darker base).
        panel_size: Size of each panel.
        seam_width: Width of seam lines relative to panel.

    Returns:
        The Blender material.
    """
    mat, nodes, links = _setup_material(name)

    bsdf = nodes.get("Principled BSDF")
    base_rgba = hex_to_rgba(hex_color)

    if seam_color:
        seam_rgba = hex_to_rgba(seam_color)
    else:
        seam_rgba = (
            base_rgba[0] * 0.6,
            base_rgba[1] * 0.6,
            base_rgba[2] * 0.6,
            1.0,
        )

    # Brick texture for panel grid
    brick = nodes.new(type='ShaderNodeTexBrick')
    brick.inputs['Scale'].default_value = 1.0 / panel_size
    brick.inputs['Color1'].default_value = base_rgba
    brick.inputs['Color2'].default_value = base_rgba
    brick.inputs['Mortar'].default_value = seam_rgba
    brick.inputs['Mortar Size'].default_value = seam_width
    brick.inputs['Bias'].default_value = 0.0
    brick.inputs['Brick Width'].default_value = 1.0
    brick.inputs['Row Height'].default_value = 1.0

    links.new(brick.outputs['Color'], bsdf.inputs['Base Color'])

    # Subtle depth at seams
    bump = nodes.new(type='ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.2
    links.new(brick.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])

    bsdf.inputs['Roughness'].default_value = 0.95
    bsdf.inputs['Metallic'].default_value = 0.0

    mat.diffuse_color = base_rgba
    return mat


def corrugated(name, hex_color, wave_period=0.15, wave_depth=0.3):
    """Corrugated metal surface with wave ridges.

    Uses Wave Texture for parallel ridges that catch light differently
    on peaks vs valleys.

    Args:
        name: Material name.
        hex_color: Base color.
        wave_period: Distance between ridges.
        wave_depth: How pronounced the ridges are (bump strength).

    Returns:
        The Blender material.
    """
    mat, nodes, links = _setup_material(name)

    bsdf = nodes.get("Principled BSDF")
    base_rgba = hex_to_rgba(hex_color)

    bsdf.inputs['Base Color'].default_value = base_rgba

    # Wave texture for ridges
    wave = nodes.new(type='ShaderNodeTexWave')
    wave.wave_type = 'BANDS'
    wave.bands_direction = 'X'
    wave.inputs['Scale'].default_value = 1.0 / wave_period
    wave.inputs['Distortion'].default_value = 0.0
    wave.inputs['Detail'].default_value = 0.0

    # Bump from wave pattern
    bump = nodes.new(type='ShaderNodeBump')
    bump.inputs['Strength'].default_value = wave_depth
    links.new(wave.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])

    bsdf.inputs['Roughness'].default_value = 0.8
    bsdf.inputs['Metallic'].default_value = 0.2

    mat.diffuse_color = base_rgba
    return mat


def rust_patchy(name, hex_color, rust_color="#8B4513", coverage=0.3,
                scale=5.0):
    """Base color with patchy rust/weathering overlay.

    Uses Voronoi + Noise to create organic patches of a secondary
    color (rust, grime, weathering) over the base.

    Args:
        name: Material name.
        hex_color: Clean base color.
        rust_color: Rust/weathering color.
        coverage: How much rust (0-1).
        scale: Noise scale (higher = smaller patches).

    Returns:
        The Blender material.
    """
    mat, nodes, links = _setup_material(name)

    bsdf = nodes.get("Principled BSDF")
    base_rgba = hex_to_rgba(hex_color)
    rust_rgba = hex_to_rgba(rust_color)

    # Noise for organic mask
    noise = nodes.new(type='ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = scale
    noise.inputs['Detail'].default_value = 4.0
    noise.inputs['Roughness'].default_value = 0.6

    # Threshold noise to create patches
    ramp = nodes.new(type='ShaderNodeValToRGB')
    # Sharp transition: clean → rusty
    ramp.color_ramp.elements[0].position = 0.5 - coverage * 0.3
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 0.5 + coverage * 0.2
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)

    links.new(noise.outputs['Fac'], ramp.inputs['Fac'])

    # Mix clean and rusty
    mix = nodes.new(type='ShaderNodeMixRGB')
    mix.inputs['Color1'].default_value = base_rgba
    mix.inputs['Color2'].default_value = rust_rgba

    links.new(ramp.outputs['Color'], mix.inputs['Fac'])
    links.new(mix.outputs['Color'], bsdf.inputs['Base Color'])

    # Rust is rougher
    mix_rough = nodes.new(type='ShaderNodeMixRGB')
    mix_rough.inputs['Color1'].default_value = (0.9, 0.9, 0.9, 1.0)
    mix_rough.inputs['Color2'].default_value = (1.0, 1.0, 1.0, 1.0)
    links.new(ramp.outputs['Color'], mix_rough.inputs['Fac'])
    links.new(mix_rough.outputs['Color'], bsdf.inputs['Roughness'])

    mat.diffuse_color = base_rgba
    return mat


def grime_gradient(name, hex_color, grime_color=None, height_range=1.0):
    """Vertical gradient darkening toward the bottom (dirt/grime accumulation).

    Uses object-space Z coordinate to darken the lower portions of a mesh,
    simulating natural dirt accumulation.

    Args:
        name: Material name.
        hex_color: Clean color (top).
        grime_color: Dirty color (bottom). None = 40% darker base.
        height_range: Object height for gradient mapping.

    Returns:
        The Blender material.
    """
    mat, nodes, links = _setup_material(name)

    bsdf = nodes.get("Principled BSDF")
    base_rgba = hex_to_rgba(hex_color)

    if grime_color:
        grime_rgba = hex_to_rgba(grime_color)
    else:
        grime_rgba = (
            base_rgba[0] * 0.6,
            base_rgba[1] * 0.6,
            base_rgba[2] * 0.55,
            1.0,
        )

    # Object-space texture coordinates
    tex_coord = nodes.new(type='ShaderNodeTexCoord')

    # Separate Z component
    separate = nodes.new(type='ShaderNodeSeparateXYZ')
    links.new(tex_coord.outputs['Object'], separate.inputs['Vector'])

    # Map Z range to 0-1
    map_range = nodes.new(type='ShaderNodeMapRange')
    map_range.inputs['From Min'].default_value = 0
    map_range.inputs['From Max'].default_value = height_range
    links.new(separate.outputs['Z'], map_range.inputs['Value'])

    # Mix grime (bottom) to clean (top)
    mix = nodes.new(type='ShaderNodeMixRGB')
    mix.inputs['Color1'].default_value = grime_rgba
    mix.inputs['Color2'].default_value = base_rgba
    links.new(map_range.outputs['Result'], mix.inputs['Fac'])
    links.new(mix.outputs['Color'], bsdf.inputs['Base Color'])

    bsdf.inputs['Roughness'].default_value = 0.95
    bsdf.inputs['Metallic'].default_value = 0.0

    mat.diffuse_color = base_rgba
    return mat
