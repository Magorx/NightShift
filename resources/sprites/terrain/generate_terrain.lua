-- Isometric terrain atlas generator for Night Shift
-- Generates an 8x15 grid of 64x32 isometric diamond tiles (512x480 total)
-- Run: aseprite -b --script generate_terrain.lua

local CELL_W = 64
local CELL_H = 32
local COLS = 8
local ROWS = 15
local W = COLS * CELL_W  -- 512
local H = ROWS * CELL_H  -- 480

-- ── Deterministic hash / noise ──────────────────────────────────────────

local function hash(x, y, seed)
    local h = x * 374761393 + y * 668265263 + (seed or 0) * 1274126177
    h = (h ~ (h >> 13)) * 1274126177
    h = h ~ (h >> 16)
    return (h % 10000) / 10000.0
end

local function value_noise(x, y, freq, seed)
    local fx = x * freq
    local fy = y * freq
    local ix = math.floor(fx)
    local iy = math.floor(fy)
    local fx2 = fx - ix
    local fy2 = fy - iy
    fx2 = fx2 * fx2 * (3 - 2 * fx2)
    fy2 = fy2 * fy2 * (3 - 2 * fy2)
    local v00 = hash(ix, iy, seed)
    local v10 = hash(ix + 1, iy, seed)
    local v01 = hash(ix, iy + 1, seed)
    local v11 = hash(ix + 1, iy + 1, seed)
    local top = v00 + (v10 - v00) * fx2
    local bot = v01 + (v11 - v01) * fx2
    return top + (bot - top) * fy2
end

local function fbm(x, y, octaves, seed)
    local val = 0
    local amp = 1
    local freq = 0.12
    local total_amp = 0
    for i = 1, octaves do
        val = val + value_noise(x, y, freq, seed + i * 1000) * amp
        total_amp = total_amp + amp
        amp = amp * 0.5
        freq = freq * 2
    end
    return val / total_amp
end

-- ── Color helpers ───────────────────────────────────────────────────────

local function rgba(r, g, b, a)
    return app.pixelColor.rgba(r, g, b, a or 255)
end

local TRANSPARENT = app.pixelColor.rgba(0, 0, 0, 0)

local function hex(s)
    s = s:gsub("^#", "")
    return rgba(tonumber(s:sub(1,2), 16), tonumber(s:sub(3,4), 16), tonumber(s:sub(5,6), 16))
end

local function decompose(c)
    return app.pixelColor.rgbaR(c), app.pixelColor.rgbaG(c), app.pixelColor.rgbaB(c), app.pixelColor.rgbaA(c)
end

local function lerp(c1, c2, t)
    t = math.max(0, math.min(1, t))
    local r1, g1, b1, a1 = decompose(c1)
    local r2, g2, b2, a2 = decompose(c2)
    return rgba(
        math.floor(r1 + (r2 - r1) * t + 0.5),
        math.floor(g1 + (g2 - g1) * t + 0.5),
        math.floor(b1 + (b2 - b1) * t + 0.5),
        math.floor(a1 + (a2 - a1) * t + 0.5)
    )
end

local function brighten(c, factor)
    local r, g, b, a = decompose(c)
    local function cl(v) return math.max(0, math.min(255, math.floor(v * factor + 0.5))) end
    return rgba(cl(r), cl(g), cl(b), a)
end

local function with_alpha(c, alpha)
    local r, g, b = decompose(c)
    return rgba(r, g, b, alpha)
end

local function add_color(c1, c2, strength)
    strength = strength or 1.0
    local r1, g1, b1, a1 = decompose(c1)
    local r2, g2, b2 = decompose(c2)
    local function cl(v) return math.max(0, math.min(255, math.floor(v + 0.5))) end
    return rgba(
        cl(r1 + r2 * strength),
        cl(g1 + g2 * strength),
        cl(b1 + b2 * strength),
        a1
    )
end

-- ── Isometric diamond check ─────────────────────────────────────────────
-- Returns true if (px, py) is inside the isometric diamond in a 64x32 cell
-- Also returns normalized u,v coords within the diamond (0-1 range)

local function in_diamond(px, py)
    -- Diamond vertices: top(32,0) right(63,16) bottom(32,31) left(0,16)
    local cx = 31.5  -- center x
    local cy = 15.5  -- center y
    local dx = math.abs(px - cx) / 32.0
    local dy = math.abs(py - cy) / 16.0
    return (dx + dy) <= 1.0, (px - cx) / 32.0, (py - cy) / 16.0
end

-- Distance from diamond edge (0 = edge, 1 = center)
local function diamond_depth(px, py)
    local cx = 31.5
    local cy = 15.5
    local dx = math.abs(px - cx) / 32.0
    local dy = math.abs(py - cy) / 16.0
    local d = dx + dy
    if d > 1.0 then return -1 end
    return 1.0 - d
end

-- Edge detection for iso shading
local function iso_shade(px, py, base_color, highlight_factor, shadow_factor)
    local depth = diamond_depth(px, py)
    if depth < 0 then return TRANSPARENT end

    -- Top-right edge gets highlight, bottom-left gets shadow
    local cx = 31.5
    local cy = 15.5
    local nx = (px - cx) / 32.0  -- -1 to 1
    local ny = (py - cy) / 16.0  -- -1 to 1

    -- Light comes from top-right
    local light = (-ny * 0.8 + nx * 0.4)  -- -1 to 1
    light = light * 0.5 + 0.5  -- 0 to 1

    -- Edge darkening (strong outline effect)
    local edge_dark = 1.0
    if depth < 0.06 then
        edge_dark = 0.65 + 0.35 * (depth / 0.06)
    elseif depth < 0.12 then
        edge_dark = 0.85 + 0.15 * ((depth - 0.06) / 0.06)
    end

    local factor = 1.0
    if light > 0.5 then
        factor = 1.0 + (light - 0.5) * 2.0 * (highlight_factor - 1.0)
    else
        factor = 1.0 - (0.5 - light) * 2.0 * (1.0 - shadow_factor)
    end

    return brighten(base_color, factor * edge_dark)
