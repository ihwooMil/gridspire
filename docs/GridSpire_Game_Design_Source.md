# GridSpire - Tactical Deckbuilding RPG 게임 설계 문서

## 1. 게임 개요

**GridSpire**는 Godot 4.4 (GDScript) 기반의 택티컬 덱빌딩 RPG이다. Slay the Spire의 덱빌딩 + 로그라이크 구조와, Final Fantasy Tactics / Into the Breach의 그리드 기반 전투를 결합한 모바일/웹 게임이다.

### 핵심 게임 루프

```
타이틀 화면 → 캐릭터 선택 → 오버월드 맵 탐색 → 전투/이벤트/상점 → 보상 → 맵 탐색 → ... → 보스 전투 → 런 종료
```

### 기술 스택
- **엔진**: Godot 4.4 stable, GL Compatibility 렌더러
- **언어**: GDScript (정적 타이핑 사용)
- **데이터 모델**: Godot Resource 클래스 (.tres 파일)
- **배포**: Web (GitHub Pages), Docker CI/CD (`barichello/godot-ci:4.4`)
- **해상도**: 1280x720 기준

---

## 2. 시스템 아키텍처

### 2.1 전체 구조

GridSpire는 **시그널 기반 느슨한 결합** 아키텍처를 사용한다. 시스템 간 직접 참조 대신 Godot 시그널로 통신하며, 전역 매니저는 Autoload 싱글톤 패턴으로 등록된다.

```
┌──────────────────────────────────────────────────────┐
│                    씬 트리                             │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐ │
│  │  GridVisual  │  │  BattleHUD  │  │ BattleResult │ │
│  │  (Node2D)   │  │  (Control)  │  │  (Control)   │ │
│  └──────┬──────┘  └──────┬──────┘  └──────────────┘ │
│         │                │                            │
│         │    시그널 기반 통신                          │
│         ▼                ▼                            │
│  ┌─────────────────────────────────────────────────┐ │
│  │              Autoload Singletons                 │ │
│  │  GameManager  BattleManager  GridManager         │ │
│  │  SceneManager  DeckManager                       │ │
│  └─────────────────────────────────────────────────┘ │
│                        │                              │
│                        ▼                              │
│  ┌─────────────────────────────────────────────────┐ │
│  │         데이터 모델 (Resource 클래스)              │ │
│  │  CharacterData  CardData  CardEffect  GridTile   │ │
│  │  BattleState  TimelineEntry  MapData  MapNode    │ │
│  └─────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

### 2.2 Autoload 싱글톤

| 싱글톤 | 역할 |
|--------|------|
| **GameManager** | 게임 상태 관리, 파티 로스터, 골드, 맵 데이터, 난이도/승천 시스템 |
| **SceneManager** | 씬 전환 관리 |
| **BattleManager** | 전투 흐름 제어, 턴 관리, 카드 플레이, 승리/패배 판정, 소환수 관리 |
| **GridManager** | 그리드 좌표 관리, BFS 경로탐색, 사거리 계산, 이동, 밀기/끌기 |
| **DeckManager** | 덱 셔플, 드로우, 디스카드, 무덤 관리 (캐릭터별) |

### 2.3 설계 원칙

1. **시그널 기반 느슨한 결합**: 시스템 간 직접 참조 대신 시그널로 통신
2. **Autoload 싱글톤 패턴**: 전역 매니저들은 Godot autoload로 등록
3. **Resource 데이터 모델**: 캐릭터/카드 데이터는 Resource 클래스로 정의, `.tres`로 저장
4. **UI와 로직 분리**: BattleManager가 게임 로직, UI는 시그널을 구독하여 표시만 담당
5. **_exit_tree() 시그널 해제 패턴**: 싱글톤에 connect한 시그널은 반드시 _exit_tree()에서 is_connected() 확인 후 disconnect

---

## 3. 게임 상태 흐름

### 3.1 GameState 열거형

```
MAIN_MENU → CHARACTER_SELECT → MAP → BATTLE → REWARD → MAP → ... → BOSS → GAME_OVER
                                 ↓       ↓
                               SHOP    EVENT
