-- Isometric terrain atlas generator for Night Shift (v2 - with elevation/depth)
-- Generates an 8x15 grid of 64x32 isometric diamond tiles (512x480 total)
-- Run: aseprite -b --script generate_terrain.lua
--
-- Atlas layout matches terrain_visual_manager.gd ATLAS indices exactly.
-- Each flat index = row * 8 + col.

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
    return app.pixelColor.rgba(
        math.max(0, math.min(255, math.floor(r + 0.5))),
        math.max(0, math.min(255, math.floor(g + 0.5))),
        math.max(0, math.min(255, math.floor(b + 0.5))),
        math.max(0, math.min(255, math.floor((a or 255) + 0.5)))
    )
end

local TRANSPARENT = app.pixelColor.rgba(0, 0, 0, 0)

local function hex(s)
    s = s:gsub("^#", "")
    return rgba(tonumber(s:sub(1,2), 16), tonumber(s:sub(3,4), 16), tonumber(s:sub(5,6), 16))
end

local function decompose(c)
    return app.pixelColor.rgbaR(c), app.pixelColor.rgbaG(c), app.pixelColor.rgbaB(c), app.pixelColor.rgbaA(c)
end

local function lerp_color(c1, c2, t)
    t = math.max(0, math.min(1, t))
    local r1, g1, b1, a1 = decompose(c1)
    local r2, g2, b2, a2 = decompose(c2)
    return rgba(
        r1 + (r2 - r1) * t,
        g1 + (g2 - g1) * t,
        b1 + (b2 - b1) * t,
        a1 + (a2 - a1) * t
    )
end

local function brighten(c, factor)
    local r, g, b, a = decompose(c)
    return rgba(r * factor, g * factor, b * factor, a)
end

local function with_alpha(c, alpha)
    local r, g, b = decompose(c)
    return rgba(r, g, b, alpha)
end

-- ── Isometric diamond helpers ───────────────────────────────────────────

local function in_diamond(px, py)
    local cx = 31.5
    local cy = 15.5
    local dx = math.abs(px - cx) / 32.0
    local dy = math.abs(py - cy) / 16.0
    return (dx + dy) <= 1.0
end

local function diamond_depth(px, py)
    local cx = 31.5
    local cy = 15.5
    local dx = math.abs(px - cx) / 32.0
    local dy = math.abs(py - cy) / 16.0
    local d = dx + dy
    if d > 1.0 then return -1 end
    return 1.0 - d
end

-- Which quadrant of the diamond: "tl", "tr", "bl", "br"
local function diamond_quadrant(px, py)
    local cx = 31.5
    local cy = 15.5
    if py < cy then
        return px < cx and "tl" or "tr"
    else
        return px < cx and "bl" or "br"
    end
end

-- ── Core tile rendering with front-face depth ───────────────────────────

local function render_diamond(col, row, base, dark, light, seed, opts)
    opts = opts or {}
    local ox = col * CELL_W
    local oy = row * CELL_H
    local edge_band = opts.edge_thickness or 0.12
    local edge_darken = opts.edge_darken or 0.60

    for py = 0, CELL_H - 1 do
        for px = 0, CELL_W - 1 do
            if not in_diamond(px, py) then goto continue end

            local depth = diamond_depth(px, py)
            local quad = diamond_quadrant(px, py)

            -- Base noise color
            local n = fbm(px + ox, py + oy, 3, seed)
            local c
            if n < 0.4 then
                c = lerp_color(dark, base, n / 0.4)
            else
                c = lerp_color(base, light, (n - 0.4) / 0.6)
            end

            -- Top-face lighting: upper-left is bright, lower-right is darker
            local cx_n = (px - 31.5) / 32.0
            local cy_n = (py - 15.5) / 16.0
            local light_val = 1.0 + (-cy_n * 0.5 - cx_n * 0.25) * 0.14

            -- Front-face depth band on bottom two edges
            if (quad == "bl" or quad == "br") and depth < edge_band then
                local t = depth / edge_band  -- 0 at edge, 1 at interior
                local front = edge_darken + (1.0 - edge_darken) * t
                -- Bottom-right is darkest (away from upper-left light)
                if quad == "br" then front = front * 0.88 end
                c = brighten(c, front * light_val)
            else
                c = brighten(c, light_val)
            end

            -- Thin dark outline at the very edge
            if depth < 0.04 then
                c = brighten(c, 0.50 + 0.50 * (depth / 0.04))
            end

            img:drawPixel(ox + px, oy + py, c)
            ::continue::
        end
    end
end

-- ── Drawing primitives ──────────────────────────────────────────────────

local function dpx(col, row, px, py, c)
    if px < 0 or px >= CELL_W or py < 0 or py >= CELL_H then return end
    if not in_diamond(px, py) then return end
    img:drawPixel(col * CELL_W + px, row * CELL_H + py, c)
end

local function dpx_free(col, row, px, py, c)
    if px < 0 or px >= CELL_W or py < 0 or py >= CELL_H then return end
    img:drawPixel(col * CELL_W + px, row * CELL_H + py, c)
end

local function dpx_blend(col, row, px, py, c, alpha)
    if px < 0 or px >= CELL_W or py < 0 or py >= CELL_H then return end
    if not in_diamond(px, py) then return end
    local ox = col * CELL_W
    local oy = row * CELL_H
    local existing = img:getPixel(ox + px, oy + py)
    local blended = lerp_color(existing, c, alpha / 255.0)
    img:drawPixel(ox + px, oy + py, blended)
end

-- ── Detail drawing functions ────────────────────────────────────────────

local function draw_grass_tuft(col, row, cx, cy, c_base, c_tip, size, seed)
    size = size or 2
    local blades = 1 + math.floor(hash(cx, cy, seed) * size)
    for b = 0, blades - 1 do
        local bx = cx + b - math.floor(blades / 2)
        local height = 1 + math.floor(hash(bx, cy, seed + 10) * 2)
        for h = 0, height do
            local t = h / math.max(1, height)
            local c = lerp_color(c_base, c_tip, t)
            if b == 0 then c = brighten(c, 1.15) end
            dpx(col, row, bx, cy - h, c)
        end
    end
end

local function draw_pebble(col, row, cx, cy, c_light, c_dark)
    dpx(col, row, cx, cy, c_dark)
    dpx(col, row, cx + 1, cy, c_light)
    if hash(cx, cy, 999) > 0.5 then
        dpx(col, row, cx, cy - 1, brighten(c_light, 1.1))
    end
end

local function draw_crack(col, row, sx, sy, length, c, seed)
    local x, y = sx, sy
    for i = 0, length - 1 do
        dpx(col, row, math.floor(x), math.floor(y), c)
        x = x + 1.0 + (hash(math.floor(x), math.floor(y), seed) - 0.3) * 0.5
        y = y + (hash(math.floor(x) + 1, math.floor(y), seed + 1) - 0.5) * 1.5
    end
end

-- Crystal shard with lit left, dark right, bright tip
local function draw_crystal_shard(col, row, cx, cy, height, width, c_body, c_light, c_dark, c_tip)
    for dy = 0, height - 1 do
        local t = dy / math.max(1, height - 1)
        local w = math.max(1, math.floor(width * (1.0 - t * 0.7) + 0.5))
        local half = math.floor(w / 2)
        for dx = -half, half do
            local c
            if dy == height - 1 then c = c_tip
            elseif dx < 0 then c = c_light
            elseif dx > 0 then c = c_dark
            else c = c_body end
            c = brighten(c, 1.0 - t * 0.12)
            dpx(col, row, cx + dx, cy - dy, c)
        end
    end