end

-- ── Palettes ────────────────────────────────────────────────────────────

local pal = {
    grass = {
        base = hex("#475C3B"),
        highlight = hex("#556E46"),
        shadow = hex("#3B4D31"),
        dark = hex("#344828"),
        light = hex("#607A50"),
        tuft = hex("#5A7848"),
        tuft_dark = hex("#3E5432"),
        dirt = hex("#6B5D4A"),
        dirt_dark = hex("#574B3C"),
        stone = hex("#7A7A72"),
        flower_r = hex("#B84848"),
        flower_y = hex("#C8B848"),
        flower_w = hex("#D0D0C8"),
    },
    pyromite = {
        base = hex("#8B3A2A"),
        crystal = hex("#C44B32"),
        glow = hex("#FF6B3D"),
        ember = hex("#FF9944"),
        dark = hex("#5C2218"),
        ash = hex("#4A3A35"),
        hot = hex("#FFB060"),
    },
    crystalline = {
        base = hex("#5B7B8F"),
        highlight = hex("#8FB4C9"),
        shadow = hex("#3F5766"),
        crystal = hex("#A8D4E8"),
        ice = hex("#C8E8F4"),
        deep = hex("#2E4555"),
        frost = hex("#D0E8F0"),
    },
    biovine = {
        base = hex("#4B5C3D"),
        vine = hex("#7B4E8A"),
        glow = hex("#5ADB50"),
        spore = hex("#8AEB80"),
        dark = hex("#2E3A28"),
        purple = hex("#9B68AA"),
        mushroom = hex("#B87848"),
        mushcap = hex("#C89868"),
    },
    wall = {
        base = hex("#6B6B6B"),
        highlight = hex("#888888"),
        shadow = hex("#4A4A4A"),
        dark = hex("#383838"),
        light = hex("#9A9A9A"),
        crack = hex("#3A3A3A"),
        moss = hex("#506040"),
    },
    ash = {
        base = hex("#7A6E63"),
        dark = hex("#5C5248"),
        light = hex("#8F8275"),
        crack = hex("#4A4038"),
        ember = hex("#8B4030"),
    },
    voltite = {
        base = hex("#4A4078"),
        yellow = hex("#E8D840"),
        blue = hex("#4080E0"),
        arc = hex("#F0F060"),
        dark = hex("#2A2050"),
    },
    umbrite = {
        base = hex("#3A2850"),
        purple = hex("#6840A0"),
        wisp = hex("#8060C0"),
        dark = hex("#1A1030"),
        glow = hex("#A880E0"),
    },
    resonite = {
        base = hex("#408080"),
        teal = hex("#50B0B0"),
        bright = hex("#80E0D0"),
        dark = hex("#285050"),
        white = hex("#C0F0E8"),
    },
}

-- ── Create sprite ───────────────────────────────────────────────────────

local spr = Sprite(W, H, ColorMode.RGB)
local img = Image(W, H, ColorMode.RGB)

-- Clear to transparent
for y = 0, H - 1 do
    for x = 0, W - 1 do
        img:drawPixel(x, y, TRANSPARENT)
    end
end

-- ── Drawing functions ───────────────────────────────────────────────────

-- Fill a diamond tile at grid position (col, row) with noise-based terrain
local function fill_diamond(col, row, base, dark, light, seed)
    local ox = col * CELL_W
    local oy = row * CELL_H
    for py = 0, CELL_H - 1 do
        for px = 0, CELL_W - 1 do
            local inside = in_diamond(px, py)
            if inside then
                local n = fbm(px + ox, py + oy, 3, seed)
                local c
                if n < 0.4 then
                    c = lerp(dark, base, n / 0.4)
                else
                    c = lerp(base, light, (n - 0.4) / 0.6)
                end
                -- Apply isometric shading
                c = iso_shade(px, py, c, 1.15, 0.85)
                img:drawPixel(ox + px, oy + py, c)
            end
        end
    end
end

-- Draw a pixel within a diamond cell (bounds + diamond checked)
local function dpx(col, row, px, py, c)
    if px < 0 or px >= CELL_W or py < 0 or py >= CELL_H then return end
    local inside = in_diamond(px, py)
    if not inside then return end
    local ox = col * CELL_W
    local oy = row * CELL_H
    img:drawPixel(ox + px, oy + py, c)
end

-- Draw a pixel with alpha blend
local function dpx_blend(col, row, px, py, c, alpha)
    if px < 0 or px >= CELL_W or py < 0 or py >= CELL_H then return end
    local inside = in_diamond(px, py)
    if not inside then return end
    local ox = col * CELL_W
    local oy = row * CELL_H
    local existing = img:getPixel(ox + px, oy + py)
    local blended = lerp(existing, c, alpha / 255.0)
    img:drawPixel(ox + px, oy + py, blended)
end

