-- primitives.lua — Isometric 3D shape primitives
--
-- Each shape is a table with:
--   :hit(sx, sy)  → { depth, face, nx, ny, nz, mx, my, mz } or nil
--   .x1,.y1,.x2,.y2  → screen bounding box (relative to shape origin)
--
-- Shapes are defined in model space centered at (0,0,0).
-- The scene renderer offsets them to world positions.
--
-- Injected via: dofile("primitives.lua")(Iso)

return function(Iso)
  local floor = math.floor
  local ceil  = math.ceil
  local sqrt  = math.sqrt
  local abs   = math.abs
  local min   = math.min
  local max   = math.max
  local pi    = math.pi
  local atan2 = math.atan2 or math.atan
  local cos   = math.cos
  local sin   = math.sin
  local huge  = math.huge

  -- ═════════════════════════════════════════════════════════════════════
  -- INTERNAL: solve wall-plane intersections for a box
  -- ═════════════════════════════════════════════════════════════════════

  -- Determinant of [[XX,ZX],[XY,ZY]] (for y-plane intersections)
  local function det_xz()
    return Iso.XX * Iso.ZY - Iso.ZX * Iso.XY
  end

  -- Determinant of [[YX,ZX],[YY,ZY]] (for x-plane intersections)
  local function det_yz()
    return Iso.YX * Iso.ZY - Iso.ZX * Iso.YY
  end

  -- Make a hit table
  local function mkhit(depth, face, nx, ny, nz, mx, my, mz)
    return { depth=depth, face=face, nx=nx, ny=ny, nz=nz, mx=mx, my=my, mz=mz }
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- BOX (width along X, depth along Y, height along Z)
  -- Origin: corner at (0,0,0), extends to (w, d, h)
  -- Visible faces: top (z=h), front_left (y=d), front_right (x=w)
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.box(w, d, h)
    local shape = { type="box", w=w, d=d, h=h }
    local corners = {
      {0,0,0},{w,0,0},{0,d,0},{w,d,0},
      {0,0,h},{w,0,h},{0,d,h},{w,d,h},
    }
    shape.x1, shape.y1, shape.x2, shape.y2 = Iso.bbox(corners)

    function shape:hit(sx, sy)
      local best = nil

      -- Top face (z = h plane)
      local mx, my = Iso.unproject(sx, sy, h)
      if mx >= -0.5 and mx <= w+0.5 and my >= -0.5 and my <= d+0.5 then
        local dp = Iso.depth(mx, my, h)
        if not best or dp < best.depth then
          best = mkhit(dp, "top", 0, 0, 1, mx, my, h)
        end
      end

      -- Front-left wall (y = d plane) — faces camera's left side
      local dxz = det_xz()
      if abs(dxz) > 1e-6 then
        local rsx = sx - d * Iso.YX
        local rsy = sy - d * Iso.YY
        local fmx = (Iso.ZY * rsx - Iso.ZX * rsy) / dxz
        local fmz = (Iso.XX * rsy - Iso.XY * rsx) / dxz
        if fmx >= -0.5 and fmx <= w+0.5 and fmz >= -0.5 and fmz <= h+0.5 then
          local dp = Iso.depth(fmx, d, fmz)
          if not best or dp < best.depth then
            best = mkhit(dp, "front_left", 0, 1, 0, fmx, d, fmz)
          end
        end
      end

      -- Front-right wall (x = w plane) — faces camera's right side
      local dyz = det_yz()
      if abs(dyz) > 1e-6 then
        local rsx = sx - w * Iso.XX
        local rsy = sy - w * Iso.XY
        local fmy = (Iso.ZY * rsx - Iso.ZX * rsy) / dyz
        local fmz = (Iso.YX * rsy - Iso.YY * rsx) / dyz
        if fmy >= -0.5 and fmy <= d+0.5 and fmz >= -0.5 and fmz <= h+0.5 then
          local dp = Iso.depth(w, fmy, fmz)
          if not best or dp < best.depth then
            best = mkhit(dp, "front_right", 1, 0, 0, w, fmy, fmz)
          end
        end
      end

      return best
    end

    return shape
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- CYLINDER (vertical axis, centered at XY origin)
  -- Radius r, height h, base at z=0, top at z=h
  -- Faces: top, body
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.cylinder(r, h)
    local shape = { type="cylinder", r=r, h=h }
    local corners = {
      {-r,-r,0},{r,-r,0},{-r,r,0},{r,r,0},
      {-r,-r,h},{r,-r,h},{-r,r,h},{r,r,h},
    }
    shape.x1, shape.y1, shape.x2, shape.y2 = Iso.bbox(corners)

    function shape:hit(sx, sy)
      local best = nil

      -- Top ellipse (z = h)
      local mx, my = Iso.unproject(sx, sy, h)
      if mx*mx + my*my <= (r+0.5)*(r+0.5) then
        local dp = Iso.depth(mx, my, h)
        if not best or dp < best.depth then
          best = mkhit(dp, "top", 0, 0, 1, mx, my, h)
        end
      end

      -- Curved body: ray from unproject(sx,sy,0) along view direction
      local mx0, my0 = Iso.unproject(sx, sy, 0)
      local vx, vy, vz = Iso._vx, Iso._vy, Iso._vz

      local a = vx*vx + vy*vy
      local b = 2*(mx0*vx + my0*vy)
      local c = mx0*mx0 + my0*my0 - r*r
      local disc = b*b - 4*a*c

      if disc >= 0 and a > 1e-9 then
        local sq = sqrt(disc)
        for _, sign in ipairs({-1, 1}) do
          local t = (-b + sign * sq) / (2*a)
          local bx, by, bz = mx0 + t*vx, my0 + t*vy, t*vz
          if bz >= -0.5 and bz <= h+0.5 then
            local dp = Iso.depth(bx, by, bz)
            if not best or dp < best.depth then
              local len = sqrt(bx*bx + by*by)
              local nnx = len > 0 and bx/len or 0
              local nny = len > 0 and by/len or 0
              best = mkhit(dp, "body", nnx, nny, 0, bx, by, bz)
            end
            break
          end
        end
      end

      return best
    end

    return shape
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- CONE (base at z=0 radius=r, apex at z=h radius=0)
  -- Faces: bottom (z=0 circle), body (conical surface)
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.cone(r, h)
    local shape = { type="cone", r=r, h=h }
    local corners = {
      {-r,-r,0},{r,-r,0},{-r,r,0},{r,r,0},{0,0,h},
    }
    shape.x1, shape.y1, shape.x2, shape.y2 = Iso.bbox(corners)

    -- Normal slope for cone: horizontal component h, vertical component r
    local nslope = sqrt(h*h + r*r)

    function shape:hit(sx, sy)
      local best = nil

      -- Conical surface: radius at height z is r*(1-z/h)
      -- Ray: (mx0+vx*t, my0+vy*t, vz*t)
      local mx0, my0 = Iso.unproject(sx, sy, 0)
      local vx, vy, vz = Iso._vx, Iso._vy, Iso._vz

      -- (mx0+vx*t)^2 + (my0+vy*t)^2 = (r*(1 - vz*t/h))^2
      local rh = r / h
      local a = vx*vx + vy*vy - rh*rh*vz*vz
      local b = 2*(mx0*vx + my0*vy) + 2*rh*rh*h*vz
      local c = mx0*mx0 + my0*my0 - r*r

      local disc = b*b - 4*a*c
      if disc >= 0 and abs(a) > 1e-9 then
        local sq = sqrt(disc)
        for _, sign in ipairs({-1, 1}) do
          local t = (-b + sign * sq) / (2*a)
          local bx, by, bz = mx0 + t*vx, my0 + t*vy, t*vz
          if bz >= -0.5 and bz <= h+0.5 then
            local dp = Iso.depth(bx, by, bz)
            if not best or dp < best.depth then
              local len = sqrt(bx*bx + by*by)
              local nnx = len > 0 and (bx/len)*h/nslope or 0
              local nny = len > 0 and (by/len)*h/nslope or 0
              local nnz = r / nslope
              best = mkhit(dp, "body", nnx, nny, nnz, bx, by, bz)
            end
            break
          end
        end
      end

      -- Bottom face (z = 0) — visible when looking from above
      local bmx, bmy = Iso.unproject(sx, sy, 0)
      if bmx*bmx + bmy*bmy <= (r+0.5)*(r+0.5) then
        local dp = Iso.depth(bmx, bmy, 0)
        if not best or dp < best.depth then
          best = mkhit(dp, "bottom", 0, 0, -1, bmx, bmy, 0)
        end
      end

      return best
    end

    return shape
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- SPHERE (centered at (0, 0, r), sits on ground at z=0)
  -- Faces: body (entire surface)
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.sphere(r)
    local shape = { type="sphere", r=r }
    local d = r * 1.1  -- margin for bbox
    local corners = {
      {-d,-d,0},{d,-d,0},{-d,d,0},{d,d,0},
      {-d,-d,2*r},{d,-d,2*r},{-d,d,2*r},{d,d,2*r},
    }
    shape.x1, shape.y1, shape.x2, shape.y2 = Iso.bbox(corners)

    function shape:hit(sx, sy)
      -- Center at (0, 0, r)
      local mx0, my0 = Iso.unproject(sx, sy, 0)
      local vx, vy, vz = Iso._vx, Iso._vy, Iso._vz

      -- (mx0+vx*t)^2 + (my0+vy*t)^2 + (vz*t - r)^2 = r^2
      local a = vx*vx + vy*vy + vz*vz
      local b = 2*(mx0*vx + my0*vy - r*vz)
      local c = mx0*mx0 + my0*my0
      local disc = b*b - 4*a*c

      if disc < 0 or a < 1e-9 then return nil end
      local sq = sqrt(disc)
      local t = (-b - sq) / (2*a)  -- near intersection
      local bx, by, bz = mx0 + t*vx, my0 + t*vy, t*vz

      if bz < -0.5 then return nil end  -- below ground

      local dp = Iso.depth(bx, by, bz)
      local nnx, nny, nnz = bx/r, by/r, (bz-r)/r
      return mkhit(dp, "body", nnx, nny, nnz, bx, by, bz)
    end

    return shape
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- HEMISPHERE (bottom half of a sphere, sitting on ground)
  -- Dome shape: flat base at z=0, curved top up to z=r
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.hemisphere(r)
    local shape = { type="hemisphere", r=r }
    local d = r * 1.1
    local corners = {
      {-d,-d,0},{d,-d,0},{-d,d,0},{d,d,0},
      {-d,-d,r},{d,-d,r},{-d,d,r},{d,d,r},
    }
    shape.x1, shape.y1, shape.x2, shape.y2 = Iso.bbox(corners)

    function shape:hit(sx, sy)
      -- Sphere centered at origin, take upper half (z >= 0)
      local mx0, my0 = Iso.unproject(sx, sy, 0)
      local vx, vy, vz = Iso._vx, Iso._vy, Iso._vz

      local a = vx*vx + vy*vy + vz*vz
      local b = 2*(mx0*vx + my0*vy)
      local c = mx0*mx0 + my0*my0 - r*r
      local disc = b*b - 4*a*c

      if disc < 0 or a < 1e-9 then return nil end
      local sq = sqrt(disc)

      for _, sign in ipairs({-1, 1}) do
        local t = (-b + sign * sq) / (2*a)
        local bx, by, bz = mx0 + t*vx, my0 + t*vy, t*vz
        if bz >= -0.5 and bz <= r + 0.5 then
          local dp = Iso.depth(bx, by, bz)
          local nnx, nny, nnz = bx/r, by/r, bz/r
          return mkhit(dp, "body", nnx, nny, nnz, bx, by, bz)
        end
      end
      return nil
    end

    return shape
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- WEDGE (box with sloped top: front edge at height hf, back at hb)
  -- Width w (X), depth d (Y), height varies linearly from hb (y=0) to hf (y=d)
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.wedge(w, d, hf, hb)
    local shape = { type="wedge", w=w, d=d, hf=hf, hb=hb }
    local hmax = max(hf, hb)
    local corners = {
      {0,0,0},{w,0,0},{0,d,0},{w,d,0},
      {0,0,hb},{w,0,hb},{0,d,hf},{w,d,hf},
    }
    shape.x1, shape.y1, shape.x2, shape.y2 = Iso.bbox(corners)

    -- Slope normal for the top face
    local dh = hf - hb  -- height change over depth d
    local slope_len = sqrt(d*d + dh*dh)
    local top_ny = -dh / slope_len
    local top_nz = d / slope_len

    function shape:hit(sx, sy)
      local best = nil

      -- Sloped top face: z = hb + (hf-hb) * my/d at point (mx, my)
      -- Use slice sampling for the slope
      for z_step = 0, 20 do
        local t = z_step / 20
        local z_test = hb + (hf - hb) * t
        local mx, my = Iso.unproject(sx, sy, z_test)
        -- Check if my/d ≈ t and mx in range
        local expected_t = d > 0 and my / d or 0
        if abs(expected_t - t) < 0.1 and mx >= -0.5 and mx <= w+0.5
           and my >= -0.5 and my <= d+0.5 then
          local dp = Iso.depth(mx, my, z_test)
          if not best or dp < best.depth then
            best = mkhit(dp, "top", 0, top_ny, top_nz, mx, my, z_test)
          end
          break
        end
      end

      -- Front-left wall (y = d, z from 0 to hf)
      local dxz = det_xz()
      if abs(dxz) > 1e-6 then
        local rsx = sx - d * Iso.YX
        local rsy = sy - d * Iso.YY
        local fmx = (Iso.ZY * rsx - Iso.ZX * rsy) / dxz
        local fmz = (Iso.XX * rsy - Iso.XY * rsx) / dxz
        if fmx >= -0.5 and fmx <= w+0.5 and fmz >= -0.5 and fmz <= hf+0.5 then
          local dp = Iso.depth(fmx, d, fmz)
          if not best or dp < best.depth then
            best = mkhit(dp, "front_left", 0, 1, 0, fmx, d, fmz)
          end
        end
      end

      -- Front-right wall (x = w, z from 0 to interpolated height)
      local dyz = det_yz()
      if abs(dyz) > 1e-6 then
        local rsx = sx - w * Iso.XX
        local rsy = sy - w * Iso.XY
        local fmy = (Iso.ZY * rsx - Iso.ZX * rsy) / dyz
        local fmz = (Iso.YX * rsy - Iso.YY * rsx) / dyz
        local h_at_y = hb + (hf - hb) * max(0, min(1, fmy / max(d, 0.01)))
        if fmy >= -0.5 and fmy <= d+0.5 and fmz >= -0.5 and fmz <= h_at_y+0.5 then
          local dp = Iso.depth(w, fmy, fmz)
          if not best or dp < best.depth then
            best = mkhit(dp, "front_right", 1, 0, 0, w, fmy, fmz)
          end
        end
      end

      return best
    end

    return shape
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- PRISM (triangular cross-section, extruded along Y)
  -- Base: triangle in XZ plane from (0,0,0) to (w,0,0) to (w/2,0,h)
  -- Extruded along Y by depth d
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.prism(w, d, h)
    local shape = { type="prism", w=w, d=d, h=h }
    local hw = w / 2
    local corners = {
      {0,0,0},{w,0,0},{hw,0,h},
      {0,d,0},{w,d,0},{hw,d,h},
    }
    shape.x1, shape.y1, shape.x2, shape.y2 = Iso.bbox(corners)

    -- Left slope normal: from (0,0,0)→(hw,0,h), cross with Y
    local sl = sqrt(hw*hw + h*h)
    local ln_x, ln_z = -h/sl, hw/sl  -- outward-pointing left
    -- Right slope normal
    local rn_x, rn_z = h/sl, hw/sl

    function shape:hit(sx, sy)
      local best = nil

      -- Front face (y = d): triangle
      local dxz = det_xz()
      if abs(dxz) > 1e-6 then
        local rsx = sx - d * Iso.YX
        local rsy = sy - d * Iso.YY
        local fmx = (Iso.ZY * rsx - Iso.ZX * rsy) / dxz
        local fmz = (Iso.XX * rsy - Iso.XY * rsx) / dxz
        -- Inside triangle: z >= 0, z <= h*(1 - |2*x/w - 1|)
        local rel_x = fmx / max(w, 0.01)
        local max_z = h * (1 - abs(2*rel_x - 1))
        if fmx >= -0.5 and fmx <= w+0.5 and fmz >= -0.5 and fmz <= max_z+0.5 then
          local dp = Iso.depth(fmx, d, fmz)
          if not best or dp < best.depth then
            best = mkhit(dp, "front_left", 0, 1, 0, fmx, d, fmz)
          end
        end
      end

      -- Left slope face: plane from edge (0,y,0)→(hw,y,h)
      -- Use slice approach
      for z_step = 0, 20 do
        local fz = h * z_step / 20
        local fx = hw * z_step / 20  -- x at this height on left slope
        local mx, my = Iso.unproject(sx, sy, fz)
        if abs(mx - fx) < 1.5 and my >= -0.5 and my <= d+0.5 and mx <= hw then
          local dp = Iso.depth(mx, my, fz)
          if not best or dp < best.depth then
            best = mkhit(dp, "left_slope", ln_x, 0, ln_z, mx, my, fz)
          end
          break
        end
      end

      -- Right slope face
      for z_step = 0, 20 do
        local fz = h * z_step / 20
        local fx = w - hw * z_step / 20
        local mx, my = Iso.unproject(sx, sy, fz)
        if abs(mx - fx) < 1.5 and my >= -0.5 and my <= d+0.5 and mx >= hw then
          local dp = Iso.depth(mx, my, fz)
          if not best or dp < best.depth then
            best = mkhit(dp, "right_slope", rn_x, 0, rn_z, mx, my, fz)
          end
          break
        end
      end

      return best
    end

    return shape
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- TORUS (major radius R, minor radius r, centered at origin in XY)
  -- Sits at z = r (center of tube at z = r)
  -- Uses slice-based rendering for the quartic intersection
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.torus(R, r)
    local shape = { type="torus", R=R, r=r }
    local d = R + r + 1
    local corners = {
      {-d,-d,0},{d,-d,0},{-d,d,0},{d,d,0},
      {-d,-d,2*r},{d,-d,2*r},{-d,d,2*r},{d,d,2*r},
    }
    shape.x1, shape.y1, shape.x2, shape.y2 = Iso.bbox(corners)

    function shape:hit(sx, sy)
      -- Slice approach: for each z level, check if unprojected point is in torus cross-section
      local best = nil
      local steps = max(8, floor(r * 2))

      for zi = steps, 0, -1 do
        local z = 2 * r * zi / steps
        local dz = z - r  -- distance from tube center height
        if abs(dz) <= r then
          local tube_r = sqrt(r*r - dz*dz)  -- tube cross-section radius at this z
          local inner = R - tube_r
          local outer = R + tube_r

          local mx, my = Iso.unproject(sx, sy, z)
          local dist = sqrt(mx*mx + my*my)

          if dist >= inner - 0.5 and dist <= outer + 0.5 then
            local dp = Iso.depth(mx, my, z)
            if not best or dp < best.depth then
              -- Normal: direction from nearest point on the major circle
              local ring_dist = dist > 0.01 and dist or 0.01
              local cx = mx * R / ring_dist  -- closest point on major circle
              local cy = my * R / ring_dist
              local nnx = mx - cx
              local nny = my - cy
              local nnz = dz
              local nlen = sqrt(nnx*nnx + nny*nny + nnz*nnz)
              if nlen > 0.01 then
                nnx, nny, nnz = nnx/nlen, nny/nlen, nnz/nlen
              end
              best = mkhit(dp, "body", nnx, nny, nnz, mx, my, z)
            end
          end
        end
      end

      return best
    end

    return shape
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- ARCH (box with semicircular cutout in the front-left face)
  -- Width w, depth d, height h, arch_radius ar (centered on front face)
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.arch(w, d, h, ar)
    ar = ar or min(w, h) * 0.4
    local shape = { type="arch", w=w, d=d, h=h, ar=ar }
    local corners = {
      {0,0,0},{w,0,0},{0,d,0},{w,d,0},
      {0,0,h},{w,0,h},{0,d,h},{w,d,h},
    }
    shape.x1, shape.y1, shape.x2, shape.y2 = Iso.bbox(corners)

    -- The arch opening is on the front_left face (y=d),
    -- centered at (w/2, d, ar), semicircular from z=0 to z=ar
    local arch_cx = w / 2

    function shape:hit(sx, sy)
      local best = nil

      -- Top face (z = h)
      local mx, my = Iso.unproject(sx, sy, h)
      if mx >= -0.5 and mx <= w+0.5 and my >= -0.5 and my <= d+0.5 then
        local dp = Iso.depth(mx, my, h)
        if not best or dp < best.depth then
          best = mkhit(dp, "top", 0, 0, 1, mx, my, h)
        end
      end

      -- Front-left wall (y = d) with arch cutout
      local dxz = det_xz()
      if abs(dxz) > 1e-6 then
        local rsx = sx - d * Iso.YX
        local rsy = sy - d * Iso.YY
        local fmx = (Iso.ZY * rsx - Iso.ZX * rsy) / dxz
        local fmz = (Iso.XX * rsy - Iso.XY * rsx) / dxz
        if fmx >= -0.5 and fmx <= w+0.5 and fmz >= -0.5 and fmz <= h+0.5 then
          -- Check if inside arch opening
          local in_arch = false
          local adx = fmx - arch_cx
          if fmz <= ar + 0.5 then
            if adx*adx + (fmz-ar)*(fmz-ar) <= ar*ar and fmz <= ar then
              in_arch = true  -- inside semicircle
            end
            if abs(adx) <= ar and fmz < ar - sqrt(max(0, ar*ar - adx*adx)) then
              in_arch = true  -- below arch curve
            end
          end
          if not in_arch then
            local dp = Iso.depth(fmx, d, fmz)
            if not best or dp < best.depth then
              best = mkhit(dp, "front_left", 0, 1, 0, fmx, d, fmz)
            end
          end
        end
      end

      -- Front-right wall (x = w)
      local dyz = det_yz()
      if abs(dyz) > 1e-6 then
        local rsx = sx - w * Iso.XX
        local rsy = sy - w * Iso.XY
        local fmy = (Iso.ZY * rsx - Iso.ZX * rsy) / dyz
        local fmz = (Iso.YX * rsy - Iso.YY * rsx) / dyz
        if fmy >= -0.5 and fmy <= d+0.5 and fmz >= -0.5 and fmz <= h+0.5 then
          local dp = Iso.depth(w, fmy, fmz)
          if not best or dp < best.depth then
            best = mkhit(dp, "front_right", 1, 0, 0, w, fmy, fmz)
          end
        end
      end

      return best
    end

    return shape
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- TRANSFORM WRAPPER: apply rotation/translation to any shape
  -- Creates a new shape that transforms screen coords before delegating
  -- ═════════════════════════════════════════════════════════════════════

  --- Translate a shape in 3D model space.
  function Iso.translate(shape, dx, dy, dz)
    local wrapper = { type="translated_"..shape.type }

    -- Recompute bbox with offset
    local osx, osy = Iso.project(dx, dy, dz)
    wrapper.x1 = shape.x1 + floor(osx) - 1
    wrapper.y1 = shape.y1 + floor(osy) - 1
    wrapper.x2 = shape.x2 + ceil(osx) + 1
    wrapper.y2 = shape.y2 + ceil(osy) + 1

    function wrapper:hit(sx, sy)
      local hit = shape:hit(sx - osx, sy - osy)
      if hit then
        hit.mx = hit.mx + dx
        hit.my = hit.my + dy
        hit.mz = hit.mz + dz
        hit.depth = Iso.depth(hit.mx, hit.my, hit.mz)
      end
      return hit
    end

    return wrapper
  end

  --- Create a shape that is a rotated version of another shape.
  -- Rotation is around the origin, then the bbox is recomputed.
  -- This is expensive (reverse-transforms every pixel) — use for static shapes.
  -- @param axis  "x", "y", or "z"
  -- @param angle  radians
  function Iso.rotate_shape(shape, axis, angle)
    local wrapper = { type="rotated_"..shape.type }

    -- Approximate new bbox by rotating original bbox corners
    local pts = {
      {shape.x1, shape.y1}, {shape.x2, shape.y1},
      {shape.x1, shape.y2}, {shape.x2, shape.y2},
    }
    -- Expand bbox generously
    local margin = max(abs(shape.x2 - shape.x1), abs(shape.y2 - shape.y1)) * 0.5
    wrapper.x1 = shape.x1 - floor(margin)
    wrapper.y1 = shape.y1 - floor(margin)
    wrapper.x2 = shape.x2 + ceil(margin)
    wrapper.y2 = shape.y2 + ceil(margin)

    local neg_angle = -angle

    function wrapper:hit(sx, sy)
      -- Unproject at multiple z levels, rotate back, test original shape
      -- This is a brute approach but works for any shape
      local best = nil

      -- Sample z range from original shape's bbox
      local z_min = -20
      local z_max = 40
      for zi = z_max * 2, z_min * 2, -1 do
        local z = zi * 0.5
        local mx, my = Iso.unproject(sx, sy, z)
        -- Rotate back to original orientation
        local omx, omy, omz = Iso.rotate(mx, my, z, axis, neg_angle)
        -- Project back to screen space for original shape
        local osx, osy = Iso.project(omx, omy, omz)
        local orig_sx = osx
        local orig_sy = osy
        -- Test against original shape in its local screen space... this doesn't work cleanly.
        -- Instead, check if (omx, omy, omz) projected gives same screen pixel
        -- Better approach: check original shape's hit at the projected position
      end

      -- Simpler: iterate original shape's screen bbox, rotate hits forward
      -- But that's even worse. Let me use the SDF/contains approach.

      -- Fallback: sample z, unproject, inverse-rotate, test containment
      for zi = 80, -20, -1 do
        local z = zi * 0.5
        local mx, my = Iso.unproject(sx, sy, z)
        local omx, omy, omz = Iso.rotate(mx, my, z, axis, neg_angle)
        -- Check if the un-rotated point is inside the original shape
        local osx, osy = Iso.project(omx, omy, omz)
        local ohit = shape:hit(osx, osy)
        if ohit then
          -- Verify the original hit point, when rotated, projects near our pixel
          local rmx, rmy, rmz = Iso.rotate(ohit.mx, ohit.my, ohit.mz, axis, angle)
          local rsx, rsy = Iso.project(rmx, rmy, rmz)
          if abs(rsx - sx) < 1.5 and abs(rsy - sy) < 1.5 then
            local dp = Iso.depth(rmx, rmy, rmz)
            if not best or dp < best.depth then
              local rnx, rny, rnz = Iso.rotate(ohit.nx, ohit.ny, ohit.nz, axis, angle)
              best = mkhit(dp, ohit.face, rnx, rny, rnz, rmx, rmy, rmz)
            end
            break
          end
        end
      end

      return best
    end

    return wrapper
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- CSG OPERATIONS
  -- ═════════════════════════════════════════════════════════════════════

  --- Union: combine two shapes (draw whichever is closer at each pixel).
  function Iso.union(a, b)
    local shape = { type="union" }
    shape.x1 = min(a.x1, b.x1)
    shape.y1 = min(a.y1, b.y1)
    shape.x2 = max(a.x2, b.x2)
    shape.y2 = max(a.y2, b.y2)

    function shape:hit(sx, sy)
      local ha = a:hit(sx, sy)
      local hb = b:hit(sx, sy)
      if ha and hb then
        return ha.depth <= hb.depth and ha or hb
      end
      return ha or hb
    end

    return shape
  end

  --- Subtract: remove shape b's volume from shape a.
  function Iso.subtract(a, b)
    local shape = { type="subtract" }
    shape.x1 = a.x1
    shape.y1 = a.y1
    shape.x2 = a.x2
    shape.y2 = a.y2

    function shape:hit(sx, sy)
      local ha = a:hit(sx, sy)
      if not ha then return nil end
      local hb = b:hit(sx, sy)
      if hb then return nil end  -- subtracted region
      return ha
    end

    return shape
  end

  --- Intersect: keep only the overlapping volume of two shapes.
  function Iso.intersect(a, b)
    local shape = { type="intersect" }
    shape.x1 = max(a.x1, b.x1)
    shape.y1 = max(a.y1, b.y1)
    shape.x2 = min(a.x2, b.x2)
    shape.y2 = min(a.y2, b.y2)

    function shape:hit(sx, sy)
      local ha = a:hit(sx, sy)
      local hb = b:hit(sx, sy)
      if ha and hb then
        return ha.depth <= hb.depth and ha or hb
      end
      return nil
    end

    return shape
  end
end
