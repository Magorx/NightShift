#!/usr/bin/env python3
"""Generate 32x32 conveyor belt sprite sheets for Factor.

All sprites face RIGHT by default. Godot handles rotation.
Each sprite sheet is 4 frames wide (128x32) for belt animation.

Output directory: resources/sprites/conveyors/

Variants:
  - straight.png        : straight belt, flow left→right
  - turn.png            : 90° turn, flow bottom→right (L-shape)
  - side_input.png      : straight belt + one side input from bottom
  - dual_side_input.png : two side inputs (from top and bottom), exit right
"""

from PIL import Image, ImageDraw
import os
import math

TILE = 32
FRAMES = 4
SHEET_W = TILE * FRAMES
SHEET_H = TILE

# ── Color palette ──────────────────────────────────────────
TRANSPARENT = (0, 0, 0, 0)
RAIL        = (60, 62, 68, 255)       # dark steel rails
RAIL_EDGE   = (45, 46, 52, 255)       # outer rail edge (darkest)
RAIL_HI     = (90, 92, 98, 255)       # inner rail highlight
BELT        = (42, 42, 48, 255)       # dark belt base
BELT_MID    = (52, 52, 58, 255)       # belt midtone
BELT_HI     = (62, 62, 68, 255)       # belt highlight
ARROW       = (210, 185, 55, 255)     # bright gold arrows
ARROW_DIM   = (160, 140, 40, 255)     # secondary arrow shade

RAIL_W = 3  # rail thickness


def new_sheet():
    return Image.new("RGBA", (SHEET_W, SHEET_H), TRANSPARENT)


