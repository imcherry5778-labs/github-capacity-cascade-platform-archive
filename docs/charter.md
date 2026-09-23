# Project Charter

## 1. 목적

이 프로젝트는 GitHub의 2026년 8월 공개 장애 보고서에서 확인할 수 있는 **과부하 기반 cascading failure**의 failure class를 실제 developer platform에 적용해, 사용자 영향부터 진단·완화·복구·재발 방지까지 검증하는 SRE / Platform Engineering 포트폴리오다.

기존 `github-capacity-cascade-lab`은 failure mechanism을 작은 단위로 분해해 학습하고 검증한 research foundation이다. 이 저장소는 그 학습을 바탕으로 **운영 가능한 ephemeral developer platform**을 설계하고 운영하는 engineering case study다.

## 2. 핵심 질문

이 프로젝트는 다음 질문에 답해야 한다.

1. 개발자가 실제로 사용하는 Git/PR/Issue 작업이 정상 상태에서 안정적으로 동작하는가?
2. 공유된 필수 경로의 요청 처리 한계가 포화되면 사용자 영향이 어떻게 나타나는가?
3. retry가 동일한 사용자 수요를 더 많은 요청 시도로 증폭시키는가?
4. 애플리케이션 CPU만 보는 autoscaling이 proxy-side saturation을 놓칠 수 있는가?
5. 어떤 완화책이 어떤 trade-off를 만드는가?
6. 부하를 끄지 않은 상태에서도 recovery를 달성할 수 있는가?
7. critical developer traffic과 bulk/automation traffic을 분리하면 blast radius를 줄일 수 있는가?
8. 같은 failure class가 다시 도입되는 것을 CI/운영 검증에서 잡을 수 있는가?

## 3. 프로젝트 원칙

### Platform first

Forgejo 기반 developer platform이 주인공이다. Reliability experiment는 플랫폼의 신뢰성을 검증하기 위한 수단이다.

### 사용자 행동을 최상위 신호로 사용

Pod Ready, CPU, HTTP 200만으로 정상 여부를 판단하지 않는다. `git fetch/clone`, `git push`, Pull Request, Issue/API 같은 **developer operation**을 최상위 SLI로 사용한다.

### 정상 운영과 실험을 분리

정상 플랫폼과 reliability fixture의 lifecycle과 ownership을 분리한다.

- Stable platform: Argo CD가 desired state를 지속적으로 reconcile한다.
- Reliability fixture: experiment runner가 일시적으로 생성하고 제거한다.
- Experiment가 Argo CD 소유 리소스를 직접 수정하지 않는다.

### 공식 용어 우선

제품 공식 용어와 업계에서 통용되는 용어를 우선한다. 프로젝트 전용 용어가 필요하면 의미와 측정 경계를 `docs/terminology.md`에 정의한다.

### 재현성과 provenance

최종 evidence에는 정확한 source revision, component version, image digest, 환경 정보와 실험 조건을 기록한다. 결과가 가설과 다르더라도 valid run이면 숨기지 않는다.

### 필요한 만큼만 복잡하게

새 기술이나 controller는 이름값 때문에 도입하지 않는다. 해결하려는 문제와 검증 방법이 명확할 때만 추가한다.

## 4. Core 범위

### Developer platform

- Forgejo v15 LTS 계열의 exact patch를 검증 후 pin
- single Forgejo replica
- Azure Database for PostgreSQL Flexible Server
- persistent application data
- Istio ingress
- custom domain + HTTPS
- Argo CD Core 기반 reconciliation
- Azure Key Vault + Workload Identity + Secrets Store CSI
- Azure Managed Prometheus / Managed Grafana / Log Analytics / Application Insights
- GitHub Actions 기반 CI, build, IaC orchestration

### 운영

- developer-operation SLI/SLO
- alert와 dashboard
- backup 후 실제 restore drill
- upgrade와 state-aware rollback 검증
- 비용/teardown 검증
- runbook과 incident documentation

### Reliability experiment

- synthetic shared authorization gate
- HAProxy overload fixture
- Envoy request-concurrency limit
- application-CPU HPA와 proxy signal 기반 KEDA 비교
- retry amplification
- overload protection
- recovery under continuing demand
- critical/bulk traffic isolation

## 5. 범위 밖

Core에서는 다음을 구현하지 않는다.

- GitHub 내부 topology의 정확한 복제
- Forgejo 자체의 multi-replica HA
- multi-region / regional disaster recovery
- Actions runner platform
- SSH Git 경로
- Backstage 같은 developer portal
- 별도 Redis/Valkey 도입
- 모든 Kubernetes resource에 Kustomize 적용
- 모든 reliability fixture의 GitOps reconciliation
- 24/7 public hosting

필요성이 실제 측정이나 운영 요구로 확인되면 별도 ADR을 통해 재검토한다.

## 6. 환경 모델

### Local

k3d를 사용한다.

- 빠른 inner loop는 direct Helm/apply를 허용한다.
- GitOps integration test에서는 Argo CD Core를 반드시 거친다.
- Azure managed service는 기능적으로 동등한 local 대체 경로를 사용한다.

### Azure

단일 region의 ephemeral AKS 환경을 사용한다.

- 실제 Azure resource 생성은 명시적 승인 후에만 수행한다.
- public ingress만 외부에 노출한다.
- PostgreSQL과 내부 component는 private path를 사용한다.
- final evidence run은 exact Git commit SHA로 platform revision을 고정한다.

## 7. 완료 기준

프로젝트가 완료되려면 다음을 모두 만족해야 한다.

- local과 Azure에서 핵심 developer journey가 검증됨
- normal test와 reliability experiment가 명확히 분리됨
- developer SLI/SLO가 baseline 근거와 함께 정의됨
- capacity-cascade scenario의 user impact와 mechanism이 관측됨
- 동일한 fault/load 조건에서 mitigation을 비교함
- 부하를 지속한 상태에서 recovery를 검증함
- critical/bulk traffic isolation을 검증함
- backup → restore → doctor → developer E2E를 실제 수행함
- upgrade/rollback contract를 검증함
- final Azure environment를 teardown하고 project-owned residual resource가 없음을 확인함
- 최종 README의 주요 주장이 reviewed evidence로 추적 가능함

## 8. 표현 경계

이 프로젝트는 GitHub의 비공개 내부 구현을 재현한다고 주장하지 않는다.

- 공개 incident source에서 직접 확인한 사실은 source와 함께 기록한다.
- 공개 자료에 대한 해석은 해석임을 밝힌다.
- synthetic shared gate, HAProxy fixture, Envoy limit, load profile 등은 프로젝트가 선택한 실험 구현이다.
- 측정하지 않은 값을 결과처럼 표현하지 않는다.
