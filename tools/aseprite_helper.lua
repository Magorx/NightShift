-- aseprite_helper.lua — reusable primitives for generating sprites via Aseprite CLI
-- Usage: local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
--
-- Provides:
--   Color:      H.rgba, H.hex, H.lerp_color, H.brighten, H.with_alpha, H.TRANSPARENT
--   Drawing:    H.px, H.rect, H.rect_outline, H.line, H.circle, H.circle_outline
--               H.bordered_rect, H.shaded_rect, H.gradient_h, H.gradient_v
--               H.checkerboard, H.dither_fill, H.flood_fill
--   Compositing: H.stamp, H.load_stamp, H.flip_h, H.flip_v, H.clear
--   Sprite:     H.new_sprite(w, h, layers, tags) — one-call setup
--   Rendering:  H.render_frames(spr, layers, tags, draw_fn)
--   Export:     H.export_layers(sprite, dir, name) — per-layer horizontal spritesheets
--   Palette:    H.load_palette(name) — load a named palette from tools/palettes/

local H = {}

local REPO = "/Users/gorishniymax/Repos/factor"

-- ═══════════════════════════════════════════════════════════════════════════
-- COLORS
-- ═══════════════════════════════════════════════════════════════════════════

H.TRANSPARENT = app.pixelColor.rgba(0, 0, 0, 0)

function H.rgba(r, g, b, a)
  return app.pixelColor.rgba(r, g, b, a or 255)
end

function H.hex(hex_str)
  -- Accepts "#RRGGBB" or "#RRGGBBAA" or "RRGGBB"
  local s = hex_str:gsub("^#", "")
  local r = tonumber(s:sub(1, 2), 16)
  local g = tonumber(s:sub(3, 4), 16)
  local b = tonumber(s:sub(5, 6), 16)
  local a = 255
  if #s >= 8 then
    a = tonumber(s:sub(7, 8), 16)
  end
  return app.pixelColor.rgba(r, g, b, a)
end

--- Decompose a pixel color into r,g,b,a
function H.decompose(c)
  return app.pixelColor.rgbaR(c),
         app.pixelColor.rgbaG(c),
         app.pixelColor.rgbaB(c),
         app.pixelColor.rgbaA(c)
end

--- Linearly interpolate between two colors
function H.lerp_color(c1, c2, t)
  local r1, g1, b1, a1 = H.decompose(c1)
  local r2, g2, b2, a2 = H.decompose(c2)
  local function mix(a_val, b_val) return math.floor(a_val + (b_val - a_val) * t + 0.5) end
  return H.rgba(mix(r1, r2), mix(g1, g2), mix(b1, b2), mix(a1, a2))
end

--- Brighten/darken a color by a factor (>1 = brighter, <1 = darker)
function H.brighten(c, factor)
  local r, g, b, a = H.decompose(c)
  local function clamp(v) return math.max(0, math.min(255, math.floor(v + 0.5))) end
  return H.rgba(clamp(r * factor), clamp(g * factor), clamp(b * factor), a)
end

--- Shift alpha of a color
function H.with_alpha(c, alpha)
  local r, g, b = H.decompose(c)
  return H.rgba(r, g, b, alpha)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DRAWING PRIMITIVES (operate on an Image)
-- ═══════════════════════════════════════════════════════════════════════════

--- Set a single pixel (bounds-checked)
function H.px(img, x, y, c)
  if x >= 0 and x < img.width and y >= 0 and y < img.height then
    img:drawPixel(x, y, c)
  end
end

--- Filled rectangle (x1,y1) to (x2,y2) inclusive
function H.rect(img, x1, y1, x2, y2, c)
  for y = math.max(0, y1), math.min(img.height - 1, y2) do
    for x = math.max(0, x1), math.min(img.width - 1, x2) do
      img:drawPixel(x, y, c)
    end
  end
end

--- Rectangle outline (1px border)
function H.rect_outline(img, x1, y1, x2, y2, c)
  for x = x1, x2 do
    H.px(img, x, y1, c)
    H.px(img, x, y2, c)
  end
  for y = y1 + 1, y2 - 1 do
    H.px(img, x1, y, c)
    H.px(img, x2, y, c)
  end
