# Implementation Plan

## 1. 목적

이 문서는 Project Charter와 Architecture를 **실제 구현 단위**로 변환한다.

이 문서가 답해야 하는 질문은 다음이다.

- 지금 무엇을 구현하는가?
- 그 작업보다 먼저 완료되어야 하는 것은 무엇인가?
- 무엇을 검증해야 완료라고 말할 수 있는가?
- Azure 비용은 어느 시점부터 발생하는가?
- 실패하면 무엇을 되돌리거나 다시 검토하는가?
- 어떤 evidence를 남기는가?

세부 파일명이나 tool 옵션을 미리 과도하게 고정하지 않는다. 실제 capability와 acceptance가 먼저다.

---

## 2. 현재 상태

| 단계 | 상태 | 비고 |
| --- | --- | --- |
| P0 Project Foundation | 완료 | Charter / Architecture / conventions |
| P1 Local Correctness Baseline | 완료 | fresh k3d + Forgejo + Git/PR/Issue E2E |
| P2 GitOps Integration | 완료 | Argo CD Core sync/self-heal + E2E |
| P3.1 Terraform State Bootstrap Source | 완료 | source/lock/static CI. Azure apply는 아직 수행하지 않음 |
| P3 Azure Environment | 진행 전 | 이 문서를 기준으로 구현 재개 |
| P4 Operations Contract | 진행 전 | |
| P5 Reliability Fixture | 진행 전 | |
| P6~P9 Experiment/Evidence | 진행 전 | |

`완료`는 repository의 현재 source와 CI에서 검증한 범위만 의미한다. Azure에서 검증하지 않은 기능을 Azure에서도 완료됐다고 표현하지 않는다.

---

## 3. 최종 책임 구조

아래는 **논리적 destination**이다. 아직 필요하지 않은 빈 디렉터리는 만들지 않는다.

```text
cmd/
├── developer-probe/       # P4부터
└── ext-authz-sim/         # P5부터

internal/
└── 실제 Go package가 필요할 때만 생성

infra/
└── terraform/
    ├── bootstrap/
    ├── foundation/
    └── environment/

platform/
├── local/
├── forgejo/
├── gitops/
├── ingress/               # 실제 ingress source가 생길 때
├── tls/                   # 실제 TLS source가 생길 때
└── telemetry/             # 실제 collector/config가 생길 때

operations/
├── slo/
├── alerts/
├── dashboards/
├── runbooks/
└── cost/

tests/
├── integration/
├── e2e/
├── infrastructure/
├── recovery/
└── upgrade/

experiments/
├── fixtures/
│   └── shared-gate/
├── scenarios/
└── load/

results/
└── evidence/

docs/
├── architecture.md
├── implementation-plan.md
├── production-readiness.md
├── adr/
├── research/
└── incidents/
```

---

## 4. Control plane ownership

### 4.1 Terraform / AKS managed lifecycle

Terraform이 소유한다.

- Azure resource lifecycle
- AKS managed add-on enablement
- Azure identity와 RBAC
- Azure DNS / Key Vault
- PostgreSQL / storage / observability

Azure에서는 다음 capability를 우선 **AKS managed add-on**으로 사용한다.

- Istio service mesh add-on
- KEDA add-on
- Azure Key Vault provider for Secrets Store CSI Driver

이유는 cluster-scoped controller의 lifecycle을 Argo CD에 불필요하게 맡기지 않기 위해서다.

### 4.2 Explicit cluster bootstrap

GitHub Actions 또는 명시적 bootstrap 절차가 담당한다.

- Argo CD Core 자체
- cert-manager controller
- AKS managed Istio revision-specific shared MeshConfig처럼 `platform` namespace 밖의 필수 cluster configuration

이 영역은 Argo CD의 `capacity-platform` AppProject 권한을 확대하기 위한 이유가 되어서는 안 된다.

### 4.3 Argo CD Core

Argo CD는 **namespaced stable desired state**를 기본 경계로 한다.

현재/예정:

