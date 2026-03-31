-- Generate Assembler Mk1 sprites (2x2 = 64x64 pixels)
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

-- Colors
local body      = H.hex("#3A4460")
local body_lt   = H.hex("#48547A")
local body_dk   = H.hex("#2A3248")
local panel     = H.hex("#323C56")
local panel_dk  = H.hex("#262E42")
local metal     = H.hex("#5A6888")
local metal_dk  = H.hex("#4A5670")
local accent    = H.hex("#6888AA")
local arm_base  = H.hex("#505E78")
local arm_tip   = H.hex("#88A0C0")
local rivet     = H.hex("#6A7A98")
local dark      = H.hex("#1E2636")
local chamber   = H.hex("#141C28")
local intake    = H.hex("#222C3E")
local glow_off  = H.hex("#384860")
local glow_on   = H.hex("#66AADD")
local glow_hot  = H.hex("#88CCFF")

H.render_frames(spr, layers, tags, function(img, layer, fi, tag, phase)
  if layer == "base" then
    -- Main body
    H.shaded_rect(img, 1, 1, 62, 62, body, body_lt, body_dk)
    -- Outline
    H.rect_outline(img, 0, 0, 63, 63, dark)

    -- Left input panels (top-left and bottom-left)
    H.bordered_rect(img, 2, 4, 12, 28, panel, panel_dk)
    H.bordered_rect(img, 2, 36, 12, 60, panel, panel_dk)

    -- Input slot openings (left side)
    H.rect(img, 0, 10, 3, 18, chamber)
    H.rect(img, 0, 42, 3, 50, chamber)

    -- Input gate opening (top of In_0 — accepts UP, centered on cell x:16)
    H.rect(img, 10, 0, 22, 3, chamber)

    -- Input gate opening (bottom of In_1 — accepts DOWN, centered on cell x:16)
    H.rect(img, 10, 60, 22, 63, chamber)

    -- Central processing chamber
    H.bordered_rect(img, 16, 8, 48, 56, panel_dk, dark)
    H.rect(img, 18, 10, 46, 54, chamber)

    -- Internal conveyor feed lines
    H.rect(img, 13, 14, 17, 16, metal_dk)
    H.rect(img, 13, 46, 17, 48, metal_dk)

    -- Output side panels
    H.bordered_rect(img, 50, 4, 62, 28, panel, panel_dk)
    H.bordered_rect(img, 50, 36, 62, 60, panel, panel_dk)

    -- Output slot openings
    H.rect(img, 60, 10, 63, 18, intake)
    H.rect(img, 60, 42, 63, 50, intake)

    -- Rivets
    H.px(img, 4, 3, rivet)
    H.px(img, 60, 3, rivet)
    H.px(img, 4, 61, rivet)
    H.px(img, 60, 61, rivet)

    -- Floor detail
    H.px(img, 15, 32, metal_dk)
    H.px(img, 49, 32, metal_dk)

  elseif layer == "top" then
    -- Full-width casing that covers the entire building including input/output panels
    -- Frame borders (full perimeter)
    H.rect(img, 0, 0, 63, 1, metal_dk)
    H.rect(img, 0, 62, 63, 63, metal_dk)
    H.rect(img, 0, 0, 1, 63, metal_dk)
    H.rect(img, 62, 0, 63, 63, metal_dk)

    -- Top gate entrance canopy (32px wide, 16px tall — covers In_0 UP)
    H.bordered_rect(img, 2, 2, 31, 15, body, metal_dk)

    -- Bottom gate entrance canopy (32px wide, 16px tall — covers In_1 DOWN)
    H.bordered_rect(img, 2, 48, 31, 61, body, metal_dk)

    -- Left input casing (continuous, covers full height, overlaps canopies)
    H.bordered_rect(img, 2, 2, 14, 61, body, metal_dk)
    -- Divider between top and bottom input slots
    H.rect(img, 2, 30, 14, 33, metal_dk)
    -- Input recesses (dark slots showing items can enter)
    H.rect(img, 4, 6, 12, 28, panel_dk)
    H.rect(img, 4, 35, 12, 59, panel_dk)

    -- Right output casing (continuous, covers full height)
    H.bordered_rect(img, 49, 2, 62, 61, body, metal_dk)
    -- Divider between top and bottom output slots
    H.rect(img, 49, 30, 62, 33, metal_dk)
    -- Output recesses
    H.rect(img, 51, 6, 60, 28, panel_dk)
    H.rect(img, 51, 35, 60, 59, panel_dk)

    -- Gate openings (cut through casing borders to show item flow)
    -- Left gates (In_0 left, In_1 left) — 3px deep for resource peek
    H.rect(img, 0, 10, 2, 18, chamber)
    H.rect(img, 0, 42, 2, 50, chamber)
    -- Top gate for In_0 (accepts UP, centered on cell x:16)
    H.rect(img, 10, 0, 22, 2, chamber)
    -- Bottom gate for In_1 (accepts DOWN, centered on cell x:16)
    H.rect(img, 10, 61, 22, 63, chamber)
    -- Right gates (Out_0, Out_1)
    H.rect(img, 62, 10, 63, 18, intake)
    H.rect(img, 62, 42, 63, 50, intake)

    -- Robotic arm assembly (animated)
    if tag == "idle" then
      local bob = phase == 0 and 0 or 1
      H.bordered_rect(img, 22, 20 + bob, 42, 44 + bob, arm_base, metal_dk)
      H.rect(img, 28, 26 + bob, 36, 38 + bob, metal)
      H.rect(img, 34, 28 + bob, 38, 30 + bob, arm_tip)
      H.rect(img, 34, 34 + bob, 38, 36 + bob, arm_tip)
      H.px(img, 24, 22 + bob, glow_off)

    elseif tag == "windup" then
      local ext = phase * 4
      H.bordered_rect(img, 22, 20, 42 + ext, 44, arm_base, metal_dk)
      H.rect(img, 28, 26, 36 + ext, 38, metal)
      H.rect(img, 36 + ext, 28, 40 + ext, 36, arm_tip)
      H.px(img, 24, 22, H.lerp_color(glow_off, glow_on, phase * 0.5))

    elseif tag == "active" then
      local offsets = {3, 0, -3, 0}
      local ox = offsets[phase + 1]
      local oy = phase % 2 == 0 and -1 or 1
      H.bordered_rect(img, 22, 20, 46, 44, arm_base, metal_dk)
      H.rect(img, 28, 26, 40 + ox, 38, metal)
      H.rect(img, 38 + ox, 30 + oy, 44 + ox, 34 + oy, arm_tip)
      if phase == 0 or phase == 2 then
        H.px(img, 42 + ox, 28 + oy, glow_hot)
        H.px(img, 40 + ox, 32 + oy, glow_on)
      end
      H.px(img, 24, 22, glow_on)

    elseif tag == "winddown" then
      local ext = (1 - phase) * 4
      H.bordered_rect(img, 22, 20, 42 + ext, 44, arm_base, metal_dk)
      H.rect(img, 28, 26, 36 + ext, 38, metal)
      H.rect(img, 34 + ext, 29, 38 + ext, 35, arm_tip)
      H.px(img, 24, 22, H.lerp_color(glow_on, glow_off, phase * 0.5))
    end

    -- Rivets on casing
    H.px(img, 3, 2, rivet)
    H.px(img, 60, 2, rivet)
    H.px(img, 3, 61, rivet)
    H.px(img, 60, 61, rivet)
  end
end)

local dir = "/Users/gorishniymax/Repos/factor/buildings/assembler/sprites"
H.save_and_export(spr, dir, "main")