end

-- Hexagonal prism for crystalline ore
local function draw_hex_prism(col, row, cx, cy, height, width, c_face_l, c_face_r, c_top)
    for dy = 0, height - 1 do
        local half = math.floor(width / 2)
        for dx = -half, half do
            local c = dx <= 0 and c_face_l or c_face_r
            dpx(col, row, cx + dx, cy - dy, c)
        end
    end
    local half = math.floor(width / 2)
    for dx = -half, half do
        dpx(col, row, cx + dx, cy - height, c_top)
        if width > 2 then
            dpx(col, row, cx + dx, cy - height - 1, brighten(c_top, 1.1))
        end
    end
end

-- Organic vine/tendril
local function draw_vine(col, row, sx, sy, length, c_base, c_tip, seed)
    local x, y = sx, sy
    for i = 0, length - 1 do
        local t = i / math.max(1, length - 1)
        dpx(col, row, math.floor(x), math.floor(y), lerp_color(c_base, c_tip, t))
        local angle = hash(math.floor(x), math.floor(y), seed) * 3.14159 * 2
        x = x + math.cos(angle) * 1.2
        y = y - 0.8 + math.sin(angle) * 0.4
    end
end

-- Mushroom
local function draw_mushroom(col, row, cx, cy, cap_c, stem_c, cap_w)
    cap_w = cap_w or 3
    dpx(col, row, cx, cy, stem_c)
    dpx(col, row, cx, cy - 1, stem_c)
    local half = math.floor(cap_w / 2)
    for dx = -half, half do
        local c = cap_c
        if dx == -half then c = brighten(cap_c, 1.2)
        elseif dx == half then c = brighten(cap_c, 0.8) end
        dpx(col, row, cx + dx, cy - 2, c)
    end
    for dx = -half + 1, half - 1 do
        dpx(col, row, cx + dx, cy - 3, brighten(cap_c, 1.15))
    end
end

-- Rock formation for walls/ores
local function draw_rock(col, row, cx, cy, w, h, c_top, c_front, c_dark)
    for dy = 0, h - 1 do
        for dx = 0, w - 1 do
            local c = c_front
            if dx == w - 1 then c = c_dark end
            if dx == 0 then c = brighten(c_front, 1.1) end
            dpx(col, row, cx + dx, cy - dy, c)
        end
    end
    for dx = 0, w - 1 do
        dpx(col, row, cx + dx, cy - h, c_top)
    end
end

-- ── Palettes ────────────────────────────────────────────────────────────

local pal = {
    grass = {
        base = hex("#475C3B"),
        highlight = hex("#607A50"),
        shadow = hex("#3B4D31"),
        dark = hex("#344828"),
        light = hex("#6B8558"),
        tuft = hex("#5A7848"),
        tuft_tip = hex("#78A060"),
        tuft_dark = hex("#3E5432"),
        dirt = hex("#6B5D4A"),
        dirt_dark = hex("#574B3C"),
        stone = hex("#7A7A72"),
        stone_dark = hex("#5A5A55"),
        crack = hex("#2E3B24"),
        flower_r = hex("#B84848"),
        flower_y = hex("#C8B848"),
        flower_w = hex("#D0D0C8"),
    },
    iron = {
        base = hex("#6B5A4A"),
        highlight = hex("#8A7A68"),
        shadow = hex("#4A3D32"),
        dark = hex("#3A2E25"),
        ore = hex("#8B6B50"),
        ore_light = hex("#A08060"),
        ore_dark = hex("#5C4435"),
        rust = hex("#7A4A30"),
    },
    copper = {
        base = hex("#5A5040"),
        highlight = hex("#7A6E58"),
        shadow = hex("#3E382E"),
        dark = hex("#2E2A22"),
        ore = hex("#B87040"),
        ore_light = hex("#D08850"),
        ore_dark = hex("#8A5030"),
        green = hex("#508860"),
    },
    coal = {
        base = hex("#3A3A38"),
        highlight = hex("#505050"),
        shadow = hex("#282828"),
        dark = hex("#1A1A1A"),
        seam = hex("#222222"),
        shiny = hex("#606060"),
        dust = hex("#484848"),
    },
    tin = {
        base = hex("#687070"),
        highlight = hex("#8A9494"),
        shadow = hex("#4A5252"),
        dark = hex("#3A4242"),
        ore = hex("#90A0A0"),
        ore_light = hex("#B0C0C0"),
        ore_dark = hex("#607070"),
    },
    gold = {
        base = hex("#6B5830"),
        highlight = hex("#8A7840"),
        shadow = hex("#4A3C20"),
        dark = hex("#3A2E18"),
        ore = hex("#D4A830"),
        ore_light = hex("#E8C848"),
        ore_dark = hex("#A08020"),
        sparkle = hex("#FFF080"),
    },
    quartz = {
        base = hex("#5B7B8F"),
        highlight = hex("#8FB4C9"),
        shadow = hex("#3F5766"),
        dark = hex("#2E4555"),
        crystal = hex("#A8D4E8"),
        ice = hex("#C8E8F4"),
        deep = hex("#2E4555"),
        frost = hex("#D0E8F0"),
    },
    sulfur = {
        base = hex("#7A7030"),
        highlight = hex("#A09840"),
        shadow = hex("#585020"),
        dark = hex("#404018"),
        bright = hex("#C8B840"),
        fume = hex("#A0A040"),
        crust = hex("#908028"),
    },
    wall = {
        base = hex("#6B6B6B"),
        highlight = hex("#909090"),
        shadow = hex("#4A4A4A"),
        dark = hex("#383838"),
        light = hex("#A0A0A0"),
        crack = hex("#3A3A3A"),
        moss = hex("#506040"),
        mortar = hex("#585858"),
    },
    stone = {
        base = hex("#7A7A72"),
        highlight = hex("#989890"),
        shadow = hex("#5A5A54"),
        dark = hex("#484844"),
        mortar = hex("#606058"),
        crack = hex("#404040"),
    },
    oil = {
        base = hex("#2A2830"),
        highlight = hex("#404048"),
        shadow = hex("#1A1820"),
        dark = hex("#101018"),
        sheen = hex("#506080"),
        rainbow = hex("#607890"),
        bubble = hex("#384050"),
    },
    crystal = {
        base = hex("#8B3A2A"),
        highlight = hex("#A84A35"),
        shadow = hex("#5C2218"),
        dark = hex("#3A1510"),
        shard = hex("#C44B32"),
        glow = hex("#FF6B3D"),
        ember = hex("#FF9944"),
        hot = hex("#FFB060"),
        ash_col = hex("#4A3A35"),
    },
    uranium = {
        base = hex("#3A5030"),
        highlight = hex("#507040"),
        shadow = hex("#283820"),
        dark = hex("#1A2818"),
        glow = hex("#80E040"),
        rod = hex("#60A830"),
        bright = hex("#A0FF60"),
    },
    biomass = {
        base = hex("#4B5C3D"),
        highlight = hex("#607848"),
        shadow = hex("#344830"),
        dark = hex("#2E3A28"),
        vine = hex("#7B4E8A"),
        glow = hex("#5ADB50"),
        spore = hex("#8AEB80"),
        purple = hex("#9B68AA"),
        mushroom = hex("#B87848"),
        mushcap = hex("#C89868"),
    },
    ash = {
        base = hex("#7A6E63"),
        highlight = hex("#908475"),
        shadow = hex("#5C5248"),
        dark = hex("#4A4038"),
        crack = hex("#3A3028"),
        ember = hex("#8B4030"),
        light = hex("#8F8275"),
    },
}

