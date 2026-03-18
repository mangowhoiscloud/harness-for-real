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
              │  133+ 라운드 자문자답      │  "스펙이 충분히 명확한가?"
              │  모호성 → 0.05           │
              └────────────┬────────────┘
                           │ 모호성 < 0.10일 때 자동 전환
              ┌────────────▼────────────┐
              │    Phase 1: 계획         │  Opus
              │  스펙 + 코드 분석         │  "무엇을 만들어야 하는가?"
              │  → IMPLEMENTATION_PLAN   │
              └────────────┬────────────┘
                           │ 계획 생성 시 자동 전환
              ┌────────────▼────────────┐
              │    Phase 2: 구현         │  Sonnet (5배 저렴)
              │  반복당 1개 항목 구현      │  "만들고, 테스트하고, 커밋."
              │  테스트 코드 70% 목표     │
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

## 이게 뭔가요?

**하네스(Harness)** 는 AI 코딩 에이전트가 장시간 자율적으로 동작할 때 안정적으로 작동하게 만드는 제어 구조입니다. Claude Code의 비행 컴퓨터라고 생각하면 됩니다 — 항법, 경로 수정, 안전 시스템을 담당해서 AI가 코딩에만 집중할 수 있게 합니다.

### 배경: 랄프톤(Ralphton)

