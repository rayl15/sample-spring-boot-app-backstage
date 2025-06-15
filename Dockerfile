# Multi-stage build for Spring Boot application
FROM eclipse-temurin:21-jdk AS builder
WORKDIR /app

# Copy maven configuration first for better layer caching
COPY mvnw pom.xml ./
COPY .mvn .mvn

# Download dependencies (this layer will be cached)
RUN ./mvnw dependency:go-offline -B

# Copy source files
COPY src src

# Build the application
RUN ./mvnw package -DskipTests

# Runtime stage
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Create a non-root user for running the application
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 --ingroup appgroup appuser

# Copy the built artifact from the builder stage
COPY --from=builder /app/target/*.jar /app/application.jar

# Set ownership and permissions
RUN chown -R appuser:appgroup /app
USER appuser

# Configure JVM options for containers
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom"

# Expose the application port
EXPOSE 8080

# Set health check using actuator endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Run the application
ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -jar /app/application.jar"]
