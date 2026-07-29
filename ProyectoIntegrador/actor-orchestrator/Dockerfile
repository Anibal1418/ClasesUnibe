FROM maven:3.9.11-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY pom.xml .
RUN mvn -q -DskipTests dependency:go-offline
COPY src ./src
RUN mvn -q -DskipTests package

FROM eclipse-temurin:21-jre
ENV PORT=8080
WORKDIR /app
COPY --from=build /workspace/target/hybrid-actor-orchestrator-1.0.0.jar /app/service.jar
CMD ["java", "-jar", "/app/service.jar"]
