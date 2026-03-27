-- compare_sprites.lua — pixel-level diff between two .aseprite files.
--
-- Compares a "reference" sprite (user-edited) against a "generated" sprite
-- (from code) and writes a detailed text report showing what the generation
-- code needs to change to match the reference.
--
-- Usage (from a wrapper script run with `aseprite -b --script /tmp/wrapper.lua`):
--
--   local compare = dofile("tools/compare_sprites.lua")
--   compare("/tmp/reference.aseprite", "buildings/smelter/sprites/main.aseprite")
--
-- Optional third argument: report output path (default /tmp/sprite_diff.txt)
--
-- Diff semantics (always "what should the code change?"):
--   ADD    = pixel exists in reference but not in generated → code must draw it
--   REMOVE = pixel exists in generated but not in reference → code must stop drawing it
--   CHANGE = both have a pixel but colors differ → code must use the reference color

local function color_hex(c)
    local r = app.pixelColor.rgbaR(c)
    local g = app.pixelColor.rgbaG(c)
    local b = app.pixelColor.rgbaB(c)
    local a = app.pixelColor.rgbaA(c)
    if a == 0 then return "transparent" end
    if a == 255 then return string.format("#%02X%02X%02X", r, g, b) end
    return string.format("#%02X%02X%02X@%d", r, g, b, a)
end

local function px_equal(a, b)
    if app.pixelColor.rgbaA(a) == 0 and app.pixelColor.rgbaA(b) == 0 then return true end
    return a == b
end

local function pixel_at(cel, x, y)
    if not cel then return app.pixelColor.rgba(0, 0, 0, 0) end
    local lx = x - cel.position.x
    local ly = y - cel.position.y
    if lx >= 0 and lx < cel.image.width and ly >= 0 and ly < cel.image.height then
        return cel.image:getPixel(lx, ly)
    end
    return app.pixelColor.rgba(0, 0, 0, 0)
end

local function build_cel_map(spr)
    local m = {}
    for _, layer in ipairs(spr.layers) do
        m[layer.name] = {}
        for _, cel in ipairs(layer.cels) do
            m[layer.name][cel.frameNumber] = cel
        end
    end
    return m
end

