#!/bin/bash
set -e
topic=mytopic
count=100000
size=1024
rate=-1
instances=3
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
    b) brokers="$OPTARG"
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

rgname=kafkabenchmark$RANDOM

#still need to create topic

az group create --name $rgname --location eastus

#start the containers
for (( i=1; i<=$instances; i++ ))
do
   name=benchmark$i
   az container create --resource-group $rgname --name $name --no-wait --restart-policy Never --image confluentinc/cp-kafka --command-line "/bin/bash -c 'bash <( curl https://raw.githubusercontent.com/djrosanova/kafkabenchmarks/master/benchmark.sh ) -b $brokers -u $username -p $password -t $topic -c $count -s $size'"
done

#cycle through containers to get results
for (( i=1; i<=$instances; i++ ))
do
   status=NA
   name=benchmark$i
   until [ $status == "\"Completed\"" ]
   do
     #echo checking status of $name
     status=$(az container show --name $name --resource-group $rgname --query 'containers[0].instanceView.currentState.detailStatus')
     sleep 30
   done
   echo report for $rgname $name >> log.txt
   az container logs --resource-group $rgname --name $name >> log.txt
done

#clean up resources
az group delete --name $rgname -y
