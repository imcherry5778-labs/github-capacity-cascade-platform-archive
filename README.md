# GitHub Capacity Cascade Platform

> A production-minded developer platform on Azure AKS that turns a public GitHub outage RCA into a reproducible reliability engineering case study.

GitHub의 2026년 8월 공개 장애 보고서에서 확인할 수 있는 **과부하 기반 cascading failure**의 failure class를 실제 Forgejo developer platform에 적용해, 사용자 영향부터 진단·완화·복구·재발 방지까지 검증하는 SRE / Platform Engineering 프로젝트다.

> 현재 상태: **Project Foundation** — 구현 전 architecture / repository contract를 고정하는 단계

## 왜 이 프로젝트를 만드는가

기존 [github-capacity-cascade-lab](https://github.com/imcherry5778-labs/github-capacity-cascade-lab)은 retry, proxy capacity, Envoy circuit breaker, autoscaling signal mismatch 같은 mechanism을 작은 실험으로 분해해 학습했다.

이 저장소는 그 결과를 실제 운영 문제로 확장한다.

```text
Public GitHub RCA
        ↓
Mechanism research (existing Lab)
        ↓
Developer Platform
        ↓
Normal operating contract
        ↓
Controlled reliability incident
        ↓
Diagnosis → Mitigation → Recovery
        ↓
Regression prevention
```

핵심 질문은 단순히 "Pod가 살아 있는가?"가 아니다.

> **개발자가 실제로 clone/fetch, push, Pull Request, Issue 작업을 수행할 수 있는가?**

## 설계 방향

### Stable developer platform

- Forgejo v15 LTS 계열
- Azure Database for PostgreSQL
- persistent application data
- Istio ingress
- custom domain + HTTPS
- Argo CD Core reconciliation
- Azure Key Vault + Workload Identity
- Azure-managed observability

### Reliability experiment

GitHub의 비공개 topology를 복제하지 않는다.

대신 `LAB_IMPLEMENTATION`으로 synthetic shared gate를 일시적으로 request path에 추가한다.

```text
Developer
  ↓
Istio Gateway
  ↓ authorization check (experiment only)
HAProxy
  ↓
Envoy sidecar
  ↓
ext-authz-sim
  ↓ ALLOW
Istio Gateway
  ↓ original request
Forgejo
```

여기서 request-concurrency saturation, retry amplification, autoscaling signal mismatch와 recovery를 통제된 조건에서 관찰한다.

`ext-authz-sim`은 Forgejo의 native authentication/authorization을 대체하지 않는다.

## Repository 책임 경계

구현이 시작되면 다음 책임 구조를 따른다. 빈 디렉터리를 미리 만들지는 않는다.

```text
cmd/            우리가 작성하는 executable
internal/       Go internal implementation

infra/          Azure Terraform lifecycle
platform/       Argo CD가 관리하는 stable platform source
operations/     SLO · alerts · dashboards · runbooks
tests/          integration · E2E · infra · recovery · upgrade
experiments/    temporary reliability fixtures and scenarios
results/        reviewed evidence
docs/           architecture · decisions · research · incidents
```

정상 테스트와 reliability experiment는 별개다.

```text
tests/
"정상 시스템이 요구사항을 만족하는가?"

experiments/
"정상 시스템에 의도한 failure condition을 주면 무엇이 일어나는가?"
```

## Control plane

```text
Terraform
= Azure infrastructure lifecycle

GitHub Actions
= CI / build / Terraform orchestration

Argo CD Core
= stable Kubernetes platform reconciliation

Experiment runner
= temporary reliability state
```

Argo CD가 관리하는 resource와 experiment runner가 관리하는 resource는 겹치지 않는다.

## Local과 Azure

### Local / k3d

- 빠른 inner loop는 direct deploy 허용
- GitOps integration에서는 Argo CD Core를 검증
- 실제 developer journey를 Azure 전에 검증

### Azure / AKS

- single-region ephemeral environment
- Azure CNI Overlay
- system/user node pool 분리
- private PostgreSQL
- public HTTPS ingress만 외부 노출
- PAYG 기준
- 실제 apply/destroy는 명시적으로 실행
- final evidence run은 exact Git commit SHA로 freeze

## 측정 원칙

최상위 신호는 infrastructure metric이 아니라 **developer operation**이다.

Core journey:

- `git clone/fetch`
- `git push`
- Pull Request read/create
- Issue/API read/create

다음 계층은 서로 구분한다.

```text
developer operation
→ operation attempt
→ HTTP request
→ authorization check
→ Envoy upstream request
→ application request
```

기존 Lab에서 사용한 `physical attempts`, `HPA blind` 같은 내부 약칭을 새 프로젝트의 기본 기술 용어로 사용하지 않는다.

## Evidence 원칙

```text
Raw run
   ↓ validity / provenance 확인
Reviewed evidence
   ↓
README / incident conclusion
```

- raw result는 append-only로 취급
- final evidence에는 exact source revision과 runtime version/digest 기록
- hypothesis와 반대 결과도 valid run이면 숨기지 않음
- Forgejo / PostgreSQL / node saturation 같은 confounder를 함께 확인
- Grafana screenshot보다 machine-readable measurement를 primary evidence로 사용

## 프로젝트 문서

- [Project Charter](docs/charter.md) — 목표, Core 범위, 완료 기준
- [Architecture](docs/architecture.md) — control plane과 ownership 경계
- [Roadmap](docs/roadmap.md) — 구현 순서와 단계별 완료 조건
- [Repository Conventions](docs/conventions.md) — 한국어 문서, commit/PR, naming 규칙
- [Terminology](docs/terminology.md) — 공식 용어와 프로젝트 측정 용어의 경계
- [AGENTS.md](AGENTS.md) — 구현 작업자가 따라야 할 repository contract

## 문서 언어

사람 대상 문서는 한국어를 기본으로 한다.

제품명, API, metric, CLI, 코드 식별자와 파일 경로는 공식 영어 표기를 유지한다.

Commit과 PR title은 다음 형식을 사용한다.

```text
<english type>(<english scope>): <한글 설명>
```

예:

```text
feat(gitops): Argo CD Core bootstrap 추가
test(recovery): Forgejo restore 검증 추가
docs(architecture): 실험 fixture 소유권 경계 명시
```

## 현재 단계에서 아직 고정하지 않는 값

다음 값은 baseline/calibration 없이 임의로 정하지 않는다.

- Azure node SKU/count
- developer SLO threshold
- KEDA threshold
- exact resource request/limit
- trace/log sampling rate
- Forgejo exact patch와 final image digest

실제 구현과 측정을 통해 근거가 생겼을 때 ADR 또는 운영 문서에 고정한다.

## 완료 후 운영 모델

이 프로젝트는 24/7 public service가 아니다.

최종 demo/evidence 후 Azure runtime을 제거하고, 포트폴리오는 source, architecture, runbook, reviewed evidence와 incident documentation으로 유지한다.

완전 종료 시에는 environment뿐 아니라 project-specific DNS delegation, identity, Terraform backend까지 정리하고 project-owned residual resource가 없음을 확인한다.