-- Draw a small cross/tuft detail
local function draw_tuft(col, row, cx, cy, c1, c2, size)
    size = size or 1
    dpx(col, row, cx, cy, c1)
    if size > 0 then
        dpx(col, row, cx - 1, cy, c2)
        dpx(col, row, cx + 1, cy, c2)
    end
    if size > 1 then
        dpx(col, row, cx, cy - 1, c2)
    end
end

-- Draw small dot cluster
local function draw_dots(col, row, cx, cy, c, count, spread, seed)
    for i = 0, count - 1 do
        local dx = math.floor(hash(cx + i, cy, seed) * spread * 2 - spread)
        local dy = math.floor(hash(cx, cy + i, seed + 99) * spread * 2 - spread)
        dpx(col, row, cx + dx, cy + dy, c)
    end
end

-- Draw a small crystal shard
local function draw_crystal(col, row, cx, cy, h, c_base, c_highlight, c_shadow)
    for dy = 0, h - 1 do
        local w = math.max(1, math.floor((h - dy) * 0.8))
        for dx = -math.floor(w / 2), math.floor(w / 2) do
            local c = c_base
            if dx < 0 then c = c_shadow end
            if dx > 0 then c = c_highlight end
            if dy == 0 then c = c_highlight end
            dpx(col, row, cx + dx, cy - dy, c)
        end
    end
end

-- Draw a small mushroom
local function draw_mushroom(col, row, cx, cy, cap_c, stem_c)
    -- Stem
    dpx(col, row, cx, cy, stem_c)
    dpx(col, row, cx, cy - 1, stem_c)
    -- Cap
    dpx(col, row, cx - 1, cy - 2, cap_c)
    dpx(col, row, cx, cy - 2, brighten(cap_c, 1.2))
    dpx(col, row, cx + 1, cy - 2, cap_c)
    dpx(col, row, cx, cy - 3, brighten(cap_c, 0.9))
end

-- Draw vine tendril segment
local function draw_tendril(col, row, sx, sy, length, dir_seed, c1, c2)
    local x, y = sx, sy
    for i = 0, length - 1 do
        local t = i / math.max(1, length - 1)
        dpx(col, row, math.floor(x), math.floor(y), lerp(c1, c2, t))
        local angle = hash(math.floor(x), math.floor(y), dir_seed) * 3.14 * 2
        x = x + math.cos(angle) * 1.5
        y = y + math.sin(angle) * 0.8
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- ROW 0: GRASS BASE + FOREGROUND VARIANTS
-- ════════════════════════════════════════════════════════════════════════

-- Col 0: Base grass
fill_diamond(0, 0, pal.grass.base, pal.grass.shadow, pal.grass.highlight, 42)

-- Cols 1-6: Grass with details
for c = 1, 6 do
    fill_diamond(c, 0, pal.grass.base, pal.grass.shadow, pal.grass.highlight, 42 + c * 7)

    local seed = c * 31
    -- Add grass tufts
    local tuft_count = 2 + math.floor(hash(c, 0, 100) * 4)
    for i = 0, tuft_count - 1 do
        local tx = 12 + math.floor(hash(c + i, 0, 101) * 40)
        local ty = 6 + math.floor(hash(c, i, 102) * 20)
        draw_tuft(c, 0, tx, ty, pal.grass.tuft, pal.grass.tuft_dark, math.floor(hash(i, c, 103) * 2))
    end

    -- Col-specific details
    if c == 2 or c == 5 then
        -- Small stones
        local sx = 20 + math.floor(hash(c, 0, 200) * 20)
        local sy = 10 + math.floor(hash(c, 0, 201) * 12)
        dpx(c, 0, sx, sy, pal.grass.stone)
        dpx(c, 0, sx + 1, sy, brighten(pal.grass.stone, 1.1))
    end

    if c == 3 or c == 6 then
        -- Dirt patch
        local dx = 22 + math.floor(hash(c, 0, 300) * 16)
        local dy = 10 + math.floor(hash(c, 0, 301) * 10)
        for ddy = -1, 1 do
            for ddx = -2, 2 do
                if math.abs(ddx) + math.abs(ddy) < 3 then
                    dpx_blend(c, 0, dx + ddx, dy + ddy, pal.grass.dirt, 160)
                end
            end
        end
    end

    if c == 4 then
        -- Tiny flower
        local fx = 28 + math.floor(hash(c, 0, 400) * 10)
        local fy = 12
        dpx(c, 0, fx, fy, pal.grass.flower_r)
        dpx(c, 0, fx, fy + 1, pal.grass.tuft_dark)
    end
end

-- Col 7: Grass misc 0
fill_diamond(7, 0, pal.grass.base, pal.grass.shadow, pal.grass.highlight, 91)
-- Slightly different color shift
for py = 0, CELL_H - 1 do
    for px = 0, CELL_W - 1 do
        local inside = in_diamond(px, py)
        if inside and hash(px, py, 777) < 0.06 then
            dpx_blend(7, 0, px, py, pal.grass.dirt, 80)
        end
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- ROW 1: MORE GRASS MISC + PYROMITE BASE + FG
-- ════════════════════════════════════════════════════════════════════════

