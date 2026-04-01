# Inventory UI — Design Document

## Overview

The player has two inventory views: a **hotbar** (always visible, 8 slots) and a **full inventory window** (opened with `I`, larger grid). Both share the same underlying slot array. Slots support drag-and-drop, multi-selection, and stack splitting.

---

## Slot Layout

| View            | Slots    | Visible when      |
|-----------------|----------|--------------------|
| Hotbar          | 0–7      | Always             |
| Full inventory  | 0–7 + expansion slots | Press `I`   |

Each slot displays:
- Item color swatch (from ItemDef)
- Quantity badge (bottom-right, hidden when 1)
- Selection highlight (when selected via Ctrl/Shift)
- Active slot ring (hotbar only, for the currently selected slot)

---

## Drag & Drop

### Starting a drag
- One **Left-click** - take an item to the hand, released on subsequent left-click
- **Left-click and hold** on a non-empty slot to begin dragging.
- A ghost of the item follows the cursor with 75% opacity.
- The source slot dims while dragging.
- If multiple slots are selected (via Ctrl/Shift), dragging any one of them drags the **entire selection** as a group, preserving its shape.

### Drop targets

| Drop onto              | Result                                                  |
|------------------------|---------------------------------------------------------|
| Empty slot             | Move item(s) to that slot                               |
| Same-type occupied slot| Merge stacks up to stack limit; overflow stays in hand  |
| Different-type slot    | Swap the two slots (single drag only, not multi)        |
| Outside inventory      | Drop as ground item at where the cursor was, but max distance is 1.5 tiles    |
| Building input (world) | Insert into building if it accepts that item type       |
| Conveyor tile (world)  | Place on conveyor if it has space                       |

### Right-click drag (stack splitting)

- **Right-click and hold** on a stack: pick up **half** (rounded up).
- The remaining half stays in the source slot.
- While holding a right-click drag, **right-click** an empty slot to deposit **one item** into it (like Minecraft).
- Release to place the held portion.

---

## Selection

### Ctrl+Click (toggle individual)

- `Ctrl+Click` a slot to **toggle** its selection state.
- Multiple non-adjacent slots can be selected this way.
- Clicking without Ctrl clears all selections and selects only the clicked slot.

### Shift+Click (range select)

- `Shift+Click` selects a **contiguous range** from the last-clicked slot to the current one.
- The range is based on slot index order (left-to-right, top-to-bottom).
- If no previous click exists, treat as regular click.

### Selection visuals

- Selected slots have a bright border (distinct from the hotbar active ring).
- Selection persists until explicitly cleared (click empty area, press Esc, or close inventory).

---

## Multi-Item Operations

### Dragging a selection

- When dragging with multiple slots selected, all selected items move together.
- Drop onto empty area: items fill consecutive empty slots starting from the drop target.
- Drop outside inventory: all selected items drop as individual ground item stacks.
- If there aren't enough empty slots for the whole selection, as many as possible are placed; the rest return to their original slots.
- Multi-drag onto an occupied slot is not allowed (only single-item drag can swap).

### Quick actions on selection

| Action            | Key          | Effect                                              |
|-------------------|--------------|-----------------------------------------------------|
| Drop selection    | Q            | Drop all selected items as ground items              |
| Move to building  | Shift+Click building slot | Transfer selected items to building |

---

## Hotbar Integration

- The hotbar slots (0–7) are the same data as the first row of the full inventory.
- `1`–`8` keys select the active hotbar slot (for drop/place actions with Q).
- Mouse scroll cycles the active slot.
- Dragging between hotbar and full inventory moves items between those slots.
- Ctrl/Shift selection works on hotbar slots too, but only when the full inventory is open.

---

## Full Inventory Window

- Opened with `I`, closed with `I` or `Esc`.
- Centered on screen, semi-transparent background.
- Shows all slots in a grid (e.g., 8 columns).
- Pauses building mode while open (no placement through the inventory).
- Mouse is captured by the inventory — clicks don't interact with the world behind it.

### Layout

```
+------------------------------------------+
|  Inventory                          [X]  |
+------------------------------------------+
|  [s0] [s1] [s2] [s3] [s4] [s5] [s6] [s7]|  <- hotbar row
|  [s8] [s9] [s10] ...                     |  <- expansion (future)
+------------------------------------------+
```

---

## Edge Cases

- **Dragging onto self**: no-op, item returns to its slot.
- **Drag cancelled** (Esc or right-click while left-dragging): item returns to source.
- **Stack overflow on merge**: excess stays attached to cursor as a continued drag.
- **Empty drag source**: if the source slot becomes empty mid-drag (e.g., another system removes it), cancel the drag silently.
- **Inventory closed while dragging**: item returns to source slot.

---

## Key Bindings Summary

| Key              | Context              | Action                                 |
|------------------|----------------------|----------------------------------------|
| Left-click+drag  | Slot                 | Drag item/selection                    |
| Right-click+drag | Slot                 | Pick up half stack, deposit one-by-one |
| Ctrl+Click       | Slot                 | Toggle selection                       |
| Shift+Click      | Slot                 | Range select                           |
| Click            | Slot (no modifier)   | Clear selection, select this slot      |
| Q                | Any (items selected) | Drop selected items                    |
| I                | Any                  | Toggle full inventory window           |
| Esc              | Inventory open       | Close inventory / cancel drag          |
| 1–8              | Any                  | Select hotbar slot                     |
| Scroll           | Any                  | Cycle hotbar slot                      |
