-- Generate Research Lab sprites (2x2 = 64x64 pixels)
-- 2 layers (base, top), tags: idle(2f), windup(2f), active(4f), winddown(2f)

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, HH = 64, 64  -- 2x2 tiles

local tags = {
  {name="idle",     from=1, to=2,  duration=0.5},
  {name="windup",   from=3, to=4,  duration=0.167},
  {name="active",   from=5, to=8,  duration=0.167},
  {name="winddown", from=9, to=10, duration=0.167},
}

local spr, layers = H.new_sprite(W, HH, {"base", "top"}, tags)

-- Colors — teal/cyan laboratory theme
local body      = H.hex("#264850")
local body_lt   = H.hex("#305A64")
local body_dk   = H.hex("#1C3840")
local panel     = H.hex("#223E46")
local panel_dk  = H.hex("#1A3038")
local metal     = H.hex("#4A6E78")
local metal_dk  = H.hex("#3A5A64")
local accent    = H.hex("#5A8A96")
local dark      = H.hex("#142830")
local chamber   = H.hex("#0E1E24")

-- Lab-specific colors
local screen_off = H.hex("#1A3038")
local screen_on  = H.hex("#44BBAA")
local screen_hot = H.hex("#66DDCC")
local flask_body = H.hex("#3A7888")
local flask_glow = H.hex("#55CCBB")
local bubble     = H.hex("#88EEDD")
local lens       = H.hex("#66AACC")
local lens_glow  = H.hex("#88CCEE")
local rivet      = H.hex("#5A7882")

H.render_frames(spr, layers, tags, function(img, layer, fi, tag, phase)
  if layer == "base" then
    -- Main body
    H.shaded_rect(img, 1, 1, 62, 62, body, body_lt, body_dk)
    -- Outline
    H.rect_outline(img, 0, 0, 63, 63, dark)

    -- Left input panels (top-left and bottom-left intake slots)
    H.bordered_rect(img, 2, 4, 12, 28, panel, panel_dk)
    H.bordered_rect(img, 2, 36, 12, 60, panel, panel_dk)

    -- Input slot openings
    H.rect(img, 0, 10, 3, 18, chamber)
    H.rect(img, 0, 42, 3, 50, chamber)

    -- Central lab bench area
    H.bordered_rect(img, 16, 6, 60, 58, panel_dk, dark)
    H.rect(img, 18, 8, 58, 56, chamber)

    -- Lab bench surface
    H.rect(img, 18, 28, 58, 36, panel)
    H.rect(img, 18, 29, 58, 29, metal_dk)
    H.rect(img, 18, 35, 58, 35, metal_dk)

    -- Internal feed tracks from inputs
    H.rect(img, 13, 14, 17, 16, metal_dk)
    H.rect(img, 13, 46, 17, 48, metal_dk)

    -- Rivets
    H.px(img, 4, 3, rivet)
    H.px(img, 60, 3, rivet)
    H.px(img, 4, 61, rivet)
    H.px(img, 60, 61, rivet)
    H.px(img, 14, 3, rivet)
    H.px(img, 14, 61, rivet)

  elseif layer == "top" then
    -- Microscope (left side of bench)
    H.rect(img, 22, 16, 26, 27, metal)
    H.rect(img, 23, 12, 25, 15, metal_dk)
    H.px(img, 24, 11, lens)
    H.rect(img, 21, 27, 27, 28, accent)

    -- Beaker/flask (center of bench)
    H.rect(img, 32, 18, 36, 27, flask_body)
    H.rect(img, 31, 24, 37, 27, flask_body)
    H.rect(img, 33, 19, 35, 23, H.hex("#2A6070"))

    -- Screen/monitor (right side)
    H.bordered_rect(img, 42, 10, 56, 26, metal_dk, dark)

    if tag == "idle" then
      -- Screen dim / standby
      local screen_c = phase == 0 and screen_off or H.lerp_color(screen_off, screen_on, 0.15)
      H.rect(img, 44, 12, 54, 24, screen_c)
      -- Standby dot
      H.px(img, 49, 18, H.lerp_color(screen_off, screen_on, 0.3 + phase * 0.1))
      -- Lens dim
      H.px(img, 24, 11, lens)

    elseif tag == "windup" then
      -- Screen powering on
      local t = phase * 0.5
      H.rect(img, 44, 12, 54, 24, H.lerp_color(screen_off, screen_on, t))
      -- Lens warming
      H.px(img, 24, 11, H.lerp_color(lens, lens_glow, t))

    elseif tag == "active" then
      -- Screen active with data/pulse
      local pulse = ({0.8, 1.0, 0.8, 0.6})[phase + 1]
      H.rect(img, 44, 12, 54, 24, H.lerp_color(screen_on, screen_hot, pulse - 0.6))
      -- Screen scan lines
      local scan_y = 12 + (phase * 3) % 12
      H.rect(img, 44, scan_y, 54, scan_y, H.lerp_color(screen_on, screen_hot, 0.5))
      -- Data dots on screen
      H.px(img, 46, 14 + phase, screen_hot)
      H.px(img, 50, 16 + phase, screen_hot)
      H.px(img, 52, 13 + phase, screen_hot)

      -- Beaker bubbles (animated)
      if phase == 0 or phase == 2 then
        H.px(img, 33, 21, bubble)
        H.px(img, 35, 20, bubble)
      end
      if phase == 1 or phase == 3 then
        H.px(img, 34, 19, bubble)
        H.px(img, 33, 22, bubble)
      end

      -- Flask glow
      H.px(img, 34, 25, flask_glow)

      -- Lens glow
      H.px(img, 24, 11, lens_glow)

    elseif tag == "winddown" then
      -- Screen dimming
      local t = 1.0 - phase * 0.5
      H.rect(img, 44, 12, 54, 24, H.lerp_color(screen_off, screen_on, t))
      H.px(img, 24, 11, H.lerp_color(lens, lens_glow, t))
    end

    -- Bottom half: sample trays on bench
    H.bordered_rect(img, 22, 38, 30, 46, metal, metal_dk)
    H.bordered_rect(img, 34, 38, 42, 46, metal, metal_dk)
    H.bordered_rect(img, 46, 38, 54, 46, metal, metal_dk)

    -- Sample tray contents (colored dots for science packs)
    H.px(img, 25, 42, H.hex("#CC3333"))  -- red pack
    H.px(img, 27, 41, H.hex("#CC3333"))
    H.px(img, 37, 42, H.hex("#33AA44"))  -- green pack
    H.px(img, 39, 41, H.hex("#33AA44"))
    H.px(img, 49, 42, H.hex("#3366CC"))  -- blue pack
    H.px(img, 51, 41, H.hex("#3366CC"))

    -- Top frame border
    H.rect(img, 14, 0, 60, 1, metal_dk)
    H.rect(img, 14, 62, 60, 63, metal_dk)
  end
end)

local dir = "/Users/gorishniymax/Repos/factor/buildings/research_lab/sprites"
H.save_and_export(spr, dir, "main")