-- Cols 0-4: Grass misc variants
for c = 0, 4 do
    fill_diamond(c, 1, pal.grass.base, pal.grass.shadow, pal.grass.highlight, 120 + c * 13)

    local seed = c * 47 + 1000
    if c == 0 then
        -- Slight color shift (yellower)
        for py = 0, CELL_H - 1 do
            for px = 0, CELL_W - 1 do
                if in_diamond(px, py) and hash(px, py, seed) < 0.15 then
                    dpx_blend(c, 1, px, py, pal.grass.light, 60)
                end
            end
        end
    elseif c == 1 then
        -- Tiny flowers scattered
        for i = 0, 3 do
            local fx = 12 + math.floor(hash(i, 1, seed) * 38)
            local fy = 5 + math.floor(hash(1, i, seed + 1) * 20)
            local fc = (i % 2 == 0) and pal.grass.flower_y or pal.grass.flower_w
            dpx(c, 1, fx, fy, fc)
        end
    elseif c == 2 then
        -- Bare/dry patches
        for py = 0, CELL_H - 1 do
            for px = 0, CELL_W - 1 do
                if in_diamond(px, py) and hash(px, py, seed) < 0.12 then
                    dpx_blend(c, 1, px, py, pal.grass.dirt_dark, 100)
                end
            end
        end
    elseif c == 3 then
        -- More tufts, denser
        for i = 0, 6 do
            local tx = 8 + math.floor(hash(i, 3, seed) * 48)
            local ty = 4 + math.floor(hash(3, i, seed + 1) * 24)
            draw_tuft(c, 1, tx, ty, pal.grass.tuft, pal.grass.tuft_dark, 1)
        end
    elseif c == 4 then
        -- Scattered stones
        for i = 0, 2 do
            local sx = 15 + math.floor(hash(i, 4, seed) * 30)
            local sy = 8 + math.floor(hash(4, i, seed + 1) * 16)
            dpx(c, 1, sx, sy, pal.grass.stone)
            dpx(c, 1, sx + 1, sy, brighten(pal.grass.stone, 0.9))
        end
    end
end

-- Col 5: Pyromite deposit base
fill_diamond(5, 1, pal.pyromite.base, pal.pyromite.dark, brighten(pal.pyromite.base, 1.2), 200)
-- Faint ember glow cracks
for py = 0, CELL_H - 1 do
    for px = 0, CELL_W - 1 do
        if in_diamond(px, py) then
            local n = fbm(px + 5 * CELL_W, py + 1 * CELL_H, 2, 210)
            if n > 0.65 and n < 0.72 then
                dpx_blend(5, 1, px, py, pal.pyromite.glow, 100)
            end
        end
    end
end

-- Cols 6-7: Pyromite foreground variants
for c = 6, 7 do
    fill_diamond(c, 1, pal.pyromite.base, pal.pyromite.dark, brighten(pal.pyromite.base, 1.2), 200 + (c - 5) * 11)
    -- Glowing cracks
    for py = 0, CELL_H - 1 do
        for px = 0, CELL_W - 1 do
            if in_diamond(px, py) then
                local n = fbm(px + c * CELL_W, py + 1 * CELL_H, 2, 220 + c)
                if n > 0.62 and n < 0.70 then
                    dpx_blend(c, 1, px, py, pal.pyromite.glow, 140)
                end
            end
        end
    end
    -- Small crystals poking up
    local count = (c == 6) and 2 or 3
    for i = 0, count - 1 do
        local cx = 16 + math.floor(hash(c + i, 1, 230) * 30)
        local cy = 10 + math.floor(hash(c, i + 1, 231) * 14)
        local ch = 2 + math.floor(hash(i, c, 232) * 3)
        draw_crystal(c, 1, cx, cy, ch, pal.pyromite.crystal, pal.pyromite.glow, pal.pyromite.dark)
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- ROW 2: PYROMITE FG/MISC + CRYSTALLINE BASE + FG
-- ════════════════════════════════════════════════════════════════════════

-- Col 0: Pyromite fg variant
fill_diamond(0, 2, pal.pyromite.base, pal.pyromite.dark, brighten(pal.pyromite.base, 1.2), 250)
for i = 0, 1 do
    local cx = 20 + i * 18
    local cy = 14 + math.floor(hash(i, 2, 251) * 8)
    draw_crystal(0, 2, cx, cy, 3, pal.pyromite.crystal, pal.pyromite.ember, pal.pyromite.dark)
end
-- Ember glow spots
draw_dots(0, 2, 30, 12, pal.pyromite.glow, 4, 8, 255)

-- Cols 1-3: Pyromite misc
for c = 1, 3 do
    fill_diamond(c, 2, pal.pyromite.base, pal.pyromite.dark, brighten(pal.pyromite.base, 1.1), 260 + c * 7)

    if c == 1 then
        -- Ember particles
        for i = 0, 5 do
            local ex = 10 + math.floor(hash(i, 2, 270) * 44)
            local ey = 4 + math.floor(hash(2, i, 271) * 24)
            dpx(c, 2, ex, ey, with_alpha(pal.pyromite.ember, 180))
        end
    elseif c == 2 then
        -- Heat shimmer dots
        for i = 0, 4 do
            local sx = 12 + math.floor(hash(i, c, 280) * 40)
            local sy = 6 + math.floor(hash(c, i, 281) * 20)
            dpx(c, 2, sx, sy, with_alpha(pal.pyromite.hot, 120))
            dpx(c, 2, sx + 1, sy, with_alpha(pal.pyromite.hot, 80))
        end
    else
        -- Ash patches
        for py = 0, CELL_H - 1 do
            for px = 0, CELL_W - 1 do
                if in_diamond(px, py) and hash(px, py, 290) < 0.08 then
                    dpx_blend(c, 2, px, py, pal.pyromite.ash, 120)
                end
            end
        end
    end
end

