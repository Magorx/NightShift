"""Inspect a .glb model by rendering screenshots from multiple camera angles.

Takes 4 screenshots: 2 from fixed isometric positions, 2 from random angles
(or user-specified via CLI). Useful for quickly assessing generated models.

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"

    # Basic — 4 screenshots saved next to the .glb
    $BLENDER --background --python tools/blender/inspect_model.py -- buildings/blender-drill/drill.glb

    # Custom output dir and resolution
    $BLENDER --background --python tools/blender/inspect_model.py -- drill.glb -o /tmp/inspect -w 1024 -h 1024

    # Override random cameras with specific angles (azimuth, elevation in degrees)
    $BLENDER --background --python tools/blender/inspect_model.py -- drill.glb --cam3 120 20 --cam4 240 10

    # Adjust zoom (lower = closer)
    $BLENDER --background --python tools/blender/inspect_model.py -- drill.glb --ortho-scale 3.0
"""

import bpy
import os
import sys
import random
from math import radians, sin, cos, pi

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BLENDER_DIR = os.path.normpath(os.path.join(SCRIPT_DIR))
sys.path.insert(0, BLENDER_DIR)

from render import clear_scene


# ---------------------------------------------------------------------------
# Camera positions
# ---------------------------------------------------------------------------
# Fixed views: standard isometric (SW corner) and opposite (NE corner)
FIXED_CAMERAS = [
    {"name": "iso_front",  "azimuth": 45,  "elevation": 54.736},
    {"name": "iso_back",   "azimuth": 225, "elevation": 54.736},
]


def camera_location_from_angles(azimuth_deg, elevation_deg, distance=20.0):
    """Convert azimuth + elevation to a world-space camera position.

    Azimuth: 0=+X, 90=+Y, measured counter-clockwise in the XY plane.
    Elevation: angle above the XY plane (0=horizon, 90=top-down).
    """
    az = radians(azimuth_deg)
    el = radians(elevation_deg)
    x = distance * cos(el) * cos(az)
    y = distance * cos(el) * sin(az)
    z = distance * sin(el)
    return (x, y, z)


def camera_rotation_from_angles(azimuth_deg, elevation_deg):
    """Euler rotation so the camera points at the origin from (azimuth, elevation)."""
    # Blender camera looks down -Z local axis.
    # rotation_euler = (elevation_from_top, 0, azimuth + 90)
    # elevation_from_top = 90 - elevation
    rx = radians(90 - elevation_deg)
    ry = 0.0
    rz = radians(90 + azimuth_deg)
    return (rx, ry, rz)


def random_camera():
    """Generate a random but reasonable camera angle."""
    azimuth = random.uniform(0, 360)
    elevation = random.uniform(15, 65)
    return azimuth, elevation


# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []

    if not argv:
        print("Usage: blender --background --python inspect_model.py -- <model.glb> [options]")
        print("Run with --help for details.")
        sys.exit(1)

    args = {
        "model": None,
        "output_dir": None,
        "width": 512,
        "height": 512,
        "ortho_scale": None,  # auto-fit if None
        "cam3": None,  # (azimuth, elevation) or None for random
        "cam4": None,
        "seed": None,
    }

    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--help", "-h"):
            print(__doc__)
            sys.exit(0)
        elif a in ("--output-dir", "-o") and i + 1 < len(argv):
            args["output_dir"] = argv[i + 1]; i += 2
        elif a in ("--width", "-w") and i + 1 < len(argv):
            args["width"] = int(argv[i + 1]); i += 2
        elif a in ("--height", "-h") and i + 1 < len(argv):
            args["height"] = int(argv[i + 1]); i += 2
        elif a == "--ortho-scale" and i + 1 < len(argv):
            args["ortho_scale"] = float(argv[i + 1]); i += 2
        elif a == "--cam3" and i + 2 < len(argv):
            args["cam3"] = (float(argv[i + 1]), float(argv[i + 2])); i += 3
        elif a == "--cam4" and i + 2 < len(argv):
            args["cam4"] = (float(argv[i + 1]), float(argv[i + 2])); i += 3
        elif a == "--seed" and i + 1 < len(argv):
            args["seed"] = int(argv[i + 1]); i += 2
        elif args["model"] is None and not a.startswith("-"):
            args["model"] = a; i += 1
        else:
            print(f"[inspect] Unknown argument: {a}")
            i += 1

    if args["model"] is None:
        print("[inspect] Error: no .glb model path provided")
        sys.exit(1)

    return args


# ---------------------------------------------------------------------------
# Scene setup
# ---------------------------------------------------------------------------
def setup_render(width, height):
    """Configure EEVEE for inspection renders (with anti-aliasing for quality)."""
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'
    # Keep some AA for inspection quality (unlike pixel art pipeline)
    scene.render.filter_size = 1.5
    scene.eevee.taa_render_samples = 16
    scene.eevee.taa_samples = 16
    scene.display_settings.display_device = 'sRGB'
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'


def setup_lighting():
    """Three-point lighting for better inspection."""
    # Key light (sun) — strong enough to show dark PBR textures
    key = bpy.data.lights.new("KeyLight", type='SUN')
    key.energy = 3.0
    key_obj = bpy.data.objects.new("KeyLight", key)
    bpy.context.scene.collection.objects.link(key_obj)
    key_obj.rotation_euler = (radians(50), radians(-30), radians(-20))

    # Fill light (opposite side, softer)
    fill = bpy.data.lights.new("FillLight", type='SUN')
    fill.energy = 1.5
    fill_obj = bpy.data.objects.new("FillLight", fill)
    bpy.context.scene.collection.objects.link(fill_obj)
    fill_obj.rotation_euler = (radians(60), radians(20), radians(160))

    # Rim light (from behind/above)
    rim = bpy.data.lights.new("RimLight", type='SUN')
    rim.energy = 1.0
    rim_obj = bpy.data.objects.new("RimLight", rim)
    bpy.context.scene.collection.objects.link(rim_obj)
    rim_obj.rotation_euler = (radians(20), 0, radians(-90))