[랄프톤](https://briandwjang.substack.com/p/8d3)은 **인간이 설계하고 AI 에이전트가 자율적으로 코딩하는** 새로운 형태의 해커톤입니다. 2026년 2월 한국 최초 랄프톤(팀어텐션 + 카카오벤처스 주최)에서 우승팀은:

- AI가 **10만 줄의 코드**를 작성
- 그 중 **70%가 테스트 코드** (AI가 스스로의 작업을 검증)
- 코딩 전 **133라운드의 소크라틱 리즈닝**으로 스펙 모호성 제거
- 자율 수행 구간에서 키보드를 **단 한 번도 터치하지 않음**

이 하네스는 그 우승 패턴을 재사용 가능한 시스템으로 만든 것입니다.

### 왜 `while true; do cat PROMPT.md | claude -p; done`만으로는 부족한가?

이것이 [원조 Ralph 루프](https://ghuntley.com/ralph/)이고, 작은 작업에는 잘 동작합니다. 하지만 대회 규모의 프로젝트에서는 더 많은 것이 필요합니다:

| 문제 | 기본 Ralph | 이 하네스 |
|------|-----------|----------|
| 스펙 모호성 → 잘못된 코드 | 수동 스펙 작성 | 자동화된 소크라틱 단계가 모호성 제거 |
| 에이전트가 루프에 갇힘 | 영원히 실행 | 회로 차단기가 감지 + 복구 |
| 비싼 API 비용 | 모든 곳에 하나의 모델 | Opus(사고) + Sonnet(구현) = 5배 절감 |
| 조기 "다 했어요!" 선언 | 감지 불가 | 이중 조건 종료 (마커 + 계획 확인) |
| 품질 게이트 없음 | 그냥 잘 되길 기도 | 훅이 타입체크 + 린트 + 테스트 강제 |
| 수동 단계 전환 | `./loop.sh plan` → `./loop.sh build` | 자동 단계 전환 |
| 진행 상황 확인 불가 | 로그 직접 읽기 | 실시간 모니터링 대시보드 |

---

## 빠른 시작

### 사전 요구사항

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) 설치 및 인증 완료
- Git
- 프로젝트 아이디어 + 스펙

### 1. 클론

```bash
git clone https://github.com/mangowhoiscloud/harness-for-real.git
cd harness-for-real
```

### 2. 스펙 작성

`specs/` 디렉토리에 스펙 파일을 만듭니다. 하나의 스펙 파일은 하나의 기능 또는 관심사를 다뤄야 합니다:

```bash
# 좋은 예: 관심사별로 분리
specs/user-authentication.md
specs/data-model.md
specs/api-endpoints.md
specs/error-handling.md

# 나쁜 예: 모든 것을 하나에
specs/everything.md
```

**"한 문장 테스트"**: 스펙이 다루는 내용을 설명할 때 "그리고"가 필요하다면, 여러 파일로 분리하세요.

### 3. 초기화

```bash
bash init.sh
```

프로젝트 타입(Node/Python/Rust/Go/Java)을 자동 감지하고 빌드 명령어를 설정합니다.

### 4. 실행

```bash
bash loop.sh
```

이것으로 끝입니다. 하네스가 여기서부터 모든 것을 처리합니다:
- **소크라틱 단계**: 스펙의 모호성 제거 (최대 150라운드)
- **계획 단계**: `IMPLEMENTATION_PLAN.md` 생성
- **구현 단계**: 반복당 1개 항목을 구현 + 테스트
- **검증 단계**: 3-에이전트 최종 검증

### 5. 모니터링 (선택사항)

별도 터미널에서:

```bash
bash scripts/monitor.sh
```

현재 단계, 완료 항목, 모호성 점수, 비용 추적 등을 실시간으로 보여줍니다.

---

## 작동 원리

### 코어 루프

```bash
while true; do
  cat PROMPT_${PHASE}.md | claude -p --model $MODEL --dangerously-skip-permissions
  # 다음 단계로 전환해야 하는가?
  # 에이전트가 막혔는가? (회로 차단기)
  # 변경사항을 git에 push
done
```

매 반복마다:
1. **깨끗한 컨텍스트 윈도우**로 시작 (누적된 혼란 없음)
2. **파일**에서 상태를 읽음 (progress.txt, IMPLEMENTATION_PLAN.md, git 히스토리)
3. **하나의 작업 단위**를 수행
4. 결과를 **파일 + git**에 저장
5. 깔끔하게 종료

핵심 원리: **기억은 컨텍스트 윈도우가 아닌 파일 시스템에 저장됩니다.** 이 덕분에 에이전트가 수시간 동안 성능 저하 없이 작업할 수 있습니다.

### 단계 전환

조건이 충족되면 자동으로 전환됩니다:

| 출발 | 도착 | 전환 조건 |
|------|------|----------|
| 소크라틱 | 계획 | CLARITY_LOG.md에서 `AMBIGUITY_SCORE < 0.10` |
| 계획 | 구현 | IMPLEMENTATION_PLAN.md가 항목과 함께 존재 |
| 구현 | 검증 | 계획에 `status: TODO`나 `status: IN_PROGRESS`가 없음 |
| 검증 | 완료 | progress.txt에 `HARNESS_COMPLETE` 마커 |
| 검증 | 구현 | 검증 실패 → 새 항목이 계획에 추가되어 구현으로 회귀 |

### 회로 차단기 (Circuit Breaker)

에이전트가 **5회 연속 git 커밋을 생성하지 못하면**:

1. Sonnet 실행 중이면 → 한 번의 복구 시도를 위해 Opus로 에스컬레이션
2. 이미 Opus면 → 다음 단계로 강제 전환
3. 다음 단계가 없으면 → 중단 후 보고

막힌 루프에 API 크레딧을 낭비하는 것을 방지합니다.

### 백프레셔 (Back Pressure)

두 개의 훅이 자동으로 품질을 강제합니다:

**`hooks/backpressure.sh`** — 매 Write/Edit 후 실행:
- 타입체크 (tsc, mypy, cargo check, go vet)
- 린트 (eslint, ruff, clippy, golangci-lint)
- 실패 시 → 에이전트가 자동으로 문제를 수정

**`hooks/pre-commit-gate.sh`** — 매 커밋 전 실행:
- 전체 테스트 스위트 통과 필수
- 건너뛴 테스트 없어야 함 (it.skip, @pytest.mark.skip)
- 실패 시 → 에이전트가 수정 후에만 커밋 가능

### 모델 라우팅

| 단계 | 모델 | 이유 |
|------|------|------|
| 소크라틱 | Opus | 모호성 분석에는 깊은 추론이 필요 |
| 계획 | Opus | 아키텍처 결정에는 신중한 사고가 필요 |
| 구현 | Sonnet | 구현은 잘 정의되어 있으므로 속도와 비용이 중요 |
| 검증 | Opus | 최종 검증에는 꼼꼼함이 필요 |

모든 곳에 Opus를 쓰는 것 대비 **약 5배 비용 절감**.

---

## 파일 구조

```
harness-for-real/
├── loop.sh                 # 메인 오케스트레이터 — 4-Phase FSM
├── init.sh                 # 환경 부트스트랩 (프로젝트 타입 자동 감지)
├── CLAUDE.md               # 프로젝트 규칙 (매 Claude 세션마다 자동 로드)
├── AGENTS.md               # 운영 가이드 (60줄 미만)
│
├── PROMPT_socratic.md      # Phase 0: 스펙 모호성 제거
├── PROMPT_plan.md          # Phase 1: 구현 계획 생성
├── PROMPT_build.md         # Phase 2: 반복당 1개 항목 구현
├── PROMPT_verify.md        # Phase 3: 3-에이전트 최종 검증
│
├── hooks/
│   ├── backpressure.sh     # Post-tool: 타입체크 + 린트
│   └── pre-commit-gate.sh  # Pre-commit: 테스트 스위트 게이트
│
├── scripts/
│   └── monitor.sh          # 실시간 진행 대시보드
│
├── specs/                  # 스펙 파일을 여기에 작성
│   └── .gitkeep
│
├── examples/
│   ├── word-counter/       # 데모: Python CLI 단어 빈도 분석기
│   │   ├── specs/
│   │   └── run-demo.sh
│   └── reode-migration-target/  # 데모: Java 레거시 마이그레이션 대상
│       ├── specs/
│       └── run-demo.sh
│
└── RESEARCH.md             # 설계 근거가 되는 전체 리서치
```

### 하네스 실행 중 생성되는 파일

```
CLARITY_LOG.md              # 소크라틱 Q&A 라운드 + 모호성 점수
IMPLEMENTATION_PLAN.md      # 상태가 포함된 우선순위 작업 목록
progress.txt                # 세션별 진행 로그
.harness-logs/              # 반복별 로그, 비용 추적
```

---

## 설정

모든 설정은 환경변수로 제어합니다:

```bash
# 단계별 반복 제한
MAX_SOCRATIC=150    # 기본값: 150 (우승팀은 133회 진행)
MAX_PLAN=10         # 기본값: 10
MAX_BUILD=999       # 기본값: 999 (무제한, 회로 차단기로 보호)
MAX_VERIFY=20       # 기본값: 20

# 회로 차단기
MAX_STUCK=5         # 진행 없는 연속 반복 횟수 임계값

# 모델 지정
OPUS_MODEL=opus     # 또는 특정 모델 ID
SONNET_MODEL=sonnet

# 권한 모드
PERMISSION_MODE="--dangerously-skip-permissions"  # 헤드리스 자율 모드

# 출력 형식
OUTPUT_FORMAT=stream-json  # 비용 추적용; 간단한 출력은 "text"
```

### 특정 단계부터 시작

```bash
bash loop.sh socratic   # 전체 실행 (기본값)
bash loop.sh plan       # 소크라틱 건너뛰고 계획부터
bash loop.sh build      # 구현부터 (계획이 있을 때)
bash loop.sh verify     # 검증부터 (구현이 끝났을 때)
```

### 반복 횟수를 줄여서 빠르게 테스트

```bash
MAX_SOCRATIC=3 MAX_PLAN=2 MAX_BUILD=10 MAX_VERIFY=2 bash loop.sh
```

---

## 예제

### Word Counter CLI (Python)

하네스의 동작을 확인하기 위한 가벼운 데모:

```bash
cd examples/word-counter
bash run-demo.sh
```

2개의 스펙 파일로 Python 단어 빈도 분석기를 만듭니다. 빠른 실행을 위해 반복 횟수를 줄여둔 설정입니다.

### REODE 마이그레이션 대상 (Java)

마이그레이션 테스트를 위한 Java 1.8 + Spring Framework 4.3.4 레거시 코드베이스:

```bash
cd examples/reode-migration-target
bash run-demo.sh
```

순환참조, XML 설정, 필드 인젝션 등 의도적인 레거시 안티패턴이 포함된 실제적인 Java 프로젝트를 생성합니다. 마이그레이션 도구의 테스트 대상으로 활용할 수 있습니다.

---

## 우승 공식

랄프톤 우승팀 분석을 기반으로:

### 1. 모호성을 먼저 제거하라

> 우승팀은 코드 한 줄 작성하기 전에 133라운드의 소크라틱 리즈닝을 실행했다. 모호성 점수는 0.05까지 떨어졌다.

소크라틱 단계는 가장 레버리지가 높은 투자입니다. 30분의 컴퓨팅으로 스펙을 명확히 하면 수시간의 잘못된 구현을 절약합니다.

### 2. 모든 것을 테스트하라

> 10만 줄 중 7만 줄이 테스트 코드였다.

`PROMPT_build.md`는 70% 테스트 코드를 목표로 합니다. 테스트는 에이전트의 자기 검증 메커니즘입니다 — 테스트 없이는 에러가 반복마다 누적됩니다.

### 3. 반복당 하나의 항목만

> 매 반복은 계획에서 정확히 하나의 작업만 처리한다.

범위 확대(scope creep)는 자율 루프의 1번 킬러입니다. 하네스는 신선한 컨텍스트로 단일 항목 반복을 강제합니다.

### 4. 비용을 최적화하라

> 3등팀의 교훈: 비싼 모델은 초반에, 저렴한 모델은 후반에.

Opus는 추론 단계(소크라틱, 계획, 검증)에, Sonnet은 구현 단계에. 같은 품질, 약 5배 적은 비용.

### 5. 키보드 터치 제로

> 우승팀은 자율 수행 구간에서 키보드를 단 한 번도 터치하지 않았다.

키보드를 만지고 있다면, 하네스가 충분히 좋지 않은 것입니다. 코드가 아니라 하네스를 고치세요.

---

## 기존 하네스와의 차이점

### [ghuntley/how-to-ralph-wiggum](https://github.com/ghuntley/how-to-ralph-wiggum)

Ralph 루프의 원조 플레이북. 이 하네스는 여기에 다음을 추가합니다:
- 자동화된 소크라틱 사전 단계 (ghuntley의 Phase 1은 수동 스펙 작성)
- 자동 단계 전환 (ghuntley는 수동 모드 전환 필요)
- 회로 차단기 (플레이북에 없음)
- 3-에이전트 검증 단계

### [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code)

회로 차단기와 종료 감지가 포함된 우수한 Claude Code 플러그인. 이 하네스와의 차이:
- 4단계 아키텍처 (vs. 단일 단계 루프)
- 소크라틱 리즈닝 단계
- 모델 라우팅 (Opus/Sonnet)
- 독립 스크립트로 구성 (플러그인 설치 불필요)

### [Chachamaru127/claude-code-harness](https://github.com/Chachamaru127/claude-code-harness)

TypeScript 가드레일이 포함된 Plan→Work→Review→Release 사이클. 이 하네스는:
- 소크라틱 사전 단계 추가
- Bash 사용 (의존성 제로, 어디서든 실행)
- 비용 최적화 모델 라우팅
- 대회(랄프톤) 맥락에 특화된 설계

---

## 리서치

설계 근거가 되는 전체 리서치는 [RESEARCH.md](./RESEARCH.md)에서 확인할 수 있습니다:
- 랄프톤 우승팀 분석
- Ralph 루프의 역사와 진화
- 하네스 엔지니어링 원칙 (Anthropic, HumanLayer, LangChain, OpenAI)
- 도구 비교 매트릭스
- 산업 벤치마크 (Stripe Minions, OpenAI Codex, LangChain Terminal Bench)

---

## 감사의 말

다음의 기여 위에 구축되었습니다:
- [Geoffrey Huntley](https://ghuntley.com/ralph/) — Ralph 루프의 창시자
- [Anthropic](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) — 장기 실행 에이전트 연구
- [HumanLayer](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents) — 하네스 엔지니어링 모범 사례
- [팀어텐션 + 카카오벤처스](https://briandwjang.substack.com/p/8d3) — 한국 최초 랄프톤 개최
- 랄프톤 우승팀 — 소크라틱 리즈닝 + 70% 테스트 + 키보드 제로 = 승리를 증명

---

## 라이선스

MIT
