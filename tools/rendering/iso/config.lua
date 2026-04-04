-- config.lua — Isometric projection configuration
--
-- Projection matrix: 3D model coords → 2D screen coords
--   screen_x = x * XX + y * YX + z * ZX
--   screen_y = x * XY + y * YY + z * ZY
--
-- The 6 values (XX,XY, YX,YY, ZX,ZY) define 3 column vectors — the screen-space
-- direction of each model axis.  Everything else derives from these.
--
-- Model space convention:
--   +X = "east"  (right on screen in standard iso)
--   +Y = "south" (left on screen in standard iso, into the scene)
--   +Z = "up"    (straight up on screen)

local Iso = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- PROJECTION MATRIX (editable — everything recomputes from these)
-- ═══════════════════════════════════════════════════════════════════════════

-- Default: 2:1 dimetric (standard pixel-art isometric)
-- Each model unit maps to these screen pixel offsets:
Iso.XX =  1      Iso.XY =  0.5    -- X axis: 1 right, 0.5 down
Iso.YX = -1      Iso.YY =  0.5    -- Y axis: 1 left,  0.5 down
Iso.ZX =  0      Iso.ZY = -1      -- Z axis: 0 horiz, 1 up

-- ═══════════════════════════════════════════════════════════════════════════
-- DERIVED VALUES (recomputed by _update)
-- ═══════════════════════════════════════════════════════════════════════════

Iso._det = 1        -- determinant of [[XX,YX],[XY,YY]]
Iso._vx  = 1        -- view direction (null-space of projection)
Iso._vy  = 1
Iso._vz  = 1

--- Recompute derived values from the current matrix.  Called automatically.
function Iso._update()
  Iso._det = Iso.XX * Iso.YY - Iso.YX * Iso.XY
  assert(math.abs(Iso._det) > 1e-9, "Degenerate projection matrix (det ≈ 0)")
  -- View direction: cross product of the two row-vectors of the 2×3 matrix
  Iso._vx = Iso.YX * Iso.ZY - Iso.ZX * Iso.YY
  Iso._vy = Iso.ZX * Iso.XY - Iso.XX * Iso.ZY
  Iso._vz = Iso.XX * Iso.YY - Iso.YX * Iso.XY  -- = _det
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIGURATION API
-- ═══════════════════════════════════════════════════════════════════════════

--- Set projection from intuitive parameters.
-- @param opts.tile_ratio  Width / height of diamond tile (2 = standard, 3 = flat, 1 = steep)
-- @param opts.z_scale     Screen pixels per model-unit of height (default 1)
-- @param opts.scale       Overall multiplier (default 1)
-- Or set raw matrix columns:
-- @param opts.XX,XY,YX,YY,ZX,ZY  Raw projection values
function Iso.configure(opts)
  if opts.tile_ratio then
    local r  = opts.tile_ratio
    local zs = opts.z_scale or 1
    local s  = opts.scale or 1
    Iso.XX =  s       Iso.XY = s / r
    Iso.YX = -s       Iso.YY = s / r
    Iso.ZX =  0       Iso.ZY = -zs * s
  end
  -- Raw overrides (applied after ratio, so you can tweak)
  if opts.XX then Iso.XX = opts.XX end
  if opts.XY then Iso.XY = opts.XY end
  if opts.YX then Iso.YX = opts.YX end
  if opts.YY then Iso.YY = opts.YY end
  if opts.ZX then Iso.ZX = opts.ZX end
  if opts.ZY then Iso.ZY = opts.ZY end
  Iso._update()
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PRESETS
-- ═══════════════════════════════════════════════════════════════════════════

--- Standard 2:1 dimetric (64×32 diamonds) — Factorio / RPG Maker style
function Iso.preset_2_1()
  Iso.configure({ tile_ratio = 2, z_scale = 1 })
end

--- True isometric (≈30°, ratio ≈ 1.732) — classic arcade/board game look
function Iso.preset_true_iso()
  Iso.configure({ tile_ratio = 1.732, z_scale = 1 })
end

--- Steep isometric (1:1 diamonds, 45° angle)
function Iso.preset_steep()
  Iso.configure({ tile_ratio = 1, z_scale = 1 })
end

--- Flat / cavalier (3:1 diamonds, shallow angle)
function Iso.preset_flat()
  Iso.configure({ tile_ratio = 3, z_scale = 1 })
end

--- Military / top-down oblique (no vertical foreshortening)
function Iso.preset_military()
  Iso.configure({ XX = 1, XY = 0, YX = 0, YY = 1, ZX = 0, ZY = -1 })
end

-- Initialize derived values
Iso._update()

return Iso
