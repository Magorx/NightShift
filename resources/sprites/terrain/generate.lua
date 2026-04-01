-- Terrain atlas generator for Factor
-- Generates an 8x10 grid of 32x32 terrain tiles (256x320 total)
-- 3 layers per tile type: background (shared), foreground variants, misc variants
-- Run: aseprite -b --script generate.lua

local CELL = 32
local COLS = 8
local ROWS = 15
local W = COLS * CELL  -- 256
local H = ROWS * CELL  -- 480

-- ── Helpers ────────────────────────────────────────────────────────────────

local function hash(x, y, seed)
    local h = x * 374761393 + y * 668265263 + seed * 1274126177
    h = (h ~ (h >> 13)) * 1274126177
    h = h ~ (h >> 16)
    return (h % 10000) / 10000.0
end

local function lerp_color(c1, c2, t)
    t = math.max(0, math.min(1, t))
    return Color(
        c1.red + (c2.red - c1.red) * t,
        c1.green + (c2.green - c1.green) * t,
        c1.blue + (c2.blue - c1.blue) * t,
        c1.alpha + (c2.alpha - c1.alpha) * t
    )
end

local function value_noise(x, y, freq, seed)
    local fx = (x * freq) % CELL
    local fy = (y * freq) % CELL
    local ix = math.floor(fx) % CELL
    local iy = math.floor(fy) % CELL
    local fx2 = fx - math.floor(fx)
    local fy2 = fy - math.floor(fy)
    fx2 = fx2 * fx2 * (3 - 2 * fx2)
    fy2 = fy2 * fy2 * (3 - 2 * fy2)
    local ix1 = (ix + 1) % CELL
    local iy1 = (iy + 1) % CELL
    local v00 = hash(ix, iy, seed)
    local v10 = hash(ix1, iy, seed)
    local v01 = hash(ix, iy1, seed)
    local v11 = hash(ix1, iy1, seed)
    local top = v00 + (v10 - v00) * fx2
    local bot = v01 + (v11 - v01) * fx2
    return top + (bot - top) * fy2
end

local function fbm(x, y, octaves, seed)
    local val = 0
    local amp = 1
    local freq = 1
    local total_amp = 0
    for i = 1, octaves do
        val = val + value_noise(x, y, freq, seed + i * 1000) * amp
        total_amp = total_amp + amp
        amp = amp * 0.5
        freq = freq * 2
    end
    return val / total_amp
end

-- Safe pixel draw (wraps coordinates for tileability)
local function put(img, ox, oy, px, py, c)
    img:drawPixel(ox + (px % CELL), oy + (py % CELL), c)
end

-- Basic fill with noise
local function fill_bg(img, col, row, base, dark, light, seed)
    local ox = col * CELL
    local oy = row * CELL
    for py = 0, CELL - 1 do
        for px = 0, CELL - 1 do
            local n = fbm(px, py, 3, seed)
            local c
            if n < 0.4 then
                c = lerp_color(dark, base, n / 0.4)
            else
                c = lerp_color(base, light, (n - 0.4) / 0.6)
            end
            img:drawPixel(ox + px, oy + py, c)
        end
    end
end

-- ── Deposit-specific background: base rock + embedded veins ────────────────

--- Iron BG: dark rocky base with thick embedded steel-gray veins
local function fill_iron_bg(img, col, row, seed)
    local ox = col * CELL
    local oy = row * CELL
    local rock_base = Color(82, 78, 80)
    local rock_dark = Color(62, 58, 60)
    local rock_light = Color(100, 95, 98)
    local vein_core = Color(135, 120, 118)  -- steel gray with warm hint
    local vein_edge = Color(112, 100, 98)
    for py = 0, CELL - 1 do
        for px = 0, CELL - 1 do
            local base_n = fbm(px, py, 3, seed)
            local c = lerp_color(rock_dark, rock_light, base_n)
            -- Thick angular veins via low-freq noise with sharp threshold
            local vn = fbm(px, py, 2, seed + 500)
            local vn2 = value_noise(px, py, 0.8, seed + 600)
            local v = vn * 0.6 + vn2 * 0.4
            if v > 0.52 and v < 0.62 then
                c = lerp_color(vein_edge, vein_core, (v - 0.52) / 0.10)
            elseif v >= 0.62 and v < 0.68 then
                c = vein_core
            elseif v >= 0.68 and v < 0.75 then
                c = lerp_color(vein_core, vein_edge, (v - 0.68) / 0.07)
            end
            img:drawPixel(ox + px, oy + py, c)
        end
    end
end

--- Copper BG: warm brown base with green-patina banded veins
local function fill_copper_bg(img, col, row, seed)
    local ox = col * CELL
    local oy = row * CELL
    local rock_base = Color(145, 95, 55)
    local rock_dark = Color(118, 78, 42)
    local rock_light = Color(170, 112, 65)
    local patina = Color(72, 128, 98)
    local copper_bright = Color(195, 125, 60)
    for py = 0, CELL - 1 do
        for px = 0, CELL - 1 do
            local base_n = fbm(px, py, 3, seed)
            local c = lerp_color(rock_dark, rock_light, base_n)
            -- Horizontal-biased banded veins (stretch x by 2)
            local vn = value_noise(px, py * 2, 1.2, seed + 500)
            local vn2 = fbm(px, py, 2, seed + 600)
            local v = vn * 0.55 + vn2 * 0.45
            if v > 0.58 and v < 0.72 then
                -- Copper vein with patina edges
                local t = (v - 0.58) / 0.14
                if t < 0.25 or t > 0.75 then
                    c = lerp_color(c, patina, 0.7)
                else
                    c = lerp_color(copper_bright, Color(210, 140, 70), t)
                end
            end
            img:drawPixel(ox + px, oy + py, c)
        end
    end
end

--- Coal BG: dark rocky base with embedded glossy coal veins
local function fill_coal_bg(img, col, row, seed)
    local ox = col * CELL
    local oy = row * CELL
    local rock_dark = Color(48, 44, 46)
    local rock_light = Color(72, 68, 70)
    local coal_core = Color(18, 18, 22)
    local coal_edge = Color(30, 30, 36)
    local coal_shiny = Color(55, 55, 68)
    for py = 0, CELL - 1 do
        for px = 0, CELL - 1 do
            local base_n = fbm(px, py, 3, seed)
            local c = lerp_color(rock_dark, rock_light, base_n)
            -- Chunky coal veins via noise threshold (like iron/copper style)
            local vn = fbm(px, py, 2, seed + 500)
            local vn2 = value_noise(px * 0.8, py, 1.0, seed + 600)
            local v = vn * 0.55 + vn2 * 0.45
            if v > 0.48 and v < 0.58 then
                c = lerp_color(c, coal_edge, 0.7)
            elseif v >= 0.58 and v < 0.72 then
                local t = (v - 0.58) / 0.14
                c = lerp_color(coal_core, coal_edge, t)
                -- Glossy highlight on coal surface
                local shine = hash(px, py, seed + 700)
                if shine > 0.85 then
                    c = lerp_color(c, coal_shiny, 0.6)
                end
            elseif v >= 0.72 and v < 0.78 then
                c = lerp_color(c, coal_edge, 0.5)
            end
            img:drawPixel(ox + px, oy + py, c)
        end
    end
end

--- Tin BG: silvery-blue base with fine speckled granular texture
local function fill_tin_bg(img, col, row, seed)
    local ox = col * CELL
    local oy = row * CELL
    local base = Color(132, 138, 148)
    local dark = Color(108, 114, 124)
    local light = Color(158, 164, 174)
    local grain_bright = Color(178, 184, 196)
    for py = 0, CELL - 1 do
        for px = 0, CELL - 1 do
            local base_n = fbm(px, py, 3, seed)
            local c = lerp_color(dark, light, base_n)
            -- Fine granular: high-frequency noise creates speckle
            local grain = hash(px, py, seed + 500)
            local grain2 = value_noise(px, py, 3.0, seed + 600)
            if grain < 0.12 then
                c = lerp_color(c, grain_bright, 0.6)
            elseif grain2 > 0.72 then
                c = lerp_color(c, dark, 0.3)
            end
            -- Subtle delicate veins: thin branching lines
            local vn = fbm(px, py, 2, seed + 700)
            if math.abs(vn - 0.5) < 0.03 then
                c = lerp_color(c, grain_bright, 0.5)
            end
            img:drawPixel(ox + px, oy + py, c)
        end
    end
