# GridSpire - Game Design Document

## 1. 개요

**장르**: 택티컬 덱빌딩 RPG (Slay the Spire + Final Fantasy Tactics)
**엔진**: Godot 4.4
**해상도**: 1280x720
**핵심 컨셉**: 그리드 기반 전투 + 덱빌딩 + 로그라이크 런 구조

---

## 2. 게임 루프

```
[타이틀] → New Game → [캐릭터 선택] → [맵] → 노드 선택 → [전투/상점/휴식/이벤트] → [보상] → [맵] → ... → [보스] → 런 클리어
                                                                                              ↓ (패배)
                                                                                        [타이틀로 복귀]
```

### 상태 전이 (GameState)
| 상태 | 설명 | 전이 조건 |
|------|------|-----------|
| MAIN_MENU | 타이틀 화면 | 게임 시작 시 |
| CHARACTER_SELECT | 캐릭터 선택 화면 | New Game 클릭 시 |
| MAP | 오버월드 맵 | 캐릭터 선택 후, 보상 후, 상점 퇴장 후 |
| BATTLE | 그리드 전투 | 맵에서 전투/엘리트/보스 노드 클릭 |
| REWARD | 보상 화면 | 전투 승리 후 |
| SHOP | 상점 화면 | 맵에서 상점 노드 클릭 |
| EVENT | 이벤트 화면 | 맵에서 이벤트 노드 클릭 |
| GAME_OVER | 게임 오버 | 전투 패배 시 (타이틀로 복귀) |

---

## 3. 오버월드 맵

### 3.1 맵 구조
- **총 16행** (Row 0 ~ Row 15)
- Row 0: START (시작점, 비표시)
- Row 1~14: 행당 2~4개 노드, 분기 경로
- Row 12: REST 고정 (보스 전 회복 보장)
- Row 15: BOSS (단일 노드)
- 좌에서 우로 스크롤 (좌우 스크롤)

### 3.2 노드 유형 (MapNodeType)
| 유형 | 아이콘 | 색상 | 설명 |
|------|--------|------|------|
| BATTLE | ! | 빨강 | 일반 전투 |
| ELITE | E | 주황 | 강화 전투 (보상 2배) |
| SHOP | $ | 초록 | 카드 구매/제거 |
| REST | R | 파랑 | 최대 HP의 30% 회복 |
| EVENT | ? | 보라 | 랜덤 이벤트 |
| BOSS | B | 진홍 | 보스 전투 |
| START | S | 회색 | 시작점 (비표시) |

### 3.3 노드 분포 규칙
| 구간 | 주요 노드 |
|------|-----------|
| Row 1~4 (초반) | BATTLE 70%, EVENT 20%, ELITE 10% |
| Row 5~9 (중반) | BATTLE 30%, ELITE 20%, EVENT 20%, SHOP 10%, REST 10% |
| Row 10~11 (후반) | BATTLE 30%, ELITE 30%, REST 20%, SHOP 20% |
| Row 12 | REST 100% (고정) |
| Row 13~14 | ELITE 40%, BATTLE 40%, REST 20% |

### 3.4 연결 규칙
- 인접 행 사이만 연결 (Row N → Row N+1)
- 교차 금지: 열 기준 정렬 후 가까운 열로만 연결
- 모든 노드는 최소 1개 이상의 연결 보장
- Row 14의 모든 노드 → Boss 연결

### 3.5 노드 시각 상태
| 상태 | 표현 |
|------|------|
| 방문 완료 | 어둡게 처리, 클릭 불가 |
| 도달 가능 | 밝게 + 노란 테두리 글로우, 클릭 가능 |
| 잠김 | 반투명, 클릭 불가 |

### 3.6 맵 UI
- **상단 바**: 층수 표시, 골드, 파티 HP 요약
- **스크롤**: 좌우 스크롤, 시작 시 좌측(현재 위치)으로 자동 스크롤

---

## 4. 전투 시스템

### 4.1 그리드
- 기본 크기: 10x8 (보스전: 12x8)
- 타일 크기: 2:1 비율 (기본 116×58), battle_scene에서 동적 계산
  - 사용 가능 영역: 가로 1190px, 세로 490px (상단 50px + 하단 180px 제외)
  - `tile_h = floor(available_h / grid_h)`, `tile_w = tile_h * 2`
- 그리드는 화면 가로 중앙에 자동 배치
- 상단 2줄 (row 0, 1)은 벽 타일 장식으로 깊이감 연출
- 캐릭터는 타일 위에 서있는 느낌 (sprite 상단 오프셋 적용)

### 4.2 타일 유형 (TileType)
| 유형 | 이동 | 시야 | 효과 |
|------|------|------|------|
| FLOOR | O | O | 없음 |
| WALL | X | X (차단) | 없음 |
| PIT | X | O | 없음 |
| HAZARD | O | O | 턴 시작 시 5 데미지 |
| ELEVATED | O | O | 없음 |

### 4.3 턴 시스템 (FFX CTB 스타일)
- 각 캐릭터는 **speed** 값 보유 (낮을수록 빠름)
- 타임라인: tick 값이 가장 낮은 캐릭터가 다음 행동
- 행동 후 tick += effective_speed
- HASTE: speed x0.75 / SLOW: speed x1.5
- **시각적 타임라인 바**: 수평 막대 위에 캐릭터 마커가 tick 값에 비례하여 위치함. 좌측=곧 행동, 우측=나중에 행동. 현재 행동 중인 캐릭터는 강조 표시.

