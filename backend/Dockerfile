# ---- Stage 1: Build ----
# Default JDK 21 LTS. Override with --build-arg JDK_VERSION=25 if needed.
ARG JDK_VERSION=21

FROM eclipse-temurin:${JDK_VERSION}-jdk-alpine AS build
ARG JDK_VERSION=21
WORKDIR /build

COPY mvnw mvnw.cmd ./
COPY .mvn .mvn
COPY pom.xml ./
RUN chmod +x mvnw && ./mvnw dependency:go-offline -q

COPY src ./src
RUN ./mvnw package -DskipTests -Djava.version=${JDK_VERSION} -q

# ---- Stage 2: Runtime ----
FROM eclipse-temurin:${JDK_VERSION}-jre-alpine AS runtime
ARG JDK_VERSION=21
WORKDIR /app

RUN addgroup -S dentalcare && adduser -S dentalcare -G dentalcare

COPY --from=build /build/target/*.jar app.jar
RUN chown dentalcare:dentalcare app.jar

USER dentalcare

EXPOSE 8080

# Config override: mount host path to /app/config/
# Spring Boot auto-detects ./config/application.properties
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-jar", "app.jar"]