-- Col 4: Crystalline deposit base
fill_diamond(4, 2, pal.crystalline.base, pal.crystalline.shadow, pal.crystalline.highlight, 300)
-- Frost patterns
for py = 0, CELL_H - 1 do
    for px = 0, CELL_W - 1 do
        if in_diamond(px, py) then
            local n = fbm(px + 4 * CELL_W, py + 2 * CELL_H, 3, 310)
            if n > 0.6 then
                dpx_blend(4, 2, px, py, pal.crystalline.frost, math.floor((n - 0.6) * 2.5 * 120))
            end
        end
    end
end

-- Cols 5-7: Crystalline foreground
for c = 5, 7 do
    fill_diamond(c, 2, pal.crystalline.base, pal.crystalline.shadow, pal.crystalline.highlight, 300 + (c - 4) * 9)
    -- Frost base pattern
    for py = 0, CELL_H - 1 do
        for px = 0, CELL_W - 1 do
            if in_diamond(px, py) then
                local n = fbm(px + c * CELL_W, py + 2 * CELL_H, 2, 320 + c)
                if n > 0.65 then
                    dpx_blend(c, 2, px, py, pal.crystalline.frost, 80)
                end
            end
        end
    end
    -- Ice shards / crystal clusters
    local count = 1 + (c - 5)
    for i = 0, count do
        local cx = 14 + math.floor(hash(c + i, 2, 330) * 34)
        local cy = 12 + math.floor(hash(c, i + 2, 331) * 12)
        local ch = 3 + math.floor(hash(i, c + 2, 332) * 3)
        draw_crystal(c, 2, cx, cy, ch, pal.crystalline.crystal, pal.crystalline.ice, pal.crystalline.deep)
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- ROW 3: CRYSTALLINE MISC + BIOVINE BASE + FG + MISC
-- ════════════════════════════════════════════════════════════════════════

-- Cols 0-2: Crystalline misc
for c = 0, 2 do
    fill_diamond(c, 3, pal.crystalline.base, pal.crystalline.shadow, pal.crystalline.highlight, 350 + c * 11)

    if c == 0 then
        -- Frost rimes (delicate ice lines)
        for i = 0, 3 do
            local sx = 10 + math.floor(hash(i, 3, 360) * 20)
            local sy = 8 + math.floor(hash(3, i, 361) * 10)
            for j = 0, 4 do
                dpx(c, 3, sx + j * 2, sy + math.floor(hash(j, i, 362) * 3) - 1, with_alpha(pal.crystalline.frost, 160))
            end
        end
    elseif c == 1 then
        -- Scattered crystal chips
        for i = 0, 5 do
            local cx = 8 + math.floor(hash(i, c, 370) * 48)
            local cy = 4 + math.floor(hash(c, i, 371) * 24)
            dpx(c, 3, cx, cy, pal.crystalline.crystal)
            if hash(i, c, 372) > 0.5 then
                dpx(c, 3, cx + 1, cy, pal.crystalline.ice)
            end
        end
    else
        -- Mixed frost + tiny shards
        for i = 0, 2 do
            local cx = 16 + math.floor(hash(i, c, 380) * 28)
            local cy = 10 + math.floor(hash(c, i, 381) * 14)
            draw_crystal(c, 3, cx, cy, 2, pal.crystalline.crystal, pal.crystalline.ice, pal.crystalline.shadow)
        end
    end
end

-- Col 3: Biovine deposit base
fill_diamond(3, 3, pal.biovine.base, pal.biovine.dark, brighten(pal.biovine.base, 1.2), 400)
-- Organic tendrils in ground
for py = 0, CELL_H - 1 do
    for px = 0, CELL_W - 1 do
        if in_diamond(px, py) then
            local n = fbm(px + 3 * CELL_W, py + 3 * CELL_H, 3, 410)
            local n2 = fbm(px + 3 * CELL_W, py + 3 * CELL_H, 2, 415)
            if n > 0.55 and n < 0.62 then
                dpx_blend(3, 3, px, py, pal.biovine.vine, 100)
            end
            if n2 > 0.7 then
                dpx_blend(3, 3, px, py, pal.biovine.glow, 40)
            end
        end
    end
end

-- Cols 4-6: Biovine foreground
for c = 4, 6 do
    fill_diamond(c, 3, pal.biovine.base, pal.biovine.dark, brighten(pal.biovine.base, 1.15), 400 + (c - 3) * 13)
    -- Vine base pattern
    for py = 0, CELL_H - 1 do
        for px = 0, CELL_W - 1 do
            if in_diamond(px, py) then
                local n = fbm(px + c * CELL_W, py + 3 * CELL_H, 2, 420 + c)
                if n > 0.58 and n < 0.65 then
                    dpx_blend(c, 3, px, py, pal.biovine.vine, 80)
                end
            end
        end
    end

    if c == 4 then
        -- Vine tendrils
        for i = 0, 2 do
            local sx = 15 + i * 14
            local sy = 14 + math.floor(hash(i, c, 430) * 8)
            draw_tendril(c, 3, sx, sy, 5, 431 + i, pal.biovine.vine, pal.biovine.purple)
        end
    elseif c == 5 then
        -- Glowing spores
        for i = 0, 4 do
            local sx = 10 + math.floor(hash(i, c, 440) * 44)
            local sy = 4 + math.floor(hash(c, i, 441) * 24)
            dpx(c, 3, sx, sy, pal.biovine.glow)
            dpx_blend(c, 3, sx - 1, sy, pal.biovine.glow, 60)
            dpx_blend(c, 3, sx + 1, sy, pal.biovine.glow, 60)
            dpx_blend(c, 3, sx, sy - 1, pal.biovine.glow, 60)
        end
    else
        -- Mushroom caps
        for i = 0, 1 do
            local mx = 18 + i * 20
            local my = 16 + math.floor(hash(i, c, 450) * 8)
            draw_mushroom(c, 3, mx, my, pal.biovine.mushcap, pal.biovine.mushroom)
        end
        -- Small spore
        dpx(c, 3, 35, 10, pal.biovine.spore)
    end
