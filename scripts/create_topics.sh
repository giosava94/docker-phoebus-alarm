#!/bin/sh

echo -e 'Creating kafka topics'

for config in "$@"
do
    topic=$config
    kafka-topics --bootstrap-server broker:29092 --create --if-not-exists --replication-factor 1 --partitions 1 --topic $topic
    kafka-configs --bootstrap-server broker:29092 --entity-type topics --alter --entity-name $topic \
    --add-config cleanup.policy=compact,segment.ms=10000,min.cleanable.dirty.ratio=0.01,min.compaction.lag.ms=1000

    # Create the deleted topics
    for topic in "${config}Command" "${config}Talk"
    do
        kafka-topics --bootstrap-server broker:29092 --create --if-not-exists --replication-factor 1 --partitions 1 --topic $topic
        kafka-configs --bootstrap-server broker:29092 --entity-type topics --alter --entity-name $topic \
        --add-config cleanup.policy=delete,segment.ms=10000,min.cleanable.dirty.ratio=0.01,min.compaction.lag.ms=1000,retention.ms=20000,delete.retention.ms=1000,file.delete.delay.ms=1000
    done
done

echo -e 'Successfully created the following topics:'
kafka-topics --bootstrap-server broker:29092 --list
