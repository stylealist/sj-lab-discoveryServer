---
name: run
description: sj-lab-discoveryServer(Eureka 디스커버리 서버)를 로컬에서 빌드/실행하고 정상 동작을 확인하는 방법. "앱 실행", "로컬 실행", "동작 확인" 요청 시 사용.
---

# 로컬 실행 (Eureka 디스커버리 서버)

이 프로젝트는 컨트롤러 없이 `@EnableEurekaServer`만 있는 Spring Boot 앱입니다. 화면 검증 대신 **Eureka 대시보드가 뜨는지**로 동작을 확인합니다.

## 절차

1. 빌드
   ```bash
   ./mvnw clean package -DskipTests
   ```
2. local 프로파일로 실행 (스스로를 유레카 클라이언트로 등록하지 않도록 `application-local.yml`이 `register-with-eureka`/`fetch-registry`를 false로 둠)
   ```bash
   ./mvnw spring-boot:run -Dspring-boot.run.profiles=local
   ```
   또는 jar로 직접 실행:
   ```bash
   java -jar target/sj-lab-discoveryservice.jar --spring.profiles.active=local
   ```
3. 확인
   - 브라우저에서 `http://localhost:8761` 접속 → Eureka 대시보드(등록된 인스턴스 목록 화면)가 뜨면 정상.
   - 또는 `curl -s http://localhost:8761/actuator/health` 로 상태 확인 (`management.endpoints.web.exposure.include: "*"` 설정으로 액추에이터가 열려 있음).
4. 종료는 실행한 프로세스를 Ctrl+C로 중단.

## 주의

- `local` 프로파일을 지정하지 않고 기본 설정으로 띄우면 `eureka.client.*` 설정이 없어 스프링 클라우드 기본값(자기 자신에게 등록 시도)이 적용될 수 있으니, 로컬 검증 시에는 항상 `local` 프로파일을 사용한다.
- 빌드 산출물은 `target/`에 생성되며, 이 저장소는 `target/`이 git에 추적되고 있으므로 실행 확인 후 `git status`로 의도치 않은 변경이 섞이지 않았는지 확인한다.
