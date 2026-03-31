-- Generate Greenhouse sprites (2x1 = 64x32 pixels)
-- 2 layers (base, top), tags: idle(2f), windup(2f), active(4f), winddown(2f)

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, HH = 64, 32

local tags = {
  {name="idle",     from=1, to=2,  duration=0.5},
  {name="windup",   from=3, to=4,  duration=0.167},
  {name="active",   from=5, to=8,  duration=0.167},
  {name="winddown", from=9, to=10, duration=0.167},
}

local spr, layers = H.new_sprite(W, HH, {"base", "top"}, tags)

-- Colors: green with glass panels
local body      = H.hex("#3A4A30")
local body_lt   = H.hex("#4A5C3E")
local body_dk   = H.hex("#2A3822")
local soil      = H.hex("#3C2E1E")
local soil_dk   = H.hex("#2C2016")
local soil_lt   = H.hex("#4A3826")
local glass     = H.hex("#88B8A0")
local glass_lt  = H.hex("#A0D4B8")
local glass_dk  = H.hex("#6A9A82")
local frame     = H.hex("#4A5A44")
local frame_dk  = H.hex("#3A4A34")
local plant     = H.hex("#3A8040")
local plant_lt  = H.hex("#50A858")
local plant_dk  = H.hex("#2A6030")
local stem      = H.hex("#306028")
local leaf      = H.hex("#48A050")
local leaf_lt   = H.hex("#60C068")
local dark      = H.hex("#141C10")
local chamber   = H.hex("#0E160C")
local rivet     = H.hex("#5A5A48")
local glow_off  = H.hex("#304828")
local glow_on   = H.hex("#60C060")

