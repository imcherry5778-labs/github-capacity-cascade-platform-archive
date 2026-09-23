# Implementation Plan

## 1. 목적

이 문서는 Roadmap의 milestone을 **실제 구현 단위와 완료 조건**으로 바꾼다.

상세 architecture/ownership은 [Architecture](architecture.md), production과 다른 선택은 [Production Readiness Boundary](production-readiness.md)를 따른다.

원칙:

- 한 PR은 가능한 한 하나의 capability를 완성한다.
- baseline/calibration이 필요한 숫자를 미리 고정하지 않는다.
- Azure는 Local에서 application/experiment contract가 안정된 뒤 짧게 사용한다.
- Azure `apply` / `destroy`는 명시적 승인 없이 실행하지 않는다.

---

## 2. 현재 상태와 실행 순서

| Unit | 상태 | Azure 비용 |
| --- | --- | ---: |
| P0 Foundation docs | 완료 | 0 |
| P1 Local Forgejo correctness | 완료 | 0 |
| P2 Local GitOps integration | 완료 | 0 |
| P3A Azure IaC source/static validation | 진행 | 0 |
| P4A Local operations/measurement | 대기 | 0 |
| P5 Local reliability fixture | 대기 | 0 |
| P3B Azure calibration environment | 대기 | 발생 |
| P4B Azure operations verification | 대기 | 발생 |
| P6 Cascade investigation | 대기 | 발생 |
| P7 Mitigation/recovery | 대기 | 발생 |
| P8 Critical/bulk isolation | 대기 | 발생 |
| P9 Regression/final evidence | 대기 | 일부 발생 |

```text
P3A Azure source
      ↓
P4A Local measurement/recovery
      ↓
P5  Local failure fixture
      ↓
P3B Azure calibration
      ↓
P4B Azure operations
      ↓
P6 → P7 → P8 → P9
```

PAYG Azure를 상시 개발 환경으로 사용하지 않는다.

---

## 3. P0~P2 완료 계약

### P1 Local correctness

현재 검증됨:

- fresh k3d lifecycle
- Forgejo v15 LTS pinned baseline
- local PostgreSQL fixture
- Git push
- clone/fetch
- feature push
- PR create/read
- Issue create/read
- disposable E2E fixture cleanup

Shell E2E는 correctness test다. SLI/load measurement는 P4A의 `developer-probe`가 담당한다.

### P2 GitOps

현재 검증됨:

- Argo CD Core exact version/commit
- restricted AppProject
- exact PR head checkout = Argo `targetRevision`
- Synced/Healthy
- manual replica drift
- self-heal
- post-heal developer E2E
- automatic prune off

---

# 4. P3A — Azure IaC source/static validation

**목표:** Azure resource를 만들기 전에 lifecycle, identity, network, managed add-on source를 완성한다.

## P3A.1 Bootstrap

현재 state storage source는 있다. 다음 implementation PR에서 bootstrap 책임을 최종 형태로 맞춘다.

Bootstrap owns:

- state RG / Storage Account / private blob container
- GitHub Actions user-assigned managed identity
- GitHub Environment `azure`용 federated credential
- empty foundation RG
- empty environment RG
- CI identity scoped RBAC

CI identity 기본 boundary:

- state storage의 Blob state read/write
- foundation RG resource 관리
- environment RG resource 관리
- 위 RG 안에서 필요한 role assignment 관리

Subscription-wide Owner/Contributor는 기본값으로 사용하지 않는다.

Bootstrap과 project finalization은 local operator의 Azure CLI/Entra authentication을 기본으로 한다.

**DoD**

- Terraform fmt/init/validate
- provider lock
- intended RBAC scope 문서 검토
- no secret/state committed
- actual apply는 Gate 1까지 금지

## P3A.2 Foundation source

Foundation owns only long-lived shared resources:

- project subdomain Azure DNS zone
- Azure Key Vault
- persistent identity/RBAC 중 필요한 최소 항목

가비아 parent domain은 유지한다. Azure에는 project subdomain만 NS delegation한다.

**DoD**

- remote backend declaration
- Terraform static validate
- DNS/Key Vault names are inputs, not hardcoded account-specific values
- finalization order documented

## P3A.3 Environment source

Environment owns ephemeral paid runtime:

- VNet/subnets
- AKS
- system/user node pools
- ACR
- Azure PostgreSQL Flexible Server
- private PostgreSQL DNS/network
- application-data storage
- Azure Monitor Workspace / Managed Prometheus
- Managed Grafana
- Log Analytics
- Application Insights
- static public IP
- AKS managed Istio/KEDA/Key Vault CSI enablement

Network contract:

