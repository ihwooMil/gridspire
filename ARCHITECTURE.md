# GridSpire Architecture

A tactical deckbuilding RPG built in Godot 4.x. Inspired by Slay the Spire but with team-based characters on a grid with movement, range, and a speed-based timeline turn system.

---

## Project Structure

```
gridspire/
├── project.godot              # Godot project config (autoloads, display, input)
├── ARCHITECTURE.md            # This file
├── scenes/
│   ├── main.tscn              # Main scene (entry point, test battle)
│   ├── battle/                # Battle-specific scenes (grid view, characters)
│   ├── map/                   # Overworld map scenes
│   ├── menu/                  # Main menu, settings
│   └── ui/                    # Reusable UI components (card widget, HP bar)
├── scripts/
│   ├── core/                  # Enums, data models, game manager, main scene script
│   ├── grid/                  # GridManager and grid-related logic
│   ├── combat/                # BattleManager, effect resolution
│   ├── cards/                 # DeckManager, card logic
│   ├── characters/            # Character AI, behavior scripts
│   ├── ui/                    # UI controller scripts
│   └── utils/                 # Shared utility functions
├── resources/
│   ├── cards/                 # .tres CardData resources
│   ├── characters/            # .tres CharacterData resources
│   └── maps/                  # .tres or .tscn map layouts
└── assets/
    ├── sprites/               # Character sprites, tile sprites, icons
    ├── fonts/                 # Custom fonts
    └── audio/                 # SFX, music
```

---

## Core Data Models

All data models are GDScript Resource classes, located in `scripts/core/`.

### Enums (`enums.gd` -> `class_name Enums`)

Central enum definitions used across the codebase:

| Enum | Values | Purpose |
|------|--------|---------|
| `CardEffectType` | DAMAGE, HEAL, MOVE, BUFF, DEBUFF, PUSH, PULL, AREA_DAMAGE, AREA_BUFF, AREA_DEBUFF, DRAW, SHIELD | What a card effect does |
| `TargetType` | SELF, SINGLE_ALLY, SINGLE_ENEMY, ALL_ALLIES, ALL_ENEMIES, TILE, AREA, NONE | Who/what a card targets |
| `TileType` | FLOOR, WALL, PIT, HAZARD, ELEVATED | Grid terrain types |
| `Faction` | PLAYER, ENEMY, NEUTRAL | Character allegiance |
| `StatusEffect` | STRENGTH, WEAKNESS, HASTE, SLOW, SHIELD, POISON, REGEN, STUN, ROOT | Buff/debuff types |
| `GameState` | MAIN_MENU, MAP, BATTLE, REWARD, SHOP, EVENT, GAME_OVER | High-level game flow |
| `TurnPhase` | DRAW, ACTION, DISCARD, END | Phases within a turn |

### CardEffect (`card_effect_resource.gd` -> `class_name CardEffect`)

A single atomic effect that a card applies. Cards can have multiple effects.

- `effect_type: CardEffectType` - What this effect does
- `value: int` - Magnitude (damage amount, heal amount, etc.)
- `duration: int` - Turns for buff/debuff
- `status_effect: StatusEffect` - Which status to apply
- `area_radius: int` - Radius for area effects
- `push_pull_distance: int` - Distance for push/pull

### CardData (`card_resource.gd` -> `class_name CardData`)

A single playable card.

- `id: String` - Unique identifier
- `card_name: String` - Display name
- `description: String` - Flavor/rules text
- `energy_cost: int` - Energy required to play
- `range_min / range_max: int` - Valid target range (Manhattan distance)
- `target_type: TargetType` - What this card targets
- `effects: Array[CardEffect]` - Effects applied when played
- `rarity: int` - 0=common, 1=uncommon, 2=rare

### CharacterData (`character_resource.gd` -> `class_name CharacterData`)

A character (player or enemy) with stats, deck, and runtime state.

