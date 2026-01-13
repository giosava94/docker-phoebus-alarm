# docker-phoebus-alarm

This repository hosts the Dockerfile used to build two Docker images published on the Docker Hub and INFN Baltig's container registry:

- giosava94/phoebus-alarm-server
- giosava94/phoebus-alarm-logger
- baltig.infn.it:4567/gsavares/docker-phoebus-alarm/alarm-server
- baltig.infn.it:4567/gsavares/docker-phoebus-alarm/alarm-logger

They download and compile from the [Phoebus github repository](https://github.com/ControlSystemStudio/phoebus) respectively the **alarm-server** and the **alarm-logger** services. For more information on how the phoebus alarm system manges EPICS alarms see the [phoebus alarms documentation](https://control-system-studio.readthedocs.io/en/latest/app/alarm/ui/doc/index.html).

# Pre-requisites

You must have [docker](https://docs.docker.com/) and [docker compose](https://docs.docker.com/compose/) installed on your host PC.

Both the alarm-server and the alarm-logger require a running [kafka](https://kafka.apache.org/documentation/) instance to correctly work. Additionally, the alarm-logger requires a running [elasticsearch](https://www.elastic.co) instance connected to the previously mentioned kafka service. We assume a basic knowledge about kafka and elasticsearch.

> When running _elasticsearch_ outisde docker, the **vm.max_map_count** kernel setting must be set to at least 262144 for production use. To permanently change the value for the **vm.max_map_count** setting, update the value in `/etc/sysctl.conf`. Instead, to apply the settings on a live system, run: `sysctl -w vm.max_map_count=262144`

# Repository content description

The Dockerfile used to build the alarm-server and alarm-logger docker images.

Two docker-compose templates as reference:
- compose.alarm-server.yml
- compose.alarm-logger.yml

The `xml` folder containing an example configuration for the alarm-server. It is loaded as a volume in the _compose.alarm-server.yml_ template. 

> The `xi:include` tag refers to the path used in the docker container.

> When starting for the first time the alarm-server, import into the xml configurations. See [Import XML configuration](#import-xml-configuration).

# Usage

## Run temporary instance

Command to run a temporary instance of an alarm-server or an alarm-logger inside a docker container

```bash
docker run --rm --name <topic> giosava94/phoebus-alarm-server -config <topic> -noshell

docker run --rm --name <topic> giosava94/phoebus-alarm-logger -topics <topic> -noshell
```

You can add other parameters if required, refers to the correct version of the [alarm-server](https://github.com/ControlSystemStudio/phoebus/tree/master/services/alarm-server) and the [alarm-logger](https://github.com/ControlSystemStudio/phoebus/tree/master/services/alarm-logger) to know the possible parameters what they expect.

> Alternatively you can download the phoebus git repository, compile the services and start them locally on your host.

## Import XML configuration

> This is mandatory the first time you start up an alarm-server instance

To import a configuration into a _running **alarm-server**_ container:

```bash
docker exec alarm-server java -jar /alarm-server/service-alarm-server.jar -config <topic> -import xml/config.xml
```

> When importing a configuration the path refers to the folder path in the docker container.

## Export XML configuration

To export an existing configuration from a _running **alarm-server**_ container:

```bash
docker exec alarm-server java -jar /alarm-server/service-alarm-server.jar -config <topic> -export xml/config.xml
```

> When exporting a configuration the path refers to the folder path in the docker container.

## Verify the alarm-logger is up and running

List all PVs monitored by the alarm-logger service:

```bash
curl -X GET 'http://localhost:8080/search/alarm'
```

Get information about a specific PV or multiple PVs using regular expression:

```bash
curl -X GET 'http://localhost:8080/search/alarm/pv/<pv-name>'
```

## Phoebus clients

**Check that your phoebus client version is at least v4.7.1 otherwise it may not work.**

If you are using this version or an older version check that your settings are as follows:

```md
org.phoebus.applications.alarm/server=<kafka-bootstrap-servers>
org.phoebus.applications.alarm/config_names=console,guardian
org.phoebus.applications.alarm/config_name=console

org.phoebus.applications.alarm.logging.ui/service_uri=<alarm-logger-http-url>
```

# Developers

## Build Images

Inside the `docker` folder there is the Dockerfile generating the alarm-server and the alarm-logger docker images. It downloads the phoebus git repository (default=v4.7.1) and compile the needed services using maven (default=v3.9).

```bash
docker build -t alarm-server --target alarm-server .
docker build -t alarm-logger --target alarm-logger .
```

If you want you can build the images using the following _--build-arg_ values:
- **PHOEBUS_VERSION**: Change the phoebus alarm system version
- **MAVEN_VERSION**: Change the maven version used to build the applications
- **JAVA_VERSION**: Change the java version used to run the applications

# Useful links

- [Phoebus alarms documentation](https://control-system-studio.readthedocs.io/en/latest/app/alarm/ui/doc/index.html)
- [Phoebus github repository](https://github.com/ControlSystemStudio/phoebus)
- [Kafka documentation](https://kafka.apache.org/documentation/)
- [To learn about configuring Kafka for access across networks](https://www.confluent.io/blog/kafka-client-cannot-connect-to-broker-on-aws-on-docker-etc/)
- [Elasticsearch 7.17](https://www.elastic.co/guide/en/welcome-to-elastic/7.17/index.html)
