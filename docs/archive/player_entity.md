# Player Entity — Design Document

## Overview

The player is a physical entity that exists in the game world alongside buildings and conveyors. Rather than an omniscient cursor, the player is a small character that walks around the factory, interacts with buildings at close range, and is subject to the world's physics — including being carried by conveyors and blocked by structures.

---

## Movement

### Walking

| Parameter        | Value         | Notes                                   |
|-----------------|---------------|-----------------------------------------|
| Base move speed  | 3 tiles/s     | ~96 px/s at 32px tiles                  |
| Sprint speed     | 5 tiles/s     | Hold shift, drains stamina              |
| Stamina pool     | 3 seconds     | Regenerates at 1s/s when not sprinting  |
| Acceleration     | 20 tiles/s^2  | Near-instant response, snappy feel      |
| Friction         | 15 tiles/s^2  | Quick stop, slight slide                |

- Input: WASD or arrow keys, 8-directional movement
- The player is a `CharacterBody2D` with a small circular collision shape (~12px radius, fits within a single tile)
- Movement uses `move_and_slide()` for smooth collision response

### Jumping

The player can jump to get on top of buildings. While on top, the player walks freely over buildings without collision. Jump is a vertical state change, not a physics arc — the camera stays top-down.

| Parameter       | Value      | Notes                                    |
|----------------|------------|------------------------------------------|
| Jump duration   | 0.3s       | Time to land after pressing jump         |
| Jump cooldown   | 0.1s       | Prevents spam                            |
| Jump key        | Space      |                                          |

**State machine:**

```
GROUNDED  --[press Space]--> JUMPING (0.3s airborne) --> ELEVATED
ELEVATED  --[moving from the building to an empty space or conveyor or some other ground-level construct]--> DROPPING (0.3s airborne) --> GROUNDED
```

- **GROUNDED** — normal movement, blocked by buildings, affected by conveyors
- **JUMPING** — brief transition, no collision with buildings, not affected by conveyors
- **ELEVATED** — walking on top of buildings, no collision with buildings, not affected by conveyors, can interact with buildings, slight visual offset/shadow to indicate height
- **DROPPING** — brief transition back down, same rules as JUMPING

When ELEVATED:
- The player sprite renders above building sprites (higher z-index than the building top)
- A small drop shadow renders beneath the player to convey height
- If the player drops onto a conveyor, they resume being transported

### Conveyor Interaction

When the player stands on a conveyor tile while GROUNDED, the conveyor pushes the player in its direction. The player can walk against the conveyor but is slowed.

| Conveyor Tier | Push speed (tiles/s) | Player effective speed (walking against) |
|--------------|---------------------|------------------------------------------|
| Basic        | 1                   | 3 - 1 = 2 tiles/s                       |
| Fast         | 2                   | 3 - 2 = 1 tiles/s                       |
| Express      | 4                   | 3 - 4 = -1 tiles/s (pushed backward)    |

- Conveyor push is applied as an additive velocity each physics frame
- The player can walk perpendicular to the conveyor at full speed (only the conveyor-direction component is affected)
- If the player is idle on a conveyor, they are transported exactly with an item speed
- Express conveyors can overpower the player — the player must jump to cross them
- Conveyor push only applies in GROUNDED state

(As there is only the basic conveyor for now, make the push speed being a variable there)

### Building Collision

Buildings act as solid obstacles while the player is GROUNDED.

- Each placed building registers its occupied tiles as collision (tilemap collision for efficiency, I presume)
- The player slides along building edges via `move_and_slide()`
- Conveyors, junctions, do **not** block movement — the player walks over them (they are floor-level). If the building is ground-level or not is decided as a flag in it
- Multi-tile buildings (smelters, assemblers, etc.) block movement — the player must jump to cross them
- Buildings under construction (ghost/preview) have no collision

**Collision categories:**

| Building           | Blocks player? | Notes                          |
|-------------------|----------------|--------------------------------|
| Conveyor          | No             | Floor-level, pushes player     |
| Splitter          | No             | Floor-level                    |
| Junction          | No             | Floor-level                    |
| Tunnel entrance   | No             | Floor-level                    |
| Drill             | Yes            | 2x2, must jump over           |
| Smelter           | Yes            | 2x2, must jump over           |
| Assembler         | Yes            | 3x3, must jump over           |
| Chemical Plant    | Yes            | 3x3, must jump over           |
| Advanced Factory  | Yes            | 4x4, must jump over           |
| Sink              | Yes            | Must jump over                 |

---

## Health

The player has a health pool. Damage comes from environmental hazards and hostile entities (future expansion). There is no combat system initially — health exists to create risk and consequence.

| Parameter          | Value      | Notes                                     |
|-------------------|------------|-------------------------------------------|
| Max HP             | 100        |                                           |
| Natural regen      | 2 HP/s     | Starts after 5s without taking damage     |
| Regen delay        | 5s         | Timer resets on any damage                |
| Respawn time       | 3s         | Fade to black, respawn at nearest hub     |
| Death penalty      | Drop inventory | Items scatter on the ground nearby     |

### Damage Sources

None for now

### Death & Respawn

- On death: the player's inventory contents drop as item entities at the death location
- The screen fades to black over 1s, then the player respawns at the nearest hub building (or map spawn point if no hub exists)
- Dropped items persist for 120s before despawning
- The player is invulnerable for 2s after respawning (visual flicker to indicate)

