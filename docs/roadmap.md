# Roadmap

## 1. 운영 원칙

이 roadmap은 기술을 많이 넣는 순서가 아니라 **검증 가능한 작은 capability를 완성하는 순서**다.

각 단계는 이전 단계의 정상 동작을 깨지 않아야 한다. Azure resource를 실제 생성하는 단계는 명시적 승인 없이 실행하지 않는다.

## P0 — Project Foundation

### 목표

Repository contract와 구현 경계를 확정한다.

### 결과물

- Project Charter
- Architecture
- Conventions / Terminology
- AGENTS.md
- reviewer용 README
- 기본 CI skeleton은 다음 단계에서 추가

### 완료 조건

- stable platform과 reliability fixture ownership이 분리돼 있음
- Local/Azure functional parity의 의미가 문서화돼 있음
- GitOps/experiment/evidence 경계가 모순 없이 설명됨

---

## P1 — Local Developer Platform

### 목표

k3d에서 실제 Forgejo developer journey를 먼저 정상화한다.

### 구현

- Forgejo v15 LTS exact patch pin
- local PostgreSQL
- persistent application data
- Istio ingress
- HTTPS 또는 local development에 적합한 TLS 경로
- developer probe
- 핵심 E2E
  - clone/fetch
  - push
  - PR read/create
  - Issue/API read/create

### 완료 조건

- 같은 test fixture에서 반복 가능한 정상 E2E
- Forgejo restart 후 state continuity 검증
- platform 자체가 reliability experiment 없이 동작

---

## P2 — GitOps and Platform Tests

### 목표

Stable platform의 desired-state reconciliation을 검증한다.

### 구현

- Argo CD Core
- stable platform Application/AppProject
- local GitOps integration path
- controlled drift test
- infrastructure/integration test

### 완료 조건

- Git desired state와 cluster live state 차이를 탐지
- self-heal 동작 검증
- automatic prune은 사용하지 않음
- experiment resource가 Argo scope 밖임을 검증

---

## P3 — Azure Foundation and Ephemeral Environment

### 목표

PAYG Azure에서 reproducible environment lifecycle을 만든다.

### Terraform

- bootstrap
  - remote state backend
  - CI OIDC federation 최소 기반
- foundation
  - Azure DNS
  - Key Vault
  - shared identity/RBAC
- environment
  - AKS
  - PostgreSQL
  - ACR
  - observability
  - public ingress 관련 resource

### Azure platform

- Azure CNI Overlay
- system/user node pool 분리
- private PostgreSQL
- Key Vault + Workload Identity + Secrets Store CSI
- GitHub Actions manual apply/destroy
- Argo CD bootstrap

### 완료 조건

- clean provision → deploy → E2E → destroy 가능
- environment destroy 후 project-owned environment resource가 남지 않음
- exact cost/runtime metadata 수집 가능
- node/DB/Forgejo가 의도하지 않은 bottleneck이 아닌지 baseline 확인

---

## P4 — Operations Contract

### 목표

장애 실험 전에 정상 서비스의 운영 계약을 만든다.

### 구현

- developer-operation SLI
- baseline 측정
- baseline 근거를 바탕으로 SLO threshold 확정
- alert/dashboard/query
- backup runbook
- actual restore drill
- Forgejo doctor + developer E2E
- upgrade/rollback test
- cost/teardown runbook

### 완료 조건

- Service Active Window와 SLO 계산 범위가 명확함
- backup이 아니라 recoverability를 실제로 검증함
- upgrade 실패 시 단순 image downgrade가 아닌 state-aware rollback 절차가 있음

---

## P5 — Reliability Fixture

### 목표

GitHub 공개 incident의 failure effect를 연구하기 위한 synthetic shared gate를 정상 platform과 분리해 추가한다.

### 구현

`experiments/fixtures/shared-gate/`

- HAProxy
- ext-authz-sim
- Envoy request-concurrency constraint
- temporary Istio authorization policy
- experiment-specific HPA/KEDA ScaledObject
- load/retry generator

### 완료 조건

- experiment 미실행 시 request path에 synthetic gate가 없음
- experiment preflight에서 normal E2E PASS
- fixture 설치/제거가 stable platform desired state를 변경하지 않음
- Forgejo native auth/permission을 우회하지 않음

---

## P6 — Cascading Failure Investigation

### 목표

사용자 영향 → 진단 → root cause 설명이 가능한 controlled incident를 만든다.

### 시나리오

1. Baseline
2. Configured Envoy request limit saturation
3. application-CPU HPA의 signal mismatch 관찰
4. bounded retry를 통한 attempt 증가
5. HAProxy/proxy pressure 관찰

### Evidence layer

- Developer impact
- Failure mechanism
- Confounder guard

### 완료 조건

- developer-operation SLI degradation이 관측됨
- retry가 operation/request attempt를 증가시키는지 계층별로 분리 측정
- Envoy official signal을 사용해 circuit-breaker rejection 확인
- Forgejo/DB/node saturation이 primary cause가 아님을 확인

---

## P7 — Mitigation and Recovery

### 목표

같은 fault/load 조건에서 완화책의 trade-off를 비교하고, 부하를 끄지 않은 상태에서 recovery를 검증한다.

### 비교 대상

- bounded backoff + jitter
- gateway/HAProxy overload protection
- Envoy/proxy signal 기반 KEDA scaling
- gradual recovery/ramp

### 완료 조건

- 동일한 measurement boundary 사용
- operation attempt, developer SLI, proxy rejection, queue/pressure를 함께 비교
- load를 중단하지 않고 recovered steady state 확인
- 측정하지 않은 recovery improvement는 주장하지 않음

---

## P8 — Critical Traffic Isolation

### 목표

interactive developer traffic과 automation/bulk traffic의 blast radius를 분리한다.

### 방향

- 같은 ext-authz-sim image를 사용하되 capacity pool을 분리
- automation overload 시 bulk path의 degradation/shedding 허용
- developer path 보호

### 완료 조건

- 두 traffic class의 결과를 별도 측정
- 전체 평균 error rate가 아니라 developer-operation SLI 보호 여부로 판단
- complex priority/fair queuing은 Core 범위 밖

---

## P9 — Regression Prevention and Final Evidence

### 목표

failure class가 다시 도입되는 것을 검증하고 포트폴리오 evidence를 고정한다.

### 구현

- capacity regression test/gate
- exact Git revision freeze
- exact component version/image digest 기록
- Azure final paired repetitions
- reviewed evidence set
- incident/postmortem
- portfolio README
- final teardown

### 완료 조건

- final evidence claim이 source run/provenance로 추적 가능
- valid run과 hypothesis support를 분리
- final Azure runtime 제거
- 가비아 DNS delegation을 포함한 project finalization 절차 문서화
- 프로젝트 완료 후 지속적인 Azure 비용이 발생하지 않음

## 2. Optional extensions

Core 완료 후에만 검토한다.

- Forgejo HA
- Redis/Valkey
- Argo CD full UI/HA
- separate GitOps configuration repository
- multi-region / DR
- Forgejo Actions
- external search indexer
- richer traffic prioritization
- always-on public demo

Optional 항목을 Core 완료 조건으로 승격하려면 별도 ADR에서 필요성을 설명해야 한다.
