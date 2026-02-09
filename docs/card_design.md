# GridSpire - Card Design Document

## 1. 궁극기 메커니즘 (Ultimate Ability System)

### 1.1 궁극기 게이지
- 각 캐릭터는 **ultimate_gauge** (0~100) 보유
- 게이지 충전 조건:
  - 카드 사용 시: **+10** (카드 1장 플레이할 때마다)
  - 피해 받을 때: **+받은 데미지 수치** (예: 15 데미지 → +15 게이지)
- 최대 게이지: **100**

### 1.2 궁극기 발동
- 게이지가 100에 도달하면 해당 캐릭터의 **궁극기 카드가 자동으로 손패에 추가**
- 궁극기 카드의 에너지 비용은 **0** (무료 사용)
- **전투당 1회** 사용 가능
- 사용 후 게이지 **0으로 리셋**
- 전투 종료 시 게이지 초기화

---

## 2. 클래스별 궁극기 (Class Ultimates)

### 2.1 Warrior - "Unstoppable Wrath" (불멸의 분노)
| 속성 | 값 |
|------|-----|
| 데미지 | 4d6+4 |
| 비용 | 0 에너지 |
| 사거리 | 1 |
| 타겟 | SINGLE_ENEMY (주 대상) + 인접 적 밀어내기 |
| 효과 | 주 대상에게 4d6+4 데미지 + 인접 적 2칸 밀어내기 (PUSH) |
| 레어리티 | Ultimate |

### 2.2 Mage - "Arcane Cataclysm" (비전 대재앙)
| 속성 | 값 |
|------|-----|
| 데미지 | 3d8 범위 데미지 (반경 2) |
| 비용 | 0 에너지 |
| 사거리 | 2~5 |
| 타겟 | AREA (반경 2) |
| 효과 | 범위 내 모든 적에게 3d8 데미지 + WEAKNESS 2턴 부여 |
| 레어리티 | Ultimate |

### 2.3 Rogue - "Death's Shadow" (죽음의 그림자)
| 속성 | 값 |
|------|-----|
| 데미지 | 5d6 (대상 HP 50% 이하 시 2배) |
| 비용 | 0 에너지 |
| 사거리 | 1 |
| 타겟 | SINGLE_ENEMY |
| 효과 | 5d6 데미지, 대상의 현재 HP가 최대 HP의 50% 이하면 데미지 2배 |
| 레어리티 | Ultimate |

---

## 3. 교차 연계 시스템 (Cross-class Combo System)

### 3.1 개요
연계 시스템은 **Setup + Exploit** 구조로 작동한다. 한 클래스가 상태이상을 부여(Setup)하면, 다른 클래스가 해당 상태이상이 걸린 대상에게 추가 효과를 발휘(Exploit)한다.

### 3.2 연계 조합

#### Warrior → Mage 연계
| Setup (Warrior) | Exploit (Mage) | 효과 |
|-----------------|----------------|------|
| WEAKNESS 부여 (Pommel Strike, Ground Slam 등) | 약화된 대상 공격 | 약화 대상에게 **1.5배 데미지** |

#### Rogue → Warrior 연계
| Setup (Rogue) | Exploit (Warrior) | 효과 |
|---------------|-------------------|------|
| POISON 부여 (Poison Blade, Venomous Fang 등) | Cleave/Whirlwind 등 범위 공격 | 범위 공격 시 **인접 적에게 독 전파** (같은 스택/지속시간) |

#### Mage → Rogue 연계
| Setup (Mage) | Exploit (Rogue) | 효과 |
|--------------|-----------------|------|
| SLOW 부여 (Frost Bolt, Ice Wall, Blizzard 등) | 둔화 대상 공격 | 둔화 대상에게 **추가 무료 행동 1회** 획득 |

### 3.3 연계 활성화 조건
- 상태이상이 활성 상태여야 함 (지속시간 > 0)
- 같은 전투 내에서만 유효
- 연계 보너스는 1회 공격당 1번만 적용

---

## 4. 전체 카드 밸런스 테이블 (Card Balance Table)

