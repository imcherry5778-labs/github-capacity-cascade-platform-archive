# Terminology

## 1. 목적

이 문서는 제품 공식 용어와 프로젝트 전용 측정 용어의 경계를 유지한다. 새 용어를 많이 만드는 것이 목적이 아니다. 혼동 가능성이 있는 표현만 정의한다.

## 2. 분류

- **SOURCE_TERM**: GitHub 공개 incident source가 실제로 사용한 표현
- **PRODUCT_TERM**: Kubernetes, Envoy, Istio, HAProxy, Forgejo 같은 제품이 공식적으로 정의한 표현
- **INDUSTRY_TERM**: SRE / distributed systems에서 널리 쓰이는 표현
- **PROJECT_TERM**: 이 프로젝트의 측정을 위해 정의한 표현
- **LEGACY_LAB_TERM**: 기존 Lab evidence에 남아 있으나 새 문서에서는 우선 사용하지 않는 표현

## 3. 핵심 용어

### cascading failure

- 분류: INDUSTRY_TERM
- 의미: 한 부분의 과부하나 실패가 다른 부분의 부하를 증가시키며 연쇄적으로 확산되는 장애
- 프로젝트명 `capacity cascade`와 동일한 공식 용어라고 보지 않는다.

### overload

- 분류: INDUSTRY_TERM
- 의미: 구성요소가 안전하게 처리할 수 있는 capacity를 넘어서는 상태
- CPU 100%만을 뜻하지 않는다. concurrency, queue, connection, request limit 등 다양한 resource에서 발생할 수 있다.

### developer operation

- 분류: PROJECT_TERM
- 의미: 개발자가 의도한 하나의 상위 행동
- 예: 한 번의 `git push`, Pull Request 생성, Issue 생성
- Git Smart HTTP의 개별 HTTP request와 1:1 관계가 아니다.

### operation attempt

- 분류: PROJECT_TERM
- 의미: 하나의 developer operation을 수행하려 한 한 번의 시도
- 하나의 operation에 retry가 있으면 여러 attempt가 생길 수 있다.

예:

```text
1 developer operation
→ initial attempt
→ retry attempt
→ retry attempt
= 3 operation attempts
```

### HTTP request

- 분류: INDUSTRY_TERM
- 의미: protocol 계층의 개별 HTTP request
- Git operation 하나가 여러 HTTP request를 만들 수 있으므로 developer operation과 구분한다.

### authorization check

- 분류: PROJECT_TERM
- 의미: reliability experiment에서 Istio Gateway가 synthetic shared gate에 보내는 외부 권한 확인 요청
- Forgejo native authentication/authorization을 대체하지 않는다.

### client retry amplification

- 분류: SOURCE_TERM / INDUSTRY_TERM
- 의미: retry 때문에 동일한 상위 수요가 더 많은 request/attempt로 변하는 현상
- 수치를 사용할 때는 무엇을 분자/분모로 사용했는지 명시한다.

예:

```text
operation-attempt amplification factor
= operation attempts / developer operations
```

### circuit breaker

- 분류: PRODUCT_TERM / INDUSTRY_TERM
- 이 프로젝트에서 Envoy circuit breaker를 언급할 때는 어떤 limit을 의미하는지 함께 쓴다.
- 예: maximum active requests / `max_requests`

### `upstream_rq_active_overflow`

- 분류: PRODUCT_TERM
- Envoy의 official counter
- configured maximum active-request circuit breaker limit 때문에 upstream request가 거절될 때 증가하는 신호로 사용한다.
- 사람이 읽는 문장에서는 metric 이름과 함께 의미를 설명한다.

### application-CPU HPA

- 분류: PROJECT_TERM
- 의미: 애플리케이션 container CPU만 `ContainerResource` metric으로 사용하는 HPA
- Kubernetes에 `blind HPA`라는 공식 mode가 있는 것이 아니다.

### proxy-signal-based scaling

- 분류: PROJECT_TERM
- 의미: Envoy의 요청 처리 상태와 직접 관련된 metric을 이용하는 scaling policy의 일반 설명
- 실제 구현 문서에서는 HPA/KEDA와 exact metric을 구체적으로 적는다.

### rate limiting

- 분류: PRODUCT_TERM / INDUSTRY_TERM
- 일정 기준을 넘는 요청을 제한하는 메커니즘
- HTTP 429와 request-rate threshold를 사용하는 구현을 막연히 `load shedding`이라고 부르지 않는다.

### load shedding

- 분류: INDUSTRY_TERM
- overload 상황에서 시스템 보호를 위해 일부 작업을 의도적으로 거절하거나 중단하는 더 넓은 개념
- 실제 메커니즘이 rate limiting이면 더 구체적인 표현인 `rate limiting`을 우선한다.

### Service Active Window

- 분류: PROJECT_TERM
- 의미: ephemeral environment가 의도적으로 서비스 가능한 상태로 선언된 측정 구간
- 24/7 monthly availability와 혼동하지 않는다.

### confounder

- 분류: INDUSTRY_TERM
- 의미: 실험 결과를 의도한 원인 외의 다른 원인으로 설명할 수 있게 만드는 교란 변수
- 예: node CPU saturation, PostgreSQL saturation, Forgejo 자체 과부하

### reviewed evidence

- 분류: PROJECT_TERM
- 의미: raw run 가운데 validity/provenance를 확인하고 포트폴리오 주장에 사용할 수 있도록 검토한 작은 evidence set
- `curated`라는 단어를 금지하지는 않지만 새 repo의 기본 표현은 reviewed/published evidence다.

## 4. Legacy Lab mapping

기존 Lab의 evidence field는 역사적 provenance를 보존하기 위해 이름을 변경하지 않는다.

| Legacy Lab term | 의미 | 새 문서에서 우선할 표현 |
| --- | --- | --- |
| `logical_requests` | k6가 의도한 상위 작업 수 | logical/developer operations, 문맥에 따라 구체화 |
| `physical_attempts` | k6가 실제 보낸 client HTTP attempt 수 | client request attempts |
| `hpa-blind` | auth-sim CPU만 보는 HPA | application-CPU HPA |
| `hpa-aware` | sidecar active-request custom metric HPA | exact metric 기반 HPA |
| `sidecar active overflow` | Envoy overflow counter에 대한 Lab 표현 | `upstream_rq_active_overflow`와 의미 설명 |
| `recovery_idle` | final queue/session이 0으로 복귀한 Lab boolean | recovery criterion met |

## 5. 작성 규칙

다음과 같은 압축 표현은 피한다.

```text
clean-source fixed-condition paired evidence
capacity-aware sidecar overflow mechanism
```

대신 측정 조건을 문장으로 풀어 쓴다.

예:

> 세 실행은 수정되지 않은 동일한 Git commit에서 수행했다. workload와 platform configuration은 동일하게 유지했고 client retry policy만 변경했다.