-- ── Create sprite ───────────────────────────────────────────────────────

local spr = Sprite(W, H, ColorMode.RGB)
img = Image(W, H, ColorMode.RGB)

for y = 0, H - 1 do
    for x = 0, W - 1 do
        img:drawPixel(x, y, TRANSPARENT)
    end
end

-- Helper: flat atlas index -> (col, row)
local function idx_to_cr(idx)
    return idx % COLS, math.floor(idx / COLS)
end

-- ════════════════════════════════════════════════════════════════════════
-- GRASS: bg=0, fg=[1..6], misc=[7..12]
-- ════════════════════════════════════════════════════════════════════════

local function grass_texture(col, row, seed)
    local ox = col * CELL_W
    local oy = row * CELL_H
    for py = 0, CELL_H - 1 do
        for px = 0, CELL_W - 1 do
            if not in_diamond(px, py) then goto cont end
            local n2 = fbm(px + ox + 500, py + oy + 500, 2, seed + 777)
            if n2 > 0.6 then
                dpx_blend(col, row, px, py, pal.grass.light, math.floor((n2 - 0.6) * 2.5 * 40))
            elseif n2 < 0.3 then
                dpx_blend(col, row, px, py, pal.grass.dark, math.floor((0.3 - n2) * 3 * 30))
            end
            if hash(px + ox, py + oy, seed + 333) < 0.03 then
                dpx_blend(col, row, px, py, pal.grass.dirt, 50)
            end
            ::cont::
        end
    end
end

-- bg=0
do
    local c, r = idx_to_cr(0)
    render_diamond(c, r, pal.grass.base, pal.grass.shadow, pal.grass.highlight, 42)
    grass_texture(c, r, 42)
    for i = 0, 2 do
        local tx = 18 + math.floor(hash(i, 0, 50) * 28)
        local ty = 10 + math.floor(hash(0, i, 51) * 12)
        draw_grass_tuft(c, r, tx, ty, pal.grass.tuft_dark, pal.grass.tuft, 1, 52 + i)
    end
end

-- fg=[1..6]
for vi = 0, 5 do
    local idx = 1 + vi
    local c, r = idx_to_cr(idx)
    local seed = 100 + vi * 17
    render_diamond(c, r, pal.grass.base, pal.grass.shadow, pal.grass.highlight, seed)
    grass_texture(c, r, seed)

    local tuft_count = 3 + vi
    for i = 0, tuft_count - 1 do
        local tx = 10 + math.floor(hash(i + vi, 0, seed + 10) * 44)
        local ty = 6 + math.floor(hash(0, i + vi, seed + 11) * 20)
        draw_grass_tuft(c, r, tx, ty, pal.grass.tuft_dark, pal.grass.tuft_tip, 2, seed + 12 + i)
    end

    if vi == 0 then
        for i = 0, 1 do
            draw_pebble(c, r, 22 + i * 14, 12 + math.floor(hash(i, 1, seed + 20) * 8), pal.grass.stone, pal.grass.stone_dark)
        end
    elseif vi == 1 then
        local dx = 24 + math.floor(hash(vi, 0, seed + 30) * 12)
        local dy = 12 + math.floor(hash(0, vi, seed + 31) * 6)
        for ddy = -1, 1 do for ddx = -2, 2 do
            if math.abs(ddx) + math.abs(ddy) < 3 then
                dpx_blend(c, r, dx + ddx, dy + ddy, pal.grass.dirt, 120)
            end
        end end
        draw_crack(c, r, dx - 2, dy, 4, pal.grass.crack, seed + 32)
    elseif vi == 2 then
        for i = 0, 1 do
            local fx = 20 + i * 16
            local fy = 10 + math.floor(hash(i, vi, seed + 40) * 10)
            dpx(c, r, fx, fy, pal.grass.flower_r)
            dpx(c, r, fx, fy + 1, pal.grass.tuft_dark)
        end
    elseif vi == 3 then
        for i = 0, 2 do
            draw_pebble(c, r, 14 + math.floor(hash(i, vi, seed + 50) * 32), 8 + math.floor(hash(vi, i, seed + 51) * 14), pal.grass.stone, pal.grass.stone_dark)
        end
        draw_crack(c, r, 18, 15, 6, pal.grass.crack, seed + 55)
    elseif vi == 4 then
        for i = 0, 2 do
            dpx(c, r, 16 + i * 12, 8 + math.floor(hash(i, vi, seed + 60) * 12), pal.grass.flower_y)
        end
    else
        draw_pebble(c, r, 20, 10, pal.grass.stone, pal.grass.stone_dark)
        draw_crack(c, r, 28, 14, 5, pal.grass.crack, seed + 70)
        dpx_blend(c, r, 36, 18, pal.grass.dirt_dark, 100)
        dpx_blend(c, r, 37, 18, pal.grass.dirt, 80)
    end
end

-- misc=[7..12]
for vi = 0, 5 do
    local idx = 7 + vi
    local c, r = idx_to_cr(idx)
    local seed = 200 + vi * 23
    render_diamond(c, r, pal.grass.base, pal.grass.shadow, pal.grass.highlight, seed)
    grass_texture(c, r, seed)

    if vi == 0 then
        for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
            if in_diamond(px, py) and hash(px, py, seed + 5) < 0.12 then
                dpx_blend(c, r, px, py, pal.grass.light, 50)
            end
        end end
    elseif vi == 1 then
        for i = 0, 3 do
            local fx = 12 + math.floor(hash(i, vi, seed + 10) * 38)
            local fy = 5 + math.floor(hash(vi, i, seed + 11) * 20)
            dpx(c, r, fx, fy, (i % 2 == 0) and pal.grass.flower_y or pal.grass.flower_w)
            dpx(c, r, fx, fy + 1, pal.grass.tuft_dark)
        end
    elseif vi == 2 then
        for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
            if in_diamond(px, py) and hash(px, py, seed + 20) < 0.10 then
                dpx_blend(c, r, px, py, pal.grass.dirt_dark, 80)
            end
        end end
    elseif vi == 3 then
        for i = 0, 5 do
            local tx = 8 + math.floor(hash(i, vi, seed + 30) * 48)
            local ty = 5 + math.floor(hash(vi, i, seed + 31) * 22)
            draw_grass_tuft(c, r, tx, ty, pal.grass.tuft_dark, pal.grass.tuft_tip, 2, seed + 32 + i)
        end
    elseif vi == 4 then
        for i = 0, 3 do
            draw_pebble(c, r, 14 + math.floor(hash(i, vi, seed + 40) * 32), 8 + math.floor(hash(vi, i, seed + 41) * 14), pal.grass.stone, pal.grass.stone_dark)
        end
    else
        for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
            if in_diamond(px, py) then
                local dist = math.abs((py - 15.5) - (px - 31.5) * 0.3)
                if dist < 3 and hash(px, py, seed + 50) < 0.4 then
                    dpx_blend(c, r, px, py, pal.grass.dirt, 80)
                end
            end
        end end
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- IRON: bg=13, fg=[14,15,16], misc=[17,18,19]
-- ════════════════════════════════════════════════════════════════════════

