# Unified Damage System + Health Bars

**Date:** 2026-04-06 evening (23:00-23:31)
**Duration:** ~0.5h

## Work Done

### Unified Damage System
Unified the damage pipeline across all entity types (player, monster, building).

- **DamageEvent** (`scripts/game/damage_event.gd`): new lightweight data carrier with `amount`, `element`, `source`
- **HealthComponent**: added `revive()` method for player respawn
- **Player**: migrated from manual `hp`/`_is_dead` to `HealthComponent`; `take_damage()` accepts `DamageEvent`
- **BuildingLogic**: added `take_damage(event: DamageEvent)` method
- **MonsterBase**: `take_damage()` accepts `DamageEvent`; all damage dealt creates events with `self` as source; aggro now only triggers from player/projectile sources (resolved longstanding TODO)
- **Projectile**: carries pre-built `DamageEvent` created by turret at fire time; single delivery path
- **TurretBehavior**: creates `DamageEvent` with itself as source when firing

### Health Bars
- **HealthBar3D** (`scripts/game/health_bar_3d.gd`): billboard 3D health bar with green→yellow→red color
- Player: always visible (y=1.0)
- Monsters: visible only when damaged (y=1.2)
- Buildings: visible only when damaged (y=1.5)

## Verification
- Parse check: clean
- Unit tests: 33/33 passed
- sim_player, sim_night_transform: pass
- scn_fight_phase_end, scn_player_movement: pass

## Next
- Element damage processing (resistances, multipliers)
- Damage modifier pipeline (armor, buffs, status effects)
- Visual damage feedback using HealthComponent.get_damage_state()
