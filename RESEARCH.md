# 랄프톤 & 하네스 엔지니어링 종합 리서치

> 2026년 3월 기준 | 자율 수행 하네스 구축을 위한 리서치

---

## 1. 랄프톤(Ralphton)이란?

### 정의
- **"인간은 퇴근하고 AI가 코딩한다"** 콘셉트의 해커톤
- 참가자는 아이디어와 설계도(하네스)만 제시, 실제 코딩은 AI 에이전트가 자율 수행
- 기존 해커톤: 인간이 코딩 → 랄프톤: 인간이 설계, AI가 코딩

### 한국 최초 랄프톤 (2026.02.28 ~ 03.01)
- **주최**: 팀어텐션 + 카카오벤처스
- **후원**: OpenAI
- **장소**: 서울 성북구
- **참가**: 예선 → 9개 팀 본선 (스타트업 개발자/창업자)
- **방식**: 1박 2일, 첫날 하네스 엔지니어링 → 에이전트 자율 루프 → 다음날 결과 평가

### 우승팀 분석 ⭐
| 항목 | 내용 |
|------|------|
| **프로젝트** | 고정캠 영상 기반 가사노동 자동화 봇 |
| **코드량** | 100,000줄 (AI 에이전트가 작성) |
| **테스트 비율** | 70% (70,000줄이 테스트 코드) |
| **핵심 전략** | 소크라틱 리즈닝 133회 루프 → 모호성 지수 0.05까지 감소 |
| **키보드 터치** | 0회 (완전 자율) |
| **검증 시스템** | Validator + Coordinator + Packer 다중 검증 |

### 우승 핵심 공식
```
Ambiguity = 1 − Σ(clarityᵢ × weightᵢ)
```
- 133회 에이전트 간 Q&A로 설계 모호성 사전 제거
- "I ship code I don't read" — 인간이 읽기 좋은 코드보다 AI가 이해하기 좋은 구조 설계

### 3등팀 교훈
- 초기: 비싼 모델(Opus) → 후반: 저렴한 모델로 동일 성능
- **비용 최적화**가 실전에서 중요

### 실패 패턴
- 스펙 급속 확장 + 병렬 워크트랙 → 모호성 증대 → 실패

---

## 2. Ralph Loop — 기원과 핵심

### 기원
- **창시자**: Geoffrey Huntley (2025년 7월)
- **이름 유래**: 심슨 가족의 Ralph Wiggum 캐릭터 (밈적 표현)
- **핵심**: `while :; do cat PROMPT.md | claude -p ; done`

### 핵심 철학
- **"루프 위에 앉으세요, 루프 안에 있지 않고"**
- 각 반복마다 깨끗한 컨텍스트로 시작
- 진행 상황은 파일과 git 히스토리에 저장
- 테스트/린트/타입체크로 작업 검증 (백프레셔)
- 최종 일관성은 반복을 통해 달성

### 타임라인
| 시기 | 이벤트 |
|------|--------|
| 2025.07 | Geoffrey Huntley 공식 출시 |
| 2025.08-09 | Cursed Lang 프로그래밍 언어를 Ralph로 구축 |
| 2025.10 | Claude Code Anonymous 발표, 팟캐스트 75분 심층분석 |
| 2025.12 | Anthropic 공식 Ralph Wiggum 플러그인 출시 |
| 2026.01 | Ralph Wiggum Showdown 영상 |
| 2026.02 | 한국 최초 랄프톤 개최 |

---

## 3. Ghuntley 공식 플레이북: 3 Phases, 2 Prompts, 1 Loop

### Phase 1: 요구사항 정의 (Human + LLM)
```
프로젝트 아이디어 → JTBD(Jobs to Be Done) 식별
→ 각 JTBD를 관심사 주제(Topic of Concern)로 분해
→ LLM이 specs/FILENAME.md 생성
```

**한 문장 테스트**: "그리고" 없이 한 문장으로 설명 가능해야 함
- ✓ "색상 추출 시스템은 이미지를 분석하여 지배적 색상을 식별"
- ✗ "사용자 시스템은 인증, 프로필, 청구를 처리" → 3개로 분리

### Phase 2: Planning Mode
```
PROMPT_plan.md → IMPLEMENTATION_PLAN.md 생성/갱신
구현 없음, 계획만. 서브에이전트 최대 500개 병렬로 코드베이스 분석
```

### Phase 3: Building Mode
```
PROMPT_build.md → IMPLEMENTATION_PLAN.md에서 최우선 작업 선택
→ 구현 → 테스트 → 커밋 → IMPLEMENTATION_PLAN.md 갱신 → 루프 종료
→ 새 컨텍스트로 재시작
```

