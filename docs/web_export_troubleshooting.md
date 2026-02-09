# Godot 4.4 Web Export + GitHub Pages 트러블슈팅

CI/CD: `barichello/godot-ci:4.4` Docker 이미지 + GitHub Actions
배포 대상: GitHub Pages (https://ihwoomil.github.io/gridspire/)

---

## 문제 1: export_presets.cfg 포맷 오류

### 증상
```
ERROR: Cannot export project with preset "Web" due to configuration errors:
ERROR: Project export for preset "Web" failed.
   at: _fs_changed (editor/editor_node.cpp:1084)
```
에러 메시지가 구체적인 원인을 알려주지 않아 디버깅이 어려웠음.

### 원인
수동으로 작성한 `export_presets.cfg`에 Godot 4.4가 요구하는 필드가 누락되었고,
타입이 잘못된 값이 포함됨.

| 항목 | 잘못된 값 | 올바른 값 |
|------|-----------|-----------|
| `variant/thread_support` | `1` (정수) | `false` (불리언) |
| `[preset.0]` 섹션 | `advanced_options` 누락 | `advanced_options=false` 필요 |
| `[preset.0]` 섹션 | `script_export_mode` 누락 | `script_export_mode=2` 필요 |
| `[preset.0.options]` 섹션 | `ensure_cross_origin_isolation_headers` 누락 | 해당 옵션 추가 필요 |
| `[preset.0.options]` 섹션 | `icon_512x512` 누락 | 빈 값으로라도 추가 필요 |
| `progressive_web_app/offline_page` | `"offline.html"` (없는 파일) | `""` (빈 문자열) |

### 해결
Godot 공식 레퍼런스(barichello/godot-ci test-project)와 Godot 4.4 소스코드
(`platform/web/export/export_plugin.cpp`)를 기반으로 정확한 포맷 작성.

### 교훈
- `export_presets.cfg`는 반드시 Godot 에디터에서 생성하거나, 해당 Godot 버전의 공식 레퍼런스를 참조할 것.
- 수동 작성 시 타입(bool vs int)과 필수 필드 누락에 주의.
- Godot의 "configuration errors" 메시지는 구체적 원인을 출력하지 않으므로, `--verbose` 플래그를 사용해도 도움이 제한적.

---

## 문제 2: git에 커밋되지 않은 필수 파일들

### 증상
```
SCRIPT ERROR: Parse Error: Could not find type "MapNodeButton" in the current scope.
          at: GDScript::reload (res://scripts/ui/overworld_map.gd:12)
SCRIPT ERROR: Parse Error: Could not find type "EncounterData" in the current scope.
          at: GDScript::reload (res://scripts/ui/reward_screen.gd:35)
ERROR: Failed to load script "res://scripts/ui/overworld_map.gd" with error "Parse error".
```

### 원인
로컬에서 Godot 에디터로 작업하면서 생성된 파일들이 `git add`되지 않은 채로 남아 있었음.
CI에서는 이 파일들이 없으므로 `class_name` 참조가 실패.

누락된 파일 목록 (총 117개):
- `scripts/core/encounter_resource.gd` (class_name EncounterData)
- `scripts/core/map_node_resource.gd` (class_name MapNode)
- `scripts/core/map_data_resource.gd` (class_name MapData)
- `scripts/ui/map_node_button.gd` (class_name MapNodeButton)
- `scripts/core/map_generator.gd`
- `scripts/combat/battle_scene.gd`
- `scripts/ui/character_select.gd`, `map_line_drawer.gd`
- 적 캐릭터 리소스 8개 (`resources/characters/*.tres`)
- 적 카드 43개 (`resources/cards/enemies/*.tres`)
- 씬 파일 6개 (`scenes/battle/`, `scenes/map/`, `scenes/menu/`, `scenes/ui/`)
- 스프라이트 에셋 3개 (`res/*.png`)

### 해결
`git status`로 untracked 파일 확인 후 모두 `git add` → commit → push.

### 교훈
- CI 배포 전에 반드시 `git status`로 untracked 파일을 확인할 것.
- Godot 에디터에서 새 파일을 생성하면 자동으로 git에 추가되지 않음.
- 특히 `class_name`을 선언한 스크립트는 다른 스크립트에서 타입으로 참조하므로, 하나라도 빠지면 연쇄적으로 Parse Error 발생.

### 디버깅 팁
CI workflow의 Import project 단계에서 `2>/dev/null`을 사용하면 스크립트 에러가 숨겨짐.
```yaml
# 나쁜 예 — 에러를 숨김
godot --headless --editor --quit 2>/dev/null || true

# 좋은 예 — 에러를 출력
godot --headless --editor --quit 2>&1 || true
```

---

## 문제 3: coi-serviceworker.min.js 다운로드 실패

### 증상
```
wget exit code 8 (Server issued an error response)
```
`https://raw.githubusercontent.com/nicbarker/coi-serviceworker/refs/heads/main/coi-serviceworker.min.js` 다운로드 실패.

### 원인
외부 GitHub 저장소의 URL이 변경되었거나 접근 불가.

### 해결
`variant/thread_support=false`로 설정하면 SharedArrayBuffer가 필요 없으므로
coi-serviceworker 자체가 불필요. 해당 단계를 워크플로우에서 제거.

### 교훈
- CI에서 외부 URL에 의존하는 단계는 실패할 수 있으므로, 필요한 파일은 프로젝트에 포함시키거나 대체 방안을 마련할 것.
- thread_support를 사용하지 않으면 coi-serviceworker는 불필요.
- thread_support를 켜려면: coi-serviceworker.min.js를 프로젝트에 직접 포함시킬 것.

---

## 최종 작동하는 설정

### export_presets.cfg (핵심 옵션)
```ini
[preset.0]
name="Web"
platform="Web"
runnable=true
advanced_options=false
script_export_mode=2

[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
progressive_web_app/enabled=false
progressive_web_app/offline_page=""
progressive_web_app/ensure_cross_origin_isolation_headers=true
```

### deploy-web.yml (핵심 단계)
```yaml
container:
  image: barichello/godot-ci:4.4
steps:
  # 1. Export 템플릿 복사 (컨테이너 내 경로 이동)
  - run: cp -r /root/.local/share/godot/export_templates/4.4.stable/*
         /github/home/.local/share/godot/export_templates/4.4.stable/

  # 2. 프로젝트 임포트 (2>&1로 에러 표시)
  - run: godot --headless --editor --quit 2>&1 || true

  # 3. Web 빌드 (--verbose로 상세 로그)
  - run: godot --headless --verbose --export-release "Web" build/web/index.html
```

### 참고 자료
- [barichello/godot-ci 공식 레포](https://github.com/abarichello/godot-ci)
- [godot-ci test-project export_presets.cfg](https://github.com/abarichello/godot-ci/blob/master/test-project/export_presets.cfg)
- [Godot 4.4 Web Export 문서](https://docs.godotengine.org/en/4.4/tutorials/export/exporting_for_web.html)
