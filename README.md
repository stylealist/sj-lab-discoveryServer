# sj-lab-discoveryServer — 서비스 레지스트리 및 디스커버리 (Netflix Eureka)

`sj-lab-discoveryServer`는 sj-lab 분산 마이크로서비스들의 동적 위치(IP 및 포트)를 등록하고 상태를 추적하는 Spring Cloud Netflix Eureka 기반의 서비스 레지스트리(Service Registry)입니다.

---

## 1. 서비스 역할 및 핵심 책임

- **중앙 서비스 레지스트리**: 백엔드 인스턴스(`mapservice-rest`, `sj-lab-scheduler`, `sj-lab-authserver`, `fast-api-ai`)가 기동될 때 자신의 네트워크 위치와 메타데이터를 등록받고 관리합니다.
- **동적 서비스 디스커버리(Service Discovery)**: API 게이트웨이(`sj-lab-apigateway`)가 클라이언트 요청을 라우팅할 때, Eureka 레지스트리를 조회하여 가용한 인스턴스 목록을 실시간으로 획득하도록 지원합니다.
- **하트비트 및 인스턴스 라이프사이클 관리**: 30초 주기의 하트비트(Heartbeat) 갱신을 통해 서비스 인스턴스의 헬스 상태를 감시하고, 장애 발생 시 만료된 인스턴스를 자동으로 제외합니다.

---

## 2. 기술 스택

- **언어 및 런타임**: Java 17, Spring Boot 3.3.2
- **프레임워크**: Spring Cloud 2023.0.3 (Spring Cloud Netflix Eureka Server)
- **모니터링**: Spring Boot Actuator
- **배포 환경**: Docker, Kubernetes (NodePort 30087), Helm, Jenkins CI, ArgoCD (GitOps)

---

## 3. 서비스 디스커버리 및 등록 프로세스

### 3.1 아키텍처 토폴로지

```
                      [Eureka Registry]
                     (:8761 / eureka.sj-lab.co.kr)
                       ▲              ▲
    (30초 주기 Heartbeat)│              │(서비스 인스턴스 목록 질의)
                       │              │
    ┌──────────────────┴──┐         ┌─┴─────────────────┐
    │ 마이크로서비스 인스턴스들 │         │ Spring Cloud      │
    │ (동적 포트 할당)      │         │ API Gateway (:8100│
    │ - MAPSERVICE-REST   │         └───────────────────┘
    │ - SJ-LAB-SCHEDULER  │                   ▲
    │ - SJ-LAB-AUTHSERVER │                   │ HTTPS 요청
    │ - FAST-API-AI       │            [클라이언트 브라우저]
    └─────────────────────┘
```

### 3.2 업무 및 라이프사이클 프로세스
1. **인스턴스 기동 및 등록(Register)**:
   - 각 마이크로서비스가 랜덤 포트(`server.port: 0`) 또는 지정 포트로 기동되면 `@EnableDiscoveryClient`를 통해 Eureka Server의 `/eureka/apps/{SERVICE-ID}`로 자신의 IP/호스트와 포트를 등록.
2. **상태 유지 및 갱신(Renew)**:
   - 클라이언트는 주기적(기본 30초)으로 REST PUT 핑을 전송하여 임대를 갱신.
3. **게이트웨이 동적 라우팅**:
   - `sj-lab-apigateway`는 서비스 ID(`lb://MAPSERVICE-REST` 등)를 Eureka에서 조회하여 실제 Pod IP로 부하 분산(Load Balancing) 요청 전달.
4. **인스턴스 해제 및 제거(Cancel & Eviction)**:
   - 인스턴스 정상 종료 시 REST DELETE 호출을 통해 레지스트리에서 즉시 제외.

---

## 4. 핵심 엔지니어링 구현 및 운영 상세

### 4.1 로컬 및 운영 환경별 Self-Registration 제어
- **로컬 개발 환경 (`local` 프로파일)**:
  - Eureka 서버 단독 실행 시 자기 자신을 레지스트리 클라이언트로 등록하지 않도록 설정하여 불필요한 등록 시도 에러 로그를 방지합니다.
  ```yaml
  eureka:
    client:
      register-with-eureka: false
      fetch-registry: false
  ```
- **운영 클라우드 환경**:
  - Kubernetes 환경에서 외부 ConfigMap을 주입받아 동작하며, 클러스터 내부 및 Ingress(`https://eureka.sj-lab.co.kr`)를 통해 웹 대시보드 상태 조회를 지원합니다.

### 4.2 인스턴스 갱신 지연 및 트러블슈팅 절차
- 인스턴스 재배포 시 Eureka의 기본 리스 만료 주기(90초)와 캐시 갱신 지연으로 인해 일시적으로 종료된 Pod로 트래픽이 라우팅될 수 있습니다.
- 긴급 운영 대응 및 로컬 디버깅 시 아래 REST API를 통해 비정상 인스턴스를 즉각 해제할 수 있습니다:
```powershell
# 현재 등록된 서비스 인스턴스 목록 확인
Invoke-RestMethod -Uri "http://localhost:8761/eureka/apps" -Headers @{Accept="application/json"}

# 지정 인스턴스 즉시 강제 등록 해제
Invoke-WebRequest -Method Delete "http://localhost:8761/eureka/apps/{SERVICE-ID}/{instanceId}"
```

---

## 5. 실행 및 개발 환경

### 로컬 빌드 및 실행
```powershell
# Maven 빌드
mvnw.cmd clean package

# 로컬 프로파일 실행 (포트 8761)
mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=local
```

### 상태 확인
- Eureka 웹 대시보드: `http://localhost:8761`
- Actuator Health 엔드포인트: `http://localhost:8761/actuator/health`
