# Production Readiness Boundary

## 1. 목적

이 프로젝트는 **production-minded engineering**을 보여주지만 실제 production service라고 주장하지 않는다.

이 문서는 일반적인 production baseline과 의도적으로 다른 선택, 그 이유, production으로 확장할 때 다시 검토할 항목을 명시한다.

---

## 2. 의도적인 차이

| 영역 | 이 프로젝트 | Production에서 재검토할 것 |
| --- | --- | --- |
| Runtime | 필요한 세션에만 만드는 ephemeral Azure environment | 24/7 운영, on-call, 장기 SLO |
| Region | single region | multi-zone / regional DR |
| Forgejo | single replica, Recreate | upstream HA 성숙도와 multi-replica architecture |
| Queue | persistent `level` queue | external queue/cache, HA, queue telemetry |
| Cache | bounded `twoqueue` | workload 규모에 따른 external cache |
| Argo CD | Core/headless, non-HA | HA control plane, multi-cluster, tighter controller RBAC |
| Argo RBAC | upstream Core same-cluster controller privilege 수용 | namespace-scoped controller/RBAC redesign |
| AKS nodes | final evidence에서 fixed capacity | Cluster Autoscaler, redundancy |
| AKS API/network | enterprise perimeter 전체를 복제하지 않음 | private API, Firewall/NAT/egress policy |
| Terraform state endpoint | public endpoint + Entra ID auth | private endpoint / self-hosted runner |
| Key Vault network | RBAC 중심, private endpoint는 Core 아님 | private endpoint/firewall |
| Key Vault purge protection | Core에서 off | stronger deletion protection |
| Istio | AKS managed add-on, 1.30+ required | 조직 mesh support policy와 revision lifecycle |
| ext_authz provider | LAB_IMPLEMENTATION | 실제 authorization architecture |
| Public demo | short-lived | continuous hardening / abuse protection |
| Paid environment lifetime | same-day, max 24h without renewed approval | continuous capacity/cost management |

---

## 3. Forgejo

### Single replica

Forgejo single replica는 단순히 구현을 줄이기 위한 선택만은 아니다.

현재 upstream chart는 multi-replica 사용에 주의가 필요하다. 이 프로젝트는 HA를 억지로 흉내 내기보다 single-pod state lifecycle을 제대로 검증한다.

검증 대상:

- persistent repositories/application data
- Pod replacement
- session continuity
- coordinated backup/restore
- upgrade/rollback
- developer E2E

### Queue

Core는 Forgejo `level` queue를 persistent application data에 둔다.

Upstream chart는 LevelDB queue를 production에 권장하지 않는다는 warning을 출력한다. 이 프로젝트는 이 제약을 숨기지 않는다.

Core에서 external Redis/Valkey를 추가하지 않는 이유:

- Forgejo replica가 1
- 새로운 stateful dependency/failure domain이 생김
- 현재 developer journey에 반드시 필요한 개선임이 증명되지 않음

대신:

- queue persistence
- restart/restore behavior
- upgrade 시 queue handling

을 실제로 검증한다.

외부 queue/cache가 필요한 evidence가 생기면 별도 ADR을 연다.

---

## 4. Managed PostgreSQL

작은 Forgejo는 SQLite로도 운영할 수 있다.

Azure PostgreSQL을 선택한 것은 Forgejo 요구사항이 아니라 다음 project goal 때문이다.

- AKS lifecycle과 DB state 분리
- private networking
- managed backup/PITR
- Cloud/Platform operating contract

Managed DB 사용을 Forgejo 전체 recoverability라고 표현하지 않는다.

전체 restore는 PostgreSQL + repository/application data + persistent secrets/version을 함께 다룬다.

---

## 5. GitOps

Argo CD 사용 자체를 production-readiness의 증거로 삼지 않는다.

검증 대상:

- desired/live state comparison
- exact source revision
- drift detection
- self-heal
- ownership boundary

### Argo controller privilege

현재 Argo CD Core same-cluster 설치는 controller에 넓은 Kubernetes 권한을 가질 수 있다.

`AppProject`가 `platform` namespace와 source repo를 제한하더라도 이것이 controller ServiceAccount 자체를 namespace-only로 만드는 것은 아니다.

이 프로젝트는:

- single operator
- one ephemeral cluster
- no Argo UI/API public exposure
- managed add-on controller를 Argo에서 제외

라는 조건에서 이 privilege를 수용한다.

Production으로 확장하면 controller RBAC, namespace-scoped deployment model, multi-tenancy를 별도로 재설계해야 한다.

