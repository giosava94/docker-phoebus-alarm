ARG MAVEN_VERSION=3.9
ARG JAVA_VERSION=16

FROM maven:${MAVEN_VERSION} AS build
ARG PHOEBUS_VERSION=4.7.1
RUN apt update \
    && apt -y install git \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*
RUN git clone -b v${PHOEBUS_VERSION} --single-branch https://github.com/ControlSystemStudio/phoebus.git
WORKDIR /phoebus
RUN mvn -q -DskipTests -pl services/alarm-server clean install 
RUN mvn -q -DskipTests -pl services/alarm-logger clean install 

FROM amazoncorretto:${JAVA_VERSION}-alpine AS alarm-server
ARG PHOEBUS_VERSION=4.7.1
WORKDIR /alarm-server
COPY --from=build /phoebus/services/alarm-server/target/service-alarm-server-${PHOEBUS_VERSION}.jar /alarm-server/service-alarm-server.jar
COPY --from=build /phoebus/services/alarm-server/target/lib /alarm-server/lib
CMD ["java", "-jar", "/alarm-server/service-alarm-server.jar", "-help"]

FROM amazoncorretto:${JAVA_VERSION}-alpine AS alarm-logger
ARG PHOEBUS_VERSION=4.7.1
WORKDIR /alarm-logger
COPY --from=build /phoebus/services/alarm-logger/target/service-alarm-logger-${PHOEBUS_VERSION}.jar /alarm-logger/service-alarm-logger.jar
EXPOSE 8080
CMD ["java", "-jar", "/alarm-logger/service-alarm-logger.jar", "-help"]