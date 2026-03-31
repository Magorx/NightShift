-- generate_no_power.lua
-- 32x32 "no power" icon: red circle with yellow lightning bolt
-- crossed by a single line perpendicular to the bolt.

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")

local W, FH = 32, 32
local LAYERS = {"icon"}
local TAGS = {
  {name="default", from=1, to=1, duration=1.0},
}
local DIR = "/Users/gorishniymax/Repos/factor/scripts/energy"

-- Colors
local RED      = H.hex("#C02020")
local RED_DK   = H.hex("#8B1515")
local RED_LT   = H.hex("#D83030")
local BOLT     = H.hex("#FFD93D")
local BOLT_DK  = H.hex("#D4A820")

local function draw_icon(img)
  -- Filled red circle (radius ~12, centered at 15,15)
  H.circle(img, 15, 15, 12, RED)
  H.circle_outline(img, 15, 15, 12, RED_DK)

  -- Inner highlight (subtle lighter arc top-left)
  H.circle_outline(img, 15, 15, 11, RED_LT)
  -- Restore the main fill over most of the inner outline (keep only top-left highlight)
  for y = 13, 27 do
    for x = 3, 28 do
      local dx, dy = x - 15, y - 15
      local d = math.sqrt(dx * dx + dy * dy)
      if d <= 10.5 and d >= 10.0 then
        H.px(img, x, y, RED)
      end
    end
  end

  -- Lightning bolt — goes from upper-right to lower-left
  -- Top arm: (18,5) -> (14,13)
  H.line(img, 18, 5, 14, 13, BOLT)
  H.line(img, 19, 5, 15, 13, BOLT)
  H.line(img, 20, 6, 16, 13, BOLT)
  -- Middle bar: horizontal at y=13..14
  H.line(img, 11, 13, 19, 13, BOLT)
  H.line(img, 11, 14, 19, 14, BOLT)
  -- Bottom arm: (17,14) -> (13,24)
  H.line(img, 17, 14, 13, 24, BOLT)
  H.line(img, 16, 14, 12, 24, BOLT)
  H.line(img, 15, 15, 11, 25, BOLT)

  -- Dark edge on bolt for depth
  H.line(img, 20, 6, 17, 12, BOLT_DK)
  H.line(img, 11, 25, 12, 25, BOLT_DK)

end

local spr, lm = H.new_sprite(W, FH, LAYERS, TAGS)
H.render_frames(spr, lm, TAGS, function(img, layer, fi, tag, phase)
  draw_icon(img)
end)

-- Export as flat PNG (not spritesheet)
spr:saveCopyAs(DIR .. "/no_power_icon.png")
print("[no_power_icon] done")
