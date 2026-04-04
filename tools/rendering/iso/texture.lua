-- texture.lua — Procedural surface textures for isometric shapes
--
-- Textures are functions: texture(hit, colors, opts) → color
-- They modify the base color based on the 3D hit position.
-- The scene renderer applies textures after shading.
--
-- Injected via: dofile("texture.lua")(Iso)

return function(Iso)
  local floor = math.floor
  local abs   = math.abs
  local sin   = math.sin
  local cos   = math.cos
  local fmod  = math.fmod
  local sqrt  = math.sqrt
  local max   = math.max

  local H  -- set by init.lua via Iso._set_helper

  -- ═════════════════════════════════════════════════════════════════════
  -- NOISE (simple hash-based pseudo-noise)
  -- ═════════════════════════════════════════════════════════════════════

  -- Integer hash for deterministic noise
  local function hash2d(x, y)
    local n = x * 374761393 + y * 668265263
    n = (n ~ (n >> 13)) * 1274126177
    n = n ~ (n >> 16)
    return (n % 256) / 255  -- 0..1
  end

  local function hash3d(x, y, z)
    return hash2d(x * 31 + z * 7, y * 17 + z * 13)
  end

  --- Noise texture: random brightness variation per pixel.
  -- amount: 0..1 how much variation (default 0.15)
  function Iso.tex_noise(amount)
    amount = amount or 0.15
    return function(hit, base_color)
      if not H then return base_color end
      local ix = floor(hit.mx + 0.5)
      local iy = floor(hit.my + 0.5)
      local iz = floor(hit.mz + 0.5)
      local n = hash3d(ix, iy, iz)
      local factor = 1.0 + (n - 0.5) * amount * 2
      return H.brighten(base_color, factor)
    end
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- BRICK pattern
  -- ═════════════════════════════════════════════════════════════════════

  --- Brick texture: staggered rectangular grid.
  -- bw, bh: brick dimensions in model units
  -- mortar_color: color for mortar lines (or nil for darker base)
  function Iso.tex_brick(bw, bh, mortar_color)
    bw = bw or 4
    bh = bh or 2
    return function(hit, base_color)
      if not H then return base_color end
      -- Use the two coordinates perpendicular to the face normal
      local u, v
      if abs(hit.nz) > 0.5 then
        u, v = hit.mx, hit.my      -- top face
      elseif abs(hit.nx) > 0.5 then
        u, v = hit.my, hit.mz      -- right wall
      else
        u, v = hit.mx, hit.mz      -- left wall
      end

      local row = floor(v / bh)
      local offset = (row % 2 == 0) and 0 or (bw / 2)
      local bu = fmod(u + offset + 1000 * bw, bw)
      local bv = fmod(v + 1000 * bh, bh)

      -- Mortar lines
      if bu < 0.8 or bv < 0.8 then
        local mc = mortar_color or H.brighten(base_color, 0.7)
        return mc
      end

      -- Slight per-brick color variation
      local brick_id = floor((u + offset) / bw) + row * 137
      local variation = hash2d(brick_id, row) * 0.15
      return H.brighten(base_color, 1.0 + variation - 0.075)
    end
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- METAL PLATE (panels with rivet dots at corners)
  -- ═════════════════════════════════════════════════════════════════════

  --- Metal plate texture: rectangular panels with corner rivets.
  -- pw, ph: panel size in model units
  -- rivet_color: color for rivets (default brighter)
  function Iso.tex_metal_plate(pw, ph, rivet_color)
    pw = pw or 8
    ph = ph or 8
    return function(hit, base_color)
      if not H then return base_color end
      local u, v
      if abs(hit.nz) > 0.5 then
        u, v = hit.mx, hit.my
      elseif abs(hit.nx) > 0.5 then
        u, v = hit.my, hit.mz
      else
        u, v = hit.mx, hit.mz
      end

      local pu = fmod(u + 1000 * pw, pw)
      local pv = fmod(v + 1000 * ph, ph)

      -- Panel edge seams
      if pu < 0.5 or pv < 0.5 then
        return H.brighten(base_color, 0.8)
      end

      -- Corner rivets (2px diameter at each corner)
      local rivet_margin = 1.5
      local is_rivet = false
      for _, cx in ipairs({rivet_margin, pw - rivet_margin}) do
        for _, cy in ipairs({rivet_margin, ph - rivet_margin}) do
          if (pu - cx)*(pu - cx) + (pv - cy)*(pv - cy) <= 1.2 then
            is_rivet = true
          end
        end
      end
      if is_rivet then
        return rivet_color or H.brighten(base_color, 1.4)
      end

      return base_color
    end
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- GRATE (parallel lines with gaps)
  -- ═════════════════════════════════════════════════════════════════════

  --- Grate texture: parallel bars with transparent gaps.
  -- spacing: distance between bars in model units
  -- bar_width: width of each bar
  -- direction: "u" or "v" (default "u" = horizontal bars)
  function Iso.tex_grate(spacing, bar_width, direction)
    spacing   = spacing or 3
    bar_width = bar_width or 1.5
    direction = direction or "u"
    return function(hit, base_color)
      if not H then return base_color end
      local u, v
      if abs(hit.nz) > 0.5 then
        u, v = hit.mx, hit.my
      elseif abs(hit.nx) > 0.5 then
        u, v = hit.my, hit.mz
      else
        u, v = hit.mx, hit.mz
      end

      local coord = direction == "u" and v or u
      local pos = fmod(coord + 1000 * spacing, spacing)
      if pos > bar_width then
        return H.brighten(base_color, 0.3)  -- deep gap
      end
      return base_color
    end
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- RIVETS (dot pattern along edges)
  -- ═════════════════════════════════════════════════════════════════════

  --- Rivet strip: dots along one axis at regular intervals.
  -- spacing: distance between rivets
  -- offset_u, offset_v: position of the rivet strip
  -- rivet_color: dot color
  function Iso.tex_rivets(spacing, strip_v, rivet_color)
    spacing = spacing or 4
    strip_v = strip_v or 0  -- v-coordinate of the rivet strip
    return function(hit, base_color)
      if not H then return base_color end
      local u, v
      if abs(hit.nz) > 0.5 then
        u, v = hit.mx, hit.my
      elseif abs(hit.nx) > 0.5 then
        u, v = hit.my, hit.mz
      else
        u, v = hit.mx, hit.mz
      end

      if abs(v - strip_v) <= 0.7 then
        local pos = fmod(u + 1000 * spacing, spacing)
        if abs(pos - spacing/2) <= 0.7 then
          return rivet_color or H.brighten(base_color, 1.5)
        end
      end
      return base_color
    end
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- WOOD GRAIN (horizontal streaks)
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.tex_wood_grain(streak_spacing)
    streak_spacing = streak_spacing or 2.5
    return function(hit, base_color)
      if not H then return base_color end
      local u, v
      if abs(hit.nz) > 0.5 then
        u, v = hit.mx, hit.my
      elseif abs(hit.nx) > 0.5 then
        u, v = hit.my, hit.mz
      else
        u, v = hit.mx, hit.mz
      end

      local grain = sin(v / streak_spacing * 3.14159 + u * 0.3) * 0.5 + 0.5
      local noise = hash2d(floor(u * 2), floor(v * 2)) * 0.1
      return H.brighten(base_color, 0.9 + grain * 0.2 + noise)
    end
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- CORRUGATED METAL (alternating light/dark rows)
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.tex_corrugated(period)
    period = period or 3
    return function(hit, base_color)
      if not H then return base_color end
      local v
      if abs(hit.nz) > 0.5 then
        v = hit.my
      elseif abs(hit.nx) > 0.5 then
        v = hit.mz
      else
        v = hit.mz
      end

      local wave = sin(v / period * 2 * 3.14159)
      return H.brighten(base_color, 0.95 + wave * 0.1)
    end
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- DIAMOND PLATE (offset dot grid, floor texture)
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.tex_diamond_plate(spacing)
    spacing = spacing or 3
    return function(hit, base_color)
      if not H then return base_color end
      local u, v
      if abs(hit.nz) > 0.5 then
        u, v = hit.mx, hit.my
      else
        u, v = hit.mx, hit.mz
      end

      local row = floor(v / spacing)
      local offset = (row % 2 == 0) and 0 or (spacing / 2)
      local pu = fmod(u + offset + 1000 * spacing, spacing)
      local pv = fmod(v + 1000 * spacing, spacing)
      local dist = sqrt((pu - spacing/2)^2 + (pv - spacing/2)^2)

      if dist < spacing * 0.25 then
        return H.brighten(base_color, 1.2)
      end
      return base_color
    end
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- HEX MESH (hexagonal pattern)
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.tex_hex_mesh(hex_size)
    hex_size = hex_size or 4
    return function(hit, base_color)
      if not H then return base_color end
      local u, v
      if abs(hit.nz) > 0.5 then
        u, v = hit.mx, hit.my
      else
        u, v = hit.mx, hit.mz
      end

      -- Convert to hex grid coordinates
      local q = (2/3 * u) / hex_size
      local r_hex = (-1/3 * u + sqrt(3)/3 * v) / hex_size

      -- Round to nearest hex
      local rq = floor(q + 0.5)
      local rr = floor(r_hex + 0.5)

      -- Distance from hex center
      local cu = rq * hex_size * 3/2
      local cv = (rq * hex_size * sqrt(3)/2) + rr * hex_size * sqrt(3)
      local dist = sqrt((u - cu)^2 + (v - cv)^2)

      -- Hex edge
      if dist > hex_size * 0.75 then
        return H.brighten(base_color, 0.7)
      end
      return base_color
    end
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- DITHERED GRADIENT (smooth shading via ordered dithering)
  -- ═════════════════════════════════════════════════════════════════════

  --- 4×4 Bayer dithered blend between two colors based on a parameter.
  -- param_fn(hit) → 0..1 value to dither between color_a and color_b
  function Iso.tex_dither(param_fn, color_a, color_b)
    local bayer = {
      { 0/16, 8/16, 2/16,10/16},
      {12/16, 4/16,14/16, 6/16},
      { 3/16,11/16, 1/16, 9/16},
      {15/16, 7/16,13/16, 5/16},
    }
    return function(hit, _base_color)
      if not H then return _base_color end
      local t = param_fn(hit)
      t = max(0, t < 1 and t or 1)
      -- Screen-space dithering for consistency
      local sx, sy = Iso.project(hit.mx, hit.my, hit.mz)
      local bx = (floor(sx) % 4) + 1
      local by = (floor(sy) % 4) + 1
      if t > bayer[by][bx] then
        return color_b
      end
      return color_a
    end
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- UTILITY: compose textures
  -- ═════════════════════════════════════════════════════════════════════

  --- Chain multiple textures: each one modifies the color from the previous.
  function Iso.tex_compose(...)
    local textures = {...}
    return function(hit, base_color)
      local c = base_color
      for _, tex in ipairs(textures) do
        c = tex(hit, c)
      end
      return c
    end
  end
end
