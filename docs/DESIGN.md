# GridSpire - 설계 문서

## 시스템 아키텍처

### 전체 구조

```
┌──────────────────────────────────────────────────────┐
│                    Main Scene                         │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐ │
│  │  GridVisual  │  │  BattleHUD  │  │ BattleResult │ │
│  │  (Node2D)   │  │  (Control)  │  │  (Control)   │ │
│  └──────┬──────┘  └──────┬──────┘  └──────────────┘ │
│         │                │                            │
│         │    시그널 기반 통신                          │
│         ▼                ▼                            │
│  ┌─────────────────────────────────────────────────┐ │
│  │              Autoload Singletons                 │ │
│  │  ┌───────────┐ ┌─────────────┐ ┌─────────────┐ │ │
│  │  │GameManager│ │BattleManager│ │ GridManager  │ │ │
│  │  └───────────┘ └──────┬──────┘ └─────────────┘ │ │
│  │                ┌──────┴──────┐ ┌─────────────┐ │ │
│  │                │TimelineSystem│ │ DeckManager │ │ │
│  │                │CardEffectRes.│ └─────────────┘ │ │
│  │                └─────────────┘                   │ │
│  └─────────────────────────────────────────────────┘ │
│                        │                              │
│                        ▼                              │
│  ┌─────────────────────────────────────────────────┐ │
│  │              Data Models (Resources)              │ │
│  │  CharacterData  CardData  GridTile  BattleState  │ │
│  └─────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

### 설계 원칙

1. **시그널 기반 느슨한 결합**: 시스템 간 직접 참조 대신 시그널로 통신
2. **Autoload 싱글톤 패턴**: 전역 매니저들은 Godot autoload로 등록
3. **Resource 데이터 모델**: 캐릭터/카드 데이터는 Resource 클래스로 정의, `.tres`로 저장 가능
4. **UI와 로직 분리**: BattleManager가 게임 로직, UI는 시그널을 구독하여 표시만 담당

---

## 씬 트리 구조

```
Main (Node2D) ─── scripts/core/main.gd
├── Camera2D
│   └── position: (640, 360)
├── UI (CanvasLayer)
│   ├── BattleHUD (Control, mouse_filter=IGNORE) ─── battle_hud.gd
│   │   ├── TopBar (HBoxContainer, mouse_filter=IGNORE)
│   │   │   └── %BattleTurnLabel (160px)
│   │   ├── %TimelineBar (Control, layout_mode=1) ─── timeline_bar.gd
│   │   │   └── 상단 바 우측, TurnLabel 옆에 배치
│   │   ├── %CharacterInfo (PanelContainer, 좌하단) ─── character_info.gd
│   │   │   └── 이름, HP바, 에너지, 드로우/무덤 카운트, 상태이상 뱃지
│   │   ├── %CardHand (Control, 하단 중앙, mouse_filter=IGNORE) ─── card_hand.gd
│   │   │   └── [CardUI 인스턴스들] (PanelContainer, mouse_filter=STOP)
│   │   ├── %EndTurnButton (Button, 우측 중앙)
│   │   ├── %GraveyardButton (Button, 우측, EndTurn 아래)
│   │   └── %GraveyardPopup (PanelContainer, 화면 중앙 600×400, hidden)
│   │       └── VBox > Header(Title+CloseButton) + ScrollContainer > GridContainer(4열)
│   └── BattleResult (Control) ─── battle_result.gd
└── GridContainer (Node2D) ─── grid_visual.gd
    └── [Character sprite Node2D들]