def lerp_color(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def put(draw, x, y, color):
    """Safe pixel draw."""
    if 0 <= x < SHEET_W and 0 <= y < SHEET_H:
        draw.point((x, y), fill=color)


def draw_hline(draw, x1, x2, y, color):
    for x in range(x1, x2 + 1):
        put(draw, x, y, color)


def draw_vline(draw, x, y1, y2, color):
    for y in range(y1, y2 + 1):
        put(draw, x, y, color)


# ── Rail drawing helpers ───────────────────────────────────

def draw_top_rail(draw, fx, x_start=0, x_end=None):
    """Horizontal rail at top of tile."""
    if x_end is None:
        x_end = TILE - 1
    draw_hline(draw, fx + x_start, fx + x_end, 0, RAIL_EDGE)
    draw_hline(draw, fx + x_start, fx + x_end, 1, RAIL)
    draw_hline(draw, fx + x_start, fx + x_end, 2, RAIL_HI)


def draw_bot_rail(draw, fx, x_start=0, x_end=None):
    """Horizontal rail at bottom of tile."""
    if x_end is None:
        x_end = TILE - 1
    draw_hline(draw, fx + x_start, fx + x_end, TILE - 3, RAIL_HI)
    draw_hline(draw, fx + x_start, fx + x_end, TILE - 2, RAIL)
    draw_hline(draw, fx + x_start, fx + x_end, TILE - 1, RAIL_EDGE)


def draw_left_rail(draw, fx, y_start=0, y_end=None):
    """Vertical rail at left of tile."""
    if y_end is None:
        y_end = TILE - 1
    draw_vline(draw, fx + 0, y_start, y_end, RAIL_EDGE)
    draw_vline(draw, fx + 1, y_start, y_end, RAIL)
    draw_vline(draw, fx + 2, y_start, y_end, RAIL_HI)


def draw_right_rail(draw, fx, y_start=0, y_end=None):
    """Vertical rail at right of tile."""
    if y_end is None:
        y_end = TILE - 1
    draw_vline(draw, fx + TILE - 3, y_start, y_end, RAIL_HI)
    draw_vline(draw, fx + TILE - 2, y_start, y_end, RAIL)
    draw_vline(draw, fx + TILE - 1, y_start, y_end, RAIL_EDGE)


def fill_belt_h(draw, fx, y1, y2, x1=0, x2=None):
    """Fill horizontal belt area with subtle gradient."""
    if x2 is None:
        x2 = TILE - 1
    h = y2 - y1
    for y in range(y1, y2 + 1):
        t = (y - y1) / max(1, h)
        # Darker at edges, lighter in middle
        brightness = 0.5 + 0.5 * math.sin(t * math.pi)
        c = lerp_color(BELT, BELT_HI, brightness)
        draw_hline(draw, fx + x1, fx + x2, y, c)


def fill_belt_v(draw, fx, x1, x2, y1=0, y2=None):
    """Fill vertical belt area with subtle gradient."""
    if y2 is None:
        y2 = TILE - 1
    w = x2 - x1
    for x_local in range(x1, x2 + 1):
        t = (x_local - x1) / max(1, w)
        brightness = 0.5 + 0.5 * math.sin(t * math.pi)
        c = lerp_color(BELT, BELT_HI, brightness)
        draw_vline(draw, fx + x_local, y1, y2, c)


# ── Chevron / arrow drawing ───────────────────────────────

def draw_chevron_right(draw, cx, cy, color=None):
    """5px tall right-pointing chevron at (cx, cy)."""
    if color is None:
        color = ARROW
    pixels = [
        (0, -2), (0, -1), (0, 0), (0, 1), (0, 2),
        (1, -1), (1, 0), (1, 1),
        (2, 0),
    ]
    for ox, oy in pixels:
        put(draw, cx + ox, cy + oy, color)


def draw_chevron_down(draw, cx, cy, color=None):
    if color is None:
        color = ARROW
    pixels = [
        (-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0),
        (-1, 1), (0, 1), (1, 1),
        (0, 2),
    ]
    for ox, oy in pixels:
        put(draw, cx + ox, cy + oy, color)


def draw_chevron_up(draw, cx, cy, color=None):
    if color is None:
        color = ARROW
    pixels = [
        (-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0),
        (-1, -1), (0, -1), (1, -1),
        (0, -2),
    ]
    for ox, oy in pixels:
        put(draw, cx + ox, cy + oy, color)


# ── Sprite generators ─────────────────────────────────────

def gen_straight():
    img = new_sheet()
    draw = ImageDraw.Draw(img)

    for f in range(FRAMES):
        fx = f * TILE

        # Rails
        draw_top_rail(draw, fx)
        draw_bot_rail(draw, fx)

        # Belt surface
        fill_belt_h(draw, fx, RAIL_W, TILE - RAIL_W - 1)

        # Two rows of animated chevrons
        anim_offset = f * (TILE // FRAMES)
        for row_y in [TILE // 2 - 5, TILE // 2 + 5]:
            for base_x in range(3, TILE + 12, 12):
                cx = (base_x + anim_offset) % TILE
                if 2 <= cx <= TILE - 4:
                    draw_chevron_right(draw, fx + cx, row_y)

        # Center line dashes for extra motion feel
        cy = TILE // 2
        for base_x in range(0, TILE + 8, 8):
            sx = (base_x + anim_offset) % TILE
            if 1 <= sx <= TILE - 3:
                draw_hline(draw, fx + sx, fx + sx + 2, cy, ARROW_DIM)

    return img


def gen_turn():
    """90° turn: flow enters from BOTTOM, exits RIGHT."""
    img = new_sheet()
    draw = ImageDraw.Draw(img)

    inner_r = RAIL_W + 1
    outer_r = TILE - RAIL_W - 1
    # Pivot at top-left corner of tile

    for f in range(FRAMES):
        fx = f * TILE

        # Draw curved belt by scanning pixels
        for py in range(TILE):
            for px_local in range(TILE):
                dist = math.sqrt(px_local ** 2 + py ** 2)
                if inner_r < dist < outer_r:
                    # Belt surface with radial gradient
                    t = (dist - inner_r) / (outer_r - inner_r)
                    brightness = 0.5 + 0.5 * math.sin(t * math.pi)
                    c = lerp_color(BELT, BELT_HI, brightness)
                    put(draw, fx + px_local, py, c)

        # Inner rail (curved)
        for py in range(TILE):
            for px_local in range(TILE):
                dist = math.sqrt(px_local ** 2 + py ** 2)
                if abs(dist - inner_r) < 1.2:
                    put(draw, fx + px_local, py, RAIL_HI)
                if abs(dist - (inner_r - 1)) < 0.8:
                    put(draw, fx + px_local, py, RAIL)

        # Outer rail (curved)
        for py in range(TILE):
            for px_local in range(TILE):
                dist = math.sqrt(px_local ** 2 + py ** 2)
                if abs(dist - outer_r) < 1.2:
                    put(draw, fx + px_local, py, RAIL_HI)
                if abs(dist - (outer_r + 1)) < 0.8:
                    put(draw, fx + px_local, py, RAIL)
                if abs(dist - (outer_r + 2)) < 0.8:
                    put(draw, fx + px_local, py, RAIL_EDGE)

        # Animated chevrons along the curve
        mid_r = (inner_r + outer_r) / 2
        anim_t = f / FRAMES
        num_arrows = 4
        for i in range(num_arrows):
            t = (i / num_arrows + anim_t) % 1.0
            # Angle sweeps from π/2 (bottom) to 0 (right)
            angle = math.pi / 2 * (1.0 - t)
            ax = int(mid_r * math.cos(angle))
            ay = int(mid_r * math.sin(angle))

            if 2 <= ax < TILE - 2 and 2 <= ay < TILE - 2:
                # Direction tangent to curve at this point
                tan_angle = angle - math.pi / 2  # tangent direction
                dx = math.cos(tan_angle)
                dy = math.sin(tan_angle)

                # Draw a small oriented arrow (3-pixel dot cluster)
                px = fx + ax
                py_c = ay
                for ddx in range(-1, 2):
                    for ddy in range(-1, 2):
                        if abs(ddx) + abs(ddy) <= 1:
                            put(draw, px + ddx, py_c + ddy, ARROW)

    return img


def gen_side_input():
    """Straight belt (left→right) with one side input from bottom."""
    img = new_sheet()
    draw = ImageDraw.Draw(img)

    # Side input gap parameters
    gap_left = 11  # local x where gap starts
    gap_right = 20  # local x where gap ends
    gap_mid = (gap_left + gap_right) // 2

    for f in range(FRAMES):
        fx = f * TILE

        # Top rail (full)
        draw_top_rail(draw, fx)

        # Bottom rail with gap
        draw_bot_rail(draw, fx, 0, gap_left - 1)
        draw_bot_rail(draw, fx, gap_right + 1, TILE - 1)

        # Main belt surface
        fill_belt_h(draw, fx, RAIL_W, TILE - RAIL_W - 1)

        # Side input channel (vertical, from bottom edge up to belt)
        # Vertical rails on sides of the gap
        draw_vline(draw, fx + gap_left, TILE - RAIL_W, TILE - 1, RAIL)
        draw_vline(draw, fx + gap_right, TILE - RAIL_W, TILE - 1, RAIL)
        # Belt fill in gap
        fill_belt_v(draw, fx, gap_left + 1, gap_right - 1, TILE - RAIL_W, TILE - 1)

        # Main horizontal chevrons
        anim_offset = f * (TILE // FRAMES)
        for row_y in [TILE // 2 - 5, TILE // 2 + 5]:
            for base_x in range(3, TILE + 12, 12):
                cx = (base_x + anim_offset) % TILE
                if 2 <= cx <= TILE - 4:
                    draw_chevron_right(draw, fx + cx, row_y)

        # Center dashes
        cy = TILE // 2
        for base_x in range(0, TILE + 8, 8):
            sx = (base_x + anim_offset) % TILE
            if 1 <= sx <= TILE - 3:
                draw_hline(draw, fx + sx, fx + sx + 2, cy, ARROW_DIM)

        # Small up-arrow in the side input channel
        side_anim = f / FRAMES
        for i in range(1):
            t = (i + side_anim) % 1.0
            cy_arrow = int(TILE - 1 - t * RAIL_W)
            if TILE - RAIL_W <= cy_arrow < TILE:
                # Tiny 3px arrow pointing up
                put(draw, fx + gap_mid, cy_arrow - 1, ARROW)
                put(draw, fx + gap_mid - 1, cy_arrow, ARROW)
                put(draw, fx + gap_mid, cy_arrow, ARROW)
                put(draw, fx + gap_mid + 1, cy_arrow, ARROW)

    return img


def gen_dual_side_input():
    """Two side inputs (top and bottom) merging and exiting right.
    No straight-through input from the left."""
    img = new_sheet()
    draw = ImageDraw.Draw(img)

    # Layout: vertical channels from top and bottom feed into a horizontal exit right
    ch_left = 10   # channel left edge (local x)
    ch_right = 21  # channel right edge
    ch_mid = (ch_left + ch_right) // 2
    exit_top = TILE // 2 - 5
    exit_bot = TILE // 2 + 4

    for f in range(FRAMES):
        fx = f * TILE

        # ── Top input channel ──
        # Vertical rails
        draw_vline(draw, fx + ch_left, 0, exit_top - 1, RAIL_EDGE)
        draw_vline(draw, fx + ch_left + 1, 0, exit_top - 1, RAIL)
        draw_vline(draw, fx + ch_left + 2, 0, exit_top - 1, RAIL_HI)
        draw_vline(draw, fx + ch_right, 0, exit_top - 1, RAIL_EDGE)
        draw_vline(draw, fx + ch_right - 1, 0, exit_top - 1, RAIL)
        draw_vline(draw, fx + ch_right - 2, 0, exit_top - 1, RAIL_HI)
        # Belt fill
        fill_belt_v(draw, fx, ch_left + RAIL_W, ch_right - RAIL_W, 0, exit_top - 1)

        # ── Bottom input channel ──
        draw_vline(draw, fx + ch_left, exit_bot + 1, TILE - 1, RAIL_EDGE)
        draw_vline(draw, fx + ch_left + 1, exit_bot + 1, TILE - 1, RAIL)
        draw_vline(draw, fx + ch_left + 2, exit_bot + 1, TILE - 1, RAIL_HI)
        draw_vline(draw, fx + ch_right, exit_bot + 1, TILE - 1, RAIL_EDGE)
        draw_vline(draw, fx + ch_right - 1, exit_bot + 1, TILE - 1, RAIL)
        draw_vline(draw, fx + ch_right - 2, exit_bot + 1, TILE - 1, RAIL_HI)
        fill_belt_v(draw, fx, ch_left + RAIL_W, ch_right - RAIL_W, exit_bot + 1, TILE - 1)

        # ── Horizontal exit channel (center to right edge) ──
        # Top rail of exit
        draw_hline(draw, fx + ch_left, fx + TILE - 1, exit_top - 1, RAIL_HI)
        draw_hline(draw, fx + ch_left, fx + TILE - 1, exit_top - 2, RAIL)
        draw_hline(draw, fx + ch_left, fx + TILE - 1, exit_top - 3, RAIL_EDGE)
        # Bottom rail of exit
        draw_hline(draw, fx + ch_left, fx + TILE - 1, exit_bot + 1, RAIL_HI)
        draw_hline(draw, fx + ch_left, fx + TILE - 1, exit_bot + 2, RAIL)
        draw_hline(draw, fx + ch_left, fx + TILE - 1, exit_bot + 3, RAIL_EDGE)
        # Belt fill
        fill_belt_h(draw, fx, exit_top, exit_bot, ch_left, TILE - 1)

        # ── Left wall (block left entry) ──
        draw_vline(draw, fx + ch_left, exit_top - 3, exit_bot + 3, RAIL_EDGE)
        draw_vline(draw, fx + ch_left + 1, exit_top, exit_bot, RAIL)

        # ── Merge junction corners ──
        # Small corner fills where channels meet the exit
        for y in range(exit_top, exit_bot + 1):
            for x_local in range(ch_left + 2, ch_right - 1):
                put(draw, fx + x_local, y, BELT_MID)

        # ── Animated arrows ──
        anim_offset = f * (TILE // FRAMES)

        # Right arrows in exit channel
        exit_cy = TILE // 2
        for base_x in range(ch_right + 2, TILE + 12, 10):
            cx = ch_right + 2 + (base_x - ch_right - 2 + anim_offset) % (TILE - ch_right - 2)
            if ch_right + 2 <= cx <= TILE - 4:
                draw_chevron_right(draw, fx + cx, exit_cy)

        # Down arrows in top channel
        anim_t = f / FRAMES
        for i in range(2):
            t = (i / 2 + anim_t) % 1.0
            cy = int(1 + t * (exit_top - 4))
            if 3 <= cy <= exit_top - 3:
                draw_chevron_down(draw, fx + ch_mid, cy)

        # Up arrows in bottom channel
        for i in range(2):
            t = (i / 2 + anim_t) % 1.0
            cy = int(TILE - 2 - t * (TILE - exit_bot - 4))
            if exit_bot + 3 <= cy <= TILE - 3:
                draw_chevron_up(draw, fx + ch_mid, cy)

    return img


# ── Main ───────────────────────────────────────────────────
def main():
    out_dir = os.path.join(os.path.dirname(__file__), "..", "resources", "sprites", "conveyors")
    os.makedirs(out_dir, exist_ok=True)

    sprites = {
        "straight": gen_straight(),
        "turn": gen_turn(),
        "side_input": gen_side_input(),
        "dual_side_input": gen_dual_side_input(),
    }

    for name, img in sprites.items():
        path = os.path.join(out_dir, f"{name}.png")
        img.save(path)
        print(f"  Saved {path}")

    print(f"\nAll conveyor sprites saved to {out_dir}/")
    print(f"Each is {SHEET_W}x{SHEET_H} (4 frames of {TILE}x{TILE})")


if __name__ == "__main__":
    main()
