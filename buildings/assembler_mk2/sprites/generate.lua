-- Generate Assembler Mk2 sprites (3x2 = 96x64 pixels)
-- 2 layers (base, top), tags: idle(2f), windup(2f), active(4f), winddown(2f)

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")
local C = H.load_palette("buildings")

local W, HH = 96, 64  -- 3x2 tiles

local tags = {
  {name="idle",     from=1, to=2,  duration=0.5},
  {name="windup",   from=3, to=4,  duration=0.167},
  {name="active",   from=5, to=8,  duration=0.167},
  {name="winddown", from=9, to=10, duration=0.167},
}

local spr, layers = H.new_sprite(W, HH, {"base", "top"}, tags)

-- Colors - darker purple-blue theme
local body      = H.hex("#2E2848")
local body_lt   = H.hex("#3C3460")
local body_dk   = H.hex("#221E38")
local panel     = H.hex("#2A2444")
local panel_dk  = H.hex("#1E1A34")
local metal     = H.hex("#504878")
local metal_dk  = H.hex("#3E3862")
local accent    = H.hex("#6858A0")
local arm_base  = H.hex("#443E68")
local arm_tip   = H.hex("#7878C0")
local rivet     = H.hex("#5A5488")
local dark      = H.hex("#161228")
local chamber   = H.hex("#0E0C1C")
local intake    = H.hex("#1A1630")
local glow_off  = H.hex("#303050")
local glow_on   = H.hex("#8866DD")
local glow_hot  = H.hex("#AA88FF")
local stage_div = H.hex("#3A3460")

