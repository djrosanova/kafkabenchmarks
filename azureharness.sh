#!/bin/bash
set -e

function report(){
totalspeed=0
totalReadSpeed=0
count=0
instanceCount=0
#readInstanceCount=0
mbpsIn=0
mbpsOut=0

while read line
do
   col1="$(cut -d "," -f 1 <<<"$line")"
   colLen=${#col1}
   if [[ $col1 == "report for"* ]]; then
     ((instanceCount++))
   elif [[ $col1 == *"records sent"* ]]; then
     speedstr="$(cut -d "," -f 2 <<<"$line")"
     speed="$(cut -d ' ' -f 2 <<<"$speedstr")"
     totalspeed="$(echo "$totalspeed + $speed" | bc -l)"
     ((count++))
     mbIn="$(cut -d "(" -f 2 <<<"$speedstr")"
     mbIn="$(cut -d ' ' -f 1  <<<"$mbIn")"
     mbpsIn="$(echo $mbpsIn + $mbIn | bc -l)"
   elif [[ $colLen == 23 ]]; then
       teststart=$col1
       testend="$(cut -d "," -f 2 <<<"$line")"
       readSpeed="$(cut -d "," -f 6 <<<"$line")"
       totalReadSpeed="$(echo "$totalReadSpeed + $readSpeed" | bc -l)"
       mbOut="$(cut -d "," -f 4 <<<"$line")"
       mbpsOut="$(echo $mbpsOut+$mbOut | bc -l)"
   elif [[ $col1 == *"Test started at"* ]]; then
     echo $line
   fi
done < "$1"
avgspeed="$(echo "$totalspeed/$count" | bc -l)"
avgread="$(echo "$totalReadSpeed/$count" | bc -l)"

formattedMBpsIn="$(echo $mbpsIn/$count*$instanceCount | bc -l)"
formattedMBpsOut="$(echo $mbpsOut/$instanceCount | bc -l)"
msgRateIn="$(echo $avgspeed*$instanceCount | bc -l)"
msgRateOut="$(echo $avgread*$instanceCount | bc -l)"
echo Test start $teststart end $testend Send $(printf %.2f $msgRateIn) msgs/sec Read $(printf %.2f $msgRateOut) Send $(printf %.2f $formattedMBpsIn) MBps Read $(printf %.2f $formattedMBpsOut) MBps across $instanceCount instances
}


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
reportDate=$(date +%Y-%m-%d_%H:%M)
echo "Test started at: $reportDate Topic:$topic Per Instance Message Count:$count Message Size:$size Brokers:$brokers" > ${reportDate}_log.txt
#start the containers
for (( i=1; i<=$instances; i++ ))
do  
   name=benchmark$i
   az container create --resource-group $rgname --name $name --no-wait --restart-policy Never --image confluentinc/cp-kafka --command-line "/bin/bash -c 'bash <( curl https://raw.githubusercontent.com/djrosanova/kafkabenchmarks/master/benchmark.sh ) -b $brokers -u $username -p $password -t $topic -c $count'"
done    

#cycle through containers to get results
for (( i=1; i<=$instances; i++ ))
do 
   status=NA
   name=benchmark$i
   until [ $status == "\"Completed\"" ]
   do
     status=$(az container show --name $name --resource-group $rgname --query 'containers[0].instanceView.currentState.detailStatus')
     sleep 30
   done
   echo report for $rgname $name >> ${reportDate}_log.txt
   az container logs --resource-group $rgname --name $name >> ${reportDate}_log.txt
done

#clean up resources
az group delete --name $rgname -y 
