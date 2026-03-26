-- Shared color palette for factory buildings.
-- Usage: local C = H.load_palette("buildings")
--
-- Naming convention:
--   base_*    — structural body colors (walls, panels)
--   metal_*   — metallic accents (rivets, pipes, flanges)
--   dark_*    — shadows, outlines, deep interiors
--   fire_*    — combustion / heat (burner, smelter)
--   energy_*  — electricity / energy indicators
--   smoke_*   — smoke, steam, exhaust
--   ore_*     — raw resource tints

return {
  -- Structure
  outline       = "#191412",
  body          = "#46372D",
  body_light    = "#524134",
  panel         = "#3C2D26",
  panel_inner   = "#32261E",
  shadow        = "#231C16",

  -- Metal / accents
  rivet         = "#5A4B3C",
  rim           = "#4B3C32",
  flange        = "#413428",
  pipe          = "#372A23",
  pipe_inner    = "#30241C",

  -- Dark / interior
  chamber       = "#160F0C",
  chamber_deep  = "#0F0A08",
  bore          = "#140F0C",
  bore_deep     = "#0C0806",
  intake        = "#231C16",
  intake_dark   = "#1C140F",
  soot          = "#1E1814",

  -- Fire / heat
  fire_dim      = "#8C320A",
  fire_outer    = "#B4460F",
  fire_mid      = "#DC6E14",
  fire_inner    = "#F5A01E",
  fire_core     = "#FFD23C",
  fire_hot      = "#FFF082",
  ember         = "#78280A",
  glow_wall     = "#5A230C",
  pipe_warm     = "#502814",
  pipe_hot      = "#643212",

  -- Energy
  bolt_dim      = "#FFDC3264",  -- with alpha
  bolt_bright   = "#FFDC32DC",
  energy_low    = "#FFD23264",
  energy_high   = "#FFD232FF",

  -- Smoke / steam
  smoke_dark    = "#7878788C",
  smoke_mid     = "#82828264",
  smoke_light   = "#8C8C8C50",

  -- Grate / bars
  grate         = "#372319",

  -- Conveyor (extracted from conveyor spritesheet)
  conv_dark     = "#3C3C42",  -- darkest belt surface
  conv_base     = "#3D3D43",  -- primary belt color
  conv_mid      = "#505256",  -- belt mid-tone
  conv_groove   = "#5A5C62",  -- belt groove / track lines
  conv_light    = "#6C6D6F",  -- belt highlight
  conv_accent   = "#B59C18",  -- yellow accent (dark)
  conv_yellow   = "#D2B937",  -- yellow accent (bright, arrows/markers)

  -- Ore tints (for drill, resource indicators)
  iron_ore      = "#8B6850",
  copper_ore    = "#B87333",
  coal          = "#2A2420",

  -- Status indicators
  active_green  = "#4CAF50",
  idle_gray     = "#606060",
  warning_red   = "#D32F2F",
}
