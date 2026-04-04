-- generate_examples.lua — Aseprite script that generates example PNGs
-- Run: /Applications/Godot.app/…  (no, this runs in Aseprite)
-- Usage: aseprite -b --script tools/rendering/iso/examples/generate_examples.lua
--
-- Generates:
--   01_primitives.png  — All basic shapes in a grid
--   02_shading.png     — Lighting and material comparison
--   03_gear_rotation.png — Animated gear spritesheet (4 frames)
--   04_mechanical.png  — Compound mechanical parts
--   05_textures.png    — Surface texture catalog
--   06_scene.png       — Full building scene with multiple shapes

local REPO = "/Users/gorishniymax/Repos/factor"
local OUT  = REPO .. "/tools/rendering/iso/examples"

local H   = dofile(REPO .. "/tools/aseprite_helper.lua")
local Iso = dofile(REPO .. "/tools/rendering/iso/init.lua")
Iso._set_helper(H)

-- Shared colors
local BROWN      = H.hex("#8B7355")
local DARK_BROWN = H.hex("#5C4A32")
local OUTLINE    = H.hex("#191412")
local METAL      = H.hex("#7B8894")
local COPPER     = H.hex("#B87333")
local RED        = H.hex("#C0392B")
local GREEN      = H.hex("#27AE60")
local BLUE       = H.hex("#2980B9")
local STONE      = H.hex("#8E8E8E")

-- ═══════════════════════════════════════════════════════════════════════
-- HELPER: render a shape to a fresh image at center
-- ═══════════════════════════════════════════════════════════════════════

local function render_single(shape, w, h, colors, opts)
  local img = Image(w, h, ColorMode.RGB)
  local cx = math.floor(w / 2)
  local cy = math.floor(h * 0.65)
  Iso.render_shape(img, shape, cx, cy, colors, opts)
  return img
end

-- ═══════════════════════════════════════════════════════════════════════
-- 01: PRIMITIVES — all shapes in a 4×3 grid
-- ═══════════════════════════════════════════════════════════════════════

local function gen_01_primitives()
  local cell_w, cell_h = 80, 80
  local cols, rows = 4, 3
  local img = Image(cell_w * cols, cell_h * rows, ColorMode.RGB)

  local colors = { base = BROWN, outline = OUTLINE }
  local shapes = {
    { Iso.box(16, 16, 12),           "Box" },
    { Iso.cylinder(10, 16),          "Cylinder" },
    { Iso.cone(10, 16),              "Cone" },
    { Iso.sphere(10),                "Sphere" },
    { Iso.hemisphere(10),            "Hemisphere" },
    { Iso.wedge(16, 16, 16, 4),      "Wedge" },
    { Iso.prism(16, 16, 14),         "Prism" },
    { Iso.torus(10, 4),              "Torus" },
    { Iso.arch(16, 12, 18, 6),       "Arch" },
    { Iso.box(20, 8, 10),            "Wide Box" },
    { Iso.cylinder(6, 20),           "Tall Cyl" },
    { Iso.cone(12, 8),               "Flat Cone" },
  }

  for i, entry in ipairs(shapes) do
    local shape = entry[1]
    local col = ((i - 1) % cols)
    local row = math.floor((i - 1) / cols)
    local ox = col * cell_w + math.floor(cell_w / 2)
    local oy = row * cell_h + math.floor(cell_h * 0.65)

    Iso.render_shape(img, shape, ox, oy, colors)
  end

  -- Save
  local spr = Sprite(img.width, img.height, ColorMode.RGB)
  spr.cels[1].image = img
  spr:saveCopyAs(OUT .. "/01_primitives.png")
  spr:close()
  print("[example] 01_primitives.png")
end

-- ═══════════════════════════════════════════════════════════════════════
-- 02: SHADING — same box with different lighting/materials
-- ═══════════════════════════════════════════════════════════════════════