### 4.4 턴 구조 (TurnPhase)
```
DRAW → ACTION → DISCARD → END
```
1. **DRAW**: 카드 5장 드로우 (적은 3장)
2. **ACTION**: 카드 사용 + 이동 (자유 행동)
3. **DISCARD**: 남은 손패 버림
4. **END**: 타임라인 진행

### 4.5 에너지 시스템
- 턴마다 energy_per_turn만큼 충전 (기본 3)
- 카드 사용 시 cost만큼 소모
- 이동은 무료 (턴당 1회)

### 4.6 이동
- 턴당 1회 이동 가능 (무료 행동)
- move_range 내 BFS 탐색으로 도달 가능 타일 표시
- ROOT 상태이상 시 이동 불가
- 이동 경로 프리뷰 (마우스 호버)

### 4.7 카드 타겟팅
| TargetType | 설명 | UI 동작 |
|------------|------|---------|
| SELF | 자기 자신 | 자동 사용 |
| NONE | 대상 없음 | 자동 사용 |
| SINGLE_ALLY | 아군 1명 | 수동 타겟 선택 |
| SINGLE_ENEMY | 적 1명 | 수동 타겟 선택 |
| ALL_ALLIES | 모든 아군 | 자동 사용 |
| ALL_ENEMIES | 모든 적 | 자동 사용 |
| TILE | 타일 지정 | 수동 타일 선택 |
| AREA | 범위 지정 | 수동 타일 선택 (반경 적용) |

### 4.8 전투 결과
- **승리**: 모든 적 사망 → REWARD 상태로 전이
- **패배**: 모든 아군 사망 → 패배 오버레이 표시 → MAIN_MENU로 복귀

### 4.9 적 AI
- 이동: 가장 가까운 플레이어를 향해 이동 (인접하면 이동 안함)
- 카드: 3장 드로우 → 에너지 범위 내에서 순서대로 사용
- 타겟: 사정거리 내 플레이어 우선 공격, 힐은 가장 낮은 HP 아군

---

## 5. 카드 시스템

### 5.1 카드 속성
| 속성 | 설명 |
|------|------|
| card_name | 카드 이름 |
| energy_cost | 에너지 비용 (1~5) |
| range_min / range_max | 최소/최대 사거리 (맨해튼 거리) |
| target_type | 타겟 유형 |
| effects | CardEffect 배열 (복수 효과 가능) |
| rarity | 0=Common, 1=Uncommon, 2=Rare |

### 5.2 효과 유형 (CardEffectType)
| 효과 | 설명 |
|------|------|
| DAMAGE | 단일 대상 데미지 |
| HEAL | HP 회복 |
| MOVE | 캐릭터 이동 |
| BUFF | 아군 상태이상 부여 |
| DEBUFF | 적 상태이상 부여 |
| PUSH | 밀어내기 |
| PULL | 끌어오기 |
| AREA_DAMAGE | 범위 데미지 |
| AREA_BUFF | 범위 버프 |
| AREA_DEBUFF | 범위 디버프 |
| DRAW | 카드 추가 드로우 |
| SHIELD | 실드 부여 |

### 5.3 데미지 계산
```
최종 데미지 = (기본값 + STRENGTH 스택) - SHIELD 흡수
WEAKNESS 시: 기본값 x 0.75
```

### 5.4 덱 관리
- **드로우 파일**: 셔플된 덱에서 카드 드로우
- **버림 파일**: 사용/턴종료 시 이동
- **소멸 파일**: 영구 제거 (전투 중)
- 드로우 파일 소진 → 버림 파일 셔플 후 드로우 파일로 이동

### 5.5 카드 풀
| 클래스 | 카드 수 | 예시 |
|--------|---------|------|
| Warrior | 20장 | Strike, Defend, Cleave, Heavy Blow, Shield Bash, Whirlwind... |
| Mage | 20장 | Arcane Bolt, Fireball, Frost Bolt, Healing Light, Meteor... |
| Rogue | 19장 | Quick Slash, Backstab, Poison Blade, Shadow Step, Assassinate... |
| 공용 | 10장 | Strike, Defend, Heal, Fireball, Shield Bash... |

### 5.6 주사위 기반 효과
- 카드 효과는 고정값 대신 **주사위 표기법 (NdS+B)** 을 사용
  - N = 주사위 개수, S = 면 수, B = 보너스
- 전투 중 카드 사용 시 **매번 랜덤으로 굴림**
- 카드 UI 표시 형식: `"Deal 2d6 damage"` (카드 면)
- 데미지 팝업 표시 형식: `"7 (2d6)"` (실제 결과 + 주사위 표기)
- BUFF/DEBUFF 스택은 **고정값** 유지 (주사위 미적용)
- 변환 기준표:
  | 기존 고정값 | 주사위 | 평균값 |
  |-------------|--------|--------|
  | 3~4 | 1d4+1 | 3.5 |
  | 5~6 | 1d6+2 | 5.5 |
  | 7~8 | 2d4 | 5.0 |
  | 9~12 | 2d6 | 7.0 |
  | 13+ | 3d6 | 10.5 |

