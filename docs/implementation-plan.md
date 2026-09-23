# Implementation Plan

## 1. 목적

이 문서는 Project Charter와 Architecture를 **실제로 구현하고 검증할 수 있는 work unit**으로 변환한다.

목표는 기술을 많이 넣는 것이 아니다. 각 단계에서 다음 질문에 답할 수 있어야 한다.

- 왜 지금 이 capability가 필요한가?
- 무엇이 먼저 완료되어야 하는가?
- 무엇을 실제로 검증해야 완료인가?
- Azure 비용은 언제부터 발생하는가?
- 실패하면 무엇을 되돌리거나 재검토하는가?
- 어떤 evidence를 남기는가?

파일명, SKU, threshold처럼 baseline/calibration이 필요한 값은 필요하기 전에 고정하지 않는다.

---

## 2. 현재 상태

| 단계 | 상태 | 실제 검증 범위 |
| --- | --- | --- |
| P0 Project Foundation | 완료 | Charter / Architecture / conventions |
| P1 Local Correctness Baseline | 완료 | fresh k3d + Forgejo + Git/PR/Issue E2E |
| P2 GitOps Integration | 완료 | Argo CD Core sync/self-heal + E2E |
| P3A.1 Terraform State Bootstrap Source | 완료 | source / provider lock / static CI |
| P3A Azure IaC Specification | 진행 | Azure apply 없이 source와 lifecycle 정의 |
| P4A Local Operations Contract | 진행 전 | |
| P5 Local Reliability Fixture | 진행 전 | |
| P3B Azure Calibration Environment | 진행 전 | 명시적 승인 필요 |
| P4B Azure Operations Verification | 진행 전 | |
| P6~P9 Final Experiment/Evidence | 진행 전 | |

여기서 **완료**는 현재 repository와 CI에서 실제로 검증한 범위만 뜻한다. Local에서 통과한 기능을 Azure에서도 검증됐다고 표현하지 않는다.

---

## 3. 구현 순서

무료 Azure credit이 끝난 PAYG 환경이므로 Azure를 먼저 띄운 채 개발하지 않는다.

최종 순서는 다음과 같다.

```text
P0  Project foundation                         DONE
 ↓
P1  Local Forgejo correctness                  DONE
 ↓
P2  Local GitOps reconciliation                DONE
 ↓
P3A Azure IaC / identity / lifecycle source    COST 0
 ↓
P4A Local operations + measurement             COST 0
 ↓
P5  Local reliability fixture                  COST 0
 ↓
P3B Azure provision + compatibility calibration   PAID, SHORT-LIVED
 ↓
P4B Azure operations verification                 PAID, SHORT-LIVED
 ↓
P6  Cascade investigation
 ↓
P7  Mitigation + recovery
 ↓
P8  Critical / bulk isolation
 ↓
P9  Regression gate + final evidence + teardown
```

이 순서는 단순 비용 절감용 타협이 아니다.

Azure에서 처음부터 application/experiment bug를 디버깅하지 않고, **Local에서 이미 검증한 workload와 experiment contract를 Cloud integration 대상으로 가져가기 위한 경계**다.

---

## 4. 최종 repository 책임 구조

아래는 논리적 destination이다. 필요하기 전에는 빈 디렉터리를 만들지 않는다.