```

### mouse_filter 설계

UI가 전체 화면을 덮지만 그리드 클릭을 차단하지 않도록:
- **IGNORE (2)**: BattleHUD, TopBar, CardHand, TimelineBar — 마우스 이벤트 통과
- **STOP (0)**: EndTurnButton, CardUI, CharacterInfo — 클릭 수신

GridVisual은 `_unhandled_input()`으로 UI가 처리하지 않은 마우스 이벤트를 수신한다.

---

## 핵심 시스템 설계

### 1. 그리드 시스템

```
GridManager (Autoload)
├── grid: Dictionary[Vector2i, GridTile]
├── tile_size: Vector2 = (116, 58)  ← 2:1 비율, battle_scene.gd에서 동적 계산
├── grid_width / grid_height: int
│
├── 타일 관리
│   ├── initialize_grid(w, h)
│   ├── get_tile(pos) → GridTile
│   └── set_tile_type(pos, type)
│
├── 캐릭터 배치/이동
│   ├── place_character(character, pos)
│   ├── move_character(character, target) → bool
│   └── remove_character(character)
│
├── 경로 탐색 (BFS)
│   ├── find_path(from, to) → Array[Vector2i]
│   ├── get_reachable_tiles(character) → Array[Vector2i]
│   └── is_tile_walkable(pos) → bool
│
├── 사거리 계산
│   ├── get_tiles_in_range(origin, min, max) → Array[Vector2i]
│   ├── get_tiles_in_range_pattern(origin, max, pattern) → Array[Vector2i]
│   ├── has_line_of_sight(from, to) → bool
│   └── manhattan_distance(a, b) → int
│
└── 강제 이동
    ├── push_character(source, target, distance)
    └── pull_character(source, target, distance)
```

**경로 탐색 알고리즘**: BFS (너비 우선 탐색)
- WALL, PIT, 점유 타일은 통과 불가
- 목적지가 점유된 경우는 허용 (타겟팅용)
- 이동 비용은 균일 (1 per tile)

**좌표 변환**:
- `grid_to_world(pos)`: `Vector2(pos) * tile_size + tile_size / 2`
- `world_to_grid(world)`: `Vector2i(world / tile_size)`

### 2. 타임라인 턴 시스템

```
TimelineSystem
├── entries: Array[TimelineEntry]
├── current_entry: TimelineEntry
│
├── initialize(characters)     tick=0으로 초기화, speed 오름차순 정렬
├── advance() → CharacterData  가장 낮은 tick의 캐릭터를 현재 턴으로
├── end_current_turn()         현재 캐릭터의 tick += effective_speed
├── get_preview(count)         다음 N턴 시뮬레이션 (상태 변경 없음)
├── recalculate()              speed 변경 후 재정렬
└── remove_dead()              사망 캐릭터 제거
```

**턴 순서 결정**:
```
tick 값이 가장 낮은 캐릭터가 다음 턴
→ 행동 후 tick += effective_speed
→ effective_speed = speed × haste(0.75) × slow(1.5)
```

**미리보기**: tick 값을 복사하여 시뮬레이션, 원본 데이터 변경 없음

### 3. 전투 흐름

```
BattleManager.start_battle(players, enemies)
    │
    ├── BattleState 생성
    ├── TimelineSystem 초기화
    ├── DeckManager.initialize_all_decks()
    ├── battle_started 시그널
    └── _next_turn()
         │
         ├── check_battle_result() → "win" / "lose" → _end_battle()
         │
         ├── timeline.advance() → 현재 캐릭터
         │
         ├── STUN 체크 → 스킵
         ├── 독/재생 적용
         ├── 위험 타일 데미지
         │
         ├── [PLAYER] _start_player_turn()
         │   ├── 에너지 초기화
         │   ├── draw_cards(5)
         │   ├── 플레이어 입력 대기
         │   │   ├── play_card() → 카드 효과 해결
         │   │   ├── move_character() → 이동 (1회)
         │   │   └── end_turn() → 디스카드 → _finish_turn()
         │   └── _finish_turn() → timeline.end_current_turn() → _next_turn()
         │
         └── [ENEMY] _start_enemy_turn()
             ├── draw_cards(3)
             ├── AI: 이동 → 카드 사용
             └── _finish_turn()