- Forgejo
- namespaced ingress/routing object
- namespaced TLS object
- SecretProviderClass와 ServiceAccount 같은 workload integration
- namespaced telemetry collector/config

계약:

- exact source revision
- auto-sync
- self-heal
- automatic prune off
- `platform` namespace 중심
- cluster-wide wildcard 권한을 추가하지 않음

### 4.4 Experiment runner

실험에서만 존재하거나 바뀌는 state를 소유한다.

- HAProxy
- ext-authz-sim
- temporary `AuthorizationPolicy`
- experimental `Sidecar` connection-pool setting
- HPA / ScaledObject
- load/fault resource
- scenario-specific routing/classification

실험이 끝나면 해당 state를 제거한다.

---

## 5. Local / Azure parity의 의미

Local과 Azure가 **같은 배포 구현**이어야 한다는 뜻은 아니다.

같아야 하는 것:

- Forgejo operating contract
- developer operation 정의
- GitOps desired-state semantics
- reliability fixture의 request path
- experiment variable과 measurement boundary

달라도 되는 것:

- local PostgreSQL vs Azure PostgreSQL
- upstream Istio local install vs AKS managed Istio add-on
- local telemetry backend vs Azure Managed Prometheus/Log Analytics
- local secret vs Azure Key Vault

환경 차이는 결과 해석에 영향을 줄 수 있으므로 final evidence에는 실제 runtime version과 topology를 기록한다.

---

# P0 — Project Foundation

**상태: 완료**

완료 evidence:

- Charter / Architecture
- conventions / terminology
- responsibility-oriented repository
- PR-gated change management

---

# P1 — Local Correctness Baseline

**상태: 완료**

## 범위

- Forgejo v15 LTS exact patch
- upstream Helm chart exact version
- single replica / Recreate
- local PostgreSQL substitute
- fresh k3d lifecycle
- health/version smoke
- normal developer E2E

Developer E2E:

- Git push
- clone/fetch
- feature push
- PR create/read
- Issue create/read

## 의도적으로 P1에 포함하지 않는 것

- Istio
- developer SLI measurement binary
- browser session restart continuity
- backup/restore

이 항목들은 각각 P3/P4에서 다룬다.

---

# P2 — GitOps Integration

**상태: 완료**

## Acceptance

- Argo CD Core exact version pin
- restricted AppProject
- upstream Forgejo chart + Git values
- exact PR head checkout과 `targetRevision` 일치
- initial Synced/Healthy
- manual replica drift
- self-heal
- post-heal developer E2E
- no automatic prune

---

# P3 — Azure Foundation and Ephemeral Environment

P3는 한 번에 구현하지 않는다.

## P3.1 — State backend lifecycle

### 현재 상태

Source/static validation은 완료했다. 실제 apply는 아직 하지 않았다.

### 실제 apply 전에 보완할 것

Bootstrap은 state storage를 만드는 것에서 끝나지 않는다.

Foundation의 첫 remote-state 접근을 위해 **operator principal의 Blob data-plane access**를 명시적으로 준비해야 한다.

필수 계약:

- Shared Key 사용 금지
- Entra ID 사용
- state container 접근 principal에 필요한 data-plane role 부여
- Terraform state는 민감 데이터로 취급
- state file/log/artifact를 Git 또는 CI artifact로 업로드하지 않음

CI identity에는 이후 state container 범위의 `Storage Blob Data Contributor` 수준 권한을 사용한다.

### Acceptance

- local operator로 bootstrap apply
- 새 shell에서 state storage 실제 존재 확인
- authorized principal만 blob state read/write 가능
- bootstrap state backup/recovery/import 절차 확인

### 비용

명시적 승인 전 apply 금지.

---

## P3.2 — Foundation

### 책임

Environment보다 오래 유지되는 최소 resource:

- project DNS zone
- Key Vault
- environment resource-group permission boundary
- GitHub Actions용 Azure federated identity
- 필요한 최소 scoped RBAC

### DNS

가비아 parent domain 전체를 Azure로 이전하지 않는다.

