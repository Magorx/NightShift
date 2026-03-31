-- Generate Chemical Plant sprites (2x2 = 64x64 pixels)
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

-- Colors: greenish industrial
local body      = H.hex("#2D3A2D")
local body_lt   = H.hex("#3A4A3A")
local body_dk   = H.hex("#1E2A1E")
local panel     = H.hex("#263226")
local panel_dk  = H.hex("#1C281C")
local metal     = H.hex("#4A5A4A")
local metal_dk  = H.hex("#3A4A3A")
local tank      = H.hex("#1A2818")
local tank_dk   = H.hex("#0E1A0C")
local tank_lt   = H.hex("#2A3A28")
local pipe_col  = H.hex("#344434")
local pipe_dk   = H.hex("#283828")
local vat       = H.hex("#1C3018")
local vat_lt    = H.hex("#2A4026")
local chemical  = H.hex("#40804A")
local chem_lt   = H.hex("#58A866")
local chem_dk   = H.hex("#2A6030")
local bubble    = H.hex("#66CC77")
local dark      = H.hex("#101810")
local chamber   = H.hex("#0C140C")
local rivet     = H.hex("#5A5A4A")
local glow_off  = H.hex("#2A3A2A")
local glow_on   = H.hex("#40AA50")

H.render_frames(spr, layers, tags, function(img, layer, fi, tag, phase)
  if layer == "base" then
    -- Main body
    H.shaded_rect(img, 1, 1, 62, 62, body, body_lt, body_dk)
    H.rect_outline(img, 0, 0, 63, 63, dark)

    -- Left input panels (2 ports)
    H.bordered_rect(img, 2, 4, 12, 28, panel, panel_dk)
    H.bordered_rect(img, 2, 36, 12, 60, panel, panel_dk)

    -- Input slot openings (left side, 2 ports)
    H.rect(img, 0, 10, 3, 18, chamber)
    H.rect(img, 0, 42, 3, 50, chamber)

    -- Right output panels (2 ports)
    H.bordered_rect(img, 51, 4, 62, 28, panel, panel_dk)
    H.bordered_rect(img, 51, 36, 62, 60, panel, panel_dk)

    -- Output slot openings (right side, 2 ports)
    H.rect(img, 60, 10, 63, 18, chamber)
    H.rect(img, 60, 42, 63, 50, chamber)

    -- Chemical tank 1 (top center)
    H.bordered_rect(img, 16, 4, 48, 28, tank, tank_dk)
    H.rect(img, 18, 6, 46, 26, vat)
    H.rect(img, 20, 10, 44, 24, vat_lt)

    -- Chemical tank 2 (bottom center)
    H.bordered_rect(img, 16, 36, 48, 60, tank, tank_dk)
    H.rect(img, 18, 38, 46, 58, vat)
    H.rect(img, 20, 42, 44, 56, vat_lt)

    -- Internal pipe connections
    H.rect(img, 13, 14, 16, 16, pipe_dk)
    H.rect(img, 13, 46, 16, 48, pipe_dk)
    H.rect(img, 48, 14, 51, 16, pipe_dk)
    H.rect(img, 48, 46, 51, 48, pipe_dk)

    -- Cross-pipe between tanks
    H.rect(img, 30, 28, 34, 36, pipe_col)
    H.rect_outline(img, 30, 28, 34, 36, pipe_dk)

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
    H.rect(img, 2, 30, 14, 33, metal_dk)
    H.rect(img, 4, 6, 12, 28, panel_dk)
    H.rect(img, 4, 35, 12, 59, panel_dk)

    -- Right output casing
    H.bordered_rect(img, 49, 2, 62, 61, body, metal_dk)
    H.rect(img, 49, 30, 62, 33, metal_dk)
    H.rect(img, 51, 6, 60, 28, panel_dk)
    H.rect(img, 51, 35, 60, 59, panel_dk)

    -- Gate openings
    H.rect(img, 0, 10, 2, 18, chamber)
    H.rect(img, 0, 42, 2, 50, chamber)
    H.rect(img, 62, 10, 63, 18, chamber)
    H.rect(img, 62, 42, 63, 50, chamber)

    -- Distillation column top (tank 1)
    H.bordered_rect(img, 18, 4, 46, 26, tank_lt, tank_dk)
    H.rect(img, 22, 8, 42, 22, tank)
    -- Column segments
    H.rect(img, 22, 12, 42, 13, pipe_dk)
    H.rect(img, 22, 17, 42, 18, pipe_dk)

    -- Reaction chamber top (tank 2)
    H.bordered_rect(img, 18, 38, 46, 58, tank_lt, tank_dk)
    H.rect(img, 22, 42, 42, 54, tank)

    -- Pipes between chambers
    H.rect(img, 31, 26, 33, 38, pipe_col)
    H.rect_outline(img, 31, 26, 33, 38, pipe_dk)

    -- Animated: bubbling in tanks
    if tag == "idle" then
      H.px(img, 30, 14 + phase, chem_dk)
      H.px(img, 34, 48 + phase, chem_dk)

    elseif tag == "windup" then
      H.px(img, 30, 14, chemical)
      H.px(img, 34, 48, chemical)
      if phase == 1 then
        H.px(img, 28, 12, chem_dk)
        H.px(img, 36, 46, chem_dk)
      end

    elseif tag == "active" then
      -- Bubbling chemical reaction
      local bx = {28, 32, 36, 30}
      local by = {10, 14, 12, 16}
      for i = 1, phase + 1 do
        H.px(img, bx[i], by[i], bubble)
        H.px(img, bx[i] + 2, by[i] + 34, bubble)
      end
      H.px(img, 30, 15, chemical)
      H.px(img, 34, 49, chemical)
      -- Glow indicator
      H.px(img, 16, 15, glow_on)
      H.px(img, 16, 47, glow_on)

    elseif tag == "winddown" then
      H.px(img, 30, 14, H.lerp_color(chemical, chem_dk, phase * 0.5))
      H.px(img, 34, 48, H.lerp_color(chemical, chem_dk, phase * 0.5))
    end

    -- Rivets on casing
    H.px(img, 3, 3, rivet)
    H.px(img, 60, 3, rivet)
    H.px(img, 3, 60, rivet)
    H.px(img, 60, 60, rivet)
  end
end)

local dir = "/Users/gorishniymax/Repos/factor/buildings/chemical_plant/sprites"
H.save_and_export(spr, dir, "main")
print("[chemical_plant] done")
