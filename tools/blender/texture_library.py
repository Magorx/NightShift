"""PBR texture library — search, download, cache, and apply.

Downloads CC0 PBR texture sets from Poly Haven (polyhaven.com).
Textures are cached locally so they're only downloaded once.

Usage:
    from texture_library import search_textures, apply_texture

    # Search for textures
    results = search_textures("rusty metal")
    # -> [{"id": "rusty_metal", "name": "Rusty Metal", ...}, ...]

    # Apply a texture set to an object
    apply_texture(obj, "rusty_metal", resolution="1k")
    # Downloads albedo + normal + roughness, creates material, applies to object

    # Or apply by keyword (picks first search result)
    apply_texture_by_search(obj, "corrugated metal", resolution="1k")
"""

import bpy
import os
import json
import urllib.request
import urllib.parse

REPO_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
CACHE_DIR = os.path.join(REPO_ROOT, "tools", "blender", ".texture_cache")

POLYHAVEN_API = "https://api.polyhaven.com"
POLYHAVEN_DL = "https://dl.polyhaven.org/file/ph-assets/Textures"


# ---------------------------------------------------------------------------
# Search
# ---------------------------------------------------------------------------
def search_textures(query, limit=10):
    """Search Poly Haven for PBR textures.

    Args:
        query: Search keyword (e.g. "rust", "metal", "wood", "concrete").
        limit: Max results to return.

    Returns:
        List of dicts: [{"id": "rusty_metal", "name": "Rusty Metal",
                         "tags": [...], "downloads": 1234}, ...]
    """
    url = f"{POLYHAVEN_API}/assets?t=textures"
    data = _fetch_json(url)

    # Filter by query (API doesn't have a search param, we filter client-side)
    query_lower = query.lower()
    results = []
    for asset_id, info in data.items():
        name = info.get("name", asset_id).lower()
        tags = [t.lower() for t in info.get("tags", [])]
        categories = [c.lower() for c in info.get("categories", [])]
        searchable = f"{name} {' '.join(tags)} {' '.join(categories)}"

        if query_lower in searchable:
            results.append({
                "id": asset_id,
                "name": info.get("name", asset_id),
                "tags": info.get("tags", []),
                "categories": info.get("categories", []),
                "downloads": info.get("download_count", 0),
            })

    # Sort by download count (most popular first)
    results.sort(key=lambda x: x["downloads"], reverse=True)
    return results[:limit]


def get_texture_files(asset_id):
    """Get available map types and resolutions for a texture.

    Args:
        asset_id: Poly Haven asset ID (e.g. "rusty_metal").

    Returns:
        Dict of {map_type: {resolution: {format: url}}}
    """
    url = f"{POLYHAVEN_API}/files/{asset_id}"
    return _fetch_json(url)


# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------
def download_texture_set(asset_id, resolution="1k", maps=None):
    """Download a PBR texture set to the local cache.

    Args:
        asset_id: Poly Haven asset ID.
        resolution: "1k", "2k", or "4k".
        maps: List of map types to download. Default: ["diff", "nor_gl", "rough"].
            Available: "diff", "nor_gl", "rough", "ao", "disp", "arm".

    Returns:
        Dict of {map_type: local_file_path}.
    """
    if maps is None:
        maps = ["diff", "nor_gl", "rough"]

    cache_subdir = os.path.join(CACHE_DIR, asset_id, resolution)
    os.makedirs(cache_subdir, exist_ok=True)

    # Get file info from API to find exact URLs
    files_data = get_texture_files(asset_id)

    # Map short names to Poly Haven map type keys
    map_key_aliases = {
        "diff": ["Diffuse", "diffuse", "diff"],
        "nor_gl": ["nor_gl", "NormalGL"],
        "nor_dx": ["nor_dx", "NormalDX"],
        "rough": ["Rough", "rough", "roughness"],
        "ao": ["AO", "ao"],
        "disp": ["Displacement", "displacement", "disp"],
        "arm": ["arm", "ARM"],
        "metal": ["Metalness", "metalness", "metal"],
    }

    downloaded = {}
    for map_short in maps:
        # Find the right key in the API response
        api_key = None
        for alias in map_key_aliases.get(map_short, [map_short]):
            if alias in files_data:
                api_key = alias
                break

        if api_key is None:
            print(f"[texture] Warning: map '{map_short}' not found for {asset_id}")
            continue

        # Get URL for requested resolution in jpg format
        res_data = files_data[api_key]
        if resolution not in res_data:
            # Fall back to available resolution
            available = list(res_data.keys())
            resolution_use = available[0] if available else None
            if not resolution_use:
                continue
            print(f"[texture] Resolution '{resolution}' not available for {map_short}, using '{resolution_use}'")
        else:
            resolution_use = resolution

        fmt_data = res_data[resolution_use]
        # Prefer jpg, fallback to png
        url = None
        for fmt in ["jpg", "png"]:
            if fmt in fmt_data:
                url = fmt_data[fmt].get("url")
                ext = fmt
                break

        if not url:
            continue

        # Download if not cached
        filename = f"{asset_id}_{map_short}_{resolution_use}.{ext}"
        local_path = os.path.join(cache_subdir, filename)

        if not os.path.exists(local_path):
            print(f"[texture] Downloading {filename}...")
            urllib.request.urlretrieve(url, local_path)
        else:
            print(f"[texture] Cached: {filename}")

        downloaded[map_short] = local_path

    return downloaded


# ---------------------------------------------------------------------------
# Apply to Blender object
# ---------------------------------------------------------------------------
def apply_texture(obj, asset_id, resolution="1k", maps=None,
                  max_size=256, tile_scale=1.0):
    """Download and apply a PBR texture set to a Blender object.

    Creates a Principled BSDF material with image textures plugged
    into Base Color, Normal, and Roughness. These export directly
    via glTF — no baking needed.

    Textures are downscaled to max_size to keep .glb files small
    (pixel-art game doesn't need high-res textures).

    A Mapping node auto-scales UVs based on object dimensions so
    textures tile proportionally instead of stretching.

    Args:
        obj: Blender mesh object.
        asset_id: Poly Haven asset ID (e.g. "rusty_metal").
        resolution: Source resolution from Poly Haven ("1k", "2k", "4k").
        maps: Map types to download/apply.
        max_size: Downscale textures to this size (pixels). None = keep original.
        tile_scale: Texture tiling multiplier. Higher = smaller tiles, more repetition.

    Returns:
        The created material.
    """
    if maps is None:
        maps = ["diff", "nor_gl", "rough"]

    # Ensure UV unwrap
    _ensure_uv(obj)

    # Download textures
    paths = download_texture_set(asset_id, resolution, maps)

    # Create material
    mat_name = f"PH_{asset_id}"
    mat = bpy.data.materials.new(mat_name)
    mat.use_nodes = True
    mat.use_backface_culling = False
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    bsdf = nodes.get("Principled BSDF")

    # -- UV scaling: Texture Coordinate → Mapping → all tex nodes --
    # This prevents stretching by tiling based on object dimensions
    tex_coord = nodes.new("ShaderNodeTexCoord")
    tex_coord.location = (-900, 0)

    mapping = nodes.new("ShaderNodeMapping")
    mapping.location = (-700, 0)
    links.new(tex_coord.outputs["UV"], mapping.inputs["Vector"])

    # Scale UVs proportionally to object bounding box
    bbox = obj.bound_box
    dims = obj.dimensions
    # Use the largest dimension as reference for uniform tiling
    max_dim = max(dims.x, dims.y, dims.z, 0.1)
    scale = tile_scale * max_dim
    mapping.inputs["Scale"].default_value = (scale, scale, scale)

    x_pos = -400

    def _load_image(path, colorspace="sRGB"):
        """Load, downscale, and pack an image."""
        img = bpy.data.images.load(path)
        if colorspace != "sRGB":
            img.colorspace_settings.name = colorspace
        if max_size and (img.size[0] > max_size or img.size[1] > max_size):
            img.scale(max_size, max_size)
        img.pack()
        return img

    def _add_tex_node(path, colorspace, location_y):
        """Create an image texture node connected to the mapping node."""
        img = _load_image(path, colorspace)
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.location = (x_pos, location_y)
        links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
        return tex

    # Albedo / Diffuse
    if "diff" in paths:
        tex = _add_tex_node(paths["diff"], "sRGB", 300)
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

    # Normal map
    if "nor_gl" in paths:
        tex = _add_tex_node(paths["nor_gl"], "Non-Color", 0)
        norm = nodes.new("ShaderNodeNormalMap")
        norm.location = (x_pos + 300, 0)
        links.new(tex.outputs["Color"], norm.inputs["Color"])
        links.new(norm.outputs["Normal"], bsdf.inputs["Normal"])

    # Roughness
    if "rough" in paths:
        tex = _add_tex_node(paths["rough"], "Non-Color", -300)
        links.new(tex.outputs["Color"], bsdf.inputs["Roughness"])

    # AO (multiply with albedo)
    if "ao" in paths and "diff" in paths:
        tex = _add_tex_node(paths["ao"], "Non-Color", 150)
        mix = nodes.new("ShaderNodeMixRGB")
        mix.blend_type = "MULTIPLY"
        mix.inputs["Fac"].default_value = 1.0
        mix.location = (x_pos + 200, 300)
        for link in list(links):
            if link.to_socket == bsdf.inputs["Base Color"]:
                albedo_output = link.from_socket
                links.remove(link)
                links.new(albedo_output, mix.inputs["Color1"])
                break
        links.new(tex.outputs["Color"], mix.inputs["Color2"])
        links.new(mix.outputs["Color"], bsdf.inputs["Base Color"])

    # Apply to object
    obj.data.materials.clear()
    obj.data.materials.append(mat)

    return mat