```text
parent.example
└── project-subdomain.parent.example
      └── NS delegation → Azure DNS
```

Terraform은 Azure DNS zone을 관리하고, 가비아 delegation은 runbook에서 명시적으로 설정/제거한다.

### GitHub OIDC

장기 Azure client secret을 만들지 않는다.

초기 foundation 생성은 local operator의 Azure CLI/Entra authentication을 허용한다.

Foundation이 federation/RBAC을 만든 뒤:

```text
GitHub Actions
→ OIDC federation
→ Azure identity
→ remote state / environment scope
```

를 기본 배포 경로로 전환한다.

CI identity에 subscription-wide Owner를 주지 않는다.

### Key Vault

Terraform은 Key Vault와 access boundary를 관리한다.

Secret value가 Terraform state에 들어가는 경우 state 자체를 민감 데이터로 취급한다.

실제 workload는 Workload Identity + Secrets Store CSI 경로로 secret을 읽는다.

### Acceptance

- foundation `plan` 검토
- explicit approved apply
- OIDC login without client secret
- state backend 접근
- DNS zone output 확인
- Key Vault RBAC deny/allow 확인

---

## P3.3 — Environment infrastructure

### 책임

Ephemeral environment:

- VNet
- AKS
- system/user node pools
- ACR
- Azure PostgreSQL Flexible Server
- private PostgreSQL DNS/network
- application data disk/storage
- Azure Monitor Workspace / Managed Prometheus
- Managed Grafana
- Log Analytics
- Application Insights
- required AKS managed add-ons

### Network

- Azure CNI Overlay
- PostgreSQL private access
- public exposure는 HTTPS ingress 하나
- private AKS API / Firewall / Bastion은 Core 범위 밖

### Nodes

초기 topology:

- dedicated system pool
- dedicated user pool
- evidence에서는 node count fixed

Exact SKU는 calibration 전 고정하지 않는다.

선택 원칙:

> 비용을 줄이기 위해 node를 작게 만들어 의도하지 않은 bottleneck을 만들지 않는다. 비용은 **runtime을 짧게 유지**해서 제어한다.

### PostgreSQL

- PostgreSQL 17 track
- private network
- Azure PITR enabled according to selected backup retention
- Forgejo 실험의 primary bottleneck이 아니어야 함

### Acceptance

- Terraform plan contains only expected project resources
- provision
- network/DNS reachability
- node pressure 없음
- PostgreSQL private connectivity
- Azure resource inventory 기록

---

## P3.4 — Managed platform capability

### AKS managed Istio

Azure Core의 기본 선택은 **AKS Istio service mesh add-on**이다.

현재 Azure 문서는 MeshConfig `extensionProviders`를 허용하며 sidecar `concurrency`를 지원한다. Custom extension provider 자체의 문제는 Azure support boundary 밖이다.

따라서 실제 selected AKS/Istio revision에서 다음 preflight를 통과해야 한다.

1. revision 확인
2. sidecar injection
3. `extensionProviders` shared MeshConfig 적용
4. `CUSTOM AuthorizationPolicy`로 test request만 ext_authz에 전달
5. policy 제거 후 normal path 복귀
6. Istio `Sidecar.inboundConnectionPool` 적용
7. configured active-request limit에서 Envoy rejection signal 관측

이 중 필수 기능이 blocked/비정상이라면 **그때만** self-managed Istio fallback ADR을 작성한다.

### AKS managed KEDA

Azure에서는 AKS KEDA add-on을 기본 사용한다.

P7에서 Azure Managed Prometheus query + Workload Identity 기반 scaling을 실제로 검증한다.

### Secrets Store CSI

AKS managed add-on을 사용한다.

Persistent workload secret은 Key Vault + Workload Identity를 사용한다.

### cert-manager

TLS DNS-01 발급을 위해 필요한 third-party cluster-scoped controller다.

Argo AppProject 권한을 확대하지 않고 explicit bootstrap으로 설치한다.

### Acceptance

- selected add-on revisions 기록
- sidecar injection 확인
- no experiment policy 상태에서 developer E2E PASS
- managed capability가 normal path를 오염시키지 않음