H.render_frames(spr, layers, tags, function(img, layer, fi, tag, phase)
  if layer == "base" then
    -- Main body
    H.shaded_rect(img, 1, 1, 62, 30, body, body_lt, body_dk)
    H.rect_outline(img, 0, 0, 63, 31, dark)

    -- Input (left side)
    H.bordered_rect(img, 2, 4, 10, 28, body_dk, dark)
    H.rect(img, 0, 10, 3, 21, chamber)

    -- Output (right side)
    H.bordered_rect(img, 53, 4, 62, 28, body_dk, dark)
    H.rect(img, 60, 10, 63, 21, chamber)

    -- Soil/planting bed (center)
    H.bordered_rect(img, 12, 4, 52, 28, soil_dk, dark)
    H.rect(img, 14, 6, 50, 26, soil)

    -- Soil texture
    H.px(img, 18, 10, soil_lt)
    H.px(img, 26, 14, soil_lt)
    H.px(img, 34, 8, soil_lt)
    H.px(img, 42, 16, soil_lt)
    H.px(img, 22, 22, soil_lt)
    H.px(img, 38, 20, soil_lt)
    H.px(img, 46, 12, soil_lt)

    -- Planting rows
    H.rect(img, 16, 12, 48, 12, soil_dk)
    H.rect(img, 16, 20, 48, 20, soil_dk)

    -- Water channel
    H.rect(img, 14, 15, 50, 17, H.hex("#2A4040"))

    -- Corner rivets
    H.px(img, 2, 2, rivet)
    H.px(img, 61, 2, rivet)
    H.px(img, 2, 29, rivet)
    H.px(img, 61, 29, rivet)

  elseif layer == "top" then
    -- Glass dome frame
    H.rect(img, 0, 0, 63, 1, frame_dk)
    H.rect(img, 0, 30, 63, 31, frame_dk)
    H.rect(img, 0, 0, 1, 31, frame_dk)
    H.rect(img, 62, 0, 63, 31, frame_dk)

    -- Input/output casings
    H.bordered_rect(img, 2, 2, 11, 29, body, frame_dk)
    H.rect(img, 4, 6, 9, 26, body_dk)
    H.bordered_rect(img, 52, 2, 62, 29, body, frame_dk)
    H.rect(img, 54, 6, 60, 26, body_dk)

    -- Gate openings
    H.rect(img, 0, 10, 2, 21, chamber)
    H.rect(img, 62, 10, 63, 21, chamber)

    -- Glass panels (semi-transparent look via lighter colors)
    H.bordered_rect(img, 13, 2, 36, 29, glass, glass_dk)
    H.bordered_rect(img, 38, 2, 51, 29, glass, glass_dk)

    -- Glass panel frame ribs
    H.rect(img, 24, 2, 25, 29, frame)
    H.rect(img, 13, 15, 51, 16, frame)
    H.rect(img, 37, 2, 37, 29, frame)

    -- Glass highlights
    H.line(img, 15, 4, 15, 13, glass_lt)
    H.line(img, 40, 4, 40, 13, glass_lt)
    H.line(img, 15, 18, 15, 27, glass_lt)

    -- Plants growing (animated)
    if tag == "idle" then
      -- Small sprouts
      H.px(img, 20, 24, stem)
      H.px(img, 20, 23, plant_dk)
      H.px(img, 30, 22, stem)
      H.px(img, 30, 21, plant_dk)
      H.px(img, 44, 24, stem)
      H.px(img, 44, 23, plant_dk)
      local bob = phase == 0 and 0 or 0

    elseif tag == "windup" then
      -- Sprouts starting to grow
      H.px(img, 20, 24, stem)
      H.px(img, 20, 23, plant)
      H.px(img, 30, 22, stem)
      H.px(img, 30, 21, plant)
      H.px(img, 44, 24, stem)
      H.px(img, 44, 23, plant)
      if phase == 1 then
        H.px(img, 20, 22, leaf)
        H.px(img, 30, 20, leaf)
      end

    elseif tag == "active" then
      -- Plants at various growth stages
      local growth = phase + 1  -- 1-4

      -- Plant 1
      H.line(img, 20, 25, 20, 25 - growth * 2, stem)
      H.px(img, 19, 24 - growth * 2, leaf)
      H.px(img, 21, 24 - growth * 2, leaf)
      if growth >= 3 then
        H.px(img, 19, 22 - growth, leaf_lt)
        H.px(img, 21, 22 - growth, leaf_lt)
      end

      -- Plant 2
      H.line(img, 30, 25, 30, 25 - growth * 2, stem)
      H.px(img, 29, 24 - growth * 2, leaf)
      H.px(img, 31, 24 - growth * 2, leaf)
      if growth >= 2 then
        H.px(img, 29, 23 - growth, plant_lt)
      end

      -- Plant 3
      H.line(img, 44, 25, 44, 25 - growth * 2, stem)
      H.px(img, 43, 24 - growth * 2, leaf)
      H.px(img, 45, 24 - growth * 2, leaf)
      if growth >= 4 then
        H.px(img, 43, 20 - growth, leaf_lt)
        H.px(img, 45, 20 - growth, leaf_lt)
      end

      H.px(img, 12, 8, glow_on)

    elseif tag == "winddown" then
      -- Plants settling
      H.line(img, 20, 25, 20, 19, stem)
      H.px(img, 19, 18, leaf)
      H.px(img, 21, 18, leaf)
      H.line(img, 30, 25, 30, 19, stem)
      H.px(img, 29, 18, leaf)
      H.px(img, 31, 18, leaf)
      H.line(img, 44, 25, 44, 19, stem)
      H.px(img, 43, 18, leaf)
      H.px(img, 45, 18, leaf)
      H.px(img, 12, 8, H.lerp_color(glow_on, glow_off, phase * 0.5))
    end

    -- Rivets
    H.px(img, 3, 3, rivet)
    H.px(img, 60, 3, rivet)
    H.px(img, 3, 28, rivet)
    H.px(img, 60, 28, rivet)
  end
end)

local dir = "/Users/gorishniymax/Repos/factor/buildings/greenhouse/sprites"
H.save_and_export(spr, dir, "main")
print("[greenhouse] done")