do
    local c, r = idx_to_cr(13)
    render_diamond(c, r, pal.iron.base, pal.iron.shadow, pal.iron.highlight, 300, {edge_thickness = 0.15, edge_darken = 0.55})
end

for vi = 0, 2 do
    local idx = 14 + vi
    local c, r = idx_to_cr(idx)
    local seed = 310 + vi * 19
    render_diamond(c, r, pal.iron.base, pal.iron.shadow, pal.iron.highlight, seed, {edge_thickness = 0.15, edge_darken = 0.55})
    local count = 2 + vi
    for i = 0, count - 1 do
        local cx = 14 + math.floor(hash(i, vi, seed + 10) * 32)
        local cy = 14 + math.floor(hash(vi, i, seed + 11) * 10)
        local h = 3 + math.floor(hash(i, vi + 1, seed + 12) * 3)
        local w = 2 + math.floor(hash(vi + 1, i, seed + 13) * 2)
        draw_rock(c, r, cx, cy, w, h, pal.iron.ore_light, pal.iron.ore, pal.iron.ore_dark)
    end
    if vi >= 1 then
        for i = 0, 1 do
            draw_crack(c, r, 18 + math.floor(hash(i, vi, seed + 20) * 24), 10 + math.floor(hash(vi, i, seed + 21) * 10), 4 + vi, pal.iron.rust, seed + 22 + i)
        end
    end
end

for vi = 0, 2 do
    local idx = 17 + vi
    local c, r = idx_to_cr(idx)
    local seed = 350 + vi * 23
    render_diamond(c, r, pal.iron.base, pal.iron.shadow, pal.iron.highlight, seed, {edge_thickness = 0.15, edge_darken = 0.55})
    draw_rock(c, r, 24 + math.floor(hash(vi, 0, seed + 10) * 16), 14 + math.floor(hash(0, vi, seed + 11) * 6), 2, 2 + vi, pal.iron.ore_light, pal.iron.ore, pal.iron.ore_dark)
    for i = 0, 3 do
        dpx(c, r, 10 + math.floor(hash(i, vi, seed + 30) * 44), 5 + math.floor(hash(vi, i, seed + 31) * 22), pal.iron.ore_dark)
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- COPPER: bg=20, fg=[21,22,23], misc=[24,25,26]
-- ════════════════════════════════════════════════════════════════════════

do
    local c, r = idx_to_cr(20)
    render_diamond(c, r, pal.copper.base, pal.copper.shadow, pal.copper.highlight, 400, {edge_thickness = 0.15, edge_darken = 0.55})
end

for vi = 0, 2 do
    local idx = 21 + vi
    local c, r = idx_to_cr(idx)
    local seed = 410 + vi * 17
    render_diamond(c, r, pal.copper.base, pal.copper.shadow, pal.copper.highlight, seed, {edge_thickness = 0.15, edge_darken = 0.55})
    local count = 2 + vi
    for i = 0, count - 1 do
        local cx = 14 + math.floor(hash(i, vi, seed + 10) * 30)
        local cy = 14 + math.floor(hash(vi, i, seed + 11) * 8)
        local h = 3 + math.floor(hash(i, vi + 1, seed + 12) * 2)
        draw_rock(c, r, cx, cy, 3, h, pal.copper.ore_light, pal.copper.ore, pal.copper.ore_dark)
        dpx(c, r, cx, cy - h, pal.copper.green)
        dpx(c, r, cx + 1, cy - h, brighten(pal.copper.green, 0.85))
    end
end

for vi = 0, 2 do
    local idx = 24 + vi
    local c, r = idx_to_cr(idx)
    local seed = 450 + vi * 19
    render_diamond(c, r, pal.copper.base, pal.copper.shadow, pal.copper.highlight, seed, {edge_thickness = 0.15, edge_darken = 0.55})
    for i = 0, 4 do
        dpx(c, r, 10 + math.floor(hash(i, vi, seed + 10) * 44), 5 + math.floor(hash(vi, i, seed + 11) * 22), pal.copper.ore)
    end
    if vi > 0 then
        draw_rock(c, r, 26 + math.floor(hash(vi, 0, seed + 20) * 12), 14, 2, 2, pal.copper.ore_light, pal.copper.ore, pal.copper.ore_dark)
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- COAL: bg=27, fg=[28,29,30], misc=[31,32,33]
-- ════════════════════════════════════════════════════════════════════════

do
    local c, r = idx_to_cr(27)
    render_diamond(c, r, pal.coal.base, pal.coal.shadow, pal.coal.highlight, 500, {edge_thickness = 0.18, edge_darken = 0.50})
end

for vi = 0, 2 do
    local idx = 28 + vi
    local c, r = idx_to_cr(idx)
    local seed = 510 + vi * 21
    render_diamond(c, r, pal.coal.base, pal.coal.shadow, pal.coal.highlight, seed, {edge_thickness = 0.18, edge_darken = 0.50})
    local count = 2 + vi
    for i = 0, count - 1 do
        local cx = 14 + math.floor(hash(i, vi, seed + 10) * 32)
        local cy = 14 + math.floor(hash(vi, i, seed + 11) * 8)
        local h = 2 + math.floor(hash(i, vi + 1, seed + 12) * 3)
        for dy = 0, h - 1 do
            local w = h - dy
            for dx = 0, w - 1 do
                local cc = pal.coal.seam
                if dy == h - 1 then cc = pal.coal.shiny end
                if dx == 0 then cc = pal.coal.dust end
                dpx(c, r, cx + dx, cy - dy, cc)
            end
        end
    end
    if vi >= 1 then
        for i = 0, vi do
            local sx = 12 + math.floor(hash(i, vi, seed + 20) * 36)
            local sy = 8 + math.floor(hash(vi, i, seed + 21) * 14)
            for j = 0, 3 do dpx_blend(c, r, sx + j, sy, pal.coal.shiny, 120) end
        end
    end
end

for vi = 0, 2 do
    local idx = 31 + vi
    local c, r = idx_to_cr(idx)
    local seed = 550 + vi * 17
    render_diamond(c, r, pal.coal.base, pal.coal.shadow, pal.coal.highlight, seed, {edge_thickness = 0.18, edge_darken = 0.50})
    for i = 0, 5 do
        dpx(c, r, 8 + math.floor(hash(i, vi, seed + 10) * 48), 4 + math.floor(hash(vi, i, seed + 11) * 24), pal.coal.seam)
    end
    if vi == 2 then draw_rock(c, r, 28, 14, 2, 2, pal.coal.shiny, pal.coal.dust, pal.coal.seam) end
end

-- ════════════════════════════════════════════════════════════════════════
-- TIN: bg=34, fg=[35,36,37], misc=[38,39,40]
-- ════════════════════════════════════════════════════════════════════════

do
    local c, r = idx_to_cr(34)
    render_diamond(c, r, pal.tin.base, pal.tin.shadow, pal.tin.highlight, 600, {edge_thickness = 0.14, edge_darken = 0.58})