```text
cmd/
├── developer-probe/        # P4A부터
└── ext-authz-sim/          # P5부터

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
├── ingress/
├── tls/
└── telemetry/

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

# 5. Control-plane ownership

## 5.1 Terraform

Terraform은 Azure resource와 Azure-managed capability의 lifecycle을 담당한다.

- Terraform state backend
- permission-boundary resource groups
- Azure identities / RBAC
- Azure DNS / Key Vault
- VNet / AKS / PostgreSQL / storage
- Azure-managed observability
- AKS managed add-on enablement

Azure Core에서는 다음을 managed capability로 우선 사용한다.

- AKS Istio service mesh add-on
- AKS KEDA add-on
- Azure Key Vault provider for Secrets Store CSI Driver

Cluster-scoped controller를 GitOps라는 이유만으로 직접 운영하지 않는다.

## 5.2 Explicit cluster bootstrap

GitHub Actions 또는 명시적 bootstrap 절차가 담당한다.

- Argo CD Core 자체
- cert-manager controller
- AKS managed Istio의 shared MeshConfig
- managed Istio ingress Service에 필요한 supported Azure Load Balancer annotation

이 영역은 `capacity-platform` AppProject의 scope를 넓히기 위한 이유가 되어서는 안 된다.

## 5.3 Argo CD Core

Argo CD는 **stable namespaced desired state**를 기본 관리 범위로 한다.

예:

- Forgejo
- Istio `Gateway` / `VirtualService` 같은 namespaced routing object
- namespaced `Issuer` / `Certificate`
- workload ServiceAccount / SecretProviderClass
- namespaced telemetry configuration

계약:

- exact Git revision
- auto-sync
- self-heal
- automatic prune off
- source/destination restriction
- experiment resource를 관리하지 않음

주의:

> AppProject restriction은 Argo application의 logical boundary다. upstream Argo CD Core controller ServiceAccount의 실제 Kubernetes RBAC가 자동으로 namespace-only가 되는 것은 아니다.

Core에서는 default Core controller privilege를 single-operator ephemeral environment의 의도적인 production-readiness deviation으로 기록한다. 추가 RBAC hardening은 필요성이 확인될 때만 수행한다.

## 5.4 AKS managed Istio ingress

Managed Istio ingress gateway의 Deployment/Service lifecycle은 AKS add-on 영역이다.

Argo는 gateway Deployment를 소유하지 않는다.

Terraform이 static public IP를 준비하고, explicit bootstrap이 AKS가 지원하는 Service annotation을 통해 managed ingress Service와 연결한다. Argo는 그 위의 namespaced routing configuration을 관리한다.

## 5.5 Experiment runner

실험에서만 생기거나 바뀌는 state를 소유한다.

- HAProxy
- ext-authz-sim
- temporary `CUSTOM AuthorizationPolicy`
- experiment `Sidecar` connection-pool policy
- HPA / ScaledObject
- load/fault configuration
- traffic-class routing

실험이 끝나면 자신이 만든 resource를 제거한다.

---

# 6. Local / Azure parity

Local과 Azure가 같은 설치 방법을 사용해야 한다는 뜻은 아니다.

같아야 하는 것:

- Forgejo operating contract
- developer operation 정의
- GitOps desired-state semantics
- shared-gate request path
- experiment variable
- measurement boundary

달라도 되는 것:

- local PostgreSQL fixture vs Azure PostgreSQL
- upstream Istio local install vs AKS managed Istio
- local metric collection vs Azure Managed Prometheus
- local Secret vs Azure Key Vault
- local KEDA runtime 검증 방식 vs AKS managed KEDA

환경 차이는 final evidence의 provenance에 기록한다.

---

# P0 — Project Foundation

**상태: 완료**

완료 범위:

- Charter
- Architecture
- conventions / terminology
- responsibility-oriented repository
- PR-gated change management

---

# P1 — Local Correctness Baseline

**상태: 완료**

구현/검증:

- Forgejo v15 LTS exact patch pin
- upstream Forgejo Helm chart exact version
- single replica / Recreate
- local PostgreSQL substitute
- fresh k3d lifecycle
- health/version smoke
- developer correctness E2E
  - Git push
  - clone/fetch
  - feature push
  - PR create/read
  - Issue create/read
- disposable test user/repository cleanup

P1 shell E2E는 **correctness test**이며 SLI measurement tool이 아니다.

---

# P2 — GitOps Integration

**상태: 완료**

Acceptance:

- Argo CD Core exact version/commit pin
- restricted AppProject
- upstream Forgejo chart + repository values
- PR head checkout revision = Argo `targetRevision`
- initial Synced/Healthy
- controlled Forgejo replica drift
- self-heal
- post-heal developer E2E
- automatic prune off

---

# P3A — Azure IaC Specification and Static Validation

**Azure cost: 0**

Azure resource를 만들지 않고 lifecycle, identity, network, add-on source를 완성한다.

## P3A.1 — Bootstrap boundary

현재 state storage source는 존재한다. 다음 변경에서 bootstrap 책임을 최종 경계에 맞춘다.

Bootstrap이 소유:

- state Resource Group / Storage Account / private blob container
- GitHub Actions용 user-assigned managed identity
- GitHub Environment `azure`를 subject로 하는 federated identity credential
- empty foundation Resource Group
- empty environment Resource Group
- CI identity에 필요한 scoped RBAC

CI identity 기본 권한:

- state storage에 Blob state read/write가 가능한 data-plane role
- foundation Resource Group에 resource 관리 권한
- environment Resource Group에 resource 관리 권한
- 위 두 RG에서 Terraform이 필요한 role assignment를 만들 수 있는 scoped RBAC-management 권한

Subscription-wide Owner/Contributor를 기본값으로 사용하지 않는다.

Bootstrap/final teardown은 local operator가 Azure CLI/Entra authentication으로 수행하는 것을 기본으로 한다.

### Acceptance

Static 단계:

- `fmt`
- `init -backend=false -lockfile=readonly`
- `validate`
- intended RBAC scope review

Actual Azure apply는 Gate 1에서만 수행한다.

## P3A.2 — Foundation source

Foundation은 bootstrap이 미리 만든 foundation RG 안에서 다음을 관리한다.

- project-dedicated Azure DNS public zone
- Azure Key Vault
- persistent shared identities/RBAC 중 실제로 필요한 것

가비아 parent domain 전체를 Azure로 이전하지 않는다.

```text
parent.example
└── project-subdomain.parent.example
      └── NS delegation → Azure DNS