---

## 6. Service mesh

Azure에서는 AKS managed Istio add-on을 우선한다.

장점:

- AKS lifecycle compatibility
- control-plane lifecycle 축소
- Azure monitoring integration
- 직접 운영하는 cluster-scoped component 감소

### Required capability

Reliability fixture의 `Sidecar.inboundConnectionPool`은 Istio 1.30+가 필요하다.

따라서 Azure selected revision은 `asm-1-30` 이상이어야 하며 실제 region/AKS support preflight에서 확인한다.

### Support boundary

Project-specific external authorization provider와 custom experiment policy가 Azure support boundary 전체에 포함된다고 가정하지 않는다.

Selected revision에서:

- extension provider
- CUSTOM AuthorizationPolicy
- inbound connection pool
- Envoy metric

을 직접 preflight한다.

필수 기능이 막힌 경우에만 self-managed Istio를 fallback ADR로 검토한다.

---

## 7. Managed KEDA

Azure에서는 AKS managed KEDA add-on을 사용한다.

KEDA 자체를 portfolio keyword로 넣는 것이 목표가 아니다.

검증 대상은:

```text
Envoy capacity signal
→ Azure Managed Prometheus
→ KEDA Prometheus scaler
→ ext-authz-sim replica
```

이다.

HPA/KEDA 비교 중에는 두 controller가 같은 Deployment를 동시에 제어하지 않는다.

---

## 8. Secrets

Core baseline:

- no committed secret
- GitHub → Azure OIDC
- Workload Identity
- Key Vault
- Secrets Store CSI
- scoped RBAC

### Ingress TLS credential

Public ingress TLS and persistent Forgejo application secrets have different lifecycles.

Core ingress TLS:

```text
cert-manager
→ ACME DNS-01
→ Azure DNS via Workload Identity
→ ClusterIssuer
→ Certificate in aks-istio-ingress
→ renewable Kubernetes TLS Secret
→ managed Istio ingress gateway
```

AKS managed Istio expects the ingress credential Secret in `aks-istio-ingress`. Therefore this Certificate/Secret lifecycle is explicit cluster bootstrap scope, not the Argo `platform` AppProject.

Core does not introduce a separate ACME-to-Key-Vault certificate synchronization pipeline merely to put the public certificate in Key Vault.

Persistent Forgejo cryptographic/database secret material remains a Key Vault + Workload Identity + CSI concern.

### Key Vault network

Core에서 private endpoint를 넣지 않는 이유는 GitHub-hosted runner와 ephemeral 운영 모델을 단순하게 유지하기 위해서다.

Secret data 자체는 public anonymous access가 아니라 Entra ID/RBAC를 사용한다.

### Purge protection

Core는 final teardown 검증이 중요한 portfolio environment이므로 purge protection을 기본적으로 켜지 않는다.

Soft delete 상태는 final inventory에 포함하며 프로젝트 완전 종료 시 필요하면 명시적으로 purge한다.

Production에서는 stronger deletion protection을 재검토해야 한다.

---

## 9. Terraform / CI identity

CI identity에 subscription-wide Owner/Contributor를 기본으로 주지 않는다.

Bootstrap이:

- state scope
- foundation RG
- environment RG

를 미리 만들고, CI identity는 이 scope 안에서만 resource/RBAC를 관리하도록 설계한다.

Bootstrap/final teardown은 local operator가 수행하는 것을 기본으로 한다.

Production에서는 별도 privileged deployment identity, approval workflow, policy-as-code 등을 재검토할 수 있다.

---

## 10. Availability와 SLO

Environment가 의도적으로 꺼져 있는 시간을 outage로 계산하지 않는다.

`Service Active Window`에서 developer-operation SLI를 측정한다.

따라서 결과를 일반적인 99.9% monthly production availability와 직접 비교하지 않는다.

---

## 11. Evidence topology

Final evidence에서는 재현성을 위해 node capacity를 고정한다.

이는 production autoscaling best practice를 부정하는 것이 아니다.

```text
Pod scaling policy = experiment variable
Node capacity       = controlled condition
```

로 분리하기 위한 experimental design이다.

---

## 12. Completion wording

최종 README에서 허용:

- production-minded
- production constraints considered
- controlled reliability experiment
- actual restore verified
- exact environment recorded

피함:

- production-ready
- GitHub outage reproduced exactly
- statistically proven
- HA Forgejo
- zero residual (cloud inventory 확인 전)