```

| 상태 | 설명 |
|------|------|
| MAIN_MENU | 타이틀 화면, 난이도 선택 |
| CHARACTER_SELECT | 캐릭터 선택 (Warrior / Mage / Rogue) |
| MAP | 오버월드 맵 탐색, 노드 선택 |
| BATTLE | 그리드 전투 진행 |
| REWARD | 전투 승리 보상 (카드 선택) |
| SHOP | 카드 구매/제거, 스탯 업그레이드 |
| EVENT | 이벤트 (동료 합류, 보물, 미스터리) |
| GAME_OVER | 런 종료 |

### 3.2 난이도/승천 시스템

Slay the Spire의 Ascension 시스템과 유사. 난이도 0(Normal) ~ 20.

| 난이도 | 효과 |
|--------|------|
| 1+ | 적 HP ×1.1 |
| 3+ | 적 공격력 ×1.1 |
| 5+ | 시작 골드 80 (기본 100) |
| 7+ | 시작 HP -5 패널티 |
| 10+ | 엘리트 +1 추가 배치 |
| 13+ | 적 HP ×1.25 |
| 16+ | 적 공격력 ×1.25 |
| 18+ | 보스 HP ×1.5 |
| 20 | 시작 HP -10 패널티 |

보스 클리어 시 `max_unlocked_difficulty = min(difficulty + 1, 20)` 해금.

---

## 4. 캐릭터 시스템

### 4.1 CharacterData (Resource 클래스)

모든 캐릭터(플레이어, 적, 소환수)는 동일한 `CharacterData` 리소스를 사용한다.

#### 기본 스탯

| 필드 | 타입 | 설명 |
|------|------|------|
| id | String | 고유 식별자 |
| character_name | String | 표시 이름 |
| faction | Faction | PLAYER / ENEMY / NEUTRAL |
| max_hp | int | 최대 HP |
| current_hp | int | 현재 HP |
| speed | int | 속도 (낮을수록 먼저 행동) |
| energy_per_turn | int | 턴당 에너지 |
| move_range | int | 이동 범위 (타일 수) |
| grid_position | Vector2i | 그리드 위치 (런타임) |
| starting_deck | Array[CardData] | 시작 덱 |

#### 영구 업그레이드 필드

| 필드 | 설명 |
|------|------|
| bonus_max_hp | 최대 HP 보너스 |
| bonus_strength | 공격력 보너스 |
| bonus_energy | 에너지 보너스 |
| bonus_move_range | 이동 범위 보너스 |
| bonus_speed | 속도 보너스 |
| max_summons | 최대 소환 수 (기본 2) |

#### 런타임 전투 상태

| 필드 | 설명 |
|------|------|
| status_effects | Dictionary (StatusEffect → {stacks, duration}) |
| element_stacks | Dictionary (원소 이름 → 스택 수) |
| cards_played_this_turn | Array[CardData] (콤보 추적) |
| active_summons | Array[CharacterData] |
| is_summon | bool |
| summon_owner | CharacterData |

### 4.2 플레이어 캐릭터 3종

#### Warrior (워리어) — 방어→반격 아키타입

| 스탯 | 값 |
|------|-----|
| HP | 60 |
| Speed | 100 |
| Energy | 3 |
| Move | 3 |

**핵심 메커니즘**: SHIELD 효과로 방어를 쌓은 뒤, SHIELD_STRIKE 효과로 방패 스택 기반 데미지를 가한다.
- `shield_damage_multiplier` 필드로 방패→데미지 변환 비율 조절
- 높은 HP와 균형 잡힌 공격력으로 전선을 유지하는 탱커 역할

**시작 덱 (10장)**:
- Strike ×2 (1d4+1 damage)
- Defend ×2 (1d6 shield)
- Cleave ×1 (area damage)
- Heavy Blow ×1 (2d6 damage)
- Shield Bash ×1 (1d4+1 damage + 1d4+1 shield)
- Battle Cry ×1 (strength buff)
- Iron Will ×1 (shield + heal)
- Pommel Strike ×1 (damage + draw)

**주요 카드 설계 패턴**:
- Shield Bash: 데미지와 방어를 동시에. 비용 1, 사거리 1
- Body Slam (SHIELD_STRIKE): 현재 방패 스택만큼 데미지. 방어를 공격으로 전환
- Shield Crusher: 높은 방패→데미지 배율의 대형 공격
- Iron Defense / Bulwark Slam / Phalanx: 방어 특화 카드군
- Rage / Reckless Strike / Berserker Cleave: BERSERK 상태 활용 (공격력 +2/스택, 방어 불가)
- Unstoppable Force / Undying Fury: 강력한 레어 카드

**아키타입 분류** (32장):
- 기본 (Core): Strike, Defend, Cleave, Heavy Blow, Shield Bash, Battle Cry, Iron Will, Pommel Strike
- 방어→반격 (Shield): Body Slam, Iron Defense, Bulwark Slam, Aegis Charge, Phalanx, Shield Crusher, Shield Wall
- 광전사 (Berserk): Rage, Reckless Strike, Savage Leap, Blood Frenzy, Berserker Cleave, Undying Fury, Berserker Rage, Bloodlust
- 유틸리티: Charge, Fortify, Ground Slam, Second Wind, Whirlwind, Rallying Shout, War Stomp, Executioner's Swing

#### Mage (마법사) — 에너지 스택 아키타입

| 스탯 | 값 |
|------|-----|
| HP | 40 |
| Speed | 80 |
| Energy | 3 |
| Move | 2 |

**핵심 메커니즘**: "에너지" 원소 스택을 축적한 뒤 일괄 소모하여 강력한 공격을 발동하는 Build-and-Burst 구조.

**에너지 스택 시스템**:
1. **축적 카드**: `element="energy"`, `element_count=1`로 플레이할 때마다 에너지 스택 +1
2. **소모 카드**: `element_cost` (특정 수 소모) 또는 `consumes_stacks` (전부 소모)
3. **스택 배율 공격**: `stack_multiplier=true` → 스택 × 주사위 굴림으로 데미지 계산
4. **일반 스케일링**: `scale_element` + `scale_per_stack`으로 스택당 가산 보너스

**시작 덱 (10장)**:
| 카드 | 비용 | 효과 | 에너지 |
|------|------|------|--------|
| Fire Bolt ×3 | 1 | 1d4 damage, SINGLE_ENEMY | +1 energy |
| Magic Intellect ×2 | 1 | Draw 2, SELF | +1 energy |
| Magic Barrier ×2 | 1 | 1d6 shield, SELF | +1 energy |
| Dark Arrow ×1 | 1 | 2d4 damage, SINGLE_ENEMY | -1 energy (소모) |
| Magic Bullet ×1 | 1 | [energy]×2d6 damage, SINGLE_ENEMY | 전부 소모 |
| Magic Explosion ×1 | 2 | [energy]×2d4 area damage (r=2), AREA | 전부 소모 |

**게임플레이 흐름**:
```
Fire Bolt(+1) → Magic Intellect(+1) → Fire Bolt(+1)
→ 에너지 3스택 축적
→ Magic Bullet: 3 × 2d6 = 평균 21 데미지 (전부 소모)
또는
→ Magic Explosion: 3 × 2d4 = 평균 15 AOE 데미지 (전부 소모)
```

**카드 .tres 파일 형식 예시** (mage_fire_bolt.tres):
```
effect_type = 0 (DAMAGE)
dice_count = 1, dice_sides = 4
element = "energy", element_count = 1
```

**카드 .tres 파일 형식 예시** (mage_magic_explosion.tres):
```
effect_type = 7 (AREA_DAMAGE)
dice_count = 2, dice_sides = 4
area_radius = 2
scale_element = "energy", stack_multiplier = true
consumes_stacks = true
```

#### Rogue (로그) — 콤보 체인 아키타입

| 스탯 | 값 |
|------|-----|
| HP | 45 |
| Speed | 70 (가장 빠름) |
| Energy | 3 |
| Move | 4 (가장 넓음) |

**핵심 메커니즘**: 카드에 태그를 부여하고, 후속 카드가 선행 태그를 확인하여 보너스를 받는 콤보 체인 시스템.

**콤보 시스템**:
1. **태그 카드**: `tags: PackedStringArray = ["quick", "strike"]` — 사용 시 태그 기록
2. **콤보 보너스**: `combo_tag="quick"`, `combo_bonus=5` — 이번 턴에 "quick" 태그가 사용되었으면 +5 데미지
3. **콤보 전용**: `combo_only=true` — 콤보 조건 미충족 시 효과 자체가 발동되지 않음
4. **태그 체크**: `CharacterData.has_tag_played(tag)` — `cards_played_this_turn`의 모든 태그 검색

**시작 덱 (10장)**:
- Quick Slash ×2 — 1d6+2 damage + Draw 1, tags: ["quick", "strike"]
- Dodge ×2 — EVASION buff, tags: ["defense"]
- Backstab ×1 — 2d6 damage, combo_tag: "quick" +5, tags: ["strike", "finisher"]
- Poison Blade ×1 — damage + poison
- Shiv ×1 — 저비용 빠른 공격
- Shadow Step ×1 — 이동 + 공격
- Sprint ×1 — 이동 범위 확장
- Throwing Knife ×1 — 원거리 공격

**콤보 체인 예시**:
```
Quick Slash (tag: "quick") → Backstab (combo_tag: "quick", +5 보너스)
→ 2d6 + 5 = 평균 12 데미지
```

**주요 보상 카드** (28장 총):
- 독/디버프: Poison Blade, Toxic Shuriken, Venomous Fang, Envenom, Toxic Cascade
- 콤보 연계: Opening Strike, Flurry, Blade Dance, Phantom Strike, Thousand Cuts
- 마무리: Death Mark, Assassinate, Coup de Grace
- 유틸리티: Preparation, Smoke Bomb, Feint, Shadow Chain, Dash Strike

### 4.3 적 캐릭터

#### 일반 적

| 캐릭터 | HP | Speed | Energy | Move | 특징 |
|--------|-----|-------|--------|------|------|
| Goblin | 30 | 90 | 2 | 2 | 기본 근접 적 |
| Slime | 35 | 120 | 2 | 1 | 느리지만 독 + 방어 |
| Skeleton Archer | 25 | 85 | 2 | 2 | 원거리 공격 |
| Bandit | 30 | 80 | 2 | 3 | 빠른 근접 |

#### 엘리트 적

| 캐릭터 | HP | 특징 |
|--------|-----|------|
| Orc Warchief | 50+ | 높은 HP, 강한 근접 |
| Dark Knight | - | 방어 + 도발 |
| Necromancer | - | 원거리 + 저주 |
| Dragon Whelp | - | AOE 공격 (화염 브레스) |

#### 보스

| 캐릭터 | 특징 |
|--------|------|
| Lich King | Death Bolt, Frost Nova, Curse of Agony, Dark Ritual, Necrotic Wave, Bone Armor, Stun Gaze (8장 덱) |

### 4.4 소환수 시스템

마법사의 SUMMON 효과로 생성. `SummonManager`가 소환수 `CharacterData`를 생성한다.

| 소환수 | HP | Speed | Energy | Move | 덱 |
|--------|-----|-------|--------|------|----|
| Fire Elemental | 15 | 90 | 2 | 2 | fire_touch ×3 |
| Ice Elemental | 20 | 110 | 2 | 1 | frost_touch ×2, ice_shield ×1 |
| Lightning Elemental | 12 | 75 | 2 | 3 | arcane_zap ×3 |
| Arcane Familiar | 10 | 70 | 1 | 3 | arcane_zap ×2 |

소환수는 독자적인 타임라인 엔트리를 가지며, 자동 AI로 행동한다 (적에게 이동 → 카드 사용). 소환수가 죽으면 소유자의 `active_summons`에서 제거되고 타임라인에서도 제거된다.

---

## 5. 카드 시스템

### 5.1 CardData (Resource 클래스)

| 필드 | 타입 | 설명 |
|------|------|------|
| id | String | 고유 식별자 |
| card_name | String | 표시 이름 |
| description | String | 설명 텍스트 |
| energy_cost | int | 에너지 비용 |
| range_min / range_max | int | 사거리 (맨해튼 거리) |
| target_type | TargetType | 타겟 유형 |
| effects | Array[CardEffect] | 효과 배열 (다중 효과 가능) |
| rarity | int | 0=common, 1=uncommon, 2=rare |
| tags | PackedStringArray | 콤보 태그 (로그용) |
| element | String | 원소 속성 (마법사용) |
| element_count | int | 플레이 시 추가할 스택 수 |
| element_cost | int | 플레이 시 소모할 스택 수 |
| consumes_stacks | bool | 전체 스택 소모 여부 |
| exhaust_on_play | bool | 사용 후 영구 소멸 (전투 내) |
| requires_berserk | bool | BERSERK 상태 필요 |

### 5.2 CardEffect (Resource 클래스)

| 필드 | 타입 | 설명 |
|------|------|------|
| effect_type | CardEffectType | 효과 유형 |
| value | int | 기본 값 (주사위 미사용 시) |
| duration | int | 버프/디버프 지속 턴 |
| status_effect | StatusEffect | 적용할 상태이상 |
| area_radius | int | 범위 효과 반경 |
| push_pull_distance | int | 밀기/끌기 거리 |
| dice_count | int | 주사위 개수 |
| dice_sides | int | 주사위 면 수 |
| dice_bonus | int | 주사위 보정값 |
| shield_damage_multiplier | float | 방패→데미지 변환 배율 (SHIELD_STRIKE용) |
| summon_id | String | 소환 대상 ID (SUMMON용) |
| scale_element | String | 원소 스케일링 대상 |
| scale_per_stack | int | 스택당 추가 값 |
| combo_tag | String | 콤보 트리거 태그 |
| combo_bonus | int | 콤보 보너스 값 |
| combo_only | bool | 콤보 전용 효과 |
| stack_multiplier | bool | 곱셈 스케일링 (스택 × 주사위) |

### 5.3 주사위 시스템

카드 효과는 고정값 또는 주사위 기반이다.

- `dice_count > 0 && dice_sides > 0` 이면 주사위 사용
- `roll()`: 각 주사위를 1~dice_sides 범위로 굴려 합산 + dice_bonus
- `get_dice_notation()`: "2d6+3" 형태의 표기법 반환
- `get_average()`: 기대값 = dice_count × (dice_sides + 1) / 2 + dice_bonus

### 5.4 CardEffectType 전체 목록

| 효과 타입 | 설명 |
|-----------|------|
| DAMAGE | 단일 대상 데미지 |
| HEAL | 힐 |
| MOVE | 이동 |
| BUFF | 아군 버프 |
| DEBUFF | 적 디버프 |
| PUSH | 밀기 |
| PULL | 끌기 |
| AREA_DAMAGE | 범위 데미지 |
| AREA_BUFF | 범위 아군 버프 |
| AREA_DEBUFF | 범위 적 디버프 |
| DRAW | 카드 드로우 |
| SHIELD | 방어막 |
| SHIELD_STRIKE | 방패 스택 기반 데미지 |
| SUMMON | 소환수 생성 |

### 5.5 TargetType 전체 목록

| 타겟 타입 | 설명 | 타겟팅 방식 |
|-----------|------|-------------|
| SELF | 시전자 자신 | 자동 발동 |
| SINGLE_ALLY | 단일 아군 | 수동 (녹색 범위) |
| SINGLE_ENEMY | 단일 적 | 수동 (빨간 범위) |
| ALL_ALLIES | 모든 아군 | 자동 발동 |
| ALL_ENEMIES | 모든 적 | 자동 발동 |
| TILE | 단일 타일 | 수동 (빨간 범위) |
| AREA | 범위 타일 | 수동 (빨간 범위 + 주황 AOE 미리보기) |
| NONE | 타겟 없음 | 자동 발동 |

### 5.6 데미지 계산 공식

```
base_damage = effect.roll() 또는 effect.value
  + source.get_status_stacks(STRENGTH)
  + source.bonus_strength
  + source.get_status_stacks(BERSERK) × 2
  + _get_scaling_bonus()   ← 원소 스택 × scale_per_stack
  + _get_combo_bonus()     ← 콤보 태그 보너스