### 5.7 몬스터별 전용 카드 풀

각 몬스터는 자체 전용 카드 풀을 보유하며, 전투 중 해당 풀에서 카드를 드로우한다.

**Goblin**
| 카드명 | 비용 | 효과 | 사거리 |
|--------|------|------|--------|
| Goblin Slash | 1 | 1d4+1 데미지 | 1 |
| Goblin Stab | 1 | 1d6+2 데미지 | 1 |
| Goblin Dodge | 1 | 1d4+1 실드 | SELF |
| Goblin Throw | 1 | 1d4+1 데미지 | 3 (원거리) |

**Slime**
| 카드명 | 비용 | 효과 | 사거리 |
|--------|------|------|--------|
| Acid Touch | 1 | 1d4+1 데미지 | 1 |
| Slime Shield | 1 | 1d6+2 실드 | SELF |
| Toxic Splash | 1 | 독 2스택 | 1 |
| Ooze | 1 | 슬로우 2턴 | 1 |

**Skeleton Archer**
| 카드명 | 비용 | 효과 | 사거리 |
|--------|------|------|--------|
| Bone Arrow | 1 | 1d6+2 데미지 | 4 (원거리) |
| Piercing Shot | 2 | 2d4 데미지 | 5 (원거리) |
| Quick Shot | 1 | 1d4+1 데미지 | 3 (원거리) |

**Bandit**
| 카드명 | 비용 | 효과 | 사거리 |
|--------|------|------|--------|
| Slash | 1 | 1d6+2 데미지 | 1 |
| Cheap Shot | 1 | 1d4+1 데미지 + 약화 1턴 | 1 |
| Ambush | 2 | 2d4 데미지 | 1 |
| Evade | 1 | 1d4+1 실드 | SELF |

**Orc Warchief**
| 카드명 | 비용 | 효과 | 사거리 |
|--------|------|------|--------|
| Cleave | 2 | 2d4 범위 데미지 | 1 (범위 1) |
| Heavy Strike | 2 | 2d4 데미지 | 1 |
| War Cry | 1 | 힘+2 | SELF |
| Iron Hide | 2 | 2d4 실드 | SELF |
| Ground Slam | 2 | 1d6+2 범위 데미지 + 슬로우 | 1 (범위 1) |

**Dark Knight**
| 카드명 | 비용 | 효과 | 사거리 |
|--------|------|------|--------|
| Slash | 2 | 2d4 데미지 | 1 |
| Shield Wall | 2 | 2d6 실드 | SELF |
| Crushing Blow | 2 | 2d6 데미지 | 1 |
| Taunt | 1 | 속박 1턴 | 2 |
| Fortify | 1 | 힘+1 + 1d4+1 실드 | SELF |

**Necromancer**
| 카드명 | 비용 | 효과 | 사거리 |
|--------|------|------|--------|
| Shadow Bolt | 1 | 1d6+2 데미지 | 4 (원거리) |
| Curse | 1 | 약화 2턴 | 3 |
| Dark Wave | 2 | 1d6+2 범위 데미지 | 3 (범위 1) |
| Bone Shield | 2 | 2d4 실드 | SELF |
| Soul Sap | 2 | 독 3스택 | 3 |

**Dragon Whelp**
| 카드명 | 비용 | 효과 | 사거리 |
|--------|------|------|--------|
| Claw | 2 | 2d6 데미지 | 1 |
| Fire Breath | 3 | 2d6 범위 데미지 | 2 (범위 2) |
| Tail Swipe | 2 | 2d4 데미지 + 밀기 2칸 | 1 |
| Wing Buffet | 2 | 1d6+2 범위 데미지 | 1 (범위 1) |
| Scale Armor | 2 | 2d6 실드 | SELF |
| Intimidate | 2 | 약화 2턴 (전체) | ALL_ENEMIES |

**Lich King**
| 카드명 | 비용 | 효과 | 사거리 |
|--------|------|------|--------|
| Death Bolt | 2 | 2d6 데미지 | 4 (원거리) |
| Frost Nova | 2 | 1d6+2 범위 데미지 + 슬로우 | 2 (범위 2) |
| Curse of Agony | 2 | 독 3스택, 3턴 | 3 |
| Dark Ritual | 1 | 힘+2 | SELF |
| Necrotic Wave | 3 | 2d4 범위 데미지 | 3 (범위 2) |
| Bone Armor | 2 | 2d6 실드 | SELF |
| Stun Gaze | 2 | 스턴 1턴 | 3 |

---

## 6. 캐릭터 시스템

### 6.1 캐릭터 속성
| 속성 | 설명 |
|------|------|
| max_hp / current_hp | 최대/현재 HP |
| speed | 행동 속도 (낮을수록 빠름) |
| energy_per_turn | 턴당 에너지 |
| move_range | 이동 범위 |
| faction | PLAYER / ENEMY / NEUTRAL |
| starting_deck | 시작 덱 구성 |
| status_effects | 현재 상태이상 |