- `id, character_name, faction` - Identity
- `max_hp, current_hp` - Health
- `speed: int` - Timeline speed (lower = acts sooner)
- `energy_per_turn: int` - Energy gained each turn
- `move_range: int` - Max tiles per move
- `grid_position: Vector2i` - Current tile on the grid
- `starting_deck: Array[CardData]` - Cards in this character's deck
- `status_effects: Dictionary` - Active buffs/debuffs at runtime

Key methods: `is_alive()`, `take_damage()`, `heal()`, `get_effective_speed()`, `modify_status()`, `tick_status_effects()`

### GridTile (`grid_tile_resource.gd` -> `class_name GridTile`)

A single tile on the battle grid.

- `position: Vector2i` - Grid coordinates
- `tile_type: TileType` - Terrain type
- `occupant: CharacterData` - Who is standing here (or null)

Key methods: `is_walkable()`, `is_occupied()`, `is_available()`

### TimelineEntry (`timeline_entry.gd` -> `class_name TimelineEntry`)

An entry on the speed-based turn timeline (FFX CTB-style).

- `character: CharacterData` - Who this entry is for
- `current_tick: int` - Accumulating tick counter (lowest acts next)

Key methods: `advance()` - adds effective speed to tick after acting

### BattleState (`battle_state.gd` -> `class_name BattleState`)

Complete state of an ongoing battle.

- `player_characters / enemy_characters: Array[CharacterData]`
- `timeline: Array[TimelineEntry]`
- `current_entry: TimelineEntry` - Whose turn it is
- `turn_phase: TurnPhase` - Current phase
- `battle_active: bool`

Key methods: `build_timeline()`, `advance_timeline()`, `end_current_turn()`, `check_battle_result()`, `get_timeline_preview()`

---

## Autoload Singletons

Registered in `project.godot` under `[autoload]`. Access from any script by name.

### GameManager (`scripts/core/game_manager.gd`)

Global game state and meta-progression.

**Signals:** `game_state_changed`, `party_updated`

**Key API:**
- `change_state(new_state)` - Transition game state
- `start_new_run()` - Reset everything for a new run
- `add_to_party(character)` / `remove_from_party(character)` - Manage party roster
- `add_gold(amount)` / `spend_gold(amount)` - Currency

### BattleManager (`scripts/combat/battle_manager.gd`)

Drives the battle loop: timeline advancement, turn phases, card resolution, win/loss.

**Signals:** `battle_started`, `battle_ended`, `turn_started`, `turn_ended`, `turn_phase_changed`, `card_played`, `character_damaged`, `character_healed`, `character_died`, `timeline_updated`

**Key API:**
- `start_battle(players, enemies)` - Begin a new battle
- `play_card(card, source, target) -> bool` - Play a card (returns false if invalid)
- `end_turn()` - End the current character's turn
- `get_timeline_preview(count)` - Get upcoming turn order

### GridManager (`scripts/grid/grid_manager.gd`)

Grid creation, tile queries, pathfinding, movement, push/pull.

**Signals:** `grid_initialized`, `character_moved`, `tile_changed`

**Key API:**
- `initialize_grid(width, height)` - Create a new grid
- `get_tile(pos)` / `set_tile_type(pos, type)` - Tile access
- `place_character(character, pos)` - Put a character on the grid
- `move_character(character, target)` - Move with pathfinding validation
- `get_reachable_tiles(character)` - Tiles a character can walk to
- `get_tiles_in_range(origin, min, max)` - Tiles within Manhattan range
- `find_path(from, to)` - BFS pathfinding
- `push_character(source, target, distance)` / `pull_character(...)` - Forced movement
- `get_characters_in_radius(center, radius)` - Area queries
- `grid_to_world(pos)` / `world_to_grid(pos)` - Coordinate conversion

### DeckManager (`scripts/cards/deck_manager.gd`)

Per-character draw/discard/exhaust pile management.

**Signals:** `cards_drawn`, `cards_discarded`, `deck_shuffled`, `card_added_to_deck`, `card_removed_from_deck`

