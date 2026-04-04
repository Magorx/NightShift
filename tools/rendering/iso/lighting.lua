-- lighting.lua — Scene-level lighting: ambient + directional + point lights
--
-- Lights are added to scenes via scene:add_light(). The renderer accumulates
-- contributions from all lights for each pixel.
--
-- Light types:
--   "ambient"     — flat intensity, no direction (uniform base brightness)
--   "directional" — parallel rays from a direction (sun-like)
--   "point"       — positional with distance falloff
--
-- Injected via: dofile("lighting.lua")(Iso)

return function(Iso)
  local sqrt  = math.sqrt
  local max   = math.max
  local min   = math.min
  local floor = math.floor

  -- ═════════════════════════════════════════════════════════════════════
  -- LIGHT CONSTRUCTORS
  -- ═════════════════════════════════════════════════════════════════════

  --- Create an ambient light (uniform brightness on all surfaces).
  -- @param intensity  0..1 brightness level (default 0.3)
  -- @param color      optional tint {r, g, b} normalized 0..1 (default white)
  function Iso.light_ambient(intensity, color)
    return {
      type      = "ambient",
      intensity = intensity or 0.3,
      color     = color or {1, 1, 1},
    }
  end

  --- Create a directional light (parallel rays, like the sun).
  -- @param dx, dy, dz  direction the light travels FROM (auto-normalized)
  -- @param intensity    brightness (default 0.7)
  -- @param color        optional tint {r, g, b} normalized 0..1
  function Iso.light_directional(dx, dy, dz, intensity, color)
    local len = sqrt(dx*dx + dy*dy + dz*dz)
    return {
      type      = "directional",
      dir       = { x = dx/len, y = dy/len, z = dz/len },
      intensity = intensity or 0.7,
      color     = color or {1, 1, 1},
    }
  end

  --- Create a point light (positional with distance falloff).
  -- @param x, y, z     position in model space
  -- @param intensity    brightness at distance=0 (default 1.0)
  -- @param radius       effective radius — light is zero beyond this (default 30)
  -- @param color        optional tint {r, g, b} normalized 0..1
  function Iso.light_point(x, y, z, intensity, radius, color)
    return {
      type      = "point",
      pos       = { x = x, y = y, z = z },
      intensity = intensity or 1.0,
      radius    = radius or 30,
      color     = color or {1, 1, 1},
    }
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- DEFAULT LIGHT SETUP
  -- ═════════════════════════════════════════════════════════════════════

  --- Return the default light setup (matches the old Iso.light behavior).
  -- Used when a scene has no explicit lights.
  function Iso.default_lights()
    return {
      Iso.light_ambient(0.35),
      Iso.light_directional(-0.577, -0.577, 0.577, 0.65),
    }
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- LIGHT ACCUMULATION
  -- ═════════════════════════════════════════════════════════════════════

  --- Compute total light contribution at a surface point.
  -- @param lights   array of light objects
  -- @param nx,ny,nz surface normal (unit vector)
  -- @param mx,my,mz model-space position of the surface point
  -- @param opts     shading options: specular, spec_pow
  -- @return brightness (float), tint_r, tint_g, tint_b (each 0..1+)
  function Iso.accumulate_light(lights, nx, ny, nz, mx, my, mz, opts)
    opts = opts or {}
    local specular = opts.specular or 0
    local spec_pow = opts.spec_pow or 8

    local total_r, total_g, total_b = 0, 0, 0

    for _, light in ipairs(lights) do
      local cr, cg, cb = light.color[1], light.color[2], light.color[3]

      if light.type == "ambient" then
        -- Uniform contribution, no direction
        local i = light.intensity
        total_r = total_r + i * cr
        total_g = total_g + i * cg
        total_b = total_b + i * cb

      elseif light.type == "directional" then
        local lx, ly, lz = light.dir.x, light.dir.y, light.dir.z
        local dot = nx * lx + ny * ly + nz * lz
        if dot > 0 then
          local diffuse = dot * light.intensity
          total_r = total_r + diffuse * cr
          total_g = total_g + diffuse * cg
          total_b = total_b + diffuse * cb

          -- Specular (Blinn-Phong)
          if specular > 0 then
            local spec = specular * (dot ^ spec_pow) * light.intensity
            total_r = total_r + spec * cr
            total_g = total_g + spec * cg
            total_b = total_b + spec * cb
          end
        end

      elseif light.type == "point" then
        -- Vector from surface to light
        local dx = light.pos.x - mx
        local dy = light.pos.y - my
        local dz = light.pos.z - mz
        local dist = sqrt(dx*dx + dy*dy + dz*dz)

        if dist < light.radius and dist > 0.01 then
          -- Normalize direction
          local lx, ly, lz = dx/dist, dy/dist, dz/dist

          local dot = nx * lx + ny * ly + nz * lz
          if dot > 0 then
            -- Smooth attenuation: quadratic falloff, reaches 0 at radius
            local t = dist / light.radius
            local atten = (1 - t * t)  -- smooth falloff to 0 at radius
            atten = atten * atten      -- sharper falloff
            local diffuse = dot * light.intensity * atten

            total_r = total_r + diffuse * cr
            total_g = total_g + diffuse * cg
            total_b = total_b + diffuse * cb

            -- Specular
            if specular > 0 then
              local spec = specular * (dot ^ spec_pow) * light.intensity * atten
              total_r = total_r + spec * cr
              total_g = total_g + spec * cg
              total_b = total_b + spec * cb
            end
          end
        end
      end
    end

    return total_r, total_g, total_b
  end

  --- Apply accumulated light to a base color.
  -- @param base_color  integer RGBA color
  -- @param lr, lg, lb  light contributions per channel (from accumulate_light)
  -- @return shaded color
  function Iso.apply_light(base_color, lr, lg, lb)
    local H = Iso._H
    if not H then return base_color end
    local r, g, b, a = H.decompose(base_color)
    local function clamp(v) return max(0, min(255, floor(v + 0.5))) end
    return H.rgba(clamp(r * lr), clamp(g * lg), clamp(b * lb), a)
  end
end
