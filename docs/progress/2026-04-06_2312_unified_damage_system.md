# Unified Damage System Refactor

**Date:** 2026-04-06 evening (23:00-23:12)
**Duration:** ~0.2h (quick session)

## Work Done

Unified the damage pipeline across all entity types (player, monster, building).

### Changes
- **DamageEvent** (`scripts/game/damage_event.gd`): new lightweight data carrier with `amount`, `element`, `source`
- **HealthComponent**: added `revive()` method for player respawn
- **Player**: migrated from manual `hp`/`_is_dead` to `HealthComponent`; `take_damage()` now accepts `DamageEvent`
- **BuildingLogic**: added `take_damage(event: DamageEvent)` method
- **MonsterBase**: `take_damage()` accepts `DamageEvent`; all damage dealt creates events with `self` as source; aggro now only triggers from player/projectile sources (resolved longstanding TODO)
- **Projectile**: carries pre-built `DamageEvent` created by turret at fire time; single delivery path
- **TurretBehavior**: creates `DamageEvent` with itself as source when firing
- Updated all tests (sim_player, sim_night_transform, bot_controller, scn_fight_phase_end, scn_player_movement)

### Verification
- Parse check: clean
- Unit tests: 33/33 passed
- sim_player: all assertions pass
- sim_night_transform: all assertions pass
- scn_fight_phase_end: pass
- scn_player_movement: pass

## Next
- Element damage processing (resistances, multipliers) -- DamageEvent carries element end-to-end, ready for implementation
- Damage modifier pipeline (armor, buffs, status effects)
- Visual damage feedback using HealthComponent.get_damage_state()
