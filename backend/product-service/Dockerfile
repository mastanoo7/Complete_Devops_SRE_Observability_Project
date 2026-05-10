# ============================================================
# Product Service — Dockerfile (Spring Boot / Maven)
# ============================================================

# ============================================================
# Builder Stage
# ============================================================

FROM maven:3.9.6-eclipse-temurin-17 AS builder

WORKDIR /app

# Copy project files
COPY . .

# Build application
RUN mvn clean package -DskipTests


# ============================================================
# Development Stage
# ============================================================

FROM eclipse-temurin:17-jre AS development

WORKDIR /app

ENV JAVA_OPTS=""

# Copy built JAR
COPY --from=builder /app/target/*.jar /app/app.jar

# Expose application port
EXPOSE 8082

# Start application
CMD ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]


# ============================================================
# Production Stage
# ============================================================

FROM eclipse-temurin:17-jre AS production

WORKDIR /app

ENV JAVA_OPTS=""

# Copy built JAR
COPY --from=builder /app/target/*.jar /app/app.jar

# Expose application port
EXPOSE 8082

# Start application
CMD ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]