---

## P3.5 — Stable Azure platform deployment

### Argo bootstrap

Argo CD Core는 explicit bootstrap한다.

Azure Application은 final evidence에서 exact commit SHA를 사용한다.

### Argo-managed state

- Forgejo
- Azure-specific Forgejo values
- namespaced Istio routing resources
- workload ServiceAccount / SecretProviderClass
- TLS Certificate/Issuer where namespaced
- telemetry collector/config

### Forgejo Azure differences

Local contract와 동일하게 유지할 것:

- app major/LTS track
- single replica
- Recreate
- session=db
- twoqueue cache
- level queue
- SSH disabled
- Actions/Packages/migration disabled

Azure 차이:

- HTTPS
- managed PostgreSQL
- Azure storage
- Key Vault secret path

### Acceptance

- Argo Synced/Healthy
- exact targetRevision
- HTTPS domain
- Git push / clone/fetch / PR / Issue
- direct Forgejo public bypass 없음

---

## P3.6 — Azure teardown and calibration

첫 Azure environment는 final evidence environment가 아니다.

목적:

- resource sizing
- latency baseline
- node/DB/Forgejo headroom
- managed Istio/KEDA/CSI compatibility
- cost/runtime 확인
- destroy workflow 검증

Acceptance:

- environment destroy 성공
- environment RG에 예상 밖 유료 resource 없음
- orphan public IP/disk/LB/monitoring resource 확인
- actual runtime과 비용 기록

---

# P4 — Operations Contract

## P4.1 — Developer probe

현재 shell E2E는 **correctness test**로 유지한다.

SLI 측정을 위해 별도 `developer-probe` Go CLI를 만든다.

한 tool이 다음 두 역할을 담당하도록 시작한다.

- single-operation synthetic probe
- controlled load/retry driver

필요성이 생기기 전까지 별도 load-generator binary를 만들지 않는다.

### Identity

Active Window 중에는 admin bootstrap API를 호출하지 않는다.

미리 준비한:

- probe user
- PAT
- dedicated repository

를 사용한다.

### Measurement

최소 기록:

- operation type
- operation id
- start/end timestamp
- success/failure
- end-to-end duration
- operation attempt number
- error class

Developer operation과 HTTP request를 같은 수로 취급하지 않는다.

---

## P4.2 — Baseline and SLO

SLI definition을 먼저 고정하고 threshold는 측정 후 정한다.

Core SLI:

- clone/fetch success + latency
- push success + latency
- PR create/read success + latency
- Issue create/read success + latency

측정 범위는 `Service Active Window`다.

24/7 monthly availability를 주장하지 않는다.

---

## P4.3 — Observability

### Metrics

- developer probe
- Forgejo
- Envoy/Istio
- HAProxy when experiment installed
- HPA/KEDA
- Kubernetes/node
- PostgreSQL

→ Azure Managed Prometheus / Managed Grafana

### Logs

- Forgejo
- Istio/Envoy
- ext-authz-sim
- HAProxy
- Kubernetes event

→ Log Analytics

### Traces

- mesh/proxy
- ext-authz-sim

→ OTel Collector → Application Insights

Forgejo 내부 function-level tracing을 Core requirement로 두지 않는다.

---

## P4.4 — Recovery and change safety

### Restart/session

- login
- Forgejo Pod replacement
- session continuity 확인
- PAT Git operation 재확인

### Backup/restore

```text
write boundary
→ flush queues
→ graceful stop
→ PostgreSQL backup
→ application-data backup
→ secrets/version manifest
→ fresh restore target
→ forgejo doctor check --all
→ developer E2E
```

PITR만으로 전체 Forgejo backup이라고 표현하지 않는다.

### Upgrade/rollback

- release notes 확인
- pre-upgrade backup
- upgrade
- doctor + E2E
- failure 시 compatible state restore + previous app version
- 단순 image downgrade를 rollback이라고 부르지 않음

---

# P5 — Reliability Fixture

## P5.1 — ext-authz-sim

