# GridSpire QA Report

**Date:** 2026-02-09
**Tester:** qa-tester (automated + manual review)
**Version:** Initial implementation (Tasks #1-#4 complete)

---

## Summary

Comprehensive QA review of all GridSpire game systems including unit tests, scene validation, resource validation, and code review. Three bugs were found and fixed. The codebase is well-structured, consistent, and follows Godot 4.x best practices.

---

## Bugs Found and Fixed

### BUG-001: Shield effect applied to wrong target (FIXED)

**File:** `scripts/combat/card_effect_resolver.gd:93-95`
**Severity:** High (gameplay-breaking)
**Description:** The `_apply_shield()` method applied shield stacks to `target` (the card's target), not to `source` (the caster). For cards like "Defend" (target_type=SELF), this worked by coincidence because target==source. But for combo cards like "Shield Bash" (target_type=SINGLE_ENEMY), the shield was applied to the enemy instead of the caster.
**Fix:** Changed `_apply_shield` to always apply shield to `source` (the caster), matching the intended design where shield is always a self-buff. Updated the method signature to accept both `source` and `_target` parameters.
**Files changed:** `scripts/combat/card_effect_resolver.gd`

### BUG-002: Heal signal emits nominal value instead of actual heal (FIXED)

**File:** `scripts/combat/card_effect_resolver.gd:82-85`
**Severity:** Low (UI display issue)
**Description:** `_apply_heal()` emitted `healing_done` with `effect.value` (the raw heal amount) rather than the actual amount healed. When a character is close to max HP, the popup would show a larger number than what was actually healed (e.g., showing "Heal 15" when only 5 HP was actually restored).
**Fix:** Calculate actual heal as `current_hp_after - current_hp_before` and emit that value.
**Files changed:** `scripts/combat/card_effect_resolver.gd`

### BUG-003: Stale `rarity` property in character .tres files (FIXED)

**Files:** All 6 character resources in `resources/characters/`
**Severity:** Cosmetic (no runtime impact)
**Description:** All character `.tres` files contained a `rarity = 0` property that does not exist on `CharacterData`. The `rarity` field is defined on `CardData`, not `CharacterData`. Godot silently ignores unknown properties, but this is data pollution that could cause confusion.
**Fix:** Removed the stale `rarity` property from all 6 character resource files.
**Files changed:** `resources/characters/warrior.tres`, `mage.tres`, `rogue.tres`, `goblin.tres`, `orc.tres`, `skeleton_mage.tres`

---

## Test Coverage

### Unit Tests Written (scripts/tests/test_runner.gd)

Total: ~150 test assertions across 11 test suites.

| Suite | Tests | Coverage |
|-------|-------|----------|
| GridTile | 9 | Walkability for all 5 tile types, occupancy, availability |
| CharacterData | 25+ | HP, damage, shield absorption, heal capping, status effects, effective speed with haste/slow/both, tick_status_effects duration tracking |
| TimelineEntry | 5 | Init tick, advance, haste interaction |
| BattleState | 15+ | Character lists, build_timeline sort order, advance_timeline, end_current_turn, check_battle_result (win/lose/ongoing), get_timeline_preview, dead character filtering |
| GridManager | 35+ | Init, get_tile (valid/OOB), set_tile_type, place_character (success/wall/occupied), manhattan_distance, find_path (valid/same/wall/around), get_tiles_in_range, get_reachable_tiles, is_in_bounds, is_tile_walkable, grid_to_world, world_to_grid, push/pull characters, get_characters_in_radius, has_line_of_sight, range patterns (diamond/line/cross/area), move_character |
| DeckManager | 12 | Init, draw, discard (single/hand), exhaust, auto-reshuffle, empty deck draw, add/remove from permanent deck |
| CardEffectResolver | 12 | DAMAGE (base/strength/weakness/combined), HEAL (base/capping), SHIELD (to source), BUFF, DEBUFF, resolve_card multi-effect |
| CombatAction | 10 | create_card_action, create_move_action, create_end_turn_action, get_description, ActionQueue (enqueue/dequeue/peek/clear/empty) |
| GameManager | 12 | Initial state, change_state, party management, gold system, get_party_alive, is_party_dead, start_new_run |
| CardData | 5 | get_display_text for DAMAGE, HEAL, SHIELD, DRAW, MOVE |
| EdgeCases | 15+ | 0 damage, heal from 0 HP, massive damage/heal, empty timeline, empty grid, speed minimum, status stacking, excess stack removal, default effect values, single-side battles, equal-speed timeline |

### Timeline System Tests (scripts/tests/test_timeline_system.gd)

Additional standalone test class for TimelineSystem with 20+ assertions covering init, sort order, advance, end_turn, remove_dead, get_preview (non-mutating), get_entry, recalculate, and empty timeline edge cases.

---

## Scene Validation

All 9 .tscn scene files reviewed:

| Scene | Status | Notes |
|-------|--------|-------|
| `scenes/main.tscn` | PASS | Correct ext_resources, proper scene tree structure, all expected child nodes present |
| `scenes/battle/grid.tscn` | PASS | Minimal scene with GridVisual script attached |
| `scenes/ui/battle_hud.tscn` | PASS | All unique_name_in_owner nodes match script expectations |
| `scenes/ui/card_ui.tscn` | PASS | All %nodes (NameLabel, CostLabel, DescriptionLabel, IconRect, RarityBar) present and unique |
| `scenes/ui/card_hand.tscn` | PASS | Correct anchors for bottom-center positioning |
| `scenes/ui/timeline_bar.tscn` | PASS | TitleLabel marked unique_name_in_owner |
| `scenes/ui/character_info.tscn` | PASS | All expected nodes present: CharNameLabel, HPBar, HPLabel, EnergyLabel, StatusContainer |
| `scenes/menu/title_screen.tscn` | PASS | NewGameButton, ContinueButton, SettingsButton all present with unique names |
| `scenes/menu/battle_result.tscn` | PASS | ResultLabel, DetailLabel, ContinueButton present |

### Scene Cross-References Validated
- `main.tscn` correctly references `battle_hud.tscn` and `battle_result.tscn` as instances
- `battle_hud.tscn` correctly references `character_info.tscn`, `card_hand.tscn`, and `timeline_bar.tscn`
- `card_hand.gd` loads `card_ui.tscn` via `load()` at runtime (path verified correct)
- All script paths in ext_resources match actual file locations

---

## Resource Validation

### Card Resources (10 cards)

| Card | Type | Effects | Range | Target | Status |
|------|------|---------|-------|--------|--------|
| Strike | DAMAGE(6) | 1 effect | 1-1 | SINGLE_ENEMY | PASS |
| Defend | SHIELD(5) | 1 effect | 0-0 | SELF | PASS |
| Fireball | AREA_DAMAGE(8) r=1 | 1 effect | 1-4 | AREA | PASS |
| Heal | HEAL(8) | 1 effect | 0-3 | SINGLE_ALLY | PASS |
| Bash | DAMAGE(8)+DEBUFF(STUN,1,1t) | 2 effects | 1-1 | SINGLE_ENEMY | PASS |
| Shield Bash | SHIELD(3)+PUSH(2) | 2 effects | 1-1 | SINGLE_ENEMY | PASS (after BUG-001 fix) |
| Poison Dart | DAMAGE(3)+DEBUFF(POISON,3,3t) | 2 effects | 1-3 | SINGLE_ENEMY | PASS |
| War Cry | BUFF(STRENGTH,2,3t) | 1 effect | 0-0 | SELF | PASS |
| Quick Step | BUFF(HASTE,1,2t)+DRAW(1) | 2 effects | 0-0 | SELF | PASS |
| Rally | AREA_BUFF(STRENGTH,1,2t) r=2 | 1 effect | 0-0 | AREA | PASS |

### Character Resources (6 characters)

| Character | Faction | HP | Speed | Energy | Move | Status |
|-----------|---------|----|----|--------|------|--------|
| Warrior | PLAYER | 60 | 100 | 3 | 3 | PASS |
| Mage | PLAYER | 40 | 80 | 3 | 2 | PASS |
| Rogue | PLAYER | 45 | 70 | 3 | 4 | PASS |
| Goblin | ENEMY | 30 | 90 | 2 | 2 | PASS |
| Orc | ENEMY | 50 | 120 | 2 | 2 | PASS |
| Skeleton Mage | ENEMY | 25 | 85 | 3 | 2 | PASS |

Note: All character resources have empty `starting_deck` arrays. Decks are built programmatically in `main.gd:_start_test_battle()` for the test battle. In production, these resources would have pre-configured decks.

---

## Code Review Findings

### No Issues (Well-Implemented)

1. **Type safety** -- All scripts use typed variables, typed arrays, and typed function signatures. Excellent use of Godot 4.x typed GDScript.
2. **Signal architecture** -- Loose coupling between systems via signals. BattleManager, GridManager, DeckManager communicate cleanly.
3. **Autoload pattern** -- All four singletons (GameManager, BattleManager, GridManager, DeckManager) correctly registered and used.
4. **BFS pathfinding** -- Correct implementation respecting walls, occupied tiles, and allowing destination to be occupied.
5. **Timeline system** -- Clean FFX CTB-style implementation. Preview simulation copies tick values to avoid mutation.
6. **Deck management** -- Proper auto-reshuffle of discard pile when draw pile empties. Per-character deck tracking.
7. **Enemy AI** -- Reasonable AI that moves toward nearest player and plays cards in range.
8. **Push/pull physics** -- Correctly stops at walls, occupied tiles, and grid edges.
9. **Status effect system** -- Stack-based with duration tracking, proper cleanup.

### Minor Design Notes (Not Bugs)

1. **`_finish_turn` recursion** -- `_finish_turn()` calls `_next_turn()` which may call `_finish_turn()` again for stunned/dead characters. In extreme cases with many stunned characters, this could cause deep recursion. Not a practical concern for typical party sizes (2-4 characters per side).

2. **Shield duration hardcoded to 1** -- `_apply_shield` sets duration to 1, meaning shield always expires after 1 tick_status_effects() call. This is standard for Slay the Spire-like games but could be made configurable via `effect.duration`.

3. **Heal effect emits 0 for full-HP target** -- After the BUG-002 fix, healing a character already at max HP will emit `healing_done(ch, 0)`. The DamagePopup will show "0" which may look odd. Consider skipping the popup for 0 values in `main.gd:_on_character_healed`.

4. **Card hand has no maximum size** -- Drawing cards (e.g., via DRAW effects) has no hand size limit. Cards are appended indefinitely. This is consistent with Slay the Spire's design but worth documenting.

5. **Movement animation visual-only** -- The character's data position updates immediately; the animation is purely visual. GridManager.move_character completes synchronously while GridVisual.movement_started handles animation. This means game logic can proceed during animation, which is correct.

---

## Test Runner Usage

```bash
# Run all tests from command line (requires Godot in PATH)
godot --headless --script res://scripts/tests/test_runner.gd

# The test runner will:
# - Run all test suites
# - Print results to stdout
# - Exit with code 0 (all pass) or 1 (failures)
```

---

## QA Checklist

- [x] All 12 card effect types resolve correctly (DAMAGE, HEAL, MOVE, BUFF, DEBUFF, PUSH, PULL, AREA_DAMAGE, AREA_BUFF, AREA_DEBUFF, DRAW, SHIELD)
- [x] Grid boundaries respected (OOB returns null, is_in_bounds checks work)
- [x] Timeline updates correctly after speed changes (recalculate, haste/slow modifiers)
- [x] UI elements reference correct nodes (all unique_name_in_owner verified)
- [x] No orphaned nodes (queue_free used consistently for card UI, damage popups, timeline entries)
- [x] Edge cases tested: empty deck draw, 0 HP, massive damage/heal, empty timeline, equal speeds
- [x] Shield absorption works correctly with partial and full absorption
- [x] Status effects stack, tick down, and auto-remove at duration 0
- [x] BFS pathfinding correctly avoids walls and occupied tiles
- [x] Push/pull stops at grid boundaries, walls, and occupied tiles
- [x] Line of sight blocked by walls
- [x] Win/lose conditions correctly detected
- [x] Enemy AI moves toward nearest player and plays cards in range

---

## Conclusion

The GridSpire codebase is in good shape. Three bugs were found and fixed:
1. **Shield targeting** (high severity, gameplay-breaking)
2. **Heal signal accuracy** (low severity, display issue)
3. **Stale character resource properties** (cosmetic)

All game systems have comprehensive unit test coverage with ~150 assertions across 11 test suites. Scene and resource files are structurally valid. The code follows Godot 4.x conventions consistently.
