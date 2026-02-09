# GridSpire - Claude Code 프로젝트 가이드

## 프로젝트 개요
Godot 4.4 (GL Compatibility) 기반 택티컬 덱빌딩 RPG.
GDScript 사용, 리소스 기반 데이터 모델 (.tres 파일).

## 빌드 & 배포
- **엔진**: Godot 4.4 stable
- **렌더러**: GL Compatibility
- **Web 배포**: GitHub Pages via GitHub Actions
  - Docker: `barichello/godot-ci:4.4`
  - URL: https://ihwoomil.github.io/gridspire/
  - Workflow: `.github/workflows/deploy-web.yml`

## 주요 규칙

### Git 커밋 전 체크리스트
1. `git status`로 untracked 파일 확인 — Godot 에디터에서 새로 만든 파일은 자동으로 git에 추가되지 않음
2. 특히 `class_name`을 선언한 .gd 파일이 빠지면 다른 스크립트에서 연쇄 Parse Error 발생
3. `.tres` 리소스 파일도 빠짐없이 커밋할 것

### export_presets.cfg 수정 시 주의사항
- 수동 편집 지양, Godot 에디터에서 생성 권장
- 수동 편집이 필요하면 `docs/web_export_troubleshooting.md` 참조
- `variant/thread_support`는 bool 타입 (true/false), int가 아님
- `progressive_web_app/offline_page`는 실제 존재하는 파일만 지정하거나 비워둘 것

### CI Workflow 디버깅
- Import 단계에서 `2>/dev/null` 사용 금지 → `2>&1`로 에러를 표시할 것
- Build 단계에서 `--verbose` 플래그 사용 권장
- 외부 URL 다운로드에 의존하는 단계는 실패 가능성 있음

## 프로젝트 구조
```
scripts/
  core/       # 데이터 모델, 열거형, 게임/씬 매니저
  combat/     # 전투 시스템, 카드 효과, 타임라인
  cards/      # 덱 매니저
  grid/       # 그리드 시스템
  ui/         # UI 스크립트
  utils/      # 유틸리티
resources/
  cards/      # 카드 .tres (warrior/, mage/, rogue/, enemies/, summons/)
  characters/ # 캐릭터 .tres
  maps/       # 맵 데이터
  upgrades/   # 스텟 업그레이드 .tres
scenes/       # .tscn 씬 파일
assets/       # 스프라이트, 아이콘
docs/         # 기획서, 트러블슈팅 문서
```

## Autoload 싱글톤
- `GameManager` — 게임 상태, 파티, 골드, 맵 관리, 난이도/승천 시스템
- `SceneManager` — 씬 전환
- `BattleManager` — 전투 진행, 턴 관리, 소환수 시그널 (`summon_added`)
- `GridManager` — 그리드 좌표, 이동, 범위 계산 (tile_size 2:1 비율, 동적 계산)
- `DeckManager` — 덱 셔플, 드로우, 버리기, 무덤 조회 (get_discard_pile)

## 전투 UI 레이아웃 (1280×720)
- **상단**: 턴 이름(좌) + 타임라인 바(우)
- **좌하단**: 캐릭터 정보 (이름, HP, 에너지, 드로우/무덤 카운트, 상태이상)
- **하단 중앙**: 카드 핸드 (부채꼴, 드로우 애니메이션)
- **우측**: End Turn 버튼 + 무덤 버튼 (클릭 시 팝업)
- **그리드**: 2:1 타일, 상단 2줄 벽 장식, 캐릭터 standing 오프셋

## 시그널 관리 규칙
- 싱글톤(BattleManager, GridManager 등)에 시그널 connect 시 반드시 `_exit_tree()`에서 disconnect
- `is_connected()` 체크 후 disconnect 패턴 사용
- 이유: 씬이 `queue_free()`로 해제된 뒤에도 싱글톤 → 해제된 노드 연결이 남아 에러 발생 가능

## 난이도/승천 시스템
- `GameManager.difficulty`: 0 = Normal, 1-20 = Ascension 레벨
- `GameManager.max_unlocked_difficulty`: 보스 클리어 시 +1 해금
- `GameManager.get_difficulty_modifiers()`: 적 HP/공격력 배율, 시작 골드, HP 패널티 등 반환
- `battle_scene.gd`에서 적 생성 시 `_apply_difficulty_modifiers()` 호출

## 동료 합류 이벤트
- 맵 노드 타입 `COMPANION` (아이콘 "+", 색상 teal)
- 파티 < 3명일 때 rows 3-6에 배치
- `GameManager.set_meta("companion_event", true)` → EVENT 씬에서 감지하여 동료 선택 UI 표시
- `GameManager.get_companion_choices()`: 파티에 없는 클래스 반환
- `GameManager.recruit_companion(id)`: 해당 클래스 캐릭터 생성 및 파티 추가

## 카드 아키타입
- **Warrior (방어→반격)**: SHIELD 효과로 방어 → SHIELD_STRIKE 효과로 방패 스택 기반 데미지
  - `shield_damage_multiplier` 필드 사용
- **Mage (원소 스택)**: `element`, `element_count` 필드로 원소 스택 축적
  - `scale_element`, `scale_per_stack`으로 스택 비례 스케일링
  - `consumes_stacks`로 스택 소모 시 대폭발
- **Rogue (콤보 체인)**: `tags` (PackedStringArray)로 태그 부여
  - `combo_tag`, `combo_bonus`로 선행 태그 확인 시 보너스 데미지
  - `combo_only`로 콤보 조건 미충족 시 효과 스킵

## 타임라인 바 애니메이션
- `_process(delta)` + `lerpf()` 기반 연속 애니메이션
- 우측(1.0) = 곧 행동 (낮은 tick), 좌측(0.0) = 방금 행동 (높은 tick)
- 행동 시 마커가 우측 끝(결승선)에 도달 → 좌측으로 리셋
- `_display_positions` (현재 표시), `_target_positions` (목표) 분리

## 그리드 비주얼 하이라이트
- **이동 범위** (파란색): `select_character()` 시 `BattleManager.has_moved_this_turn` 및 ROOT 상태 확인
- **공격 범위** (빨간색): 카드 타겟팅 진입 시 표시
- **AOE 미리보기** (주황색): AREA 카드 타겟팅 중 호버 시 `effect.area_radius` 기반 영향 범위 표시
- **경로 미리보기** (하늘색): 이동 가능 타일 호버 시 BFS 경로 표시

## 오버월드 맵
- `ScrollContainer`로 가로 스크롤 (horizontal_scroll_mode = ALWAYS)
- 마우스 휠 상/하 → 가로 스크롤 변환 (`_unhandled_input`에서 처리)
- `MapNodeButton`: 노드 타입별 색상/아이콘, 방문/도달가능/잠김 상태별 스타일
- `MapLineDrawer`: 노드 간 연결선 렌더링
