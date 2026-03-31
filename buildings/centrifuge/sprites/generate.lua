-- Generate Centrifuge sprites (2x2 = 64x64 pixels)
-- 2 layers (base, top), tags: idle(2f), windup(2f), active(4f), winddown(2f)

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, HH = 64, 64

local tags = {
  {name="idle",     from=1, to=2,  duration=0.5},
  {name="windup",   from=3, to=4,  duration=0.167},
  {name="active",   from=5, to=8,  duration=0.167},
  {name="winddown", from=9, to=10, duration=0.167},
}

local spr, layers = H.new_sprite(W, HH, {"base", "top"}, tags)

-- Colors: blue-gray industrial
local body      = H.hex("#343C4A")
local body_lt   = H.hex("#424C5C")
local body_dk   = H.hex("#262E3A")
local panel     = H.hex("#2C3440")
local panel_dk  = H.hex("#222A34")
local metal     = H.hex("#5A6478")
local metal_dk  = H.hex("#4A5466")
local drum      = H.hex("#4A5868")
local drum_lt   = H.hex("#5C6C80")
local drum_dk   = H.hex("#3A4856")
local hub       = H.hex("#6A7888")
local hub_lt    = H.hex("#8090A0")
local dark      = H.hex("#161C24")
local chamber   = H.hex("#101820")
local rivet     = H.hex("#5A6474")
local glow_off  = H.hex("#3A4454")
local glow_on   = H.hex("#6688BB")
local glow_hot  = H.hex("#88AADD")
local spin_mark = H.hex("#5A6A7E")

