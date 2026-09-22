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
RUN mvn dependency:go-offline -B || true

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
ENV PORT=8080
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