```

### 4. 카드 효과 해결

```
CardEffectResolver.resolve_card(card, source, target)
    │
    └── card.effects 순회:
        ├── DAMAGE  → target.take_damage(value + strength - weakness)
        ├── HEAL    → target.heal(value), 최대HP 캡
        ├── SHIELD  → source.modify_status(SHIELD, value)  ← 항상 시전자
        ├── BUFF    → target.modify_status(status, stacks, duration)
        ├── DEBUFF  → target.modify_status(status, stacks, duration)
        ├── PUSH    → GridManager.push_character(source, target, distance)
        ├── PULL    → GridManager.pull_character(source, target, distance)
        ├── DRAW    → DeckManager.draw_cards(source, value) → 핸드에 추가
        ├── MOVE    → GridManager.move_character(target, position)
        ├── AREA_*  → GridManager.get_characters_in_radius() → 각각 적용
        └── 시그널: damage_dealt, healing_done, character_killed
```

**데미지 계산**:
```
base_damage = effect.value
+ source.get_status_stacks(STRENGTH)
× (0.75 if target has WEAKNESS)
- target.get_status_stacks(SHIELD) → 실드 먼저 소모
= actual_damage → target.take_damage()
```

### 5. 카드 타겟팅 흐름

```
[카드 클릭]
    │
    ├── SELF / NONE / ALL_* → 즉시 발동 (auto-target)
    │   └── BattleManager.play_card(card, source, source)
    │
    └── SINGLE_ENEMY / SINGLE_ALLY / TILE / AREA
        │
        ├── BattleHUD.targeting_requested 시그널
        ├── main.gd → GridVisual.enter_targeting_mode(card, source)
        ├── 빨간 사거리 하이라이트 표시
        │
        ├── [좌클릭 유효 타겟] → GridVisual.target_selected 시그널
        │   └── main.gd → BattleManager.play_card(card, source, target)
        │
        ├── [좌클릭 무효 위치] → 타겟팅 취소
        └── [우클릭] → 타겟팅 취소
```

### 6. 카드 레지스트리

```
CardRegistry (static class)
│
├── CLASS_CARDS: Dictionary
│   ├── "warrior": Array[String]  (32 card paths)
│   ├── "mage": Array[String]     (33 card paths)
│   └── "rogue": Array[String]    (28 card paths)
│
├── UPGRADES: Array[String]       (7 upgrade paths)
│
├── get_class_cards(class_id) → Array[CardData]
│   └── 직업별 카드 로딩 (load() 사용, 웹 빌드 호환)
│
├── get_all_player_cards() → Array[CardData]
│   └── 전체 플레이어 카드풀 (상점용)
│
└── get_upgrades() → Array[StatUpgrade]
    └── 전체 스탯 업그레이드 목록
```

**설계 근거**: Godot Web 내보내기에서 `DirAccess.open("res://...")`은
PCK 패킹된 파일시스템을 열거할 수 없어 `null`을 반환한다.
정적 경로 딕셔너리와 `load(path)`를 사용하여 모든 플랫폼에서 동작하도록 한다.

**보상 흐름**:
```
전투 승리 → REWARD state → RewardScreen
    │
    ├── CardRegistry.get_class_cards(class_prefix)
    ├── 레어리티 가중치 적용 (Common 3x, Uncommon 2x, Rare 1x)
    ├── 3장 고유 카드 선택지 표시
    │
    ├── [카드 선택] → DeckManager.add_card_to_deck()
    └── [Skip] → 카드 미추가 → MAP state
```

### 7. 덱 관리

```
DeckManager (Autoload)
│
├── Per-character piles:
│   ├── draw_piles: Dict[CharacterData, Array[CardData]]
│   ├── discard_piles: Dict[CharacterData, Array[CardData]]
│   └── exhaust_piles: Dict[CharacterData, Array[CardData]]
│
├── initialize_deck(character)
│   └── starting_deck → draw_pile, 셔플
│
├── draw_cards(character, count) → Array[CardData]
│   └── draw_pile 비면 → discard_pile 셔플하여 draw_pile로
│
├── discard_card(character, card)
├── discard_hand(character, hand)
├── exhaust_card(character, card)  ← 영구 제거 (전투 내)
│
├── get_draw_count(character) → int
├── get_discard_count(character) → int
├── get_discard_pile(character) → Array[CardData]  ← 무덤 팝업 표시용
│
└── 영구 덱 수정 (보상/상점)
    ├── add_card_to_deck(character, card)
    └── remove_card_from_deck(character, card)
