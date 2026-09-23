# Roadmap

이 문서는 프로젝트의 milestone과 현재 상태를 요약한다.

세부 dependency, acceptance, 비용 gate는 [Implementation Plan](implementation-plan.md)을 따른다.

## 상태

| Milestone | 상태 |
| --- | --- |
| P0 Project Foundation | 완료 |
| P1 Local Correctness Baseline | 완료 |
| P2 GitOps Integration | 완료 |
| P3A Azure IaC Specification | 진행 |
| P4A Local Operations Contract | 대기 |
| P5 Local Reliability Fixture | 대기 |
| P3B Azure Calibration Environment | 대기 |
| P4B Azure Operations Verification | 대기 |
| P6 Cascading Failure Investigation | 대기 |
| P7 Mitigation and Recovery | 대기 |
| P8 Critical / Bulk Isolation | 대기 |
| P9 Regression Prevention and Final Evidence | 대기 |

---

## P0 — Project Foundation

**완료**

- Project Charter
- Architecture
- terminology / conventions
- repository contract
- Korean-first documentation policy
- PR-gated change management

---

## P1 — Local Correctness Baseline

**완료**

- k3d fresh-cluster lifecycle
- Forgejo v15 LTS pinned baseline
- local PostgreSQL fixture
- persistent application data
- Git push
- clone/fetch
- PR create/read
- Issue create/read
- test fixture cleanup

이 단계의 shell E2E는 correctness test다. SLI/load measurement는 P4A에서 별도 developer-probe로 만든다.

---

## P2 — GitOps Integration

**완료**

- Argo CD Core
- restricted AppProject
- exact PR head revision
- auto-sync / self-heal
- automatic prune off
- controlled live drift
- post-heal developer E2E

---

## P3A — Azure IaC Specification

**진행 — Azure 비용 0**

실제 Azure resource를 만들기 전에 source/lifecycle을 완성한다.

- Terraform bootstrap boundary
- remote state
- GitHub OIDC identity
- scoped Azure RBAC
- foundation DNS / Key Vault
- environment VNet / AKS / PostgreSQL / observability
- AKS managed Istio / KEDA / Key Vault CSI source
- Azure apply/destroy runbook
- Terraform static validation

완료 조건:

- 모든 root stack이 static validate 가능
- Azure dependency graph가 명확함
- subscription-wide CI privilege가 필요하지 않음
- actual apply 전 필요한 값/preflight 목록이 고정됨

---

## P4A — Local Operations Contract

**Azure 비용 0**

정상 서비스를 측정하고 복구하는 계약을 local에서 먼저 만든다.

- existing Git CLI/curl path를 재사용하는 structured developer probe
- machine-readable operation/attempt measurement schema
- bulk/retry load용 k6
- low-cardinality metrics
- structured logs / correlation
- Service Active Window 정의
- session continuity
- coordinated backup/restore mechanics
- upgrade/rollback mechanics

SLO threshold는 아직 확정하지 않는다. Azure baseline을 측정한 뒤 결정한다.

---

## P5 — Local Reliability Fixture

**Azure 비용 0**

- Azure candidate와 정렬된 pinned upstream Istio local profile
- ext-authz-sim
- HAProxy
- shared-gate lifecycle
- inbound Envoy request limit
- application-container CPU HPA
- no-retry / bounded retry
- mechanism/confounder measurement
- fixture cleanup

완료 조건:

- normal E2E PASS
- healthy gate E2E PASS
- intentional Envoy saturation 관측
- retry attempt 증가 측정
- Forgejo/DB/node가 primary bottleneck이 아님
- fixture 제거 후 normal E2E PASS

---

## P3B — Azure Calibration Environment

**PAYG — 명시적 승인 후 실행**

Local contract가 안정된 뒤 처음 Azure environment를 실제 생성한다.

- bootstrap / foundation apply
- GitHub OIDC
- AKS + private PostgreSQL
- managed Istio / KEDA / Key Vault CSI
- Argo bootstrap
- cert-manager + Azure DNS Workload Identity + ClusterIssuer
- ingress Certificate/TLS Secret in `aks-istio-ingress`
- HTTPS / DNS
- Azure developer E2E
- resource sizing/headroom calibration
- actual runtime/cost
- same-day destroy by default; >24h requires renewed approval
- destroy/residual inventory

Managed Istio selected revision은 region/AKS compatibility와 required capability를 실제 preflight에서 확인한 뒤 고정한다.

---

## P4B — Azure Operations Verification

**PAYG — short-lived session**

- Managed Prometheus / Grafana
- Log Analytics
- Application Insights
- OTel integration
- developer baseline
- SLO threshold 확정
- Azure backup/restore drill
- upgrade/rollback drill
- runbooks / alerts / dashboards

---

## P6 — Cascading Failure Investigation

Controlled incident:

1. normal baseline
2. healthy shared gate
3. Envoy inbound request-limit saturation
4. application-container CPU HPA
5. bounded retry
6. retry amplification + HAProxy/Envoy pressure

Evidence:

- developer impact
- mechanism
- confounder guard

---

## P7 — Mitigation and Recovery

동일한 fault/load boundary에서 비교한다.

- no retry
- immediate bounded retry
- exponential backoff + jitter
- HAProxy overload protection
- application-container CPU HPA
- Envoy metric → Managed Prometheus → managed KEDA

부하를 끄지 않은 상태에서 recovery를 측정한다.

---

## P8 — Critical / Bulk Isolation

같은 ext-authz-sim image를 사용하되 capacity pool을 분리한다.

- critical developer traffic
- bulk/automation traffic

Bulk overload 상황에서 critical developer SLI가 보호되는지 검증한다.

Complex priority scheduler/fair queuing은 Core 범위 밖이다.

---

## P9 — Regression Prevention and Final Evidence

- cost-free local capacity regression gate
- exact source commit freeze
- fixed Azure topology
- 3 controlled repetitions 기본 계획
- Baseline / Cascade / Mitigated / Isolated 비교
- reviewed evidence
- incident/postmortem
- final portfolio README
- environment destroy
- project finalization
  - Gabia delegation
  - foundation
  - identity/RBAC
  - Key Vault soft-delete/purge state
  - Terraform backend
  - final Azure inventory/cost

---

## Optional

Core 완료 후 실제 필요가 있을 때만 검토한다.

- Redis/Valkey
- Forgejo HA
- separate GitOps repo
- Argo CD full UI/HA
- multi-region / DR
- Forgejo Actions
- external search index
- Backstage
- richer traffic prioritization
- always-on public demo
