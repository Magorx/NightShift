-- Frog 16x16 pixel art via Lua scripting
local spr = Sprite(16, 16, ColorMode.RGB)
spr.filename = "frog.aseprite"

local cel = spr.cels[1]
local img = cel.image

-- Color palette
local C = {
  dark   = Color(45, 90, 30),     -- dark green outline
  mid    = Color(74, 140, 42),    -- main body green
  light  = Color(109, 179, 58),   -- belly highlights
  bright = Color(124, 200, 69),   -- spot highlights
  white  = Color(255, 255, 255),  -- eye whites
  pupil  = Color(17, 17, 17),     -- eye pupils
  mouth  = Color(196, 64, 64),    -- red mouth
  foot   = Color(232, 168, 48),   -- orange feet
  clear  = Color(0, 0, 0, 0),    -- transparent
}

-- Helper: draw a row of pixels from a string map
local function draw_row(y, row_data)
  for x, color in pairs(row_data) do
    img:drawPixel(x, y, color)
  end
end

-- Row-by-row sprite definition (only non-transparent pixels)
-- Row 1: top of head
for x = 5, 10 do img:drawPixel(x, 1, C.dark) end

-- Row 2: head outline + fill
for x = 3, 4 do img:drawPixel(x, 2, C.dark) end
for x = 5, 10 do img:drawPixel(x, 2, C.mid) end
for x = 11, 12 do img:drawPixel(x, 2, C.dark) end

-- Row 3: eyes
img:drawPixel(2, 3, C.dark)
img:drawPixel(3, 3, C.white); img:drawPixel(4, 3, C.pupil)
for x = 5, 10 do img:drawPixel(x, 3, C.mid) end
img:drawPixel(11, 3, C.white); img:drawPixel(12, 3, C.pupil)
img:drawPixel(13, 3, C.dark)

-- Row 4: eyes lower
img:drawPixel(2, 4, C.dark)
img:drawPixel(3, 4, C.white); img:drawPixel(4, 4, C.pupil)
for x = 5, 10 do img:drawPixel(x, 4, C.mid) end
img:drawPixel(11, 4, C.white); img:drawPixel(12, 4, C.pupil)
img:drawPixel(13, 4, C.dark)

-- Row 5: below eyes
img:drawPixel(3, 5, C.dark)
for x = 4, 11 do img:drawPixel(x, 5, C.mid) end
img:drawPixel(12, 5, C.dark)

-- Row 6: mouth
img:drawPixel(3, 6, C.dark)
for x = 4, 5 do img:drawPixel(x, 6, C.mid) end
for x = 6, 9 do img:drawPixel(x, 6, C.mouth) end
for x = 10, 11 do img:drawPixel(x, 6, C.mid) end
img:drawPixel(12, 6, C.dark)

-- Row 7: body
img:drawPixel(2, 7, C.dark)
for x = 3, 12 do img:drawPixel(x, 7, C.mid) end
img:drawPixel(13, 7, C.dark)

-- Row 8: body wide + highlights
img:drawPixel(1, 8, C.dark)
for x = 2, 13 do img:drawPixel(x, 8, C.mid) end
img:drawPixel(4, 8, C.light); img:drawPixel(11, 8, C.light)
img:drawPixel(14, 8, C.dark)

-- Row 9: belly
img:drawPixel(1, 9, C.dark)
for x = 2, 13 do img:drawPixel(x, 9, C.mid) end
img:drawPixel(3, 9, C.light); img:drawPixel(4, 9, C.light)
img:drawPixel(7, 9, C.light); img:drawPixel(8, 9, C.light)
img:drawPixel(11, 9, C.light); img:drawPixel(12, 9, C.light)
img:drawPixel(14, 9, C.dark)

-- Row 10: body lower
img:drawPixel(1, 10, C.dark)
for x = 2, 13 do img:drawPixel(x, 10, C.mid) end
img:drawPixel(14, 10, C.dark)

-- Row 11: body narrowing + spots
img:drawPixel(2, 11, C.dark)
for x = 3, 12 do img:drawPixel(x, 11, C.mid) end
img:drawPixel(4, 11, C.bright); img:drawPixel(11, 11, C.bright)
img:drawPixel(13, 11, C.dark)

-- Row 12: lower body
img:drawPixel(3, 12, C.dark)
for x = 4, 11 do img:drawPixel(x, 12, C.mid) end
img:drawPixel(12, 12, C.dark)

-- Row 13: legs split
img:drawPixel(3, 13, C.dark); img:drawPixel(4, 13, C.mid)
img:drawPixel(5, 13, C.dark); img:drawPixel(6, 13, C.dark)
img:drawPixel(7, 13, C.mid); img:drawPixel(8, 13, C.mid)
img:drawPixel(9, 13, C.dark); img:drawPixel(10, 13, C.dark)
img:drawPixel(11, 13, C.mid); img:drawPixel(12, 13, C.dark)

-- Row 14: upper feet
img:drawPixel(2, 14, C.dark)
img:drawPixel(3, 14, C.foot); img:drawPixel(4, 14, C.foot)
img:drawPixel(5, 14, C.dark)
img:drawPixel(7, 14, C.dark); img:drawPixel(8, 14, C.dark)
img:drawPixel(10, 14, C.dark)
img:drawPixel(11, 14, C.foot); img:drawPixel(12, 14, C.foot)
img:drawPixel(13, 14, C.dark)

-- Row 15: feet spread
for x = 1, 5 do img:drawPixel(x, 15, C.foot) end
for x = 10, 14 do img:drawPixel(x, 15, C.foot) end

-- Export
spr:saveCopyAs("/Users/gorishniymax/Repos/factor/tmp/aseprite_lua/frog.png")
spr:saveCopyAs("/Users/gorishniymax/Repos/factor/tmp/aseprite_lua/frog.aseprite")