end

--- Gold BG: dark host rock with rare thin bright gold threads
local function fill_gold_bg(img, col, row, seed)
    local ox = col * CELL
    local oy = row * CELL
    local rock_base = Color(95, 85, 62)
    local rock_dark = Color(72, 64, 48)
    local rock_light = Color(115, 105, 78)
    local gold_vein = Color(218, 195, 65)
    local gold_bright = Color(245, 225, 105)
    for py = 0, CELL - 1 do
        for px = 0, CELL - 1 do
            local base_n = fbm(px, py, 3, seed)
            local c = lerp_color(rock_dark, rock_light, base_n)
            -- Thin rare veins: very narrow threshold on noise
            local vn = fbm(px, py, 2, seed + 500)
            local vn2 = value_noise(px, py, 1.5, seed + 600)
            local v = vn * 0.5 + vn2 * 0.5
            if math.abs(v - 0.5) < 0.02 then
                c = gold_vein
            elseif math.abs(v - 0.5) < 0.025 then
                c = lerp_color(c, gold_vein, 0.5)
            end
            -- Rare bright spots where veins cross
            if math.abs(vn - 0.5) < 0.015 and math.abs(vn2 - 0.5) < 0.04 then
                c = gold_bright
            end
            img:drawPixel(ox + px, oy + py, c)
        end
    end
end

--- Quartz BG: pale crystalline base with angular faceted blocks
local function fill_quartz_bg(img, col, row, seed)
    local ox = col * CELL
    local oy = row * CELL
    local base = Color(182, 170, 192)
    local dark = Color(155, 143, 165)
    local light = Color(210, 198, 220)
    local crystal_face = Color(225, 215, 238)
    local crystal_shadow = Color(145, 135, 158)
    for py = 0, CELL - 1 do
        for px = 0, CELL - 1 do
            local base_n = fbm(px, py, 3, seed)
            local c = lerp_color(dark, light, base_n)
            -- Angular blocks: use two perpendicular noise layers
            local n1 = value_noise(px, py, 1.0, seed + 500)
            local n2 = value_noise(px, py, 1.0, seed + 600)
            -- Create faceted look with sharp thresholds
            local block = math.floor(n1 * 5) / 5.0
            local block2 = math.floor(n2 * 5) / 5.0
            local edge = math.abs(n1 * 5 - math.floor(n1 * 5 + 0.5))
            local edge2 = math.abs(n2 * 5 - math.floor(n2 * 5 + 0.5))
            if edge < 0.08 or edge2 < 0.08 then
                c = lerp_color(c, crystal_shadow, 0.6)
            elseif (block + block2) > 1.2 then
                c = lerp_color(c, crystal_face, 0.4)
            end
            img:drawPixel(ox + px, oy + py, c)
        end
    end
end

--- Sulfur BG: volcanic yellow-green with bubbly/crusty round formations
local function fill_sulfur_bg(img, col, row, seed)
    local ox = col * CELL
    local oy = row * CELL
    local base = Color(165, 158, 32)
    local dark = Color(138, 132, 22)
    local light = Color(192, 185, 45)
    local crust = Color(205, 198, 55)
    local vent_dark = Color(110, 105, 18)
    for py = 0, CELL - 1 do
        for px = 0, CELL - 1 do
            local base_n = fbm(px, py, 3, seed)
            local c = lerp_color(dark, light, base_n)
            -- Bubbly round formations via cellular-like noise
            local n1 = value_noise(px, py, 1.2, seed + 500)
            local n2 = value_noise(px, py, 1.2, seed + 600)
            local dist = math.sqrt((n1 - 0.5)^2 + (n2 - 0.5)^2)
            -- Concentric rings = bubbly look
            local ring = math.abs(math.sin(dist * 18.0))
            if ring > 0.8 then
                c = lerp_color(c, crust, 0.6)
            elseif dist < 0.15 then
                c = lerp_color(c, vent_dark, 0.5)
            end
            img:drawPixel(ox + px, oy + py, c)
        end
    end
end

-- ── Deposit-specific foreground vein functions ─────────────────────────────

