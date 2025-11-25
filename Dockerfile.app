# Dockerfile para aplicação Spring Boot - Lambda + Kafka

# Estágio 1: Build
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /build

# Copiar arquivos do Maven
COPY .mvn/ .mvn/
COPY mvnw .
COPY pom.xml .

# Baixar dependências (cache layer)
RUN ./mvnw dependency:go-offline

# Copiar código fonte
COPY src/ src/

# Build da aplicação
RUN ./mvnw clean package -DskipTests

# Estágio 2: Runtime
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# Criar usuário não-root
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

# Copiar JAR do estágio de build
COPY --from=builder /build/target/lambda-modulo3-*.jar app.jar

# Expor porta da aplicação
EXPOSE 8080

# Variáveis de ambiente (podem ser sobrescritas)
ENV SPRING_PROFILES_ACTIVE=docker
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/api/kafka/health || exit 1

# Executar aplicação
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]