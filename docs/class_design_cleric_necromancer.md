# Cleric & Necromancer Class Design

## Cleric (Holy Healer / Faith Stacker)

### Stats
| Stat | Value |
|------|-------|
| HP | 50 |
| Speed | 90 |
| Energy | 3 |
| Move | 3 |

### Archetype: Faith Stacking
- Uses `element = "faith"` with existing element_stacks system
- Most cards generate +1 faith per play
- Faith stacks power scaling damage cards (Divine Judgment, Holy Wrath, Divine Storm)
- `consumes_stacks` on burst cards (Divine Judgment, Divine Storm)

### Starting Deck (10 cards, 7 types)
| Card | Qty | Cost | Target | Effects |
|------|-----|------|--------|---------|
| Holy Light | x2 | 1 | Ally 0-2 | Heal 1d4+2, +1 faith |
| Divine Shield | x2 | 1 | Self | Shield 1d4+1, +1 faith |
| Smite | x2 | 1 | Enemy 1-2 | Damage 1d6+1, +1 faith |
| Blessing | x1 | 1 | Ally 0-2 | Buff STR 1 / 2 turns, +1 faith |
| Prayer | x1 | 1 | Self | Heal 1d6 + Draw 1, +1 faith |
| Purifying Flame | x1 | 1 | Enemy 1-2 | Damage 1d4 + Weakness 1 / 2 turns, +1 faith |
| Radiance | x1 | 2 | Area 0-1 r1 | Area Buff Regen 2 / 2 turns, +1 faith |

### Card Pool (10 cards)
| Card | Cost | Target | Effects | Rarity |
|------|------|--------|---------|--------|
| Divine Judgment | 2 | Enemy 1-3 | Damage 1d6 +2/faith, consume | Uncommon |
| Sanctuary | 1 | Ally 0-2 | Buff Shield 5 / 99 turns | Uncommon |
| Haste Prayer | 1 | Ally 0-2 | Buff Haste 1 / 3 turns | Uncommon |
| Greater Heal | 2 | Ally 0-3 | Heal 2d6+3 | Uncommon |
| Holy Wrath | 2 | Enemy 1-3 | Damage 1d6 +2/faith (non-consuming) | Uncommon |
| Mass Blessing | 2 | Area 0-1 r2 | Area Buff STR 1 / 3 turns | Uncommon |
| Retribution | 1 | Enemy 1-2 | Damage 1d4 + Shield 1d4 | Uncommon |
| Divine Light | 2 | Ally 0-3 | Heal 1d8+2 + Regen 1 / 3 turns | Uncommon |
| Condemn | 1 | Enemy 1-3 | Slow 1 + Weakness 1 / 2 turns | Common |
| Divine Storm | 3 | Enemy 1-3 | Damage [faith] x 1d8, consume | Rare |

---

## Necromancer (Sacrifice / Soul Stacker)

### Stats
| Stat | Value |
|------|-------|
| HP | 35 |
| Speed | 85 |
| Energy | 3 |
| Move | 2 |

### Archetype: Sacrifice for Soul Stacks
- Uses `element = "soul"` with existing element_stacks system
- Sacrifice cards deal direct HP damage to allies (bypasses shield/evasion)
- Sacrifice cards apply UNHEALABLE debuff, blocking Cleric heals
- Soul stacks power scaling damage cards (Soul Bolt, Soul Explosion, Reaper)
- Solo necromancer cannot use sacrifice cards (range_min=1 excludes self)

### Starting Deck (10 cards, 7 types)
| Card | Qty | Cost | Target | Effects |
|------|-----|------|--------|---------|
| Dark Bolt | x2 | 1 | Enemy 1-3 | Damage 1d4+1, +1 soul |
| Bone Shield | x2 | 1 | Self | Shield 1d4+1, +1 soul |
| Life Tap | x2 | 1 | Ally 1-2 | Sacrifice 5 + Unhealable 2 turns, +2 soul |
| Soul Bolt | x1 | 1 | Enemy 1-3 | Damage 1d4 +1/soul |
| Shadow Grasp | x1 | 1 | Enemy 1-2 | Damage 1d4 + Root 1 turn, +1 soul |
| Dark Pact | x1 | 1 | Ally 1-2 | Sacrifice 3 + Unhealable 1 turn + Draw 2, +1 soul |
| Hex | x1 | 1 | Enemy 1-3 | Poison 2 / 3 turns, +1 soul |

### Card Pool (9 cards)
| Card | Cost | Target | Effects | Rarity |
|------|------|--------|---------|--------|
| Soul Explosion | 2 | Enemy 1-3 | Damage [soul] x 2d4, consume | Uncommon |
| Mass Sacrifice | 2 | Ally 1-2 | Sacrifice 8 + Unhealable 3 turns + Shield 2d6, +2 soul | Uncommon |
| Death Coil | 2 | Enemy 1-3 | Damage 2d6+2, +1 soul | Uncommon |
| Necrotic Wave | 2 | Area 1-2 r1 | Area Debuff Poison 2 / 3 turns, +1 soul | Uncommon |
| Soul Shield | 1 | Self | Shield 1d4 +2/soul | Uncommon |
| Wither | 1 | Enemy 1-3 | Weakness 2 / 2 turns, +1 soul | Common |
| Soul Harvest | 1 | Ally 1-2 | Sacrifice 3 + Unhealable 1 turn + Draw 3, +2 soul | Uncommon |
| Blood Ritual | 2 | Ally 1-2 | Sacrifice 10 + Unhealable 3 turns + Draw 3 + Shield 2d4, +3 soul | Rare |
| Reaper | 3 | Enemy 1-2 | Damage [soul] x 1d10, consume | Rare |

---

## New Systems

### StatusEffect: UNHEALABLE
- Blocks ALL healing: card heal effects, REGEN status effect ticks
- `heal()` returns 0 when UNHEALABLE stacks > 0
- Stacks increase on re-application, duration uses max
- Displayed as "CURSE" in character info panel (purple)

### CardEffectType: SACRIFICE
- Direct HP loss that bypasses SHIELD and EVASION
- Minimum 1 HP guaranteed (target cannot die from sacrifice)
- Always targets allies (range_min=1 excludes self)
- Emits damage_dealt signal for UI feedback

### Synergies & Counterplay
- Cleric + Necromancer: Necromancer sacrifices allies for soul power, but UNHEALABLE blocks Cleric heals
- Cleric team: Strong sustain through heals, regen, and faith-based damage scaling
- Solo Necromancer: Cannot use sacrifice cards alone (designed as party-dependent)