-- 8-connected flood-fill clustering of changed pixels
local function cluster_pixels(changed, w)
    local set = {}
    for _, p in ipairs(changed) do set[p.y * w + p.x] = p end

    local visited = {}
    local clusters = {}

    for _, p in ipairs(changed) do
        local key = p.y * w + p.x
        if not visited[key] then
            local cluster = {}
            local queue = { p }
            visited[key] = true
            while #queue > 0 do
                local cur = table.remove(queue, 1)
                cluster[#cluster + 1] = cur
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        if dx ~= 0 or dy ~= 0 then
                            local nk = (cur.y + dy) * w + (cur.x + dx)
                            if set[nk] and not visited[nk] then
                                visited[nk] = true
                                queue[#queue + 1] = set[nk]
                            end
                        end
                    end
                end
            end
            clusters[#clusters + 1] = cluster
        end
    end

    table.sort(clusters, function(a, b) return #a > #b end)
    return clusters
end

local function bbox(pixels)
    local x1, y1, x2, y2 = 9999, 9999, 0, 0
    for _, p in ipairs(pixels) do
        if p.x < x1 then x1 = p.x end
        if p.y < y1 then y1 = p.y end
        if p.x > x2 then x2 = p.x end
        if p.y > y2 then y2 = p.y end
    end
    return x1, y1, x2, y2
end

local function describe_cluster(cluster, w)
    local x1, y1, x2, y2 = bbox(cluster)
    local cw, ch = x2 - x1 + 1, y2 - y1 + 1
    local fill = #cluster / (cw * ch) * 100
    local shape = ""
    if cw == 1 and ch == 1 then shape = "pixel"
    elseif fill > 95 then shape = "solid rect"
    elseif fill > 75 then shape = "~rect"
    elseif cw == 1 or ch == 1 then shape = "line"
    else shape = "region" end

    -- Dominant target color
    local color_counts = {}
    for _, p in ipairs(cluster) do
        local c = color_hex(p.ref)
        color_counts[c] = (color_counts[c] or 0) + 1
    end
    local best_color, best_n = "?", 0
    for c, n in pairs(color_counts) do
        if n > best_n then best_color, best_n = c, n end
    end

    return string.format("%d px  (%d,%d)-(%d,%d) %dx%d  [%s]  target: %s",
        #cluster, x1, y1, x2, y2, cw, ch, shape, best_color)
end

-- ═══════════════════════════════════════════════════════════════════════════

local function compare(path_ref, path_gen, report_path)
    report_path = report_path or "/tmp/sprite_diff.txt"

    local spr_ref = app.open(path_ref)
    assert(spr_ref, "Cannot open reference: " .. path_ref)
    local spr_gen = app.open(path_gen)
    assert(spr_gen, "Cannot open generated: " .. path_gen)

    local out = {}
    local function log(s) out[#out + 1] = s end

    -- ── Header ──────────────────────────────────────────────────────────
    log("=== SPRITE DIFF REPORT ===")
    log(string.format("Reference: %s  [%dx%d, %d layers, %d frames]",
        path_ref, spr_ref.width, spr_ref.height, #spr_ref.layers, #spr_ref.frames))
    log(string.format("Generated: %s  [%dx%d, %d layers, %d frames]",
        path_gen, spr_gen.width, spr_gen.height, #spr_gen.layers, #spr_gen.frames))
    log("")

    -- ── Structural checks ───────────────────────────────────────────────
    if spr_ref.width ~= spr_gen.width or spr_ref.height ~= spr_gen.height then
        log(string.format("!! CANVAS SIZE MISMATCH  ref=%dx%d  gen=%dx%d",
            spr_ref.width, spr_ref.height, spr_gen.width, spr_gen.height))
    end
    if #spr_ref.frames ~= #spr_gen.frames then
        log(string.format("!! FRAME COUNT MISMATCH  ref=%d  gen=%d",
            #spr_ref.frames, #spr_gen.frames))
    end

    -- Layers
    local layers_ref, layer_order = {}, {}
    for _, l in ipairs(spr_ref.layers) do
        layers_ref[l.name] = l
        layer_order[#layer_order + 1] = l.name
    end
    local layers_gen = {}
    for _, l in ipairs(spr_gen.layers) do layers_gen[l.name] = l end

    for n in pairs(layers_ref) do
        if not layers_gen[n] then log("!! Layer '" .. n .. "' only in reference") end
    end
    for n in pairs(layers_gen) do
        if not layers_ref[n] then log("!! Layer '" .. n .. "' only in generated") end
    end

    -- Tags
    local tags_ref, tags_gen = {}, {}
    for _, t in ipairs(spr_ref.tags) do
        tags_ref[t.name] = { from = t.fromFrame.frameNumber, to = t.toFrame.frameNumber }
    end
    for _, t in ipairs(spr_gen.tags) do
        tags_gen[t.name] = { from = t.fromFrame.frameNumber, to = t.toFrame.frameNumber }
    end
    for name, tr in pairs(tags_ref) do
        local tg = tags_gen[name]
        if not tg then
            log(string.format("!! Tag '%s' only in reference (frames %d-%d)", name, tr.from, tr.to))
        elseif tr.from ~= tg.from or tr.to ~= tg.to then
            log(string.format("!! Tag '%s' range differs  ref=%d-%d  gen=%d-%d",
                name, tr.from, tr.to, tg.from, tg.to))
        end
    end
    for name in pairs(tags_gen) do
        if not tags_ref[name] then log("!! Tag '" .. name .. "' only in generated") end
    end

    -- Frame timing
    local min_frames = math.min(#spr_ref.frames, #spr_gen.frames)
    local timing_diffs = {}
    for i = 1, min_frames do
        local dr = spr_ref.frames[i].duration
        local dg = spr_gen.frames[i].duration
        if math.abs(dr - dg) > 0.001 then
            timing_diffs[#timing_diffs + 1] =
                string.format("  Frame %d: gen=%.3fs  ref=%.3fs", i, dg, dr)
        end
    end
    if #timing_diffs > 0 then
        log("Timing differences:")
        for _, s in ipairs(timing_diffs) do log(s) end
    end
    log("")

    -- ── Frame→tag lookup ────────────────────────────────────────────────
    local frame_tag, frame_phase = {}, {}
    for _, t in ipairs(spr_ref.tags) do
        for i = t.fromFrame.frameNumber, t.toFrame.frameNumber do
            frame_tag[i] = t.name
            frame_phase[i] = i - t.fromFrame.frameNumber
        end
    end

    -- ── Pixel comparison ────────────────────────────────────────────────
    local cel_ref = build_cel_map(spr_ref)
    local cel_gen = build_cel_map(spr_gen)

    local w = math.min(spr_ref.width, spr_gen.width)
    local h = math.min(spr_ref.height, spr_gen.height)

    local identical_count, diff_frames = 0, 0
    local action_items = {}

    local common_layers = {}
    for _, name in ipairs(layer_order) do
        if layers_gen[name] then common_layers[#common_layers + 1] = name end
    end

    for _, layer_name in ipairs(common_layers) do
        for fi = 1, min_frames do
            local tag  = frame_tag[fi] or "?"
            local phase = frame_phase[fi] or 0

            local cr = cel_ref[layer_name] and cel_ref[layer_name][fi]
            local cg = cel_gen[layer_name] and cel_gen[layer_name][fi]

            local changed = {}
            for y = 0, h - 1 do
                for x = 0, w - 1 do
                    local pr = pixel_at(cr, x, y)
                    local pg = pixel_at(cg, x, y)
                    if not px_equal(pr, pg) then
                        local ar = app.pixelColor.rgbaA(pr)
                        local ag = app.pixelColor.rgbaA(pg)
                        local ctype
                        if ar > 0 and ag == 0 then ctype = "add"
                        elseif ar == 0 and ag > 0 then ctype = "remove"
                        else ctype = "change" end
                        changed[#changed + 1] = {
                            x = x, y = y, ref = pr, gen = pg, type = ctype
                        }
                    end
                end
            end

            if #changed == 0 then
                identical_count = identical_count + 1
            else
                diff_frames = diff_frames + 1
                local label = string.format("%s | frame %d (%s #%d)", layer_name, fi, tag, phase)
                log(string.format("--- %s --- %d pixels differ", label, #changed))

                -- Bounding box
                local bx1, by1, bx2, by2 = bbox(changed)
                log(string.format("  Bounds: (%d,%d)-(%d,%d)  [%dx%d]",
                    bx1, by1, bx2, by2, bx2 - bx1 + 1, by2 - by1 + 1))

                -- Categorise
                local adds, removes, changes = {}, {}, {}
                for _, p in ipairs(changed) do
                    if p.type == "add" then adds[#adds + 1] = p
                    elseif p.type == "remove" then removes[#removes + 1] = p
                    else changes[#changes + 1] = p end
                end
                if #adds > 0 then log(string.format("  ADD   %d px (code must draw these)", #adds)) end
                if #removes > 0 then log(string.format("  REMOVE %d px (code draws these but shouldn't)", #removes)) end
                if #changes > 0 then log(string.format("  CHANGE %d px (wrong color)", #changes)) end

                -- Color transition summary
                local trans = {}
                for _, p in ipairs(changed) do
                    local key = color_hex(p.gen) .. " → " .. color_hex(p.ref)
                    trans[key] = (trans[key] or 0) + 1
                end
                local sorted = {}
                for k, n in pairs(trans) do sorted[#sorted + 1] = { k = k, n = n } end
                table.sort(sorted, function(a, b) return a.n > b.n end)

                log("  Transitions (generated → reference):")
                for i, t in ipairs(sorted) do
                    if i > 15 then
                        log(string.format("    ... and %d more", #sorted - 15))
                        break
                    end
                    log(string.format("    %s  (%d px)", t.k, t.n))
                end

                -- Cluster analysis
                local clusters = cluster_pixels(changed, w)
                if #clusters > 1 or #changed > 10 then
                    log(string.format("  Clusters: %d regions", #clusters))
                    for ci, cl in ipairs(clusters) do
                        if ci > 15 then
                            log(string.format("    ... and %d more small clusters", #clusters - 15))
                            break
                        end
                        log("    " .. ci .. ". " .. describe_cluster(cl, w))
                    end
                end

                -- Individual pixels (capped at 200)
                if #changed <= 200 then
                    log("  Pixels:")
                    for _, p in ipairs(changed) do
                        log(string.format("    (%2d,%2d) %s → %s  [%s]",
                            p.x, p.y, color_hex(p.gen), color_hex(p.ref), p.type))
                    end
                end

                log("")

                -- Build action item
                for ci, cl in ipairs(clusters) do
                    if ci > 5 then break end
                    local cx1, cy1, cx2, cy2 = bbox(cl)
                    -- Dominant target
                    local tc = {}
                    for _, p in ipairs(cl) do
                        local c = color_hex(p.ref)
                        tc[c] = (tc[c] or 0) + 1
                    end
                    local best_c, best_n = "?", 0
                    for c, n in pairs(tc) do if n > best_n then best_c, best_n = c, n end end

                    local dom_type = cl[1].type
                    for _, p in ipairs(cl) do
                        if p.type ~= dom_type then dom_type = "mixed"; break end
                    end

                    action_items[#action_items + 1] = string.format(
                        "%s frame %d (%s #%d): %s %d px at (%d,%d)-(%d,%d) → %s",
                        layer_name, fi, tag, phase,
                        dom_type:upper(), #cl,
                        cx1, cy1, cx2, cy2, best_c)
                end
            end
        end
    end

    -- ── Summary ─────────────────────────────────────────────────────────
    log("=== SUMMARY ===")
    log(string.format("Identical: %d layer-frames", identical_count))
    log(string.format("Different: %d layer-frames", diff_frames))
    if diff_frames == 0 then
        log("RESULT: Sprites are IDENTICAL")
    end
    log("")

    -- ── Action items ────────────────────────────────────────────────────
    if #action_items > 0 then
        log("=== ACTION ITEMS (what generate.lua must change) ===")
        for i, item in ipairs(action_items) do
            log(string.format("%d. %s", i, item))
        end
        log("")
    end

    -- ── Write ───────────────────────────────────────────────────────────
    local text = table.concat(out, "\n") .. "\n"
    local f = io.open(report_path, "w")
    f:write(text)
    f:close()

    print(text)
    print("Report saved to: " .. report_path)

    spr_ref:close()
    spr_gen:close()
end

return compare