if source has WEAKNESS:
  damage × 0.75

→ target.take_damage(damage)
  EVASION 체크: 15% × stacks (최대 75%), 회피 시 스택 -1
  SHIELD 먼저 소모
  남은 데미지 → current_hp 감소
```

**스택 배율 계산** (`stack_multiplier=true` 일 때):
```
base_damage = stacks × effect.roll()
```
예: 에너지 3스택, 2d6 효과 → 3 × (2d6 굴림결과) = 3 × 7(평균) = 21

### 5.7 카드 레지스트리

`CardRegistry`는 모든 카드/업그레이드의 경로를 정적 Dictionary로 관리한다. 이는 Godot Web Export에서 `DirAccess`로 PCK 내부 파일을 열거할 수 없는 제약을 우회하기 위함이다.

현재 카드 수:
- Warrior: 32장
- Mage: 6장 (에너지 스택 재설계 완료)
- Rogue: 28장
- 업그레이드: 7종

---

## 6. 전투 시스템

### 6.1 전투 흐름

```
BattleManager.start_battle(players, enemies)
    ├── BattleState 생성
    ├── TimelineSystem 초기화
    ├── DeckManager.initialize_all_decks()
    ├── battle_started 시그널
    └── _next_turn()
         │
         ├── check_battle_result() → "win" / "lose" → _end_battle()
         │
         ├── timeline.advance() → 현재 캐릭터 (가장 낮은 tick)
         │
         ├── STUN 체크 → 스턴 시 턴 스킵
         ├── 독/재생 적용 (턴 시작 효과)
         ├── 위험 타일 데미지 (5 고정)
         │
         ├── [PLAYER 턴] _start_player_turn()
         │   ├── 에너지 = energy_per_turn + bonus_energy
         │   ├── draw_cards(5)
         │   ├── 플레이어 입력 대기
         │   │   ├── play_card() → 효과 해결 → 카드 디스카드/소멸
         │   │   ├── move_character() → BFS 이동 (턴당 1회)
         │   │   └── end_turn() → 남은 핸드 디스카드 → _finish_turn()
         │   └── _finish_turn() → tick += effective_speed → _next_turn()
         │
         ├── [ENEMY 턴] _start_enemy_turn()
         │   ├── draw_cards(3)
         │   ├── AI: 가장 가까운 플레이어 쪽으로 이동
         │   ├── AI: 사거리 내 카드 순차 사용
         │   └── _finish_turn()
         │
         └── [SUMMON 턴] _start_summon_turn()
             ├── draw_cards(3)
             ├── AI: 가장 가까운 적 쪽으로 이동
             ├── AI: 카드 사용
             └── _finish_turn()
