"""Export Source and Sink debug buildings as 3D models (.glb) for Godot import.

Source: spawns items. Green accent, upward-pointing cone/arrow, open top.
Sink: consumes items. Red accent, downward funnel, grate on top.

Both are compact ~1.6x1.6 industrial boxes with distinct silhouettes.

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
    $BLENDER --background --python tools/blender/scenes/debug_buildings_model.py
"""

import bpy
import os
import sys
import math

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BLENDER_DIR = os.path.normpath(os.path.join(SCRIPT_DIR, ".."))
REPO_ROOT = os.path.normpath(os.path.join(BLENDER_DIR, "..", ".."))
sys.path.insert(0, BLENDER_DIR)

from render import clear_scene
from materials.pixel_art import create_flat_material, load_palette
from texture_library import apply_texture
from prefabs_src.box import generate_box
from prefabs_src.cylinder import generate_cylinder
from prefabs_src.cone import generate_cone
from prefabs_src.bolt import generate_bolt
from prefabs_src.pipe import generate_pipe
from anim_helpers import (
    animate_rotation, animate_translation, animate_shake, animate_static,
    FPS,
)


# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
C = load_palette("buildings")

STEEL      = "#7A8898"
STEEL_DK   = "#6A7888"
STEEL_LT   = "#96A4B4"
BODY_MAIN  = "#5A4838"
BODY_LIGHT = "#6E5A48"
BODY_ROOF  = "#7A6854"
CABLE      = "#2A2A2A"

# Debug accents
SOURCE_GREEN    = C["active_green"]   # #4CAF50
SOURCE_GREEN_LT = "#6ECF72"
SOURCE_GREEN_DK = "#2E7D32"
SINK_RED        = C["warning_red"]    # #D32F2F
SINK_RED_LT     = "#EF5350"
SINK_RED_DK     = "#8B1A1A"
CHAMBER_DARK    = C["chamber_deep"]   # #0F0A08
GRATE_COLOR     = C["grate"]          # #372319


# ---------------------------------------------------------------------------
# Export helpers
# ---------------------------------------------------------------------------
def export_glb(output_path):
    """Select all and export as .glb with NLA animations."""
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_animation_mode='NLA_TRACKS',
        export_merge_animation='NLA_TRACK',
        export_animations=True,
    )


def export_blend(output_path):
    """Save the current scene as a .blend file."""
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=output_path)


