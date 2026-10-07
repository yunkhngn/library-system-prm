# ==============================================================================
# Multi-stage Dockerfile for Spring Boot (Java 21)
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Build stage
# ------------------------------------------------------------------------------
FROM maven:3.9.9-eclipse-temurin-21-alpine AS builder
WORKDIR /workspace

# Cache dependency layer
COPY pom.xml .
RUN mvn dependency:resolve -B

# Copy source code and package application (skipping tests for container image)
COPY src ./src
RUN mvn clean package -DskipTests

# ------------------------------------------------------------------------------
# Stage 2: Runtime stage
# ------------------------------------------------------------------------------
FROM eclipse-temurin:21-jre-alpine AS runner
WORKDIR /app

# Create non-root system user for security
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

# Copy built artifact from builder stage
COPY --from=builder /workspace/target/*.jar app.jar

# Configuration & environment defaults
ENV SERVER_PORT=8080 \
    PORT=8080 \
    JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -Dserver.port=${SERVER_PORT:-${PORT:-8080}} -jar app.jar"]