end

--- Bordered filled rectangle: fill + outline in one call
function H.bordered_rect(img, x1, y1, x2, y2, fill, border)
  H.rect(img, x1, y1, x2, y2, fill)
  H.rect_outline(img, x1, y1, x2, y2, border)
end

--- Shaded rectangle: fill with highlight on top/left, shadow on bottom/right
function H.shaded_rect(img, x1, y1, x2, y2, fill, highlight, shadow)
  H.rect(img, x1, y1, x2, y2, fill)
  -- Top edge highlight
  for x = x1, x2 do H.px(img, x, y1, highlight) end
  -- Left edge highlight
  for y = y1 + 1, y2 do H.px(img, x1, y, highlight) end
  -- Bottom edge shadow
  for x = x1, x2 do H.px(img, x, y2, shadow) end
  -- Right edge shadow
  for y = y1, y2 - 1 do H.px(img, x2, y, shadow) end
end

--- Bresenham line from (x1,y1) to (x2,y2)
function H.line(img, x1, y1, x2, y2, c)
  local dx = math.abs(x2 - x1)
  local dy = -math.abs(y2 - y1)
  local sx = x1 < x2 and 1 or -1
  local sy = y1 < y2 and 1 or -1
  local err = dx + dy
  while true do
    H.px(img, x1, y1, c)
    if x1 == x2 and y1 == y2 then break end
    local e2 = 2 * err
    if e2 >= dy then err = err + dy; x1 = x1 + sx end
    if e2 <= dx then err = err + dx; y1 = y1 + sy end
  end
end

--- Filled circle (midpoint algorithm)
function H.circle(img, cx, cy, r, c)
  for y = -r, r do
    for x = -r, r do
      if x * x + y * y <= r * r then
        H.px(img, cx + x, cy + y, c)
      end
    end
  end
end

--- Circle outline (midpoint algorithm)
function H.circle_outline(img, cx, cy, r, c)
  local x, y = r, 0
  local err = 1 - r
  while x >= y do
    H.px(img, cx + x, cy + y, c)
    H.px(img, cx - x, cy + y, c)
    H.px(img, cx + x, cy - y, c)
    H.px(img, cx - x, cy - y, c)
    H.px(img, cx + y, cy + x, c)
    H.px(img, cx - y, cy + x, c)
    H.px(img, cx + y, cy - x, c)
    H.px(img, cx - y, cy - x, c)
    y = y + 1
    if err < 0 then
      err = err + 2 * y + 1
    else
      x = x - 1
      err = err + 2 * (y - x) + 1
    end
  end
end

--- Horizontal gradient fill between two colors
function H.gradient_h(img, x1, y1, x2, y2, c_left, c_right)
  local w = x2 - x1
  if w <= 0 then return end
  for x = x1, x2 do
    local t = (x - x1) / w
    local c = H.lerp_color(c_left, c_right, t)
    for y = y1, y2 do
      H.px(img, x, y, c)
    end
  end
end

--- Vertical gradient fill between two colors
function H.gradient_v(img, x1, y1, x2, y2, c_top, c_bottom)
  local h = y2 - y1
  if h <= 0 then return end
  for y = y1, y2 do
    local t = (y - y1) / h
    local c = H.lerp_color(c_top, c_bottom, t)
    for x = x1, x2 do
      H.px(img, x, y, c)
    end
  end
end

--- Checkerboard pattern fill
function H.checkerboard(img, x1, y1, x2, y2, c1, c2, size)
  size = size or 1
  for y = y1, y2 do
    for x = x1, x2 do
      local checker = (math.floor((x - x1) / size) + math.floor((y - y1) / size)) % 2
      H.px(img, x, y, checker == 0 and c1 or c2)
    end
  end
end