### 6.2 플레이어 캐릭터
| 캐릭터 | HP | Speed | Energy | Move | 특징 |
|--------|-----|-------|--------|------|------|
| Warrior | 60 | 100 | 3 | 3 | 높은 HP, 넓은 이동, 근접 위주 |
| Mage | 40 | 80 | 3 | 2 | 낮은 HP, 빠른 속도, 원거리/범위 |
| Rogue | 45 | 70 | 3 | 4 | 높은 속도, 독/회피 특화 |

### 6.3 적 캐릭터

#### 일반 몬스터 (Normal)
| ID | 이름 | HP | Speed | Energy | Move | 특징 | 등장 구간 |
|---|---|---|---|---|---|---|---|
| goblin | Goblin | 30 | 90 | 2 | 2 | 약한 근접, 투척 가능 | Floor 1-8 |
| slime | Slime | 40 | 130 | 2 | 1 | 느린 탱커, 독/슬로우 | Floor 4-14 |
| skeleton_archer | Skeleton Archer | 20 | 85 | 2 | 2 | 유리대포, 원거리 공격 | Floor 5-14 |
| bandit | Bandit | 35 | 95 | 2 | 3 | 균형잡힌 근접, 약화 부여 | Floor 6-14 |

#### 엘리트 몬스터 (Elite)
| ID | 이름 | HP | Speed | Energy | Move | 특징 | 등장 구간 |
|---|---|---|---|---|---|---|---|
| orc_warchief | Orc Warchief | 65 | 110 | 3 | 2 | 광역 근접, 자체 강화 | Floor 1-9 |
| dark_knight | Dark Knight | 55 | 105 | 3 | 2 | 실드 특화, 속박 | Floor 6-14 |
| necromancer | Necromancer | 40 | 90 | 3 | 2 | 원거리 디버프, 독/약화 | Floor 10-14 |

#### 보스 몬스터 (Boss)
| ID | 이름 | HP | Speed | Energy | Move | 특징 |
|---|---|---|---|---|---|---|
| dragon_whelp | Dragon Whelp | 100 | 95 | 4 | 2 | 강력한 범위 공격, 높은 HP |
| lich_king | Lich King | 80 | 80 | 4 | 2 | 빠른 디버프 마스터, 스턴 |

### 6.4 시작 파티
- 게임 시작 시 **캐릭터 선택 화면**에서 **1명의 캐릭터를 선택**
- 선택 가능: Warrior, Mage, Rogue
- 추가 아군은 **이벤트를 통해 모험 중 합류** 가능
- 각 클래스별 시작 덱:
  - **Warrior**: Strike x2, Defend x2, Cleave, Heavy Blow, Shield Bash, Battle Cry, Iron Will, Pommel Strike (10장)
  - **Mage**: Arcane Bolt x2, Mana Shield x2, Fireball, Frost Bolt, Healing Light, Arcane Intellect, Spark, Chain Lightning (10장)
  - **Rogue**: Shiv x2, Dodge x2, Quick Slash, Poison Blade, Throwing Knife, Sprint, Preparation, Crippling Strike (10장)

### 6.5 스프라이트
| 캐릭터 | 스프라이트 시트 | 애니메이션 |
|--------|----------------|-----------|
| Mage | Seo-A-walk.png (5x5, 25프레임) | idle, walk |
| Mage | mage-cast.png (5x5, 25프레임) | cast |
| Mage | mage-kneel.png (5x5, 25프레임) | kneel |
| Warrior | 없음 (원형 플레이스홀더) | - |
| 적 | 없음 (원형 플레이스홀더) | - |

---

## 7. 상태이상 (StatusEffect)

| 상태 | 유형 | 효과 |
|------|------|------|
| STRENGTH | 버프 | 데미지 +스택 수 |
| WEAKNESS | 디버프 | 데미지 x0.75 |
| HASTE | 버프 | 속도 x0.75 (더 빨라짐) |
| SLOW | 디버프 | 속도 x1.5 (느려짐) |
| SHIELD | 버프 | 데미지 흡수 (스택 = 흡수량) |
| POISON | 디버프 | 턴 시작 시 스택 수만큼 데미지 |
| REGEN | 버프 | 턴 시작 시 스택 수만큼 회복 |
| STUN | 디버프 | 턴 스킵 (1스택 소모) |
| ROOT | 디버프 | 이동 불가 |

- 모든 상태이상은 스택 + 지속시간 기반
- 턴 종료 시 지속시간 -1, 0이 되면 제거

---

## 8. 보상 화면

### 8.1 보상 구성
- **골드**: 전투 종류에 따라 자동 지급
  - 일반 전투: 25g
  - 엘리트 전투: 50g
  - 보스 전투: 100g
- **카드 선택**: 3장 중 1장 선택 (또는 스킵)

### 8.2 카드 제공 규칙
- 선택한 캐릭터의 클래스 카드 풀에서 3장 제공
- 레어리티 가중치: Common 3배, Uncommon 2배, Rare 1배
- 중복 카드 이름 없음 (3장 모두 다른 카드)
- 캐릭터 탭으로 대상 선택 후 카드 선택

### 8.3 보상 후
- 선택한 카드가 해당 캐릭터의 영구 덱에 추가
- current_floor +1
- MAP 상태로 복귀

---

## 9. 상점

### 9.1 구매 (Buy)
- 모든 클래스 풀에서 랜덤 6장 표시
- 가격 (레어리티 기반):
  - Common: 50g
  - Uncommon: 75g
  - Rare: 150g
