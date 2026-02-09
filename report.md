# GridSpire - UI 이슈 리포트

## 보고된 이슈 (2026-02-09)

### 1. 타임라인 바가 안 보여 → **해결됨**
- 원인: `timeline_bar.tscn`에 `layout_mode = 1` 누락으로 BattleHUD 안에서 앵커 크기가 0으로 해석됨
- 수정: `layout_mode = 1` 추가, 상단 바 우측에 명시적 배치 (offset_left=170, offset_top=5)

### 2. UI가 메인 전장을 가림 → **해결됨**
- 캐릭터 정보를 좌하단으로 이동 (anchor_top=1, anchor_bottom=1, offset_top=-180)
- 카드 핸드를 하단 중앙으로 이동 (offset_left=250, offset_right=-90)
- End Turn 버튼을 전장 우측 중앙으로 이동

### 3. 타일 가로 2:1 비율 + 캐릭터 서있는 느낌 → **해결됨**
- `GridManager.tile_size` 기본값: `Vector2(116, 58)` (2:1 비율)
- `battle_scene.gd`에서 동적 계산: `tile_h = floor(available_h / grid_h)`, `tile_w = tile_h * 2`
- 그리드를 화면 가로 중앙에 자동 배치
- 캐릭터 스프라이트에 `stand_offset = Vector2(0, -ts.y * 0.3)` 적용
- AnimatedSprite2D 오프셋: `Vector2(0, -ref_frame_h * 0.35)`
- 상단 2줄(row 0, 1)을 벽 타일로 자동 배치하여 깊이감 연출

### 4. 턴 종료 우측 + 캐릭터 정보 좌하단 → **해결됨**
- EndTurnButton: anchor_left=1, anchor_top=0.5 (전장 우측 중앙)
- CharacterInfo: anchor_top=1, anchor_bottom=1 (좌하단)

### 5. 에너지를 캐릭터 정보에만 표시 → **해결됨**
- TopBar에서 BattleEnergyLabel, DrawCountLabel, DiscardCountLabel 제거
- CharacterInfo에 `"Energy: %d / %d"` 포맷으로 표시
- CharacterInfo에 DrawCountLabel, DiscardCountLabel 추가

### 6. 카드 드로우 애니메이션 → **해결됨**
- `card_hand.gd`에 `_animate_draw()` 추가
- DRAW_ORIGIN = Vector2(-130, -30) (CharInfo 방향)에서 시작
- scale 0.3→1.0, alpha 0→1, stagger 0.1s 간격

### 7. 사용한 카드가 우측 무덤으로 이동 → **해결됨**
- `battle_hud.gd`에 `_animate_discard_to_graveyard()` 추가
- 임시 CardUI 생성 → 무덤 위치로 tween (0.4s, scale 0.1, fade)

### 8. 무덤 클릭 시 버려진 카드 확인 → **해결됨**
- GraveyardButton: 우측, "Grave\n(N)" 텍스트
- GraveyardPopup: 화면 중앙 600×400, 4열 그리드
- `DeckManager.get_discard_pile()` 메서드 추가

## 수정된 파일 (12개)
1. `scenes/ui/timeline_bar.tscn` — layout_mode = 1 추가
2. `scripts/grid/grid_manager.gd` — tile_size 기본값 2:1 비율
3. `scenes/battle/battle_scene.tscn` — GridContainer 위치 조정
4. `scripts/combat/battle_scene.gd` — 동적 타일 크기, 중앙 정렬, 벽 타일
5. `scripts/grid/grid_visual.gd` — standing 오프셋, 2:1 스케일링
6. `scenes/ui/battle_hud.tscn` — 전체 레이아웃 재배치 + Graveyard 노드
7. `scripts/ui/battle_hud.gd` — 에너지 라벨 제거, 무덤 UI, 버리기 애니메이션
8. `scenes/ui/character_info.tscn` — DrawCount/DiscardCount 라벨 추가
9. `scripts/ui/character_info.gd` — 에너지/드로우/무덤 표시, 시그널 연결
10. `scenes/ui/card_hand.tscn` — offset 조정
11. `scripts/ui/card_hand.gd` — 드로우 애니메이션, 위치 추적
12. `scripts/cards/deck_manager.gd` — get_discard_pile() 추가