end

for vi = 0, 2 do
    local idx = 35 + vi
    local c, r = idx_to_cr(idx)
    local seed = 610 + vi * 19
    render_diamond(c, r, pal.tin.base, pal.tin.shadow, pal.tin.highlight, seed, {edge_thickness = 0.14, edge_darken = 0.58})
    local count = 2 + vi
    for i = 0, count - 1 do
        local cx = 14 + math.floor(hash(i, vi, seed + 10) * 30)
        local cy = 14 + math.floor(hash(vi, i, seed + 11) * 8)
        local h = 2 + math.floor(hash(i, vi + 1, seed + 12) * 2)
        draw_rock(c, r, cx, cy, 2 + math.floor(hash(i, vi, seed + 14) * 2), h, pal.tin.ore_light, pal.tin.ore, pal.tin.ore_dark)
    end
end

for vi = 0, 2 do
    local idx = 38 + vi
    local c, r = idx_to_cr(idx)
    local seed = 650 + vi * 23
    render_diamond(c, r, pal.tin.base, pal.tin.shadow, pal.tin.highlight, seed, {edge_thickness = 0.14, edge_darken = 0.58})
    for i = 0, 3 do
        dpx(c, r, 10 + math.floor(hash(i, vi, seed + 10) * 44), 6 + math.floor(hash(vi, i, seed + 11) * 20), pal.tin.ore)
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- GOLD: bg=41, fg=[42,43,44], misc=[45,46,47]
-- ════════════════════════════════════════════════════════════════════════

do
    local c, r = idx_to_cr(41)
    render_diamond(c, r, pal.gold.base, pal.gold.shadow, pal.gold.highlight, 700, {edge_thickness = 0.16, edge_darken = 0.52})
end

for vi = 0, 2 do
    local idx = 42 + vi
    local c, r = idx_to_cr(idx)
    local seed = 710 + vi * 17
    render_diamond(c, r, pal.gold.base, pal.gold.shadow, pal.gold.highlight, seed, {edge_thickness = 0.16, edge_darken = 0.52})
    local count = 2 + vi
    for i = 0, count - 1 do
        local cx = 14 + math.floor(hash(i, vi, seed + 10) * 30)
        local cy = 14 + math.floor(hash(vi, i, seed + 11) * 8)
        local h = 2 + math.floor(hash(i, vi + 1, seed + 12) * 3)
        draw_rock(c, r, cx, cy, 2, h, pal.gold.ore_light, pal.gold.ore, pal.gold.ore_dark)
        dpx(c, r, cx, cy - h, pal.gold.sparkle)
    end
    if vi >= 1 then
        local sx = 16 + math.floor(hash(vi, 0, seed + 20) * 20)
        local sy = 10 + math.floor(hash(0, vi, seed + 21) * 8)
        for j = 0, 4 + vi do
            dpx_blend(c, r, sx + j, sy + math.floor(hash(j, vi, seed + 22) * 3) - 1, pal.gold.ore, 160)
        end
    end
end

for vi = 0, 2 do
    local idx = 45 + vi
    local c, r = idx_to_cr(idx)
    local seed = 750 + vi * 19
    render_diamond(c, r, pal.gold.base, pal.gold.shadow, pal.gold.highlight, seed, {edge_thickness = 0.16, edge_darken = 0.52})
    for i = 0, 4 do
        local sx = 10 + math.floor(hash(i, vi, seed + 10) * 44)
        local sy = 5 + math.floor(hash(vi, i, seed + 11) * 22)
        dpx(c, r, sx, sy, pal.gold.ore)
        if hash(i, vi, seed + 15) > 0.6 then dpx(c, r, sx + 1, sy, pal.gold.sparkle) end
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- QUARTZ (Crystalline): bg=48, fg=[49,50,51], misc=[52,53,54]
-- ════════════════════════════════════════════════════════════════════════

do
    local c, r = idx_to_cr(48)
    render_diamond(c, r, pal.quartz.base, pal.quartz.shadow, pal.quartz.highlight, 800, {edge_thickness = 0.14, edge_darken = 0.55})
    for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
        if in_diamond(px, py) then
            local n = fbm(px + 480, py + 800, 3, 805)
            if n > 0.6 then dpx_blend(c, r, px, py, pal.quartz.frost, math.floor((n - 0.6) * 2.5 * 80)) end
        end
    end end
end

for vi = 0, 2 do
    local idx = 49 + vi
    local c, r = idx_to_cr(idx)
    local seed = 810 + vi * 21
    render_diamond(c, r, pal.quartz.base, pal.quartz.shadow, pal.quartz.highlight, seed, {edge_thickness = 0.14, edge_darken = 0.55})
    for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
        if in_diamond(px, py) then
            local n = fbm(px + idx * 10, py + 800, 2, seed + 5)
            if n > 0.62 then dpx_blend(c, r, px, py, pal.quartz.frost, 60) end
        end
    end end
    local count = 2 + vi
    for i = 0, count - 1 do
        local cx = 14 + math.floor(hash(i, vi, seed + 10) * 30)
        local cy = 14 + math.floor(hash(vi, i, seed + 11) * 8)
        local h = 4 + math.floor(hash(i, vi + 1, seed + 12) * 3)
        local w = 2 + math.floor(hash(vi + 1, i, seed + 13) * 2)
        draw_hex_prism(c, r, cx, cy, h, w, pal.quartz.crystal, pal.quartz.deep, pal.quartz.ice)
    end
end

for vi = 0, 2 do
    local idx = 52 + vi
    local c, r = idx_to_cr(idx)
    local seed = 850 + vi * 17
    render_diamond(c, r, pal.quartz.base, pal.quartz.shadow, pal.quartz.highlight, seed, {edge_thickness = 0.14, edge_darken = 0.55})
    if vi == 0 then
        for i = 0, 3 do
            local sx = 10 + math.floor(hash(i, vi, seed + 10) * 20)
            local sy = 8 + math.floor(hash(vi, i, seed + 11) * 10)
            for j = 0, 4 do
                dpx(c, r, sx + j * 2, sy + math.floor(hash(j, i, seed + 12) * 3) - 1, with_alpha(pal.quartz.frost, 160))
            end
        end
    elseif vi == 1 then
        for i = 0, 4 do
            local sx = 10 + math.floor(hash(i, vi, seed + 20) * 44)
            local sy = 5 + math.floor(hash(vi, i, seed + 21) * 22)
            dpx(c, r, sx, sy, pal.quartz.crystal)
            if hash(i, vi, seed + 22) > 0.5 then dpx(c, r, sx + 1, sy, pal.quartz.ice) end
        end
    else
        draw_hex_prism(c, r, 28, 14, 3, 2, pal.quartz.crystal, pal.quartz.deep, pal.quartz.ice)
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- SULFUR: bg=55, fg=[56,57,58], misc=[59,60,61]
-- ════════════════════════════════════════════════════════════════════════

do
    local c, r = idx_to_cr(55)
    render_diamond(c, r, pal.sulfur.base, pal.sulfur.shadow, pal.sulfur.highlight, 900, {edge_thickness = 0.14, edge_darken = 0.55})
end