# ===========================================================================
# SOURCE BUILDING
# ===========================================================================
def build_source():
    """Build the Source debug building -- spawns items upward."""
    clear_scene()

    root = bpy.data.objects.new("Source", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.5
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # -- BASE PLATFORM --
    base = add(generate_box(w=1.8, d=1.8, h=0.1, hex_color=STEEL_DK))
    base.name = "BasePlatform"

    # Corner feet
    for i, (fx, fy) in enumerate([(-0.7, -0.7), (0.7, -0.7), (0.7, 0.7), (-0.7, 0.7)]):
        foot = add(generate_cylinder(radius=0.09, height=0.06, segments=8,
                                     hex_color=STEEL_DK))
        foot.name = f"Foot_{i}"
        foot.location = (fx, fy, -0.06)

    # -- MAIN BODY --
    body = add(generate_box(w=1.6, d=1.6, h=0.6, hex_color=BODY_MAIN, seam_count=1))
    body.name = "Body"
    body.location = (0, 0, 0.1)

    # Reinforcement band around body
    band = add(generate_box(w=1.65, d=1.65, h=0.08, hex_color=STEEL_DK))
    band.name = "Band"
    band.location = (0, 0, 0.35)

    # Green accent stripe near top of body
    stripe = add(generate_box(w=1.62, d=1.62, h=0.04, hex_color=SOURCE_GREEN))
    stripe.name = "GreenStripe"
    stripe.location = (0, 0, 0.62)

    # -- ROOF PLATFORM --
    roof = add(generate_box(w=1.7, d=1.7, h=0.08, hex_color=BODY_ROOF))
    roof.name = "Roof"
    roof.location = (0, 0, 0.7)

    # -- CENTRAL APERTURE (open top cylinder for items to emerge from) --
    aperture_ring = add(generate_cylinder(radius=0.5, height=0.12, segments=12,
                                          hex_color=STEEL))
    aperture_ring.name = "ApertureRing"
    aperture_ring.location = (0, 0, 0.76)

    # Dark chamber inside (smaller cylinder)
    chamber = add(generate_cylinder(radius=0.38, height=0.06, segments=12,
                                    hex_color=CHAMBER_DARK))
    chamber.name = "Chamber"
    chamber.location = (0, 0, 0.78)

    # -- UPWARD ARROW -- the signature silhouette element
    # Central column (post) rising from the body
    post = add(generate_cylinder(radius=0.15, height=0.8, segments=8,
                                 hex_color=SOURCE_GREEN))
    post.name = "ArrowPost"
    post.location = (0, 0, 0.85)

    # Arrow cone pointing up
    arrow_cone = add(generate_cone(radius_bottom=0.35, radius_top=0.0, height=0.4,
                                   segments=8, hex_color=SOURCE_GREEN_LT))
    arrow_cone.name = "ArrowCone"
    arrow_cone.location = (0, 0, 1.65)

    # Arrow base disc (where cone meets post)
    arrow_base = add(generate_cylinder(radius=0.35, height=0.06, segments=8,
                                       hex_color=SOURCE_GREEN_DK))
    arrow_base.name = "ArrowBase"
    arrow_base.location = (0, 0, 1.60)

    # -- SIDE DETAILS --
    # Small exhaust pipe on back-left
    exhaust = add(generate_pipe(length=0.4, radius=0.06, wall_thickness=0.015,
                                hex_color=C["pipe"]))
    exhaust.name = "Exhaust"
    exhaust.location = (-0.6, 0.65, 0.3)

    # Control panel on front face
    panel = add(generate_box(w=0.35, d=0.06, h=0.25, hex_color=BODY_LIGHT))
    panel.name = "ControlPanel"
    panel.location = (0.3, -0.82, 0.35)

    # Status light on panel (green)
    light = add(generate_cylinder(radius=0.04, height=0.02, segments=6,
                                  hex_color=SOURCE_GREEN_LT))
    light.name = "StatusLight"
    light.rotation_euler = (math.radians(90), 0, 0)
    light.location = (0.3, -0.86, 0.5)

    # -- BOLTS --
    bolt_positions = [
        # Roof corners
        (0.7, 0.7, 0.82), (-0.7, 0.7, 0.82), (0.7, -0.7, 0.82), (-0.7, -0.7, 0.82),
        # Band bolts
        (0.83, 0.5, 0.45), (0.83, -0.5, 0.45), (-0.83, 0.5, 0.45), (-0.83, -0.5, 0.45),
        (0.5, 0.83, 0.45), (-0.5, 0.83, 0.45), (0.5, -0.83, 0.45), (-0.5, -0.83, 0.45),
    ]
    for i, (bx, by, bz) in enumerate(bolt_positions):
        b = add(generate_bolt(head_radius=0.04, head_height=0.025, hex_color=C["rivet"]))
        b.name = f"Bolt_{i}"
        b.location = (bx, by, bz)

    return {
        "root": root,
        "body": body,
        "band": band,
        "arrow_cone": arrow_cone,
        "arrow_post": post,
        "arrow_base": arrow_base,
    }


def bake_source_animations(objects):
    """Bake Source animations: idle wobble, active pulse."""
    cone = objects["arrow_cone"]
    post = objects["arrow_post"]
    base = objects["arrow_base"]
    body = objects["body"]
    band = objects["band"]

    cone_z = cone.location.z
    post_z = post.location.z
    base_z = base.location.z

    # -- idle (2 sec): gentle up/down bob of arrow --
    animate_translation(cone, "idle", duration=2.0, axis='Z',
                        value_fn=lambda t: cone_z + 0.03 * math.sin(t * math.pi * 2))
    animate_translation(post, "idle", duration=2.0, axis='Z',
                        value_fn=lambda t: post_z + 0.03 * math.sin(t * math.pi * 2))
    animate_translation(base, "idle", duration=2.0, axis='Z',
                        value_fn=lambda t: base_z + 0.03 * math.sin(t * math.pi * 2))
    animate_static(body, "idle", duration=2.0)
    animate_static(band, "idle", duration=2.0)

    # -- active (2 sec): faster pulsing bob + body shake --
    animate_translation(cone, "active", duration=2.0, axis='Z',
                        value_fn=lambda t: cone_z + 0.08 * abs(math.sin(t * math.pi * 6)))
    animate_translation(post, "active", duration=2.0, axis='Z',
                        value_fn=lambda t: post_z + 0.08 * abs(math.sin(t * math.pi * 6)))
    animate_translation(base, "active", duration=2.0, axis='Z',
                        value_fn=lambda t: base_z + 0.08 * abs(math.sin(t * math.pi * 6)))
    animate_shake(body, "active", duration=2.0, amplitude=0.01, frequency=6)
    animate_shake(band, "active", duration=2.0, amplitude=0.01, frequency=6)


# ===========================================================================
# SINK BUILDING
# ===========================================================================
def build_sink():
    """Build the Sink debug building -- consumes items downward."""
    clear_scene()

    root = bpy.data.objects.new("Sink", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.5
    bpy.context.scene.collection.objects.link(root)

    def add(obj):
        obj.parent = root
        return obj

    # -- BASE PLATFORM --
    base = add(generate_box(w=1.8, d=1.8, h=0.1, hex_color=STEEL_DK))
    base.name = "BasePlatform"

    # Corner feet
    for i, (fx, fy) in enumerate([(-0.7, -0.7), (0.7, -0.7), (0.7, 0.7), (-0.7, 0.7)]):
        foot = add(generate_cylinder(radius=0.09, height=0.06, segments=8,
                                     hex_color=STEEL_DK))
        foot.name = f"Foot_{i}"
        foot.location = (fx, fy, -0.06)

    # -- MAIN BODY (taller than source, more "pit" feel) --
    body = add(generate_box(w=1.6, d=1.6, h=0.7, hex_color=BODY_MAIN, seam_count=1))
    body.name = "Body"
    body.location = (0, 0, 0.1)

    # Reinforcement band
    band = add(generate_box(w=1.65, d=1.65, h=0.08, hex_color=STEEL_DK))
    band.name = "Band"
    band.location = (0, 0, 0.4)

    # Red warning stripe
    stripe = add(generate_box(w=1.62, d=1.62, h=0.04, hex_color=SINK_RED))
    stripe.name = "RedStripe"
    stripe.location = (0, 0, 0.72)

    # -- HOPPER RIM (wider funnel opening at top) --
    hopper_rim = add(generate_cylinder(radius=0.85, height=0.1, segments=12,
                                       hex_color=STEEL))
    hopper_rim.name = "HopperRim"
    hopper_rim.location = (0, 0, 0.8)

    # Inner hopper ring (slightly smaller, darker)
    hopper_inner = add(generate_cylinder(radius=0.72, height=0.06, segments=12,
                                         hex_color=STEEL_DK))
    hopper_inner.name = "HopperInner"
    hopper_inner.location = (0, 0, 0.82)

    # -- FUNNEL (downward-pointing cone = inverted frustum inside) --
    # This is the signature visual: an inverted cone suggesting items fall in.
    # We create it as a cone pointing DOWN (rotated 180 degrees around X).
    funnel = add(generate_cone(radius_bottom=0.65, radius_top=0.2, height=0.5,
                               segments=10, hex_color=SINK_RED_DK))
    funnel.name = "Funnel"
    funnel.rotation_euler = (math.radians(180), 0, 0)
    funnel.location = (0, 0, 0.82)

    # Dark void at center (the "hole" items fall into)
    void = add(generate_cylinder(radius=0.2, height=0.04, segments=10,
                                 hex_color=CHAMBER_DARK))
    void.name = "Void"
    void.location = (0, 0, 0.3)

    # -- GRATE BARS over the opening (cross pattern) --
    # Two crossing bars over the hopper opening
    for i, rot_z in enumerate([0, math.radians(90)]):
        grate_bar = add(generate_box(w=1.3, d=0.06, h=0.04, hex_color=GRATE_COLOR))
        grate_bar.name = f"GrateBar_{i}"
        grate_bar.location = (0, 0, 0.9)
        grate_bar.rotation_euler = (0, 0, rot_z)

    # Diagonal bars
    for i, rot_z in enumerate([math.radians(45), math.radians(-45)]):
        grate_diag = add(generate_box(w=1.1, d=0.04, h=0.03, hex_color=GRATE_COLOR))
        grate_diag.name = f"GrateDiag_{i}"
        grate_diag.location = (0, 0, 0.88)
        grate_diag.rotation_euler = (0, 0, rot_z)

    # -- SIDE DETAILS --
    # Warning pipe on side (suggests drainage)
    drain = add(generate_pipe(length=0.35, radius=0.07, wall_thickness=0.015,
                              hex_color=C["pipe"]))
    drain.name = "DrainPipe"
    drain.rotation_euler = (0, math.radians(90), 0)
    drain.location = (0.9, 0.3, 0.3)

    # Control panel on front face
    panel = add(generate_box(w=0.35, d=0.06, h=0.25, hex_color=BODY_LIGHT))
    panel.name = "ControlPanel"
    panel.location = (-0.3, -0.82, 0.35)

    # Warning light on panel (red)
    light = add(generate_cylinder(radius=0.04, height=0.02, segments=6,
                                  hex_color=SINK_RED_LT))
    light.name = "WarningLight"
    light.rotation_euler = (math.radians(90), 0, 0)
    light.location = (-0.3, -0.86, 0.5)

    # -- CORNER POSTS (visual weight at corners, shorter than source arrow) --
    for i, (px, py) in enumerate([(-0.7, -0.7), (0.7, -0.7), (0.7, 0.7), (-0.7, 0.7)]):
        corner = add(generate_cylinder(radius=0.06, height=0.2, segments=6,
                                       hex_color=SINK_RED_DK))
        corner.name = f"CornerPost_{i}"
        corner.location = (px, py, 0.8)

        cap = add(generate_cylinder(radius=0.08, height=0.03, segments=6,
                                    hex_color=SINK_RED))
        cap.name = f"CornerCap_{i}"
        cap.location = (px, py, 1.0)

    # -- BOLTS --
    bolt_positions = [
        # Rim edge bolts
        (0.6, 0.6, 0.92), (-0.6, 0.6, 0.92), (0.6, -0.6, 0.92), (-0.6, -0.6, 0.92),
        # Band bolts
        (0.83, 0.5, 0.5), (0.83, -0.5, 0.5), (-0.83, 0.5, 0.5), (-0.83, -0.5, 0.5),
        (0.5, 0.83, 0.5), (-0.5, 0.83, 0.5), (0.5, -0.83, 0.5), (-0.5, -0.83, 0.5),
    ]
    for i, (bx, by, bz) in enumerate(bolt_positions):
        b = add(generate_bolt(head_radius=0.04, head_height=0.025, hex_color=C["rivet"]))
        b.name = f"Bolt_{i}"
        b.location = (bx, by, bz)

    return {
        "root": root,
        "body": body,
        "band": band,
        "funnel": funnel,
        "hopper_rim": hopper_rim,
    }


def bake_sink_animations(objects):
    """Bake Sink animations: idle hum, active consuming."""
    body = objects["body"]
    band = objects["band"]
    funnel = objects["funnel"]
    rim = objects["hopper_rim"]

    # -- idle (2 sec): subtle vibration --
    animate_shake(body, "idle", duration=2.0, amplitude=0.005, frequency=3)
    animate_shake(band, "idle", duration=2.0, amplitude=0.005, frequency=3)
    animate_static(funnel, "idle", duration=2.0)
    animate_static(rim, "idle", duration=2.0)

    # -- active (2 sec): stronger shake + funnel spin --
    animate_shake(body, "active", duration=2.0, amplitude=0.015, frequency=8)
    animate_shake(band, "active", duration=2.0, amplitude=0.015, frequency=8)
    animate_rotation(funnel, "active", duration=2.0, axis='Z',
                     total_angle=math.pi * 4)
    animate_shake(rim, "active", duration=2.0, amplitude=0.008, frequency=6)


# ===========================================================================
# Texture application
# ===========================================================================
def apply_source_textures():
    """Apply PBR textures to all Source objects that should have them."""
    for obj in bpy.data.objects:
        name = obj.name
        if name == "BasePlatform":
            apply_texture(obj, "metal_plate_02", resolution="1k")
        elif name == "Body":
            apply_texture(obj, "painted_metal_shutter", resolution="1k")
        elif name in ("Band", "HopperRim", "HopperInner"):
            apply_texture(obj, "metal_plate", resolution="1k")
        elif name == "Roof":
            apply_texture(obj, "metal_plate_02", resolution="1k")
        elif name == "ApertureRing":
            apply_texture(obj, "metal_plate", resolution="1k")
        elif name == "ControlPanel":
            apply_texture(obj, "painted_metal_shutter", resolution="1k")
        elif name == "Exhaust":
            apply_texture(obj, "rusty_metal_02", resolution="1k")


def apply_sink_textures():
    """Apply PBR textures to all Sink objects that should have them."""
    for obj in bpy.data.objects:
        name = obj.name
        if name == "BasePlatform":
            apply_texture(obj, "metal_plate_02", resolution="1k")
        elif name == "Body":
            apply_texture(obj, "painted_metal_shutter", resolution="1k")
        elif name in ("Band",):
            apply_texture(obj, "metal_plate", resolution="1k")
        elif name in ("HopperRim", "HopperInner"):
            apply_texture(obj, "metal_plate", resolution="1k")
        elif name == "ControlPanel":
            apply_texture(obj, "painted_metal_shutter", resolution="1k")
        elif name == "DrainPipe":
            apply_texture(obj, "rusty_metal_02", resolution="1k")


# ===========================================================================
# Main
# ===========================================================================
def main():
    # ── SOURCE ────────────────────────────────────────────────────────
    source_dir = os.path.join(REPO_ROOT, "buildings", "source", "models")

    print("[debug_buildings] Building Source...")
    objects = build_source()
    bake_source_animations(objects)

    # Export flat version first
    flat_glb = os.path.join(source_dir, "source_flat.glb")
    export_glb(flat_glb)
    flat_blend = os.path.join(source_dir, "source_flat.blend")
    export_blend(flat_blend)
    print(f"[debug_buildings] Source flat: {flat_glb}")

    # Apply textures and export textured version
    apply_source_textures()
    tex_glb = os.path.join(source_dir, "source.glb")
    export_glb(tex_glb)
    tex_blend = os.path.join(source_dir, "source.blend")
    export_blend(tex_blend)
    print(f"[debug_buildings] Source textured: {tex_glb}")

    # ── SINK ──────────────────────────────────────────────────────────
    sink_dir = os.path.join(REPO_ROOT, "buildings", "sink", "models")

    print("[debug_buildings] Building Sink...")
    objects = build_sink()
    bake_sink_animations(objects)

    # Export flat version first
    flat_glb = os.path.join(sink_dir, "sink_flat.glb")
    export_glb(flat_glb)
    flat_blend = os.path.join(sink_dir, "sink_flat.blend")
    export_blend(flat_blend)
    print(f"[debug_buildings] Sink flat: {flat_glb}")

    # Apply textures and export textured version
    apply_sink_textures()
    tex_glb = os.path.join(sink_dir, "sink.glb")
    export_glb(tex_glb)
    tex_blend = os.path.join(sink_dir, "sink.blend")
    export_blend(tex_blend)
    print(f"[debug_buildings] Sink textured: {tex_glb}")

    print("[debug_buildings] Done!")


if __name__ == "__main__":
    main()