```

가비아의 NS delegation 자체는 외부-provider runbook action이며 Terraform Azure state에 넣지 않는다.

## P3A.3 — Environment source

Environment는 bootstrap이 미리 만든 environment RG 안에서 다음을 관리한다.

- VNet / subnets
- AKS
- system/user node pools
- ACR
- Azure PostgreSQL Flexible Server
- private PostgreSQL network/DNS
- Forgejo application-data storage
- Azure Monitor Workspace / Managed Prometheus
- Managed Grafana
- Log Analytics
- Application Insights
- static public IP
- required AKS managed add-ons

### Network

- Azure CNI Overlay
- PostgreSQL private access
- public exposure는 HTTPS ingress 하나
- private AKS API / Firewall / Bastion은 Core 범위 밖

### Nodes

- dedicated system pool
- dedicated user pool
- final evidence에서 node capacity fixed

Exact SKU/count는 Azure preflight/calibration 후 고정한다.

비용은 node를 위험하게 줄여서가 아니라 **environment runtime을 짧게 유지해** 제어한다.

## P3A.4 — Managed capability source

### Istio

Azure 기본 선택은 AKS managed Istio add-on이다.

중요한 dependency:

> 이 프로젝트가 사용하는 `Sidecar.inboundConnectionPool`은 Istio 1.30+가 필요하다.

따라서 실제 Azure environment에서 선택하는 managed revision은 **`asm-1-30` 이상**이어야 한다.

Exact revision은 source에 추측으로 고정하지 않는다. Azure apply 직전에 region/AKS compatibility를 조회해 고정하고 evidence에 기록한다.

Local reliability fixture도 가능한 한 같은 Istio minor(1.30+)를 사용한다.

### KEDA

Azure는 AKS managed KEDA add-on을 사용한다.

Controller는 Azure-managed이고, experiment runner가 scenario-specific ScaledObject를 소유한다.

### Key Vault CSI

AKS managed Key Vault CSI provider를 사용한다.

### cert-manager

TLS DNS-01에 필요할 때만 설치한다.

- controller: explicit cluster bootstrap
- 가능하면 namespaced `Issuer` / `Certificate`: Argo
- `ClusterIssuer`는 실제 요구가 없으면 사용하지 않음

---

# P4A — Local Operations and Measurement Contract

**Azure cost: 0**

Reliability experiment 전에 정상 운영의 measurement/recovery contract를 local에서 만든다.

## P4A.1 — developer-probe

별도 Go CLI 하나로 시작한다.

역할:

- single developer operation probe
- controlled repeated operation
- client-side retry mode

필요가 확인되기 전까지 별도 load-generator binary를 만들지 않는다.

Core operation:

- clone/fetch
- push
- PR create/read
- Issue create/read

### Measurement schema

최소 기록:

- run/scenario identity
- operation type
- operation id
- start/end timestamp
- success/failure
- end-to-end duration
- operation attempt number
- retry reason/error class

Developer operation과 HTTP request를 같은 수로 취급하지 않는다.

Metric label은 operation type/outcome 같은 low-cardinality 값만 사용한다. operation id는 metric label에 넣지 않는다.

### Identity

Active Window 측정 중에는 admin bootstrap API를 호출하지 않는다.

미리 준비한:

- probe user
- PAT
- dedicated repository

를 사용한다.

## P4A.2 — Local instrumentation contract

Azure managed observability stack을 Local에 복제하지 않는다.

Local에서 먼저 고정할 것:

- metric names / units / labels
- structured log schema
- request/run correlation
- ext-authz-sim OTel span boundary
- Prometheus scrape endpoint

Azure exporter/backend 연결은 P4B에서 수행한다.

## P4A.3 — Forgejo state/recovery mechanics

### Session continuity

- UI login/session 획득
- Forgejo Pod replacement
- session continuity 확인
- PAT 기반 Git operation 재확인

### Backup mechanics

Local에서 coordinated recovery 절차를 먼저 검증한다.

```text
write boundary
→ flush queues
→ graceful stop
→ pg_dump
→ application-data backup
→ secret/version manifest
→ fresh restore target
→ forgejo doctor check --all
→ developer E2E
```

Azure PITR를 전체 Forgejo backup으로 표현하지 않는다.

### Upgrade/rollback

- release notes 확인
- pre-upgrade backup
- upgrade
- doctor + E2E
- failure 시 compatible state restore + previous app version

단순 image downgrade를 rollback이라고 부르지 않는다.

---

# P5 — Local Reliability Fixture

**Azure cost: 0**

GitHub public RCA에서 추출한 failure effect를 local에서 먼저 재현 가능한 fixture로 만든다.

## P5.1 — ext-authz-sim

직접 개발하는 server-side service는 이 작은 Go service 하나다.

최소 기능:

- Envoy HTTP external authorization response
- health/readiness
- Prometheus metrics
- OTel tracing
- deterministic latency/error control
- bounded in-flight option
- runtime fault control

DB를 추가하지 않는다.

Check data path와 admin/control surface는 분리한다.

예:

- request-check port
- admin/metrics port

Admin/fault endpoint는 public ingress로 노출하지 않는다.

## P5.2 — shared gate

Experiment namespace의 기본 구조:

```text
Istio Gateway
→ ext_authz provider
→ HAProxy               # sidecar injection 없음
→ ext-authz-sim Service
→ Envoy inbound sidecar
→ ext-authz-sim app
```

정상 original request는 authorization ALLOW 후 Forgejo로 간다.

`ext-authz-sim`은 Forgejo native authentication/authorization을 대체하지 않는다.

Git push body 전체를 ext-authz service로 보내지 않는다.

## P5.3 — proxy capacity target

의도적으로 제한하는 target은 **ext-authz-sim Pod의 inbound Envoy sidecar**다.

Istio 1.30+ `Sidecar.inboundConnectionPool`에서 HTTP active-request limit을 구성한다.

이렇게 해야 다음 관계를 연구할 수 있다.

```text
application CPU remains relatively low
        ↓
