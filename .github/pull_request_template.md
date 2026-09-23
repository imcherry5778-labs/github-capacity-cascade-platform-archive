## 무엇을 변경했는가

<!-- 변경 내용을 짧게 설명한다. -->

## 왜 필요한가

<!-- 해결하려는 문제와 선택 이유를 설명한다. -->

## 어떻게 검증했는가

<!-- 실제로 실행한 test/command/evidence를 적는다. 실행하지 않았다면 이유를 적는다. -->

## 영향 범위

<!-- platform / infra / operations / tests / experiments / docs 등 -->

## 남은 문제 또는 의도적인 한계

<!-- 없으면 "없음"이라고 적는다. -->

## 체크리스트

- [ ] 한 PR이 하나의 목적에 집중한다.
- [ ] 제품 공식 용어를 우선 사용했다.
- [ ] secret, credential, kubeconfig, Terraform state를 포함하지 않았다.
- [ ] 변경과 관련된 test/static validation을 실행했다.
- [ ] reliability experiment 변경이라면 정상 E2E preflight 경계를 유지했다.
- [ ] Azure 비용이 발생하는 변경은 자동 apply되지 않는다.
