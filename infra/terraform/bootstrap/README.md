# Terraform Bootstrap

이 stack은 **Terraform remote state 저장소 자체**를 만든다. 이 때문에 프로젝트에서 유일하게 local Terraform state를 허용한다.

## 생성 대상

- Terraform state 전용 Resource Group
- Standard LRS Storage Account
- private Blob Container
- Blob versioning
- blob/container soft delete 7일

Storage Account는 Shared Key를 비활성화하고 Microsoft Entra ID 인증을 기본으로 사용한다.

GitHub-hosted runner에서 향후 remote state에 접근해야 하므로 Storage public network endpoint는 Core에서 유지한다. 이는 blob container를 public으로 공개한다는 의미가 아니다. Container access level은 `private`이다.

## 사전 조건

실제 apply 전에는 다음을 확인해야 한다.

1. Azure CLI로 올바른 subscription에 로그인했는가?
2. `Microsoft.Storage` Resource Provider가 등록되어 있는가?
3. `storage_account_name`이 전역에서 사용 가능한 고유 이름인가?
4. 예상되는 생성 리소스와 비용을 확인했는가?
5. 사용자가 명시적으로 Azure apply를 승인했는가?

Provider의 automatic Resource Provider registration은 사용하지 않는다. Subscription-level 변경을 Terraform provider가 암묵적으로 만들지 않게 하기 위해서다.

## 검증

이 단계의 CI는 Azure에 로그인하지 않는다.

```bash
terraform fmt -check -recursive infra/terraform
terraform -chdir=infra/terraform/bootstrap init -backend=false
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

실제 이름은 source에 하드코딩하지 않는다.

## 다음 stack과의 관계

Bootstrap 성공 후:

```text
bootstrap
  └── Azure Blob state backend
        ├── foundation.tfstate
        └── environment.tfstate
```

Foundation/environment는 별도의 state lifecycle을 가진다.

## 복구

Local bootstrap state를 잃었다고 기존 Azure resource를 새로 만들지 않는다. Existing resource를 확인한 뒤 `terraform import`로 bootstrap state를 복구한다.

## 최종 종료

프로젝트를 완전히 archive할 때는:

1. environment destroy
2. foundation destroy
3. 가비아 DNS delegation 등 외부 연결 정리
4. bootstrap resource/state 보존 필요성 최종 확인
5. bootstrap destroy
6. project-owned Azure resource가 남지 않았는지 확인

순서를 따른다.
