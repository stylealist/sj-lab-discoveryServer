# Base image
FROM openjdk:17-jdk-alpine

# 작업 디렉토리 설정
WORKDIR /app

# 빌드된 JAR 파일을 복사
#COPY target/your-app.jar /app/your-app.jar
CP -R target/your-app.jar /app/your-app.jar

# 애플리케이션 실행
ENTRYPOINT ["java", "-jar", "/app/your-app.jar"]