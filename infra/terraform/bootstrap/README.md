# Terraform Bootstrap

이 stack은 **Terraform remote state 저장소와 GitHub Actions의 Azure OIDC trust 기반**을 만든다. 이 때문에 프로젝트에서 유일하게 local Terraform state를 허용한다.

아직 이 stack 자체를 Azure에 apply하지 않았다. 실제 apply는 사용자의 명시적 승인 이후에만 수행한다.

## 생성 대상

- bootstrap 전용 Resource Group
- Standard LRS Storage Account
- private Blob Container
- Blob versioning
- blob/container soft delete 7일
- GitHub Actions용 user-assigned managed identity
- GitHub OIDC federated identity credential
- state Storage Account 범위의 `Storage Blob Data Contributor`

Storage Account는 Shared Key를 비활성화하고 Microsoft Entra ID 인증을 기본으로 사용한다.

GitHub-hosted runner에서 향후 remote state에 접근해야 하므로 Storage public network endpoint는 Core에서 유지한다. 이는 blob container를 public으로 공개한다는 의미가 아니다. Container access level은 `private`이다.

## GitHub OIDC trust

이 repository는 2026-07-15 이후 생성되어 immutable GitHub OIDC subject 형식을 사용한다.

현재 trust subject:

```text
repo:imcherry5778-labs@273613742/github-capacity-cascade-platform@1377253823:environment:azure-demo
```

이 값은 다음 두 경계를 동시에 고정한다.

- owner/repository name + immutable GitHub IDs
- GitHub Environment `azure-demo`

Azure federated credential은 issuer `https://token.actions.githubusercontent.com`, audience `api://AzureADTokenExchange`를 사용한다.

### 현재 authorization 범위

Deployment identity가 이 단계에서 받는 Azure RBAC는 state Storage Account의:

```text
Storage Blob Data Contributor
```

뿐이다.

Subscription-wide `Contributor`나 privileged RBAC role은 bootstrap 편의를 위해 미리 부여하지 않는다. Foundation/environment 배포에 실제 필요한 scope가 정해진 뒤 별도 변경으로 추가한다.

## GitHub Environment

`azure-demo` environment는 workflow가 암묵적으로 생성하게 두지 않는다.

Azure apply workflow를 추가하기 전에 repository Settings에서 environment를 명시적으로 만들고 protection rule을 검토한다.

향후 workflow에서 Azure OIDC token을 요청하는 job은:

```yaml
environment: azure-demo

permissions:
  id-token: write
  contents: read
```

경계를 사용한다.

Client ID, Tenant ID, Subscription ID는 credential secret이 아니다. 실제 workflow wiring 방식은 apply workflow를 추가할 때 별도로 결정한다. Long-lived Azure client secret은 사용하지 않는다.

## 사전 조건

실제 bootstrap apply 전에는 다음을 확인해야 한다.

1. Azure CLI로 올바른 subscription에 로그인했는가?
2. `Microsoft.Storage`와 `Microsoft.ManagedIdentity` Resource Provider가 등록되어 있는가?
3. 실행 사용자가 bootstrap resource와 RBAC assignment를 만들 권한이 있는가?
4. `storage_account_name`이 전역에서 사용 가능한 고유 이름인가?
5. GitHub repository ID / owner ID / `azure-demo` environment 이름이 trust subject와 일치하는가?
6. 예상되는 생성 리소스와 비용을 확인했는가?
7. 사용자가 명시적으로 Azure apply를 승인했는가?

Provider의 automatic Resource Provider registration은 사용하지 않는다. Subscription-level 변경을 Terraform provider가 암묵적으로 만들지 않게 하기 위해서다.

## 검증

PR CI는 Azure에 로그인하지 않는다.

```bash
terraform fmt -check -recursive infra/terraform
terraform -chdir=infra/terraform/bootstrap init -backend=false -lockfile=readonly
terraform -chdir=infra/terraform/bootstrap validate
```

따라서 PR 검증은 **Azure resource를 생성하지 않는다**.

## 실제 apply

실제 Azure apply는 자동 PR workflow에 넣지 않는다. 명시적 승인을 받은 뒤 별도 lifecycle에서 수행한다.

예시 입력:

```bash
terraform -chdir=infra/terraform/bootstrap apply \
  -var='storage_account_name=<globally-unique-name>'
```

실제 Storage Account 이름은 source에 하드코딩하지 않는다.

## 다음 stack과의 관계

Bootstrap 성공 후:

```text
bootstrap
├── Azure Blob state backend
│   ├── foundation.tfstate
│   └── environment.tfstate
└── GitHub deployment identity
    └── state backend access only
```

Foundation/environment는 별도의 state lifecycle을 가진다.

## 복구

Local bootstrap state를 잃었다고 기존 Azure resource를 새로 만들지 않는다. Existing resource를 확인한 뒤 `terraform import`로 bootstrap state를 복구한다.

## 최종 종료

프로젝트를 완전히 archive할 때는:

1. environment destroy
2. foundation destroy
3. 가비아 DNS delegation 등 외부 연결 정리
4. GitHub Environment/deployment variables 정리
5. bootstrap resource/state 보존 필요성 최종 확인
6. OIDC federated credential / managed identity / state backend destroy
7. project-owned Azure resource가 남지 않았는지 확인

순서를 따른다.
