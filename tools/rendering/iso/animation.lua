-- animation.lua — Animation helpers: rotation, oscillation, particles, scrolling
--
-- These produce values or shape transforms driven by a frame index.
-- Injected via: dofile("animation.lua")(Iso)

return function(Iso)
  local floor = math.floor
  local sin   = math.sin
  local cos   = math.cos
  local sqrt  = math.sqrt
  local abs   = math.abs
  local pi    = math.pi
  local max   = math.max
  local min   = math.min
  local fmod  = math.fmod

  -- ═════════════════════════════════════════════════════════════════════
  -- VALUE GENERATORS (return a number for the given frame)
  -- ═════════════════════════════════════════════════════════════════════

  --- Sinusoidal oscillation between lo and hi.
  -- @param lo, hi   value range
  -- @param period   frames per full cycle
  -- @param phase    offset in frames (default 0)
  function Iso.anim_oscillate(frame, lo, hi, period, phase)
    phase = phase or 0
    local t = sin(2 * pi * (frame + phase) / period) * 0.5 + 0.5
    return lo + (hi - lo) * t
  end

  --- Linear ramp that wraps: 0→1→0→1 over 'period' frames.
  function Iso.anim_sawtooth(frame, period)
    return fmod(frame, period) / period
  end

  --- Triangle wave: 0→1→0 over 'period' frames.
  function Iso.anim_triangle(frame, period)
    local t = fmod(frame, period) / period
    return t < 0.5 and (t * 2) or (2 - t * 2)
  end

  --- Step function: returns floor(frame / step_size) mod steps.
  -- Useful for discrete animation phases.
  function Iso.anim_step(frame, steps, step_size)
    step_size = step_size or 1
    return floor(frame / step_size) % steps
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- ROTATION ANGLE (for gears, fans, etc.)
  -- ═════════════════════════════════════════════════════════════════════

  --- Rotation angle in radians for a given frame.
  -- @param rpm       revolutions per N frames
  -- @param frames_per_rev  how many frames for one full revolution
  function Iso.anim_rotation(frame, frames_per_rev)
    frames_per_rev = frames_per_rev or 8
    return 2 * pi * frame / frames_per_rev
  end

  --- Create a gear shape at a specific animation frame.
  -- Convenience: returns Iso.gear with the angle set for the frame.
  function Iso.anim_gear(outer_r, inner_r, hole_r, teeth, thickness, frame, frames_per_rev)
    local angle = Iso.anim_rotation(frame, frames_per_rev)
    return Iso.gear(outer_r, inner_r, hole_r, teeth, thickness, angle)
  end

  --- Create a fan shape at a specific animation frame.
  function Iso.anim_fan(blades, radius, blade_width, thickness, hub_r, frame, frames_per_rev)
    local angle = Iso.anim_rotation(frame, frames_per_rev)
    return Iso.fan(blades, radius, blade_width, thickness, hub_r, angle)
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- SHAKE / VIBRATION
  -- ═════════════════════════════════════════════════════════════════════

  --- Random-looking shake offset for a frame.
  -- Returns dx, dy in screen pixels.
  function Iso.anim_shake(frame, amplitude)
    amplitude = amplitude or 1
    -- Use hash for deterministic pseudo-random
    local n = frame * 374761393
    n = (n ~ (n >> 13)) * 1274126177
    local dx = ((n % 256) / 128 - 1) * amplitude
    n = n * 668265263
    n = (n ~ (n >> 13)) * 1274126177
    local dy = ((n % 256) / 128 - 1) * amplitude
    return dx, dy
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- PARTICLE SYSTEM
  -- ═════════════════════════════════════════════════════════════════════

  --- Create a particle emitter configuration.
  -- @param opts table:
  --   origin:    {x, y, z}  emission point in model space
  --   velocity:  {x, y, z}  base velocity per frame
  --   spread:    degrees of random spread (default 15)
  --   gravity:   z acceleration per frame (default 0, negative = rise)
  --   lifetime:  frames before particle dies (default 8)
  --   size:      {min, max} pixel size (default {1, 2})
  --   count:     particles emitted per frame (default 1)
  --   seed:      random seed for reproducibility
  function Iso.particle_emitter(opts)
    return {
      origin   = opts.origin   or {0, 0, 0},
      velocity = opts.velocity or {0, 0, 1},
      spread   = (opts.spread or 15) * pi / 180,
      gravity  = opts.gravity  or 0,
      lifetime = opts.lifetime or 8,
      size     = opts.size     or {1, 2},
      count    = opts.count    or 1,
      seed     = opts.seed     or 42,
    }
  end

  --- Generate particle positions for a given frame.
  -- Returns a list of {sx, sy, age, size} in screen coordinates.
  -- @param emitter  config from particle_emitter()
  -- @param frame    current frame number
  -- @param ox, oy   screen offset of the emitter's parent
  function Iso.particle_positions(emitter, frame, ox, oy)
    ox = ox or 0
    oy = oy or 0
    local particles = {}
    local rng_base = emitter.seed

    for birth = max(0, frame - emitter.lifetime + 1), frame do
      for pi_idx = 0, emitter.count - 1 do
        local age = frame - birth
        -- Deterministic random from birth frame + index
        local rng = (birth * 374761393 + pi_idx * 668265263 + rng_base) % 2147483647
        local function nrand()
          rng = (rng * 1103515245 + 12345) % 2147483647
          return (rng % 10000) / 10000  -- 0..1
        end

        -- Random spread offset
        local spread_x = (nrand() - 0.5) * 2 * emitter.spread
        local spread_y = (nrand() - 0.5) * 2 * emitter.spread

        -- Position
        local vx = emitter.velocity[1] + spread_x
        local vy = emitter.velocity[2] + spread_y
        local vz = emitter.velocity[3]

        local px = emitter.origin[1] + vx * age
        local py = emitter.origin[2] + vy * age
        local pz = emitter.origin[3] + vz * age + 0.5 * emitter.gravity * age * age

        -- Project to screen
        local sx, sy = Iso.project(px, py, pz)
        sx = sx + ox
        sy = sy + oy

        -- Size (shrinks with age)
        local t = age / emitter.lifetime
        local sz = emitter.size[1] + (emitter.size[2] - emitter.size[1]) * (1 - t)

        table.insert(particles, {
          sx = floor(sx + 0.5),
          sy = floor(sy + 0.5),
          age = age,
          t = t,  -- 0..1 normalized age (0=born, 1=dead)
          size = max(1, floor(sz + 0.5)),
        })
      end
    end

    return particles
  end

  --- Draw particles onto an image.
  -- @param colors  list of colors for age interpolation (young → old)
  function Iso.draw_particles(img, particles, colors)
    if not Iso._H then return end
    local H = Iso._H

    for _, p in ipairs(particles) do
      -- Interpolate color from age
      local ci = min(#colors, max(1, floor(p.t * (#colors - 1)) + 1))
      local c = colors[ci]

      if p.size <= 1 then
        H.px(img, p.sx, p.sy, c)
      else
        H.circle(img, p.sx, p.sy, floor(p.size / 2), c)
      end
    end
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- TEXTURE SCROLLING (for conveyor-like effects)
  -- ═════════════════════════════════════════════════════════════════════

  --- Returns a texture offset for scrolling surfaces.
  -- direction: "u" or "v"
  -- speed: model units per frame
  function Iso.anim_scroll(frame, speed, direction)
    direction = direction or "u"
    return frame * speed
  end
end