Envoy inbound active-request limit saturates
        ↓
request rejection
        ↓
application-container CPU HPA can miss the bottleneck
```

HAProxy는 별도의 queue/admission/rate-limiting layer다.

## P5.4 — Local scenario acceptance

필수:

1. normal path E2E PASS
2. shared gate healthy 상태 E2E PASS
3. configured sidecar limit saturation
4. Envoy rejection signal 관측
5. retry 없음 / bounded retry operation attempt 차이 측정
6. fixture 제거 후 normal path E2E PASS
7. Forgejo/DB/node가 primary bottleneck이 아님

Local에서 KEDA runtime이 꼭 필요하다고 증명되기 전까지 controller를 추가하지 않는다. KEDA manifest/schema와 metric contract는 준비하되, Azure managed KEDA integration은 P7에서 검증한다.

---

# P3B — Azure Provision and Compatibility Calibration

**유료 Azure session. 사용자 명시 승인 필수.**

Local application/fixture contract가 안정된 뒤 처음 실제 Azure environment를 만든다.

## P3B.1 — Gate 1: bootstrap / foundation

실행 전:

- current Azure pricing estimate
- intended resource inventory
- current subscription/region preflight
- required Resource Provider registration
- exact Git commit
- user approval

검증:

- bootstrap apply
- remote state actual read/write via authorized principal
- GitHub OIDC login without client secret
- foundation apply
- DNS zone output
- Key Vault RBAC allow/deny
- no subscription-wide CI privilege

## P3B.2 — Gate 2: environment calibration

Environment를 짧게 provision한다.

Preflight에서 확정:

- AKS supported Kubernetes version
- AKS managed Istio revision, 반드시 asm-1-30+
- node SKU availability/quota
- PostgreSQL SKU availability
- expected Azure managed observability resources

## P3B.3 — Managed capability preflight

### Istio

검증:

1. selected revision 확인
2. sidecar injection
3. shared MeshConfig `extensionProviders`
4. `CUSTOM AuthorizationPolicy`
5. managed ingress
6. `Sidecar.inboundConnectionPool`
7. Envoy rejection metric
8. policy 제거 후 normal path 복귀

필수 기능이 blocked되거나 재현 불가능할 때만 self-managed Istio fallback ADR을 연다.

`EnvoyFilter`를 Core 기본 해법으로 사용하지 않는다.

### KEDA

- managed KEDA controller 동작
- Workload Identity path 준비
- Azure Managed Prometheus scaler compatibility

### Key Vault CSI

- Workload Identity
- secret mount/sync
- Pod recreation 후 stable cryptographic material 유지

## P3B.4 — Stable Azure platform

- Argo CD Core explicit bootstrap
- exact `targetRevision`
- Forgejo Azure values
- managed Istio routing
- HTTPS
- managed PostgreSQL
- Key Vault secret path
- direct Forgejo public bypass 없음

Developer E2E 전체 통과가 acceptance다.

## P3B.5 — Calibration / destroy

첫 Azure environment의 목적은 final evidence가 아니다.

측정:

- baseline CPU/memory
- node headroom
- Forgejo headroom
- DB connections/latency/headroom
- base developer latency
- actual runtime
- actual cost signal

이 세션에서 node SKU/count를 evidence profile 후보로 고정한다.

작업 후 environment destroy하고 project-owned **ephemeral environment resource**가 남지 않았는지 inventory로 확인한다.

Foundation/bootstrap은 이후 세션을 위해 의도적으로 남길 수 있다.

---

# P4B — Azure Operations Verification

**유료 Azure session.**

## P4B.1 — Managed observability

Metrics:

- developer probe
- Forgejo
- Istio/Envoy
- HPA/KEDA
- Kubernetes/node
- PostgreSQL
- HAProxy/ext-authz when fixture active

→ Azure Managed Prometheus / Managed Grafana

Logs:

→ Log Analytics

Traces:

- mesh/proxy
- ext-authz-sim

→ OTel Collector → Application Insights

Forgejo internal function-level tracing은 Core requirement가 아니다.

## P4B.2 — Baseline SLI/SLO

Service Active Window에서 baseline을 측정한 후에만 threshold를 확정한다.

Core SLI:

- clone/fetch success + latency
- push success + latency
- PR create/read success + latency
- Issue create/read success + latency

24/7 monthly availability를 주장하지 않는다.

## P4B.3 — Azure recovery drill

비용을 줄이기 위해 별도 PostgreSQL server를 무조건 하나 더 만들지 않는다.

가능하면:

- 같은 Azure PostgreSQL server의 fresh restore database
- fresh namespace/PVC

를 사용해 application restore를 검증한다.

Acceptance:

- DB + app-data + secret/version state 복원
- `forgejo doctor check --all`
- developer E2E
- restore target cleanup

PITR는 별도 DB recovery capability로 확인한다.

## P4B.4 — Upgrade/rollback

Azure에서 실제 state-aware upgrade/rollback contract를 한 번 검증한다.

---

# P6 — Cascading Failure Investigation

Final evidence에 사용할 controlled incident를 만든다.

Scenario progression:

1. normal baseline
2. healthy shared-gate baseline
3. Envoy inbound active-request limit saturation
4. application-container CPU HPA scenario
5. bounded retry scenario
6. retry에 따른 attempt 증가와 proxy pressure 관찰

Valid run은 다음 세 층을 함께 만족해야 한다.

### Developer impact

- operation success
- operation latency

### Mechanism

- operation attempts/retries
- Envoy active request/rejection
- HAProxy queue/admission
- scaling state

### Confounder guard

- Forgejo
- PostgreSQL
- AKS nodes

Node/DB/Forgejo가 먼저 포화되면 원하는 현상이 보여도 final evidence로 승격하지 않는다.

---

# P7 — Mitigation and Recovery

같은 workload/fault boundary에서 변경 변수만 바꾼다.

비교:

- no retry
- bounded immediate retry
- bounded exponential backoff + jitter
- HAProxy rate limiting/admission/queue protection
- application-container CPU HPA
- KEDA based on verified Envoy saturation/concurrency signal

`retry budget`은 실제 shared budget/ratio mechanism을 구현했을 때만 그 이름을 사용한다.

## KEDA path

Azure:

```text
Envoy metric
→ Azure Managed Prometheus
→ AKS managed KEDA Prometheus scaler
→ ext-authz-sim Deployment
```

KEDA identity에는 Azure Monitor Workspace를 읽을 수 있는 최소 role을 부여한다.

Exact PromQL/threshold는 실제 metric capture/calibration 후 고정한다.

HPA와 KEDA는 같은 scenario에서 동시에 Deployment를 제어하지 않는다.

## Recovery

Demand를 중단하지 않는다.

```text
steady demand
→ overload
→ mitigation
→ pressure drains
→ developer SLI recovered
```

Recovery criterion/time을 실제 측정한다.

---

# P8 — Critical / Bulk Traffic Isolation

복잡한 scheduler는 만들지 않는다.

최소 구조:

```text
authorization check entry
      ↓