### 4.1 주사위 변환 기준
| 기존 고정값 | 주사위 표기 | 평균값 |
|-------------|------------|--------|
| 3~4 | 1d4+1 | 3.5 |
| 5~6 | 1d6+2 | 5.5 |
| 7~8 | 2d4 | 5.0 |
| 9~12 | 2d6 | 7.0 |
| 13+ | 3d6 | 10.5 |

### 4.2 Warrior 카드 (20장)

| 카드명 | 비용 | 사거리 | 주사위 | 효과 유형 | 레어리티 |
|--------|------|--------|--------|-----------|----------|
| Strike | 1 | 1 | 1d6+2 | DAMAGE | Common |
| Defend | 1 | 0 | 1d6+2 | SHIELD | Common |
| Cleave | 1 | 1 | 1d4+1 (반경 1) | AREA_DAMAGE | Common |
| Heavy Blow | 2 | 1 | 2d6 | DAMAGE | Common |
| Shield Bash | 1 | 1 | 1d4+1 / 1d4+1 | DAMAGE + SHIELD | Common |
| Battle Cry | 1 | 0 | - | BUFF (STRENGTH 2, 3턴) | Common |
| Iron Will | 1 | 0 | 2d4 | SHIELD | Common |
| Rallying Shout | 0 | 0 | - | BUFF (STRENGTH 1, 3턴) | Common |
| Shield Wall | 2 | 0 | 2d6 | SHIELD + BUFF (ROOT 2턴) | Uncommon |
| Pommel Strike | 2 | 1 | 1d6+2 | DAMAGE + DEBUFF (STUN 1턴) | Uncommon |
| Charge | 2 | 1 | 2d4 | DAMAGE + PUSH 1 | Uncommon |
| Second Wind | 2 | 0 | 1d6+2 / 1d4+1 | HEAL + SHIELD | Uncommon |
| Whirlwind | 2 | 0~1 | 2d4 (반경 1) | AREA_DAMAGE | Uncommon |
| Ground Slam | 2 | 1 | 1d6+2 (반경 1) | AREA_DAMAGE + AREA_DEBUFF (ROOT 1턴) | Uncommon |
| Bloodlust | 2 | 0 | - | BUFF (STRENGTH 3, 2턴) + BUFF (HASTE 2턴) | Uncommon |
| Executioner's Swing | 3 | 1 | 3d6 | DAMAGE | Rare |
| Fortify | 3 | 0 | 3d6 | SHIELD + BUFF (REGEN 3턴) | Rare |
| Unstoppable Force | 3 | 1 | 2d6 | DAMAGE + PUSH 2 + DEBUFF (STUN 1턴) | Rare |
| War Stomp | 2 | 0~1 | - | AREA_DEBUFF (STUN 1턴, 반경 1) | Rare |
| Berserker Rage | 1 | 0 | - | BUFF (STRENGTH 4, 3턴) + DEBUFF (WEAKNESS 3턴, 자신) | Rare |

### 4.3 Mage 카드 (20장)

