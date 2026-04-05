"""Procedural shader-based textures for terrain and buildings.

Creates Principled BSDF materials with shader-node procedural
textures. No image textures — everything is generated from hex
colors and Blender's built-in noise/pattern nodes.

These materials are palette-constrained: you provide hex colors
and the textures create subtle variation within that palette.

Usage:
    from materials.procedural import grassland, rocky_land, pyromite_ground
    mat = grassland("grass_base", "#597A4D")
    mat = rocky_land("rock", "#7A6B5A")
    mat = pyromite_ground("pyro", "#3A2218")
"""

from materials.procedural.rocky_land import rocky_land
from materials.procedural.grassland import grassland
from materials.procedural.pyromite_ground import pyromite_ground
from materials.procedural.crystalline_ground import crystalline_ground
from materials.procedural.biovine_ground import biovine_ground

__all__ = [
    'rocky_land',
    'grassland',
    'pyromite_ground',
    'crystalline_ground',
    'biovine_ground',
]