H.render_frames(spr, layers, tags, function(img, layer, fi, tag, phase)
  if layer == "base" then
    -- Main body
    H.shaded_rect(img, 1, 1, 62, 62, body, body_lt, body_dk)
    H.rect_outline(img, 0, 0, 63, 63, dark)

    -- Left input panel
    H.bordered_rect(img, 2, 8, 12, 56, panel, panel_dk)
    H.rect(img, 0, 14, 3, 22, chamber)
    H.rect(img, 0, 42, 3, 50, chamber)

    -- Right output panel
    H.bordered_rect(img, 51, 8, 62, 56, panel, panel_dk)
    H.rect(img, 60, 14, 63, 22, chamber)
    H.rect(img, 60, 42, 63, 50, chamber)

    -- Central drum housing (heavy industrial frame)
    H.bordered_rect(img, 14, 4, 50, 60, panel_dk, dark)
    H.rect(img, 16, 6, 48, 58, chamber)

    -- Drum base plate (circular platform)
    H.circle(img, 32, 32, 18, drum_dk)
    H.circle(img, 32, 32, 16, drum)

    -- Internal feed lines
    H.rect(img, 12, 17, 15, 19, metal_dk)
    H.rect(img, 12, 45, 15, 47, metal_dk)
    H.rect(img, 49, 17, 52, 19, metal_dk)
    H.rect(img, 49, 45, 52, 47, metal_dk)

    -- Corner rivets
    H.px(img, 3, 2, rivet)
    H.px(img, 60, 2, rivet)
    H.px(img, 3, 61, rivet)
    H.px(img, 60, 61, rivet)

  elseif layer == "top" then
    -- Frame borders
    H.rect(img, 0, 0, 63, 1, metal_dk)
    H.rect(img, 0, 62, 63, 63, metal_dk)
    H.rect(img, 0, 0, 1, 63, metal_dk)
    H.rect(img, 62, 0, 63, 63, metal_dk)

    -- Left input casing
    H.bordered_rect(img, 2, 2, 14, 61, body, metal_dk)
    H.rect(img, 4, 10, 12, 55, panel_dk)

    -- Right output casing
    H.bordered_rect(img, 49, 2, 62, 61, body, metal_dk)
    H.rect(img, 51, 10, 60, 55, panel_dk)

    -- Gate openings
    H.rect(img, 0, 14, 2, 22, chamber)
    H.rect(img, 0, 42, 2, 50, chamber)
    H.rect(img, 62, 14, 63, 22, chamber)
    H.rect(img, 62, 42, 63, 50, chamber)

    -- Spinning drum (animated)
    if tag == "idle" then
      -- Static drum
      H.circle(img, 32, 32, 14, drum)
      H.circle_outline(img, 32, 32, 14, drum_dk)
      H.circle(img, 32, 32, 4, hub)
      H.px(img, 32, 32, hub_lt)
      -- Orientation marks (+ shape)
      H.line(img, 32, 18, 32, 22, spin_mark)
      H.line(img, 32, 42, 32, 46, spin_mark)
      H.line(img, 18, 32, 22, 32, spin_mark)
      H.line(img, 42, 32, 46, 32, spin_mark)
      local bob = phase == 0 and 0 or 0
      H.px(img, 16, 6, glow_off)

    elseif tag == "windup" then
      H.circle(img, 32, 32, 14, drum)
      H.circle_outline(img, 32, 32, 14, drum_dk)
      H.circle(img, 32, 32, 4, hub)
      H.px(img, 32, 32, hub_lt)
      -- Slight rotation hint
      if phase == 0 then
        H.line(img, 32, 18, 32, 22, spin_mark)
        H.line(img, 32, 42, 32, 46, spin_mark)
        H.line(img, 18, 32, 22, 32, spin_mark)
        H.line(img, 42, 32, 46, 32, spin_mark)
      else
        H.line(img, 34, 18, 36, 22, spin_mark)
        H.line(img, 30, 42, 28, 46, spin_mark)
        H.line(img, 18, 30, 22, 28, spin_mark)
        H.line(img, 42, 34, 46, 36, spin_mark)
      end
      H.px(img, 16, 6, H.lerp_color(glow_off, glow_on, phase * 0.5))

    elseif tag == "active" then
      -- Spinning drum with rotating marks
      H.circle(img, 32, 32, 14, drum_lt)
      H.circle_outline(img, 32, 32, 14, drum_dk)
      H.circle(img, 32, 32, 4, hub)
      H.px(img, 32, 32, hub_lt)

      -- 4 rotation positions for the marks
      local marks = {
        {{0,-14},{0,-10},{0,14},{0,10},{-14,0},{-10,0},{14,0},{10,0}},       -- 0 deg
        {{10,-10},{7,-7},{-10,10},{-7,7},{-10,-10},{-7,-7},{10,10},{7,7}},   -- 45 deg
        {{14,0},{10,0},{-14,0},{-10,0},{0,-14},{0,-10},{0,14},{0,10}},       -- 90 deg
        {{10,10},{7,7},{-10,-10},{-7,-7},{10,-10},{7,-7},{-10,10},{-7,7}},   -- 135 deg
      }
      local m = marks[phase + 1]
      for i = 1, #m, 2 do
        H.line(img, 32 + m[i][1], 32 + m[i][2], 32 + m[i+1][1], 32 + m[i+1][2], spin_mark)
      end

      H.px(img, 16, 6, glow_on)
      -- Motion blur effect
      if phase % 2 == 0 then
        H.circle_outline(img, 32, 32, 12, H.with_alpha(drum_lt, 128))
      end

    elseif tag == "winddown" then
      H.circle(img, 32, 32, 14, drum)
      H.circle_outline(img, 32, 32, 14, drum_dk)
      H.circle(img, 32, 32, 4, hub)
      H.px(img, 32, 32, hub_lt)
      -- Slowing marks
      if phase == 0 then
        H.line(img, 34, 18, 36, 22, spin_mark)
        H.line(img, 30, 42, 28, 46, spin_mark)
        H.line(img, 18, 30, 22, 28, spin_mark)
        H.line(img, 42, 34, 46, 36, spin_mark)
      else
        H.line(img, 32, 18, 32, 22, spin_mark)
        H.line(img, 32, 42, 32, 46, spin_mark)
        H.line(img, 18, 32, 22, 32, spin_mark)
        H.line(img, 42, 32, 46, 32, spin_mark)
      end
      H.px(img, 16, 6, H.lerp_color(glow_on, glow_off, phase * 0.5))
    end

    -- Rivets on casing
    H.px(img, 3, 3, rivet)
    H.px(img, 60, 3, rivet)
    H.px(img, 3, 60, rivet)
    H.px(img, 60, 60, rivet)
  end
end)

local dir = "/Users/gorishniymax/Repos/factor/buildings/centrifuge/sprites"
H.save_and_export(spr, dir, "main")
print("[centrifuge] done")
