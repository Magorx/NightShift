"""Core rendering pipeline for isometric building sprites.

Provides scene setup (camera, lights, render settings) and frame rendering.
All resolution is configurable — nothing is hardcoded to a specific size.

Usage from a scene script:
    from render import setup_scene, render_frames
    setup_scene(width=64, height=72)
    # ... build your scene ...
    render_frames(output_dir="buildings/blender-drill/sprites/frames", tags={...})
"""

import bpy
import os
from math import radians

# Repo root — two levels up from tools/blender/
REPO_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))


def clear_scene():
    """Remove all objects, meshes, materials, and actions from the scene."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for block in [bpy.data.meshes, bpy.data.materials, bpy.data.cameras,
                  bpy.data.lights, bpy.data.actions]:
        for item in block:
            block.remove(item)
    # Clear material cache so stale references don't persist
    from materials.pixel_art import clear_material_cache
    clear_material_cache()


def setup_camera(width, height, ortho_scale=4.0):
    """Create an orthographic isometric camera.

    Args:
        width: Render width in pixels.
        height: Render height in pixels.
        ortho_scale: Orthographic scale (controls how much world space is visible).

    Returns:
        The camera object.
    """
    cam_data = bpy.data.cameras.new("IsoCam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = ortho_scale

    cam_obj = bpy.data.objects.new("IsoCam", cam_data)
    bpy.context.scene.collection.objects.link(cam_obj)

    # Standard isometric: X=54.736° (arctan(sqrt(2))), Z=45°
    cam_obj.rotation_euler = (radians(54.736), 0, radians(45))
    # Place far enough away along the isometric viewing axis
    cam_obj.location = (15, -15, 15)

    bpy.context.scene.camera = cam_obj
    return cam_obj


def setup_lighting():
    """Create a single directional light (upper-left) matching the Iso library convention.

    Returns:
        The light object.
    """
    light_data = bpy.data.lights.new("DirLight", type='SUN')
    light_data.energy = 1.0

    light_obj = bpy.data.objects.new("DirLight", light_data)
    bpy.context.scene.collection.objects.link(light_obj)

    # Upper-left direction matching the existing sprite convention
    light_obj.rotation_euler = (radians(50), radians(-30), radians(-20))
    return light_obj


def setup_render(width, height):
    """Configure EEVEE render settings for pixel-perfect output.

    Args:
        width: Render width in pixels.
        height: Render height in pixels.
    """
    scene = bpy.context.scene

    scene.render.engine = 'BLENDER_EEVEE'

    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100

    # Transparent background (RGBA)
    scene.render.film_transparent = True

    # PNG with alpha
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'

    # Kill anti-aliasing: no filter, single sample
    scene.render.filter_size = 0.0
    scene.eevee.taa_render_samples = 1
    scene.eevee.taa_samples = 1

    # Color management — standard, no filmic curve mangling our palette colors
    scene.display_settings.display_device = 'sRGB'
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'


def setup_scene(width=64, height=72, ortho_scale=4.0):
    """Full scene setup: clear, camera, lighting, render settings.

    Args:
        width: Canvas width in pixels.
        height: Canvas height in pixels.
        ortho_scale: Orthographic camera scale.

    Returns:
        The camera object.
    """
    clear_scene()
    cam = setup_camera(width, height, ortho_scale)
    setup_lighting()
    setup_render(width, height)
    return cam


def set_object_visibility(obj, visible):
    """Show or hide an object for rendering."""
    obj.hide_render = not visible
    obj.hide_viewport = not visible


def render_single_frame(output_path):
    """Render the current frame to a PNG file.

    Args:
        output_path: Full path for the output PNG (without extension — Blender adds it).
    """
    scene = bpy.context.scene
    scene.render.filepath = output_path
    bpy.ops.render.render(write_still=True)


def render_frames(output_dir, tags, layers=None, frame_callback=None):
    """Render all frames for all tags and layers.

    Args:
        output_dir: Directory for output PNGs.
        tags: Dict of tag_name -> {"frames": int} defining animation segments.
            Example: {"idle": {"frames": 1}, "active": {"frames": 4}}
        layers: Optional list of layer names (e.g. ["base", "top"]).
            If provided, frame_callback must handle visibility toggling.
            If None, renders a single pass per frame.
        frame_callback: Optional callable(tag_name, frame_index, layer_name)
            called before each render to set up animation state and visibility.
            frame_index is 0-based within the tag.
    """
    os.makedirs(output_dir, exist_ok=True)
    scene = bpy.context.scene

    if layers is None:
        layers = [None]

    global_frame = 1
    for tag_name, tag_info in tags.items():
        num_frames = tag_info["frames"]
        for fi in range(num_frames):
            scene.frame_set(global_frame)

            for layer in layers:
                if frame_callback:
                    frame_callback(tag_name, fi, layer)

                if layer is not None:
                    filename = f"{layer}_{tag_name}_{fi}"
                else:
                    filename = f"{tag_name}_{fi}"

                filepath = os.path.join(output_dir, filename)
                render_single_frame(filepath)

            global_frame += 1


def link_prefab(blend_path, object_name=None):
    """Append an object from a .blend prefab file into the current scene.

    Args:
        blend_path: Path to the .blend file (relative to REPO_ROOT or absolute).
        object_name: Name of the object to append. If None, appends the first
            non-camera, non-light object found.

    Returns:
        The appended Blender object.
    """
    if not os.path.isabs(blend_path):
        blend_path = os.path.join(REPO_ROOT, blend_path)

    with bpy.data.libraries.load(blend_path) as (data_from, data_to):
        if object_name:
            data_to.objects = [object_name]
        else:
            data_to.objects = data_from.objects

    obj = None
    for o in data_to.objects:
        if o is not None:
            bpy.context.scene.collection.objects.link(o)
            if obj is None and o.type == 'MESH':
                obj = o

    return obj