| 카드명 | 비용 | 사거리 | 주사위 | 효과 유형 | 레어리티 |
|--------|------|--------|--------|-----------|----------|
| Arcane Bolt | 1 | 1~3 | 1d6+2 | DAMAGE | Common |
| Mana Shield | 1 | 0 | 1d6+2 | SHIELD | Common |
| Fireball | 2 | 2~4 | 1d6+2 (반경 1) | AREA_DAMAGE | Common |
| Frost Bolt | 1 | 1~3 | 1d4+1 | DAMAGE + DEBUFF (SLOW 2턴) | Common |
| Spark | 0 | 1~4 | 1d4+1 | DAMAGE | Common |
| Arcane Intellect | 1 | 0 | - | DRAW 2 | Common |
| Enfeeble | 1 | 1~3 | - | DEBUFF (WEAKNESS 3턴) | Common |
| Healing Light | 1 | 1~3 | 2d4 | HEAL | Common |
| Chain Lightning | 2 | 1~4 | 1d4+1 (반경 2) | AREA_DAMAGE | Uncommon |
| Ice Wall | 2 | 1~3 | - | AREA_DEBUFF (SLOW 2턴, 반경 1) | Uncommon |
| Arcane Barrier | 2 | 0~3 | - | AREA_BUFF (SHIELD 6, 반경 2) | Uncommon |
| Searing Ray | 2 | 2~5 | 2d6 | DAMAGE | Uncommon |
| Toxic Cloud | 2 | 2~4 | 1d4+1 (반경 1) | AREA_DAMAGE + AREA_DEBUFF (POISON 3, 3턴) | Uncommon |
| Time Warp | 1 | 0 | - | BUFF (HASTE 2턴) + DRAW 1 | Uncommon |
| Mass Heal | 2 | 0~3 | - | AREA_BUFF (REGEN 5, 반경 2) | Uncommon |
| Meteor | 3 | 2~5 | 2d6 (반경 2) | AREA_DAMAGE | Rare |
| Blizzard | 3 | 2~4 | 1d6+2 (반경 2) | AREA_DAMAGE + AREA_DEBUFF (SLOW 2턴) | Rare |
| Pyroblast | 3 | 2~5 | 3d6 | DAMAGE | Rare |
| Gravity Well | 2 | 2~4 | 1d4+1 (반경 2) | AREA_DAMAGE + AREA_DEBUFF (ROOT 1턴) | Rare |
| Arcane Torrent | 2 | 1~3 | 2d4 | DAMAGE + DRAW 2 | Rare |

### 4.4 Rogue 카드 (19장)

| 카드명 | 비용 | 사거리 | 주사위 | 효과 유형 | 레어리티 |
|--------|------|--------|--------|-----------|----------|
| Shiv | 0 | 1 | 1d4+1 | DAMAGE | Common |
| Dodge | 1 | 0 | 1d6+2 | SHIELD | Common |
| Quick Slash | 1 | 1 | 1d6+2 | DAMAGE + DRAW 1 | Common |
| Poison Blade | 1 | 1 | 1d4+1 | DAMAGE + DEBUFF (POISON 2, 3턴) | Common |
| Sprint | 1 | 0 | - | BUFF (HASTE 2턴) | Common |
| Throwing Knife | 1 | 1~2 | 1d6+2 | DAMAGE | Common |
| Preparation | 1 | 0 | - | DRAW 3 | Common |
| Crippling Strike | 1 | 1 | 1d4+1 | DAMAGE + DEBUFF (WEAKNESS 2턴) | Common |
| Backstab | 1 | 1 | 2d6 | DAMAGE | Uncommon |
| Shadow Step | 1 | 0 | - | BUFF (HASTE 2턴) + DRAW 1 | Uncommon |
| Flurry | 1 | 1 | 1d4+1 x2 | DAMAGE x2 | Uncommon |
| Expose Weakness | 1 | 1 | 1d4+1 | DAMAGE + DEBUFF (WEAKNESS 3턴) | Uncommon |
| Smoke Bomb | 1 | 0 | 1d6+2 | SHIELD + BUFF (HASTE 1턴) | Uncommon |
| Toxic Shuriken | 1 | 1~2 | 1d4+1 | DAMAGE + DEBUFF (POISON 2, 4턴) | Uncommon |
| Venomous Fang | 2 | 1 | 1d6+2 | DAMAGE + DEBUFF (POISON 3, 3턴) | Uncommon |
| Blade Dance | 2 | 1 | 1d4+1 x2 / 1d4+1 | DAMAGE x2 + SHIELD | Rare |
| Death Mark | 2 | 1 | 1d6+2 | DAMAGE + DEBUFF (POISON 4, 3턴) + DEBUFF (WEAKNESS 2턴) | Rare |
| Assassinate | 3 | 1 | 3d6 | DAMAGE | Rare |
| Phantom Strike | 2 | 1 | 2d4 | DAMAGE + BUFF (HASTE 1턴) + DRAW 1 | Rare |
| Thousand Cuts | 3 | 1 | 1d4+1 x3 | DAMAGE x3 + DEBUFF (POISON 3, 3턴) | Rare |

### 4.5 공용 카드 (10장)