local function gen_02_shading()
  local cell_w, cell_h = 80, 80
  local cols, rows = 4, 2
  local img = Image(cell_w * cols, cell_h * rows, ColorMode.RGB)

  local box = Iso.box(16, 16, 12)

  local configs = {
    -- Row 1: different base colors with auto-shade
    { colors = { base = BROWN, outline = OUTLINE },    label = "Brown" },
    { colors = { base = METAL, outline = OUTLINE },    label = "Metal" },
    { colors = { base = COPPER, outline = OUTLINE },   label = "Copper" },
    { colors = { base = RED, outline = OUTLINE },      label = "Red" },
    -- Row 2: manual face colors + specular
    { colors = { top = H.hex("#A0906D"), front_left = H.hex("#6B5535"),
                 front_right = H.hex("#7B6545"), outline = OUTLINE },
      label = "Manual" },
    { colors = { base = METAL, outline = OUTLINE },
      opts = { shading = { specular = 0.5, spec_pow = 4 } },
      label = "Specular" },
    { colors = { base = STONE, outline = OUTLINE },
      opts = { shading = { ambient = 0.5, diffuse = 0.5 } },
      label = "Ambient" },
    { colors = { base = DARK_BROWN, outline = OUTLINE },
      opts = { shading = { ambient = 0.2, diffuse = 0.8 } },
      label = "Dramatic" },
  }

  for i, cfg in ipairs(configs) do
    local col = ((i - 1) % cols)
    local row = math.floor((i - 1) / cols)
    local ox = col * cell_w + math.floor(cell_w / 2)
    local oy = row * cell_h + math.floor(cell_h * 0.65)
    Iso.render_shape(img, box, ox, oy, cfg.colors, cfg.opts)
  end

  local spr = Sprite(img.width, img.height, ColorMode.RGB)
  spr.cels[1].image = img
  spr:saveCopyAs(OUT .. "/02_shading.png")
  spr:close()
  print("[example] 02_shading.png")
end

-- ═══════════════════════════════════════════════════════════════════════
-- 03: GEAR ROTATION — 4 frames of a rotating gear
-- ═══════════════════════════════════════════════════════════════════════

local function gen_03_gear_rotation()
  local cell_w, cell_h = 64, 64
  local frames = 8
  local img = Image(cell_w * frames, cell_h, ColorMode.RGB)

  local gear_colors = { base = METAL, outline = OUTLINE,
                        hole = H.hex("#333333") }

  for f = 0, frames - 1 do
    local gear = Iso.anim_gear(14, 10, 3, 8, 5, f, frames)
    local ox = f * cell_w + math.floor(cell_w / 2)
    local oy = math.floor(cell_h * 0.6)
    Iso.render_shape(img, gear, ox, oy, gear_colors)
  end

  local spr = Sprite(img.width, img.height, ColorMode.RGB)
  spr.cels[1].image = img
  spr:saveCopyAs(OUT .. "/03_gear_rotation.png")
  spr:close()
  print("[example] 03_gear_rotation.png")
end

-- ═══════════════════════════════════════════════════════════════════════
-- 04: MECHANICAL — compound parts (pipe, gear on axle, piston, fan)
-- ═══════════════════════════════════════════════════════════════════════

