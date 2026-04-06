"""Shared helpers for procedural material creation."""

import bpy
import os
import sys

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..")))
from materials.pixel_art import hex_to_rgba


def setup_material(name):
    """Create a new material with nodes enabled, return (mat, nodes, links)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = False
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    return mat, nodes, links