for vi = 0, 2 do
    local idx = 56 + vi
    local c, r = idx_to_cr(idx)
    local seed = 910 + vi * 19
    render_diamond(c, r, pal.sulfur.base, pal.sulfur.shadow, pal.sulfur.highlight, seed, {edge_thickness = 0.14, edge_darken = 0.55})
    local count = 2 + vi
    for i = 0, count - 1 do
        local cx = 14 + math.floor(hash(i, vi, seed + 10) * 30)
        local cy = 14 + math.floor(hash(vi, i, seed + 11) * 8)
        local h = 2 + math.floor(hash(i, vi + 1, seed + 12) * 3)
        draw_crystal_shard(c, r, cx, cy, h, 2, pal.sulfur.crust, pal.sulfur.bright, pal.sulfur.dark, pal.sulfur.bright)
    end
    if vi >= 1 then
        for i = 0, 1 do
            local fx = 18 + math.floor(hash(i, vi, seed + 20) * 24)
            local fy = 6 + math.floor(hash(vi, i, seed + 21) * 8)
            dpx_blend(c, r, fx, fy, pal.sulfur.fume, 100)
            dpx_blend(c, r, fx, fy - 1, pal.sulfur.fume, 60)
        end
    end
end

for vi = 0, 2 do
    local idx = 59 + vi
    local c, r = idx_to_cr(idx)
    local seed = 950 + vi * 23
    render_diamond(c, r, pal.sulfur.base, pal.sulfur.shadow, pal.sulfur.highlight, seed, {edge_thickness = 0.14, edge_darken = 0.55})
    for i = 0, 3 do
        dpx(c, r, 10 + math.floor(hash(i, vi, seed + 10) * 44), 5 + math.floor(hash(vi, i, seed + 11) * 22), pal.sulfur.crust)
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- WALL: bg=62, fg=[63,64,65], misc=[66,67,68]
-- ════════════════════════════════════════════════════════════════════════

local function wall_mortar(col, row, alpha)
    alpha = alpha or 120
    for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
        if not in_diamond(px, py) then goto cont end
        if diamond_depth(px, py) < 0.08 then goto cont end
        if py % 8 == 0 then dpx_blend(col, row, px, py, pal.wall.mortar, alpha) end
        local offset = (math.floor(py / 8) % 2 == 0) and 0 or 10
        if (px + offset) % 16 == 0 then dpx_blend(col, row, px, py, pal.wall.mortar, math.floor(alpha * 0.8)) end
        ::cont::
    end end
end

do
    local c, r = idx_to_cr(62)
    render_diamond(c, r, pal.wall.base, pal.wall.shadow, pal.wall.highlight, 1000, {edge_thickness = 0.20, edge_darken = 0.45})
    wall_mortar(c, r, 120)
end

for vi = 0, 2 do
    local idx = 63 + vi
    local c, r = idx_to_cr(idx)
    local seed = 1010 + vi * 17
    render_diamond(c, r, pal.wall.base, pal.wall.shadow, pal.wall.highlight, seed, {edge_thickness = 0.20, edge_darken = 0.45})
    wall_mortar(c, r, 120)
    for i = 0, vi + 1 do
        draw_crack(c, r, 10 + math.floor(hash(i, vi, seed + 10) * 30), 6 + math.floor(hash(vi, i, seed + 11) * 18), 4 + vi * 2, pal.wall.crack, seed + 12 + i)
    end
    if vi >= 1 then
        draw_rock(c, r, 22 + math.floor(hash(vi, 0, seed + 20) * 16), 12 + math.floor(hash(0, vi, seed + 21) * 6), 3, 2 + vi, pal.wall.light, pal.wall.base, pal.wall.shadow)
    end
end

for vi = 0, 2 do
    local idx = 66 + vi
    local c, r = idx_to_cr(idx)
    local seed = 1050 + vi * 19
    render_diamond(c, r, pal.wall.base, pal.wall.shadow, pal.wall.highlight, seed, {edge_thickness = 0.20, edge_darken = 0.45})
    wall_mortar(c, r, 100)
    if vi == 0 then
        for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
            if in_diamond(px, py) then
                local n = fbm(px + idx * 10, py + 1000, 2, seed + 5)
                if n > 0.5 and py > CELL_H / 2 then
                    dpx_blend(c, r, px, py, pal.wall.moss, math.floor((n - 0.5) * 2 * 120))
                end
            end
        end end
    elseif vi == 1 then
        for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
            if in_diamond(px, py) then dpx_blend(c, r, px, py, pal.wall.dark, 40) end
        end end
        draw_crack(c, r, 16, 10, 8, pal.wall.crack, seed + 10)
    else
        for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
            local d = diamond_depth(px, py)
            if d >= 0 and d < 0.12 then
                local n = hash(px, py, seed + 20)
                if n < 0.25 then dpx(c, r, px, py, TRANSPARENT)
                elseif n < 0.45 then dpx_blend(c, r, px, py, pal.wall.dark, 100) end
            end
        end end
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- STONE: bg=69, fg=[70,71,72], misc=[73,74,75]
-- ════════════════════════════════════════════════════════════════════════

local function stone_grid(col, row, alpha)
    alpha = alpha or 100
    for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
        if not in_diamond(px, py) then goto cont end
        if diamond_depth(px, py) < 0.06 then goto cont end
        local u = (px - 31.5) + (py - 15.5) * 2
        local v = -(px - 31.5) + (py - 15.5) * 2
        if math.abs(u % 16) < 1 or math.abs(v % 16) < 1 then
            dpx_blend(col, row, px, py, pal.stone.mortar, alpha)
        end
        ::cont::
    end end
end

do
    local c, r = idx_to_cr(69)
    render_diamond(c, r, pal.stone.base, pal.stone.shadow, pal.stone.highlight, 1100, {edge_thickness = 0.10, edge_darken = 0.60})
    stone_grid(c, r, 100)
end

for vi = 0, 2 do
    local idx = 70 + vi
    local c, r = idx_to_cr(idx)
    local seed = 1110 + vi * 19
    render_diamond(c, r, pal.stone.base, pal.stone.shadow, pal.stone.highlight, seed, {edge_thickness = 0.10, edge_darken = 0.60})
    stone_grid(c, r, 100)
    for i = 0, vi do
        draw_crack(c, r, 14 + math.floor(hash(i, vi, seed + 10) * 28), 8 + math.floor(hash(vi, i, seed + 11) * 14), 4 + vi * 2, pal.stone.crack, seed + 12 + i)
    end
end

for vi = 0, 2 do
    local idx = 73 + vi
    local c, r = idx_to_cr(idx)
    local seed = 1150 + vi * 23
    local shade = 0.9 + hash(vi, 0, seed) * 0.2
    render_diamond(c, r, brighten(pal.stone.base, shade), brighten(pal.stone.shadow, shade), brighten(pal.stone.highlight, shade), seed, {edge_thickness = 0.10, edge_darken = 0.60})
    stone_grid(c, r, 80)
end

-- ════════════════════════════════════════════════════════════════════════
-- OIL: bg=80, fg=[81,82,83], misc=[84,85,86]
-- ════════════════════════════════════════════════════════════════════════