직접 개발하는 server-side application은 이 작은 Go service 하나다.

최소 기능:

- HTTP ext_authz check
- health/readiness
- Prometheus metrics
- OTel tracing
- deterministic latency/error control
- bounded in-flight option for independent application overload tests

DB를 추가하지 않는다.

---

## P5.2 — Shared-gate request path

```text
Client
→ Istio Ingress Gateway
→ CUSTOM ext_authz check
→ HAProxy
→ ext-authz-sim Pod
   → Envoy inbound sidecar
   → ext-authz-sim app
→ ALLOW / DENY
→ Gateway
→ original request
→ Forgejo native auth/authorization
```

Ext-authz request에는 Git push body 전체를 포함하지 않는다.

### Proxy capacity target

실험에서 의도적으로 제한하는 target은 **ext-authz-sim Pod의 inbound Envoy sidecar**다.

Istio `Sidecar.inboundConnectionPool`의 HTTP active-request limit을 사용한다.

이렇게 해야:

- app CPU는 낮을 수 있음
- inbound sidecar가 먼저 request를 거절함
- 같은 ext-authz Deployment를 app-CPU HPA와 proxy-signal KEDA로 비교 가능

HAProxy는 별도로 queue/admission/rate-limiting signal을 제공한다.

---

## P5.3 — Fixture lifecycle

정상 상태:

```text
Gateway → Forgejo
```

실험 상태:

```text
Gateway → shared gate check → Forgejo
```

Acceptance:

- fixture install 전 E2E PASS
- fixture healthy 상태 E2E PASS
- fixture remove 후 E2E PASS
- Forgejo native permission을 우회하지 않음
- Argo stable resource를 직접 mutation하지 않음

---

# P6 — Cascading Failure Investigation

## 시나리오 순서

1. normal baseline
2. shared gate healthy baseline
3. Envoy inbound active-request limit saturation
4. application-CPU HPA scenario
5. bounded client retry scenario
6. retry에 따른 operation attempt 증가와 proxy pressure 관찰

## Valid run 조건

Developer impact:

- operation success/latency

Mechanism:

- operation attempts/retries
- Envoy active request / circuit-breaker rejection
- HAProxy queue/admission signal
- scaling state

Confounder guard:

- Forgejo
- PostgreSQL
- AKS nodes

Node/DB/Forgejo가 먼저 포화되면 원하는 현상이 보여도 final evidence로 승격하지 않는다.

---

# P7 — Mitigation and Recovery

같은 fault/load boundary에서 변경 변수만 바꾼다.

## 비교

- no retry
- bounded immediate retry
- bounded exponential backoff + jitter
- HAProxy rate limiting/admission/queue protection
- application-CPU HPA
- KEDA using verified Envoy saturation/concurrency signal

`retry budget`은 실제 shared budget/ratio mechanism을 구현한 경우에만 그 이름을 사용한다.

## KEDA

Azure:

```text
Envoy metric
→ Azure Managed Prometheus
→ KEDA Prometheus scaler
→ ext-authz-sim Deployment replicas
```

Exact PromQL/threshold는 metric capture와 calibration 후 고정한다.

## Recovery

Demand를 중단하지 않는다.

```text
steady load
→ overload
→ mitigation
→ pressure drains
→ developer SLI recovered
```

Recovery criterion과 시간을 실제 측정한다.

---

# P8 — Critical / Bulk Traffic Isolation

복잡한 scheduler를 만들지 않는다.

최소 구조:

```text
shared authorization entry
      ↓
HAProxy classification
      ├── critical capacity pool
      └── bulk capacity pool
```

두 pool은 같은 ext-authz-sim image를 사용한다.

Synthetic client가 명시적인 lab traffic-class metadata를 사용하도록 하고, 이를 GitHub 실제 production routing이라고 주장하지 않는다.

Acceptance:

- bulk overload 유도
- bulk degradation/shedding 관찰
- critical developer operation SLI 별도 측정
- critical pool 보호 여부를 동일 workload로 비교

---

# P9 — Regression Prevention and Final Evidence