--- Ordered dither fill (2x2 Bayer) between two colors
function H.dither_fill(img, x1, y1, x2, y2, c1, c2, threshold)
  threshold = threshold or 0.5
  local bayer = {{0.0, 0.5}, {0.75, 0.25}}
  for y = y1, y2 do
    for x = x1, x2 do
      local bx = (x % 2) + 1
      local by = (y % 2) + 1
      local c = bayer[by][bx] < threshold and c1 or c2
      H.px(img, x, y, c)
    end
  end
end

--- Flood fill from a point (replaces target_color with fill_color)
function H.flood_fill(img, sx, sy, fill_color)
  if sx < 0 or sx >= img.width or sy < 0 or sy >= img.height then return end
  local target = img:getPixel(sx, sy)
  if target == fill_color then return end
  local stack = {{sx, sy}}
  while #stack > 0 do
    local pt = table.remove(stack)
    local x, y = pt[1], pt[2]
    if x >= 0 and x < img.width and y >= 0 and y < img.height and img:getPixel(x, y) == target then
      img:drawPixel(x, y, fill_color)
      table.insert(stack, {x + 1, y})
      table.insert(stack, {x - 1, y})
      table.insert(stack, {x, y + 1})
      table.insert(stack, {x, y - 1})
    end
  end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- COMPOSITING (uses native Image:drawImage for performance)
-- ═══════════════════════════════════════════════════════════════════════════

--- Clear an image (or a sub-region). Uses native Image:clear().
function H.clear(img, x1, y1, x2, y2)
  if x1 then
    img:clear(Rectangle(x1, y1, x2 - x1 + 1, y2 - y1 + 1))
  else
    img:clear()
  end
end

--- Composite src image onto dst at (x,y) with optional opacity (0-255).
--- Uses native alpha-blended drawImage — much faster than pixel-by-pixel.
function H.stamp(dst, src, x, y, opacity)
  dst:drawImage(src, Point(x or 0, y or 0), opacity or 255)
end

--- Load a PNG file as a reusable Image (stamp/texture).
--- Cache loaded images to avoid re-reading the same file.
H._stamp_cache = {}
function H.load_stamp(path)
  if not H._stamp_cache[path] then
    H._stamp_cache[path] = Image{ fromFile = path }
  end
  return H._stamp_cache[path]
end

--- Return a horizontally flipped copy of an image.
function H.flip_h(img)
  local copy = img:clone()
  copy:flip(FlipType.HORIZONTAL)
  return copy
end

--- Return a vertically flipped copy of an image.
function H.flip_v(img)
  local copy = img:clone()
  copy:flip(FlipType.VERTICAL)
  return copy
end

--- Create a small image (detail stamp) by drawing into it.
--- draw_fn(img) receives a fresh w x h image to draw on.
--- Returns the image for use with H.stamp().
function H.make_stamp(w, h, draw_fn)
  local img = Image(w, h, ColorMode.RGB)
  draw_fn(img)
  return img
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SPRITE SETUP
-- ═══════════════════════════════════════════════════════════════════════════

--- Create a sprite with layers, frames, and tags in one call.
---
--- layers: array of layer name strings, e.g. {"base", "top"}
---         First name becomes the default layer (renamed). Rest are added.
---         Order = bottom to top (first = lowest z).
---
--- tags: array of {name=, from=, to=, duration=}, e.g.
---       { {name="idle", from=1, to=2, duration=0.2},
---         {name="active", from=3, to=6, duration=0.15} }
---       'from'/'to' are 1-based frame numbers. Total frames = max 'to' across all tags.
---       'duration' sets frame duration for frames in this tag's range.
---
--- Returns: sprite, {layer_name = layer_obj}, {tag_name = tag_obj}
function H.new_sprite(w, h, layers, tags)
  local spr = Sprite(w, h, ColorMode.RGB)
  app.activeSprite = spr

  -- Determine total frame count
  local max_frame = 1
  for _, t in ipairs(tags or {}) do
    if t.to > max_frame then max_frame = t.to end
  end

  -- Setup layers: rename default, add rest
  local layer_map = {}
  local base = spr.layers[1]
  -- Delete default cel
  for _, cel in ipairs(base.cels) do spr:deleteCel(cel) end

  if layers and #layers > 0 then
    base.name = layers[1]
    layer_map[layers[1]] = base
    for i = 2, #layers do
      local l = spr:newLayer()
      l.name = layers[i]
      layer_map[layers[i]] = l
    end
  else
    layer_map["default"] = base
  end

  -- Setup frames
  spr.frames[1].duration = 0.15 -- default
  for i = 2, max_frame do
    spr:newEmptyFrame(i)
  end

  -- Apply tag durations to frames and create tags
  local tag_map = {}
  for _, t in ipairs(tags or {}) do
    -- Set frame durations
    if t.duration then
      for i = t.from, t.to do
        if spr.frames[i] then
          spr.frames[i].duration = t.duration
        end
      end
    end
    local tag = spr:newTag(t.from, t.to)
    tag.name = t.name
    tag_map[t.name] = tag
  end

  return spr, layer_map, tag_map
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FRAME RENDERING
-- ═══════════════════════════════════════════════════════════════════════════

