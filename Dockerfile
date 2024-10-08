# Base image
FROM openjdk:17-jdk-alpine

# 작업 디렉토리 설정
WORKDIR /app

# 빌드된 JAR 파일을 복사
COPY target/sj-lab-discoveryservice.jar /app/sj-lab-discoveryservice.jar

# 포트 노출 (Eureka 서버의 기본 포트)
EXPOSE 8761

# 애플리케이션 실행
ENTRYPOINT ["java", "-jar", "/app/sj-lab-discoveryservice.jar"]