# GitOps

이 디렉터리는 Argo CD가 관리하는 **stable platform desired state**를 정의한다.

## Core 계약

- Argo CD Core를 사용한다.
- Web UI/API server는 Core 범위에 넣지 않는다.
- `platform/`의 stable workload만 Argo CD가 관리한다.
- reliability experiment fixture는 Argo CD scope 밖에 둔다.
- automated sync와 self-heal을 사용한다.
- automatic prune은 사용하지 않는다.
- final evidence에서는 exact Git commit SHA를 `targetRevision`으로 사용한다.

## Forgejo Application

Forgejo 자체 chart를 복사하지 않는다.

Argo CD multiple sources를 사용해:

1. upstream Forgejo OCI Helm chart
2. 이 repository의 `platform/forgejo/values-common.yaml`
3. 환경별 values

를 결합한다.

Local GitOps integration에서는 `values-local.yaml`을 사용한다.

`forgejo-application.yaml.tmpl`의 `__TARGET_REVISION__`은 검증 script가 실제 remote Git SHA로 치환한다. Local fast inner loop의 direct Helm path와 GitOps integration path는 의도적으로 분리한다.

## Ownership

Argo CD가 관리:

- Forgejo Deployment/Service/PVC 등 chart가 생성하는 stable resource

Argo CD가 관리하지 않음:

- local PostgreSQL substitute
- disposable local Secret
- reliability experiment fixture
- fault/load resource
