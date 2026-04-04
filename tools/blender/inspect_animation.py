"""Render animation preview frames from a .glb model.

Imports a .glb, sets up an isometric camera, and renders 4 evenly-spaced
frames for each animation. Output goes to a preview/ directory next to
the .glb.

Usage:
    BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"

    # Preview all animations in a model
    $BLENDER --background --python tools/blender/preview.py -- buildings/drill/models/drill.glb

    # Custom resolution
    $BLENDER --background --python tools/blender/preview.py -- buildings/drill/models/drill.glb --size 256

    # Custom frame count per animation
    $BLENDER --background --python tools/blender/preview.py -- buildings/drill/models/drill.glb --frames 8
"""

import bpy
import os
import sys
from math import radians


def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []

    if not argv:
        print("Usage: blender --background --python preview.py -- <model.glb> [--size N] [--frames N]")
        sys.exit(1)

    glb_path = argv[0]
    size = 256
    frames_per_anim = 4

    i = 1
    while i < len(argv):
        if argv[i] == "--size" and i + 1 < len(argv):
            size = int(argv[i + 1]); i += 2
        elif argv[i] == "--frames" and i + 1 < len(argv):
            frames_per_anim = int(argv[i + 1]); i += 2
        else:
            i += 1

    return glb_path, size, frames_per_anim


def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for block in [bpy.data.meshes, bpy.data.materials, bpy.data.cameras,
                  bpy.data.lights, bpy.data.actions, bpy.data.images]:
        for item in block:
            block.remove(item)


def setup_camera(size):
    """Isometric orthographic camera matching the game's view angle."""
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = 'ORTHO'

    cam_obj = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.scene.collection.objects.link(cam_obj)
    cam_obj.rotation_euler = (radians(54.736), 0, radians(45))
    cam_obj.location = (15, -15, 15)

    bpy.context.scene.camera = cam_obj
    return cam_obj, cam_data


def setup_lighting():
    """Key light + fill for readable previews."""
    # Key light — strong enough for dark PBR textures
    key_data = bpy.data.lights.new("KeyLight", type='SUN')
    key_data.energy = 3.0
    key_obj = bpy.data.objects.new("KeyLight", key_data)
    bpy.context.scene.collection.objects.link(key_obj)
    key_obj.rotation_euler = (radians(50), radians(-30), radians(-20))

    # Fill light (opposite side)
    fill_data = bpy.data.lights.new("FillLight", type='SUN')
    fill_data.energy = 1.5
    fill_obj = bpy.data.objects.new("FillLight", fill_data)
    bpy.context.scene.collection.objects.link(fill_obj)
    fill_obj.rotation_euler = (radians(40), radians(30), radians(160))


def setup_render(size):
    """EEVEE render settings for preview."""
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'
    scene.render.filter_size = 0.5  # slight AA for preview readability
    scene.eevee.taa_render_samples = 4

    # Standard color management
    scene.display_settings.display_device = 'sRGB'
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'


def fit_camera_to_scene(cam_obj, cam_data):
    """Auto-fit ortho_scale so the model fills the frame with padding."""
    # Compute bounding box of all mesh objects
    min_co = [float('inf')] * 3
    max_co = [float('-inf')] * 3

    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        for corner in obj.bound_box:
            world_co = obj.matrix_world @ bpy.mathutils.Vector(corner) if hasattr(bpy, 'mathutils') else None
            if world_co is None:
                from mathutils import Vector
                world_co = obj.matrix_world @ Vector(corner)
            for i in range(3):
                min_co[i] = min(min_co[i], world_co[i])
                max_co[i] = max(max_co[i], world_co[i])

    if min_co[0] == float('inf'):
        cam_data.ortho_scale = 5.0
        return

    # Compute scene size and set ortho scale with padding
    scene_size = max(max_co[i] - min_co[i] for i in range(3))
    cam_data.ortho_scale = scene_size * 1.4  # 40% padding

    # Center camera target on bounding box center
    center = [(min_co[i] + max_co[i]) / 2 for i in range(3)]
    # Move camera so it looks at the center
    from mathutils import Vector
    view_dir = Vector(cam_obj.location).normalized()
    cam_obj.location = Vector(center) + view_dir * 20


def collect_animations():
    """Find all animations and their frame ranges from the imported scene.

    Returns:
        List of (name, frame_start, frame_end) tuples.
    """
    anims = []
    for action in bpy.data.actions:
        start, end = action.frame_range
        anims.append((action.name, int(start), int(end)))
    return anims


def assign_animation(action_name):
    """Assign an animation to all objects that have tracks for it."""
    action = bpy.data.actions.get(action_name)
    if not action:
        return

    for obj in bpy.context.scene.objects:
        if obj.animation_data is None:
            continue
        # Check NLA tracks for this animation name
        for track in obj.animation_data.nla_tracks:
            for strip in track.strips:
                if strip.action and strip.action.name == action_name:
                    # Mute all tracks, unmute this one
                    for t in obj.animation_data.nla_tracks:
                        t.mute = True
                    track.mute = False
                    return


def render_animation_previews(glb_path, size, frames_per_anim):
    """Main entry point: import .glb and render preview frames."""
    clear_scene()

    # Import the model
    if not os.path.isabs(glb_path):
        glb_path = os.path.abspath(glb_path)

    print(f"[preview] Importing {glb_path}")
    bpy.ops.import_scene.gltf(filepath=glb_path)

    # Setup rendering
    cam_obj, cam_data = setup_camera(size)
    setup_lighting()
    setup_render(size)
    fit_camera_to_scene(cam_obj, cam_data)

    # Output directory: next to the .glb in a preview/ folder
    model_dir = os.path.dirname(glb_path)
    preview_dir = os.path.join(model_dir, "preview")
    os.makedirs(preview_dir, exist_ok=True)

    # Collect animations
    anims = collect_animations()
    if not anims:
        # No animations — just render a single static frame
        print("[preview] No animations found, rendering static frame")
        bpy.context.scene.render.filepath = os.path.join(preview_dir, "static")
        bpy.ops.render.render(write_still=True)
        print(f"[preview] Saved: preview/static.png")
        return

    print(f"[preview] Found {len(anims)} animations: {[a[0] for a in anims]}")

    # For each animation, render evenly-spaced frames
    for anim_name, frame_start, frame_end in anims:
        print(f"[preview] Rendering '{anim_name}' ({frame_start}-{frame_end})")

        # Enable this animation on all objects via NLA
        for obj in bpy.context.scene.objects:
            if obj.animation_data is None:
                continue
            for track in obj.animation_data.nla_tracks:
                # Unmute tracks matching this animation, mute others
                track.mute = (track.name != anim_name)

        duration = frame_end - frame_start
        for fi in range(frames_per_anim):
            if frames_per_anim > 1:
                t = fi / (frames_per_anim - 1)
            else:
                t = 0
            frame = int(frame_start + t * duration)
            bpy.context.scene.frame_set(frame)

            filename = f"{anim_name}_{fi}"
            filepath = os.path.join(preview_dir, filename)
            bpy.context.scene.render.filepath = filepath
            bpy.ops.render.render(write_still=True)

    # Summary
    total = len(anims) * frames_per_anim
    print(f"[preview] Done. {total} frames rendered to {preview_dir}/")


if __name__ == "__main__":
    glb_path, size, frames_per_anim = parse_args()
    render_animation_previews(glb_path, size, frames_per_anim)
