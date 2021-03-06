#!/bin/bash
set -e
topic=mytopic
count=10000
size=1024
rate=-1
mode="both"
consumerGroup=1
while getopts ":t:c:s:r:b:u:p:h:m:g:" opt; do
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
    m) mode="$OPTARG"
    ;;
    g) consumerGroup="$OPTARG"
    ;;
    h) echo usage
        echo -t topic to send to
        echo -c count of messages to sned
        echo -s size of each message
        echo -r rate per second to send
        echo -b bootstrap servers DNS, with port, for your Confluent Cloud cluster
        echo -u cluster API key
        echo -p cluster API secret
	echo -m mode: send, receive, both
    ;;
    \?) echo "Invalid option -$OPTARG use -h for help" >&2
    ;;
  esac
done

if [[ ! -z $bootstrap ]]
then
    PERF_PRODUCER_CONFIG="bootstrap.servers=$bootstrap\nrequest.timeout.ms=60000\nacks=all\nsasl.mechanism=PLAIN\nsecurity.protocol=SASL_SSL\nsasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"$username\" password=\"$password\";"
    echo -e $PERF_PRODUCER_CONFIG > perf.config
    if [[ $mode == "both" ]];
    then
      nohup kafka-producer-perf-test --topic $topic --record-size $size --producer.config perf.config  --throughput $rate --num-records $count &
      kafka-consumer-perf-test --broker-list $bootstrap --consumer.config perf.config --topic $topic --messages $count --group group$consumerGroup
    elif [[ $mode == "send" ]]; then
       kafka-producer-perf-test --topic $topic --record-size $size --producer.config perf.config  --throughput $rate --num-records $count
    elif [[ $mode == "receive" ]]; then 
       kafka-consumer-perf-test --broker-list $bootstrap --consumer.config perf.config --topic $topic --messages $count --group group$consumerGroup
    fi
else
    echo "missing -b bootstrap servers, use -h for help"
fi