```

### 6.2 타임라인 (턴 순서) 시스템

FFX (Final Fantasy X)의 CTB (Conditional Turn-Based) 시스템을 차용.

**원리**:
- 각 캐릭터는 `current_tick` 값을 가짐
- 가장 낮은 tick의 캐릭터가 다음 턴
- 행동 후: `tick += effective_speed`
- `effective_speed = speed × haste(0.75) × slow(1.5)`
- 낮은 speed = 더 빠른 행동 (적은 tick 증가)

**타임라인 바 UI**:
- 화면 상단 가로 바
- 우측(1.0) = 곧 행동 (낮은 tick), 좌측(0.0) = 방금 행동 (높은 tick)
- 마커가 lerp 기반으로 부드럽게 이동
- 행동 시 마커가 우측 끝(결승선)에 도달 → 좌측으로 리셋
- 턴 진행 중에는 애니메이션 일시정지

**미리보기**: tick 값을 복사하여 시뮬레이션, 원본 데이터 변경 없음

### 6.3 카드 타겟팅 흐름

```
[카드 클릭 또는 드래그 시작]
    │
    ├── SELF / NONE / ALL_* → 즉시 발동 (auto-target)
    │   └── BattleManager.play_card(card, source, source)
    │
    └── SINGLE_ENEMY / SINGLE_ALLY / TILE / AREA
        │
        ├── BattleHUD.targeting_requested 시그널
        ├── GridVisual.enter_targeting_mode(card, source)
        │   ├── 사거리 하이라이트 표시
        │   │   ├── 적 대상: 빨간색 (COLOR_ATTACK_RANGE)
        │   │   └── 아군 대상: 녹색 (COLOR_ALLY_RANGE)
        │   └── AOE 카드: 호버 시 주황색 영향 범위 미리보기
        │
        ├── [좌클릭 유효 타겟] → target_selected 시그널 → play_card()
        ├── [좌클릭 무효 위치] → 타겟팅 취소
        └── [우클릭] → 타겟팅 취소
```

**카드 드래그-드롭**:
1. CardUI에서 드래그 시작 → card_drag_started → BattleHUD → targeting_requested
2. 드래그 중: card_drag_moved → drag_hover_updated → grid_container.update_drag_hover()
   - AOE 미리보기 자동 업데이트
3. 드롭: card_drag_dropped → drag_drop_requested → battle_scene._on_drag_drop()
   - auto-target 카드: 카드 핸드 영역 위에 드롭하면 발동
   - manual-target 카드: 드롭 위치의 그리드 좌표 → 유효 타겟 확인 → play_card()

### 6.4 카드 효과 해결 순서

```
CardEffectResolver.resolve_card(card, source, target):
    1. 원소 스택 추가 (element, element_count)
       - element == "all" → fire, ice, lightning 모두 추가
    2. 각 effect에 대해 apply_effect() 실행
       - combo_only 체크 → 미충족 시 스킵
       - effect_type별 로직 분기
    3. cards_played_this_turn에 카드 기록 (콤보 추적용)
    4. element_cost > 0이면 해당 원소 스택 차감
    5. consumes_stacks == true이면 모든 원소 스택 소거