- Azure CNI Overlay
- private PostgreSQL
- public exposure is HTTPS ingress only
- private AKS API / Firewall / Bastion are out of Core scope

Node SKU/count is not fixed until P3B calibration.

## P3A.4 Managed capability requirement

### Istio

Azure default: AKS managed Istio.

The experiment uses `Sidecar.inboundConnectionPool`, so selected revision must be **`asm-1-30` or newer**.

Exact revision is selected after region/AKS compatibility preflight, not guessed now.

Required preflight later:

- injection
- MeshConfig `extensionProviders`
- `CUSTOM AuthorizationPolicy`
- `Sidecar.inboundConnectionPool`
- Envoy rejection metric
- policy removal restores normal path

If a required capability is blocked, only then open a self-managed Istio fallback ADR.

### KEDA

Azure default: AKS managed KEDA. Scenario-specific ScaledObject remains experiment-owned.

### Key Vault CSI

Azure default: AKS managed provider + Workload Identity.

### cert-manager

Install only when TLS work starts.

- controller: explicit cluster bootstrap
- Azure DNS DNS-01 authentication: Workload Identity
- issuer: ACME `ClusterIssuer`
- ingress `Certificate`: `aks-istio-ingress` namespace
- resulting TLS Secret name must match Istio `Gateway.spec.servers[].tls.credentialName`

AKS managed Istio ingress reads the TLS credential from the ingress gateway namespace. Therefore ingress certificate lifecycle is **not** placed under the Argo `platform` AppProject.

Core does not add a Key Vault certificate automation pipeline for public ingress TLS. Key Vault remains the persistent application-secret boundary; cert-manager owns the renewable ingress TLS Secret.

Microsoft's managed-Istio secure-gateway example uses Key Vault CSI to create the same gateway TLS Secret in `aks-istio-ingress`. Our cert-manager path is therefore a **project implementation choice**, not an Azure product requirement. P3B preflight must prove that the cert-manager-generated Secret is accepted by the selected managed ingress revision. If this fails, fall back to the documented Key Vault CSI gateway-credential path rather than widening Argo ownership or adding a custom ingress controller.

---

# 5. P4A — Local operations/measurement

**Goal:** define how normal developer experience is measured and recovered before introducing faults.

## P4A.1 Structured developer probe

새 binary를 먼저 만들지 않는다. 현재 E2E에서 이미 검증된 **Git CLI + curl/Forgejo API** 경로를 재사용해 structured probe를 먼저 만든다.

Responsibilities:

- single developer operation 실행
- machine-readable JSONL/summary output
- end-to-end duration과 success/failure 기록
- 동일한 pre-created user/PAT/repository를 반복 사용
- correctness fixture 생성용 admin API를 measured path에서 제외

Core operations:

- clone/fetch
- push
- PR create/read
- Issue create/read

Minimum result fields:

- run/scenario id
- operation type/id
- timestamps
- success/failure
- end-to-end duration
- attempt number
- retry/error class

Rules:

- developer operation != HTTP request
- operation id is not a Prometheus label
- metrics use low-cardinality operation/outcome labels
- active measurement does not create/delete users on every operation

Bulk/retry traffic generation은 **k6**를 우선 사용한다. k6 scenario에서 logical operation과 client request attempt를 별도 counter로 기록한다.

별도 Go `developer-probe` binary는 shell/curl/Git CLI 구조로 측정 정확도나 동시성 요구를 만족할 수 없다는 실제 문제가 확인될 때만 도입한다. Core에서 직접 개발하는 필수 server-side binary는 `ext-authz-sim` 하나로 유지한다.

## P4A.2 Instrumentation contract

Local does not clone the whole Azure observability stack.

Local only fixes:

- metric names/units/labels
- structured log schema
- run/request correlation
- Prometheus endpoints
- ext-authz-sim OTel span boundary when P5 starts

Backend-specific Azure wiring waits for P4B.

## P4A.3 Forgejo recovery mechanics

Verify locally:

- browser/UI session continuity across Forgejo Pod replacement
- PAT Git still works after restart
- coordinated backup mechanics
- fresh restore target
- `forgejo doctor check --all`
- developer E2E
- upgrade and state-aware rollback mechanics

Backup boundary:

```text
write boundary
→ flush queues
→ graceful stop
→ pg_dump
→ application-data backup
→ secret/version manifest
→ restore
→ doctor
→ E2E
```

PITR alone is not Forgejo recovery.

---

# 6. P5 — Local reliability fixture

**Goal:** make the failure mechanism reproducible before paying for Azure.

## P5.1 ext-authz-sim

Only custom server-side service in Core.

Minimum capability:

- Envoy HTTP external authorization response
- health/readiness
- Prometheus metrics
- OTel tracing
- deterministic latency/error control
- bounded in-flight option
- runtime fault control

