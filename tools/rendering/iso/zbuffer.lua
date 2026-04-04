-- zbuffer.lua — Per-pixel depth buffer for isometric compositing
--
-- Injected via: dofile("zbuffer.lua")(Iso)

return function(Iso)

  --- Create a depth buffer for a canvas of size w × h.
  -- Each pixel stores the depth of the closest surface drawn so far.
  -- Undrawn pixels have depth = math.huge (infinity).
  function Iso.zbuffer(w, h)
    local buf = { w = w, h = h }
    for y = 0, h - 1 do
      buf[y] = {}
      for x = 0, w - 1 do
        buf[y][x] = math.huge
      end
    end
    return buf
  end

  --- Test-and-set: returns true if (x, y) should be drawn at this depth.
  -- If true, the depth buffer is updated.  If false, the pixel is occluded.
  function Iso.ztest(zbuf, x, y, depth)
    if x < 0 or x >= zbuf.w or y < 0 or y >= zbuf.h then return false end
    if depth < zbuf[y][x] then
      zbuf[y][x] = depth
      return true
    end
    return false
  end

  --- Read the current depth at a pixel (math.huge if empty).
  function Iso.zread(zbuf, x, y)
    if x < 0 or x >= zbuf.w or y < 0 or y >= zbuf.h then return math.huge end
    return zbuf[y][x]
  end

  --- Check if a pixel has been drawn (depth < infinity).
  function Iso.zfilled(zbuf, x, y)
    if x < 0 or x >= zbuf.w or y < 0 or y >= zbuf.h then return false end
    return zbuf[y][x] < math.huge
  end

  --- Clear the depth buffer back to infinity.
  function Iso.zclear(zbuf)
    for y = 0, zbuf.h - 1 do
      for x = 0, zbuf.w - 1 do
        zbuf[y][x] = math.huge
      end
    end
  end
end
