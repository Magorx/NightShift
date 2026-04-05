"""Export all conveyor belt variants as 3D models (.glb) for Godot import.

Variants (wall config defines the shape):
- straight:       walls left/right, open front/back — basic 1-in 1-out
- turn:           walls left/front (L-shape) — input back, output right
- two_straight:   wall right only — straight + side input from left
- two_turn:       wall front only (T-shape) — input back, outputs left+right
- cross:          no walls (+ shape) — all 4 sides open

Each variant gets flat + textured versions.

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/conveyor_model.py
"""

import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BLENDER_DIR = os.path.normpath(os.path.join(SCRIPT_DIR, ".."))
REPO_ROOT = os.path.normpath(os.path.join(BLENDER_DIR, "..", ".."))
sys.path.insert(0, BLENDER_DIR)

from export_helpers import export_glb
from render import clear_scene
from anim_helpers import animate_shake, animate_static
from prefabs_src.conveyor_parts import (
    create_conveyor_root,
    add_base_plate, add_hazard_stripe,
    add_wall, add_wall_details,
    add_belt_surface, add_belt_grooves_y, add_belt_grooves_x,
    add_direction_arrow,
    apply_conveyor_textures,
)


# ---------------------------------------------------------------------------
# Variant definitions
# ---------------------------------------------------------------------------
#   arrows: list of (x, y, rotation_deg)   0°=+Y, 90°=-X, 180°=-Y, 270°=+X
VARIANTS = [
    {
        "name": "conveyor",
        "walled": {'left', 'right'},
        "arrows": [(0, 0.05, 0)],
        "grooves": {'y'},
    },
    {
        "name": "conveyor_turn",
        "walled": {'left', 'front'},
        "arrows": [],
        "grooves": {'x', 'y'},
    },
    {
        "name": "conveyor_two_straight",
        "walled": {'right'},
        "arrows": [],
        "grooves": {'x', 'y'},
    },
    {
        "name": "conveyor_two_turn",
        "walled": {'front'},
        "arrows": [],
        "grooves": {'x', 'y'},
    },
    {
        "name": "conveyor_cross",
        "walled": set(),
        "arrows": [],
        "grooves": {'x', 'y'},
    },
]


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
def build_variant(variant):
    """Build a conveyor variant from its config dict."""
    clear_scene()

    name = variant["name"]
    walled = variant["walled"]

    root, add = create_conveyor_root(name)

    base = add_base_plate(add)
    add_hazard_stripe(add)

    walls = {}
    for side in walled:
        wall, _cap, _lip = add_wall(add, side)
        add_wall_details(add, side)
        walls[side] = wall

    belt = add_belt_surface(add, walled)

    if 'y' in variant["grooves"]:
        add_belt_grooves_y(add, walled)
    if 'x' in variant["grooves"]:
        add_belt_grooves_x(add, walled)

    for ax, ay, rot in variant["arrows"]:
        add_direction_arrow(add, x=ax, y=ay, rotation_deg=rot)

    return {"root": root, "belt": belt, "base": base, "walls": walls}


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------
def bake_animations(objects):
    """Bake idle/active/wall animation states."""
    belt = objects["belt"]
    base = objects["base"]
    walls = objects["walls"]

    for state in ("idle", "wall"):
        animate_static(belt, state, duration=2.0)
        animate_static(base, state, duration=2.0)
        for w in walls.values():
            animate_static(w, state, duration=2.0)

    animate_shake(belt, "active", duration=2.0, amplitude=0.002, frequency=10)
    animate_static(base, "active", duration=2.0)
    for w in walls.values():
        animate_static(w, "active", duration=2.0)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    output_dir = os.path.join(REPO_ROOT, "buildings", "conveyor", "models")
    print(f"[conveyor_model] Output dir: {output_dir}")

    for variant in VARIANTS:
        name = variant["name"]

        # Flat version
        objects = build_variant(variant)
        bake_animations(objects)
        flat_path = os.path.join(output_dir, f"{name}_flat.glb")
        export_glb(flat_path)
        print(f"[conveyor_model] {name} flat: {flat_path}")

        # Textured version
        objects = build_variant(variant)
        bake_animations(objects)
        apply_conveyor_textures(objects["root"])
        path = os.path.join(output_dir, f"{name}.glb")
        export_glb(path)
        print(f"[conveyor_model] {name} textured: {path}")

    print(f"[conveyor_model] Done — {len(VARIANTS)} variants exported.")


if __name__ == "__main__":
    main()