No database.

Request-check data path and admin/metrics surface use separate ports. Admin/fault control is never public ingress.

## P5.2 Shared gate

```text
Istio ingress
→ ext_authz check
→ HAProxy                 # no sidecar
→ ext-authz-sim Service
→ Envoy inbound sidecar
→ ext-authz-sim app
→ ALLOW / DENY
→ original request → Forgejo
```

The gate does not replace Forgejo authentication/authorization and does not receive the full Git push body.

## P5.3 Capacity target

Use upstream Istio 1.30+ locally.

The intentional bottleneck is ext-authz-sim Pod **inbound Envoy**, configured through `Sidecar.inboundConnectionPool.http.http2MaxRequests`.

Despite the field name, Istio defines `http2MaxRequests` as the maximum number of active requests for both HTTP/1.1 and HTTP/2. The expected Envoy overflow counter is `upstream_rq_active_overflow`; selected local/Azure revisions must verify this mapping before evidence promotion.

Compare:

- application-container CPU HPA
- sidecar saturation/rejection signal

HAProxy is a separate queue/admission/rate-limiting layer.

## P5.4 Local DoD

- normal E2E PASS
- healthy shared gate E2E PASS
- configured Envoy limit saturates
- official Envoy rejection signal observed
- no-retry vs bounded-retry attempt count differs as expected
- Forgejo/DB/node are not primary bottlenecks
- fixture removal returns to normal E2E

Do not add local KEDA controller until there is a concrete need. KEDA runtime integration is Azure P7 work; Local can validate manifests/metric contract first.

---

# 7. P3B — Azure calibration environment

**Paid, short-lived, explicit approval required.**

## Gate 1: Bootstrap/Foundation

Before apply:

- current Azure price estimate
- expected resource/RBAC inventory
- region/subscription preflight
- exact source commit
- user approval

DoD:

- bootstrap apply
- remote state read/write through authorized principal
- GitHub OIDC login without client secret
- foundation apply
- DNS zone outputs
- Key Vault RBAC allow/deny
- no subscription-wide CI privilege

## Gate 2: Environment

Preflight selects and records:

- supported AKS Kubernetes version
- managed Istio revision, **asm-1-30+**
- node SKU/quota
- PostgreSQL SKU
- managed observability dependencies

Then provision:

- AKS
- private PostgreSQL
- managed add-ons
- Argo Core bootstrap
- static public IP / HTTPS
- Forgejo stable platform

DoD:

- exact Argo targetRevision
- HTTPS Git/PR/Issue E2E
- no direct public Forgejo bypass
- node/Forgejo/DB headroom
- actual runtime/cost recorded

## Managed Istio ingress

Terraform creates static public IP.

Managed ingress Deployment/Service remains AKS-owned.

Explicit bootstrap:

- applies only supported Azure Load Balancer annotations needed to bind the managed gateway to the static IP
- installs/configures cert-manager when TLS work starts
- creates Azure DNS Workload Identity binding for cert-manager
- creates ACME `ClusterIssuer`
- creates the ingress `Certificate` in `aks-istio-ingress`

Argo manages `Gateway` / `VirtualService` routing objects, not the managed gateway Deployment or ingress TLS credential lifecycle.

The Istio `Gateway` `credentialName` must match the TLS Secret generated in `aks-istio-ingress`.

## Calibration cleanup

First Azure environment is not final evidence.

After sizing/compatibility work:

- environment destroy
- ephemeral-resource inventory
- orphan disk/IP/LB/monitoring check
- runtime/cost record

Foundation/bootstrap may intentionally remain for later sessions.

Paid `environment` resources are **same-day by default** and must be destroyed after the working/evidence session. A paid environment must not remain for more than **24 hours** unless the user explicitly approves an extension.

---

# 8. P4B — Azure operations verification

## Observability

Metrics:
developer probe, Forgejo, Istio/Envoy, HAProxy/ext-authz, HPA/KEDA, node/Kubernetes, PostgreSQL
→ Managed Prometheus / Grafana.

Logs → Log Analytics.

Mesh/ext-authz traces → OTel Collector → Application Insights.

Forgejo function-level tracing is not required.

## SLO baseline

Measure Service Active Window baseline first, then set thresholds with rationale.

SLIs:

- clone/fetch success + latency
- push success + latency
- PR create/read success + latency
- Issue create/read success + latency

Do not claim 24/7 monthly availability.

## Azure restore

Prefer a low-cost independent restore target:

- fresh database on the same PostgreSQL server when appropriate
- fresh namespace/PVC

Verify DB + app data + secret/version consistency, doctor, and E2E. Clean up the restore target.

## Upgrade/rollback