- 구매 시 해당 클래스 캐릭터의 덱에 자동 추가
- 클래스 매칭 실패 시 첫 번째 살아있는 캐릭터에게 추가

### 9.2 제거 (Remove)
- 비용: 75g
- 캐릭터 탭 선택 → 해당 캐릭터 덱 표시 → 카드 클릭으로 제거
- 영구 덱(starting_deck)에서 제거

### 9.3 상점 UI
- 상단: "SHOP" 제목 + 보유 골드
- 중앙: 구매 카드 6장 (카드 UI + 가격 버튼)
- 하단: 제거 섹션 (캐릭터 탭 + 덱 카드 표시)
- "Leave Shop" 버튼 → MAP 복귀

---

## 10. 휴식 (Rest)

- 파티 전원 **최대 HP의 30%** 회복
- 즉시 처리 (별도 화면 없음, 맵에서 인라인)
- 노드 방문 처리 후 맵 갱신

---

## 11. 이벤트 (Event)

- **현재**: 골드 15g 즉시 지급 (플레이스홀더)
- **향후 확장 예정**: 별도 이벤트 화면, 선택지 기반 보상/패널티

---

## 12. 경제 시스템

### 12.1 골드 획득
| 출처 | 금액 |
|------|------|
| 런 시작 | 100g |
| 일반 전투 | 25g |
| 엘리트 전투 | 50g |
| 보스 전투 | 100g |
| 이벤트 | 15g |

### 12.2 골드 소비
| 항목 | 비용 |
|------|------|
| Common 카드 구매 | 50g |
| Uncommon 카드 구매 | 75g |
| Rare 카드 구매 | 150g |
| 카드 제거 | 75g |

---

## 13. 씬 구조

### 13.1 메인 씬 (main.tscn)
```
Main (Node2D)
├── Camera2D (640, 360)
├── SceneContainer (Node2D)          ← SceneManager가 여기에 씬 교체
└── PersistentUI (CanvasLayer, layer=10)
    ├── GoldDisplay (Label)          ← 맵/전투/보상/상점에서 표시
    └── TransitionOverlay (ColorRect) ← 페이드 인/아웃 (0.25초)
```

### 13.2 SceneManager 씬 매핑
| GameState | 씬 경로 |
|-----------|---------|
| MAIN_MENU | scenes/menu/title_screen.tscn |
| CHARACTER_SELECT | scenes/menu/character_select.tscn |
| MAP | scenes/map/overworld_map.tscn |
| BATTLE | scenes/battle/battle_scene.tscn |
| REWARD | scenes/ui/reward_screen.tscn |
| SHOP | scenes/ui/shop_screen.tscn |
| GAME_OVER | scenes/menu/title_screen.tscn |

### 13.3 오토로드 싱글톤
| 이름 | 역할 |
|------|------|
| GameManager | 게임 상태, 파티, 골드, 맵/인카운터 관리 |
| SceneManager | 씬 전환 (페이드 트랜지션) |
| BattleManager | 전투 흐름, 턴 관리, 카드 사용 |
| GridManager | 그리드 연산, 경로 탐색, 캐릭터 배치 |
| DeckManager | 덱 관리, 드로우/버림/소멸 |

---

## 14. 전투 씬 구조 (battle_scene.tscn)
```
BattleScene (Node2D)
├── Camera2D
├── UI (CanvasLayer)
│   ├── BattleHUD
│   │   ├── TopBar (턴 이름 160px)
│   │   ├── TimelineBar (상단 바 우측, layout_mode=1)
│   │   ├── CharacterInfo (좌하단, 이름/HP/에너지/드로우/무덤/상태이상)
│   │   ├── CardHand (하단 중앙, 부채꼴 배치, 드로우 애니메이션)
│   │   ├── EndTurnButton (우측 중앙)
│   │   ├── GraveyardButton (우측, EndTurn 아래, 무덤 카운트)
│   │   └── GraveyardPopup (화면 중앙 600×400, 버린 카드 목록)
│   └── BattleResult (패배 오버레이)
└── GridContainer (Node2D, grid_visual.gd, 동적 위치 계산)
    └── 캐릭터 스프라이트들 (동적 생성, standing 오프셋)
```

---

## 15. 인카운터 설정

### 15.1 일반 전투 (Normal)
| Floor | 적 구성 (랜덤) | 보상 |
|---|---|---|
| 1-3 | Goblin x1 | 25g |
| 4-5 | Goblin x2 / Slime x1 / Goblin + Slime | 25g |
| 6-8 | Bandit x1 / Skeleton Archer + Goblin / Slime + Goblin | 25g |
| 9-11 | Bandit + Skeleton Archer / Bandit + Goblin / Skeleton Archer x2 | 25g |
| 12-14 | Bandit x2 / Skeleton Archer + Slime / Bandit + Skeleton Archer | 25g |

- 그리드: 10x8
- 각 Floor 구간에서 해당 구성 중 랜덤 1개 선택

### 15.2 엘리트 전투 (Elite)
| Floor | 적 구성 (랜덤) | 보상 |
|---|---|---|
| 1-5 | Orc Warchief | 50g |
| 6-9 | Dark Knight / Orc Warchief + Goblin | 50g |
| 10-14 | Necromancer / Dark Knight + Skeleton Archer | 50g |

