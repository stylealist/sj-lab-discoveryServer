# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

`sj-lab` MSA(마이크로서비스 아키텍처)에서 사용하는 **Spring Cloud Netflix Eureka 디스커버리(서비스 레지스트리) 서버** 단일 모듈 프로젝트입니다.
컨트롤러/서비스 로직은 없고, `@EnableEurekaServer`만 붙은 Spring Boot 애플리케이션 하나로 구성됩니다 (`src/main/java/com/example/discoveryservice/DiscoveryserviceApplication.java`). 다른 마이크로서비스들이 이 서버에 등록(register)하고 서로를 조회(discover)하는 용도입니다.

- Java 17, Spring Boot 3.3.2, Spring Cloud 2023.0.3
- 빌드 산출물 이름 고정: `sj-lab-discoveryservice.jar` (`pom.xml`의 `<finalName>`)

## 자주 사용하는 명령어

```bash
# 빌드 (jar 생성: target/sj-lab-discoveryservice.jar)
./mvnw clean package
# Windows: mvnw.cmd clean package

# 테스트 전체 실행
./mvnw test

# 단일 테스트 클래스 실행
./mvnw test -Dtest=DiscoveryserviceApplicationTests

# 로컬 실행 (기본 프로파일, 포트 8761)
./mvnw spring-boot:run

# local 프로파일로 실행
./mvnw spring-boot:run -Dspring-boot.run.profiles=local
# 또는: java -jar target/sj-lab-discoveryservice.jar --spring.profiles.active=local
```

실행 후 http://localhost:8761 에서 Eureka 대시보드 확인.

## 아키텍처

- **설정 파일 구조**
  - `application.yml`: 기본 설정. 서버 포트 `8761`, 액추에이터 엔드포인트 전체 노출(`management.endpoints.web.exposure.include: "*"`).
  - `application-local.yml`: `local` 프로파일 전용. `register-with-eureka: false`, `fetch-registry: false`로 설정되어 있어, 로컬에서 이 서버 자신이 스스로에게 클라이언트로 등록되지 않도록 함.
  - `local` 외 프로파일(예: `prod`)은 저장소 내에 없고, 배포 시 외부 ConfigMap으로 주입됨 (아래 배포 섹션 참고).

- **배포 파이프라인**
  1. Maven으로 jar 빌드 → `Dockerfile`이 `target/sj-lab-discoveryservice.jar`를 이미지에 복사 (Dockerfile 자체는 Maven 빌드를 수행하지 않으므로, 이미지를 빌드하기 전에 반드시 `./mvnw clean package`가 선행되어야 함).
  2. 이미지는 네이버클라우드 컨테이너 레지스트리(`sj-lab-registry.kr.ncr.ntruss.com`)에 푸시.
  3. `manifests/deployment.yaml`: 네임스페이스 `sj-lab`에 배포. `SPRING_PROFILES_ACTIVE=prod`, `SPRING_CONFIG_LOCATION=classpath:/,file:/app/config/`로 설정해 ConfigMap `discoveryserver-config`를 `/app/config`에 마운트, 운영 설정을 외부 주입.
  - git 히스토리 상 과거에는 Jenkins가 이미지 태그를 올려 커밋하는 방식(`Update image tag to N from Jenkins`)으로 CI/CD가 동작했고, 가장 최근 커밋(`[fix] helm 배포로 변경`)에서 Helm 기반 배포로 전환됨. `manifests/deployment.yaml`은 이전 방식(raw K8s manifest)의 흔적이므로, 배포 관련 작업 시 실제 사용 중인 배포 방식(Helm)이 무엇인지 먼저 확인할 것.

## 참고

- `target/` 디렉터리가 `.gitignore` 없이 git에 커밋되어 있어(`git status`에 `target/classes/application.yml` 등이 추적됨), 리소스 파일을 수정할 때는 반드시 `src/main/resources/` 쪽을 수정해야 함. `target/` 하위 파일은 빌드 산출물이므로 직접 편집하지 말 것.
- `application.yml`의 `management.endpoints.web.exposure.include: "*"`는 모든 액추에이터 엔드포인트를 노출하므로, 운영 설정을 다룰 때 보안 관점에서 유의할 것.
- 과거 커밋(`실서버에서 eureka 클라이언트가 감지되지 않도록 수정`)에서 알 수 있듯, 운영 환경에서의 Eureka self-registration 동작이 이슈가 된 이력이 있으므로 `eureka.client.*` 설정 변경 시 주의.