HAProxy classification
      ├── critical capacity pool
      └── bulk capacity pool
```

두 pool은 같은 ext-authz-sim image를 사용한다.

Synthetic client는 명시적인 lab traffic-class metadata를 사용한다. 이를 GitHub 실제 production routing이라고 주장하지 않는다.

Acceptance:

- bulk overload
- bulk degradation/shedding
- critical developer operation 별도 측정
- critical pool 보호 여부 비교

Per-user fairness, dynamic priority queue, custom scheduler는 Core 범위 밖이다.

---

# P9 — Regression Prevention and Final Evidence

## P9.1 — Cost-free regression gate

일반 PR에서 Azure를 띄우지 않는다.

Local/CI에서 잡을 수 있는 failure class만 자동화한다.

예:

- developer correctness regression
- operation-attempt amplification bound
- unexpected Envoy rejection in normal profile
- scenario manifest/config regression
- GitOps revision contract regression

## P9.2 — Final Azure evidence

조건:

- exact source commit
- clean source state
- fixed node topology
- runtime versions/digests
- exact scenario configuration
- normal preflight PASS
- confounder guard
- observation window
- cleanup result

Final comparison은 기본적으로 3 controlled repetitions을 계획한다.

이를 통계적 유의성 주장으로 사용하지 않는다.

Published comparison:

```text
Baseline
Cascade
Mitigated
Isolated
```

공통 축:

- developer operation SLI
- operation-attempt amplification
- Envoy rejection
- HAProxy pressure
- scaling state
- Forgejo/DB/node health

## P9.3 — Final teardown

Project completion 후:

1. environment destroy
2. environment residual inventory
3. 가비아 project subdomain delegation 제거
4. foundation resource/identity/RBAC 제거
5. Key Vault soft-delete/purge 상태 확인
6. foundation destroy
7. remote state 보존 필요성 최종 확인
8. bootstrap destroy
9. project-owned Azure resource final inventory
10. final cost 확인

`terraform destroy` 성공만으로 `zero residual`을 주장하지 않는다.

---

# 7. Azure 비용 gate

## Gate 0 — Local/static

Azure cost: 0

자동 실행 가능.

- Terraform fmt/init/validate
- k3d
- Argo integration
- developer probe
- local recovery
- local reliability fixture

## Gate 1 — Bootstrap/foundation

사용자 명시 승인 필요.

실행 전:

- pricing estimate
- resource/RBAC inventory
- region/subscription preflight
- expected persistent resources

## Gate 2 — Calibration environment

사용자 명시 승인 필요.

목적:

- compatibility
- sizing
- baseline
- cost
- destroy workflow

장기 hosting 용도가 아니다.

## Gate 3 — Final evidence window

- exact commit freeze
- fixed topology
- scenario freeze
- evidence window 중 merge/deploy 변화 금지
- controlled repetitions

## Gate 4 — Environment destroy

- Terraform destroy
- cloud inventory
- orphan disk/IP/LB 확인
- monitoring resource 확인
- actual runtime/cost 기록

## Gate 5 — Project finalization

Foundation/bootstrap/DNS delegation까지 정리한다.

---

# 8. Work unit Definition of Done

Azure/experiment/recovery처럼 lifecycle이 중요한 PR은 다음을 답한다.

- **Prerequisite** — 무엇이 먼저 완료돼야 하는가
- **Change** — 이번 unit이 추가하는 capability
- **Verification** — 실제 실행한 test/command
- **Acceptance** — 완료 판정
- **Cost impact** — Azure 비용/권한 변화
- **Cleanup/Rollback** — 실패 시 복구
- **Evidence** — 무엇을 남기는가

작은 문서 수정에 이 형식을 억지로 적용하지 않는다.

---

# 9. 새 기술을 추가하는 조건

다음 네 조건을 만족하지 않으면 새 technology/controller/service를 Core에 추가하지 않는다.

1. 현재 설계로 해결할 수 없는 실제 문제가 관측됨
2. 새 component가 문제를 어떻게 해결하는지 설명 가능
3. 추가 failure domain/운영비용을 검증할 방법이 있음
4. Core scope를 늘릴 가치가 있음

기본 Optional:

- Redis/Valkey
- Forgejo multi-replica
- separate GitOps repo
- full Argo CD UI/HA
- Elasticsearch/Meilisearch
- multi-region
- Backstage
- Kafka/RabbitMQ/Service Bus
- complex priority scheduler
- always-on public demo
