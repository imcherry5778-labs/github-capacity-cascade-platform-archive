# Forgejo Platform Configuration

이 디렉터리는 upstream Forgejo Helm chart에 전달하는 source configuration만 저장한다. Rendered manifest는 Git에 저장하지 않는다.

## 현재 baseline

- Forgejo app: `15.0.9-rootless`
- Forgejo Helm chart: `17.1.1`
- replica: 1
- deployment strategy: `Recreate`
- SSH Git disabled; Azure Core는 HTTPS Git만 허용
- Local E2E는 port-forward된 HTTP endpoint를 개발용 예외로 사용
- database: external PostgreSQL
- session: database provider
- cache: `twoqueue`
- queue: `level`
- 새 repository의 기본 unit을 code / releases / issues / pull requests로 명시
- repository code/PR/Issue를 Core developer journey에 사용
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

## Local runtime 확인

Fresh local lifecycle 전체를 확인하려면:

```bash
make local-verify
```

이 명령은 다음 순서로 동작한다.

1. k3d cluster 생성
2. 기본 kubeconfig를 수정하지 않는 별도 local kubeconfig 생성
3. disposable database/admin Secret 생성
4. PostgreSQL 배포와 readiness 확인
5. Forgejo Helm release 배포
6. `/api/healthz`와 `/api/v1/version` smoke
7. local cluster 삭제

실패한 경우 Pod와 Kubernetes event를 출력한 뒤 cleanup을 시도한다.

개발 중 cluster를 유지하려면 `make local-up` → `make local-smoke`를 사용하고 마지막에 `make local-down`을 실행한다.

## Developer journey E2E

`make local-e2e`는 실행 중인 local platform에서 Forgejo native authentication/authorization을 사용해 다음 developer operation을 검증한다.

1. 일반 developer user와 private repository 생성
2. Personal Access Token으로 `git push`
3. authenticated `git clone` / `git fetch`
4. feature branch push
5. Pull Request create/read
6. Issue create/read

Git Smart HTTP의 개별 request 수를 developer operation 수와 동일하게 취급하지 않는다. 이 E2E의 목적은 정상 platform에서 상위 developer journey가 성공하는지 확인하는 것이다.

`make local-verify`는 fresh cluster에서 smoke 후 이 E2E까지 실행하고 cleanup한다.