| 카드명 | 비용 | 사거리 | 주사위 | 효과 유형 | 레어리티 |
|--------|------|--------|--------|-----------|----------|
| Strike | 1 | 1 | 1d6+2 | DAMAGE | Common |
| Defend | 1 | 0 | 1d6+2 | SHIELD | Common |
| Heal | 1 | 0~3 | 2d4 | HEAL | Common |
| Fireball | 2 | 1~4 | 2d4 (반경 1) | AREA_DAMAGE | Uncommon |
| Shield Bash | 1 | 1 | 1d4+1 | SHIELD + PUSH 2 | Uncommon |
| Poison Dart | 1 | 1~3 | 1d4+1 | DAMAGE + DEBUFF (POISON 3, 3턴) | Uncommon |
| Bash | 2 | 1 | 2d4 | DAMAGE + DEBUFF (STUN 1턴) | Uncommon |
| Quick Step | 1 | 0 | - | BUFF (HASTE 2턴) + DRAW 1 | Uncommon |
| War Cry | 1 | 0 | - | BUFF (STRENGTH 2, 3턴) | Uncommon |
| Rally | 2 | 0 | - | AREA_BUFF (STRENGTH 1, 2턴, 반경 2) | Rare |

---

## 5. Warrior 아키타입 카드 (12장)

### 5.1 Shield Strike 아키타입 (6장)

| 카드명 | 비용 | 사거리 | 효과 | 레어리티 |
|--------|------|--------|------|----------|
| Body Slam | 1 | 1 | SHIELD_STRIKE ×1.0 | Common |
| Iron Defense | 1 | 0 | SHIELD 1d6+3 (dur=99) | Common |
| Bulwark Slam | 2 | 1 | SHIELD 1d6+2 (dur=99) + SHIELD_STRIKE ×1.0 | Uncommon |
| Aegis Charge | 2 | 1-2 | SHIELD_STRIKE ×1.5 + PUSH 1 | Uncommon |
| Phalanx | 2 | 0 | SHIELD 2d6+2 (dur=99) + DRAW 1 | Rare |
| Shield Crusher | 3 | 1 | SHIELD_STRIKE ×2.0. Exhaust | Rare |

### 5.2 Berserker 아키타입 (6장)

| 카드명 | 비용 | 사거리 | 효과 | 레어리티 |
|--------|------|--------|------|----------|
| Rage | 1 | 0 | BERSERK 2 (3턴) | Common |
| Reckless Strike | 1 | 1 | 1d8+3 데미지. requires_berserk | Common |
| Savage Leap | 1 | 0 | EVASION 2 (2턴) + MOVE 3 | Uncommon |
| Blood Frenzy | 2 | 0 | BERSERK 3 (4턴) + DRAW 2 | Uncommon |
| Berserker Cleave | 2 | 0-1 | 2d6+2 범위 데미지 (반경 1) | Rare |
| Undying Fury | 3 | 0 | BERSERK 5 (99턴) + EVASION 3 (99턴) + HEAL 2d6. Exhaust | Rare |

---

## 6. Mage 아키타입 카드 (13장)

### 6.1 Element Stack 아키타입 (8장)

| 카드명 | 비용 | 사거리 | 원소 | 효과 | 레어리티 |
|--------|------|--------|------|------|----------|
| Flame Jet | 1 | 1-3 | fire(1) | 1d6+2 데미지, +1/fire stack | Common |
| Ice Shard | 1 | 1-3 | ice(1) | 1d4+1 데미지 +1/ice stack + SLOW 1턴 | Common |
| Volt Bolt | 0 | 1-4 | lightning(1) | 1d4 데미지, +1/lightning stack | Common |
| Inferno | 2 | 2-4 | fire(2) | 1d6+1 범위 데미지 +2/fire stack (R1) | Uncommon |
| Glacial Barrier | 1 | 0 | ice(1) | 1d4+1 실드 +2/ice stack | Uncommon |
| Storm Surge | 1 | 1-4 | lightning(2) | 1d4+1 범위 데미지 +1/lightning stack (R2) | Uncommon |
| Convergence | 2 | 1-4 | — | 1d4+1 데미지 +3/total stack. consumes | Rare |
| Elemental Mastery | 3 | 0 | — | +3 all element stacks + DRAW 2. Exhaust | Rare |

### 6.2 Summon 아키타입 (5장)

