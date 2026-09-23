# AGENTS.md

이 저장소는 SRE / Platform Engineering 포트폴리오 프로젝트다. 작업자는 기능을 많이 추가하는 것보다 **검증 가능한 최소 변경**을 우선한다.

## 1. 기본 원칙

- 한 번에 하나의 작은 목적을 해결한다.
- 새 tool/controller/service는 실제 문제가 확인되기 전에 추가하지 않는다.
- 빈 abstraction, 미래용 module, placeholder directory를 미리 만들지 않는다.
- 구현 전에 관련 upstream 문서와 현재 pinned version의 실제 동작을 확인한다.
- 구현 순서와 acceptance는 `docs/implementation-plan.md`를 따른다. 명세에 없는 새 capability를 먼저 구현하지 않는다.
- 측정하지 않은 값을 결과처럼 작성하지 않는다.
- GitHub의 비공개 architecture나 설정을 추정해 사실처럼 쓰지 않는다.

## 2. 문서와 용어

- 사람 대상 문서는 한국어를 기본으로 한다.
- 제품명, API, metric, CLI, code identifier, 파일 경로는 공식 영어를 유지한다.
- `docs/conventions.md`와 `docs/terminology.md`를 따른다.
- 제품 공식 용어가 있으면 임의의 기술 약칭을 만들지 않는다.
- project term을 새로 만들면 의미와 측정 경계를 문서화한다.
- `operation`, `attempt`, `HTTP request`, `authorization check`, `upstream request`를 혼용하지 않는다.

## 3. Git

- branch 이름은 영어로 작성한다.
- commit/PR title은 `<type>(<scope>): <한글 설명>` 형식을 따른다.
- main에 직접 구현 변경을 쌓지 않는다.
- PR-gated change management를 사용한다.
- 한 PR은 가능한 한 하나의 목적을 가진다.

## 4. Source of truth

Git에는 authoritative source configuration만 저장한다.

저장:

- Go source
- Terraform
- Helm source/values
- 필요한 plain YAML
- test / experiment definition
- reviewed evidence
- 문서

저장하지 않음:

- Terraform state
- secret/credential
- kubeconfig
- generated vendor manifest
- 대용량 raw telemetry
- local temporary file

Rendered manifest는 CI에서 생성하고 검증한다.

## 5. Version과 dependency

- container, Helm chart, Terraform provider, GitHub Action version은 reproducibility를 고려해 pin한다.
- final evidence에는 실제 runtime version과 image digest를 기록한다.
- floating version을 evidence run에 사용하지 않는다.
- third-party GitHub Action은 가능한 경우 full commit SHA pin을 사용한다.

## 6. Stable platform과 experiment ownership

Argo CD가 소유하는 stable platform과 experiment runner가 소유하는 temporary resource를 섞지 않는다.

Argo CD 기본 scope:

- Forgejo
- namespaced Istio routing object
- Forgejo workload ServiceAccount / SecretProviderClass
- namespaced telemetry config

Azure managed / explicit bootstrap scope:

- AKS managed Istio/KEDA/Key Vault CSI
- managed Istio ingress Deployment/Service
- Argo CD Core 자체
- cert-manager controller
- Azure DNS Workload Identity 기반 ClusterIssuer
- `aks-istio-ingress` ingress Certificate/TLS Secret lifecycle
- shared Istio MeshConfig

AppProject 제한이 Argo controller ServiceAccount 자체의 Kubernetes RBAC를 제한한다고 가정하지 않는다.

Experiment scope:

- synthetic shared gate
- HAProxy
- ext-authz-sim
- temporary authorization policy
- experiment HPA / ScaledObject
- fault/load resource

Experiment는 Argo CD가 소유하는 resource를 직접 mutation하지 않는다.

## 7. Tests before experiments

Reliability experiment 전에 관련 정상 test가 통과해야 한다.

최소 preflight:

- Forgejo healthy
- PostgreSQL reachable/healthy
- expected Argo applications Synced/Healthy
- clone/fetch
- push
- PR operation
- Issue/API operation

실험 중 node, Forgejo, DB 같은 confounder가 primary bottleneck이 되면 결과를 성공 evidence로 승격하지 않는다.

## 8. Evidence

- raw run은 append-only로 취급한다.
- 실패/negative result를 성공처럼 수정하지 않는다.
- valid run과 hypothesis support를 구분한다.
- final evidence run은 exact source commit을 기록한다.
- secret, private path, credential을 evidence에 넣지 않는다.
- reviewed evidence는 판정과 재검토에 필요한 최소 파일만 Git에 저장한다.

## 9. Azure safety

- 실제 Azure provision/destroy는 명시적 사용자 승인 없이 실행하지 않는다.
- PAYG 비용을 사용한다는 사실을 전제로 한다.
- Azure 실제 provision 전에 cost/resource/RBAC preflight를 수행한다.
- Local operations/reliability work를 완료하기 전 Azure를 장기 개발 환경처럼 유지하지 않는다.
- 유료 environment는 same-day destroy가 기본이며 24시간을 넘겨 유지하려면 새 명시적 승인을 받는다.
- evidence run에서 node SKU/count는 임의로 변경하지 않는다.
- cost 절감을 위해 의도하지 않은 bottleneck을 만들지 않는다.
- destroy 후 project-owned residual resource를 확인한다.
- project finalization에서는 DNS delegation/identity/state backend까지 별도 절차로 정리한다.

## 10. Secret과 identity

- long-lived Azure client secret을 Git/GitHub Secret에 저장하는 방향을 기본값으로 사용하지 않는다.
- GitHub Actions → Azure는 OIDC federation을 우선한다.
- persistent workload secret은 Azure Key Vault + Workload Identity 경로를 우선한다.
- experiment-only secret은 ephemeral Kubernetes Secret을 사용할 수 있다.

## 11. 구현 전 확인이 필요한 값

다음은 문서에 임의의 숫자를 박지 않는다.

- Azure node SKU/count
- SLO threshold
- KEDA threshold
- exact resource request/limit
- log/trace sampling rate
- Forgejo exact patch/image digest
- Azure AKS exact Kubernetes patch
- Azure managed Istio exact revision (`asm-1-30` 이상 requirement는 유지)

필요한 baseline 또는 upstream 검증 후 결정한다.

## 12. 완료 주장

`pass`, `verified`, `reproduced`, `restored`, `zero residual` 같은 표현은 실제 command/test/evidence를 확인한 뒤에만 사용한다.
