# Forgejo Platform Configuration

이 디렉터리는 upstream Forgejo Helm chart에 전달하는 source configuration만 저장한다. Rendered manifest는 Git에 저장하지 않는다.

## 현재 baseline

- Forgejo app: `15.0.9-rootless`
- Forgejo Helm chart: `17.1.1`
- replica: 1
- deployment strategy: `Recreate`
- Git transport: HTTPS only
- database: external PostgreSQL
- session: database provider
- cache: `twoqueue`
- queue: `level`
- repository code/PR/Issue만 Core에 사용
- Actions, Packages, mirroring, repository migration은 Core baseline에서 비활성화

Exact version inventory는 [../../versions.env](../../versions.env)를 함께 갱신한다.

## Secret contract

Source values에 credential을 넣지 않는다.

Local runtime에는 다음 Kubernetes Secret이 필요하다.

### `forgejo-database`

필수 key:

- `password`

같은 secret을 local PostgreSQL과 Forgejo database password에 사용한다. 이는 disposable local environment에만 해당한다. Azure에서는 Key Vault + Workload Identity 경로를 사용한다.

### `forgejo-admin`

필수 key:

- `username`
- `password`

Local runtime script가 disposable credential을 생성한다. Secret 값은 Git에 저장하지 않는다.

## 환경 분리

`values-common.yaml`에는 Local/Azure에서 동일해야 하는 Forgejo operating contract를 둔다.

`values-local.yaml`에는 local PostgreSQL address, local URL, local storage class처럼 환경 차이만 둔다.

Azure values는 Azure 구현 단계에서 실제 dependency가 생길 때 추가한다.
