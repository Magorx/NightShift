-- shading.lua — Lighting, auto-shade, and outline detection
--
-- Injected via: dofile("shading.lua")(Iso)

return function(Iso)
  local sqrt = math.sqrt
  local max  = math.max
  local min  = math.min
  local abs  = math.abs
  local floor = math.floor

  -- ═════════════════════════════════════════════════════════════════════
  -- LIGHT DIRECTION
  -- ═════════════════════════════════════════════════════════════════════

  -- Default: light from upper-left (standard for pixel art)
  Iso.light = { x = -0.577, y = -0.577, z = 0.577 }

  --- Set the global light direction (auto-normalized).
  function Iso.set_light(lx, ly, lz)
    local len = sqrt(lx*lx + ly*ly + lz*lz)
    Iso.light = { x = lx/len, y = ly/len, z = lz/len }
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- SHADING
  -- ═════════════════════════════════════════════════════════════════════

  --- Raw shading factor from a surface normal.
  -- Returns 0..1 where 0 = fully shadowed, 1 = fully lit.
  function Iso.shade_factor(nx, ny, nz)
    local dot = nx * Iso.light.x + ny * Iso.light.y + nz * Iso.light.z
    return max(0, min(1, dot * 0.5 + 0.5))
  end

  --- Shade a color by a surface normal.
  -- opts.ambient  (default 0.35): minimum brightness
  -- opts.diffuse  (default 0.65): light contribution
  -- opts.specular (default 0):    specular highlight strength
  -- opts.spec_pow (default 8):    specular shininess
  function Iso.shade_color(base, nx, ny, nz, opts)
    if not Iso._H then return base end
    local H = Iso._H
    opts = opts or {}
    local ambient  = opts.ambient  or 0.35
    local diffuse  = opts.diffuse  or 0.65
    local specular = opts.specular or 0
    local spec_pow = opts.spec_pow or 8

    local f = Iso.shade_factor(nx, ny, nz)
    local brightness = ambient + diffuse * f

    -- Specular highlight (Blinn-Phong approximation)
    if specular > 0 then
      local dot = nx * Iso.light.x + ny * Iso.light.y + nz * Iso.light.z
      if dot > 0 then
        local spec = specular * (dot ^ spec_pow)
        brightness = brightness + spec
      end
    end

    return H.brighten(base, brightness)
  end

  --- Resolve a color for a hit, supporting both manual face colors and auto-shade.
  -- colors table can have:
  --   colors.base + auto-shade from normal
  --   colors.<face_name> = explicit color for that face
  --   colors.outline = outline color
  function Iso.resolve_color(colors, face, nx, ny, nz, opts)
    if colors[face] then
      return colors[face]
    elseif colors.base then
      return Iso.shade_color(colors.base, nx, ny, nz, opts)
    else
      return colors.top or colors.body or 0  -- fallback
    end
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- OUTLINE DETECTION
  -- ═════════════════════════════════════════════════════════════════════

  --- Check if a screen pixel is on the silhouette edge of drawn geometry.
  -- Tests 4-connected neighbors in the depth buffer.
  -- @param depth_threshold  max depth gap before it's an edge (default 2)
  function Iso.is_outline(zbuf, sx, sy, depth_threshold)
    depth_threshold = depth_threshold or 2
    if sx < 0 or sx >= zbuf.w or sy < 0 or sy >= zbuf.h then return false end
    local d = zbuf[sy][sx]
    if d >= math.huge then return false end

    local dirs = {{-1,0},{1,0},{0,-1},{0,1}}
    for _, dir in ipairs(dirs) do
      local nx, ny = sx + dir[1], sy + dir[2]
      if nx < 0 or nx >= zbuf.w or ny < 0 or ny >= zbuf.h then
        return true  -- edge of canvas
      end
      if zbuf[ny][nx] >= math.huge then
        return true  -- neighbor is empty
      end
      if abs(zbuf[ny][nx] - d) > depth_threshold then
        return true  -- sharp depth discontinuity (shape boundary)
      end
    end
    return false
  end

  --- Draw outlines for all filled pixels in a zbuffer onto an image.
  function Iso.draw_outlines(img, zbuf, outline_color, depth_threshold)
    local H = Iso._H
    if not H then return end
    for sy = 0, zbuf.h - 1 do
      for sx = 0, zbuf.w - 1 do
        if Iso.is_outline(zbuf, sx, sy, depth_threshold) then
          H.px(img, sx, sy, outline_color)
        end
      end
    end
  end
end