def apply_texture_by_search(obj, query, resolution="1k", maps=None,
                            max_size=256, tile_scale=1.0):
    """Search for a texture by keyword and apply the top result.

    Args:
        obj: Blender mesh object.
        query: Search keyword (e.g. "rusty metal", "wood planks").
        resolution: Texture resolution.
        maps: Map types to use.

    Returns:
        The created material, or None if no results.
    """
    results = search_textures(query, limit=1)
    if not results:
        print(f"[texture] No results for '{query}'")
        return None

    asset = results[0]
    print(f"[texture] Using: {asset['name']} ({asset['id']})")
    return apply_texture(obj, asset["id"], resolution, maps, max_size, tile_scale)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _fetch_json(url):
    """Fetch JSON from a URL."""
    req = urllib.request.Request(url, headers={"User-Agent": "NightShift-BlenderPipeline/1.0"})
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())


def _ensure_uv(obj):
    """Smart UV project if no UVs exist."""
    if obj.type != 'MESH':
        return
    if len(obj.data.uv_layers) > 0:
        return

    prev_active = bpy.context.view_layer.objects.active
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=66, margin_method='SCALED', island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.select_set(False)
    bpy.context.view_layer.objects.active = prev_active


def list_cache():
    """List all cached texture sets.

    Returns:
        List of (asset_id, resolution, maps) tuples.
    """
    cached = []
    if not os.path.exists(CACHE_DIR):
        return cached
    for asset_id in os.listdir(CACHE_DIR):
        asset_dir = os.path.join(CACHE_DIR, asset_id)
        if not os.path.isdir(asset_dir):
            continue
        for res in os.listdir(asset_dir):
            res_dir = os.path.join(asset_dir, res)
            if os.path.isdir(res_dir):
                maps = os.listdir(res_dir)
                cached.append((asset_id, res, maps))
    return cached