```

---

## 데이터 모델

### 클래스 다이어그램

```
Resource
├── CardEffect
│   ├── effect_type: CardEffectType
│   ├── value: int
│   ├── duration: int
│   ├── status_effect: StatusEffect
│   ├── area_radius: int
│   └── push_pull_distance: int
│
├── CardData
│   ├── id: String
│   ├── card_name: String
│   ├── description: String
│   ├── energy_cost: int
│   ├── range_min / range_max: int
│   ├── target_type: TargetType
│   ├── effects: Array[CardEffect]
│   └── rarity: int
│
├── CharacterData
│   ├── id, character_name: String
│   ├── faction: Faction
│   ├── max_hp / current_hp: int
│   ├── speed: int
│   ├── energy_per_turn: int
│   ├── move_range: int
│   ├── grid_position: Vector2i
│   ├── starting_deck: Array[CardData]
│   ├── status_effects: Dictionary
│   └── methods: take_damage(), heal(), get_effective_speed(), etc.
│
├── GridTile
│   ├── position: Vector2i
│   ├── tile_type: TileType
│   ├── occupant: CharacterData
│   └── methods: is_walkable(), is_occupied(), is_available()
│
├── TimelineEntry
│   ├── character: CharacterData
│   ├── current_tick: int
│   └── methods: advance()
│
└── BattleState
    ├── player_characters / enemy_characters: Array[CharacterData]
    ├── timeline: Array[TimelineEntry]
    ├── current_entry: TimelineEntry
    ├── turn_phase: TurnPhase
    ├── turn_number: int
    ├── battle_active: bool
    └── methods: check_battle_result(), get_timeline_preview()