```

### 6.5 상태이상 (StatusEffect)

| 상태 | 효과 | 지속 |
|------|------|------|
| STRENGTH | 공격 데미지 +stacks | duration 턴 |
| WEAKNESS | 공격 데미지 ×0.75 | duration 턴 |
| HASTE | 속도 ×0.75 (빨라짐) | duration 턴 |
| SLOW | 속도 ×1.5 (느려짐) | duration 턴 |
| SHIELD | 데미지 흡수 | duration 턴 또는 소모 시 |
| POISON | 턴 시작 시 stacks 데미지 | duration 턴 |
| REGEN | 턴 시작 시 stacks 힐 | duration 턴 |
| STUN | 턴 스킵 (stacks -1) | 즉시 소모 |
| ROOT | 이동 불가 | duration 턴 |
| BERSERK | 공격 +2/스택, 방패 획득 불가 | duration 턴 |
| EVASION | 15%/스택 회피 (최대 75%), 회피 시 -1 | 소모형 |

---

## 7. 그리드 시스템

### 7.1 그리드 구조

- **저장 방식**: `Dictionary[Vector2i, GridTile]` — 해시맵
- **타일 크기**: 2:1 비율 (가로:세로), battle_scene.gd에서 동적 계산
- **좌표계**: (0,0) = 좌상단
- **기본 크기**: 10×8 (인카운터 설정에 따라 변동)

### 7.2 타일 타입

| 타입 | 통과 | 점유 | 설명 |
|------|------|------|------|
| FLOOR | O | O | 기본 바닥 (체커보드 패턴) |
| WALL | X | X | 벽 (시야선 차단) |
| PIT | X | X | 구덩이 |
| HAZARD | O | O | 위험 타일 (턴 시작 시 5 데미지) |
| ELEVATED | O | O | 높은 지형 |

### 7.3 좌표 변환

```
grid_to_world(grid_pos) = Vector2(grid_pos) × tile_size + tile_size × 0.5
world_to_grid(world_pos) = Vector2i((world_pos / tile_size).floor())
```

### 7.4 경로 탐색

**BFS (너비 우선 탐색)**:
- WALL, PIT, 점유 타일은 통과 불가
- 목적지가 점유된 경우는 허용 (타겟팅용)
- 이동 비용은 균일 (1 per tile)
- 4방향 직교 이동만 (대각선 없음)

### 7.5 사거리 패턴

| 패턴 | 설명 |
|------|------|
| DIAMOND | 표준 맨해튼 거리 (기본) |
| LINE | 4방향 직선 (벽에서 차단) |
| CROSS | + 모양 (벽 무시) |
| AREA | 정사각형 영역 |

### 7.6 강제 이동 (Push/Pull)

- `push_character(source, target, distance)`: 시전자로부터 멀어지는 방향으로 밀기
- `pull_character(source, target, distance)`: 시전자 쪽으로 끌기
- `_slide_character()`: 방향으로 한 칸씩 이동, 벽/점유 타일에서 정지
- `movement_started` 시그널 발생 → 이동 애니메이션 재생

### 7.7 시야선 (Line of Sight)

- Bresenham 방식 스텝핑
- WALL 타일이 경로상에 있으면 시야 차단

---

## 8. 덱 관리 시스템

### 8.1 구조

캐릭터별로 3개의 카드 더미를 관리:

| 더미 | 설명 |
|------|------|
| draw_pile | 드로우 파일 (셔플된 상태) |
| discard_pile | 디스카드 (버린 카드) |
| exhaust_pile | 소멸 (전투 중 영구 제거) |

### 8.2 드로우 흐름

```
draw_cards(character, count):
    반복 count번:
        draw_pile 비었으면:
            discard_pile → draw_pile로 합침
            셔플
        draw_pile에서 1장 pop
    cards_drawn 시그널 emit
```

### 8.3 보상/상점 덱 수정

- `add_card_to_deck(character, card)` — starting_deck에 추가 (영구)
- `remove_card_from_deck(character, card)` — starting_deck에서 제거 (영구)

보상 흐름:
```
전투 승리 → REWARD state → RewardScreen
    ├── CardRegistry.get_class_cards(class_id) — 해당 클래스 카드풀
    ├── 레어리티 가중치: Common ×3, Uncommon ×2, Rare ×1
    ├── 3장 고유 카드 선택지 표시
    ├── [카드 선택] → DeckManager.add_card_to_deck()
    └── [Skip] → 카드 미추가
