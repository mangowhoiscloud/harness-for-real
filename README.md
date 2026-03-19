# harness-for-real

**랄프톤 & AI 에이전트 해커톤을 위한 경쟁급 자율 수행 하네스.**

당신이 자는 동안 AI가 10만 줄의 코드를 작성합니다. 이 하네스는 그 코드가 *올바른* 코드인지 보장합니다.

```
                    ┌──────────────┐
                    │  당신이 스펙을  │
                    │    작성한다    │
                    └──────┬───────┘
                           │
              ┌────────────▼────────────┐
              │  Phase 0: 소크라틱 리즈닝  │  Opus
              │  자문자답으로 모호성 제거   │  "스펙이 충분히 명확한가?"
              │  + 수렴 가속 (v2)        │
              └────────────┬────────────┘
                           │ 모호성 임계값 or 수렴 감지 시 자동 전환
              ┌────────────▼────────────┐
              │    Phase 1: 계획         │  Opus
              │  스펙 + 코드 분석         │  "무엇을 만들어야 하는가?"
              │  → IMPLEMENTATION_PLAN   │
              │  + 의존 그래프 + 병렬 그룹 │
              └────────────┬────────────┘
                           │ 계획 생성 시 자동 전환
              ┌────────────▼────────────┐
              │    Phase 2: 구현         │  적응형 라우팅 (v2)
              │  독립 항목 → 병렬 빌드    │  Sonnet 기본, 실패 시 Opus
              │  의존 항목 → 순차 빌드    │  + 런타임 학습 주입
              └────────────┬────────────┘
                           │ 모든 항목 DONE일 때 자동 전환
              ┌────────────▼────────────┐
              │    Phase 3: 검증         │  Opus
              │  3-에이전트 검증          │  "실제로 동작하는가?"
              │  Validator+Coordinator   │
              │  +Packer                 │
              └────────────┬────────────┘
                           │
                     ┌─────▼─────┐
                     │   완료     │
                     └───────────┘
```

---

## 하네스란

AI 코딩 에이전트가 장시간 자율적으로 동작할 때, 방향을 잃지 않고 안정적으로 작동하게 만드는 제어 구조입니다. 항법과 경로 수정, 안전 시스템을 담당하는 비행 컴퓨터 — AI는 코딩에만 집중하고, 하네스가 나머지를 맡습니다.

### 왜 만들었는가

