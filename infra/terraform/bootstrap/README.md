# Terraform Bootstrap

이 stack은 프로젝트의 **Terraform state와 Azure CI trust boundary**를 만든다. Remote state 저장소 자체를 생성해야 하므로 프로젝트에서 유일하게 local Terraform state를 허용한다.

## 생성 대상

- Terraform state 전용 Resource Group
- Standard LRS Storage Account
- private Blob Container
- Blob versioning
- blob/container soft delete 7일
- foundation Resource Group
- environment Resource Group
- GitHub Actions용 user-assigned managed identity
- GitHub Environment `azure`용 federated identity credential
- CI identity의 project-scoped Azure RBAC

Storage Account는 Shared Key를 비활성화하고 Microsoft Entra ID 인증을 기본으로 사용한다.

GitHub-hosted runner에서 향후 remote state에 접근해야 하므로 Storage public network endpoint는 Core에서 유지한다. 이는 blob container를 public으로 공개한다는 의미가 아니다. Container access level은 `private`이다.

## GitHub Actions OIDC

CI는 long-lived Azure client secret을 사용하지 않는다.

현재 federated credential은 GitHub.com의 immutable OIDC subject 형식과 이 repository의 immutable owner/repository ID를 사용한다.

```text
issuer   = https://token.actions.githubusercontent.com
subject  = repo:imcherry5778-labs@273613742/github-capacity-cascade-platform@1377253823:environment:azure
audience = api://AzureADTokenExchange
```

GitHub workflow job은 `environment: azure`를 사용해야 이 subject와 일치한다.

Repository rename/transfer 또는 OIDC customization 변경은 subject를 바꿀 수 있다. 실제 P3B apply 전에 GitHub OIDC preview/settings에서 현재 subject가 source와 정확히 일치하는지 다시 확인한다.

## CI identity RBAC

CI identity에는 다음 scope만 부여한다.

| Scope | Role | 목적 |
| --- | --- | --- |
| state blob container | `Storage Blob Data Contributor` | foundation/environment remote state read/write |
| foundation Resource Group | `Contributor` | foundation resource lifecycle |
| foundation Resource Group | `Role Based Access Control Administrator` | foundation RG 내부 role assignment lifecycle |
| environment Resource Group | `Contributor` | environment resource lifecycle |
| environment Resource Group | `Role Based Access Control Administrator` | environment RG 내부 role assignment lifecycle |

`Role Based Access Control Administrator`는 privileged role이므로 project-owned Resource Group 밖으로 scope를 넓히지 않는다.

기본 contract에서 CI identity에 subscription-wide `Owner`, `Contributor`, `User Access Administrator`를 부여하지 않는다. Custom role이나 RBAC condition도 실제 필요가 확인되기 전에는 추가하지 않는다.

## 사전 조건

실제 apply 전에는 다음을 확인해야 한다.

1. Azure CLI로 올바른 subscription에 로그인했는가?
2. `Microsoft.Storage`, `Microsoft.ManagedIdentity`, `Microsoft.Authorization` 등 필요한 Resource Provider가 등록되어 있는가?
3. local operator가 project Resource Group 생성과 해당 scope role assignment 생성에 필요한 권한을 가지고 있는가?
4. `storage_account_name`이 전역에서 사용 가능한 고유 이름인가?
5. GitHub OIDC subject가 현재 repository/environment contract와 일치하는가?
6. 예상되는 생성 resource/RBAC와 비용을 확인했는가?
7. 사용자가 명시적으로 Azure apply를 승인했는가?

Provider의 automatic Resource Provider registration은 사용하지 않는다. Subscription-level 변경을 Terraform provider가 암묵적으로 만들지 않게 하기 위해서다.

## 검증

이 단계의 CI는 Azure에 로그인하지 않는다.

```bash
terraform fmt -check -recursive infra/terraform
terraform -chdir=infra/terraform/bootstrap init -backend=false -lockfile=readonly
terraform -chdir=infra/terraform/bootstrap validate
```

따라서 PR 검증은 **Azure resource를 생성하지 않는다**.

## 실제 apply

실제 Azure apply는 자동 PR workflow에 넣지 않는다. 명시적 승인을 받은 뒤 P3B Gate 1에서 별도 lifecycle로 수행한다.

예시 입력:

```bash
terraform -chdir=infra/terraform/bootstrap apply \
  -var='storage_account_name=<globally-unique-name>'
```

Storage Account의 실제 이름은 source에 하드코딩하지 않는다.

## 다음 stack과의 관계

Bootstrap 성공 후 foundation/environment stack은 bootstrap이 만든 Resource Group을 입력/reference로 사용한다. 각 stack이 자기 Resource Group을 새로 만들지 않는다.

```text
bootstrap
├── Azure Blob state backend
│   ├── foundation.tfstate
│   └── environment.tfstate
├── foundation Resource Group
└── environment Resource Group
```

Foundation/environment는 별도의 state lifecycle을 가진다.

## 복구

Local bootstrap state를 잃었다고 기존 Azure resource를 새로 만들지 않는다. Existing resource를 확인한 뒤 `terraform import`로 bootstrap state를 복구한다.

## 최종 종료

프로젝트를 완전히 archive할 때는:

1. environment destroy
2. foundation destroy
3. 가비아 DNS delegation 등 외부 연결 정리
4. foundation/environment scope의 CI RBAC 정리
5. GitHub Actions federated credential / CI identity 정리
6. bootstrap resource/state 보존 필요성 최종 확인
7. bootstrap destroy
8. project-owned Azure resource가 남지 않았는지 확인

순서를 따른다.
