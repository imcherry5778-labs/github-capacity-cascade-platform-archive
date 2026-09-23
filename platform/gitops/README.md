# Argo CD GitOps Baseline

이 디렉터리는 stable platform의 Argo CD source contract를 저장한다.

## 현재 범위

P2 첫 단계에서는 local PostgreSQL만 Argo CD가 reconcile한다.

- Argo CD Core 사용
- public monorepo를 source로 사용
- `capacity-platform` AppProject로 source/destination/resource kind 제한
- automated sync 활성화
- self-heal 활성화
- automatic prune 비활성화
- reliability experiment resource는 이 project/application 범위에 포함하지 않음

Forgejo는 아직 direct Helm deployment를 유지한다. PostgreSQL reconciliation이 검증된 다음 작은 변경에서 Forgejo ownership을 Argo CD로 이전한다.

## Revision policy

Repository source에는 기본 `targetRevision: main`을 둔다.

GitOps integration test에서는 push된 exact commit SHA를 runtime에서 주입한다. Local working tree의 아직 push되지 않은 commit을 Argo CD가 읽을 수 있다고 가정하지 않는다.

Final Azure evidence에서는 같은 원칙으로 exact source commit을 사용한다.

## Reconciliation test

`make gitops-verify`는 다음을 확인한다.

1. fresh local platform 생성
2. pinned Argo CD Core 설치
3. PostgreSQL Application이 `Synced / Healthy`인지 확인
4. self-heal을 잠시 끄고 PostgreSQL Service에 controlled drift 생성
5. Application이 `OutOfSync`를 탐지하는지 확인
6. self-heal을 다시 켜 desired state가 복구되는지 확인
7. Forgejo health smoke 재확인
8. cluster cleanup

이 검증은 reliability experiment가 아니라 stable platform의 infrastructure test다.
