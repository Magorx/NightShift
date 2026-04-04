-- projection.lua — 3D ↔ 2D coordinate conversion, rotation, depth
--
-- All functions read projection constants from the Iso table (set by config.lua).
-- Injected via: dofile("projection.lua")(Iso)

return function(Iso)
  local cos  = math.cos
  local sin  = math.sin
  local sqrt = math.sqrt
  local abs  = math.abs

  -- ═════════════════════════════════════════════════════════════════════
  -- PROJECTION
  -- ═════════════════════════════════════════════════════════════════════

  --- Project a 3D model point to 2D screen coordinates (fractional).
  function Iso.project(x, y, z)
    return x * Iso.XX + y * Iso.YX + z * Iso.ZX,
           x * Iso.XY + y * Iso.YY + z * Iso.ZY
  end

  --- Project and round to integer pixel coordinates.
  function Iso.project_px(x, y, z)
    local sx, sy = Iso.project(x, y, z)
    return math.floor(sx + 0.5), math.floor(sy + 0.5)
  end

  --- Unproject a screen pixel back to model (x, y) at a given model z.
  -- Since the projection loses one dimension, z must be supplied.
  function Iso.unproject(sx, sy, z)
    local rsx = sx - z * Iso.ZX
    local rsy = sy - z * Iso.ZY
    local d = Iso._det
    return (Iso.YY * rsx - Iso.YX * rsy) / d,
           (Iso.XX * rsy - Iso.XY * rsx) / d
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- DEPTH
  -- ═════════════════════════════════════════════════════════════════════

  --- Depth of a 3D point along the view direction.
  -- LOWER depth = closer to camera (drawn on top).
  function Iso.depth(x, y, z)
    return Iso._vx * x + Iso._vy * y + Iso._vz * z
  end

  --- View direction components (unit vector pointing into the scene).
  function Iso.view_dir()
    local vx, vy, vz = Iso._vx, Iso._vy, Iso._vz
    local len = sqrt(vx*vx + vy*vy + vz*vz)
    return vx/len, vy/len, vz/len
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- 3D ROTATION
  -- ═════════════════════════════════════════════════════════════════════

  --- Rotate a point around a cardinal axis through the origin.
  -- @param axis  "x", "y", or "z"
  -- @param angle  radians
  function Iso.rotate(x, y, z, axis, angle)
    local c, s = cos(angle), sin(angle)
    if axis == "x" then
      return x, y*c - z*s, y*s + z*c
    elseif axis == "y" then
      return x*c + z*s, y, -x*s + z*c
    else  -- "z"
      return x*c - y*s, x*s + y*c, z
    end
  end

  --- Rotate around a cardinal axis through an arbitrary center point.
  function Iso.rotate_around(x, y, z, cx, cy, cz, axis, angle)
    local dx, dy, dz = x - cx, y - cy, z - cz
    local rx, ry, rz = Iso.rotate(dx, dy, dz, axis, angle)
    return rx + cx, ry + cy, rz + cz
  end

  --- Rotate around an arbitrary axis through the origin (Rodrigues formula).
  -- @param ax,ay,az  unit vector of the rotation axis
  -- @param angle  radians
  function Iso.rotate_axis(x, y, z, ax, ay, az, angle)
    local c, s = cos(angle), sin(angle)
    local dot = x*ax + y*ay + z*az
    local cx, cy, cz = ay*z - az*y, az*x - ax*z, ax*y - ay*x
    return x*c + cx*s + ax * dot * (1 - c),
           y*c + cy*s + ay * dot * (1 - c),
           z*c + cz*s + az * dot * (1 - c)
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- BOUNDING BOX HELPERS
  -- ═════════════════════════════════════════════════════════════════════

  --- Screen bounding box of a set of 3D points.
  -- Returns: x1, y1, x2, y2 (integer, 1px margin)
  function Iso.bbox(points)
    local sxmin, symin =  math.huge,  math.huge
    local sxmax, symax = -math.huge, -math.huge
    for _, p in ipairs(points) do
      local sx, sy = Iso.project(p[1], p[2], p[3])
      if sx < sxmin then sxmin = sx end
      if sx > sxmax then sxmax = sx end
      if sy < symin then symin = sy end
      if sy > symax then symax = sy end
    end
    return math.floor(sxmin) - 1, math.floor(symin) - 1,
           math.ceil(sxmax) + 1,  math.ceil(symax) + 1
  end
end