end

-- Col 7: Biovine misc
fill_diamond(7, 3, pal.biovine.base, pal.biovine.dark, brighten(pal.biovine.base, 1.1), 460)
draw_tendril(7, 3, 20, 16, 6, 461, pal.biovine.vine, pal.biovine.glow)
draw_dots(7, 3, 35, 12, pal.biovine.spore, 3, 6, 465)

-- ════════════════════════════════════════════════════════════════════════
-- ROW 4: BIOVINE MISC + RESERVED
-- ════════════════════════════════════════════════════════════════════════

-- Cols 0-1: More biovine misc
for c = 0, 1 do
    fill_diamond(c, 4, pal.biovine.base, pal.biovine.dark, brighten(pal.biovine.base, 1.1), 470 + c * 9)
    if c == 0 then
        -- Scattered spores and vine bits
        for i = 0, 3 do
            local sx = 10 + math.floor(hash(i, c, 475) * 40)
            local sy = 5 + math.floor(hash(c, i, 476) * 20)
            dpx(c, 4, sx, sy, pal.biovine.spore)
        end
        draw_tendril(c, 4, 30, 18, 4, 477, pal.biovine.vine, pal.biovine.dark)
    else
        -- Purple vine overlay
        for py = 0, CELL_H - 1 do
            for px = 0, CELL_W - 1 do
                if in_diamond(px, py) then
                    local n = fbm(px + c * CELL_W, py + 4 * CELL_H, 2, 480)
                    if n > 0.6 and n < 0.66 then
                        dpx_blend(c, 4, px, py, pal.biovine.purple, 90)
                    end
                end
            end
        end
    end
end

-- Cols 2-7: Reserved (fill with grass)
for c = 2, 7 do
    fill_diamond(c, 4, pal.grass.base, pal.grass.shadow, pal.grass.highlight, 500 + c * 7)
end

-- ════════════════════════════════════════════════════════════════════════
-- ROWS 5-7: RESERVED (grass variants)
-- ════════════════════════════════════════════════════════════════════════

for row = 5, 7 do
    for c = 0, 7 do
        fill_diamond(c, row, pal.grass.base, pal.grass.shadow, pal.grass.highlight, 600 + row * 50 + c * 11)
        -- Add some random subtle details
        if hash(c, row, 610) > 0.5 then
            local tx = 20 + math.floor(hash(c, row, 611) * 24)
            local ty = 10 + math.floor(hash(c, row, 612) * 12)
            draw_tuft(c, row, tx, ty, pal.grass.tuft, pal.grass.tuft_dark, 1)
        end
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- ROW 8: STONE WALLS
-- ════════════════════════════════════════════════════════════════════════

-- Cols 0-3: Stone wall base + variants
for c = 0, 3 do
    fill_diamond(c, 8, pal.wall.base, pal.wall.shadow, pal.wall.highlight, 800 + c * 17)

    -- Rock grain: horizontal-ish cracks
    for i = 0, 2 + c do
        local sx = 8 + math.floor(hash(i, c + 8, 810) * 30)
        local sy = 5 + math.floor(hash(c + 8, i, 811) * 20)
        local len = 3 + math.floor(hash(i, c, 812) * 8)
        for j = 0, len - 1 do
            local dy = math.floor(hash(sx + j, sy, 813) * 3) - 1
            dpx_blend(c, 8, sx + j, sy + dy, pal.wall.crack, 160)
        end
    end

    if c >= 2 then
        -- More pronounced cracks for variants
        for py = 0, CELL_H - 1 do
            for px = 0, CELL_W - 1 do
                if in_diamond(px, py) then
                    local n = fbm(px + c * CELL_W, py + 8 * CELL_H, 3, 820 + c)
                    if n > 0.58 and n < 0.62 then
                        dpx_blend(c, 8, px, py, pal.wall.dark, 140)
                    end
                end
            end
        end
    end
end

-- Cols 4-6: Wall misc
for c = 4, 6 do
    fill_diamond(c, 8, pal.wall.base, pal.wall.shadow, pal.wall.highlight, 840 + c * 13)

    if c == 4 then
        -- Mossy wall
        for py = 0, CELL_H - 1 do
            for px = 0, CELL_W - 1 do
                if in_diamond(px, py) then
                    local n = fbm(px + c * CELL_W, py + 8 * CELL_H, 2, 850)
                    if n > 0.5 and py > CELL_H / 2 then
                        dpx_blend(c, 8, px, py, pal.wall.moss, math.floor((n - 0.5) * 2 * 160))
                    end
                end
            end
        end
    elseif c == 5 then
        -- Darker stone
        for py = 0, CELL_H - 1 do
            for px = 0, CELL_W - 1 do
                if in_diamond(px, py) then
                    dpx_blend(c, 8, px, py, pal.wall.dark, 60)
                end
            end
        end
        -- A few cracks
        for i = 0, 2 do
            local sx = 12 + i * 14
            local sy = 8 + math.floor(hash(i, 5, 860) * 14)
            for j = 0, 4 do
                dpx(c, 8, sx + j, sy + math.floor(hash(j, i, 861) * 3) - 1, pal.wall.crack)
            end
        end
    else
        -- Crumbled edges
        local depth_thresh = 0.15
        for py = 0, CELL_H - 1 do
            for px = 0, CELL_W - 1 do
                local d = diamond_depth(px, py)
                if d >= 0 and d < depth_thresh then
                    local n = hash(px, py, 870)
                    if n < 0.3 then
                        dpx(c, 8, px, py, TRANSPARENT)
                    elseif n < 0.5 then
                        dpx_blend(c, 8, px, py, pal.wall.dark, 120)
                    end
                end
            end
        end
    end