```

---

## 9. 오버월드 맵

### 9.1 맵 생성 (MapGenerator)

Slay the Spire 스타일 절차적 맵 생성.

- **총 16행** (0=START, 1-14=generated, 15=BOSS)
- **행당 2-4개 노드** (시드 기반 RNG)
- **연결**: 인접 행 간 교차 없는 연결, 모든 노드 도달 가능 보장

### 9.2 맵 노드 타입

| 노드 | 설명 | 분포 |
|------|------|------|
| START | 시작점 | 행 0, 1개 |
| BATTLE | 일반 전투 | 초반에 집중 |
| ELITE | 강화 전투 | 중후반에 증가 |
| SHOP | 상점 | 중반 이후 |
| REST | 휴식 (HP 회복) | 행 12 강제 배치 |
| EVENT | 이벤트 | 전반에 분산 |
| COMPANION | 동료 합류 | 행 3-6, 파티<3명일 때 |
| BOSS | 보스 전투 | 행 15, 1개 |

### 9.3 행별 노드 분포

- **초반 (1-4)**: 전투 70%, 이벤트 20%, 엘리트 10%
- **중반 (5-9)**: 전투 30%, 엘리트 20%, 이벤트 20%, 상점 10%, 휴식 10%
- **후반 (10-11)**: 전투 30%, 엘리트 30%, 휴식 20%, 상점 10%
- **행 12**: 무조건 휴식 (보스 전 회복)
- **행 13-14**: 엘리트 40%, 전투 40%, 휴식 10%

### 9.4 동료 합류 이벤트

- 맵 생성 시 파티가 3명 미만이면 행 3-6에 COMPANION 노드 1개 배치
- EVENT 노드를 우선 변환, 없으면 BATTLE 노드를 변환
- `GameManager.get_companion_choices()`: 파티에 없는 클래스 반환
- `GameManager.recruit_companion(id)`: 해당 클래스 캐릭터 생성 및 파티 추가

### 9.5 맵 UI

- `ScrollContainer` 기반 가로 스크롤
- 마우스 휠 상/하 → 가로 스크롤 변환 (전용 `MapScrollContainer` 스크립트)
- `MapNodeButton`: 노드 타입별 색상/아이콘, 방문/도달가능/잠김 상태별 스타일
- `MapLineDrawer`: 노드 간 연결선 렌더링

---

## 10. 전투 UI 레이아웃

### 10.1 화면 구성 (1280×720)

```
┌──────────────────────────────────────────────────────────────┐
│ [턴 이름 라벨]     [═══ 타임라인 바 ═══════════════════]     │  상단
├──────────────────────────────────────────────────────────────┤
│                                                              │
│                    그리드 (2:1 타일)                          │
│                  [상단 2줄: 벽 장식]                          │  중앙
│                  [캐릭터 스프라이트]                          │
│                  [하이라이트 오버레이]                        │
│                                                     [End]   │
│                                                     [Turn]  │
│                                                     [Grave] │
├──────────────────────────────────────────────────────────────┤
│ ┌────────┐                                                   │
│ │ 캐릭터 │    [  카드 1  ] [  카드 2  ] [  카드 3  ]         │  하단
│ │ 정보   │    [  부채꼴 핸드 배치  ]                         │
│ └────────┘                                                   │
└──────────────────────────────────────────────────────────────┘
```

### 10.2 mouse_filter 설계

UI가 전체 화면을 덮지만 그리드 클릭을 차단하지 않도록:
- **IGNORE (2)**: BattleHUD, TopBar, CardHand, TimelineBar — 마우스 이벤트 통과
- **STOP (0)**: EndTurnButton, CardUI, CharacterInfo — 클릭 수신

GridVisual은 `_unhandled_input()`으로 UI가 처리하지 않은 마우스 이벤트를 수신한다.

### 10.3 카드 핸드 UI

- **부채꼴 배치**: 원호 반경 600px, 최대 30도 펼침
- **카드 크기**: 120×170px
- **드로우 애니메이션**: 좌하단(CharInfo 방향)에서 날아옴, 0.35초, EASE_OUT + TRANS_BACK
- **디스카드 애니메이션**: 카드가 무덤 버튼 쪽으로 날아가며 축소
- **드래그**: 클릭으로 선택 또는 드래그로 타겟 지정

### 10.4 그리드 비주얼 하이라이트

| 색상 | 용도 | 조건 |
|------|------|------|
| 파란색 (0.2, 0.5, 0.9, 0.3) | 이동 범위 | 캐릭터 선택 시 (이미 이동했거나 ROOT면 표시 안 함) |
| 빨간색 (0.9, 0.2, 0.2, 0.25) | 공격 범위 | 적 대상 카드 타겟팅 시 |
| 녹색 (0.2, 0.7, 0.3, 0.25) | 아군 범위 | 아군 대상 카드 타겟팅 시 |
| 주황색 (1.0, 0.5, 0.1, 0.35) | AOE 미리보기 | AREA 카드 타겟팅 중 호버 시 |
| 하늘색 (0.3, 0.7, 1.0, 0.5) | 경로 미리보기 | 이동 가능 타일 호버 시 (BFS 경로) |
| 노란색 (1.0, 0.9, 0.3, 0.4) | 선택된 타일 | 타일 클릭 시 |
| 흰색 (1.0, 1.0, 1.0, 0.15) | 호버 | 마우스 호버 |

### 10.5 캐릭터 정보 패널 (좌하단)

- 이름, HP 바, 에너지 표시
- 드로우 파일/무덤 카운트
- 상태이상 뱃지 (아이콘 + 스택 수)

### 10.6 데미지/힐 팝업

- 캐릭터 위치에서 위로 날아가는 숫자
- 데미지: 빨간색 + 빨간 스프라이트 플래시 (0.3초)
- 힐: 녹색 + 녹색 스프라이트 플래시 (0.3초)

---

## 11. 시그널 맵

### 11.1 BattleManager 시그널

| 시그널 | 인자 | 구독자 |
|--------|------|--------|
| battle_started() | - | BattleHUD, TimelineBar |
| battle_ended(result) | String | BattleHUD, CardHand, BattleResult |
| turn_started(character) | CharacterData | BattleHUD, CardHand, TimelineBar |
| turn_ended(character) | CharacterData | CardHand, TimelineBar |
| card_played(card, src, tgt) | CardData, CharacterData, Variant | BattleHUD |
| character_damaged(ch, amt) | CharacterData, int | BattleScene (팝업 + 플래시) |
| character_healed(ch, amt) | CharacterData, int | BattleScene (팝업 + 플래시) |
| character_died(ch) | CharacterData | BattleScene (스프라이트 제거) |
| energy_changed(cur, max) | int, int | BattleHUD |
| hand_updated(hand) | Array[CardData] | CardHand |
| timeline_updated() | - | TimelineBar |
| summon_added(summon, owner) | CharacterData, CharacterData | BattleScene |

### 11.2 GridManager 시그널

| 시그널 | 인자 | 구독자 |
|--------|------|--------|
| grid_initialized(w, h) | int, int | GridVisual |
| character_moved(ch, from, to) | CharacterData, Vector2i, Vector2i | GridVisual |
| tile_changed(pos, tile) | Vector2i, GridTile | GridVisual |
| movement_started(ch, path) | CharacterData, Array[Vector2i] | GridVisual (애니메이션) |
| movement_finished(ch) | CharacterData | GridVisual |

### 11.3 DeckManager 시그널

| 시그널 | 인자 | 구독자 |
|--------|------|--------|
| cards_drawn(ch, cards) | CharacterData, Array[CardData] | - |
| cards_discarded(ch, cards) | CharacterData, Array[CardData] | BattleHUD |
| deck_shuffled(ch) | CharacterData | - |
| card_added_to_deck(ch, card) | CharacterData, CardData | - |
| card_removed_from_deck(ch, card) | CharacterData, CardData | - |

### 11.4 UI 시그널

| 시그널 | 발신 | 수신 |
|--------|------|------|
| targeting_requested(card, source) | BattleHUD | BattleScene → GridVisual |
| drag_drop_requested(card, source, pos) | BattleHUD | BattleScene |
| drag_hover_updated(screen_pos) | BattleHUD | BattleScene → GridVisual |
| target_selected(card, src, tgt) | GridVisual | BattleScene → BattleManager |
| targeting_cancelled() | GridVisual | - |
| character_selected(ch) | GridVisual | - |
| character_deselected() | GridVisual | - |
| card_selected(card) | CardHand | BattleHUD |

---

## 12. 적 AI 시스템

### 12.1 적 턴 흐름

1. 3장 드로우
2. 가장 가까운 플레이어 쪽으로 이동 (이미 인접하면 안 이동)
3. 에너지가 허용하는 한 카드 순차 사용
4. 남은 핸드 디스카드

### 12.2 타겟 선택 로직

| 카드 타입 | AI 로직 |
|-----------|---------|
| SINGLE_ENEMY (적 기준 플레이어) | 사거리 내 첫 번째 생존 플레이어 |
| SINGLE_ALLY (적 기준 아군) | HP가 가장 낮은 생존 아군 |
| AREA/TILE | 가장 많은 플레이어를 포함하는 타일 |
| SELF/NONE/ALL_* | 자동 사용 |

### 12.3 소환수 AI

소환수는 적 AI와 유사하지만, 타겟이 반대:
- 가장 가까운 적(ENEMY)을 향해 이동
- SINGLE_ENEMY → 적 대상
- SINGLE_ALLY → 아군(PLAYER) 대상 (힐/버프)

---

## 13. 캐릭터 스프라이트 시스템

### 13.1 구조

- `grid_visual.gd`의 `sprite_sheets` Dictionary에 스프라이트 시트 정의
- `character_name`으로 매핑: "Mage" → walk, cast, kneel 애니메이션

### 13.2 스프라이트 시트 형식

```gdscript
sprite_sheets = {
    "Mage": {
        "walk": { "path": "res://res/Seo-A-walk.png", "cols": 5, "rows": 5, "frame_count": 25, "fps": 12.0 },
        "cast": { "path": "res://res/mage-cast.png", ... },
        "kneel": { "path": "res://res/mage-kneel.png", ... },
    },
}
```

### 13.3 애니메이션

- **idle**: walk 시트의 첫 프레임
- **walk**: 이동 시 재생, 이동 방향에 따라 flip_h
- **cast**: (현재 미사용, 카드 사용 시 연결 가능)
- **kneel**: (현재 미사용, 저HP 시 연결 가능)

### 13.4 스프라이트 없는 캐릭터

스프라이트 시트가 없는 캐릭터는 원형 플레이스홀더로 표시:
- 플레이어: 파란색 원
- 적: 빨간색 원
- 중립: 회색 원
- 원 안에 이름 첫 글자 표시

### 13.5 이동 애니메이션

- `_start_movement_animation()`: 경로를 따라 lerp 기반 이동
- `move_speed = 250.0` px/s
- 각 타일 간 진행률 0→1로 보간
- 완료 시 `movement_finished` 시그널 + idle 애니메이션 복귀

### 13.6 스프라이트 플래시

`flash_character(character, flash_color, duration)`:
- `sprite.modulate = flash_color` → Tween으로 `Color.WHITE`로 복귀
- 데미지: 빨간색 (1.0, 0.3, 0.3), 힐: 녹색 (0.3, 1.0, 0.3)

---

## 14. 전투 씬 구성

### 14.1 battle_scene.gd

전투 씬 진입점. `GameManager.current_encounter`에서 인카운터 데이터를 읽어 전투를 구성한다.

#### 그리드 설정
- 타일 크기: 2:1 비율, 화면에 맞게 동적 계산
- 상단 2줄: 벽 타일 (장식)
- 장애물: 시드 기반 RNG로 벽 2-4개 + 위험 타일 1개 배치
- 플레이어: 왼쪽 (col=1), 적: 오른쪽 (col=grid_w-2)

#### 적 생성
1. `EncounterData.enemy_ids`에서 적 ID 목록 읽기
2. `resources/characters/` 경로에서 CharacterData .tres 로드
3. `duplicate(true)`로 복사 → HP/상태 초기화
4. 적에게 덱이 없으면 `_load_enemy_deck()`으로 ID 기반 매칭
5. `_apply_difficulty_modifiers()`: 난이도에 따른 HP 배율 적용

---

## 15. 프로젝트 파일 구조

```
gridspire/
├── project.godot
├── CLAUDE.md                    프로젝트 가이드 (Claude Code용)
├── docs/
│   ├── REQUIREMENTS.md          요구사항 정의서
│   ├── DESIGN.md                설계 문서
│   └── GridSpire_Game_Design_Source.md  이 문서 (NotebookLM 소스)
├── scenes/
│   ├── battle/
│   │   └── battle_scene.tscn    전투 씬
│   ├── map/
│   │   └── overworld_map.tscn   오버월드 맵
│   ├── menu/
│   │   ├── title_screen.tscn    타이틀 화면
│   │   ├── battle_result.tscn   전투 결과
│   │   ├── event_screen.tscn    이벤트 화면
│   │   └── character_select.tscn 캐릭터 선택
│   └── ui/
│       ├── battle_hud.tscn      전투 HUD
│       ├── card_ui.tscn         카드 위젯
│       ├── card_hand.tscn       카드 핸드
│       ├── character_info.tscn  캐릭터 정보 패널
│       └── timeline_bar.tscn    타임라인 바
├── scripts/
│   ├── core/
│   │   ├── enums.gd             전역 열거형
│   │   ├── game_manager.gd      [Autoload] 게임 상태
│   │   ├── card_resource.gd     CardData 리소스
│   │   ├── card_effect_resource.gd  CardEffect 리소스
│   │   ├── character_resource.gd CharacterData 리소스
│   │   ├── grid_tile_resource.gd GridTile 리소스
│   │   ├── timeline_entry.gd    TimelineEntry 리소스
│   │   ├── battle_state.gd      BattleState
│   │   ├── card_registry.gd     정적 카드 레지스트리
│   │   └── map_generator.gd     절차적 맵 생성
│   ├── grid/
│   │   ├── grid_manager.gd      [Autoload] 그리드 로직
│   │   └── grid_visual.gd       그리드 렌더링 & 입력
│   ├── combat/
│   │   ├── battle_manager.gd    [Autoload] 전투 흐름
│   │   ├── battle_scene.gd      전투 씬 코디네이터
│   │   ├── timeline_system.gd   FFX CTB 턴 시스템
│   │   ├── card_effect_resolver.gd  카드 효과 해결
│   │   ├── combat_action.gd     액션 큐
│   │   └── summon_manager.gd    소환수 생성
│   ├── cards/
│   │   └── deck_manager.gd      [Autoload] 덱 관리
│   ├── ui/
│   │   ├── battle_hud.gd        전투 HUD
│   │   ├── card_ui.gd           카드 위젯
│   │   ├── card_hand.gd         카드 핸드 (부채꼴 배치)
│   │   ├── character_info.gd    캐릭터 정보 패널
│   │   ├── timeline_bar.gd      타임라인 바 (lerp 애니메이션)
│   │   ├── damage_popup.gd      데미지/힐 팝업
│   │   ├── overworld_map.gd     맵 화면
│   │   ├── map_scroll_container.gd  맵 스크롤 처리
│   │   ├── title_screen.gd      타이틀 화면
│   │   ├── battle_result.gd     전투 결과
│   │   ├── reward_screen.gd     보상 화면
│   │   ├── shop_screen.gd       상점 화면
│   │   ├── event_screen.gd      이벤트 화면
│   │   └── character_select.gd  캐릭터 선택 화면
│   └── tests/
│       └── test_runner.gd       테스트 러너
├── resources/
│   ├── cards/
│   │   ├── warrior/             워리어 카드 32장
│   │   ├── mage/                마법사 카드 6장
│   │   ├── rogue/               로그 카드 28장
│   │   ├── enemies/             적 카드 ~35장
│   │   └── summons/             소환수 카드
│   ├── characters/              캐릭터 .tres 14종
│   ├── maps/                    맵 데이터
│   └── upgrades/                스탯 업그레이드 7종
└── assets/
    ├── sprites/
    ├── fonts/
    └── audio/