do
    local c, r = idx_to_cr(80)
    render_diamond(c, r, pal.oil.base, pal.oil.shadow, pal.oil.highlight, 1200, {edge_thickness = 0.16, edge_darken = 0.50})
    for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
        if in_diamond(px, py) then
            local n = fbm(px + 800, py + 1200, 3, 1205)
            if n > 0.55 and n < 0.65 then dpx_blend(c, r, px, py, pal.oil.sheen, 40) end
        end
    end end
end

for vi = 0, 2 do
    local idx = 81 + vi
    local c, r = idx_to_cr(idx)
    local seed = 1210 + vi * 17
    render_diamond(c, r, pal.oil.base, pal.oil.shadow, pal.oil.highlight, seed, {edge_thickness = 0.16, edge_darken = 0.50})
    for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
        if in_diamond(px, py) then
            local n = fbm(px + idx * 10, py + seed, 2, seed + 5)
            if n > 0.5 then dpx_blend(c, r, px, py, pal.oil.sheen, math.floor((n - 0.5) * 2 * 50)) end
            local n2 = fbm(px + idx * 10 + 500, py + seed + 500, 2, seed + 10)
            if n2 > 0.7 then dpx_blend(c, r, px, py, pal.oil.rainbow, 30) end
        end
    end end
    -- Dark pool patches
    local count = 1 + vi
    for i = 0, count - 1 do
        local cx = 18 + math.floor(hash(i, vi, seed + 20) * 24)
        local cy = 10 + math.floor(hash(vi, i, seed + 21) * 12)
        for dy = -1, 1 do for dx = -2, 2 do
            if math.abs(dx) + math.abs(dy) < 3 then dpx_blend(c, r, cx + dx, cy + dy, pal.oil.dark, 80) end
        end end
    end
    for i = 0, vi do
        dpx(c, r, 14 + math.floor(hash(i, vi, seed + 30) * 32), 6 + math.floor(hash(vi, i, seed + 31) * 18), pal.oil.bubble)
    end
end

for vi = 0, 2 do
    local idx = 84 + vi
    local c, r = idx_to_cr(idx)
    local seed = 1250 + vi * 19
    render_diamond(c, r, pal.oil.base, pal.oil.shadow, pal.oil.highlight, seed, {edge_thickness = 0.16, edge_darken = 0.50})
    for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
        if in_diamond(px, py) then
            local n = fbm(px + idx * 10, py + seed, 2, seed + 5)
            if n > 0.6 then dpx_blend(c, r, px, py, pal.oil.sheen, 30) end
        end
    end end
end

-- ════════════════════════════════════════════════════════════════════════
-- CRYSTAL (Pyromite): bg=87, fg=[88,89,90], misc=[91,92,93]
-- ════════════════════════════════════════════════════════════════════════

do
    local c, r = idx_to_cr(87)
    render_diamond(c, r, pal.crystal.base, pal.crystal.shadow, pal.crystal.highlight, 1300, {edge_thickness = 0.16, edge_darken = 0.50})
    for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
        if in_diamond(px, py) then
            local n = fbm(px + 870, py + 1300, 2, 1305)
            if n > 0.62 and n < 0.70 then dpx_blend(c, r, px, py, pal.crystal.glow, 80) end
        end
    end end
end

for vi = 0, 2 do
    local idx = 88 + vi
    local c, r = idx_to_cr(idx)
    local seed = 1310 + vi * 21
    render_diamond(c, r, pal.crystal.base, pal.crystal.shadow, pal.crystal.highlight, seed, {edge_thickness = 0.16, edge_darken = 0.50})
    -- Glow cracks
    for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
        if in_diamond(px, py) then
            local n = fbm(px + idx * 10, py + seed, 2, seed + 5)
            if n > 0.60 and n < 0.68 then dpx_blend(c, r, px, py, pal.crystal.glow, 100) end
        end
    end end
    -- Jagged crystal shards
    local count = 2 + vi
    for i = 0, count - 1 do
        local cx = 12 + math.floor(hash(i, vi, seed + 10) * 34)
        local cy = 16 + math.floor(hash(vi, i, seed + 11) * 6)
        local h = 4 + math.floor(hash(i, vi + 1, seed + 12) * 4)
        local w = 1 + math.floor(hash(vi + 1, i, seed + 13) * 2)
        draw_crystal_shard(c, r, cx, cy, h, w, pal.crystal.shard, pal.crystal.glow, pal.crystal.dark, pal.crystal.ember)
    end
    -- Ember glow
    for i = 0, 2 do
        dpx_blend(c, r, 14 + math.floor(hash(i, vi, seed + 20) * 32), 8 + math.floor(hash(vi, i, seed + 21) * 12), pal.crystal.hot, 120)
    end
end

for vi = 0, 2 do
    local idx = 91 + vi
    local c, r = idx_to_cr(idx)
    local seed = 1350 + vi * 17
    render_diamond(c, r, pal.crystal.base, pal.crystal.shadow, pal.crystal.highlight, seed, {edge_thickness = 0.16, edge_darken = 0.50})
    if vi == 0 then
        for i = 0, 4 do
            dpx(c, r, 10 + math.floor(hash(i, vi, seed + 10) * 44), 4 + math.floor(hash(vi, i, seed + 11) * 24), with_alpha(pal.crystal.ember, 180))
        end
    elseif vi == 1 then
        for i = 0, 3 do
            dpx(c, r, 12 + math.floor(hash(i, vi, seed + 20) * 40), 6 + math.floor(hash(vi, i, seed + 21) * 20), with_alpha(pal.crystal.hot, 120))
        end
    else
        for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
            if in_diamond(px, py) and hash(px, py, seed + 30) < 0.06 then
                dpx_blend(c, r, px, py, pal.crystal.ash_col, 100)
            end
        end end
        draw_crystal_shard(c, r, 28, 14, 3, 1, pal.crystal.shard, pal.crystal.glow, pal.crystal.dark, pal.crystal.ember)
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- URANIUM: bg=94, fg=[95,96,97], misc=[98,99,100]
-- ════════════════════════════════════════════════════════════════════════

do
    local c, r = idx_to_cr(94)
    render_diamond(c, r, pal.uranium.base, pal.uranium.shadow, pal.uranium.highlight, 1400, {edge_thickness = 0.14, edge_darken = 0.55})
    for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
        if in_diamond(px, py) then
            local n = fbm(px + 940, py + 1400, 2, 1405)
            if n > 0.6 then dpx_blend(c, r, px, py, pal.uranium.glow, math.floor((n - 0.6) * 2.5 * 40)) end
        end
    end end
end

for vi = 0, 2 do
    local idx = 95 + vi
    local c, r = idx_to_cr(idx)
    local seed = 1410 + vi * 19
    render_diamond(c, r, pal.uranium.base, pal.uranium.shadow, pal.uranium.highlight, seed, {edge_thickness = 0.14, edge_darken = 0.55})
    for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
        if in_diamond(px, py) then
            local n = fbm(px + idx * 10, py + seed, 2, seed + 5)
            if n > 0.55 then dpx_blend(c, r, px, py, pal.uranium.glow, math.floor((n - 0.55) * 3 * 30)) end
        end
    end end
    local count = 2 + vi
    for i = 0, count - 1 do
        local cx = 14 + math.floor(hash(i, vi, seed + 10) * 30)
        local cy = 14 + math.floor(hash(vi, i, seed + 11) * 8)
        local h = 3 + math.floor(hash(i, vi + 1, seed + 12) * 3)
        for dy = 0, h - 1 do
            dpx(c, r, cx, cy - dy, pal.uranium.rod)
            if dy == h - 1 then dpx(c, r, cx, cy - dy, pal.uranium.bright) end
            dpx_blend(c, r, cx - 1, cy - dy, pal.uranium.glow, 50)
            dpx_blend(c, r, cx + 1, cy - dy, pal.uranium.glow, 50)
        end
    end