- 그리드: 10x8

### 15.3 보스 전투 (Boss)
| 구성 | 보상 | 그리드 |
|---|---|---|
| Dragon Whelp (단독) | 100g | 12x8 |
| Lich King + Skeleton Archer x2 | 100g | 12x8 |

- 보스 2종 중 랜덤 1개 선택

---

## 16. UI/UX 흐름

### 16.1 타이틀 화면
- "GRIDSPIRE" 제목 + 부제
- New Game / Continue (비활성) / Settings (미구현)

### 16.2 맵 화면
- 좌우 스크롤 맵 (좌→우)
- 노드 클릭 → 해당 노드 유형에 맞는 액션 실행
- 상단 바: Floor, Gold, 파티 HP

### 16.3 전투 화면
전투 화면 레이아웃 (1280×720):

```
+------------------------------------------------------------------+
| [턴 이름]            [Timeline Bar]                               |  50px
+------------------------------------------------------------------+
|                                                         [End Turn]|
|                                                                   |
|               GRID (10×8, 타일 2:1 비율)                [무덤]   |
|               맨 위 2줄 = 벽 타일 장식                   [(n)]   |
|               캐릭터가 타일 위에 서있는 느낌                       |
|                                                                   |
+------------------------------------------------------------------+
| [캐릭터정보] |                                                    |
|  이름/HP     |          [카드 핸드 - 부채꼴]                      |
|  에너지      |                                                    |
|  드로우/무덤 |                                                    |
+------------------------------------------------------------------+
```

- 그리드: 2:1 비율 타일, 체커보드 패턴, 상단 2줄 벽 장식
- 좌클릭: 캐릭터 선택/이동/타겟 선택
- 우클릭: 선택 취소/타겟팅 취소
- 카드 사용 방식 (2가지):
  - **드래그 앤 드롭**: 카드를 그리드 위로 드래그하여 타겟에 놓기
  - **클릭-투-클릭**: 카드 클릭 → 타겟 클릭 (기존 방식)
- 손패 표시: **부채꼴(fan) 배치**, 호버 시 카드 확대
- **카드 드로우 애니메이션**: 좌하단 CharInfo에서 핸드로 날아가는 연출
- **카드 버리기 애니메이션**: 사용한 카드가 우측 무덤 버튼으로 날아감
- **무덤 팝업**: 무덤 버튼 클릭 시 화면 중앙에 600×400 팝업, 버려진 카드 목록 4열 그리드
- 자동 타겟 카드: 클릭/드래그 즉시 사용
- 수동 타겟 카드: 사거리 표시 → 타일/캐릭터 클릭 또는 드롭

### 16.4 보상 화면
- "VICTORY" + 골드 획득 표시
- 캐릭터 탭 → 3장 카드 → 선택 또는 Skip

### 16.5 상점 화면
- 구매 섹션 (6장) + 제거 섹션
- "Leave Shop" 버튼

---

## 17. 파일 구조

```
gridspire/
├── project.godot
├── scenes/
│   ├── main.tscn
│   ├── battle/
│   │   ├── battle_scene.tscn
│   │   └── grid.tscn
│   ├── map/
│   │   ├── overworld_map.tscn
│   │   └── map_node_button.tscn
│   ├── menu/
│   │   ├── title_screen.tscn
│   │   ├── character_select.tscn
│   │   └── battle_result.tscn
│   └── ui/
│       ├── card_ui.tscn
│       ├── card_hand.tscn
│       ├── battle_hud.tscn
│       ├── character_info.tscn
│       ├── timeline_bar.tscn
│       ├── reward_screen.tscn
│       └── shop_screen.tscn
├── scripts/
│   ├── core/
│   │   ├── enums.gd
│   │   ├── main.gd
│   │   ├── game_manager.gd
│   │   ├── scene_manager.gd
│   │   ├── character_resource.gd
│   │   ├── card_resource.gd
│   │   ├── card_effect_resource.gd
│   │   ├── battle_state.gd
│   │   ├── timeline_entry.gd
│   │   ├── grid_tile_resource.gd
│   │   ├── map_node_resource.gd
│   │   ├── map_data_resource.gd
│   │   ├── map_generator.gd
│   │   └── encounter_resource.gd
│   ├── combat/
│   │   ├── battle_manager.gd
│   │   ├── battle_scene.gd
│   │   ├── timeline_system.gd
│   │   ├── card_effect_resolver.gd
│   │   └── combat_action.gd
│   ├── grid/
│   │   ├── grid_manager.gd
│   │   └── grid_visual.gd
│   ├── cards/
│   │   └── deck_manager.gd
│   └── ui/
│       ├── battle_hud.gd
│       ├── card_ui.gd
│       ├── card_hand.gd
│       ├── battle_result.gd
│       ├── title_screen.gd
│       ├── character_info.gd
│       ├── timeline_bar.gd
│       ├── damage_popup.gd
│       ├── overworld_map.gd
│       ├── map_node_button.gd
│       ├── map_line_drawer.gd
│       ├── reward_screen.gd
│       ├── shop_screen.gd
│       └── character_select.gd
├── resources/
│   ├── characters/
│   │   ├── warrior.tres
│   │   ├── mage.tres
│   │   ├── rogue.tres
│   │   ├── goblin.tres
│   │   ├── slime.tres
│   │   ├── skeleton_archer.tres
│   │   ├── bandit.tres
│   │   ├── orc_warchief.tres
│   │   ├── dark_knight.tres
│   │   ├── necromancer.tres
│   │   ├── dragon_whelp.tres
│   │   └── lich_king.tres
│   └── cards/
│       ├── (공용 10장 .tres)
│       ├── warrior/ (20장 .tres)
│       ├── mage/ (20장 .tres)
│       ├── rogue/ (19장 .tres)
│       └── enemies/
│           ├── goblin/ (goblin_slash, goblin_stab, goblin_dodge, goblin_throw .tres)
│           ├── slime/ (acid_touch, slime_shield, toxic_splash, ooze .tres)
│           ├── skeleton_archer/ (bone_arrow, piercing_shot, quick_shot .tres)
│           ├── bandit/ (slash, cheap_shot, ambush, evade .tres)
│           ├── orc_warchief/ (cleave, heavy_strike, war_cry, iron_hide, ground_slam .tres)
│           ├── dark_knight/ (slash, shield_wall, crushing_blow, taunt, fortify .tres)
│           ├── necromancer/ (shadow_bolt, curse, dark_wave, bone_shield, soul_sap .tres)
│           ├── dragon_whelp/ (claw, fire_breath, tail_swipe, wing_buffet, scale_armor, intimidate .tres)
│           └── lich_king/ (death_bolt, frost_nova, curse_of_agony, dark_ritual, necrotic_wave, bone_armor, stun_gaze .tres)
├── res/
│   ├── Seo-A-walk.png (Mage walk 스프라이트)
│   ├── mage-cast.png (Mage cast 스프라이트)
│   └── mage-kneel.png (Mage kneel 스프라이트)
└── assets/
    └── sprites/
        └── icon.svg
```