--- Iterate frames and call a draw function per layer per frame.
--- Automatically creates cels with fresh images.
---
--- draw_fn(img, layer_name, frame_index, tag_name, phase)
---   img:        Image to draw on (W x H, transparent)
---   layer_name: string
---   frame_index: 1-based
---   tag_name:   which tag this frame belongs to (or nil)
---   phase:      0-based index within the tag (for animation variation)
---
function H.render_frames(spr, layer_map, tags, draw_fn)
  -- Build frame->tag lookup
  local frame_tag = {}
  local frame_phase = {}
  for _, t in ipairs(tags or {}) do
    for i = t.from, t.to do
      frame_tag[i] = t.name
      frame_phase[i] = i - t.from
    end
  end

  for i, frame in ipairs(spr.frames) do
    local tag_name = frame_tag[i]
    local phase = frame_phase[i] or 0
    for name, layer in pairs(layer_map) do
      local img = Image(spr.width, spr.height, ColorMode.RGB)
      draw_fn(img, name, i, tag_name, phase)
      spr:newCel(layer, frame, img, Point(0, 0))
    end
  end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORT
-- ═══════════════════════════════════════════════════════════════════════════

--- Export per-layer horizontal spritesheets.
--- Outputs: {dir}/{name}-{layer_name}.png for each layer.
--- Returns list of exported paths.
function H.export_layers(spr, dir, name)
  local paths = {}
  for _, layer in ipairs(spr.layers) do
    local sheet = Image(spr.width * #spr.frames, spr.height, ColorMode.RGB)
    for i, frame in ipairs(spr.frames) do
      local cel = layer:cel(frame.frameNumber)
      if cel then
        local offset_x = (i - 1) * spr.width + cel.position.x
        local offset_y = cel.position.y
        sheet:drawImage(cel.image, Point(offset_x, offset_y))
      end
    end
    local path = dir .. "/" .. name .. "-" .. layer.name .. ".png"
    sheet:saveAs(path)
    table.insert(paths, path)
    print("Exported: " .. path)
  end
  return paths
end

--- Save .aseprite and export layer sheets in one call.
function H.save_and_export(spr, dir, name)
  spr:saveAs(dir .. "/" .. name .. ".aseprite")
  local paths = H.export_layers(spr, dir, name)
  spr:close()
  return paths
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PALETTES
-- ═══════════════════════════════════════════════════════════════════════════

--- Load a palette table from tools/palettes/{name}.lua
--- Palette files should return a table of named colors, e.g.:
---   return { outline = "#191412", body = "#46372D", ... }
--- Returns a table with the same keys but converted to pixel colors.
function H.load_palette(name)
  local path = REPO .. "/tools/palettes/" .. name .. ".lua"
  local raw = dofile(path)
  local pal = {}
  for k, v in pairs(raw) do
    if type(v) == "string" then
      pal[k] = H.hex(v)
    else
      pal[k] = v
    end
  end
  return pal
end

print("[aseprite_helper] loaded")
return H