| 카드명 | 비용 | 사거리 | 효과 | 레어리티 |
|--------|------|--------|------|----------|
| Summon Fire Elemental | 2 | 1-2 | SUMMON fire_elemental | Common |
| Summon Ice Elemental | 2 | 1-2 | SUMMON ice_elemental | Common |
| Summon Lightning Elemental | 2 | 1-2 | SUMMON lightning_elemental + lightning(1) | Uncommon |
| Arcane Familiar | 1 | 1-2 | SUMMON arcane_familiar | Uncommon |
| Elemental Army | 3 | 1-2 | SUMMON fire + ice elemental. Exhaust | Rare |

---

## 7. Rogue 아키타입 카드 (8장)

### 7.1 Combo/Chain 아키타입

태그 종류: strike, poison, setup, finisher, movement

| 카드명 | 비용 | 사거리 | 태그 | 콤보 | 효과 | 레어리티 |
|--------|------|--------|------|------|------|----------|
| Opening Strike | 1 | 1 | strike | — | 1d6+2 데미지 | Common |
| Envenom | 1 | 1-2 | poison | strike→+3 | 1d4 데미지 + POISON 2(3턴) | Common |
| Fan of Knives | 1 | 1-2 | strike | movement→+2 | 1d4+1 범위 데미지 (R1) | Common |
| Feint | 0 | 0 | setup | — | DRAW 1 + EVASION 1(2턴) | Common |
| Dash Strike | 1 | 1-2 | movement,strike | setup→+4 | 1d6+2 데미지 | Uncommon |
| Toxic Cascade | 2 | 1-2 | poison,finisher | poison→+5 | 1d6+1 데미지 + POISON 3(3턴) | Uncommon |
| Coup de Grace | 2 | 1 | finisher | strike→+6, poison→+4(only) | 1d8+3 데미지 | Rare |
| Shadow Chain | 1 | 0 | setup,movement | — | DRAW 3 + EVASION 2(2턴) + HASTE 2턴. Exhaust | Rare |

### 7.2 기존 로그 카드 태그 매핑

| 카드명 | 태그 |
|--------|------|
| Quick Slash | strike |
| Poison Blade | poison |
| Backstab | strike, finisher |
| Shiv | strike |
| Shadow Step | movement |
| Sprint | movement |
| Dodge | setup |
| Throwing Knife | strike |
| Preparation | setup |
| Crippling Strike | strike, poison |
| Flurry | strike |
| Expose Weakness | setup, poison |
| Smoke Bomb | setup, movement |
| Toxic Shuriken | strike, poison |
| Venomous Fang | poison, finisher |
| Blade Dance | strike, finisher |
| Death Mark | setup, finisher |
| Assassinate | strike, finisher |
| Phantom Strike | movement, strike |
| Thousand Cuts | strike, poison, finisher |

---

## 8. 소환수 스펙 테이블

| ID | 이름 | HP | Speed | Energy | Move | 덱 |
|---|---|---|---|---|---|---|
| fire_elemental | Fire Elemental | 15 | 90 | 2 | 2 | Fire Touch ×3 |
| ice_elemental | Ice Elemental | 20 | 110 | 2 | 1 | Frost Touch ×2, Ice Shield ×1 |
| lightning_elemental | Lightning Elemental | 12 | 75 | 2 | 3 | Arcane Zap ×3 |
| arcane_familiar | Arcane Familiar | 10 | 70 | 1 | 3 | Arcane Zap ×2 |

---

## 9. 아키타입 시너지/반시너지

**시너지:**
- Shield Strike + Berserker: 상호 배타적 (BERSERK 시 방어도 획득 불가), 서로 다른 빌드 분기
- Element Stack + Summon: 원소 카드 사용으로 스택 축적하면서 소환수가 추가 딜링
- Combo Chain: 태그 순서 최적화 (setup → movement → strike → finisher)

**반시너지:**
- Berserker + Shield Strike: BERSERK 상태에서 방어도 획득 불가
- Summon 과다 사용: 소환수가 타임라인 슬롯 차지, 본체 행동 빈도 감소
- Combo 의존: 핸드 순서에 크게 의존, 드로우 RNG 영향 큼
