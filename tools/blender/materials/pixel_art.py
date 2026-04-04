"""Material creation for low-poly industrial style rendering.

Provides flat PBR materials (cached by hex color to avoid duplicates)
and a palette loader that reads our Lua palette files.
"""

import bpy
import os
import re

REPO_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

# Cache: hex_color -> material. Cleared by clear_material_cache().
_material_cache = {}


def hex_to_rgba(hex_str):
    """Convert a hex color string to (r, g, b, a) with values 0-1.

    Supports '#RRGGBB' and '#RRGGBBAA' formats.
    """
    h = hex_str.lstrip('#')
    r = int(h[0:2], 16) / 255.0
    g = int(h[2:4], 16) / 255.0
    b = int(h[4:6], 16) / 255.0
    a = int(h[6:8], 16) / 255.0 if len(h) >= 8 else 1.0
    return (r, g, b, a)


def clear_material_cache():
    """Clear the material cache. Call after clear_scene()."""
    _material_cache.clear()


def create_flat_material(name, hex_color):
    """Create or reuse a flat-colored PBR material (Principled BSDF).

    Materials are cached by hex_color — multiple objects with the same
    color share one material, reducing duplication in the exported .glb.

    Args:
        name: Material name (used only if creating a new material).
        hex_color: Color as '#RRGGBB' or '#RRGGBBAA'.

    Returns:
        The Blender material.
    """
    key = hex_color.upper()
    if key in _material_cache:
        return _material_cache[key]

    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = False

    nodes = mat.node_tree.nodes

    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = hex_to_rgba(hex_color)
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0

    mat.diffuse_color = hex_to_rgba(hex_color)

    _material_cache[key] = mat
    return mat


def create_toon_material(name, hex_color, steps=3, ambient=0.4):
    """Create a toon-shaded material with discrete shading steps.

    Gives a slightly more 3D look than pure emission while staying
    palette-friendly. Uses a ColorRamp to quantize the diffuse shading.

    Args:
        name: Material name.
        hex_color: Base color as '#RRGGBB'.
        steps: Number of discrete shading levels (2-4 typical for pixel art).
        ambient: Minimum brightness (0-1). Higher = less shadow.

    Returns:
        The Blender material.
    """
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = False

    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    # Diffuse BSDF for basic shading
    diffuse = nodes.new(type='ShaderNodeBsdfDiffuse')
    diffuse.inputs[0].default_value = hex_to_rgba(hex_color)

    # Shader to RGB — converts shading to a color value we can quantize
    shader_to_rgb = nodes.new(type='ShaderNodeShaderToRGB')
    links.new(diffuse.outputs[0], shader_to_rgb.inputs[0])

    # ColorRamp — quantizes into discrete steps
    ramp = nodes.new(type='ShaderNodeValToRGB')
    ramp.color_ramp.interpolation = 'CONSTANT'

    # Set up N discrete shading steps
    # Clear default elements and rebuild
    elements = ramp.color_ramp.elements
    # There are always at least 2 elements; remove extras
    while len(elements) > 2:
        elements.remove(elements[-1])

    base_rgba = hex_to_rgba(hex_color)
    for i in range(steps):
        pos = i / steps
        brightness = ambient + (1.0 - ambient) * (i / (steps - 1))
        color = (
            min(base_rgba[0] * brightness, 1.0),
            min(base_rgba[1] * brightness, 1.0),
            min(base_rgba[2] * brightness, 1.0),
            1.0,
        )
        if i < len(elements):
            elements[i].position = pos
            elements[i].color = color
        else:
            elem = elements.new(pos)
            elem.color = color

    links.new(shader_to_rgb.outputs[0], ramp.inputs[0])

    # Emission from the quantized color — so lighting doesn't further modify it
    emission = nodes.new(type='ShaderNodeEmission')
    links.new(ramp.outputs[0], emission.inputs[0])
    emission.inputs[1].default_value = 1.0

    output = nodes.new(type='ShaderNodeOutputMaterial')
    links.new(emission.outputs[0], output.inputs[0])

    mat.diffuse_color = hex_to_rgba(hex_color)
    return mat


def load_palette(palette_name):
    """Load a Lua palette file and return a dict of name -> hex color string.

    Parses the simple `key = "#RRGGBB"` format from tools/palettes/*.lua.

    Args:
        palette_name: Name without extension (e.g. "buildings").

    Returns:
        Dict mapping color names to hex strings.
    """
    path = os.path.join(REPO_ROOT, "tools", "palettes", f"{palette_name}.lua")
    palette = {}

    with open(path, 'r') as f:
        content = f.read()

    # Match lines like: key = "#RRGGBB" or key = "#RRGGBBAA"
    pattern = re.compile(r'(\w+)\s*=\s*"(#[0-9A-Fa-f]{6,8})"')
    for match in pattern.finditer(content):
        palette[match.group(1)] = match.group(2)

    return palette
