-- scene.lua — Multi-shape composition with depth-sorted rendering
--
-- A scene holds shapes at 3D positions, renders them with automatic
-- occlusion via the depth buffer, applies shading and textures, then
-- draws outlines.
--
-- Lighting: scenes have a light list. If no lights are added explicitly,
-- the default setup (ambient 0.35 + directional 0.65) is used, matching
-- the old Iso.shade_color behavior.
--
-- Injected via: dofile("scene.lua")(Iso)

return function(Iso)
  local floor = math.floor
  local ceil  = math.ceil
  local min   = math.min
  local max   = math.max

  local H  -- set by init

  -- ═════════════════════════════════════════════════════════════════════
  -- SCENE OBJECT
  -- ═════════════════════════════════════════════════════════════════════

  --- Create a scene for a given canvas size.
  -- @param w, h  canvas dimensions in pixels
  -- @param origin_x, origin_y  screen position of model origin (default: center-bottom)
  function Iso.scene(w, h, origin_x, origin_y)
    origin_x = origin_x or floor(w / 2)
    origin_y = origin_y or floor(h * 0.75)

    local scene = {
      w = w, h = h,
      ox = origin_x, oy = origin_y,
      items = {},
      lights = {},
    }

    --- Add a shape to the scene.
    -- @param shape   a primitive from Iso.box(), Iso.cylinder(), etc.
    -- @param pos     {x, y, z} position in model space (default {0,0,0})
    -- @param colors  color table: { base=..., outline=..., [face_name]=... }
    -- @param opts    optional: { texture=fn, shading={specular,...} }
    function scene:add(shape, pos, colors, opts)
      pos = pos or {0, 0, 0}
      table.insert(self.items, {
        shape   = shape,
        pos     = pos,
        colors  = colors or {},
        opts    = opts or {},
      })
    end

    --- Add a light to the scene.
    -- @param light  a light from Iso.light_ambient(), Iso.light_directional(), Iso.light_point()
    function scene:add_light(light)
      table.insert(self.lights, light)
    end

    --- Resolve the final color for a hit, using the scene's light list.
    -- Handles explicit face colors, auto-shading from base color, and textures.
    local function resolve_lit(colors, face, hit, world_pos, lights, shading_opts)
      -- Explicit face color — use as-is (no lighting)
      if colors[face] then
        return colors[face]
      end

      -- Need a base color to light
      local base = colors.base or colors.top or colors.body
      if not base then return 0 end

      -- Compute world-space position of the hit point
      local wmx = hit.mx + world_pos[1]
      local wmy = hit.my + world_pos[2]
      local wmz = hit.mz + world_pos[3]

      -- Accumulate light
      local lr, lg, lb = Iso.accumulate_light(
        lights, hit.nx, hit.ny, hit.nz, wmx, wmy, wmz, shading_opts
      )

      return Iso.apply_light(base, lr, lg, lb)
    end

    --- Render all shapes onto an Aseprite Image.
    -- @param img   Image to draw on
    -- @param zbuf  optional pre-existing zbuffer (created if nil)
    -- @return zbuf  the depth buffer (for outline pass or further compositing)
    function scene:render(img, zbuf)
      H = Iso._H
      if not H then error("Iso._set_helper() not called — load aseprite_helper first") end

      zbuf = zbuf or Iso.zbuffer(self.w, self.h)

      -- Use default lights if none added
      local lights = #self.lights > 0 and self.lights or Iso.default_lights()

      for _, item in ipairs(self.items) do
        local shape  = item.shape
        local pos    = item.pos
        local colors = item.colors
        local opts   = item.opts

        -- Screen offset of the shape's model origin
        local sox, soy = Iso.project(pos[1], pos[2], pos[3])
        sox = sox + self.ox
        soy = soy + self.oy

        -- Screen bounds (clipped to canvas)
        local sx1 = max(0, floor(sox + shape.x1))
        local sy1 = max(0, floor(soy + shape.y1))
        local sx2 = min(self.w - 1, ceil(sox + shape.x2))
        local sy2 = min(self.h - 1, ceil(soy + shape.y2))

        -- Render each pixel
        for sy = sy1, sy2 do
          for sx = sx1, sx2 do
            local hit = shape:hit(sx - sox, sy - soy)
            if hit then
              -- Adjust depth for world position
              local world_depth = hit.depth + Iso.depth(pos[1], pos[2], pos[3])

              if Iso.ztest(zbuf, sx, sy, world_depth) then
                -- Resolve color with scene lighting
                local c = resolve_lit(
                  colors, hit.face, hit, pos, lights, opts.shading
                )

                -- Apply texture if provided
                if opts.texture then
                  c = opts.texture(hit, c)
                end

                H.px(img, sx, sy, c)
              end
            end
          end
        end
      end

      return zbuf
    end

    --- Draw outlines for all rendered geometry.
    -- Call after render().
    function scene:draw_outlines(img, zbuf, outline_color, depth_threshold)
      H = Iso._H
      if not H then return end
      outline_color = outline_color or H.hex("#191412")
      Iso.draw_outlines(img, zbuf, outline_color, depth_threshold)
    end

    --- Convenience: render + outlines in one call.
    function scene:draw(img, outline_color, depth_threshold)
      local zbuf = self:render(img)
      if outline_color ~= false then
        self:draw_outlines(img, zbuf, outline_color, depth_threshold)
      end
      return zbuf
    end

    return scene
  end

  -- ═════════════════════════════════════════════════════════════════════
  -- QUICK RENDER (no scene setup needed — uses legacy shading for compat)
  -- ═════════════════════════════════════════════════════════════════════

  --- Render a single shape onto an image at a given screen position.
  -- Uses the old resolve_color path (global Iso.light direction).
  -- For lit rendering, use a scene with add_light().
  function Iso.render_shape(img, shape, sx, sy, colors, opts)
    H = Iso._H
    if not H then error("Iso._set_helper() not called") end

    opts = opts or {}
    local zbuf = Iso.zbuffer(img.width, img.height)

    local x1 = max(0, floor(sx + shape.x1))
    local y1 = max(0, floor(sy + shape.y1))
    local x2 = min(img.width - 1, ceil(sx + shape.x2))
    local y2 = min(img.height - 1, ceil(sy + shape.y2))

    for py = y1, y2 do
      for px = x1, x2 do
        local hit = shape:hit(px - sx, py - sy)
        if hit and Iso.ztest(zbuf, px, py, hit.depth) then
          local c = Iso.resolve_color(colors, hit.face, hit.nx, hit.ny, hit.nz, opts.shading)
          if opts.texture then
            c = opts.texture(hit, c)
          end
          H.px(img, px, py, c)
        end
      end
    end

    -- Outlines
    if colors.outline then
      Iso.draw_outlines(img, zbuf, colors.outline, opts.depth_threshold)
    end

    return zbuf
  end
end
