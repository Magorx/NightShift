-- generate_items.lua — Night Shift resource item atlas (96x16, 6 items at 16x16)
-- Run: /Applications/Aseprite.app/Contents/MacOS/aseprite -b --script resources/items/sprites/generate_items.lua
-- Volumetric 3D items with strong directional lighting (upper-left source)

local H = dofile("/Users/gorishniymax/Repos/factor/tools/aseprite_helper.lua")

local OUT_DIR = "/Users/gorishniymax/Repos/factor/resources/items/sprites"

-- Create a 96x16 sprite (6 columns x 1 row, 16x16 each)
local spr = Sprite(96, 16, ColorMode.RGB)
app.activeSprite = spr

local img = Image(96, 16, ColorMode.RGB)

-- Helper: offset drawing for each cell (1-based cell index)
local function ox(cell, x) return (cell - 1) * 16 + x end

-- Generic pixel map renderer
local function draw_map(img, cell, data, pmap)
  for y = 0, 15 do
    if data[y] then
      for x = 0, 15 do
        local v = data[y][x+1]
        if v and v > 0 and pmap[v] then
          H.px(img, ox(cell, x), y, pmap[v])
        end
      end
    end
  end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PALETTES — 8 tones each for deep volumetric shading
-- Tone 8 = anti-alias / shadow edge (dark semi-transparent feel)
-- ═══════════════════════════════════════════════════════════════════════════

local pyro = {
  H.hex("#3D0E06"),   -- 1: deepest shadow (bottom-right faces)
  H.hex("#6E1A0C"),   -- 2: dark shadow
  H.hex("#A83820"),   -- 3: mid shadow face
  H.hex("#D05830"),   -- 4: mid lit face
  H.hex("#FF7840"),   -- 5: bright lit face
  H.hex("#FFB050"),   -- 6: warm glow / ember
  H.hex("#FFE068"),   -- 7: specular / hottest point
  H.hex("#802818"),   -- 8: anti-alias edge
}

local crys = {
  H.hex("#162838"),   -- 1: deepest shadow
  H.hex("#2A4058"),   -- 2: dark face
  H.hex("#406888"),   -- 3: mid shadow
  H.hex("#6098B8"),   -- 4: mid lit
  H.hex("#90C8E0"),   -- 5: bright face
  H.hex("#C0E8F8"),   -- 6: highlight
  H.hex("#FFFFFF"),   -- 7: specular
  H.hex("#304858"),   -- 8: anti-alias edge
}

local bio = {
  H.hex("#142810"),   -- 1: deepest shadow
  H.hex("#244820"),   -- 2: dark shell
  H.hex("#3C7838"),   -- 3: mid body
  H.hex("#58B050"),   -- 4: lit surface
  H.hex("#8848A8"),   -- 5: purple accent
  H.hex("#B870D8"),   -- 6: core glow
  H.hex("#E0A8F8"),   -- 7: core specular
  H.hex("#304828"),   -- 8: anti-alias edge
}

local steam = {
  H.hex("#202838"),   -- 1: deepest cool shadow
  H.hex("#384868"),   -- 2: cool shadow
  H.hex("#607898"),   -- 3: cool mid
  H.hex("#90A8C8"),   -- 4: neutral light
  H.hex("#F0A848"),   -- 5: warm mid
  H.hex("#FFD080"),   -- 6: warm highlight
  H.hex("#FFF0C0"),   -- 7: bright warm specular
  H.hex("#485868"),   -- 8: anti-alias edge
}

local verd = {
  H.hex("#102018"),   -- 1: deepest shadow
  H.hex("#203830"),   -- 2: dark crystal
  H.hex("#386858"),   -- 3: mid body
  H.hex("#58A890"),   -- 4: lit face
  H.hex("#306828"),   -- 5: vine dark
  H.hex("#50A838"),   -- 6: vine lit
  H.hex("#88E0C8"),   -- 7: crystal specular
  H.hex("#284838"),   -- 8: anti-alias edge
}

