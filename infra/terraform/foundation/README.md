# Terraform Foundation

이 stack은 Azure environment를 만들고 지우는 반복 과정에서도 유지할 수 있는 **긴 lifecycle의 shared foundation**을 관리한다.

## Core 리소스

현재 foundation에는 다음만 포함한다.

- project-dedicated Azure DNS public zone
- persistent platform Azure Key Vault
- foundation Resource Group

GitHub OIDC identity/RBAC와 AKS/PostgreSQL은 이 stack에 아직 포함하지 않는다.

## DNS 경계

가비아에서 관리하는 전체 parent domain을 Azure DNS로 옮기지 않는다.

예를 들어 사용자가 `example.com`을 가지고 있다면 프로젝트용 zone은 다음처럼 별도 subdomain을 사용할 수 있다.

```text
platform.example.com
```

Terraform이 Azure DNS zone을 만들면 `dns_name_servers` output으로 authoritative name server 목록을 얻는다.

그 다음 가비아 parent zone에서 해당 subdomain에 NS delegation을 설정한다.

```text
example.com (Gabia)
└── platform.example.com
      └── delegated to Azure DNS name servers
```

프로젝트를 완전히 종료할 때는 Azure DNS zone 삭제 전후로 가비아의 이 delegation도 정리한다.

## Key Vault 경계

Key Vault는 다음 persistent platform secret을 위한 저장소다.

- Forgejo cryptographic material
- database credential
- 향후 persistent workload secret

Core에서는 Azure RBAC authorization을 사용한다.

현재 public network endpoint를 허용하는 것은 GitHub-hosted runner와 AKS workload가 별도 private endpoint 없이 접근할 수 있게 하기 위한 단순화다. 이는 secret을 public access로 공개한다는 의미가 아니다. 데이터 접근은 Entra ID/RBAC로 제어한다.

Private Endpoint/Firewall은 실제 요구가 생길 때 별도 ADR로 검토한다.

### Purge protection

이 프로젝트는 ephemeral portfolio lifecycle과 최종 teardown을 검증해야 하므로 Core에서는 `purge_protection_enabled = false`로 둔다.

Soft delete retention은 7일이다. 프로젝트 완전 종료 시에는 soft-deleted vault가 남아 있는지도 확인하고, 필요하면 명시적으로 purge한다.

이 선택은 24/7 production Key Vault baseline과 다른 의도적인 trade-off다.

## Remote backend

Foundation은 bootstrap stack이 만든 Azure Blob backend를 사용한다.

Backend 값은 source에 계정별 값을 하드코딩하지 않고 `terraform init -backend-config=...`로 전달한다.

예:

```bash
terraform -chdir=infra/terraform/foundation init \
  -backend-config='resource_group_name=<bootstrap-rg>' \
  -backend-config='storage_account_name=<bootstrap-storage>' \
  -backend-config='container_name=tfstate' \
  -backend-config='key=foundation.tfstate' \
  -backend-config='use_azuread_auth=true'
```

실제 backend 값은 bootstrap output과 Azure identity contract가 확정된 뒤 workflow에 연결한다.

## 실제 apply 전 필요한 값

다음 값은 source에 하드코딩하지 않는다.

- `dns_zone_name`
- `key_vault_name`

둘 다 실제 사용자의 domain/naming context가 필요하기 때문이다.

## 현재 검증 범위

PR CI는 Azure에 로그인하지 않고:

```bash
terraform fmt -check -recursive infra/terraform
terraform -chdir=infra/terraform/foundation init -backend=false -lockfile=readonly
terraform -chdir=infra/terraform/foundation validate
```

만 수행한다.

따라서 이 단계에서는 Azure resource와 비용이 생성되지 않는다.
