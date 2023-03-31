FROM maven:3.9 AS build
RUN apt update & apt -y install git
RUN git clone -b v4.7.1 --single-branch https://github.com/ControlSystemStudio/phoebus.git
WORKDIR /phoebus
RUN mvn -q -DskipTests -pl services/alarm-server clean install 
RUN mvn -q -DskipTests -pl services/alarm-logger clean install 

FROM openjdk:16-slim-buster as alarm-server
COPY --from=build /phoebus/services/alarm-server/target/service-alarm-server-4.7.1.jar /alarm-server/service-alarm-server.jar
COPY --from=build /phoebus/services/alarm-server/target/lib /alarm-server/lib
WORKDIR /alarm-server
ENTRYPOINT ["java", "-jar", "/alarm-server/service-alarm-server.jar"]
CMD ["-list"]

FROM openjdk:16-slim-buster as alarm-logger
COPY --from=build /phoebus/services/alarm-logger/target/service-alarm-logger-4.7.1.jar /alarm-logger/service-alarm-logger.jar
WORKDIR /alarm-logger
ENTRYPOINT ["java", "-jar", "/alarm-logger/service-alarm-logger.jar"]
CMD ["-list"]