end

-- Col 7 row 8: empty/transparent
-- (left transparent)

-- ════════════════════════════════════════════════════════════════════════
-- ROW 9: MORE STONE VARIANTS
-- ════════════════════════════════════════════════════════════════════════

for c = 0, 3 do
    local shade = (c < 2) and 0.85 or 1.15
    fill_diamond(c, 9,
        brighten(pal.wall.base, shade),
        brighten(pal.wall.shadow, shade),
        brighten(pal.wall.highlight, shade),
        900 + c * 19)
    -- Subtle grain
    for i = 0, 2 do
        local sx = 10 + math.floor(hash(i, c + 9, 910) * 35)
        local sy = 6 + math.floor(hash(c + 9, i, 911) * 18)
        dpx(c, 9, sx, sy, pal.wall.crack)
        dpx(c, 9, sx + 1, sy, pal.wall.crack)
    end
end

-- Cols 4-7 row 9: transparent/reserved

-- ════════════════════════════════════════════════════════════════════════
-- ROW 10: VOLTITE (electric yellow-blue)
-- ════════════════════════════════════════════════════════════════════════

for c = 0, 3 do
    fill_diamond(c, 10, pal.voltite.base, pal.voltite.dark, brighten(pal.voltite.base, 1.3), 1000 + c * 23)

    if c == 0 then
        -- Base deposit
        for py = 0, CELL_H - 1 do
            for px = 0, CELL_W - 1 do
                if in_diamond(px, py) then
                    local n = fbm(px, py + 10 * CELL_H, 2, 1010)
                    if n > 0.6 then
                        dpx_blend(c, 10, px, py, pal.voltite.blue, 60)
                    end
                end
            end
        end
    else
        -- Electric arcs
        local arc_count = c
        for i = 0, arc_count - 1 do
            local sx = 10 + math.floor(hash(i, c, 1020) * 40)
            local sy = 6 + math.floor(hash(c, i, 1021) * 18)
            -- Jagged line
            local x, y = sx, sy
            for j = 0, 4 do
                dpx(c, 10, math.floor(x), math.floor(y), pal.voltite.yellow)
                x = x + 2 + hash(j, i, 1022) * 3
                y = y + (hash(j + 1, i, 1023) - 0.5) * 4
            end
        end
        -- Glow spots
        for i = 0, 2 do
            local gx = 14 + math.floor(hash(i, c + 10, 1030) * 32)
            local gy = 8 + math.floor(hash(c + 10, i, 1031) * 16)
            dpx(c, 10, gx, gy, pal.voltite.arc)
        end
    end
end

-- Cols 4-7: more voltite variants
for c = 4, 7 do
    fill_diamond(c, 10, pal.voltite.base, pal.voltite.dark, brighten(pal.voltite.base, 1.2), 1040 + c * 11)
    -- Scattered electric dots
    for i = 0, 3 do
        local ex = 10 + math.floor(hash(i, c, 1050) * 44)
        local ey = 4 + math.floor(hash(c, i, 1051) * 24)
        dpx(c, 10, ex, ey, pal.voltite.yellow)
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- ROW 11: UMBRITE (dark purple shadow)
-- ════════════════════════════════════════════════════════════════════════

for c = 0, 3 do
    fill_diamond(c, 11, pal.umbrite.base, pal.umbrite.dark, brighten(pal.umbrite.base, 1.2), 1100 + c * 19)

    if c == 0 then
        -- Base with subtle swirls
        for py = 0, CELL_H - 1 do
            for px = 0, CELL_W - 1 do
                if in_diamond(px, py) then
                    local n = fbm(px + 11 * CELL_W, py + 11 * CELL_H, 3, 1110)
                    if n > 0.55 then
                        dpx_blend(c, 11, px, py, pal.umbrite.purple, math.floor((n - 0.55) * 4 * 80))
                    end
                end
            end
        end
    else
        -- Wisps
        for i = 0, c do
            local wx = 12 + math.floor(hash(i, c, 1120) * 36)
            local wy = 6 + math.floor(hash(c, i, 1121) * 18)
            dpx(c, 11, wx, wy, pal.umbrite.wisp)
            dpx_blend(c, 11, wx - 1, wy, pal.umbrite.glow, 60)
            dpx_blend(c, 11, wx + 1, wy, pal.umbrite.glow, 60)
            dpx_blend(c, 11, wx, wy - 1, pal.umbrite.glow, 40)
        end
    end
end

-- Cols 4-7: more umbrite
for c = 4, 7 do
    fill_diamond(c, 11, pal.umbrite.base, pal.umbrite.dark, brighten(pal.umbrite.base, 1.15), 1140 + c * 13)
    -- Shadow wisps
    for i = 0, 2 do
        local wx = 14 + math.floor(hash(i, c, 1150) * 30)
        local wy = 8 + math.floor(hash(c, i, 1151) * 14)
        dpx(c, 11, wx, wy, pal.umbrite.glow)
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- ROW 12: RESONITE (sonic teal)
-- ════════════════════════════════════════════════════════════════════════

