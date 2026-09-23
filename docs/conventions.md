# Repository Conventions

## 1. 목표

이 저장소는 사람이 읽기 쉬운 한국어 문서와 자동화에 적합한 영어 machine interface를 함께 사용한다. 규칙 자체가 복잡해지지 않도록 필요한 것만 정의한다.

## 2. 문서 언어

### 기본 원칙

- 사람 대상 문서는 한국어를 기본으로 한다.
- 번역투보다 자연스러운 한국어를 우선한다.
- 제품명, API resource/field, metric, CLI, 코드 식별자, 파일 경로는 공식 영어 표기를 유지한다.
- 낯선 기술 용어는 처음 등장할 때 필요한 만큼 설명하고 공식 영어 용어를 함께 적는다.
- 같은 개념을 여러 이름으로 바꾸어 쓰지 않는다.
- 제품/업계에 이미 통용되는 표현이 있으면 프로젝트 전용 약칭을 만들지 않는다.

### Machine interface

다음은 영어를 사용한다.

- source code identifier
- JSON/YAML key
- metric name / log field
- environment variable
- Make target
- script / file / directory name
- Git branch
- GitHub label canonical name

Code comment와 machine log도 영어를 기본으로 한다.

## 3. Commit convention

형식:

```text
<type>(<scope>): <한글 설명>
```

예:

```text
feat(gitops): Argo CD Core bootstrap 추가
fix(forgejo): Pod 재생성 후 session 유지 문제 수정
docs(architecture): 실험 fixture 소유권 경계 명시
test(recovery): Forgejo restore 검증 추가
ci(terraform): Azure plan workflow 추가
```

권장 type:

- `feat`
- `fix`
- `docs`
- `test`
- `refactor`
- `perf`
- `build`
- `ci`
- `chore`
- `revert`

scope는 필요할 때만 사용하고 영어 lowercase를 사용한다.

운영 계약을 깨는 변경은 `!`를 사용할 수 있다.

```text
feat(platform)!: ingress 배포 계약 변경
```

## 4. Branch convention

Branch는 영어로 작성한다.

예:

```text
feat/argocd-bootstrap
feat/forgejo-platform
fix/session-persistence
docs/project-foundation
test/restore-drill
experiment/retry-amplification
```

## 5. Pull Request

PR title은 commit convention과 같은 형식을 사용한다.

PR body는 한국어로 작성한다.

기본 질문:

1. 무엇을 변경했는가?
2. 왜 필요한가?
3. 어떻게 검증했는가?
4. 영향 범위는 어디까지인가?
5. 남은 문제나 의도적인 한계가 있는가?

이 저장소는 solo project이므로 PR 사용을 peer code review라고 표현하지 않는다. **PR-gated change management**로 설명한다.

Main에는 squash merge를 기본으로 한다.

## 6. Naming

### Scenario

`good`, `bad`, `aware`, `blind`처럼 평가가 들어간 이름보다 실제 변경 변수를 사용한다.

권장:

```text
retry-immediate
retry-backoff-jitter
hpa-app-cpu
keda-envoy-active-requests
envoy-request-limit
```

### Measurement

`operation`, `attempt`, `HTTP request`, `authorization check`, `Envoy upstream request`를 서로 바꾸어 쓰지 않는다.

프로젝트 전용 ratio/metric을 만들면:

- 분자
- 분모
- 측정 위치
- 단위

를 문서에 정의한다.

## 7. 공식 용어 우선

가능하면 다음 순서로 표현을 선택한다.

1. upstream product의 공식 명칭
2. SRE/distributed systems에서 널리 통용되는 명칭
3. 평범한 한국어 설명
4. 필요한 경우에만 project term

Project term은 `docs/terminology.md`에 정의한다.

## 8. Git에 저장하는 것

Git에 저장:

- source code
- Terraform / Helm / plain YAML source configuration
- test와 experiment definition
- human-readable docs
- 작은 reviewed evidence

Git에 저장하지 않음:

- Terraform state
- secret
- kubeconfig
- raw credential
- 전체 environment dump
- 대용량 raw metrics/logs/traces
- generated vendor manifest
- local temporary files

Rendered manifest는 CI에서 생성하고 검증하며 source of truth로 commit하지 않는다.

## 9. Evidence 표현

다음을 구분한다.

- valid / invalid run
- experiment PASS / FAIL
- developer SLO met / violated
- hypothesis supported / not supported / inconclusive

`experiment PASS`와 `SLO met`는 같은 의미가 아니다.

측정하지 않은 값은 결과로 작성하지 않는다.

가설과 다른 결과라도 valid run이면 보존한다.

## 10. 변경 원칙

- 한 PR은 가능한 한 하나의 목적을 가진다.
- 새로운 tool/controller는 실제 문제가 확인되기 전에 추가하지 않는다.
- 빈 디렉터리나 미래용 abstraction을 미리 만들지 않는다.
- module/helper는 실제 중복이나 독립된 계약이 생길 때 추출한다.
- README는 reviewer entry point로 유지하고 운영 세부사항을 모두 넣지 않는다.