[랄프톤(Ralphton)](https://briandwjang.substack.com/p/8d3)은 인간이 설계하고 AI 에이전트가 자율적으로 코딩하는 해커톤입니다. 2026년 2월 한국 최초 랄프톤에서 우승팀은 AI에게 10만 줄의 코드를 작성시키면서 키보드를 단 한 번도 터치하지 않았습니다. 이 하네스는 그 우승 전략을 재사용 가능한 시스템으로 만든 것입니다.

---

## 설계 원칙

우승팀 분석과 글로벌 사례 리서치에서 도출한 5가지 원칙이 이 하네스의 모든 설계 결정을 관통합니다.

### 1. 코딩 전에 모호성을 제거하라

우승팀은 코드를 짜기 전에 133라운드의 소크라틱 리즈닝을 실행하여 모호성 점수를 0.05까지 낮췄습니다. 입력(스펙)의 품질이 출력(코드)의 품질을 결정합니다 — 스펙이 모호하면 에이전트는 수만 줄의 잘못된 코드를 자신 있게 작성합니다. 이 하네스는 Phase 0에서 이 과정을 자동화합니다.

### 2. 에이전트가 자기 작업을 검증할 수 있어야 한다

우승팀의 10만 줄 중 7만 줄이 테스트 코드였습니다. 테스트는 에이전트의 자기 검증 메커니즘이며, 이것 없이는 에러가 반복마다 누적됩니다. 하네스는 70% 테스트 코드를 목표로 하고, 훅으로 타입체크/린트/테스트 통과를 강제합니다.

### 3. 한 번에 하나만 처리하라

범위 확대(scope creep)는 자율 루프의 1번 킬러입니다. 매 반복은 계획에서 정확히 하나의 작업만 처리하고, 신선한 컨텍스트로 다음 반복을 시작합니다.

### 4. 사고에는 비싼 모델, 구현에는 빠른 모델

3등팀의 교훈: 초반에 비싼 모델을 쓰고 후반에는 저렴한 모델로 전환하라. Opus(소크라틱, 계획, 검증)와 Sonnet(구현)을 분리하면 동일한 품질에 약 5배 적은 비용이 듭니다.

### 5. 키보드를 만지고 있다면 하네스를 고쳐라

키보드를 터치하는 것은 하네스가 불완전하다는 신호입니다. 코드가 아니라 하네스를 개선하세요.

---

## 왜 기본 Ralph 루프로는 부족한가

`while true; do cat PROMPT.md | claude -p; done` — [원조 Ralph 루프](https://ghuntley.com/ralph/)는 작은 작업에 잘 동작합니다. 대회 규모에서는:

| 문제 | 기본 Ralph | 이 하네스 |
|------|-----------|----------|
| 스펙 모호성 → 잘못된 코드 | 수동 스펙 작성 | 소크라틱 단계가 모호성 자동 제거 |
| 에이전트가 루프에 갇힘 | 영원히 실행 | 예측형 회로 차단기 + Opus 에스컬레이션 + 강제 전환 |
| 비싼 API 비용 | 단일 모델 | 적응형 Opus/Sonnet 라우팅 + 예산 강제 |
| 조기 완료 선언 | 감지 불가 | 이중 조건 종료 (마커 + 계획 상태 확인) |
| 품질 게이트 없음 | 기도 | 훅이 타입체크 + 린트 + 테스트 + TODO 검사 강제 |
| 수동 단계 전환 | `./loop.sh plan` 수동 실행 | 4-Phase FSM 자동 전환 |
| 크래시 시 처음부터 | 상태 유실 | 체크포인트 자동 저장 + 재시작 |

---

## 빠른 시작

### 사전 요구사항

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) 설치 및 인증
- Git

### 1. 클론

```bash
git clone https://github.com/mangowhoiscloud/harness-for-real.git
cd harness-for-real
```

### 2. 스펙 작성

`specs/` 디렉토리에 스펙 파일을 만듭니다. 하나의 파일은 하나의 관심사를 다뤄야 합니다:

```bash
specs/user-authentication.md   # 인증
specs/data-model.md            # 데이터 모델
specs/api-endpoints.md         # API 엔드포인트
specs/error-handling.md        # 에러 처리
```

**"한 문장 테스트"**: 스펙을 설명할 때 "그리고"가 필요하면 분리하세요.

### 3. 초기화

```bash
bash init.sh
```

프로젝트 타입을 자동 감지하고(Node/Python/Rust/Go/Java + 패키지 매니저), `.harness-config`에 빌드/테스트/린트 커맨드를 저장합니다. 이 파일이 이후 모든 동작의 설정 소스가 됩니다.

### 4. 실행

```bash
bash loop.sh
```

하네스가 4단계를 자동으로 진행합니다:
- **소크라틱** → 스펙 모호성 제거 (최대 150라운드, 수렴 가속)
- **계획** → `IMPLEMENTATION_PLAN.md` 생성 (의존 그래프 + 병렬 그룹)
- **구현** → 독립 항목 병렬 빌드 + 순차 빌드 (적응형 모델 라우팅)
- **검증** → 3-에이전트 최종 검증

### 5. 모니터링 (선택)

별도 터미널에서:

```bash
bash scripts/monitor.sh
```

현재 단계, 완료 항목, 모호성 점수, 비용, 스펙 변경 감지를 실시간으로 표시합니다.

---

## 작동 원리

### 코어 메커니즘

**루프**: 매 반복마다 깨끗한 컨텍스트 윈도우로 시작하고, 상태는 파일 시스템(progress.txt, IMPLEMENTATION_PLAN.md, git)에 저장됩니다. 기억을 컨텍스트가 아닌 파일에 외부화하는 것이 핵심 — 에이전트가 수시간 작업해도 성능이 저하되지 않습니다.

**단계 전환**: 조건이 충족되면 자동으로 다음 단계로 넘어갑니다:

| 출발 | 도착 | 조건 |
|------|------|------|
| 소크라틱 | 계획 | `AMBIGUITY_SCORE < AMBIGUITY_THRESHOLD` (기본 0.10) |
| 계획 | 구현 | IMPLEMENTATION_PLAN.md에 항목 존재 |
| 구현 | 검증 | `status: TODO`나 `IN_PROGRESS` 항목 없음 |
| 검증 | 완료 | `HARNESS_COMPLETE` 마커 |
| 검증 | 구현 | 검증 실패 시 새 항목 추가 → 구현으로 회귀 |

**모델 라우팅**: Opus는 추론이 필요한 단계(소크라틱, 계획, 검증)에, Sonnet은 구현 단계에 배치됩니다. v2에서는 **적응형 라우팅**이 추가되어, 구현 중 아이템의 복잡도(S/M/L/XL)와 실패 횟수에 따라 자동으로 Opus로 에스컬레이션합니다.

### v2 기능

**병렬 빌드**: `scripts/plan-parser.sh`가 IMPLEMENTATION_PLAN.md의 의존 그래프를 분석하여 독립 아이템을 식별합니다. `scripts/parallel-build.sh`가 git worktree로 각 아이템을 별도 브랜치에서 동시 빌드하고, 완료 후 메인 브랜치에 자동 머지합니다. 머지 충돌 시 순차 빌드로 폴백합니다.

**예측형 회로 차단기**: 기본 회로 차단기(연속 N회 커밋 없음)에 더해, 에이전트의 실패 패턴을 분석합니다. `PREDICTIVE_STUCK` 횟수 이상 실패하면 에이전트의 제안(SPLIT/ESCALATE/SKIP)에 따라 전략을 전환합니다.

**런타임 학습 주입**: 구현 단계에서 에이전트가 발견한 교훈을 `LEARNINGS.md`에 축적합니다. 다음 반복 시 프롬프트에 자동 주입되어, 같은 실수를 반복하지 않습니다.

**수렴 가속**: 소크라틱 단계에서 모호성 점수가 `CONVERGENCE_STAGNATION` 라운드 연속 변화 없이 `CONVERGENCE_THRESHOLD` 이하이면 조기 전환합니다. 불필요한 반복을 줄여 비용을 절감합니다.

### 품질 보장

**백프레셔**: 두 개의 훅이 `.harness-config`에서 커맨드를 읽어 자동 실행합니다:

- **`backpressure.sh`** (Write/Edit마다, 60초 타임아웃) — 타입체크 + 린트. 실패 시 에이전트가 즉시 수정.
- **`pre-commit-gate.sh`** (커밋마다, 120초 타임아웃) — 테스트 스위트 + skip 마커 차단(it.skip, @pytest.mark.skip, @Disabled) + 소스 코드 TODO/FIXME 차단. 실패 시 커밋 불가.

`.harness-config`가 없으면 pre-commit-gate가 커밋을 차단하여, init.sh 미실행 상태에서 백프레셔 없이 코드가 커밋되는 것을 방지합니다.

**테스트 비율 측정**: `bash scripts/test-ratio.sh`로 소스 대비 테스트 코드 비율을 확인할 수 있습니다 (목표: 70%).

### 안전장치

**회로 차단기**: `MAX_STUCK`회(기본 5) 연속 git 커밋이 없으면 작동합니다. Sonnet이면 Opus로 에스컬레이션, Opus이면 "RECOVERY MODE" 컨텍스트를 주입하여 다른 접근을 유도합니다. 복구 실패 시 다음 단계로 강제 전환합니다. v2의 **예측형 회로 차단기**는 `PREDICTIVE_STUCK`회(기본 2) 실패 시 선제적으로 모델 에스컬레이션 또는 아이템 분할을 시도합니다.

**예산 강제**: `MAX_BUDGET_USD=30 bash loop.sh`로 설정. 80% 도달 시 경고, 100% 시 체크포인트 저장 후 자동 중단합니다. 토큰당 가격은 `.harness-config`에서 관리됩니다.

**체크포인트**: 매 반복마다 `.harness-logs/harness-state.json`에 상태를 저장합니다. 크래시 후 `bash loop.sh`로 마지막 지점부터 재시작되고, `bash loop.sh socratic --fresh`로 처음부터 시작할 수 있습니다.

**스펙 변경 감지**: `init.sh`가 `specs/` 해시를 저장하고, `monitor.sh`가 실시간으로 변경을 감지합니다. 소크라틱 완료 후 스펙이 수정되면 CLARITY_LOG.md 무효화 경고를 표시합니다.

### 외부 문서 통합 (Context Hub)

[context-hub](https://github.com/andrewyng/context-hub) (`chub`)를 통해 에이전트가 외부 API/SDK의 최신 문서를 실시간으로 조회합니다. LLM 지식 컷오프로 인한 API 할루시네이션을 방지합니다.

- `init.sh`가 chub 설치 여부를 감지하고, 프로젝트 타입에 맞는 문서 인덱스를 `.context/`에 프리페치
- 각 페이즈 프롬프트에 chub 조회 스텝이 내장되어, 에이전트가 외부 라이브러리 사용 시 자동으로 최신 문서를 참조
- 설치: `npm install -g @aisuite/chub` (없으면 `npx`로 폴백)

```bash
# 에이전트가 사용하는 패턴
chub search "stripe"              # 문서 검색
chub get stripe/api --lang py     # 문서 가져오기
chub annotate stripe/api "note"   # 학습 내용 기록 (세션 간 유지)
```

---

## 예제

### Word Counter CLI (Python)

2개 스펙 파일로 단어 빈도 분석기를 자율 생성하는 가벼운 데모:

```bash
cd examples/word-counter
bash run-demo.sh
```

**데모 실행 결과** (2026-03-19 전체 완주):

| 페이즈 | 반복 | 소요 | 비용 | 비고 |
|--------|------|------|------|------|
| Socratic | 1 | ~3분 | $0.63 | 모호성 0.00, 즉시 통과 |
| Plan | 1 | ~3분 | $0.59 | 5 항목, 3 병렬 그룹 |
| Build | 8 | ~25분 | $1.31 | 병렬 빌드 → 순차 빌드, 회로 차단기 1회 |
| Verify | 1 | ~4분 | $0.52 | 3-에이전트 검증 통과 |
| **합계** | **11** | **37분** | **$3.06** | **5모듈 + 5테스트 자율 생성** |

생성된 의존 그래프와 병렬 빌드:
```
group_1 (병렬):  Tokenizer ──┐
                 Counter ─────┼──→ group_2: CLI ──→ Integration Tests
                 Formatter ───┘
```

### REODE 마이그레이션 대상 (Java)

Java 1.8 + Spring Framework 4.3.4 레거시 코드베이스를 자율 생성하는 데모. 순환참조, XML 설정, 필드 인젝션 등 의도적인 안티패턴이 포함되어 마이그레이션 도구의 테스트 대상으로 활용 가능:

```bash
cd examples/reode-migration-target
bash run-demo.sh
```

---

## 설정

### .harness-config (단일 진실 소스)

`init.sh` 실행 시 자동 생성되며, 모든 훅과 loop.sh가 이 파일을 source합니다:

```bash
PROJECT_TYPE="python-uv"
PKG_MGR="uv"
BUILD_CMD="uv build"
TEST_CMD="uv run pytest"
LINT_CMD="uv run ruff check ."
TYPECHECK_CMD="uv run mypy . 2>/dev/null || true"
SRC_DIRS="src/ lib/"
TEST_DIRS="tests/ test/"

OPUS_MODEL="${OPUS_MODEL:-opus}"
SONNET_MODEL="${SONNET_MODEL:-sonnet}"

# 토큰당 가격 (모델 업데이트 시 수정)
OPUS_INPUT_PRICE=0.000015
OPUS_OUTPUT_PRICE=0.000075
SONNET_INPUT_PRICE=0.000003
SONNET_OUTPUT_PRICE=0.000015

AMBIGUITY_THRESHOLD=0.10
TEST_CODE_RATIO_TARGET=0.70
```

`init.sh`는 다중 프로젝트 파일 감지 시 경고를 출력하며, 패키지 매니저(npm/yarn/pnpm/bun)를 자동으로 구분합니다. 에이전트가 AGENTS.md를 수정한 경우 재실행 시에도 내용을 보존합니다.

### 환경변수 오버라이드

```bash
MAX_SOCRATIC=150          # 소크라틱 최대 반복 (기본 150)
MAX_PLAN=10               # 계획 최대 반복 (기본 10)
MAX_BUILD=999             # 구현 최대 반복 (기본 999, 회로 차단기 보호)
MAX_VERIFY=20             # 검증 최대 반복 (기본 20)
MAX_STUCK=5               # 회로 차단기 임계값 (기본 5)
PREDICTIVE_STUCK=2        # v2: 예측형 에스컬레이션 임계값 (기본 2)
MAX_PARALLEL=3            # v2: 병렬 빌드 최대 워커 수 (기본 3)
CONVERGENCE_THRESHOLD=0.15 # v2: 수렴 가속 임계값 (기본 0.15)
CONVERGENCE_STAGNATION=3  # v2: 수렴 정체 감지 라운드 (기본 3)
MAX_BUDGET_USD=50         # 예산 한도 (기본 0=무제한)
PERMISSION_MODE="--dangerously-skip-permissions"  # 헤드리스 모드
```

### 실행 옵션

```bash
bash loop.sh              # 전체 실행 (소크라틱부터, 체크포인트 있으면 재시작)
bash loop.sh plan         # 계획부터 시작
bash loop.sh build        # 구현부터 시작
bash loop.sh verify       # 검증부터 시작
bash loop.sh socratic --fresh  # 체크포인트 무시, 처음부터

# 빠른 테스트
MAX_SOCRATIC=3 MAX_PLAN=2 MAX_BUILD=10 MAX_VERIFY=2 bash loop.sh
```

---

## 파일 구조

```
harness-for-real/
├── loop.sh                 # 4-Phase FSM + 체크포인트 + 예산 강제
├── init.sh                 # 환경 감지 → .harness-config 생성
├── CLAUDE.md               # 프로젝트 규칙 (매 세션 자동 로드)
├── AGENTS.md               # 운영 가이드 (60줄 미만)
├── PROMPT_socratic.md      # Phase 0: 모호성 제거
├── PROMPT_plan.md          # Phase 1: 구현 계획
├── PROMPT_build.md         # Phase 2: 구현 + 테스트
├── PROMPT_verify.md        # Phase 3: 3-에이전트 검증
├── hooks/
│   ├── backpressure.sh     # 타입체크 + 린트 (Post-tool)
│   └── pre-commit-gate.sh  # 테스트 + TODO 검사 (Pre-commit)
├── scripts/
│   ├── monitor.sh          # 실시간 대시보드
│   ├── plan-parser.sh      # IMPLEMENTATION_PLAN.md 파서 (의존성, 병렬 그룹)
│   ├── parallel-build.sh   # git worktree 기반 병렬 빌드 오케스트레이터
│   └── test-ratio.sh       # 테스트 코드 비율 측정
├── specs/                  # 스펙 파일
├── examples/               # word-counter, reode-migration-target
├── docs/blog/              # 하네스 엔지니어링 블로그 포스트
└── RESEARCH.md             # 설계 근거 전체 리서치
```

### 실행 중 생성되는 파일

| 파일 | 용도 |
|------|------|
| `.harness-config` | 단일 설정 소스 (init.sh 생성) |
| `CLARITY_LOG.md` | 소크라틱 Q&A + 모호성 점수 |
| `IMPLEMENTATION_PLAN.md` | 우선순위 작업 목록 + 상태 |
| `progress.txt` | 세션별 진행 로그 |
| `.harness-logs/harness-state.json` | 체크포인트 |
| `.harness-logs/cost.log` | 토큰/비용 기록 |
| `.harness-logs/phase.log` | 단계 전환 이벤트 |
| `.harness-logs/metrics.log` | v2: 반복별 메트릭 (에러 수, 아이템 실패) |
| `.harness-logs/specs.hash` | 스펙 변경 감지용 해시 |
| `LEARNINGS.md` | v2: 런타임 학습 축적 (세션 간 유지) |

---

## 기존 하네스와의 차이점

| | [ghuntley 플레이북](https://github.com/ghuntley/how-to-ralph-wiggum) | [ralph-claude-code](https://github.com/frankbria/ralph-claude-code) | [claude-code-harness](https://github.com/Chachamaru127/claude-code-harness) | **이 하네스** |
|---|---|---|---|---|
| 소크라틱 사전 단계 | 수동 스펙 | 없음 | 없음 | 자동화 |
| 단계 전환 | 수동 | 종료 감지만 | Plan→Work→Review | 4-Phase FSM 자동 |
| 회로 차단기 | 없음 | 있음 | 없음 | 대칭 복구 + 예측형 에스컬레이션 |
| 모델 라우팅 | 없음 | 없음 | 없음 | 적응형 Opus/Sonnet (복잡도 기반) |
| 병렬 빌드 | 없음 | 없음 | 없음 | git worktree 독립 아이템 동시 빌드 |
| 런타임 학습 | 없음 | 없음 | 없음 | LEARNINGS.md 축적 + 자동 주입 |
| 예산 강제 | 없음 | 속도 제한 | 없음 | 토큰 기반 자동 중단 |
| 체크포인트 | 없음 | 세션 연속성 | 없음 | JSON 상태 파일 |
| 의존성 | 없음 | npm 플러그인 | TypeScript + Node | Bash only |

---

## 리서치

설계 근거가 되는 전체 리서치는 [RESEARCH.md](./RESEARCH.md)에서 확인할 수 있습니다. 하네스 엔지니어링의 진화와 글로벌 트렌드를 다룬 블로그 포스트는 [docs/blog/](./docs/blog/harness-engineering-era.md)에 있습니다.

---

## 감사의 말

- [Geoffrey Huntley](https://ghuntley.com/ralph/) — Ralph 루프의 창시자
- [Anthropic](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) — 장기 실행 에이전트 연구
- [HumanLayer](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents) — 하네스 엔지니어링 모범 사례
- [팀어텐션 + 카카오벤처스](https://briandwjang.substack.com/p/8d3) — 한국 최초 랄프톤 개최

---

## 라이선스

Apache License 2.0 — [LICENSE](./LICENSE) 참조