```

### 현재 카드 데이터 (10종)

| 카드 | 비용 | 타겟 | 사거리 | 효과 |
|------|------|------|--------|------|
| Strike | 1 | SINGLE_ENEMY | 1-1 | DAMAGE(6) |
| Defend | 1 | SELF | 0-0 | SHIELD(5) |
| Fireball | 2 | AREA | 1-4 | AREA_DAMAGE(8) r=1 |
| Heal | 1 | SINGLE_ALLY | 0-3 | HEAL(8) |
| Bash | 2 | SINGLE_ENEMY | 1-1 | DAMAGE(8) + STUN(1t) |
| Shield Bash | 1 | SINGLE_ENEMY | 1-1 | SHIELD(3) + PUSH(2) |
| Poison Dart | 1 | SINGLE_ENEMY | 1-3 | DAMAGE(3) + POISON(3, 3t) |
| War Cry | 1 | SELF | 0-0 | BUFF(STRENGTH+2, 3t) |
| Quick Step | 1 | SELF | 0-0 | BUFF(HASTE, 2t) + DRAW(1) |
| Rally | 2 | AREA | 0-0 | AREA_BUFF(STRENGTH+1, 2t) r=2 |

### 현재 캐릭터 데이터 (6종)

| 캐릭터 | 진영 | HP | Speed | Energy | Move |
|--------|------|-----|-------|--------|------|
| Warrior | PLAYER | 60 | 100 | 3 | 3 |
| Mage | PLAYER | 40 | 80 | 3 | 2 |
| Rogue | PLAYER | 45 | 70 | 3 | 4 |
| Goblin | ENEMY | 30 | 90 | 2 | 2 |
| Orc | ENEMY | 50 | 120 | 2 | 2 |
| Skeleton Mage | ENEMY | 25 | 85 | 3 | 2 |

---

## 시그널 맵

### BattleManager 시그널

```
battle_started()              → BattleHUD (표시), CardHand (준비)
battle_ended(result)          → BattleResult (승패 표시), BattleHUD (숨김)
turn_started(character)       → BattleHUD (정보 갱신), CardHand (핸드 표시)
turn_ended(character)         → CardHand (핸드 클리어)
card_played(card, src, tgt)   → BattleHUD (에너지 갱신), CardHand (재렌더)
character_damaged(ch, amt)    → main.gd (데미지 팝업)
character_healed(ch, amt)     → main.gd (힐 팝업)
character_died(ch)            → main.gd (스프라이트 제거, 타일 정리)
energy_changed(cur, max)      → BattleHUD (에너지 라벨)
hand_updated(hand)            → CardHand (핸드 재렌더)
timeline_updated()            → TimelineBar (순서 갱신)
summon_added(summon, owner)   → BattleScene (소환수 스프라이트 생성)
```

### GridManager 시그널

```
grid_initialized(w, h)       → GridVisual (스프라이트 생성, 렌더링)
character_moved(ch, from, to) → GridVisual (스프라이트 위치 갱신)
tile_changed(pos, tile)       → GridVisual (타일 재렌더)
movement_started(ch, path)    → GridVisual (이동 애니메이션 시작)
movement_finished(ch)         → GridVisual (애니메이션 완료)
```

### UI 시그널

```
BattleHUD.targeting_requested(card, source)  → main.gd → GridVisual 타겟팅 모드
GridVisual.target_selected(card, src, tgt)   → main.gd → BattleManager.play_card()
GridVisual.targeting_cancelled()              → 타겟팅 취소
GridVisual.character_selected(ch)             → 이동 범위 표시
GridVisual.character_deselected()             → 하이라이트 해제
CardHand.card_selected(card)                  → BattleHUD → 자동/수동 타겟팅
```

---

## 파일 구조

```
gridspire/
├── project.godot
├── ARCHITECTURE.md
├── docs/
│   ├── REQUIREMENTS.md          ← 요구사항 정의서
│   └── DESIGN.md                ← 이 문서
├── scenes/
│   ├── main.tscn                 메인 씬 (진입점)
│   ├── battle/
│   │   └── grid.tscn             전투 그리드 씬
│   ├── menu/
│   │   ├── title_screen.tscn     타이틀 화면
│   │   └── battle_result.tscn    전투 결과 오버레이
│   └── ui/
│       ├── battle_hud.tscn       전투 HUD (메인 오버레이)
│       ├── card_ui.tscn          카드 위젯
│       ├── card_hand.tscn        카드 핸드 컨테이너
│       ├── character_info.tscn   캐릭터 정보 패널
│       └── timeline_bar.tscn     타임라인 바
├── scripts/
│   ├── core/
│   │   ├── enums.gd              전역 열거형
│   │   ├── card_effect_resource.gd  카드 효과 데이터
│   │   ├── card_resource.gd      카드 데이터
│   │   ├── character_resource.gd 캐릭터 데이터
│   │   ├── grid_tile_resource.gd 타일 데이터
│   │   ├── timeline_entry.gd     타임라인 엔트리
│   │   ├── battle_state.gd       전투 상태
│   │   ├── card_registry.gd      정적 카드/업그레이드 레지스트리
│   │   ├── game_manager.gd       [Autoload] 전역 게임 상태
│   │   └── main.gd               메인 씬 스크립트
│   ├── grid/
│   │   ├── grid_manager.gd       [Autoload] 그리드 로직
│   │   └── grid_visual.gd        그리드 렌더링 & 입력
│   ├── combat/
│   │   ├── battle_manager.gd     [Autoload] 전투 흐름
│   │   ├── timeline_system.gd    타임라인 시스템
│   │   ├── card_effect_resolver.gd  카드 효과 해결
│   │   └── combat_action.gd      액션 큐
│   ├── cards/
│   │   └── deck_manager.gd       [Autoload] 덱 관리
│   ├── ui/
│   │   ├── battle_hud.gd         전투 HUD 컨트롤러
│   │   ├── card_ui.gd            카드 위젯
│   │   ├── card_hand.gd          카드 핸드
│   │   ├── character_info.gd     캐릭터 정보
│   │   ├── timeline_bar.gd       타임라인 바
│   │   ├── damage_popup.gd       데미지 팝업
│   │   ├── title_screen.gd       타이틀 화면
│   │   ├── battle_result.gd      전투 결과
│   │   ├── reward_screen.gd     보상 화면 (CardRegistry 사용)
│   │   ├── shop_screen.gd       상점 화면 (CardRegistry 사용)
│   │   └── event_screen.gd      이벤트 화면 (CardRegistry 사용)
│   └── tests/
│       ├── test_runner.gd        테스트 러너 (~150 assertions)
│       ├── test_timeline_system.gd  타임라인 테스트
│       └── QA_REPORT.md          QA 리포트
├── resources/
│   ├── cards/                    카드 .tres 파일 (10종)
│   ├── characters/               캐릭터 .tres 파일 (6종)
│   └── maps/
└── assets/
    ├── sprites/
    ├── fonts/
    └── audio/