--- Iron FG: thick angular jagged veins with steel-gray highlights
local function draw_iron_veins(img, col, row, variant, seed)
    local ox = col * CELL
    local oy = row * CELL
    local vein_colors = {
        Color(140, 128, 125),  -- warm gray
        Color(148, 140, 142),  -- metallic silver
        Color(155, 138, 132),  -- steel with subtle warmth
    }
    local highlight = Color(172, 162, 158)
    -- Angular veins: walk with sharp turns
    local count = 3 + variant
    for i = 1, count do
        local sx = math.floor(hash(i, 0, seed) * CELL)
        local sy = math.floor(hash(i, 1, seed) * CELL)
        -- Pick from 4 cardinal-ish angles (angular, not smooth)
        local angles = {0, math.pi/2, math.pi*0.25, math.pi*0.75}
        local ai = math.floor(hash(i, 2, seed) * #angles) + 1
        local angle = angles[ai]
        local len = 10 + math.floor(hash(i, 3, seed) * 12)
        local ci = math.floor(hash(i, 4, seed) * #vein_colors) + 1
        ci = math.min(ci, #vein_colors)
        local vc = vein_colors[ci]
        local cx, cy = sx, sy
        for step = 0, len do
            -- Draw 2-3 pixel wide vein
            local width = 2
            if hash(step, i, seed + 30) > 0.6 then width = 3 end
            for w = 0, width - 1 do
                put(img, ox, oy, cx + w, cy, vc)
                put(img, ox, oy, cx, cy + w, vc)
            end
            -- Highlight on top edge
            if hash(step, i, seed + 40) > 0.6 then
                put(img, ox, oy, cx, cy - 1, highlight)
            end
            -- Advance with sharp angular turns
            cx = cx + math.floor(math.cos(angle) + 0.5)
            cy = cy + math.floor(math.sin(angle) + 0.5)
            -- Sharp turn every few steps
            if hash(step, i, seed + 50) > 0.7 then
                ai = (ai % #angles) + 1
                angle = angles[ai] + (hash(step, i, seed + 60) - 0.5) * 0.3
            end
        end
    end
end

--- Copper FG: branching veins with green patina spots
local function draw_copper_veins(img, col, row, variant, seed)
    local ox = col * CELL
    local oy = row * CELL
    local vein_main = Color(198, 128, 62)
    local patina = Color(68, 125, 95)
    local patina_light = Color(85, 142, 112)
    -- Main vein with branches
    local count = 2 + variant
    for i = 1, count do
        local sx = math.floor(hash(i, 0, seed) * CELL)
        local sy = math.floor(hash(i, 1, seed) * CELL)
        local angle = hash(i, 2, seed) * math.pi * 2
        local len = 12 + math.floor(hash(i, 3, seed) * 10)
        local cx, cy = sx, sy
        for step = 0, len do
            local wobble = (hash(step, i, seed + 50) - 0.5) * 2.5
            local px2 = math.floor(cx + math.sin(angle) * wobble)
            local py2 = math.floor(cy - math.cos(angle) * wobble)
            -- Main vein (1-2 wide)
            put(img, ox, oy, px2, py2, vein_main)
            if step % 2 == 0 then
                put(img, ox, oy, px2 + 1, py2, vein_main)
            end
            -- Patina spots along edges
            if hash(step, i, seed + 70) > 0.65 then
                local pc = patina
                if hash(step, i, seed + 80) > 0.5 then pc = patina_light end
                put(img, ox, oy, px2 - 1, py2, pc)
                put(img, ox, oy, px2 + 2, py2, pc)
            end
            -- Branch off occasionally
            if hash(step, i, seed + 90) > 0.82 then
                local ba = angle + (hash(step, i, seed + 91) - 0.5) * math.pi * 0.8
                local blen = 3 + math.floor(hash(step, i, seed + 92) * 5)
                local bx, by = px2, py2
                for bs = 0, blen do
                    bx = bx + math.floor(math.cos(ba) + 0.5)
                    by = by + math.floor(math.sin(ba) + 0.5)
                    local bc = vein_main
                    if bs > blen - 2 then bc = patina end
                    put(img, ox, oy, bx, by, bc)
                end
            end
            cx = cx + math.cos(angle)
            cy = cy + math.sin(angle)
            angle = angle + (hash(step, i, seed + 100) - 0.5) * 0.4
        end
    end
end

--- Coal FG: glossy horizontal seam lines with shiny reflections
local function draw_coal_seams(img, col, row, variant, seed)
    local ox = col * CELL
    local oy = row * CELL
    local coal_dark = Color(12, 12, 16)
    local coal_gloss = Color(48, 48, 62)
    local coal_bright = Color(75, 75, 92)
    -- Organic coal chunk veins (like copper/iron style, not horizontal lines)
    local count = 3 + variant * 2
    for i = 1, count do
        local sx = math.floor(hash(i, 0, seed) * CELL)
        local sy = math.floor(hash(i, 1, seed) * CELL)
        local angle = hash(i, 2, seed) * math.pi * 2
        local len = 6 + math.floor(hash(i, 3, seed) * 10)
        local cx, cy = sx + 0.0, sy + 0.0
        for step = 0, len do
            local px2 = math.floor(cx)
            local py2 = math.floor(cy)
            -- Coal vein body (2px wide)
            put(img, ox, oy, px2, py2, coal_dark)
            put(img, ox, oy, px2 + 1, py2, coal_dark)
            put(img, ox, oy, px2, py2 + 1, coal_dark)
            -- Glossy edge highlight
            if hash(step, i, seed + 300) > 0.5 then
                put(img, ox, oy, px2 - 1, py2, coal_gloss)
            end
            if hash(step, i, seed + 310) > 0.6 then
                put(img, ox, oy, px2, py2 - 1, coal_gloss)
            end
            -- Occasional bright glint
            if hash(step, i, seed + 400) > 0.85 then
                put(img, ox, oy, px2, py2, coal_bright)
            end
            -- Wander direction
            local turn = (hash(step, i, seed + 50) - 0.5) * 1.2
            angle = angle + turn
            cx = cx + math.cos(angle)
            cy = cy + math.sin(angle)
        end
    end
end

--- Tin FG: fine criss-crossing delicate network veins
local function draw_tin_network(img, col, row, variant, seed)
    local ox = col * CELL
    local oy = row * CELL
    local vein_light = Color(178, 184, 196)
    local vein_mid = Color(162, 168, 180)
    -- Many thin veins crossing at various angles
    local count = 6 + variant * 2
    for i = 1, count do
        local sx = math.floor(hash(i, 0, seed) * CELL)
        local sy = math.floor(hash(i, 1, seed) * CELL)
        local angle = hash(i, 2, seed) * math.pi
        local len = 6 + math.floor(hash(i, 3, seed) * 8)
        local c = vein_light
        if hash(i, 4, seed) > 0.5 then c = vein_mid end
        for step = 0, len do
            local wobble = (hash(step, i, seed + 50) - 0.5) * 1.5
            local px2 = math.floor(sx + math.cos(angle) * step + math.sin(angle) * wobble)
            local py2 = math.floor(sy + math.sin(angle) * step - math.cos(angle) * wobble)
            -- Single pixel thin vein
            put(img, ox, oy, px2, py2, c)
            -- Occasional node point (bright dot at intersections)
            if hash(step, i, seed + 60) > 0.88 then
                put(img, ox, oy, px2 + 1, py2, Color(195, 200, 212))
                put(img, ox, oy, px2 - 1, py2, Color(195, 200, 212))
                put(img, ox, oy, px2, py2 + 1, Color(195, 200, 212))
            end
        end
    end
end

--- Gold FG: thin dramatic bright threads with glint points
local function draw_gold_threads(img, col, row, variant, seed)
    local ox = col * CELL
    local oy = row * CELL
    local gold = Color(225, 200, 68)
    local gold_bright = Color(250, 235, 115)
    local gold_pale = Color(200, 180, 55)
    -- Few thin dramatic veins
    local count = 2 + variant
    for i = 1, count do
        local sx = math.floor(hash(i, 0, seed) * CELL)
        local sy = math.floor(hash(i, 1, seed) * CELL)
        local angle = hash(i, 2, seed) * math.pi * 2
        local len = 8 + math.floor(hash(i, 3, seed) * 14)
        local cx, cy = sx + 0.0, sy + 0.0
        for step = 0, len do
            local px2 = math.floor(cx)
            local py2 = math.floor(cy)
            -- Thin 1px line
            put(img, ox, oy, px2, py2, gold)
            -- Bright glint points
            if hash(step, i, seed + 70) > 0.8 then
                put(img, ox, oy, px2, py2, gold_bright)
                -- 4-point sparkle
                if hash(step, i, seed + 71) > 0.5 then
                    put(img, ox, oy, px2 + 1, py2, gold_pale)
                    put(img, ox, oy, px2 - 1, py2, gold_pale)
                    put(img, ox, oy, px2, py2 + 1, gold_pale)
                    put(img, ox, oy, px2, py2 - 1, gold_pale)
                end
            end
            -- Gentle curves
            cx = cx + math.cos(angle)
            cy = cy + math.sin(angle)
            angle = angle + (hash(step, i, seed + 80) - 0.5) * 0.6
        end
    end
end

--- Quartz FG: hexagonal/angular crystal cluster outlines
local function draw_quartz_crystals(img, col, row, variant, seed)
    local ox = col * CELL
    local oy = row * CELL
    local crystal = Color(222, 212, 235)
    local highlight = Color(240, 232, 250)
    local shadow = Color(155, 145, 168)
    local count = 3 + variant
    for i = 1, count do
        local cx = math.floor(hash(i, 0, seed) * (CELL - 8)) + 4
        local cy = math.floor(hash(i, 1, seed) * (CELL - 8)) + 4
        local h = 4 + math.floor(hash(i, 2, seed) * 5)
        local w = 2 + math.floor(hash(i, 3, seed) * 3)
        local tilt = math.floor((hash(i, 4, seed) - 0.5) * 3)
        -- Pointed crystal shape (hexagonal-ish)
        for dy = 0, h - 1 do
            local row_w = w
            if dy == 0 then row_w = math.max(1, w - 2)
            elseif dy == 1 or dy == h - 1 then row_w = math.max(1, w - 1)
            end
            local x_offset = math.floor(dy * tilt / h)
            for dx = 0, row_w - 1 do
                local px2 = cx - math.floor(row_w / 2) + dx + x_offset
                local py2 = cy - math.floor(h / 2) + dy
                -- Left edge = highlight, right edge = shadow, interior = crystal
                local c = crystal
                if dx == 0 then c = highlight
                elseif dx == row_w - 1 then c = shadow
                end
                if dy == 0 then c = highlight end
                put(img, ox, oy, px2, py2, c)
            end
        end
    end
end

--- Sulfur FG: round bubbly/crusty mound shapes
local function draw_sulfur_mounds(img, col, row, variant, seed)
    local ox = col * CELL
    local oy = row * CELL
    local crust_outer = Color(195, 188, 42)
    local crust_inner = Color(218, 210, 58)
    local bright = Color(235, 228, 75)
    local count = 3 + variant
    for i = 1, count do
        local cx = math.floor(hash(i, 0, seed) * (CELL - 6)) + 3
        local cy = math.floor(hash(i, 1, seed) * (CELL - 6)) + 3
        local r = 2 + math.floor(hash(i, 2, seed) * 3)
        -- Draw round mound with concentric coloring
        for dy = -r, r do
            for dx = -r, r do
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist <= r + 0.5 then
                    local t = dist / r
                    local c
                    if t > 0.7 then
                        c = crust_outer
                    elseif t > 0.35 then
                        c = crust_inner
                    else
                        c = bright
                    end
                    -- Crust texture on edge
                    if t > 0.5 and hash(cx + dx, cy + dy, seed + 300) > 0.6 then
                        c = lerp_color(c, Color(175, 168, 35), 0.4)
                    end
                    put(img, ox, oy, cx + dx, cy + dy, c)
                end
            end
        end
    end
end

--- Oil BG: dark tar-like surface with iridescent rainbow sheen
local function fill_oil_bg(img, col, row, seed)
    local ox = col * CELL
    local oy = row * CELL
    local base = Color(35, 28, 22)
    local dark = Color(22, 18, 14)
    local light = Color(48, 40, 32)
    local sheen_purple = Color(55, 30, 65)
    local sheen_blue = Color(30, 40, 60)
    local sheen_green = Color(35, 50, 35)
    for py = 0, CELL - 1 do
        for px = 0, CELL - 1 do
            local base_n = fbm(px, py, 3, seed)
            local c = lerp_color(dark, light, base_n)
            -- Iridescent oil sheen via overlapping noise
            local n1 = value_noise(px, py, 0.8, seed + 500)
            local n2 = value_noise(px, py, 1.2, seed + 600)
            local sheen = (n1 + n2) * 0.5
            if sheen > 0.55 and sheen < 0.65 then
                c = lerp_color(c, sheen_purple, 0.4)
            elseif sheen > 0.45 and sheen < 0.55 then
                c = lerp_color(c, sheen_blue, 0.3)
            elseif sheen > 0.35 and sheen < 0.45 then
                c = lerp_color(c, sheen_green, 0.25)
            end
            img:drawPixel(ox + px, oy + py, c)
        end
    end
end

--- Oil FG: tar pools and bubble-like features
local function draw_oil_pools(img, col, row, variant, seed)
    local ox = col * CELL
    local oy = row * CELL
    local pool_dark = Color(15, 12, 10)
    local pool_sheen = Color(50, 35, 60)
    local bubble = Color(60, 50, 70)
    local count = 2 + variant
    for i = 1, count do
        local cx = math.floor(hash(i, 0, seed) * (CELL - 8)) + 4
        local cy = math.floor(hash(i, 1, seed) * (CELL - 8)) + 4
        local r = 2 + math.floor(hash(i, 2, seed) * 3)
        for dy = -r, r do
            for dx = -r, r do
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist <= r + 0.5 then
                    local t = dist / r
                    local c = pool_dark
                    if t > 0.6 then c = lerp_color(pool_dark, pool_sheen, (t - 0.6) / 0.4) end
                    put(img, ox, oy, cx + dx, cy + dy, c)
                end
            end
        end
        -- Bubble highlights
        if hash(i, 3, seed) > 0.4 then
            put(img, ox, oy, cx - 1, cy - 1, bubble)
        end
    end
end

--- Crystal BG: dark violet host rock with angular prismatic formations
local function fill_crystal_bg(img, col, row, seed)
    local ox = col * CELL
    local oy = row * CELL
    local base = Color(75, 50, 95)
    local dark = Color(55, 35, 72)
    local light = Color(98, 68, 120)
    local prism1 = Color(140, 80, 180)
    local prism2 = Color(100, 120, 200)
    for py = 0, CELL - 1 do
        for px = 0, CELL - 1 do
            local base_n = fbm(px, py, 3, seed)
            local c = lerp_color(dark, light, base_n)
            -- Prismatic angular blocks
            local n1 = value_noise(px, py, 1.0, seed + 500)
            local n2 = value_noise(px, py, 1.0, seed + 600)
            local edge = math.abs(n1 * 4 - math.floor(n1 * 4 + 0.5))
            if edge < 0.06 then
                c = lerp_color(c, prism1, 0.5)
            elseif n2 > 0.7 then
                c = lerp_color(c, prism2, 0.3)
            end
            img:drawPixel(ox + px, oy + py, c)
        end
    end
end

--- Crystal FG: protruding crystal formations
local function draw_crystal_formations(img, col, row, variant, seed)
    local ox = col * CELL
    local oy = row * CELL
    local crystal_body = Color(160, 100, 200)
    local crystal_hi = Color(200, 150, 240)
    local crystal_shadow = Color(90, 55, 120)
    local count = 3 + variant
    for i = 1, count do
        local cx = math.floor(hash(i, 0, seed) * (CELL - 8)) + 4
        local cy = math.floor(hash(i, 1, seed) * (CELL - 8)) + 4
        local h = 4 + math.floor(hash(i, 2, seed) * 5)
        local w = 2 + math.floor(hash(i, 3, seed) * 2)
        local tilt = math.floor((hash(i, 4, seed) - 0.5) * 3)
        for dy = 0, h - 1 do
            local row_w = w
            if dy == 0 or dy == h - 1 then row_w = math.max(1, w - 1) end
            local x_offset = math.floor(dy * tilt / h)
            for dx = 0, row_w - 1 do
                local px2 = cx - math.floor(row_w / 2) + dx + x_offset
                local py2 = cy - math.floor(h / 2) + dy
                local c = crystal_body
                if dx == 0 then c = crystal_hi
                elseif dx == row_w - 1 then c = crystal_shadow end
                if dy == 0 then c = crystal_hi end
                put(img, ox, oy, px2, py2, c)
            end
        end
    end
end

--- Uranium BG: dark rock with eerie green luminescent veins
local function fill_uranium_bg(img, col, row, seed)
    local ox = col * CELL
    local oy = row * CELL
    local base = Color(55, 60, 52)
    local dark = Color(38, 42, 36)
    local light = Color(72, 78, 68)
    local glow = Color(60, 180, 75)
    local glow_dim = Color(45, 120, 55)
    for py = 0, CELL - 1 do
        for px = 0, CELL - 1 do
            local base_n = fbm(px, py, 3, seed)
            local c = lerp_color(dark, light, base_n)
            -- Green glowing veins
            local vn = fbm(px, py, 2, seed + 500)
            if math.abs(vn - 0.5) < 0.03 then
                c = glow
            elseif math.abs(vn - 0.5) < 0.06 then
                c = lerp_color(c, glow_dim, 0.5)
            end
            img:drawPixel(ox + px, oy + py, c)
        end
    end
end

--- Uranium FG: glowing ore chunks
local function draw_uranium_chunks(img, col, row, variant, seed)
    local ox = col * CELL
    local oy = row * CELL
    local ore_body = Color(50, 150, 60)
    local ore_bright = Color(80, 210, 90)
    local ore_dark = Color(35, 100, 42)
    local count = 2 + variant
    for i = 1, count do
        local cx = math.floor(hash(i, 0, seed) * (CELL - 6)) + 3
        local cy = math.floor(hash(i, 1, seed) * (CELL - 6)) + 3
        local r = 2 + math.floor(hash(i, 2, seed) * 2)
        for dy = -r, r do
            for dx = -r, r do
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist <= r + 0.3 then
                    local t = dist / r
                    local c = ore_body
                    if t < 0.4 then c = ore_bright
                    elseif t > 0.7 then c = ore_dark end
                    put(img, ox, oy, cx + dx, cy + dy, c)
                end
            end
        end
        -- Glow halo
        for dy = -(r+1), r+1 do
            for dx = -(r+1), r+1 do
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist > r + 0.3 and dist <= r + 1.5 then
                    local h = hash(cx+dx, cy+dy, seed + 300)
                    if h > 0.5 then
                        put(img, ox, oy, cx + dx, cy + dy, Color(55, 140, 62, 100))
                    end
                end
            end
        end
    end
end

--- Biomass BG: rich organic soil with decomposing plant matter
local function fill_biomass_bg(img, col, row, seed)
    local ox = col * CELL
    local oy = row * CELL
    local base = Color(65, 85, 40)
    local dark = Color(45, 62, 28)
    local light = Color(82, 105, 52)
    local soil = Color(72, 60, 38)
    for py = 0, CELL - 1 do
        for px = 0, CELL - 1 do
            local base_n = fbm(px, py, 3, seed)
            local c = lerp_color(dark, light, base_n)
            -- Soil patches
            local sn = value_noise(px, py, 0.8, seed + 500)
            if sn > 0.65 then
                c = lerp_color(c, soil, 0.4)
            end
            img:drawPixel(ox + px, oy + py, c)
        end
    end
end

--- Biomass FG: organic growths - mushrooms, moss patches, vine tendrils
local function draw_biomass_growth(img, col, row, variant, seed)
    local ox = col * CELL
    local oy = row * CELL
    local leaf_green = Color(55, 120, 45)
    local leaf_bright = Color(75, 145, 55)
    local moss = Color(48, 95, 38)
    local stem = Color(60, 50, 30)
    -- Moss patches
    local moss_count = 3 + variant
    for i = 1, moss_count do
        local cx = math.floor(hash(i, 0, seed) * (CELL - 4)) + 2
        local cy = math.floor(hash(i, 1, seed) * (CELL - 4)) + 2
        local r = 2 + math.floor(hash(i, 2, seed) * 2)
        for dy = -r, r do
            for dx = -r, r do
                if hash(cx+dx, cy+dy, seed + 100 + i) > 0.35 then
                    local dist = math.sqrt(dx*dx + dy*dy)
                    if dist <= r + 0.5 then
                        local c = moss
                        if hash(cx+dx, cy+dy, seed + 200) > 0.6 then c = leaf_green end
                        put(img, ox, oy, cx + dx, cy + dy, c)
                    end
                end
            end
        end
    end
    -- Small mushrooms/plants
    for i = 1, 2 + variant do
        local mx = math.floor(hash(i + 10, 0, seed) * (CELL - 4)) + 2
        local my = math.floor(hash(i + 10, 1, seed) * (CELL - 4)) + 2
        put(img, ox, oy, mx, my + 1, stem)
        put(img, ox, oy, mx, my, leaf_bright)
        put(img, ox, oy, mx - 1, my - 1, leaf_green)
        put(img, ox, oy, mx + 1, my - 1, leaf_green)
        put(img, ox, oy, mx, my - 1, leaf_bright)
    end
end

-- ── Generic helpers for misc layer ─────────────────────────────────────────

local function draw_tiny_shapes(img, col, row, shapes, seed)
    local ox = col * CELL
    local oy = row * CELL
    for i, shape in ipairs(shapes) do
        local cx = math.floor(hash(i, 0, seed) * (CELL - 4)) + 2
        local cy = math.floor(hash(i, 1, seed) * (CELL - 4)) + 2
        if shape.type == "dot" then
            img:drawPixel(ox + cx, oy + cy, shape.color)
        elseif shape.type == "cross" then
            img:drawPixel(ox + cx, oy + cy, shape.color)
            img:drawPixel(ox + cx + 1, oy + cy, shape.color)
            img:drawPixel(ox + cx - 1, oy + cy, shape.color)
            img:drawPixel(ox + cx, oy + cy + 1, shape.color)
            img:drawPixel(ox + cx, oy + cy - 1, shape.color)
        elseif shape.type == "square" then
            for dy = 0, 1 do for dx = 0, 1 do
                img:drawPixel(ox + cx + dx, oy + cy + dy, shape.color)
            end end
        elseif shape.type == "flower" then
            img:drawPixel(ox + cx, oy + cy, shape.center)
            img:drawPixel(ox + cx + 1, oy + cy, shape.color)
            img:drawPixel(ox + cx - 1, oy + cy, shape.color)
            img:drawPixel(ox + cx, oy + cy + 1, shape.color)
            img:drawPixel(ox + cx, oy + cy - 1, shape.color)
        elseif shape.type == "tri" then
            img:drawPixel(ox + cx, oy + cy - 1, shape.color)
            img:drawPixel(ox + cx - 1, oy + cy, shape.color)
            img:drawPixel(ox + cx + 1, oy + cy, shape.color)
            img:drawPixel(ox + cx, oy + cy, shape.color)
        elseif shape.type == "line" then
            for s = 0, (shape.len or 3) - 1 do
                img:drawPixel(ox + cx + s, oy + cy, shape.color)
            end
        elseif shape.type == "vline" then
            for s = 0, (shape.len or 3) - 1 do
                img:drawPixel(ox + cx, oy + cy + s, shape.color)
            end
        end
    end
end

local function draw_grass_blades(img, col, row, colors, count, max_height, seed)
    local ox = col * CELL
    local oy = row * CELL
    for i = 1, count do
        local bx = math.floor(hash(i, 0, seed) * CELL)
        local by = math.floor(hash(i, 1, seed) * (CELL - max_height)) + max_height
        local height = 2 + math.floor(hash(i, 2, seed) * (max_height - 1))
        local ci = math.floor(hash(i, 3, seed) * #colors) + 1
        ci = math.min(ci, #colors)
        local c = colors[ci]
        for h = 0, height - 1 do
            local lean = 0
            if h > 1 then lean = math.floor((hash(i, 4, seed) - 0.5) * 2) end
            local px = (bx + lean) % CELL
            local py = (by - h) % CELL
            img:drawPixel(ox + px, oy + py, c)
        end
    end
end

local function draw_scatter(img, col, row, colors, density, min_size, max_size, seed)
    local ox = col * CELL
    local oy = row * CELL
    for py = 0, CELL - 1 do
        for px = 0, CELL - 1 do
            local h = hash(px, py, seed)
            if h < density then
                local ci = math.floor(hash(px, py, seed + 100) * #colors) + 1
                ci = math.min(ci, #colors)
                local size = min_size + math.floor(hash(px, py, seed + 200) * (max_size - min_size + 1))
                for dy = 0, size - 1 do
                    for dx = 0, size - 1 do
                        img:drawPixel(ox + (px + dx) % CELL, oy + (py + dy) % CELL, colors[ci])
                    end
                end
            end
        end
    end
end

-- ── Sprite creation ───────────────────────────────────────────────────────

local spr = Sprite(W, H, ColorMode.RGB)
spr.filename = "terrain_atlas.aseprite"

local layer = spr.layers[1]
layer.name = "Atlas"
local cel = spr.cels[1]
local img = cel.image

-- Clear to fully transparent
for py = 0, H - 1 do
    for px = 0, W - 1 do
        img:drawPixel(px, py, Color(0, 0, 0, 0))
    end
end

-- ══════════════════════════════════════════════════════════════════════════
-- GRASS (Row 0-1): 1 bg + 6 fg + 6 misc = 13 sprites
-- ══════════════════════════════════════════════════════════════════════════

local GRASS_BASE = Color(72, 90, 56)
local GRASS_DARK = Color(58, 77, 44)
local GRASS_LIGHT = Color(86, 106, 65)
local GRASS_BRIGHT = Color(98, 120, 72)

fill_bg(img, 0, 0, GRASS_BASE, GRASS_DARK, GRASS_LIGHT, 1001)

draw_grass_blades(img, 1, 0, {GRASS_BRIGHT, GRASS_LIGHT, Color(80, 100, 58)}, 12, 3, 2001)
draw_grass_blades(img, 2, 0, {GRASS_BRIGHT, Color(90, 112, 64), GRASS_LIGHT}, 8, 5, 2002)
draw_grass_blades(img, 3, 0, {GRASS_BRIGHT, GRASS_LIGHT, Color(76, 96, 54)}, 18, 4, 2003)
draw_scatter(img, 4, 0, {Color(62, 54, 40), Color(70, 60, 46)}, 0.04, 1, 2, 2004)
draw_grass_blades(img, 4, 0, {GRASS_LIGHT}, 5, 3, 2014)

-- fg4: Clover-like leaf clusters
for i = 1, 6 do
    local cx = math.floor(hash(i, 0, 2005) * (CELL - 4)) + 2
    local cy = math.floor(hash(i, 1, 2005) * (CELL - 4)) + 2
    local ox2 = 5 * CELL
    local oy2 = 0 * CELL
    local c = Color(68, 100, 50)
    if hash(i, 2, 2005) > 0.5 then c = Color(74, 108, 55) end
    img:drawPixel(ox2 + cx, oy2 + cy - 1, c)
    img:drawPixel(ox2 + cx - 1, oy2 + cy, c)
    img:drawPixel(ox2 + cx + 1, oy2 + cy, c)
    img:drawPixel(ox2 + cx, oy2 + cy, Color(60, 80, 42))
    img:drawPixel(ox2 + cx, oy2 + cy + 1, Color(60, 80, 42))
end

draw_grass_blades(img, 6, 0, {Color(82, 96, 60), Color(74, 88, 54)}, 10, 6, 2006)

-- misc0-5
draw_tiny_shapes(img, 7, 0, {
    {type="flower", color=Color(200, 180, 60), center=Color(220, 200, 80)},
    {type="flower", color=Color(180, 100, 140), center=Color(220, 140, 170)},
    {type="dot", color=Color(210, 190, 70)},
}, 3001)
draw_tiny_shapes(img, 0, 1, {
    {type="square", color=Color(120, 115, 100)},
    {type="dot", color=Color(105, 100, 88)},
    {type="square", color=Color(130, 125, 110)},
    {type="dot", color=Color(95, 90, 80)},
}, 3002)
draw_tiny_shapes(img, 1, 1, {
    {type="tri", color=Color(140, 100, 40)},
    {type="dot", color=Color(160, 110, 50)},
}, 3003)

-- misc3: Small mushroom
do
    local cx, cy = 14, 18
    local ox2, oy2 = 2 * CELL, 1 * CELL
    img:drawPixel(ox2 + cx, oy2 + cy - 2, Color(180, 60, 50))
    img:drawPixel(ox2 + cx - 1, oy2 + cy - 1, Color(180, 60, 50))
    img:drawPixel(ox2 + cx, oy2 + cy - 1, Color(200, 80, 60))
    img:drawPixel(ox2 + cx + 1, oy2 + cy - 1, Color(180, 60, 50))
    img:drawPixel(ox2 + cx, oy2 + cy, Color(200, 190, 170))
    img:drawPixel(ox2 + cx, oy2 + cy + 1, Color(190, 180, 160))
    local cx2, cy2 = 20, 22
    img:drawPixel(ox2 + cx2, oy2 + cy2 - 1, Color(170, 55, 45))
    img:drawPixel(ox2 + cx2 - 1, oy2 + cy2, Color(170, 55, 45))
    img:drawPixel(ox2 + cx2, oy2 + cy2, Color(190, 180, 160))
end

draw_tiny_shapes(img, 3, 1, {
    {type="dot", color=Color(30, 28, 25)},
    {type="dot", color=Color(35, 32, 28)},
    {type="dot", color=Color(28, 26, 22)},
    {type="dot", color=Color(32, 30, 26)},
    {type="dot", color=Color(30, 28, 24)},
}, 3005)
draw_tiny_shapes(img, 4, 1, {
    {type="dot", color=Color(200, 220, 240, 180)},
    {type="dot", color=Color(180, 210, 235, 160)},
}, 3006)

-- ══════════════════════════════════════════════════════════════════════════
-- IRON (Row 1 cols 5-7, Row 2 cols 0-3)
-- Thick angular rust-red veins in dark rocky base
-- ══════════════════════════════════════════════════════════════════════════

fill_iron_bg(img, 5, 1, 4001)
draw_iron_veins(img, 6, 1, 0, 4002)   -- fewer veins
draw_iron_veins(img, 7, 1, 1, 4003)   -- medium
draw_iron_veins(img, 0, 2, 2, 4004)   -- dense

draw_tiny_shapes(img, 1, 2, {
    {type="cross", color=Color(200, 195, 210)},
    {type="dot", color=Color(190, 185, 200)},
    {type="dot", color=Color(210, 205, 220)},
}, 4005)
draw_tiny_shapes(img, 2, 2, {
    {type="line", color=Color(60, 56, 60), len=4},
    {type="vline", color=Color(55, 52, 56), len=3},
}, 4006)
draw_tiny_shapes(img, 3, 2, {
    {type="square", color=Color(118, 110, 108)},
    {type="dot", color=Color(132, 122, 120)},
    {type="square", color=Color(105, 98, 96)},
}, 4007)

-- ══════════════════════════════════════════════════════════════════════════
-- COPPER (Row 2 cols 4-7, Row 3 cols 0-2)
-- Branching veins with green patina in warm brown rock
-- ══════════════════════════════════════════════════════════════════════════

fill_copper_bg(img, 4, 2, 5001)
draw_copper_veins(img, 5, 2, 0, 5002)
draw_copper_veins(img, 6, 2, 1, 5003)
draw_copper_veins(img, 7, 2, 2, 5004)

draw_tiny_shapes(img, 0, 3, {
    {type="square", color=Color(70, 130, 100)},
    {type="dot", color=Color(85, 145, 115)},
    {type="square", color=Color(62, 118, 88)},
}, 5005)
draw_tiny_shapes(img, 1, 3, {
    {type="tri", color=Color(195, 125, 58)},
    {type="dot", color=Color(210, 140, 70)},
}, 5006)
draw_tiny_shapes(img, 2, 3, {
    {type="cross", color=Color(78, 135, 105)},
    {type="dot", color=Color(65, 120, 92)},
}, 5007)

-- ══════════════════════════════════════════════════════════════════════════
-- COAL (Row 3 cols 3-7, Row 4 cols 0-1)
-- Glossy horizontal strata seams in near-black base
-- ══════════════════════════════════════════════════════════════════════════

fill_coal_bg(img, 3, 3, 6001)
draw_coal_seams(img, 4, 3, 0, 6002)
draw_coal_seams(img, 5, 3, 1, 6003)
draw_coal_seams(img, 6, 3, 2, 6004)

draw_tiny_shapes(img, 7, 3, {
    {type="dot", color=Color(55, 55, 68)},
    {type="dot", color=Color(48, 48, 60)},
    {type="cross", color=Color(65, 65, 78)},
}, 6005)
draw_tiny_shapes(img, 0, 4, {
    {type="dot", color=Color(35, 35, 44)},
    {type="line", color=Color(42, 42, 52), len=3},
    {type="dot", color=Color(70, 70, 85)},
}, 6006)
draw_tiny_shapes(img, 1, 4, {
    {type="dot", color=Color(85, 60, 35, 140)},
    {type="dot", color=Color(95, 70, 40, 120)},
}, 6007)

-- ══════════════════════════════════════════════════════════════════════════
-- TIN (Row 4 cols 2-7, Row 5 col 0)
-- Fine criss-crossing network veins in silvery granular base
-- ══════════════════════════════════════════════════════════════════════════

fill_tin_bg(img, 2, 4, 7001)
draw_tin_network(img, 3, 4, 0, 7002)
draw_tin_network(img, 4, 4, 1, 7003)
draw_tin_network(img, 5, 4, 2, 7004)

draw_tiny_shapes(img, 6, 4, {
    {type="cross", color=Color(195, 200, 215)},
    {type="dot", color=Color(185, 190, 205)},
}, 7005)
draw_tiny_shapes(img, 7, 4, {
    {type="tri", color=Color(145, 150, 162)},
    {type="dot", color=Color(160, 165, 178)},
}, 7006)
draw_tiny_shapes(img, 0, 5, {
    {type="dot", color=Color(200, 205, 218)},
    {type="dot", color=Color(195, 200, 212)},
    {type="dot", color=Color(190, 195, 208)},
}, 7007)

-- ══════════════════════════════════════════════════════════════════════════
-- GOLD (Row 5 cols 1-7)
-- Thin dramatic bright threads in dark host rock
-- ══════════════════════════════════════════════════════════════════════════

fill_gold_bg(img, 1, 5, 8001)
draw_gold_threads(img, 2, 5, 0, 8002)
draw_gold_threads(img, 3, 5, 1, 8003)
draw_gold_threads(img, 4, 5, 2, 8004)

draw_tiny_shapes(img, 5, 5, {
    {type="cross", color=Color(255, 245, 180)},
    {type="dot", color=Color(250, 240, 160)},
}, 8005)
draw_tiny_shapes(img, 6, 5, {
    {type="line", color=Color(128, 110, 30), len=3},
    {type="vline", color=Color(120, 105, 28), len=3},
}, 8006)
draw_tiny_shapes(img, 7, 5, {
    {type="dot", color=Color(230, 210, 70)},
    {type="dot", color=Color(218, 195, 60)},
}, 8007)

-- ══════════════════════════════════════════════════════════════════════════
-- QUARTZ (Row 6)
-- Angular hexagonal crystal clusters in pale faceted base
-- ══════════════════════════════════════════════════════════════════════════

fill_quartz_bg(img, 0, 6, 9001)
draw_quartz_crystals(img, 1, 6, 0, 9002)
draw_quartz_crystals(img, 2, 6, 1, 9003)
draw_quartz_crystals(img, 3, 6, 2, 9004)

draw_tiny_shapes(img, 4, 6, {
    {type="tri", color=Color(230, 220, 242)},
    {type="dot", color=Color(238, 228, 248)},
}, 9005)
draw_tiny_shapes(img, 5, 6, {
    {type="square", color=Color(168, 158, 180)},
    {type="dot", color=Color(178, 168, 190)},
}, 9006)
draw_tiny_shapes(img, 6, 6, {
    {type="cross", color=Color(245, 238, 255, 160)},
    {type="dot", color=Color(235, 228, 248, 140)},
}, 9007)

-- ══════════════════════════════════════════════════════════════════════════
-- SULFUR (Row 6 col 7, Row 7 cols 0-5)
-- Round bubbly/crusty mounds in volcanic yellow-green base
-- ══════════════════════════════════════════════════════════════════════════

fill_sulfur_bg(img, 7, 6, 10001)
draw_sulfur_mounds(img, 0, 7, 0, 10002)
draw_sulfur_mounds(img, 1, 7, 1, 10003)
draw_sulfur_mounds(img, 2, 7, 2, 10004)

draw_tiny_shapes(img, 3, 7, {
    {type="dot", color=Color(200, 195, 55, 100)},
    {type="dot", color=Color(190, 185, 50, 80)},
    {type="dot", color=Color(210, 205, 60, 60)},
}, 10005)
draw_tiny_shapes(img, 4, 7, {
    {type="cross", color=Color(228, 220, 72)},
    {type="dot", color=Color(218, 210, 62)},
}, 10006)
draw_tiny_shapes(img, 5, 7, {
    {type="dot", color=Color(160, 155, 30)},
    {type="dot", color=Color(155, 150, 28)},
}, 10007)

-- ══════════════════════════════════════════════════════════════════════════
-- MUD WALL (Row 7 cols 6-7, Row 8 cols 0-4)
-- ══════════════════════════════════════════════════════════════════════════

local MUD_BASE = Color(107, 81, 56)
local MUD_DARK = Color(85, 64, 44)
local MUD_LIGHT = Color(130, 100, 70)
local MUD_CRACK = Color(70, 52, 36)

fill_bg(img, 6, 7, MUD_BASE, MUD_DARK, MUD_LIGHT, 11001)

-- fg0: Dried cracks (using generic vein helper inline)
do
    local ox2 = 7 * CELL
    local oy2 = 7 * CELL
    for i = 1, 5 do
        local sx = math.floor(hash(i, 0, 11002) * CELL)
        local sy = math.floor(hash(i, 1, 11002) * CELL)
        local angle = hash(i, 2, 11002) * math.pi * 2
        local len = 6 + math.floor(hash(i, 3, 11002) * 10)
        for step = 0, len do
            local wobble = (hash(step, i, 11052) - 0.5) * 3
            local px2 = math.floor(sx + math.cos(angle) * step + math.sin(angle) * wobble) % CELL
            local py2 = math.floor(sy + math.sin(angle) * step - math.cos(angle) * wobble) % CELL
            img:drawPixel(ox2 + px2, oy2 + py2, MUD_CRACK)
            if hash(step, i, 11077) > 0.5 then
                img:drawPixel(ox2 + (px2 + 1) % CELL, oy2 + py2, MUD_CRACK)
            end
        end
    end
end

-- fg1: Layered sediment
for i = 0, 4 do
    local y_start = 2 + i * 6
    local band_color = Color(115, 88, 62)
    if i % 2 == 1 then band_color = Color(95, 72, 50) end
    for px = 0, CELL - 1 do
        local py = y_start % CELL
        if hash(px, y_start, 11003) > 0.25 then
            img:drawPixel(0 * CELL + px, 8 * CELL + py, band_color)
        end
    end
end

-- fg2: Smooth patches
do
    local ox2 = 1 * CELL
    local oy2 = 8 * CELL
    for i = 1, 4 do
        local cx = math.floor(hash(i, 0, 11004) * CELL)
        local cy = math.floor(hash(i, 1, 11004) * CELL)
        local size = 2 + math.floor(hash(i, 2, 11004) * 3)
        local colors = {Color(118, 90, 64), Color(122, 94, 68), MUD_LIGHT}
        local ci = math.floor(hash(i, 3, 11004) * #colors) + 1
        ci = math.min(ci, #colors)
        for dy = 0, size - 1 do for dx = 0, size - 1 do
            if hash(dx + i*7, dy + i*13, 11099) > 0.25 then
                img:drawPixel(ox2 + (cx + dx) % CELL, oy2 + (cy + dy) % CELL, colors[ci])
            end
        end end
    end
end

draw_tiny_shapes(img, 2, 8, {
    {type="line", color=Color(75, 58, 35), len=4},
    {type="vline", color=Color(70, 54, 32), len=3},
}, 11005)
draw_tiny_shapes(img, 3, 8, {
    {type="square", color=Color(120, 115, 100)},
    {type="dot", color=Color(110, 105, 92)},
}, 11006)
draw_tiny_shapes(img, 4, 8, {
    {type="line", color=Color(80, 60, 42), len=5},
    {type="dot", color=Color(75, 56, 38)},
}, 11007)

-- ══════════════════════════════════════════════════════════════════════════
-- STONE WALL (Row 8 cols 5-7, Row 9 cols 0-3)
-- ══════════════════════════════════════════════════════════════════════════

local STONE_BASE = Color(140, 138, 128)
local STONE_DARK = Color(115, 113, 105)
local STONE_LIGHT = Color(165, 162, 150)
local STONE_JOINT = Color(90, 88, 82)

fill_bg(img, 5, 8, STONE_BASE, STONE_DARK, STONE_LIGHT, 12001)

-- fg0: Block joints
do
    local ox2 = 6 * CELL
    local oy2 = 8 * CELL
    for y = 0, CELL - 1, 8 do
        for px = 0, CELL - 1 do
            if hash(px, y, 12002) > 0.2 then
                img:drawPixel(ox2 + px, oy2 + y, STONE_JOINT)
            end
        end
    end
    for row_i = 0, 3 do
        local y_start = row_i * 8
        local x_offset = (row_i % 2) * 8
        for x = x_offset, CELL - 1, 16 do
            for py = y_start, math.min(y_start + 7, CELL - 1) do
                if hash(x, py, 12012) > 0.3 then
                    img:drawPixel(ox2 + x, oy2 + py, STONE_JOINT)
                end
            end
        end
    end
end

-- fg1: Fissure lines
do
    local ox2 = 7 * CELL
    local oy2 = 8 * CELL
    for i = 1, 4 do
        local sx = math.floor(hash(i, 0, 12003) * CELL)
        local sy = math.floor(hash(i, 1, 12003) * CELL)
        local angle = hash(i, 2, 12003) * math.pi * 2
        local len = 6 + math.floor(hash(i, 3, 12003) * 10)
        for step = 0, len do
            local wobble = (hash(step, i, 12053) - 0.5) * 3
            local px2 = math.floor(sx + math.cos(angle) * step + math.sin(angle) * wobble) % CELL
            local py2 = math.floor(sy + math.sin(angle) * step - math.cos(angle) * wobble) % CELL
            img:drawPixel(ox2 + px2, oy2 + py2, Color(100, 98, 90))
        end
    end
end

-- fg2: Rough facets
do
    local ox2 = 0 * CELL
    local oy2 = 9 * CELL
    local colors = {STONE_LIGHT, Color(150, 148, 138), Color(155, 152, 142)}
    for i = 1, 5 do
        local cx = math.floor(hash(i, 0, 12004) * CELL)
        local cy = math.floor(hash(i, 1, 12004) * CELL)
        local size = 2 + math.floor(hash(i, 2, 12004) * 2)
        local ci = math.floor(hash(i, 3, 12004) * #colors) + 1
        ci = math.min(ci, #colors)
        for dy = 0, size - 1 do for dx = 0, size - 1 do
            if hash(dx + i*7, dy + i*13, 12099) > 0.25 then
                img:drawPixel(ox2 + (cx + dx) % CELL, oy2 + (cy + dy) % CELL, colors[ci])
            end
        end end
    end
end

draw_tiny_shapes(img, 1, 9, {
    {type="square", color=Color(70, 100, 55)},
    {type="dot", color=Color(80, 110, 60)},
    {type="dot", color=Color(65, 95, 50)},
}, 12005)
draw_tiny_shapes(img, 2, 9, {
    {type="tri", color=Color(125, 122, 112)},
    {type="dot", color=Color(135, 132, 122)},
}, 12006)
draw_tiny_shapes(img, 3, 9, {
    {type="square", color=Color(150, 148, 80)},
    {type="dot", color=Color(140, 138, 75)},
    {type="dot", color=Color(145, 142, 78)},
}, 12007)

-- ══════════════════════════════════════════════════════════════════════════
-- OIL (Row 10)
-- Dark tar-like pools with iridescent rainbow sheen
-- ══════════════════════════════════════════════════════════════════════════

fill_oil_bg(img, 0, 10, 13001)
draw_oil_pools(img, 1, 10, 0, 13002)
draw_oil_pools(img, 2, 10, 1, 13003)
draw_oil_pools(img, 3, 10, 2, 13004)

draw_tiny_shapes(img, 4, 10, {
    {type="dot", color=Color(50, 35, 60)},
    {type="dot", color=Color(45, 30, 55)},
    {type="dot", color=Color(55, 40, 65)},
}, 13005)
draw_tiny_shapes(img, 5, 10, {
    {type="square", color=Color(25, 20, 18)},
    {type="dot", color=Color(30, 25, 22)},
}, 13006)
draw_tiny_shapes(img, 6, 10, {
    {type="dot", color=Color(40, 50, 60, 120)},
    {type="dot", color=Color(50, 30, 55, 100)},
}, 13007)

-- ══════════════════════════════════════════════════════════════════════════
-- CRYSTAL (Row 11)
-- Purple prismatic formations in dark violet rock
-- ══════════════════════════════════════════════════════════════════════════

fill_crystal_bg(img, 7, 10, 14001)
draw_crystal_formations(img, 0, 11, 0, 14002)
draw_crystal_formations(img, 1, 11, 1, 14003)
draw_crystal_formations(img, 2, 11, 2, 14004)

draw_tiny_shapes(img, 3, 11, {
    {type="tri", color=Color(180, 120, 220)},
    {type="dot", color=Color(170, 110, 210)},
}, 14005)
draw_tiny_shapes(img, 4, 11, {
    {type="cross", color=Color(130, 80, 170)},
    {type="dot", color=Color(140, 90, 180)},
}, 14006)
draw_tiny_shapes(img, 5, 11, {
    {type="dot", color=Color(190, 140, 230)},
    {type="dot", color=Color(100, 120, 200)},
}, 14007)

-- ══════════════════════════════════════════════════════════════════════════
-- URANIUM (Row 12)
-- Glowing green radioactive ore in dark rock
-- ══════════════════════════════════════════════════════════════════════════

fill_uranium_bg(img, 6, 11, 15001)
draw_uranium_chunks(img, 7, 11, 0, 15002)
draw_uranium_chunks(img, 0, 12, 1, 15003)
draw_uranium_chunks(img, 1, 12, 2, 15004)

draw_tiny_shapes(img, 2, 12, {
    {type="cross", color=Color(70, 180, 80)},
    {type="dot", color=Color(60, 160, 70)},
}, 15005)
draw_tiny_shapes(img, 3, 12, {
    {type="dot", color=Color(50, 140, 55, 140)},
    {type="dot", color=Color(55, 150, 60, 120)},
}, 15006)
draw_tiny_shapes(img, 4, 12, {
    {type="dot", color=Color(45, 130, 52)},
    {type="dot", color=Color(40, 110, 45)},
}, 15007)

-- ══════════════════════════════════════════════════════════════════════════
-- BIOMASS (Row 13)
-- Organic green growths with moss, mushrooms, and vine tendrils
-- ══════════════════════════════════════════════════════════════════════════

fill_biomass_bg(img, 5, 12, 16001)
draw_biomass_growth(img, 6, 12, 0, 16002)
draw_biomass_growth(img, 7, 12, 1, 16003)
draw_biomass_growth(img, 0, 13, 2, 16004)

draw_tiny_shapes(img, 1, 13, {
    {type="flower", color=Color(90, 150, 60), center=Color(120, 180, 80)},
    {type="dot", color=Color(55, 110, 42)},
}, 16005)
draw_tiny_shapes(img, 2, 13, {
    {type="tri", color=Color(70, 130, 50)},
    {type="dot", color=Color(80, 140, 55)},
}, 16006)
draw_tiny_shapes(img, 3, 13, {
    {type="dot", color=Color(65, 55, 35)},
    {type="dot", color=Color(58, 48, 30)},
    {type="square", color=Color(50, 95, 35)},
}, 16007)

-- ══════════════════════════════════════════════════════════════════════════
-- ASH (Row 14)
-- Depleted biomass — dry cracked gray-brown soil with charred remnants
-- ══════════════════════════════════════════════════════════════════════════

local function fill_ash_bg(img, col, row, seed)
    local ox = col * CELL
    local oy = row * CELL
    local base = Color(105, 95, 82)
    local dark = Color(82, 74, 64)
    local light = Color(120, 110, 96)
    local char_dark = Color(55, 50, 45)
    for py = 0, CELL - 1 do
        for px = 0, CELL - 1 do
            local base_n = fbm(px, py, 3, seed)
            local c = lerp_color(dark, light, base_n)
            -- Charred patches
            local sn = value_noise(px, py, 0.7, seed + 500)
            if sn > 0.7 then
                c = lerp_color(c, char_dark, 0.5)
            end
            -- Cracks: thin dark lines
            local crack_n = value_noise(px, py, 1.2, seed + 300)
            if crack_n > 0.78 and crack_n < 0.82 then
                c = lerp_color(c, Color(45, 40, 35), 0.7)
            end
            img:drawPixel(ox + px, oy + py, c)
        end
    end
end

local function draw_ash_detail(img, col, row, variant, seed)
    local ox = col * CELL
    local oy = row * CELL
    local char_color = Color(60, 55, 48)
    local dead_stem = Color(75, 65, 50)
    local ember = Color(140, 80, 40)
    -- Charred debris spots
    local count = 2 + variant
    for i = 1, count do
        local cx = math.floor(hash(i, 0, seed) * (CELL - 4)) + 2
        local cy = math.floor(hash(i, 1, seed) * (CELL - 4)) + 2
        put(img, ox, oy, cx, cy, char_color)
        if hash(i, 2, seed) > 0.5 then
            put(img, ox, oy, cx + 1, cy, char_color)
        end
    end
    -- Dead plant stumps
    for i = 1, 1 + variant do
        local sx = math.floor(hash(i + 20, 0, seed) * (CELL - 4)) + 2
        local sy = math.floor(hash(i + 20, 1, seed) * (CELL - 4)) + 2
        put(img, ox, oy, sx, sy, dead_stem)
        put(img, ox, oy, sx, sy + 1, dead_stem)
        if hash(i + 20, 2, seed) > 0.7 then
            put(img, ox, oy, sx - 1, sy, ember)
        end
    end
end

-- Ash bg at atlas index 108 -> col 4, row 13
fill_ash_bg(img, 4, 13, 17001)
-- Ash fg variants at 109-111 -> (5,13), (6,13), (7,13)
draw_ash_detail(img, 5, 13, 0, 17002)
draw_ash_detail(img, 6, 13, 1, 17003)
draw_ash_detail(img, 7, 13, 2, 17004)

-- ── Save ──────────────────────────────────────────────────────────────────

local script_path = debug.getinfo(1, "S").source:sub(2)
local dir = script_path:match("(.*/)")
if not dir or dir == "" then dir = "./" end

spr:saveAs(dir .. "terrain_atlas.aseprite")
spr:saveCopyAs(dir .. "terrain_atlas.png")

print("Terrain atlas generated: " .. W .. "x" .. H .. " (" .. COLS .. "x" .. ROWS .. " grid of " .. CELL .. "x" .. CELL .. ")")
print("Total sprites: 112 (13 grass + 63 deposits/walls + 32 new deposits + 4 ash)")