## Regression gate

Local/CI에서 비용 없이 잡을 수 있는 failure class를 자동화한다.

예:

- operation-attempt amplification upper bound
- unexpected Envoy overflow
- stable E2E regression
- scaling manifest/config regression

Azure-only behavior를 일반 PR마다 실행하지 않는다.

## Final Azure evidence

조건:

- exact source commit
- clean source state
- fixed node topology
- component runtime version/digest
- exact scenario config
- normal preflight PASS
- confounder guard
- cleanup result

비용과 variance를 고려해 final comparison은 기본적으로 **3 controlled repetitions**을 계획한다.

이를 통계적 유의성 주장으로 사용하지 않는다.

## Published result

최종 비교 축:

```text
Baseline
Cascade
Mitigated
Isolated
```

각 축에서:

- developer operation SLI
- attempt amplification
- Envoy rejection
- HAProxy pressure
- scaling
- Forgejo/DB/node health

를 같은 measurement boundary로 제시한다.

---

# 6. Azure apply / 비용 gate

## Gate 0 — Local / static

- Azure cost: 0
- Terraform validate
- k3d
- Argo integration
- local reliability development

자동 실행 가능.

## Gate 1 — Bootstrap / Foundation

사용자 명시 승인 필요.

실행 전:

- current Azure pricing estimate 작성
- resource inventory 검토
- expected persistent resources 확인
- state/RBAC preflight

Foundation은 필요 시 여러 Azure sessions 사이 유지할 수 있다.

## Gate 2 — Environment calibration

사용자 명시 승인 필요.

목표는 장기 hosting이 아니라 sizing/compatibility/calibration이다.

Environment는 필요한 session에만 만들고 작업 후 destroy한다.

## Gate 3 — Final evidence window

- exact commit freeze
- fixed topology
- scenario configuration freeze
- merge/deploy 변화 금지
- controlled repetitions

## Gate 4 — Environment destroy

- Terraform destroy
- Kubernetes/cloud resource inventory
- orphan disk/IP/LB 확인
- monitoring resource 확인
- actual cost/runtime 기록

## Gate 5 — Project finalization

프로젝트 완전 종료 시:

- environment 없음 확인
- 가비아 project subdomain delegation 제거
- foundation identity/RBAC 제거
- Key Vault soft-delete/purge 상태 확인
- foundation destroy
- Terraform state 보존 필요성 확인
- bootstrap destroy
- project-owned Azure resource final inventory

`terraform destroy` 성공만으로 `zero residual`을 주장하지 않는다.

---

# 7. Work unit 공통 Definition of Done

각 구현 PR은 가능한 경우 다음을 명시한다.

## Prerequisite

무엇이 먼저 완료되어야 하는가.

## Change

이번 PR이 실제로 추가/변경하는 capability.

## Verification

실제로 실행한 command/test.

## Acceptance

무엇이 관측돼야 완료인가.

## Cost impact

Azure resource를 만들거나 과금 경로를 바꾸는가.

## Cleanup / rollback

실패 시 되돌리는 방법.

## Evidence

무엇을 machine-readable하게 남기는가.

작은 코드 변경에 이 항목을 형식적으로 모두 채우라는 의미는 아니다. Azure/experiment/recovery처럼 lifecycle이 중요한 work unit에서 사용한다.

---

# 8. 구현 중 새 결정을 여는 기준

다음 조건이 아니면 새 technology를 추가하지 않는다.

1. 현재 설계로 해결할 수 없는 실제 문제가 관측됨
2. 추가 component가 문제를 어떻게 해결하는지 설명 가능
3. 새로운 failure domain과 운영비용을 검증할 방법이 있음
4. Core scope를 늘릴 가치가 있음

따라서 다음은 기본적으로 Optional이다.

- Redis/Valkey
- Forgejo multi-replica
- separate GitOps repo
- full Argo CD UI/HA
- Elasticsearch/Meilisearch
- multi-region
- Backstage
- service bus / Kafka / RabbitMQ
- complex priority scheduler
