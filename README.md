# sj-lab-discoveryServer — 서비스 레지스트리(Eureka)

> sj-lab 마이크로서비스들이 자신을 등록하고, 게이트웨이가 이 목록을 보고 `lb://SERVICE-ID`로 라우팅하도록 하는 **디스커버리 서버**입니다.
> 코드는 `@EnableEurekaServer`가 붙은 클래스 하나뿐이지만, **운영에서 이 서버의 동작을 이해하는 것이 장애 대응의 핵심**이었습니다.

| | |
|---|---|
| **운영 대시보드** | `https://eureka.sj-lab.co.kr` |
| **로컬 대시보드** | `http://localhost:8761` |
| **스택** | Java 17 · Spring Boot 3.3.2 · Spring Cloud 2023.0.3 (Netflix Eureka Server) |

---

## 1. 위치

```
[게이트웨이] sj-lab-apigateway :8100 ──조회──┐
                                              ▼
[이 서비스] sj-lab-discoveryServer :8761 (Eureka Server)
                                              ▲
[백엔드] mapservice-rest · sj-lab-scheduler · sj-lab-authserver · fast-api-ai ──등록──┘
```

이 구조 덕분에 백엔드는 `server.port: 0`(랜덤 포트)으로 떠도 되고, 게이트웨이는 파드 IP를 몰라도 됩니다.

---

## 2. 운영에서 배운 것 (면접에서 이야기하고 싶은 부분)

### ① 배포 직후 간헐적 500/503의 정체

백엔드를 재배포하면 잠깐 요청의 일부가 실패합니다. 원인은 **Eureka 레지스트리에 죽은 인스턴스가 남아 있는 구간**입니다(리스 만료까지 1~3분). 게이트웨이는 그 인스턴스로도 로드밸런싱을 시도해 연결 거부(500)가 나고, 목록이 빈 순간에는 503이 납니다.

대응을 절차로 정리했습니다.

```powershell
# 등록 상태 확인
Invoke-RestMethod -Uri "http://localhost:8761/eureka/apps" -Headers @{Accept="application/json"}

# 죽은 인스턴스 즉시 해제
Invoke-WebRequest -Method Delete "http://localhost:8761/eureka/apps/MAPSERVICE-REST/<instanceId>"
```

운영에서 실제로 이 증상을 재현·관찰해 `docs/dev-environment.md`에 기록해 두었고, 무중단 롤아웃(`replicas: 2` + preStop 지연)이 근본 해결책이라는 것도 과제로 남겨 두었습니다.

### ② self-registration 설정

로컬(`local` 프로파일)에서는 이 서버가 **자기 자신에게 클라이언트로 등록되지 않도록** `register-with-eureka: false`, `fetch-registry: false`로 둡니다. 운영에서 이 설정 때문에 문제가 됐던 이력이 있어 `eureka.client.*` 변경은 신중히 다룹니다.

### ③ 설정 외부화

운영 프로파일은 저장소에 두지 않고 **ConfigMap으로 주입**합니다(`SPRING_CONFIG_LOCATION=classpath:/,file:/app/config/`). 저장소가 public이므로 환경별 값이 코드에 섞이지 않게 하는 원칙을 전 서비스에 동일하게 적용했습니다.

---

## 3. 실행

```bash
mvnw.cmd clean package                                       # target/sj-lab-discoveryservice.jar
mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=local    # 8761
mvnw.cmd test
```

기동 후 `http://localhost:8761`에서 등록된 서비스를 확인합니다. 총괄 저장소의 `scripts/local-stack.ps1`이 이 서버를 가장 먼저 띄웁니다.

| 파일 | 내용 |
|---|---|
| `application.yml` | 포트 8761, 액추에이터 전체 노출 |
| `application-local.yml` | self-registration 비활성 |

---

## 4. 배포

```
git push → Jenkins(빌드 → 이미지 push) → sj-lab-k8s-manifests 의 image.tag 자동 커밋
        → ArgoCD 동기화 → Kubernetes 롤아웃 (NodePort 30087 → 8761)
```

Dockerfile은 Maven 빌드를 하지 않고 jar를 복사하므로 `package`가 선행되어야 합니다. `manifests/deployment.yaml`은 Helm 전환 이전의 잔재이므로, 배포를 다룰 때는 현재 방식(Helm 차트)을 먼저 확인합니다.

---

## 5. 주의 · 한계

- **`target/` 디렉터리가 git에 추적되고 있습니다.** 설정을 고칠 때는 반드시 `src/main/resources/` 쪽을 수정하세요(빌드 산출물을 직접 편집하면 다음 빌드에 사라집니다).
- 액추에이터가 전부 열려 있어(`exposure.include: "*"`) 운영 보안 관점에서 정리가 필요합니다.
- 단일 인스턴스라 이 서버가 죽으면 새 등록·조회가 멈춥니다(기존 캐시로 잠시 버팁니다). 피어 구성은 다음 과제입니다.

## 참고

- 전체 구조: 총괄 저장소 `mapservice-rest`의 `docs/system-architecture.md`
- 로컬 기동 순서·장애 대응: 같은 저장소의 `docs/dev-environment.md`
- 작업 규칙: 이 저장소의 `CLAUDE.md`
