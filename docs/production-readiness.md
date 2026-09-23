# Production Readiness Boundary

## 1. 목적

이 프로젝트는 **production-minded engineering**을 보여주지만 실제 production service라고 주장하지 않는다.

여기서는 일반적인 production baseline과 의도적으로 다른 선택을 명시한다.

---

## 2. 의도적인 차이

| 영역 | 이 프로젝트 | Production에서 재검토할 것 |
| --- | --- | --- |
| Runtime | 필요할 때 만드는 ephemeral environment | 24/7 운영, on-call, 장기 SLO |
| Region | single region | multi-zone / regional DR |
| Forgejo | single replica, Recreate | upstream HA 성숙도와 multi-replica architecture |
| Queue | local `level` queue on persistent data | external queue/cache와 HA 요구 |
| Cache | bounded `twoqueue` | workload 규모에 따른 external cache |
| Argo CD | Core/headless, non-HA | HA control plane / multi-cluster |
| AKS nodes | controlled fixed capacity during evidence | production Cluster Autoscaler / larger redundancy |
| System pool | portfolio-sized topology | production redundancy baseline |
| AKS API/network | Core에서는 enterprise perimeter 전체를 복제하지 않음 | private API, Firewall, NAT, egress controls |
| Terraform state endpoint | public endpoint + Entra auth | private endpoint/self-hosted runner 필요성 |
| Key Vault network | RBAC 중심, private endpoint는 Core 아님 | private endpoint/firewall |
| Key Vault purge protection | Core에서 off | production에서는 보통 stronger deletion protection |
| Istio | AKS managed add-on 우선 | support boundary와 조직 운영정책 |
| ext_authz provider | LAB_IMPLEMENTATION | 실제 auth/policy architecture |
| Public demo | short-lived | continuous service hardening |

---

## 3. Forgejo

Single replica는 단순화를 위한 임의 선택만은 아니다.

현재 프로젝트는 upstream chart의 HA 제약을 받아들이고, multi-replica를 억지로 production처럼 보이게 만들지 않는다.

대신 다음을 실제로 검증한다.

- persistent state
- Pod replacement
- backup/restore
- upgrade/rollback
- developer E2E

---

## 4. Managed PostgreSQL

작은 Forgejo는 SQLite로도 운영할 수 있다.

Azure PostgreSQL을 선택한 것은 Forgejo 요구사항이 아니라 다음 project goal 때문이다.

- AKS lifecycle과 DB state 분리
- private networking
- managed backup/PITR
- Cloud/Platform operating contract

Managed DB 사용을 곧바로 Forgejo 전체 recoverability라고 표현하지 않는다.

---

## 5. GitOps

Argo CD 사용 자체를 production-readiness의 증거로 삼지 않는다.

검증 대상은:

- desired/live state 비교
- drift detection
- self-heal
- exact revision
- ownership boundary

Cluster-scoped controller를 모두 Argo CD에 넣지 않는다. Least-privilege AppProject를 유지하는 것을 더 중요하게 본다.

---

## 6. Service mesh

Azure에서는 AKS managed Istio add-on을 우선한다.

장점:

- AKS compatibility
- managed control-plane lifecycle
- Azure Managed Prometheus integration
- cluster-scoped Istio lifecycle 축소

단, project-specific external authorization provider는 Azure support boundary 밖일 수 있다.

따라서 managed add-on을 사용한다는 이유로 실험 기능이 검증됐다고 가정하지 않는다. Selected revision에서 capability preflight를 통과해야 한다.

---

## 7. Availability와 SLO

Environment가 의도적으로 꺼져 있는 시간을 월간 outage로 계산하지 않는다.

`Service Active Window`에서 developer-operation SLI를 측정한다.

따라서 이 프로젝트 결과를 일반적인 99.9% monthly production availability와 직접 비교하지 않는다.

---

## 8. Security

Core에서 유지하는 baseline:

- no committed secrets
- GitHub → Azure OIDC
- Workload Identity
- scoped Azure RBAC
- Key Vault runtime secret path
- GitHub Action full SHA pin
- dependency/provider lock
- public ingress only
- PostgreSQL private access

다만 enterprise perimeter 전체를 복제하지 않는다.

---

## 9. Evidence topology

Final evidence에서는 재현성을 위해 node capacity를 고정한다.

이것은 production autoscaling best practice를 부정하는 것이 아니다.

실험 중:

```text
Pod scaling policy = experiment variable
Node capacity       = controlled condition
```

로 분리하기 위한 연구 설계다.

---

## 10. Completion wording

최종 README에서는 다음 표현을 구분한다.

허용:

- production-minded
- production constraints considered
- controlled reliability experiment
- actual restore verified
- exact environment recorded

피함:

- production-ready
- GitHub outage reproduced exactly
- statistically proven (반복 횟수만으로)
- HA Forgejo (single replica 상태에서)
- zero residual (cloud inventory 확인 전)