local function gen_04_mechanical()
  local cell_w, cell_h = 80, 80
  local cols, rows = 4, 2
  local img = Image(cell_w * cols, cell_h * rows, ColorMode.RGB)

  local parts = {
    { Iso.pipe("x", 20, 4, 1),           { base = METAL, outline = OUTLINE } },
    { Iso.pipe("y", 20, 4, 1),           { base = COPPER, outline = OUTLINE } },
    { Iso.gear(12, 8, 2, 8, 4, 0),       { base = METAL, outline = OUTLINE } },
    { Iso.fan(4, 14, 0.4, 2, 3, 0),      { base = COPPER, outline = OUTLINE } },
    { Iso.piston(6, 3, 12, 8),           { base = METAL, outline = OUTLINE } },
    { Iso.axle("x", 24, 2),              { base = STONE, outline = OUTLINE } },
    { Iso.pipe_elbow(8, 3),              { base = COPPER, outline = OUTLINE } },
    { Iso.valve_wheel(8, 5, 2, 0),       { base = RED, outline = OUTLINE } },
  }

  for i, entry in ipairs(parts) do
    local shape, colors = entry[1], entry[2]
    local col = ((i - 1) % cols)
    local row = math.floor((i - 1) / cols)
    local ox = col * cell_w + math.floor(cell_w / 2)
    local oy = row * cell_h + math.floor(cell_h * 0.65)
    Iso.render_shape(img, shape, ox, oy, colors)
  end

  local spr = Sprite(img.width, img.height, ColorMode.RGB)
  spr.cels[1].image = img
  spr:saveCopyAs(OUT .. "/04_mechanical.png")
  spr:close()
  print("[example] 04_mechanical.png")
end

-- ═══════════════════════════════════════════════════════════════════════
-- 05: TEXTURES — same box with different surface textures
-- ═══════════════════════════════════════════════════════════════════════

local function gen_05_textures()
  local cell_w, cell_h = 80, 80
  local cols, rows = 4, 3
  local img = Image(cell_w * cols, cell_h * rows, ColorMode.RGB)

  local box = Iso.box(18, 18, 14)

  local textures = {
    { nil,                                    BROWN,  "Plain" },
    { Iso.tex_noise(0.2),                     BROWN,  "Noise" },
    { Iso.tex_brick(4, 3),                    RED,    "Brick" },
    { Iso.tex_metal_plate(8, 8),              METAL,  "Metal Plate" },
    { Iso.tex_grate(3, 1.5, "u"),             METAL,  "Grate" },
    { Iso.tex_wood_grain(2),                  BROWN,  "Wood" },
    { Iso.tex_corrugated(2.5),                METAL,  "Corrugated" },
    { Iso.tex_diamond_plate(3),               METAL,  "Diamond" },
    { Iso.tex_hex_mesh(4),                    STONE,  "Hex Mesh" },
    { Iso.tex_compose(Iso.tex_noise(0.1),
        Iso.tex_brick(5, 3)),                 BROWN,  "Noisy Brick" },
    { Iso.tex_compose(Iso.tex_metal_plate(6,6),
        Iso.tex_noise(0.08)),                 METAL,  "Worn Metal" },
    { Iso.tex_rivets(4, 1),                   COPPER, "Rivets" },
  }

  for i, entry in ipairs(textures) do
    local tex, base, _label = entry[1], entry[2], entry[3]
    local col = ((i - 1) % cols)
    local row = math.floor((i - 1) / cols)
    local ox = col * cell_w + math.floor(cell_w / 2)
    local oy = row * cell_h + math.floor(cell_h * 0.65)

    local colors = { base = base, outline = OUTLINE }
    local opts = tex and { texture = tex } or {}
    Iso.render_shape(img, box, ox, oy, colors, opts)
  end

  local spr = Sprite(img.width, img.height, ColorMode.RGB)
  spr.cels[1].image = img
  spr:saveCopyAs(OUT .. "/05_textures.png")
  spr:close()
  print("[example] 05_textures.png")
end

-- ═══════════════════════════════════════════════════════════════════════
-- 06: SCENE — composite building with multiple shapes
-- ═══════════════════════════════════════════════════════════════════════

