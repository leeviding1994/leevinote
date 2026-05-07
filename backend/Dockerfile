FROM openjdk:26-ea-21-oraclelinux8
WORKDIR /app
COPY build/libs/leevinote-backend.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]