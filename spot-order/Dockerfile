FROM eclipse-temurin:21-jre AS builder
WORKDIR /build

COPY build/libs/*.jar app.jar

RUN java -Djarmode=tools -jar app.jar extract --layers --launcher --destination extracted

FROM eclipse-temurin:21-jre
WORKDIR /app

COPY --from=builder /build/extracted/dependencies/ ./
COPY --from=builder /build/extracted/spring-boot-loader/ ./
COPY --from=builder /build/extracted/snapshot-dependencies/ ./
COPY --from=builder /build/extracted/application/ ./

# /config 디렉토리의 설정 파일을 추가로 읽음
ENV SPRING_CONFIG_ADDITIONAL_LOCATION=file:/config/

EXPOSE 8082
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