---

## Inventory

The player carries a personal inventory for manually transporting items, bootstrapping new factory sections, and clearing jammed conveyors.

### Capacity

| Parameter          | Value       | Notes                                   |
|-------------------|-------------|-----------------------------------------|
| Inventory slots    | 8           | Unlockable to 12 via tech tree          |
| Stack size per slot| 16          | Matches item stack size definitions     |
| Pickup range       | 1.5 tiles   | Centered on player position             |
| Drop range         | 1 tile      | Drops in front of the player            |

### Picking Up Items

- **From conveyors:** Walk over or near an item on a conveyor and press `E` to grab it. The item is removed from the conveyor's buffer and placed in the first available inventory slot.
- **From the ground:** Loose items (dropped on death, ejected from full buildings) can be picked up the same way.
- **From buildings:** Open a building's info panel (click or `E` at close range) and click items in its inventory/buffer to transfer them to the player's inventory.
- **Auto-pickup:** Items dropped by the player (from death) have a 1s pickup immunity to prevent instant re-grab. No other auto-pickup — the player must press `E`.

### Dropping / Placing Items

- Press `Q` to drop the currently selected inventory item in front of the player as a loose ground item
- Hold lmb and drag item from the inventory. If the drag ends in an empty cell - drop it loose. If the inventory/buffer of the building under the dropping cell can accept some of the items dragged - they are going there, the rest is loose.
- Loose items should be stacks - several item icons, with exact number of them shown if the mouse is hovered on them

### Inventory UI

- Hotbar at the bottom of the screen showing all inventory slots (similar to Minecraft/Terraria)
- Number keys `1`-`8` to select active slot
- Mouse scroll to cycle active slot
- Each slot shows: item icon, quantity badge, highlight ring on selected slot
- Empty slots are dimly outlined
- When inventory is full and the player tries to pick up, show a brief "Inventory Full" toast message

### Inventory Interactions Summary

| Action               | Key       | Context                          | Effect                              |
|---------------------|-----------|----------------------------------|-------------------------------------|
| Pick up item         | E         | Near loose item / conveyor item  | Item moves to first empty slot      |
| Select slot          | 1-8       | Any time                         | Selects active inventory slot       |
| Cycle slot           | Scroll    | Any time                         | Next/prev slot                      |
| Transfer from building| Shift+Click| Building info panel open        | Item moves to player inventory      |
| Open whole inventory | I | inventory window | will be designed later |

---

## Visual Representation

- The player is a **16x16 pixel** character sprite centered within the 32x32 tile grid
- Simple geometric design consistent with the game's flat/low-poly style: a colored square body with a directional triangle indicator (shows facing direction)
- 4 directional sprite frames (or a single sprite that rotates)
- Walk animation: 2-frame bob cycle
- Jump: slight scale-up (1.2x) during airborne states + drop shadow appears below
- Elevated: sustained 1.1x scale + persistent shadow
- Damage flash: sprite flickers white for 0.1s on hit
- Death: sprite shrinks to 0 over 0.5s
- Respawn invulnerability: sprite flickers (toggle visibility every 0.1s)

### Z-Ordering

| State      | Z-Index | Renders...                          |
|-----------|---------|-------------------------------------|
| GROUNDED  | 5       | Above conveyors, below buildings    |
| JUMPING   | 15      | Above everything                    |
| ELEVATED  | 15      | Above everything                    |
| DROPPING  | 15      | Above everything                    |

---

## Interaction Range

The player must be physically close to buildings to interact with them. This creates meaningful traversal within the factory.

| Action                  | Range       | Notes                              |
|------------------------|-------------|------------------------------------|
| Build / place building  | 4 tiles     | Can place buildings nearby         |
| Destroy building        | 4 tiles     | Must be close to demolish          |
| Open building info      | 4 tiles     | Click or E on nearby building      |
| Pick up item            | 1.5 tiles   | Very close proximity               |
| Drop / insert item      | 1.5 tile      | Directly adjacent                  |

---

## Serialization

Player state is included in the existing save format under a `"player"` key:

```json
{
  "player": {
    "position": [x, y],
    "health": 100,
    "inventory": [
      {"item_id": "iron_ore", "quantity": 5},
      null,
      {"item_id": "iron_plate", "quantity": 3},
      ...
    ],
    "state": "GROUNDED"
  }
}
```

- Position is saved as world coordinates (not grid coordinates)
- Inventory preserves slot positions (null = empty slot)
- Health and state are restored on load
- Dropped ground items are serialized separately in a `"ground_items"` array

---

## Implementation Notes

- The player scene is a `CharacterBody2D` with a `CollisionShape2D` (circle), `Sprite2D`, and a `PlayerLogic` script
- Player is added as a child of `GameWorld`, sibling to `BuildingLayer` and `ItemLayer`
- Conveyor push is calculated in `_physics_process()` by querying the tile under the player's position
- Building collision uses Godot's built-in physics layers: buildings on layer 2, player on layer 1, mask includes layer 2 only when GROUNDED
- Inventory is a standalone resource/class (`scripts/inventory/player_inventory.gd`) — not the same as the building `Inventory` class
- Jump state machine is a simple enum-based FSM inside `PlayerLogic`
- Camera follows the player smoothly (lerp-based tracking)
