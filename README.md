# docker-phoebus-alarm

This repository hosts the Dockerfile used to build two Docker images published on the Docker Hub:

- giosava94/phoebus-alarm-server
- giosava94/phoebus-alarm-logger

They download and compile from the [Phoebus github repository](https://github.com/ControlSystemStudio/phoebus) respectively the alarm-server and the alarm-logger services. For more information on how the phoebus alarm system manges EPICS alarms see the [phoebus alarms documentation](https://control-system-studio.readthedocs.io/en/latest/app/alarm/ui/doc/index.html).

# Pre-requisites

You must have [docker](https://docs.docker.com/) and [docker compose](https://docs.docker.com/compose/) installed on your host PC.

We assume a basic knowledge about [kafka](https://kafka.apache.org/documentation/) and [elasticsearch](https://www.elastic.co).

When running _elasticsearch_ in docker, the **vm.max_map_count** kernel setting must be set to at least 262144 for production use.

To permanently change the value for the **vm.max_map_count** setting, update the value in `/etc/sysctl.conf`. Instead, to apply the settings on a live system, run:

```
sysctl -w vm.max_map_count=262144
```

# Repository content description

The `scripts` folder contains the bash scripts used to generate or delete kafka topics. `create_alarm_topics.sh` and `delete_alarm_topics.sh` can be used outside the kafka docker container.

The `xml` folder contains an example configuration for the alarm-server. It is loaded as a volume and the `xi:include` tag refers to the path used in the docker container.

`settings.ini` contains the essential default parameters for the phoebus client to work with the version issued in this repository.

In this repository we also provide three docker-compose templates as reference:

- docker-compose.alarm-server.template.yml
- docker-compose.alarm-logger.template.yml
- docker-compose.template.yml

The last provide a complete example of a basic phoebus alarm system with an alarm-logger and an alarm-server. Here the list of the services present in the template and what they do:

- **zookeeper**: Service for maintaining configuration information, naming, providing distributed synchronization, and providing group services. Needed by kafka.
- **broker (Kafka)**: Kafka instantiation. Service to notify PV alarm changes. It makes use of topics to split communications. Initialized with the correct topic at startup. It also generates the kafka topics needed by the alarm-server and the alarm-logger.
- **alarm-server**: Service to monitor PV changes. It uses the broker service to inspect PV changes. It uses the corresponding xml configuration to generate the alarm-tree. _Console_ topic. To allow the server to read PVs network mode must be _host_.
- **elasticsearch**: Service to manage indices creation.
- **kibana**: _(Optional)_ Separated UI mainly used to inspect elasticsearch indices.
- **alarm-logger**: Service to log PV history through elasticsearch indices. It uses the broker service to inspect PV changes.

> When starting for the first time the services it is necessary to import into the alarm-servers the xml configurations. See [Import XML configuration](#import-xml-configuration).

> The elasticsearch server stores in the `/usr/share/elasticsearch/data` folder the indices and the alarm histories. Make a backup of this folder to not lose alarm histories.

# Usage

## Run temporary instance

Command to run a temporary instance of an alarm-server or an alarm-logger inside a docker container

```
docker run --rm --name <topic> giosava94/phoebus-alarm-server:4.7.1 -config <topic> -noshell

docker run --rm --name <topic> giosava94/phoebus-alarm-logger:4.7.1 -topics <topic> -noshell
```

You can add other parameters if required, refers to the correct version of the [alarm-server](https://github.com/ControlSystemStudio/phoebus/tree/master/services/alarm-server) and the [alarm-logger](https://github.com/ControlSystemStudio/phoebus/tree/master/services/alarm-logger) to know the possible parameters what they expect.

> Alternatively you can download the phoebus git repository, compile the services and start them locally on your host.

# Start the complete suite

If you want to use the alarm system provided in this repository you can start up it with the following command:

```
docker compose -f docker-compose.template.yml up -d
```

> If you want to keep everything as it is, you have to create an IOC generating a PV named **myioc:test**, otherwise you can edit the `xml/config.xml` file to directly include your configuration.
>
> The system uses the default topic **accelerator**.

## Import XML configuration

> This is mandatory the first time you start up the service

To import a configuration into a _running_ alarm-server

```
docker exec alarm-server java -jar /alarm-server/service-alarm-server.jar \
-config <topic> -import xml/config.xml
```

> When importing a configuration the path refers to the folder path in the docker container.

## Export XML configuration

To export an existing configuration from a _running_ alarm-server

```
docker exec alarm-server-<topic> java -jar /alarm-server/service-alarm-server.jar \
-config <topic> -export xml/config.xml
```

> When exporting a configuration the path refers to the folder path in the docker container.

## Add a new alarm server instance

If you want to add a new configuration or topic you have to instantiate a new alarm-server.

You can copy the service contained in `docker/docker-compose.alarm-server.template.yml` into the `docker-compose.template.yml`.

Consequently remember to:

- Give a new name to the service and the container name.
- Add the `-topic <topic>` line to the `command` compose property.
- Add the `depends_on` compose property in order to wait for kafka topics initialization before starting. Here how the property should be:
  ```
  depends_on:
    broker:
      condition: service_healthy
  ```
  It is not mandatory but avoid initial disconnection problems.
- Append your topic to `-topics` attribute of the `command` compose property of the alarm-logger service (as a comma separated list). If the `-topics <topics>` attribute is not present add it.
- Add a new folder (named as your topic) inside `xml` folder, place there your xml configuration and include in the alarm-server volume only that folder if you do not want to.
- Add the new topic to **org.phoebus.applications.alarm/config_names** in the `settings.ini` of your client.
- Add to the `KAFKA_CREATE_TOPICS` the necessary topics: **\<topic>**, **\<topic>Talk** and **\<topic>Command**.
  Here an example:
  ```
  "<topic>:1:1:compact --config=segment.ms=10000 --config=min.cleanable.dirty.ratio=0.01 --config=min.compaction.lag.ms=1000, \
  <topic>Command:1:1:delete --config=segment.ms=10000 --config=min.cleanable.dirty.ratio=0.01 --config=min.compaction.lag.ms=1000 \
  --config=retention.ms=20000 --config=delete.retention.ms=1000 --config=file.delete.delay.ms=1000, \
  <topic>Talk:1:1:delete --config=segment.ms=10000 --config=min.cleanable.dirty.ratio=0.01 --config=min.compaction.lag.ms=1000 \
  --config=retention.ms=20000 --config=delete.retention.ms=1000 --config=file.delete.delay.ms=1000"
  ```
  You can create them manually using the dedicated script (see [Add and delete topics to Kafka](#add-and-delete-topics-to-kafka)).
- If necessary, import your configuration when the service is up (see [Import XML configuration](#import-xml-configuration)).

## Add and delete topics to Kafka

The docker compose automatically creates the necessary topics on kafka server.

To manually create or delete a topic from your host PC you can use these commands (from `scripts` folder):

```
sh create_alarm_topics.sh <topic>
sh delete_alarm_topics.sh <topic>
```

## Useful commands to check if elasticsearch is up

Here a set of useful commands to run from your host PC to check communication and state of services.

### Elasticsearch

List all indices on the elasticsearch server:

```
curl -X GET 'http://localhost:9200/_cat/indices?v'
```

List mapping of all indices with a pretty shape:

```
curl -X GET 'localhost:9200/*/_mapping?pretty'
```

Search for all items or a specific item within an index:

```
curl -X GET "localhost:9200/<index_name>/_search?pretty"

curl -X GET "localhost:9200/<index_name>/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "query": {
    "wildcard": {
      "pv": "AlLlrfCryo02A_Qwrs02:*"
    }
  }
}
'
```

### Alarm-Logger

List all PVs monitored by the alarm-logger service:

```
curl -X GET 'http://localhost:8080/search/alarm'
```

Get information about a specific PV or multiple PVs using regular expression:

```
curl -X GET 'http://localhost:8080/search/alarm/pv/<pv-name>'
```

# Client

Check that your phoebus client version is at least v4.7.1 otherwise it may not work. If you are using this version or an older version check that your settings are equal to the onces in `settings.ini` file inside this project.

# Deploying

If you deploy your service on a different host from the one running the client you have to update the `docker-compose.template.yml` as follows:

- **broker**: replace the `PLAINTEXT://localhost:9092` with `PLAINTEXT://<host-name>:9092`
- **alarm-server**: replace `-server localhost` with `-server <host-name>:9092`

Moreover update the phoebus client `setting.ini`'s properties:

- org.phoebus.applications.alarm.logging.ui/service_uri = http://\<host-name>:8080
- org.phoebus.applications.alarm/server=\<host-name>:9092

If you use a different topic from accelerator changes the phoebus client `settings.ini` property:

- org.phoebus.applications.alarm/config_name=\<topic>

> If you change ports number remember to apply changes to all services and to the client.

# Developers

## Build Images

Inside the `docker` folder there is the Dockerfile generating the alarm-server and the alarm-logger docker images. It downloads the phoebus git repository (v4.7.1) and compile the needed services using maven (v3.9).

```
docker build -t giosava94/phoebus-alarm-server:4.7.1 --target alarm-server .
docker build -t giosava94/phoebus-alarm-logger:4.7.1 --target alarm-logger .
```

# Useful links

- [Phoebus alarms documentation](https://control-system-studio.readthedocs.io/en/latest/app/alarm/ui/doc/index.html)
- [Phoebus github repository](https://github.com/ControlSystemStudio/phoebus)
- [Kafka documentation](https://kafka.apache.org/documentation/)
- [To learn about configuring Kafka for access across networks](https://www.confluent.io/blog/kafka-client-cannot-connect-to-broker-on-aws-on-docker-etc/)
- [Elasticsearch 7.17](https://www.elastic.co/guide/en/welcome-to-elastic/7.17/index.html)
