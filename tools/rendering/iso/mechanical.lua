-- mechanical.lua — Compound mechanical shapes: gears, pipes, pistons, fans
--
-- Built on top of primitives.  Each returns a shape with :hit(sx, sy).
-- Injected via: dofile("mechanical.lua")(Iso)

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
  local fmod  = math.fmod

  local function mkhit(depth, face, nx, ny, nz, mx, my, mz)
    return { depth=depth, face=face, nx=nx, ny=ny, nz=nz, mx=mx, my=my, mz=mz }
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- GEAR / COG (vertical axis, centered at XY origin)
  --
  -- outer_r:     outer radius (tip of teeth)
  -- inner_r:     inner radius (valley between teeth)
  -- hole_r:      axle hole radius (0 = no hole)
  -- teeth:       number of teeth
  -- thickness:   height (Z extent)
  -- angle:       rotation offset in radians (for animation)
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.gear(outer_r, inner_r, hole_r, teeth, thickness, angle)
    hole_r    = hole_r or 0
    teeth     = teeth or 8
    thickness = thickness or 4
    angle     = angle or 0

    local shape = { type="gear", outer_r=outer_r, inner_r=inner_r,
                    hole_r=hole_r, teeth=teeth, thickness=thickness, angle=angle }

    local d = outer_r + 2
    local corners = {
      {-d,-d,0},{d,-d,0},{-d,d,0},{d,d,0},
      {-d,-d,thickness},{d,-d,thickness},{-d,d,thickness},{d,d,thickness},
    }
    shape.x1, shape.y1, shape.x2, shape.y2 = Iso.bbox(corners)

    -- Gear profile: given angle theta, return the outer boundary radius
    local tooth_angle = 2 * pi / teeth
    local half_tooth  = tooth_angle * 0.35  -- teeth are ~70% of tooth pitch

    local function gear_radius(theta)
      -- Offset by animation angle
      local t = fmod(theta - angle + 100 * pi, tooth_angle)
      if t < half_tooth or t > tooth_angle - half_tooth then
        return outer_r  -- tooth peak
      else
        return inner_r  -- valley
      end
    end

    -- Check if (mx, my) at given z is inside the gear cross-section
    local function in_gear(mx, my)
      local dist = sqrt(mx*mx + my*my)
      if dist < hole_r - 0.5 then return false end  -- inside axle hole
      local theta = atan2(my, mx)
      local gr = gear_radius(theta)
      return dist <= gr + 0.5
    end

    function shape:hit(sx, sy)
      local best = nil

      -- Top face (z = thickness)
      local mx, my = Iso.unproject(sx, sy, thickness)
      if in_gear(mx, my) then
        local dp = Iso.depth(mx, my, thickness)
        if not best or dp < best.depth then
          best = mkhit(dp, "top", 0, 0, 1, mx, my, thickness)
        end
      end

      -- Side faces: use ray-cylinder approach but with gear profile
      -- Sample along view ray at z=0 base
      local mx0, my0 = Iso.unproject(sx, sy, 0)
      local vx, vy, vz = Iso._vx, Iso._vy, Iso._vz

      -- Check body by sampling t values along the ray
      local steps = max(12, floor(outer_r))
      for ti = 0, steps do
        local t = -outer_r + (2 * outer_r) * ti / steps
        local bx, by, bz = mx0 + t*vx, my0 + t*vy, t*vz
        if bz >= -0.5 and bz <= thickness + 0.5 then
          local dist = sqrt(bx*bx + by*by)
          local theta = atan2(by, bx)
          local gr = gear_radius(theta)
          -- On the outer surface if dist ≈ gr (within 1 pixel)
          if abs(dist - gr) < 1.5 and dist >= hole_r - 0.5 then
            local dp = Iso.depth(bx, by, bz)
            if not best or dp < best.depth then
              local len = max(dist, 0.01)
              best = mkhit(dp, "body", bx/len, by/len, 0, bx, by, bz)
            end
            break
          end
          -- On the inner hole surface
          if hole_r > 0 and abs(dist - hole_r) < 1.5 and dist <= gr + 0.5 then
            local dp = Iso.depth(bx, by, bz)
            if not best or dp < best.depth then
              local len = max(dist, 0.01)
              best = mkhit(dp, "hole", -bx/len, -by/len, 0, bx, by, bz)
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
  -- PIPE along a model axis
  --
  -- Pipe is a cylinder segment with optional wall thickness (hollow).
  -- axis: "x" or "y"
  -- length, outer_r, wall_thickness (0 = solid)
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.pipe(axis, length, outer_r, wall)
    wall = wall or 0
    local inner_r = wall > 0 and (outer_r - wall) or 0
    local shape = { type="pipe", axis=axis, length=length,
                    outer_r=outer_r, inner_r=inner_r }

    local d = outer_r + 2
    local corners
    if axis == "x" then
      corners = {
        {0,-d,-d},{length,-d,-d},{0,d,-d},{length,d,-d},
        {0,-d,d},{length,-d,d},{0,d,d},{length,d,d},
      }
    else  -- "y"
      corners = {
        {-d,0,-d},{-d,length,-d},{d,0,-d},{d,length,-d},
        {-d,0,d},{-d,length,d},{d,0,d},{d,length,d},
      }
    end
    shape.x1, shape.y1, shape.x2, shape.y2 = Iso.bbox(corners)

    function shape:hit(sx, sy)
      -- Transform to make the pipe along Z, then use cylinder logic
      -- For pipe along X: swap X↔Z in model space
      -- For pipe along Y: swap Y↔Z in model space

      local best = nil
      -- Use slice approach: for each position along the pipe axis,
      -- check if the cross-section (circle) contains the unprojected point
      local steps = max(12, floor(length))
      for ai = steps, 0, -1 do
        local a = length * ai / steps
        -- Unproject at different assumptions based on axis
        if axis == "x" then
          -- At model x = a, the pipe cross-section is a circle in YZ
          -- Screen coords at x=a: sx_base = a*XX, sy_base = a*XY
          -- Remaining: sy - sy_base = my*YY + mz*ZY, sx - sx_base = my*YX + mz*ZX
          local rsx = sx - a * Iso.XX
          local rsy = sy - a * Iso.XY
          local det = Iso.YX * Iso.ZY - Iso.ZX * Iso.YY
          if abs(det) > 1e-6 then
            local my = (Iso.ZY * rsx - Iso.ZX * rsy) / det
            local mz = (Iso.YX * rsy - Iso.YY * rsx) / det
            local dist = sqrt(my*my + mz*mz)
            if dist <= outer_r + 0.5 and (inner_r <= 0 or dist >= inner_r - 0.5) then
              local dp = Iso.depth(a, my, mz)
              if not best or dp < best.depth then
                -- Determine face
                local face = "body"
                local nnx, nny, nnz = 0, my/max(dist,0.01), mz/max(dist,0.01)
                if ai == steps then
                  face = "cap_end"
                  nnx, nny, nnz = 1, 0, 0
                elseif ai == 0 then
                  face = "cap_start"
                  nnx, nny, nnz = -1, 0, 0
                end
                best = mkhit(dp, face, nnx, nny, nnz, a, my, mz)
              end
              if face == "body" then break end
            end
          end
        else  -- "y"
          local rsx = sx - a * Iso.YX
          local rsy = sy - a * Iso.YY
          local det = Iso.XX * Iso.ZY - Iso.ZX * Iso.XY
          if abs(det) > 1e-6 then
            local mx = (Iso.ZY * rsx - Iso.ZX * rsy) / det
            local mz = (Iso.XX * rsy - Iso.XY * rsx) / det
            local dist = sqrt(mx*mx + mz*mz)
            if dist <= outer_r + 0.5 and (inner_r <= 0 or dist >= inner_r - 0.5) then
              local dp = Iso.depth(mx, a, mz)
              if not best or dp < best.depth then
                local face = "body"
                local nnx, nny, nnz = mx/max(dist,0.01), 0, mz/max(dist,0.01)
                if ai == steps then
                  face = "cap_end"
                  nnx, nny, nnz = 0, 1, 0
                elseif ai == 0 then
                  face = "cap_start"
                  nnx, nny, nnz = 0, -1, 0
                end
                best = mkhit(dp, face, nnx, nny, nnz, mx, a, mz)
              end
              if face == "body" then break end
            end
          end
        end
      end

      return best
    end

    return shape
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- PIPE ELBOW (90° bend connecting two pipe directions)
  --
  -- Connects pipe_x to pipe_y (or specified axes) with a curved joint.
  -- bend_r: radius of the bend centerline
  -- pipe_r: pipe cross-section radius
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.pipe_elbow(bend_r, pipe_r)
    local shape = { type="pipe_elbow", bend_r=bend_r, pipe_r=pipe_r }
    local d = bend_r + pipe_r + 2
    local corners = {
      {-d,-d,-d},{d,-d,-d},{-d,d,-d},{d,d,-d},
      {-d,-d,d},{d,-d,d},{-d,d,d},{d,d,d},
    }
    shape.x1, shape.y1, shape.x2, shape.y2 = Iso.bbox(corners)

    function shape:hit(sx, sy)
      -- Bend is a quarter-torus in the XY plane
      -- Centerline: arc from (bend_r, 0, 0) to (0, bend_r, 0) at radius bend_r
      local best = nil
      local steps = 16

      for zi = floor(pipe_r), -floor(pipe_r), -1 do
        local z = zi
        if abs(z) <= pipe_r then
          local mx, my = Iso.unproject(sx, sy, z)
          -- Distance from the bend arc in XY plane
          local dist_xy = sqrt(mx*mx + my*my)
          local arc_dist = abs(dist_xy - bend_r)
          local total_dist = sqrt(arc_dist*arc_dist + z*z)

          -- Check angle is in the 0..90° range (first quadrant)
          local theta = atan2(my, mx)
          if theta >= -0.1 and theta <= pi/2 + 0.1 and total_dist <= pipe_r + 0.5 then
            local dp = Iso.depth(mx, my, z)
            if not best or dp < best.depth then
              local nx = dist_xy > 0.01 and (mx/dist_xy) * (dist_xy - bend_r) / max(total_dist, 0.01) or 0
              local ny = dist_xy > 0.01 and (my/dist_xy) * (dist_xy - bend_r) / max(total_dist, 0.01) or 0
              local nz = z / max(total_dist, 0.01)
              best = mkhit(dp, "body", nx, ny, nz, mx, my, z)
            end
          end
        end
      end

      return best
    end

    return shape
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- PISTON (cylinder + rod sliding in a sleeve)
  --
  -- sleeve_r:    outer sleeve radius
  -- rod_r:       inner rod radius
  -- sleeve_h:    sleeve height
  -- rod_extend:  how far the rod extends above sleeve (animated)
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.piston(sleeve_r, rod_r, sleeve_h, rod_extend)
    rod_extend = rod_extend or 0
    local total_h = sleeve_h + max(0, rod_extend)

    local sleeve = Iso.cylinder(sleeve_r, sleeve_h)
    local rod = Iso.translate(Iso.cylinder(rod_r, rod_extend + 2), 0, 0, sleeve_h - 2)

    local shape = Iso.union(sleeve, rod)
    shape.type = "piston"
    return shape
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- AXLE (thin cylinder, along X or Y axis)
  -- Convenience wrapper around pipe() with solid cross-section.
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.axle(axis, length, radius)
    radius = radius or 1.5
    local shape = Iso.pipe(axis, length, radius, 0)
    shape.type = "axle"
    return shape
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- FAN / PROPELLER (blades rotating around Z axis)
  --
  -- blades:  number of blades
  -- radius:  blade length
  -- width:   blade width (angular, in radians)
  -- thickness: blade thickness (Z)
  -- hub_r:   hub radius
  -- angle:   rotation offset (for animation)
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.fan(blades, radius, blade_width, thickness, hub_r, angle)
    blades      = blades or 3
    blade_width = blade_width or 0.3
    thickness   = thickness or 2
    hub_r       = hub_r or 3
    angle       = angle or 0

    local shape = { type="fan" }
    local d = radius + 2
    local corners = {
      {-d,-d,0},{d,-d,0},{-d,d,0},{d,d,0},
      {-d,-d,thickness},{d,-d,thickness},{-d,d,thickness},{d,d,thickness},
    }
    shape.x1, shape.y1, shape.x2, shape.y2 = Iso.bbox(corners)

    local blade_angle = 2 * pi / blades

    local function in_fan(mx, my)
      local dist = sqrt(mx*mx + my*my)
      if dist <= hub_r + 0.5 then return true end  -- hub
      if dist > radius + 0.5 then return false end
      local theta = atan2(my, mx)
      for i = 0, blades - 1 do
        local ba = angle + i * blade_angle
        local diff = fmod(theta - ba + 3*pi, 2*pi) - pi
        if abs(diff) <= blade_width / 2 then
          return true
        end
      end
      return false
    end

    function shape:hit(sx, sy)
      local best = nil

      -- Top face
      local mx, my = Iso.unproject(sx, sy, thickness)
      if in_fan(mx, my) then
        local dp = Iso.depth(mx, my, thickness)
        best = mkhit(dp, "top", 0, 0, 1, mx, my, thickness)
      end

      -- Body (thin, so just check z=0 to thickness)
      local mx0, my0 = Iso.unproject(sx, sy, 0)
      if not best and in_fan(mx0, my0) then
        -- Check if visible on the side
        local vx, vy, vz = Iso._vx, Iso._vy, Iso._vz
        for ti = 0, floor(thickness * 2) do
          local t = ti * 0.5
          local bx, by, bz = mx0 + t*vx/(abs(vz)+0.01), my0 + t*vy/(abs(vz)+0.01), t
          if bz >= 0 and bz <= thickness and in_fan(bx, by) then
            local dp = Iso.depth(bx, by, bz)
            if not best or dp < best.depth then
              local dist = sqrt(bx*bx + by*by)
              best = mkhit(dp, "body", bx/max(dist,0.01), by/max(dist,0.01), 0, bx, by, bz)
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
  -- VALVE WHEEL (small gear-like shape on a pipe)
  -- Convenience: gear with many thin teeth = spoked wheel
  -- ═════════════════════════════════════════════════════════════════════

  function Iso.valve_wheel(radius, spokes, thickness, angle)
    spokes    = spokes or 6
    thickness = thickness or 2
    angle     = angle or 0
    -- A valve wheel is a thin ring with spokes
    local hub = Iso.cylinder(radius * 0.2, thickness)
    local rim = Iso.subtract(
      Iso.cylinder(radius, thickness),
      Iso.cylinder(radius - 1, thickness + 1)
    )
    local wheel = Iso.union(hub, rim)
    -- Add spokes as thin boxes
    for i = 0, spokes - 1 do
      local a = angle + i * 2 * pi / spokes
      -- Spoke: thin box rotated
      -- Approximate with a gear that has spoke-like teeth
    end
    -- Simpler: just use the gear with large inner_r
    return Iso.gear(radius, radius * 0.7, radius * 0.15, spokes, thickness, angle)
  end
end