def import_glb(path):
    """Import a .glb file and return its bounding box center and auto ortho scale."""
    import mathutils

    abs_path = os.path.abspath(path)
    if not os.path.exists(abs_path):
        print(f"[inspect] Error: file not found: {abs_path}")
        sys.exit(1)

    bpy.ops.import_scene.gltf(filepath=abs_path)

    # Compute combined bounding box of all mesh objects
    min_co = [float('inf')] * 3
    max_co = [float('-inf')] * 3
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        for corner in obj.bound_box:
            wc = obj.matrix_world @ mathutils.Vector(corner)
            for i in range(3):
                min_co[i] = min(min_co[i], wc[i])
                max_co[i] = max(max_co[i], wc[i])

    if min_co[0] == float('inf'):
        # No mesh objects found — return defaults
        return (0, 0, 0), 4.0

    center = tuple((min_co[i] + max_co[i]) / 2.0 for i in range(3))
    dims = tuple(max_co[i] - min_co[i] for i in range(3))
    max_dim = max(dims)
    # Ortho scale: add padding so the model isn't flush against edges
    auto_ortho = max_dim * 1.4

    print(f"[inspect] Bounding box: {dims[0]:.2f} x {dims[1]:.2f} x {dims[2]:.2f}")
    print(f"[inspect] Center: ({center[0]:.2f}, {center[1]:.2f}, {center[2]:.2f})")
    print(f"[inspect] Auto ortho_scale: {auto_ortho:.2f}")

    return center, auto_ortho


def create_camera(name, azimuth, elevation, ortho_scale, target=(0, 0, 0)):
    """Create an orthographic camera aimed at target from the given angles."""
    cam_data = bpy.data.cameras.new(name)
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = ortho_scale

    cam_obj = bpy.data.objects.new(name, cam_data)
    bpy.context.scene.collection.objects.link(cam_obj)

    cam_obj.location = camera_location_from_angles(azimuth, elevation)
    cam_obj.rotation_euler = camera_rotation_from_angles(azimuth, elevation)

    # Point at target using a track-to constraint for accuracy
    constraint = cam_obj.constraints.new(type='TRACK_TO')
    empty = bpy.data.objects.get("InspectTarget")
    if empty is None:
        empty = bpy.data.objects.new("InspectTarget", None)
        empty.location = target
        bpy.context.scene.collection.objects.link(empty)
    constraint.target = empty
    constraint.track_axis = 'TRACK_NEGATIVE_Z'
    constraint.up_axis = 'UP_Y'

    return cam_obj


def render_screenshot(cam_obj, output_path):
    """Render a single frame using the given camera."""
    bpy.context.scene.camera = cam_obj
    bpy.context.scene.frame_set(1)
    bpy.context.scene.render.filepath = output_path
    bpy.ops.render.render(write_still=True)
    print(f"[inspect] Saved: {output_path}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    args = parse_args()

    if args["seed"] is not None:
        random.seed(args["seed"])

    model_path = args["model"]
    model_name = os.path.splitext(os.path.basename(model_path))[0]

    # Output directory
    if args["output_dir"]:
        out_dir = args["output_dir"]
    else:
        out_dir = os.path.join(os.path.dirname(os.path.abspath(model_path)), "inspect")
    os.makedirs(out_dir, exist_ok=True)

    print(f"[inspect] Model: {model_path}")
    print(f"[inspect] Output: {out_dir}")

    # Set up scene
    clear_scene()
    center, auto_ortho = import_glb(model_path)
    ortho_scale = args["ortho_scale"] if args["ortho_scale"] is not None else auto_ortho

    setup_render(args["width"], args["height"])
    setup_lighting()

    # Build camera list: 2 fixed + 2 random/custom
    cameras = []

    for fixed in FIXED_CAMERAS:
        cam = create_camera(
            fixed["name"], fixed["azimuth"], fixed["elevation"],
            ortho_scale, target=center,
        )
        cameras.append((fixed["name"], cam))

    # Camera 3
    if args["cam3"]:
        az, el = args["cam3"]
        name = f"custom_az{int(az)}_el{int(el)}"
    else:
        az, el = random_camera()
        name = f"random_az{int(az)}_el{int(el)}"
    cam3 = create_camera(name, az, el, ortho_scale, target=center)
    cameras.append((name, cam3))

    # Camera 4
    if args["cam4"]:
        az, el = args["cam4"]
        name = f"custom_az{int(az)}_el{int(el)}"
    else:
        az, el = random_camera()
        name = f"random_az{int(az)}_el{int(el)}"
    cam4 = create_camera(name, az, el, ortho_scale, target=center)
    cameras.append((name, cam4))

    # Render all views
    for view_name, cam_obj in cameras:
        output_path = os.path.join(out_dir, f"{model_name}_{view_name}.png")
        render_screenshot(cam_obj, output_path)

    print(f"[inspect] Done — {len(cameras)} screenshots saved to {out_dir}")


if __name__ == "__main__":
    main()
