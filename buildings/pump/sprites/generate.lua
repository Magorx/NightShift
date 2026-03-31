-- Generate Pump sprites (1x1 = 32x32 pixels)
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

-- Colors: dark industrial with oil-colored accents
local body      = H.hex("#2E2A28")
local body_lt   = H.hex("#3A3634")
local body_dk   = H.hex("#222020")
local pipe_col  = H.hex("#3C3430")
local pipe_dk   = H.hex("#2A2420")
local metal     = H.hex("#585050")
local metal_dk  = H.hex("#484040")
local piston    = H.hex("#606060")
local piston_lt = H.hex("#787070")
local oil       = H.hex("#1A1408")
local oil_dk    = H.hex("#100C04")
local rivet     = H.hex("#5A4B3C")
local dark      = H.hex("#141210")
local chamber   = H.hex("#160F0C")
local glow_off  = H.hex("#3A3230")
local glow_on   = H.hex("#8B6850")

H.render_frames(spr, layers, tags, function(img, layer, fi, tag, phase)
  if layer == "base" then
    -- Main body
    H.shaded_rect(img, 1, 1, 30, 30, body, body_lt, body_dk)
    H.rect_outline(img, 0, 0, 31, 31, dark)

    -- Input pipe (left side)
    H.rect(img, 0, 12, 5, 19, pipe_col)
    H.rect(img, 0, 13, 3, 18, oil)
    H.rect(img, 4, 11, 6, 20, pipe_dk)

    -- Output pipe (right side)
    H.rect(img, 26, 12, 31, 19, pipe_col)
    H.rect(img, 28, 13, 31, 18, oil)
    H.rect(img, 25, 11, 27, 20, pipe_dk)

    -- Pump chamber (center)
    H.bordered_rect(img, 8, 6, 23, 25, body_dk, dark)
    H.rect(img, 10, 8, 21, 23, chamber)

    -- Oil reservoir
    H.rect(img, 11, 16, 20, 22, oil)
    H.rect(img, 12, 18, 19, 21, oil_dk)

    -- Internal pipe connection
    H.rect(img, 6, 14, 9, 17, pipe_dk)
    H.rect(img, 22, 14, 25, 17, pipe_dk)

    -- Corner rivets
    H.px(img, 2, 2, rivet)
    H.px(img, 29, 2, rivet)
    H.px(img, 2, 29, rivet)
    H.px(img, 29, 29, rivet)

  elseif layer == "top" then
    -- Pump housing top
    H.bordered_rect(img, 6, 4, 25, 27, metal_dk, dark)

    -- Pipe flanges (left/right)
    H.rect(img, 0, 12, 5, 19, pipe_col)
    H.rect_outline(img, 3, 11, 6, 20, metal_dk)
    H.rect(img, 25, 12, 31, 19, pipe_col)
    H.rect_outline(img, 25, 11, 28, 20, metal_dk)

    -- Gate openings
    H.rect(img, 0, 13, 2, 18, oil)
    H.rect(img, 29, 13, 31, 18, oil)

    -- Piston head (animated)
    if tag == "idle" then
      local bob = phase == 0 and 0 or 1
      H.bordered_rect(img, 10, 8 + bob, 21, 14 + bob, piston, metal_dk)
      H.rect(img, 13, 10 + bob, 18, 12 + bob, piston_lt)
      H.px(img, 15, 9 + bob, glow_off)

    elseif tag == "windup" then
      local dy = phase * 2
      H.bordered_rect(img, 10, 8 + dy, 21, 14 + dy, piston, metal_dk)
      H.rect(img, 13, 10 + dy, 18, 12 + dy, piston_lt)
      H.px(img, 15, 9 + dy, H.lerp_color(glow_off, glow_on, phase * 0.5))

    elseif tag == "active" then
      -- Piston pumping up and down
      local offsets = {0, 4, 8, 4}
      local dy = offsets[phase + 1]
      H.bordered_rect(img, 10, 8 + dy, 21, 14 + dy, piston, metal_dk)
      H.rect(img, 13, 10 + dy, 18, 12 + dy, piston_lt)
      H.px(img, 15, 9 + dy, glow_on)
      -- Piston rod
      H.rect(img, 14, 15, 17, 8 + dy, metal)

    elseif tag == "winddown" then
      local dy = (1 - phase) * 4
      H.bordered_rect(img, 10, 8 + dy, 21, 14 + dy, piston, metal_dk)
      H.rect(img, 13, 10 + dy, 18, 12 + dy, piston_lt)
      H.px(img, 15, 9 + dy, H.lerp_color(glow_on, glow_off, phase * 0.5))
    end

    -- Rivets on housing
    H.px(img, 7, 5, rivet)
    H.px(img, 24, 5, rivet)
    H.px(img, 7, 26, rivet)
    H.px(img, 24, 26, rivet)
  end
end)

local dir = "/Users/gorishniymax/Repos/factor/buildings/pump/sprites"
H.save_and_export(spr, dir, "main")
print("[pump] done")