```

---

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-02-09 | 초기 아키텍처 설계 및 프로젝트 구조 생성 |
| 2026-02-09 | 그리드 시스템 구현 (BFS, 사거리 패턴, 시야선) |
| 2026-02-09 | 전투/카드/타임라인 시스템 구현 |
| 2026-02-09 | UI 씬 및 스크립트 구현 |
| 2026-02-09 | QA 테스트 작성, 버그 3건 수정 |
| 2026-02-09 | get_path → get_grid_path 이름 충돌 수정 |
| 2026-02-09 | mouse_filter 수정, 카드 타겟팅 시스템 추가 |
| 2026-02-09 | CardRegistry 추가, DirAccess→정적 레지스트리 전환 (웹 빌드 호환) |
| 2026-02-09 | 전투 UI 전면 개편: 타임라인 바 visibility 수정, 2:1 타일 비율, 좌하단 캐릭터 정보 (에너지/드로우/무덤 통합), 우측 턴 종료/무덤 버튼, 카드 드로우/버리기 애니메이션, 무덤 팝업, 상단 2줄 벽 타일, 캐릭터 standing 오프셋 |
| 2026-02-09 | **버그 수정 4건**: (1) 타임라인 바 size 폴백 + minimum_size 설정 (2) 5개 파일에 `_exit_tree()` 시그널 disconnect 추가 (시그널 누적 방지) (3) `_slide_character()`에서 `movement_started` 시그널 emit 추가 (Push/Pull 애니메이션) (4) `_apply_summon()`에서 `GridManager.place_character()` 호출 + `summon_added` 시그널 추가 |
| 2026-02-09 | **신규 기능 2건**: (1) 동료 합류 이벤트 — COMPANION 맵 노드, `get_companion_choices()`, `recruit_companion()`, 이벤트 화면 동료 선택 UI (2) 난이도/승천 시스템 — `difficulty` 0-20, `get_difficulty_modifiers()`, `_apply_difficulty_modifiers()`, 타이틀 화면 난이도 슬라이더, 보스 클리어 시 해금 |
| 2026-02-09 | **카드 아키타입 검증**: 전용 에이전트가 warrior_shield_strike.tres 생성, 마법사 8장 원소 필드 수정, 로그 2장 콤보 필드 수정, 소환 카드 2장 수정 |
| 2026-02-09 | **UX 개선 4건**: (1) 타임라인 바 lerp 기반 연속 애니메이션 (우측=곧 행동, 좌측=방금 행동, 결승선, 리셋) (2) 이동 완료 후 이동 범위 미표시 (`has_moved_this_turn` / ROOT 체크) (3) AREA 카드 타겟팅 시 AOE 영향 범위 주황색 미리보기 (4) 오버월드 맵 마우스 휠 가로 스크롤 지원 |