local function gen_06_scene()
  local w, h = 128, 128
  local img = Image(w, h, ColorMode.RGB)

  local sc = Iso.scene(w, h, 64, 96)

  -- Base box (building body)
  sc:add(Iso.box(24, 24, 16), {0, 0, 0},
    { base = BROWN, outline = OUTLINE },
    { texture = Iso.tex_metal_plate(8, 8) })

  -- Chimney (cylinder on top)
  sc:add(Iso.cylinder(4, 12), {4, 4, 16},
    { base = STONE, outline = OUTLINE })

  -- Dome on roof
  sc:add(Iso.hemisphere(5), {16, 16, 16},
    { base = COPPER, outline = OUTLINE })

  -- Gear on the side
  sc:add(Iso.gear(6, 4, 1.5, 6, 3, 0.3), {24, 12, 8},
    { base = METAL, outline = OUTLINE })

  -- Small box detail
  sc:add(Iso.box(4, 4, 3), {-4, 10, 0},
    { base = DARK_BROWN, outline = OUTLINE })

  sc:draw(img, OUTLINE)

  local spr = Sprite(img.width, img.height, ColorMode.RGB)
  spr.cels[1].image = img
  spr:saveCopyAs(OUT .. "/06_scene.png")
  spr:close()
  print("[example] 06_scene.png")
end

-- ═══════════════════════════════════════════════════════════════════════
-- 07: PROJECTION COMPARISON — same box in different projection presets
-- ═══════════════════════════════════════════════════════════════════════

local function gen_07_projections()
  local cell_w, cell_h = 80, 80
  local cols = 5
  local img = Image(cell_w * cols, cell_h, ColorMode.RGB)

  local presets = {
    { "2:1 Dimetric",  function() Iso.preset_2_1() end },
    { "True Iso",      function() Iso.preset_true_iso() end },
    { "Steep (1:1)",   function() Iso.preset_steep() end },
    { "Flat (3:1)",    function() Iso.preset_flat() end },
    { "Military",      function() Iso.preset_military() end },
  }

  local colors = { base = BROWN, outline = OUTLINE }

  for i, preset in ipairs(presets) do
    preset[2]()  -- apply preset
    local box = Iso.box(14, 14, 10)  -- must recreate after config change
    local ox = (i - 1) * cell_w + math.floor(cell_w / 2)
    local oy = math.floor(cell_h * 0.65)
    Iso.render_shape(img, box, ox, oy, colors)
  end

  -- Restore default
  Iso.preset_2_1()

  local spr = Sprite(img.width, img.height, ColorMode.RGB)
  spr.cels[1].image = img
  spr:saveCopyAs(OUT .. "/07_projections.png")
  spr:close()
  print("[example] 07_projections.png")
end

-- ═══════════════════════════════════════════════════════════════════════
-- 08: CSG — boolean operations demo
-- ═══════════════════════════════════════════════════════════════════════

local function gen_08_csg()
  local cell_w, cell_h = 96, 80
  local cols = 3
  local img = Image(cell_w * cols, cell_h, ColorMode.RGB)

  local box = Iso.box(16, 16, 12)
  local cyl = Iso.translate(Iso.cylinder(7, 14), 8, 8, -1)

  local ops = {
    Iso.union(box, cyl),
    Iso.subtract(box, cyl),
    Iso.intersect(box, cyl),
  }

  local colors = { base = BROWN, outline = OUTLINE }
  for i, shape in ipairs(ops) do
    local ox = (i - 1) * cell_w + math.floor(cell_w / 2)
    local oy = math.floor(cell_h * 0.65)
    Iso.render_shape(img, shape, ox, oy, colors)
  end

  local spr = Sprite(img.width, img.height, ColorMode.RGB)
  spr.cels[1].image = img
  spr:saveCopyAs(OUT .. "/08_csg.png")
  spr:close()
  print("[example] 08_csg.png")
end

-- ═══════════════════════════════════════════════════════════════════════
-- RUN ALL
-- ═══════════════════════════════════════════════════════════════════════

print("=== Generating iso_geo examples ===")
gen_01_primitives()
gen_02_shading()
gen_03_gear_rotation()
gen_04_mechanical()
gen_05_textures()
gen_06_scene()
gen_07_projections()
gen_08_csg()
print("=== Done! ===")
