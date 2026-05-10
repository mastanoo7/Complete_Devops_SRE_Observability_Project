# ============================================================
# Order Service — Dockerfile (Spring Boot / Maven)
# ============================================================

FROM maven:3.9.6-eclipse-temurin-17 AS builder

WORKDIR /app

COPY pom.xml ./
RUN mvn -q -DskipTests dependency:go-offline

COPY src ./src
RUN mvn -q -DskipTests package

FROM eclipse-temurin:17-jre AS development

WORKDIR /app
ENV JAVA_OPTS=""
COPY --from=builder /app/target/*.jar /app/app.jar

EXPOSE 8084
CMD ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]

FROM eclipse-temurin:17-jre AS production

WORKDIR /app
ENV JAVA_OPTS=""
COPY --from=builder /app/target/*.jar /app/app.jar

EXPOSE 8084
CMD ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]