end

for vi = 0, 2 do
    local idx = 98 + vi
    local c, r = idx_to_cr(idx)
    local seed = 1450 + vi * 23
    render_diamond(c, r, pal.uranium.base, pal.uranium.shadow, pal.uranium.highlight, seed, {edge_thickness = 0.14, edge_darken = 0.55})
    for i = 0, 3 do
        dpx(c, r, 10 + math.floor(hash(i, vi, seed + 10) * 44), 5 + math.floor(hash(vi, i, seed + 11) * 22), pal.uranium.glow)
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- BIOMASS (Biovine): bg=101, fg=[102,103,104], misc=[105,106,107]
-- ════════════════════════════════════════════════════════════════════════

do
    local c, r = idx_to_cr(101)
    render_diamond(c, r, pal.biomass.base, pal.biomass.shadow, pal.biomass.highlight, 1500, {edge_thickness = 0.14, edge_darken = 0.55})
    for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
        if in_diamond(px, py) then
            local n = fbm(px + 1010, py + 1500, 3, 1505)
            if n > 0.55 and n < 0.62 then dpx_blend(c, r, px, py, pal.biomass.vine, 80) end
            local n2 = fbm(px + 1510, py + 2000, 2, 1510)
            if n2 > 0.7 then dpx_blend(c, r, px, py, pal.biomass.glow, 30) end
        end
    end end
end

for vi = 0, 2 do
    local idx = 102 + vi
    local c, r = idx_to_cr(idx)
    local seed = 1510 + vi * 21
    render_diamond(c, r, pal.biomass.base, pal.biomass.shadow, pal.biomass.highlight, seed, {edge_thickness = 0.14, edge_darken = 0.55})
    for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
        if in_diamond(px, py) then
            local n = fbm(px + idx * 10, py + seed, 2, seed + 5)
            if n > 0.56 and n < 0.63 then dpx_blend(c, r, px, py, pal.biomass.vine, 60) end
        end
    end end
    if vi == 0 then
        for i = 0, 2 do
            draw_vine(c, r, 14 + i * 14, 16 + math.floor(hash(i, vi, seed + 10) * 6), 5, pal.biomass.vine, pal.biomass.purple, seed + 11 + i)
        end
    elseif vi == 1 then
        for i = 0, 4 do
            local sx = 10 + math.floor(hash(i, vi, seed + 20) * 44)
            local sy = 5 + math.floor(hash(vi, i, seed + 21) * 22)
            dpx(c, r, sx, sy, pal.biomass.glow)
            dpx_blend(c, r, sx - 1, sy, pal.biomass.glow, 40)
            dpx_blend(c, r, sx + 1, sy, pal.biomass.glow, 40)
        end
        draw_vine(c, r, 20, 18, 6, pal.biomass.vine, pal.biomass.glow, seed + 25)
    else
        for i = 0, 1 do
            draw_mushroom(c, r, 18 + i * 16, 18 + math.floor(hash(i, vi, seed + 30) * 6), pal.biomass.mushcap, pal.biomass.mushroom, 3)
        end
        draw_vine(c, r, 30, 16, 4, pal.biomass.vine, pal.biomass.purple, seed + 35)
        dpx(c, r, 35, 10, pal.biomass.spore)
    end
end

for vi = 0, 2 do
    local idx = 105 + vi
    local c, r = idx_to_cr(idx)
    local seed = 1550 + vi * 17
    render_diamond(c, r, pal.biomass.base, pal.biomass.shadow, pal.biomass.highlight, seed, {edge_thickness = 0.14, edge_darken = 0.55})
    if vi == 0 then
        for i = 0, 3 do
            dpx(c, r, 10 + math.floor(hash(i, vi, seed + 10) * 40), 5 + math.floor(hash(vi, i, seed + 11) * 20), pal.biomass.spore)
        end
        draw_vine(c, r, 28, 18, 4, pal.biomass.vine, pal.biomass.dark, seed + 15)
    elseif vi == 1 then
        for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
            if in_diamond(px, py) then
                local n = fbm(px + idx * 10, py + seed, 2, seed + 5)
                if n > 0.58 and n < 0.64 then dpx_blend(c, r, px, py, pal.biomass.purple, 70) end
            end
        end end
    else
        for i = 0, 4 do
            dpx(c, r, 8 + math.floor(hash(i, vi, seed + 20) * 48), 4 + math.floor(hash(vi, i, seed + 21) * 24), pal.biomass.glow)
        end
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- ASH: bg=108, fg=[109,110,111], misc reuses [108,109,110]
-- ════════════════════════════════════════════════════════════════════════

do
    local c, r = idx_to_cr(108)
    render_diamond(c, r, pal.ash.base, pal.ash.shadow, pal.ash.highlight, 1600, {edge_thickness = 0.12, edge_darken = 0.58})
    for i = 0, 2 do
        draw_crack(c, r, 12 + math.floor(hash(i, 0, 1605) * 28), 8 + math.floor(hash(0, i, 1606) * 14), 5, pal.ash.crack, 1607 + i)
    end
end

for vi = 0, 2 do
    local idx = 109 + vi
    local c, r = idx_to_cr(idx)
    local seed = 1610 + vi * 19
    render_diamond(c, r, pal.ash.base, pal.ash.shadow, pal.ash.highlight, seed, {edge_thickness = 0.12, edge_darken = 0.58})
    for i = 0, 1 + vi do
        draw_crack(c, r, 10 + math.floor(hash(i, vi, seed + 10) * 30), 6 + math.floor(hash(vi, i, seed + 11) * 18), 4 + vi * 2, pal.ash.crack, seed + 12 + i)
    end
    if vi >= 1 then
        for i = 0, 2 do
            dpx(c, r, 12 + math.floor(hash(i, vi, seed + 20) * 40), 5 + math.floor(hash(vi, i, seed + 21) * 22), with_alpha(pal.ash.ember, 140))
        end
    end
    if vi == 2 then
        for py = 0, CELL_H - 1 do for px = 0, CELL_W - 1 do
            if in_diamond(px, py) and hash(px, py, seed + 30) < 0.05 then
                dpx_blend(c, r, px, py, pal.ash.crack, 80)
            end
        end end
    end
end

-- ════════════════════════════════════════════════════════════════════════
-- FINALIZE
-- ════════════════════════════════════════════════════════════════════════

local cel = spr.cels[1]
cel.image = img

local out_dir = "/Users/gorishniymax/Repos/factor/resources/sprites/terrain"
spr:saveCopyAs(out_dir .. "/terrain_atlas.png")
spr:saveAs(out_dir .. "/terrain_atlas.aseprite")
spr:close()

print("Terrain atlas exported to: " .. out_dir .. "/terrain_atlas.png")
print("Size: " .. W .. "x" .. H .. " (" .. COLS .. " cols x " .. ROWS .. " rows, " .. CELL_W .. "x" .. CELL_H .. " cells)")
