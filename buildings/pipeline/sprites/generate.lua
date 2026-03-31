-- Generate Pipeline sprites (1x1 = 32x32 pixels)
-- 2 layers (base, top), tags: idle(2f), windup(2f), active(4f), winddown(2f)

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, HH = 32, 32

local tags = {
  {name="idle",     from=1, to=2,  duration=0.5},
  {name="windup",   from=3, to=4,  duration=0.167},
  {name="active",   from=5, to=8,  duration=0.167},
  {name="winddown", from=9, to=10, duration=0.167},
}

local spr, layers = H.new_sprite(W, HH, {"base", "top"}, tags)

-- Colors: purple pipe fitting
local body      = H.hex("#3A2E48")
local body_lt   = H.hex("#4A3C5A")
local body_dk   = H.hex("#2A2038")
local pipe_col  = H.hex("#44386A")
local pipe_lt   = H.hex("#584C80")
local pipe_dk   = H.hex("#342858")
local pipe_in   = H.hex("#1C1430")
local flange    = H.hex("#504470")
local flange_dk = H.hex("#3E3458")
local metal     = H.hex("#5A5070")
local metal_dk  = H.hex("#4A4060")
local dark      = H.hex("#120E1A")
local rivet     = H.hex("#5A5268")
local glow_off  = H.hex("#302848")
local glow_on   = H.hex("#6A58AA")

H.render_frames(spr, layers, tags, function(img, layer, fi, tag, phase)
  if layer == "base" then
    -- Main body
    H.shaded_rect(img, 1, 1, 30, 30, body, body_lt, body_dk)
    H.rect_outline(img, 0, 0, 31, 31, dark)

    -- Central pipe tube (horizontal)
    H.rect(img, 0, 10, 31, 21, pipe_col)
    H.rect(img, 2, 12, 29, 19, pipe_lt)
    H.rect(img, 4, 14, 27, 17, pipe_in)

    -- Connector ports (left and right)
    H.bordered_rect(img, 0, 8, 4, 23, flange, flange_dk)
    H.bordered_rect(img, 27, 8, 31, 23, flange, flange_dk)

    -- Port openings
    H.rect(img, 0, 12, 2, 19, pipe_in)
    H.rect(img, 29, 12, 31, 19, pipe_in)

    -- Support brackets
    H.rect(img, 8, 8, 10, 10, metal_dk)
    H.rect(img, 8, 21, 10, 23, metal_dk)
    H.rect(img, 21, 8, 23, 10, metal_dk)
    H.rect(img, 21, 21, 23, 23, metal_dk)

    -- Corner rivets
    H.px(img, 2, 2, rivet)
    H.px(img, 29, 2, rivet)
    H.px(img, 2, 29, rivet)
    H.px(img, 29, 29, rivet)

  elseif layer == "top" then
    -- Pipe housing top
    H.bordered_rect(img, 3, 6, 28, 25, body, dark)

    -- Top pipe surface
    H.rect(img, 5, 10, 26, 21, pipe_col)
    H.rect(img, 7, 12, 24, 19, pipe_lt)

    -- Highlight stripe
    H.rect(img, 7, 14, 24, 15, pipe_col)

    -- Flange tops
    H.bordered_rect(img, 0, 9, 4, 22, flange, flange_dk)
    H.bordered_rect(img, 27, 9, 31, 22, flange, flange_dk)

    -- Gate openings
    H.rect(img, 0, 12, 2, 19, pipe_in)
    H.rect(img, 29, 12, 31, 19, pipe_in)

    -- Flow indicator (animated)
    if tag == "idle" then
      H.px(img, 15, 15, glow_off)
      H.px(img, 16, 15, glow_off)

    elseif tag == "windup" then
      H.px(img, 15, 15, H.lerp_color(glow_off, glow_on, phase * 0.5))
      H.px(img, 16, 15, H.lerp_color(glow_off, glow_on, phase * 0.5))

    elseif tag == "active" then
      -- Flow dots moving through pipe
      local positions = {8, 12, 18, 23}
      local dot_x = positions[phase + 1]
      H.px(img, dot_x, 15, glow_on)
      H.px(img, dot_x + 1, 15, glow_on)
      -- Trail
      if dot_x > 8 then
        H.px(img, dot_x - 2, 15, H.lerp_color(glow_off, glow_on, 0.3))
      end

    elseif tag == "winddown" then
      H.px(img, 15, 15, H.lerp_color(glow_on, glow_off, phase * 0.5))
      H.px(img, 16, 15, H.lerp_color(glow_on, glow_off, phase * 0.5))
    end

    -- Rivets on housing
    H.px(img, 5, 7, rivet)
    H.px(img, 26, 7, rivet)
    H.px(img, 5, 24, rivet)
    H.px(img, 26, 24, rivet)
  end
end)

local dir = "/Users/gorishniymax/Repos/factor/buildings/pipeline/sprites"
H.save_and_export(spr, dir, "main")
print("[pipeline] done")