---

## 18. 알려진 제한사항 / 향후 과제

| # | 항목 | 현재 상태 | 비고 |
|---|------|-----------|------|
| 1 | Mage cast/kneel 트리거 | 애니메이션 데이터만 등록됨 | 카드 사용 시 cast, 사망 시 kneel 재생 연결 필요 |
| 2 | Warrior/적 스프라이트 | 원형 플레이스홀더 | 스프라이트 시트 추가 필요 |
| 3 | EVENT 씬 | 인라인 골드 지급만 | 별도 이벤트 화면 + 선택지 시스템 필요 |
| 4 | Continue 버튼 | 비활성 | 세이브/로드 시스템 미구현 |
| 5 | Settings 화면 | 미구현 | 볼륨, 해상도 등 |
| 6 | Rogue 파티원 | 리소스만 존재 | 시작 파티 추가 또는 이벤트로 합류 |
| 7 | 런 클리어 화면 | 없음 | 보스 처치 후 승리 연출 |
| 8 | 사운드/BGM | 없음 | 전체 오디오 미구현 |
| 9 | 시그널 해제 | battle_scene 종료 시 미해제 | 씬 전환 시 잔류 시그널 에러 가능 |
| 10 | 상점 카드 클래스 자동 매칭 | 단순 매칭 | 수동 캐릭터 선택 UI 필요 |
| 11 | 맵 시드 기반 재현 | seed 전달됨 | 동일 시드 동일 맵 보장 필요 확인 |
| 12 | 장비/유물 시스템 | 없음 | Slay the Spire의 렐릭에 해당 |

---

## 19. 궁극기 & 연계 시스템

상세 설계는 **[docs/card_design.md](card_design.md)** 참조.

### 19.1 궁극기 (Ultimate Ability)
- 각 캐릭터는 궁극기 게이지 (0~100) 보유
- 충전: 카드 사용 (+10), 피해 받음 (+받은 데미지)
- 게이지 100 도달 시 궁극기 카드가 자동으로 손패에 추가
- 비용 0, 전투당 1회 사용, 사용 후 게이지 리셋

### 19.2 클래스별 궁극기
| 클래스 | 궁극기명 | 효과 |
|--------|----------|------|
| Warrior | Unstoppable Wrath | 4d6+4 데미지 + 인접 적 2칸 밀어내기 |
| Mage | Arcane Cataclysm | 3d8 범위(반경 2) 데미지 + WEAKNESS 2턴 |
| Rogue | Death's Shadow | 5d6 데미지, 대상 HP 50% 이하 시 2배 |

### 19.3 교차 연계 (Cross-class Combo)
- **Setup + Exploit** 구조: 한 클래스가 상태이상 부여 → 다른 클래스가 추가 효과 발휘
- Warrior(WEAKNESS) → Mage: 1.5배 데미지
- Rogue(POISON) → Warrior: 범위 공격 시 독 전파
- Mage(SLOW) → Rogue: 무료 추가 행동 1회

---

## 20. 클래스별 아키타입 시스템

### 20.1 Warrior 아키타입