for c = 0, 3 do
    fill_diamond(c, 12, pal.resonite.base, pal.resonite.dark, brighten(pal.resonite.base, 1.2), 1200 + c * 17)

    if c == 0 then
        -- Base with concentric ring hints
        for py = 0, CELL_H - 1 do
            for px = 0, CELL_W - 1 do
                if in_diamond(px, py) then
                    local dx = (px - 31.5) / 32
                    local dy = (py - 15.5) / 16
                    local dist = math.sqrt(dx * dx + dy * dy)
                    local ring = math.sin(dist * 20) * 0.5 + 0.5
                    if ring > 0.8 then
                        dpx_blend(c, 12, px, py, pal.resonite.teal, 50)
                    end
                end
            end
        end
    else
        -- Geometric patterns
        for i = 0, c do
            local gx = 14 + math.floor(hash(i, c, 1220) * 32)
            local gy = 8 + math.floor(hash(c, i, 1221) * 14)
            -- Small diamond/square
            dpx(c, 12, gx, gy - 1, pal.resonite.bright)
            dpx(c, 12, gx - 1, gy, pal.resonite.teal)
            dpx(c, 12, gx + 1, gy, pal.resonite.teal)
            dpx(c, 12, gx, gy + 1, pal.resonite.bright)
            dpx(c, 12, gx, gy, pal.resonite.white)
        end
    end
end

for c = 4, 7 do
    fill_diamond(c, 12, pal.resonite.base, pal.resonite.dark, brighten(pal.resonite.base, 1.15), 1240 + c * 11)
    for i = 0, 2 do
        local gx = 16 + math.floor(hash(i, c, 1250) * 28)
        local gy = 10 + math.floor(hash(c, i, 1251) * 12)
        dpx(c, 12, gx, gy, pal.resonite.bright)
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- ROW 13: ASH TERRAIN
-- ════════════════════════════════════════════════════════════════════════

for c = 0, 7 do
    fill_diamond(c, 13, pal.ash.base, pal.ash.dark, pal.ash.light, 1300 + c * 23)

    -- Cracks
    if c < 4 then
        for i = 0, 1 + c do
            local sx = 10 + math.floor(hash(i, c + 13, 1310) * 30)
            local sy = 6 + math.floor(hash(c + 13, i, 1311) * 18)
            local len = 4 + math.floor(hash(i, c, 1312) * 6)
            for j = 0, len - 1 do
                local dy = math.floor(hash(sx + j, sy, 1313) * 3) - 1
                dpx_blend(c, 13, sx + j, sy + dy, pal.ash.crack, 180)
            end
        end
    end

    -- Ember specks on some tiles
    if c >= 3 and c <= 6 then
        for i = 0, 2 do
            local ex = 12 + math.floor(hash(i, c, 1320) * 40)
            local ey = 5 + math.floor(hash(c, i, 1321) * 22)
            dpx(c, 13, ex, ey, with_alpha(pal.ash.ember, 140))
        end
    end

    -- Scorched patches
    if c >= 5 then
        for py = 0, CELL_H - 1 do
            for px = 0, CELL_W - 1 do
                if in_diamond(px, py) and hash(px, py, 1330 + c) < 0.06 then
                    dpx_blend(c, 13, px, py, pal.ash.crack, 100)
                end
            end
        end
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- ROW 14: ASH VARIANTS
-- ════════════════════════════════════════════════════════════════════════

for c = 0, 7 do
    -- Slightly different base shade per variant
    local shade = 0.9 + hash(c, 14, 1400) * 0.2
    fill_diamond(c, 14,
        brighten(pal.ash.base, shade),
        brighten(pal.ash.dark, shade),
        brighten(pal.ash.light, shade),
        1400 + c * 31)

    -- Various details
    if c % 3 == 0 then
        -- Deep cracks
        for i = 0, 2 do
            local sx = 14 + math.floor(hash(i, c + 14, 1410) * 28)
            local sy = 8 + math.floor(hash(c + 14, i, 1411) * 14)
            for j = 0, 5 do
                dpx_blend(c, 14, sx + j, sy + math.floor(hash(j, i, 1412) * 3) - 1, pal.ash.crack, 200)
            end
        end
    elseif c % 3 == 1 then
        -- Scattered ember dots
        for i = 0, 4 do
            local ex = 8 + math.floor(hash(i, c, 1420) * 48)
            local ey = 3 + math.floor(hash(c, i, 1421) * 26)
            dpx(c, 14, ex, ey, with_alpha(pal.ash.ember, 120))
        end
    else
        -- Lighter ash dust
        for py = 0, CELL_H - 1 do
            for px = 0, CELL_W - 1 do
                if in_diamond(px, py) and hash(px, py, 1430 + c) < 0.1 then
                    dpx_blend(c, 14, px, py, pal.ash.light, 80)
                end
            end
        end
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- FINALIZE: Apply image to sprite and export
-- ════════════════════════════════════════════════════════════════════════

-- Place image onto sprite cel
local cel = spr.cels[1]
cel.image = img

-- Save as PNG directly
local out_dir = "/Users/gorishniymax/Repos/factor/resources/sprites/terrain"
spr:saveCopyAs(out_dir .. "/terrain_atlas.png")
spr:saveAs(out_dir .. "/terrain_atlas.aseprite")
spr:close()

print("Terrain atlas exported to: " .. out_dir .. "/terrain_atlas.png")
print("Size: " .. W .. "x" .. H .. " (" .. COLS .. " cols x " .. ROWS .. " rows, " .. CELL_W .. "x" .. CELL_H .. " cells)")