```

---

## 16. 스탯 업그레이드 시스템

보상이나 상점에서 획득하는 영구 스탯 업그레이드.

| 업그레이드 | 효과 |
|------------|------|
| HP (Small) | max_hp + 값, current_hp + 값 |
| HP (Large) | max_hp + 값, current_hp + 값 |
| Strength | bonus_strength + 값 |
| Energy | bonus_energy + 값 |
| Move | bonus_move_range + 값 |
| Speed | bonus_speed + 값 |
| Summon | max_summons + 값 |

---

## 17. 적 캐릭터 상세 및 덱 구성

### 17.1 적 덱 배정 테이블

| 적 ID | 덱 구성 |
|--------|---------|
| goblin | goblin_slash ×2, goblin_stab, goblin_dodge, goblin_throw |
| slime | slime_acid_touch ×2, slime_shield, slime_toxic_splash, slime_ooze |
| skeleton_archer | archer_bone_arrow ×3, archer_piercing_shot, archer_quick_shot |
| bandit | bandit_slash ×2, bandit_cheap_shot, bandit_ambush, bandit_evade |
| orc_warchief | warchief_heavy_strike ×2, warchief_cleave, warchief_war_cry, warchief_iron_hide, warchief_ground_slam |
| dark_knight | dark_knight_slash ×2, dark_knight_shield_wall, dark_knight_crushing_blow, dark_knight_taunt, dark_knight_fortify |
| necromancer | necro_shadow_bolt ×2, necro_curse, necro_dark_wave, necro_bone_shield, necro_soul_sap |
| dragon_whelp | dragon_claw ×2, dragon_fire_breath, dragon_tail_swipe, dragon_wing_buffet, dragon_scale_armor, dragon_intimidate |
| lich_king | lich_death_bolt ×2, lich_frost_nova, lich_curse_of_agony, lich_dark_ritual, lich_necrotic_wave, lich_bone_armor, lich_stun_gaze |

### 17.2 폴백 로직

`_load_enemy_deck()`에서 ID 매칭 실패 시:
- "mage" 또는 "skeleton"이 이름에 포함 → 마법사 기본 덱
- 그 외 → 워리어 기본 덱

---

## 18. 핵심 설계 결정 사항

### 18.1 왜 FFX CTB 턴 시스템인가?

- 속도 스탯이 전투에 직접적 영향 → 속도 버프/디버프의 전략적 가치
- 턴 순서 미리보기로 전략 수립 가능
- Slay the Spire의 단순 턴제보다 깊이 있는 전투

### 18.2 왜 주사위 시스템인가?

- 고정 데미지보다 변동성이 있어 긴장감 제공
- Slay the Spire와 차별화되는 TRPG 느낌
- `get_average()`로 AI가 기대값 기반 판단 가능

### 18.3 왜 Resource 데이터 모델인가?

- Godot 에디터에서 직접 편집 가능 (.tres Inspector)
- `duplicate(true)`로 깊은 복사 → 인스턴스별 독립 상태
- `load(path)`로 간단히 로딩

### 18.4 왜 정적 CardRegistry인가?

- Godot Web Export에서 `DirAccess.open("res://...")`이 PCK 내부를 열거 불가
- 정적 Dictionary + `load(path)` 조합으로 모든 플랫폼에서 동작

### 18.5 왜 마법사를 에너지 스택으로 재설계했는가?

기존: 33장의 개별 원소 카드 (fire, ice, lightning) → 복잡하고 시너지 부족
현재: 6장의 에너지 축적/소모 카드 → 명확한 Build-and-Burst 패턴
- 축적 카드 (Fire Bolt, Magic Intellect, Magic Barrier): 각각 유틸리티 + 에너지 +1
- 소모 카드 (Dark Arrow, Magic Bullet, Magic Explosion): 에너지 소모하여 강력한 공격
- `stack_multiplier`로 스택 수에 비례하는 폭발적 데미지

---

## 19. 용어 사전

| 용어 | 설명 |
|------|------|
| Autoload | Godot의 전역 싱글톤 패턴 |
| Resource | Godot의 직렬화 가능 데이터 클래스 |
| .tres | Godot Resource의 텍스트 형식 파일 |
| .tscn | Godot Scene의 텍스트 형식 파일 |
| Signal | Godot의 이벤트/옵저버 패턴 구현 |
| GDScript | Godot의 내장 스크립팅 언어 |
| CTB | Conditional Turn-Based (FFX의 턴 시스템) |
| BFS | Breadth-First Search (너비 우선 탐색) |
| Manhattan Distance | |x1-x2| + |y1-y2| (격자 거리) |
| AOE | Area of Effect (범위 효과) |
| PCK | Godot의 패키지 파일 형식 |
| Tick | 타임라인 시스템의 시간 단위 |
| Stack | 상태이상/원소의 중첩 수 |
| Exhaust | 전투 중 영구 제거 (덱으로 돌아오지 않음) |
| Combo Tag | 로그의 연계 공격 조건 태그 |
| Stack Multiplier | 마법사의 곱셈 스케일링 (스택 × 주사위) |
| Element Cost | 특정 수의 원소 스택 소모 |
| Consumes Stacks | 모든 원소 스택 일괄 소모 |