**Shield Strike (방어도 딜링)**
- 방어도를 축적한 후, Shield Strike 카드로 현재 방어도만큼 데미지 출력
- Shield Strike 카드의 SHIELD 효과는 duration=99로 설정하여 턴이 넘어가도 유지
- 주요 카드: Body Slam, Iron Defense, Bulwark Slam, Aegis Charge, Phalanx, Shield Crusher

**Berserker (광전사)**
- BERSERK 상태이상: 스택당 +2 데미지, 방어도 획득 불가
- EVASION 상태이상: 스택당 15% 회피 (최대 75%), 성공 시 1스택 소모
- requires_berserk 카드는 BERSERK 상태에서만 사용 가능
- 주요 카드: Rage, Reckless Strike, Savage Leap, Blood Frenzy, Berserker Cleave, Undying Fury

### 20.2 Mage 아키타입

**Element Stack (속성 스택)**
- 원소 속성: fire, ice, lightning
- 카드 사용 시 해당 원소 스택 축적 (card.element_count만큼)
- 스택에 비례하여 데미지/실드 증가 (scale_element, scale_per_stack)
- Elemental Convergence: 전체 스택 × 3 데미지 후 모든 스택 소모 (consumes_stacks)
- 주요 카드: Flame Jet, Ice Shard, Volt Bolt, Inferno, Glacial Barrier, Storm Surge, Convergence, Elemental Mastery

**Summon (소환수)**
- 소환수는 독립 CharacterData로 그리드에 배치, 타임라인에 등장
- 소환수 AI: 적을 향해 이동, 에너지 범위 내 카드 자동 사용
- 소환 상한: max_summons (기본 2), 초과 시 소환 실패
- 소환수 3종: Fire Elemental (HP15, Spd90), Ice Elemental (HP20, Spd110), Arcane Familiar (HP10, Spd70)
- 주요 카드: Summon Fire/Ice/Lightning Elemental, Arcane Familiar, Elemental Army

### 20.3 Rogue 아키타입

**Combo/Chain (태그 연계)**
- 카드에 태그 부여: strike, poison, setup, finisher, movement
- 같은 턴에 특정 태그가 이미 사용되었으면 콤보 보너스 발동
- combo_tag: 조건 태그, combo_bonus: 보너스 값, combo_only: 조건 충족 시에만 효과 발동
- 기존 19장 로그 카드에도 태그 추가 (예: Quick Slash → strike, Backstab → strike+finisher)
- 주요 신규 카드: Opening Strike, Envenom, Fan of Knives, Feint, Dash Strike, Toxic Cascade, Coup de Grace, Shadow Chain

---

## 21. 소환수 시스템

| ID | 이름 | HP | Speed | Energy | Move | 덱 |
|---|---|---|---|---|---|---|
| fire_elemental | Fire Elemental | 15 | 90 | 2 | 2 | fire_touch ×3 |
| ice_elemental | Ice Elemental | 20 | 110 | 2 | 1 | frost_touch ×2, ice_shield ×1 |
| lightning_elemental | Lightning Elemental | 12 | 75 | 2 | 3 | arcane_zap ×3 |
| arcane_familiar | Arcane Familiar | 10 | 70 | 1 | 3 | arcane_zap ×2 |

소환수 카드:
| 카드명 | 비용 | 사거리 | 효과 |
|--------|------|--------|------|
| Fire Touch | 1 | 1 | 1d6+2 데미지 |
| Frost Touch | 1 | 1 | 1d4+1 데미지 + SLOW 1턴 |
| Ice Shield | 1 | 0 | 1d4+1 실드 |
| Arcane Zap | 1 | 2-3 | 1d6+2 데미지 |

---

## 22. 스텟 업그레이드 시스템

- 상점과 이벤트에서 캐릭터 스텟을 영구적으로 강화 가능
- 업그레이드 적용 시 bonus_* 필드에 누적

| ID | 이름 | 효과 | 가격 |
|---|---|---|---|
| upgrade_hp_small | Vitality Shard | +5 Max HP | 75g |
| upgrade_hp_large | Vitality Crystal | +10 Max HP | 150g |
| upgrade_str | Strength Shard | +1 Strength (영구) | 100g |
| upgrade_energy | Energy Rune | +1 Energy/턴 | 250g |
| upgrade_move | Swift Boots | +1 이동 | 100g |
| upgrade_speed | Haste Charm | -10 Speed (빨라짐) | 125g |
| upgrade_summon | Summoner's Sigil | +1 소환 상한 | 175g |

---

## 23. 이벤트 시스템

EVENT 노드 방문 시 3종 이벤트 중 랜덤 1개 발생:

| 이벤트 | 선택지 | 효과 |
|--------|--------|------|
| 대장간 (Blacksmith) | HP -5 대가로 강화 | Strength +1 |
| 치유의 샘 (Healing Fountain) | 선택 A: 전원 HP 회복 / 선택 B: Max HP +5 | 전체 회복 또는 영구 강화 |
| 방랑 상인 (Wandering Merchant) | 스텟 업그레이드 구매 | 50% 할인 가격으로 1개 구매 |

---

## 24. 신규 상태이상

| 상태 | 유형 | 효과 |
|------|------|------|
| BERSERK | 버프/디버프 | 스택당 +2 데미지, SHIELD 획득 불가 |
| EVASION | 버프 | 스택당 15% 회피 (최대 75%), 회피 성공 시 1스택 소모 |