### 프로젝트 구조
```
project-root/
├── loop.sh                  # Ralph 루프 스크립트
├── PROMPT_plan.md           # 계획 모드 프롬프트
├── PROMPT_build.md          # 빌드 모드 프롬프트
├── AGENTS.md                # 운영 가이드 (~60줄, 간결하게!)
├── IMPLEMENTATION_PLAN.md   # 우선순위 작업 목록 (에이전트가 관리)
├── specs/                   # JTBD별 요구사항 명세
│   ├── topic-a.md
│   └── topic-b.md
└── src/
    └── lib/                 # 공유 유틸리티
```

### loop.sh 핵심
```bash
#!/bin/bash
MODE=${1:-build}
PROMPT_FILE="PROMPT_${MODE}.md"
ITERATION=0

while true; do
  cat "$PROMPT_FILE" | claude -p \
    --dangerously-skip-permissions \
    --output-format=stream-json \
    --model opus \
    --verbose

  git push origin "$(git branch --show-current)"
  ITERATION=$((ITERATION + 1))
  echo "======================== LOOP $ITERATION ========================"
done
```

### PROMPT_build.md 핵심 패턴
```markdown
0a. Study `specs/*` with up to 500 parallel Sonnet subagents
0b. Study @IMPLEMENTATION_PLAN.md
1. Implement the most important item from @IMPLEMENTATION_PLAN.md
   - Before changes, search codebase (don't assume not implemented)
   - Up to 500 parallel Sonnet subagents for search/read
   - Only 1 Sonnet subagent for build/tests
2. Run tests after implementing
3. Update @IMPLEMENTATION_PLAN.md with findings
4. git add -A && git commit && git push
```

### 핵심 언어 패턴 (프롬프트에 반복 삽입)
- `"don't assume not implemented"` — 가장 중요
- `"using parallel subagents"`
- `"only 1 subagent for build/tests"` — 빌드 충돌 방지
- `"capture the why"` — 왜 그렇게 했는지 기록
- `"Implement functionality completely. Placeholders waste time."`
- `"Keep @AGENTS.md operational only"` — 상태 노트는 IMPLEMENTATION_PLAN.md에

---

## 4. 하네스 엔지니어링 — 2026년 최신 정의

### 진화 경로
```
프롬프트 엔지니어링 → 컨텍스트 엔지니어링 → 하네스 엔지니어링
```

### 정의
"AI 에이전트를 신뢰할 수 있게 만드는 인프라, 제약, 피드백 루프를 설계하는 분야"

### 3대 핵심 원칙
1. **제어(Control)**: 에이전트가 허용된 범위 밖의 행동을 하지 않도록 제한
2. **감시(Monitoring)**: 동작 상태와 출력 결과를 실시간 추적/기록
3. **개선(Feedback)**: 오류 감지 → 다음 동작에 반영하는 루프

### 3대 구성요소
1. **컨텍스트 엔지니어링**: AGENTS.md, CLAUDE.md, specs/, 아키텍처 문서
2. **아키텍처 제약**: 린터, 타입체크, 구조 테스트, pre-commit 훅
3. **엔트로피 관리**: 문서-코드 일관성 검증, 패턴 강제, 의존성 감시

### 핵심 공식
```
코딩 에이전트 = AI 모델(들) + 하네스
"모델은 상품화; 하네스가 경쟁 우위"
```

LangChain이 모델 변경 없이 하네스만 개선해 Terminal Bench 52.8% → 66.5% 달성 (Top 30 → Top 5)

---

## 5. 실전 하네스 구성요소 상세

### 5.1 CLAUDE.md / AGENTS.md
- **60줄 미만** 유지 (ETH 취리히 연구: LLM 생성 시 성능 악화 + 20% 비용 증가)
- **수동 작성 필수** — 자동 생성 금지
- 효과 없는 것: 코드베이스 개요, 디렉토리 나열
- 효과 있는 것: 빌드/테스트 명령, 발견된 패턴, CLI 사용법

### 5.2 백프레셔 (Back Pressure)
"에이전트 자신에 대한 구조를 설정하여 품질과 정확성에 대한 자동화된 피드백"

**필수 체크리스트:**
- 타입체크 + 빌드 자동화
- 단위/통합 테스트
- 코드 커버리지
- UI 상호작용 테스트 (Playwright/Puppeteer)

**중요**: 실패만 표면화, 성공은 무음 → 맥락 오염 방지

### 5.3 서브 에이전트 (맥락 방화벽)
```
부모 에이전트 (Opus, 오케스트레이션)
  → 서브 에이전트 (Sonnet/Haiku, 구체적 작업)
  → 최종 요약만 반환 (중간 도구 호출/결과 제외)
```
- Chroma 연구: 맥락 길이 증가 → 성능 저하
- 맥락 방화벽: 서브에이전트가 중간 결과를 격리

### 5.4 훅(Hooks)
```bash
# Post-tool hook 예시
#!/bin/bash
cd "$CLAUDE_PROJECT_DIR"
bun run --parallel \
  "biome check . --write --unsafe" \
  "turbo run typecheck" 2>&1
# exit 0: 성공(무음), exit 2: 오류(에이전트 재진입)
```

### 5.5 MCP 서버
- 도구 설명이 시스템 프롬프트에 삽입됨 → 과다 시 맥락 오염
- **CLI 래퍼** 선호: MCP 서버 대신 경량 CLI + CLAUDE.md 예제 → 토큰 절약
- 필요한 도구만 연결, 과다 사용 주의

### 5.6 스킬(Skills)
```
my-skill/
├── SKILL.md              # 활성화 시 로드
├── response_template.md  # 참고 자료
└── CLIs/                 # 경량 CLI 래퍼
```
- 점진적 공개(Progressive Disclosure)
- 필요할 때만 활성화

---

## 6. Anthropic 공식 가이드: 장기 실행 에이전트

### 2단계 에이전트 아키텍처
1. **Initializer Agent** (첫 실행만): init.sh, claude-progress.txt 생성, 초기 커밋
2. **Coding Agent** (이후 모든 세션): 증분적 진행, 구조화된 업데이트

### 세션 시작 루틴 (매 컨텍스트 윈도우)
```
1. pwd → 작업 디렉토리 확인
2. claude-progress.txt 읽기 → 최근 작업 파악
3. feature list 검토 → 미완료 항목 확인
4. git log → 최근 변경사항
5. init.sh 실행 → 개발 환경 시작
6. 기본 기능 테스트 → 앱 상태 검증
7. 새 기능 작업 시작
```

### Feature List 파일 (JSON)
```json
{"category": "functional", "description": "기능 설명",
 "steps": [...], "passes": false}
```
- **테스트 제거/편집 금지** — 누락/결함 방지
- 테스트 후에만 `passes: true`로 변경

### 실패 모드 대응
| 문제 | 대응 |
|------|------|
| 조기 완료 선언 | Feature list로 강제 검증 |
| 환경 파악 불가 | init.sh로 표준화 |
| 버그 누적 | 매 세션 시작 시 기본 기능 테스트 |

---

## 7. 최강 하네스 도구 비교 (2026.03 기준)

### Tier 1: 공식/검증된 프레임워크

| 도구 | 특징 | 적합도 |
|------|------|--------|
| **ghuntley/how-to-ralph-wiggum** | 공식 플레이북, 3P2P1L, 500+ 서브에이전트 | ⭐⭐⭐⭐⭐ |
| **frankbria/ralph-claude-code** | 지능형 종료감지, 회로차단기, 속도제한, 566 테스트 | ⭐⭐⭐⭐⭐ |
| **Chachamaru127/claude-code-harness** | Plan→Work→Review→Release 사이클, 9개 가드레일 | ⭐⭐⭐⭐ |
| **humanlayer/advanced-context-engineering** | ACE 프레임워크, 1.6k stars | ⭐⭐⭐⭐ |

### Tier 2: 특화 구현체

| 도구 | 특징 | 적합도 |
|------|------|--------|
| **mj-meyer/choo-choo-ralph** | 5단계 워크플로우, 구조화된 명세 | ⭐⭐⭐⭐ |
| **mikeyobrien/ralph-orchestrator** | Rust 기반, 7개 AI 백엔드 지원 | ⭐⭐⭐ |
| **vercel-labs/ralph-loop-agent** | Vercel TypeScript SDK, 다중 에이전트 | ⭐⭐⭐ |
| **ClaytonFarr/ralph-playbook** | 실전 플레이북 | ⭐⭐⭐ |

### Tier 3: 참고 자료

| 도구 | 특징 |
|------|------|
| **snarktank/ralph** | PRD 기반 자동 브랜칭, Amp/Claude Code 지원 |
| **rubenmarcus/ralph-starter** | GitHub/Linear/Notion 통합, 다중 에이전트 |
| **coleam00/your-claude-engineer** | Slack/GitHub/Linear 통합 에이전트 하네스 |

---

## 8. 산업 사례 벤치마크

### OpenAI
- 인간 코드 0%로 100만줄+ 앱 구축
- 엔지니어 역할: 코드 작성 → 아키텍처 설계

### Stripe ("Minions")
- 주당 1,000+ PR 병합
- Slack → Minion 코드 작성 → CI → PR → 인간 리뷰

### LangChain 미들웨어 체인
```
Request → LocalContextMiddleware
        → LoopDetectionMiddleware
        → ReasoningSandwichMiddleware
        → PreCompletionChecklistMiddleware
        → Response
```
- 모델 변경 없이 하네스만으로 Top 30 → Top 5

---

## 9. 랄프톤 최적 전략 도출

### 승리 공식 (우승팀 분석 기반)

```
1. 모호성 최소화 (Ambiguity Score → 0.05)
   └── 소크라틱 리즈닝 100+ 회 루프
   └── Validator + Coordinator + Packer 다중 검증

2. 테스트 우선 (70% 테스트 코드)
   └── 에이전트가 자기 작업을 검증할 수 있어야 성공
   └── 실패만 표면화, 성공은 무음

3. 완전 자율 (키보드 0회)
   └── 하네스 설계가 곧 실력
   └── 루프 위에 앉기, 안에 들어가지 말기

4. 비용 최적화
   └── 초기: Opus (계획/복잡 추론)
   └── 후반: Sonnet/Haiku (구현/검색)
```

### 실전 하네스 설계 체크리스트

- [ ] specs/ 디렉토리에 JTBD별 명세서 작성 (한 문장 테스트 통과)
- [ ] PROMPT_plan.md — 계획 모드 프롬프트 (구현 금지, 분석만)
- [ ] PROMPT_build.md — 빌드 모드 프롬프트 (백프레셔 포함)
- [ ] AGENTS.md — 60줄 이하, 운영 정보만
- [ ] loop.sh — 반복 루프 스크립트 (종료 감지 포함)
- [ ] 백프레셔: 타입체크 + 린트 + 테스트 자동화
- [ ] 서브에이전트: Opus(계획) + Sonnet(구현) 분리
- [ ] 소크라틱 리즈닝 루프: 명세 모호성 사전 제거
- [ ] 회로 차단기: 진행 없는 루프 감지 및 자동 복구
- [ ] init.sh: 개발 환경 원클릭 셋업

---

## 10. 참고 자료 (Sources)

### 핵심 문서
- [한국 최초 랄프톤 후기: 하네스 엔지니어링 시대](https://briandwjang.substack.com/p/8d3)
- [서울경제: 인간은 자고 AI가 밤새 코딩](https://www.sedaily.com/article/20015256)
- [Anthropic: Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [HumanLayer: Skill Issue — Harness Engineering](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents)
- [NxCode: Harness Engineering Complete Guide 2026](https://www.nxcode.io/resources/news/harness-engineering-complete-guide-ai-agent-codex-2026)
- [채널톡: 하네스 엔지니어링이란?](https://channel.io/ko/blog/articles/what-is-harness-2611ddf1)

### Geoffrey Huntley 원문
- [Ralph Wiggum as a Software Engineer](https://ghuntley.com/ralph/)
- [Everything is a Ralph Loop](https://ghuntley.com/loop/)
- [Don't Waste Your Back Pressure](https://ghuntley.com/pressure/)
- [I Ran Claude in a Loop for 3 Months](https://ghuntley.com/cursed/)

### 구현체
- [awesome-ralph (도구 목록)](https://github.com/snwfdhmp/awesome-ralph)
- [ghuntley/how-to-ralph-wiggum (공식 플레이북)](https://github.com/ghuntley/how-to-ralph-wiggum)
- [frankbria/ralph-claude-code (Claude Code 전용)](https://github.com/frankbria/ralph-claude-code)
- [Chachamaru127/claude-code-harness (Plan→Work→Review)](https://github.com/Chachamaru127/claude-code-harness)
- [humanlayer/advanced-context-engineering](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents)

### 학습 자료
- [Getting Started with Ralph](https://www.aihero.dev/getting-started-with-ralph)
- [11 Tips for AI Coding with Ralph Wiggum](https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum)
- [A Brief History of Ralph](https://www.humanlayer.dev/blog/brief-history-of-ralph)
- [VentureBeat: How Ralph Wiggum Became the Biggest Name in AI](https://venturebeat.com/technology/how-ralph-wiggum-went-from-the-simpsons-to-the-biggest-name-in-ai-right-now)

### 영상/팟캐스트
- [Ralph Wiggum Deep Dive with Geoffrey Huntley](https://www.youtube.com/watch?v=SB6cO97tfiY)
- [AI That Works Podcast (75분 심층분석)](https://www.youtube.com/watch?v=fOPvAPdqgPo)
- [Dev Interrupted: Inventing the Ralph Wiggum Loop](https://linearb.io/dev-interrupted/podcast/inventing-the-ralph-wiggum-loop)