Run the state-aware upgrade/rollback contract once on Azure.

---

# 9. P6~P8 experiment progression

## P6 Cascade investigation

Scenario progression:

1. normal baseline
2. healthy shared gate
3. inbound Envoy request-limit saturation
4. application-container CPU HPA
5. bounded client retry
6. retry attempt increase + HAProxy/Envoy pressure

A valid run contains:

- **Developer impact:** success/latency
- **Mechanism:** attempts, Envoy rejection, HAProxy pressure, scaling
- **Confounder guard:** Forgejo, PostgreSQL, AKS nodes

If Forgejo/DB/node saturates first, do not promote the run.

## P7 Mitigation/recovery

Compare under the same workload/fault boundary:

- no retry
- bounded immediate retry
- exponential backoff + jitter
- HAProxy overload protection
- application-container CPU HPA
- Envoy metric → Managed Prometheus → managed KEDA

Do not call max-attempts alone a retry budget.

HPA and KEDA never control the same Deployment in the same scenario.

Recovery keeps demand running and measures the actual recovery criterion/time.

## P8 Critical/bulk isolation

Minimum redesign:

```text
authorization entry
      ↓
HAProxy classification
      ├── critical capacity pool
      └── bulk capacity pool
```

Both pools use the same ext-authz-sim image.

Synthetic traffic-class metadata is a LAB_IMPLEMENTATION and is not claimed as GitHub production routing.

DoD:

- bulk overload induced
- bulk degradation/shedding observed
- critical developer SLI measured separately
- same overload compared before/after isolation

No custom scheduler/fair-queueing Core scope.

---

# 10. P9 regression/final evidence

## Cost-free PR gate

General PRs do not create Azure resources.

Automate only what Local can reliably catch:

- normal developer regression
- version/config drift
- operation-attempt amplification bounds where deterministic
- unexpected Envoy rejection in normal profile
- experiment manifest/schema regression
- GitOps exact-revision regression

## Final Azure evidence

Freeze:

- exact source commit
- node topology
- component versions/digests
- scenario config
- observation windows

Preflight normal E2E and confounder guard first.

Default plan: **3 controlled repetitions** per final comparison. This does not imply statistical significance.

Published comparison:

- Baseline
- Cascade
- Mitigated
- Isolated

Common signals:

- developer SLI
- attempt amplification
- Envoy rejection
- HAProxy pressure
- scaling state
- Forgejo/DB/node health

## Finalization

After final evidence:

1. destroy environment
2. inventory ephemeral residuals
3. remove Gabia project-subdomain delegation
4. remove foundation identity/RBAC/resources
5. inspect Key Vault soft-delete/purge state
6. destroy foundation
7. decide whether state evidence must be exported
8. destroy bootstrap
9. final Azure resource inventory
10. final cost check

A successful `terraform destroy` alone is not “zero residual”.

---

# 11. Azure cost gates

| Gate | Action | Approval |
| --- | --- | --- |
| 0 | Local/static CI | automatic |
| 1 | Bootstrap/foundation apply | explicit |
| 2 | Calibration environment | explicit |
| 3 | Final evidence window | explicit |
| 4 | Environment destroy | explicit execution, expected after session |
| 5 | Project finalization | explicit |

Gate 1+ 실행 전 current pricing/resource estimate를 갱신한다.

Paid environment policy:

- environment runtime is same-day by default
- after a calibration/demo/evidence session, environment destroy is the expected next action
- an environment may remain up to 24 hours only to finish the same approved work
- staying beyond 24 hours requires a new explicit approval
- bootstrap/foundation can remain intentionally because their cost/lifecycle is evaluated separately

---

# 12. Work-unit Definition of Done

Lifecycle이 중요한 PR은 가능한 한 다음을 명시한다.

- **Prerequisite**
- **Change**
- **Verification**
- **Acceptance**
- **Cost impact**
- **Cleanup/Rollback**
- **Evidence**

작은 코드/문서 변경에는 형식적으로 강제하지 않는다.

---

# 13. 새 기술 추가 기준

다음 조건을 만족하지 않으면 Core에 새 technology/controller/service를 넣지 않는다.

1. 현재 설계로 해결할 수 없는 실제 문제가 관측됨
2. 새 component가 그 문제를 어떻게 해결하는지 설명 가능
3. 새 failure domain/운영비용을 검증할 방법이 있음
4. Core scope를 늘릴 가치가 있음

기본 Optional:

- Redis/Valkey
- Forgejo multi-replica
- separate GitOps repo
- Argo CD full UI/HA
- Elasticsearch/Meilisearch
- multi-region
- Backstage
- Kafka/RabbitMQ/Service Bus
- complex priority scheduler
- always-on public demo
