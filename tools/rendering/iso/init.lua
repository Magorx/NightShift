-- init.lua — Isometric 3D Geometry Library entry point
--
-- Usage:
--   local Iso = dofile("/path/to/tools/rendering/iso/init.lua")
--   Iso._set_helper(H)  -- pass your aseprite_helper instance
--
-- All modules are loaded and wired into the single Iso table.
-- Configuration is via Iso.configure() or Iso.preset_*() functions.

-- Discover our directory from this file's path
local info = debug.getinfo(1, "S")
local dir = info.source:match("^@(.+)/[^/]+$")
if not dir then
  -- Fallback: assume standard repo location
  dir = "/Users/gorishniymax/Repos/factor/tools/rendering/iso"
end

-- Load config (returns the base Iso table)
local Iso = dofile(dir .. "/config.lua")

-- Load modules (each returns a function that extends Iso)
dofile(dir .. "/projection.lua")(Iso)
dofile(dir .. "/zbuffer.lua")(Iso)
dofile(dir .. "/shading.lua")(Iso)
dofile(dir .. "/primitives.lua")(Iso)
dofile(dir .. "/mechanical.lua")(Iso)
dofile(dir .. "/texture.lua")(Iso)
dofile(dir .. "/lighting.lua")(Iso)
dofile(dir .. "/animation.lua")(Iso)
dofile(dir .. "/scene.lua")(Iso)

-- Helper reference (set once, used by all modules via Iso._H)
function Iso._set_helper(helper)
  Iso._H = helper
end

print("[iso_geo] loaded — " .. dir)
return Iso
