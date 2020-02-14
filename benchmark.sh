#!/bin/bash
set -e
topic=mytopic
count=10000
size=1024
rate=-1
while getopts ":t:c:s:r:b:u:p:h:" opt; do
  case $opt in
    t) topic="$OPTARG"
    ;;
    c) count="$OPTARG"
    ;;
    s) size="$OPTARG"
    ;;
    r) rate="$OPTARG"
    ;;
    b) bootstrap="$OPTARG"
    ;;
    u) username="$OPTARG"
    ;;
    p) password="$OPTARG"
    ;;

    h) echo usage
        echo -t topic to send to
        echo -c count of messages to sned
        echo -s size of each message
        echo -r rate per second to send
        echo -b bootstrap servers DNS, with port, for your Confluent Cloud cluster
        echo -u cluster API key
        echo -p cluster API secret
    ;;
    \?) echo "Invalid option -$OPTARG use -h for help" >&2
    ;;
  esac
done
echo "bootstrap" $bootstrap

if [[ ! -z $bootstrap ]]
then
    PERF_PRODUCER_CONFIG="bootstrap.servers=$bootstrap\nclient.id=mirror_maker_producer\nrequest.timeout.ms=60000\nsasl.mechanism=PLAIN\nsecurity.protocol=SASL_SSL\nsasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"$username\" password=\"$password\";"
    echo -e $PERF_PRODUCER_CONFIG > perf.config
    nohup kafka-producer-perf-test --topic $topic --record-size $size --producer.config perf.config  --throughput $rate --num-records $count &
    nohup kafka-consumer-perf-test --broker-list $bootstrap --consumer.config perf.config --topic $topic --messages $count &

else
    echo "missing -b bootstrap servers, use -h for help"
fi