local frozen = {
  H.hex("#281020"),   -- 1: deepest shadow
  H.hex("#482038"),   -- 2: dark flame
  H.hex("#883050"),   -- 3: mid flame
  H.hex("#D84868"),   -- 4: bright flame
  H.hex("#FF7888"),   -- 5: hot glow
  H.hex("#48B848"),   -- 6: green vine
  H.hex("#FFA8B0"),   -- 7: flame specular
  H.hex("#582838"),   -- 8: anti-alias edge
}


-- ═══════════════════════════════════════════════════════════════════════════
-- 1. PYROMITE — Two jagged crystal shards, angular and asymmetric
--    Main shard: thick, leans upper-left to lower-right, faceted.
--    Secondary shard: smaller, lower-right, catches light differently.
--    Light from upper-left: left faces bright (5,6,7), right faces dark (1,2).
--    Ember glow where shards overlap at base. Bottom shadow edge.
-- ═══════════════════════════════════════════════════════════════════════════
local pyro_data = {
  [0]  = {  0, 0, 0, 0, 0, 0, 0, 0, 7, 6, 5, 0, 0, 0, 0, 0 },
  [1]  = {  0, 0, 0, 0, 0, 0, 0, 7, 6, 5, 4, 8, 0, 0, 0, 0 },
  [2]  = {  0, 0, 0, 0, 0, 0, 7, 6, 5, 4, 3, 2, 0, 0, 0, 0 },
  [3]  = {  0, 0, 0, 0, 0, 6, 6, 5, 4, 4, 3, 2, 8, 0, 0, 0 },
  [4]  = {  0, 0, 0, 0, 6, 5, 5, 4, 4, 3, 3, 2, 1, 0, 0, 0 },
  [5]  = {  0, 0, 0, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1, 0, 0, 0 },
  [6]  = {  0, 0, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1, 0, 0, 0, 0 },
  [7]  = {  0, 6, 6, 5, 4, 4, 3, 3, 3, 2, 1, 0, 0, 0, 0, 0 },
  [8]  = {  0, 8, 5, 5, 4, 6, 4, 3, 2, 2, 1, 0, 0, 5, 7, 0 },
  [9]  = {  0, 0, 8, 4, 4, 4, 3, 3, 2, 1, 0, 0, 5, 6, 5, 8 },
  [10] = {  0, 0, 0, 8, 4, 6, 4, 3, 2, 8, 0, 6, 5, 4, 3, 1 },
  [11] = {  0, 0, 0, 0, 3, 7, 6, 3, 1, 0, 6, 6, 4, 3, 2, 1 },
  [12] = {  0, 0, 0, 0, 8, 3, 3, 2, 8, 0, 5, 4, 4, 3, 1, 8 },
  [13] = {  0, 0, 0, 0, 0, 8, 2, 1, 0, 0, 8, 3, 3, 2, 8, 0 },
  [14] = {  0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 8, 1, 8, 0, 0 },
  [15] = {  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0 },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. CRYSTALLINE — Tall hexagonal prism, symmetrical, faceted
--    Three visible faces: top (6,7), left face (4,5), right face (2,3).
--    Central ridge line divides left/right faces. Specular on top-left vertex.
--    Clean geometric silhouette, tallest item in the set.
-- ═══════════════════════════════════════════════════════════════════════════
local crys_data = {
  [0]  = {  0, 0, 0, 0, 0, 7, 6, 6, 5, 4, 0, 0, 0, 0, 0, 0 },
  [1]  = {  0, 0, 0, 0, 7, 6, 5, 6, 4, 3, 8, 0, 0, 0, 0, 0 },
  [2]  = {  0, 0, 0, 7, 6, 5, 5, 6, 4, 3, 2, 8, 0, 0, 0, 0 },
  [3]  = {  0, 0, 7, 5, 5, 5, 4, 6, 4, 3, 2, 2, 8, 0, 0, 0 },
  [4]  = {  0, 6, 5, 5, 5, 4, 4, 6, 4, 3, 3, 2, 1, 8, 0, 0 },
  [5]  = {  0, 6, 5, 5, 4, 4, 5, 6, 4, 3, 3, 2, 2, 1, 0, 0 },
  [6]  = {  0, 5, 5, 5, 4, 4, 5, 7, 5, 3, 3, 2, 2, 1, 0, 0 },
  [7]  = {  0, 5, 5, 4, 4, 5, 6, 7, 6, 4, 3, 2, 2, 1, 0, 0 },
  [8]  = {  0, 5, 5, 4, 4, 4, 5, 5, 4, 3, 3, 2, 2, 1, 0, 0 },
  [9]  = {  0, 8, 5, 4, 4, 4, 4, 4, 3, 3, 3, 2, 1, 8, 0, 0 },
  [10] = {  0, 0, 8, 4, 4, 4, 4, 4, 3, 3, 2, 2, 8, 0, 0, 0 },
  [11] = {  0, 0, 0, 8, 4, 4, 3, 3, 3, 2, 2, 8, 0, 0, 0, 0 },
  [12] = {  0, 0, 0, 0, 8, 3, 3, 3, 2, 2, 8, 0, 0, 0, 0, 0 },
  [13] = {  0, 0, 0, 0, 0, 8, 2, 2, 2, 8, 0, 0, 0, 0, 0, 0 },
  [14] = {  0, 0, 0, 0, 0, 0, 8, 1, 8, 0, 0, 0, 0, 0, 0, 0 },
  [15] = {  0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0 },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. BIOVINE — Organic curled seed pod with vine spiral, glowing purple core
--    Fat rounded pod shape upper-left, curling tendril reaches to lower-right.
--    Purple core glows through the translucent green shell (center of pod).
--    Bumpy organic surface, asymmetric. Pod is the main volume.
-- ═══════════════════════════════════════════════════════════════════════════
local bio_data = {
  [0]  = {  0, 0, 0, 0, 0, 4, 4, 3, 0, 0, 0, 0, 0, 0, 0, 0 },
  [1]  = {  0, 0, 0, 0, 4, 4, 3, 3, 2, 0, 0, 0, 0, 0, 0, 0 },
  [2]  = {  0, 0, 0, 4, 4, 4, 3, 3, 2, 1, 0, 0, 0, 0, 0, 0 },
  [3]  = {  0, 0, 4, 4, 3, 3, 3, 2, 2, 1, 8, 0, 0, 0, 0, 0 },
  [4]  = {  0, 4, 4, 3, 7, 6, 5, 3, 2, 1, 0, 0, 0, 0, 0, 0 },
  [5]  = {  4, 4, 3, 6, 7, 6, 7, 6, 2, 1, 8, 0, 0, 0, 0, 0 },
  [6]  = {  4, 3, 3, 7, 6, 7, 6, 5, 2, 1, 0, 0, 0, 0, 0, 0 },
  [7]  = {  4, 3, 5, 6, 7, 6, 5, 3, 2, 1, 0, 0, 0, 0, 0, 0 },
  [8]  = {  8, 3, 3, 5, 6, 5, 3, 2, 2, 1, 8, 0, 0, 0, 0, 0 },
  [9]  = {  0, 8, 3, 3, 5, 3, 3, 2, 1, 8, 0, 0, 0, 4, 3, 0 },
  [10] = {  0, 0, 8, 3, 3, 3, 2, 2, 1, 0, 0, 0, 4, 4, 3, 8 },
  [11] = {  0, 0, 0, 8, 2, 3, 2, 1, 8, 0, 0, 4, 3, 3, 2, 1 },
  [12] = {  0, 0, 0, 0, 8, 2, 2, 1, 8, 0, 4, 4, 3, 2, 1, 8 },
  [13] = {  0, 0, 0, 0, 0, 8, 1, 1, 2, 3, 3, 3, 2, 1, 8, 0 },
  [14] = {  0, 0, 0, 0, 0, 0, 8, 8, 1, 2, 2, 1, 1, 8, 0, 0 },
  [15] = {  0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8, 8, 0, 0, 0, 0 },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. STEAM BURST — Contained ball of swirling steam/energy, oblate puff
--    Wider than tall. Warm orange upper-left, cool blue lower-right.
--    Visible vortex swirl: warm spiral from upper-left, cool on lower-right.
--    Wispy anti-aliased edges. Small detached wisp upper-right.
-- ═══════════════════════════════════════════════════════════════════════════
local steam_data = {
  [0]  = {  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
  [1]  = {  0, 0, 0, 0, 8, 7, 6, 5, 8, 0, 0, 0, 0, 0, 0, 0 },
  [2]  = {  0, 0, 0, 7, 6, 6, 5, 5, 4, 8, 0, 0, 8, 4, 8, 0 },
  [3]  = {  0, 0, 7, 6, 6, 5, 5, 4, 4, 4, 8, 4, 4, 3, 2, 8 },
  [4]  = {  0, 8, 6, 6, 5, 5, 4, 4, 4, 4, 4, 4, 3, 3, 2, 8 },
  [5]  = {  8, 6, 6, 5, 5, 7, 6, 5, 4, 4, 3, 3, 3, 2, 2, 8 },
  [6]  = {  8, 5, 5, 5, 6, 7, 6, 5, 4, 3, 3, 3, 2, 2, 1, 8 },
  [7]  = {  8, 5, 5, 6, 7, 6, 5, 4, 4, 4, 3, 3, 2, 1, 1, 8 },
  [8]  = {  8, 5, 5, 5, 6, 5, 4, 4, 3, 3, 3, 2, 2, 1, 8, 0 },
  [9]  = {  8, 4, 4, 4, 5, 4, 4, 3, 3, 3, 2, 2, 1, 8, 0, 0 },
  [10] = {  0, 8, 4, 4, 4, 4, 3, 3, 3, 2, 2, 1, 8, 0, 0, 0 },
  [11] = {  0, 0, 8, 3, 3, 3, 3, 2, 2, 2, 1, 8, 0, 0, 0, 0 },
  [12] = {  0, 0, 0, 8, 3, 3, 2, 2, 2, 1, 8, 0, 0, 0, 0, 0 },
  [13] = {  0, 0, 0, 0, 8, 8, 2, 1, 8, 8, 0, 0, 0, 0, 0, 0 },
  [14] = {  0, 0, 0, 0, 0, 0, 8, 8, 0, 0, 0, 0, 0, 0, 0, 0 },
  [15] = {  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. VERDANT COMPOUND — Diamond/gem shape with vine veins through crystal
--    Pointed top and bottom, widest at center. Clean faceted diamond.
--    Top-left faces bright (4,7), bottom-right dark (1,2). Vine veins (5,6)
--    run diagonally across facets. Specular on top-left edge.
-- ═══════════════════════════════════════════════════════════════════════════
local verd_data = {
  [0]  = {  0, 0, 0, 0, 0, 0, 0, 7, 4, 0, 0, 0, 0, 0, 0, 0 },
  [1]  = {  0, 0, 0, 0, 0, 0, 7, 4, 4, 3, 0, 0, 0, 0, 0, 0 },
  [2]  = {  0, 0, 0, 0, 0, 7, 4, 4, 6, 3, 8, 0, 0, 0, 0, 0 },
  [3]  = {  0, 0, 0, 0, 7, 4, 4, 6, 5, 3, 2, 8, 0, 0, 0, 0 },
  [4]  = {  0, 0, 0, 4, 4, 6, 5, 4, 3, 5, 6, 2, 1, 0, 0, 0 },
  [5]  = {  0, 0, 4, 4, 6, 5, 4, 4, 3, 3, 5, 6, 2, 1, 0, 0 },
  [6]  = {  0, 4, 4, 3, 5, 4, 4, 7, 4, 3, 3, 5, 2, 2, 1, 0 },
  [7]  = {  0, 4, 4, 6, 4, 4, 7, 4, 4, 3, 3, 3, 6, 2, 1, 0 },
  [8]  = {  0, 8, 3, 3, 5, 4, 4, 4, 3, 3, 2, 6, 2, 1, 0, 0 },
  [9]  = {  0, 0, 8, 3, 3, 5, 6, 3, 3, 5, 6, 2, 1, 8, 0, 0 },
  [10] = {  0, 0, 0, 8, 3, 5, 6, 3, 6, 5, 2, 1, 8, 0, 0, 0 },
  [11] = {  0, 0, 0, 0, 8, 2, 5, 6, 5, 2, 1, 8, 0, 0, 0, 0 },
  [12] = {  0, 0, 0, 0, 0, 8, 2, 5, 2, 1, 8, 0, 0, 0, 0, 0 },
  [13] = {  0, 0, 0, 0, 0, 0, 8, 2, 1, 8, 0, 0, 0, 0, 0, 0 },
  [14] = {  0, 0, 0, 0, 0, 0, 0, 8, 8, 0, 0, 0, 0, 0, 0, 0 },
  [15] = {  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 6. FROZEN FLAME — Flame shape with vine tendrils wrapping it
--    Main flame tongue rises from bottom-center, leans left. Smaller secondary
--    flame upper-right. Green vine (6) wraps around in a spiral pattern.
--    Hot glow (5,7) in the core, dark base (1,2). Teardrop silhouette.
-- ═══════════════════════════════════════════════════════════════════════════
local frozen_data = {
  [0]  = {  0, 0, 0, 0, 0, 7, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
  [1]  = {  0, 0, 0, 0, 7, 5, 5, 4, 0, 0, 0, 0, 0, 0, 0, 0 },
  [2]  = {  0, 0, 0, 7, 5, 5, 4, 3, 8, 0, 0, 0, 5, 0, 0, 0 },
  [3]  = {  0, 0, 7, 5, 5, 4, 6, 3, 2, 8, 0, 5, 7, 5, 0, 0 },
  [4]  = {  0, 7, 5, 5, 4, 6, 3, 3, 2, 0, 0, 5, 4, 3, 8, 0 },
  [5]  = {  0, 5, 5, 4, 6, 4, 3, 3, 2, 8, 4, 6, 3, 2, 1, 0 },
  [6]  = {  0, 5, 4, 6, 4, 4, 3, 6, 3, 2, 4, 3, 6, 2, 1, 0 },
  [7]  = {  0, 4, 4, 4, 3, 3, 6, 4, 6, 3, 3, 3, 2, 1, 8, 0 },
  [8]  = {  0, 4, 4, 3, 6, 3, 3, 3, 3, 6, 3, 2, 1, 8, 0, 0 },
  [9]  = {  0, 8, 3, 6, 3, 3, 3, 3, 6, 2, 2, 1, 8, 0, 0, 0 },
  [10] = {  0, 0, 8, 3, 3, 6, 3, 3, 3, 2, 1, 8, 0, 0, 0, 0 },
  [11] = {  0, 0, 0, 8, 3, 3, 6, 3, 2, 2, 1, 0, 0, 0, 0, 0 },
  [12] = {  0, 0, 0, 0, 8, 2, 3, 6, 2, 1, 8, 0, 0, 0, 0, 0 },
  [13] = {  0, 0, 0, 0, 0, 8, 2, 2, 1, 8, 0, 0, 0, 0, 0, 0 },
  [14] = {  0, 0, 0, 0, 0, 0, 8, 1, 8, 0, 0, 0, 0, 0, 0, 0 },
  [15] = {  0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0 },
}


-- ═══════════════════════════════════════════════════════════════════════════
-- RENDER ALL
-- ═══════════════════════════════════════════════════════════════════════════

draw_map(img, 1, pyro_data, pyro)
draw_map(img, 2, crys_data, crys)
draw_map(img, 3, bio_data, bio)
draw_map(img, 4, steam_data, steam)
draw_map(img, 5, verd_data, verd)
draw_map(img, 6, frozen_data, frozen)

-- Put image into the sprite's cel
local cel = spr.cels[1]
cel.image = img

-- Save as PNG directly
spr:saveCopyAs(OUT_DIR .. "/item_atlas.png")
spr:close()

print("Done! Saved item_atlas.png")