**Key API:**
- `initialize_deck(character)` / `initialize_all_decks(characters)` - Set up piles
- `draw_cards(character, count)` - Draw from pile (auto-shuffles discard when empty)
- `discard_hand(character, hand)` / `discard_card(character, card)` - Send to discard
- `exhaust_card(character, card)` - Remove from battle
- `add_card_to_deck(character, card)` / `remove_card_from_deck(character, card)` - Permanent deck modification
- `get_draw_count(character)` / `get_discard_count(character)` - Pile sizes

---

## Turn Flow (Speed-Based Timeline)

```
1. BattleState.build_timeline()        -- Initialize timeline from all characters
2. BattleState.advance_timeline()      -- Pick character with lowest tick
3. Character turn begins:
   a. DRAW phase: DeckManager.draw_cards(character, 5)
   b. ACTION phase: Player selects cards / AI decides
      - BattleManager.play_card(card, source, target)
      - Effects resolved via _apply_effect()
   c. DISCARD phase: Remaining hand discarded
   d. END phase: TimelineEntry.advance() adds speed to tick
4. Check win/loss via BattleState.check_battle_result()
5. Repeat from step 2
```

**Speed system:** Lower speed = acts more often. A character with speed 50 acts twice as often as one with speed 100. Haste multiplies speed by 0.75, Slow by 1.5.

---

## Grid System

- Rectangular grid, default 10x8 tiles
- Manhattan distance for range calculations
- BFS pathfinding for movement (respects walls, occupied tiles)
- Push/pull uses dominant axis direction
- Tile types: FLOOR (walkable), WALL (blocks), PIT (blocks), HAZARD (walkable + damage), ELEVATED (walkable + defense bonus)
- Coordinate conversion: `grid_to_world()` / `world_to_grid()` with configurable `tile_size`

---

## Card System

- Each character has their own deck (not shared)
- Cards cost energy (default 3 energy per turn)
- Cards have range (Manhattan distance from caster)
- Multiple effects per card allow combo cards (e.g., "Deal 5 damage AND push 2 tiles")
- Target types determine what the player clicks on (enemy, ally, tile, self, area)
- Draw pile auto-shuffles discard pile when empty

---

## Scene Tree (main.tscn)

```
Main (Node2D) ─── scripts/core/main.gd
├── Camera2D
├── UI (CanvasLayer)
│   ├── BattleHUD (Control, mouse_filter=IGNORE) ─── battle_hud.gd
│   │   ├── TopBar (HBoxContainer, mouse_filter=IGNORE)
│   │   │   ├── %BattleTurnLabel, %BattleEnergyLabel
│   │   │   └── %DrawCountLabel, %DiscardCountLabel
│   │   ├── %CharacterInfo (PanelContainer) ─── character_info.gd
│   │   ├── %CardHand (HBoxContainer, mouse_filter=IGNORE) ─── card_hand.gd
│   │   │   └── [CardUI instances] (PanelContainer, mouse_filter=STOP)
│   │   ├── %TimelineBar (VBoxContainer, mouse_filter=IGNORE) ─── timeline_bar.gd
│   │   └── %EndTurnButton (Button)
│   └── BattleResult (Control) ─── battle_result.gd
└── GridContainer (Node2D) ─── grid_visual.gd
    └── [Character sprite Node2D들]
```

> **자세한 설계 문서**: `docs/DESIGN.md` 참고
> **요구사항 문서**: `docs/REQUIREMENTS.md` 참고

---

## Development Guidelines

- Use Godot 4.x syntax: `class_name`, `@export`, `@onready`, typed variables
- Access autoloads by name: `GameManager`, `BattleManager`, `GridManager`, `DeckManager`
- Use signals for loose coupling between systems
- Resources (CardData, CharacterData) can be saved as `.tres` files in `resources/`
- All enums go through the `Enums` class: `Enums.CardEffectType.DAMAGE`
- Grid positions are `Vector2i`, world positions are `Vector2`

---

## Next Steps

- 오버월드 맵 (Slay the Spire 스타일 노드 맵)
- 보상/상점 시스템
- 유물 시스템
- 다중 스테이지/보스전
- 캐릭터 해금/성장

> 전체 향후 계획은 `docs/REQUIREMENTS.md`의 "향후 요구사항" 섹션 참고