H.render_frames(spr, layers, tags, function(img, layer, fi, tag, phase)
  if layer == "base" then
    -- Main body
    H.shaded_rect(img, 1, 1, 94, 62, body, body_lt, body_dk)
    H.rect_outline(img, 0, 0, 95, 63, dark)

    -- Left input panels (3 inputs: top-left, bottom-left, top-center)
    H.bordered_rect(img, 2, 4, 12, 28, panel, panel_dk)
    H.bordered_rect(img, 2, 36, 12, 60, panel, panel_dk)

    -- Input slot openings (left side)
    H.rect(img, 0, 10, 3, 18, chamber)
    H.rect(img, 0, 42, 3, 50, chamber)

    -- Input gate opening (top of In_0 — accepts UP, centered on cell x:16)
    H.rect(img, 10, 0, 22, 3, chamber)

    -- Input gate opening (bottom of In_1 — accepts DOWN, centered on cell x:16)
    H.rect(img, 10, 60, 22, 63, chamber)

    -- Top center input slot (In_2 - from top only)
    H.rect(img, 38, 0, 56, 3, chamber)
    H.bordered_rect(img, 34, 4, 58, 14, panel, panel_dk)

    -- Processing stage 1 (left third)
    H.bordered_rect(img, 14, 8, 30, 56, panel_dk, dark)
    H.rect(img, 16, 10, 28, 54, chamber)

    -- Stage divider 1
    H.rect(img, 31, 6, 32, 58, stage_div)

    -- Processing stage 2 (middle third)
    H.bordered_rect(img, 34, 16, 60, 56, panel_dk, dark)
    H.rect(img, 36, 18, 58, 54, chamber)

    -- Stage divider 2
    H.rect(img, 61, 6, 62, 58, stage_div)

    -- Processing stage 3 (right third) + output
    H.bordered_rect(img, 64, 8, 82, 56, panel_dk, dark)
    H.rect(img, 66, 10, 80, 54, chamber)

    -- Right output panels
    H.bordered_rect(img, 84, 4, 94, 28, panel, panel_dk)
    H.bordered_rect(img, 84, 36, 94, 60, panel, panel_dk)

    -- Output slot openings
    H.rect(img, 92, 10, 95, 18, intake)
    H.rect(img, 92, 42, 95, 50, intake)

    -- Internal conveyor feed lines
    H.rect(img, 13, 14, 15, 16, metal_dk)
    H.rect(img, 13, 46, 15, 48, metal_dk)
    H.rect(img, 29, 32, 35, 33, metal_dk)
    H.rect(img, 59, 32, 65, 33, metal_dk)

    -- Rivets
    H.px(img, 4, 3, rivet)
    H.px(img, 92, 3, rivet)
    H.px(img, 4, 61, rivet)
    H.px(img, 92, 61, rivet)
    H.px(img, 32, 3, rivet)
    H.px(img, 62, 3, rivet)

  elseif layer == "top" then
    -- Full-width casing that covers the entire building including input panels
    -- Top and bottom frame borders (full width)
    H.rect(img, 0, 0, 95, 1, metal_dk)
    H.rect(img, 0, 62, 95, 63, metal_dk)
    -- Left and right side borders
    H.rect(img, 0, 0, 1, 63, metal_dk)
    H.rect(img, 94, 0, 95, 63, metal_dk)

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

    -- Top center input casing (In_2)
    H.bordered_rect(img, 34, 2, 58, 12, body, metal_dk)
    H.rect(img, 38, 5, 54, 10, panel_dk)

    -- Right output casing (continuous, covers full height)
    H.bordered_rect(img, 82, 2, 94, 61, body, metal_dk)
    -- Divider between top and bottom output slots
    H.rect(img, 82, 30, 94, 33, metal_dk)
    -- Output recesses
    H.rect(img, 84, 6, 92, 28, panel_dk)
    H.rect(img, 84, 35, 92, 59, panel_dk)

    -- Gate openings (cut through casing borders to show item flow)
    -- Left gates (In_0 left, In_1 left) — 3px deep for resource peek
    H.rect(img, 0, 10, 2, 18, chamber)
    H.rect(img, 0, 42, 2, 50, chamber)
    -- Top gate for In_0 (accepts UP, centered on cell x:16, wider)
    H.rect(img, 10, 0, 22, 2, chamber)
    -- Bottom gate for In_1 (accepts DOWN, centered on cell x:16, wider)
    H.rect(img, 10, 61, 22, 63, chamber)
    -- Top gate for In_2 (accepts UP, centered on cell x:48)
    H.rect(img, 38, 0, 56, 2, chamber)
    -- Right gates (Out_0, Out_1)
    H.rect(img, 94, 10, 95, 18, intake)
    H.rect(img, 94, 42, 95, 50, intake)

    -- Multi-stage processing arms (animated)
    if tag == "idle" then
      local bob = phase == 0 and 0 or 1
      -- Stage 1 arm
      H.bordered_rect(img, 16, 18 + bob, 28, 36 + bob, arm_base, metal_dk)
      H.rect(img, 20, 24 + bob, 24, 30 + bob, metal)
      -- Stage 2 arm
      H.bordered_rect(img, 38, 22 + bob, 56, 40 + bob, arm_base, metal_dk)
      H.rect(img, 42, 28 + bob, 52, 34 + bob, metal)
      -- Stage 3 arm
      H.bordered_rect(img, 66, 18 + bob, 80, 36 + bob, arm_base, metal_dk)
      H.rect(img, 70, 24 + bob, 76, 30 + bob, metal)
      -- Status lights (off)
      H.px(img, 18, 20 + bob, glow_off)
      H.px(img, 40, 24 + bob, glow_off)
      H.px(img, 68, 20 + bob, glow_off)

    elseif tag == "windup" then
      local ext = phase * 2
      -- Stage arms extending
      H.bordered_rect(img, 16, 18, 28 + ext, 36, arm_base, metal_dk)
      H.rect(img, 20, 24, 24 + ext, 30, metal)
      H.bordered_rect(img, 38, 22, 56 + ext, 40, arm_base, metal_dk)
      H.rect(img, 42, 28, 52 + ext, 34, metal)
      H.bordered_rect(img, 66, 18, 80 + ext, 36, arm_base, metal_dk)
      H.rect(img, 70, 24, 76 + ext, 30, metal)
      -- Lights warming
      local g = H.lerp_color(glow_off, glow_on, phase * 0.5)
      H.px(img, 18, 20, g)
      H.px(img, 40, 24, g)
      H.px(img, 68, 20, g)

    elseif tag == "active" then
      local offsets = {2, 0, -2, 0}
      local ox = offsets[phase + 1]
      local oy = phase % 2 == 0 and -1 or 1
      -- Stage 1 working
      H.bordered_rect(img, 16, 18, 30, 36, arm_base, metal_dk)
      H.rect(img, 20, 24, 26 + ox, 30, metal)
      H.rect(img, 24 + ox, 26 + oy, 28 + ox, 28 + oy, arm_tip)
      -- Stage 2 working
      H.bordered_rect(img, 38, 22, 58, 40, arm_base, metal_dk)
      H.rect(img, 42, 28, 54 - ox, 34, metal)
      H.rect(img, 50 - ox, 30 + oy, 54 - ox, 32 + oy, arm_tip)
      -- Stage 3 working
      H.bordered_rect(img, 66, 18, 82, 36, arm_base, metal_dk)
      H.rect(img, 70, 24, 78 + ox, 30, metal)
      H.rect(img, 76 + ox, 26 + oy, 80 + ox, 28 + oy, arm_tip)
      -- Sparks
      if phase == 0 or phase == 2 then
        H.px(img, 26 + ox, 24 + oy, glow_hot)
        H.px(img, 52 - ox, 28 + oy, glow_hot)
        H.px(img, 78 + ox, 24 + oy, glow_hot)
      end
      -- Status lights on
      H.px(img, 18, 20, glow_on)
      H.px(img, 40, 24, glow_on)
      H.px(img, 68, 20, glow_on)

    elseif tag == "winddown" then
      local ext = (1 - phase) * 2
      H.bordered_rect(img, 16, 18, 28 + ext, 36, arm_base, metal_dk)
      H.rect(img, 20, 24, 24 + ext, 30, metal)
      H.bordered_rect(img, 38, 22, 56 + ext, 40, arm_base, metal_dk)
      H.rect(img, 42, 28, 52 + ext, 34, metal)
      H.bordered_rect(img, 66, 18, 80 + ext, 36, arm_base, metal_dk)
      H.rect(img, 70, 24, 76 + ext, 30, metal)
      local g = H.lerp_color(glow_on, glow_off, phase * 0.5)
      H.px(img, 18, 20, g)
      H.px(img, 40, 24, g)
      H.px(img, 68, 20, g)
    end

    -- Rivets on casing
    H.px(img, 3, 2, rivet)
    H.px(img, 92, 2, rivet)
    H.px(img, 3, 61, rivet)
    H.px(img, 92, 61, rivet)
    H.px(img, 32, 2, rivet)
    H.px(img, 62, 2, rivet)
  end
end)

local dir = "/Users/gorishniymax/Repos/factor/buildings/assembler_mk2/sprites"
H.save_and_export(spr, dir, "main")
