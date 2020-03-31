#!/bin/bash
set -e

function report(){
totalspeed=0
totalReadSpeed=0
count=0
instanceCount=0
readInstanceCount=0
writeInstanceCount=0
mbpsIn=0
mbpsOut=0
newReport=0

while read line
do
   col1="$(cut -d "," -f 1 <<<"$line")"
   colLen=${#col1}
   if [[ $col1 == "report for"* ]]; then
     ((instanceCount++))
     newReport=1
   elif [[ $col1 == *"records sent"* ]]; then
     speedstr="$(cut -d "," -f 2 <<<"$line")"
     speed="$(cut -d ' ' -f 2 <<<"$speedstr")"
     totalspeed="$(echo "$totalspeed + $speed" | bc -l)"
     ((count++))
     mbIn="$(cut -d "(" -f 2 <<<"$speedstr")"
     mbIn="$(cut -d ' ' -f 1  <<<"$mbIn")"
     mbpsIn="$(echo $mbpsIn + $mbIn | bc -l)"
     if [[ $newReport == 1 ]]; then
       ((writeInstanceCount++))
       newReport=0
     fi
   elif [[ $colLen == 23 ]]; then
       ((readInstanceCount++))
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
formattedMBpsIn="$(echo "($mbpsIn/$count)*$writeInstanceCount" | bc -l)"
formattedMBpsOut="$(echo $mbpsOut + 1 | bc -l)"
msgRateIn="$(echo $avgspeed*$writeInstanceCount | bc -l)"
echo Test start $teststart end $testend Send: $(printf %.2f $msgRateIn) msgs/sec Read: $(printf %.2f $totalReadSpeed) Send: $(printf %.2f $formattedMBpsIn) MBps Read: $(printf %.2f $formattedMBpsOut) MBps across $writeInstanceCount send instances $readInstanceCount read instances

echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
}

topic=mytopic
count=100000
size=1024
rate=-1
instances=3
location=eastus
ratio=3
reportOnly=0
while getopts ":t:c:s:r:b:u:p:h:l:i:o:" opt; do
  case $opt in
    t) topic="$OPTARG"
    ;;
    c) count="$OPTARG"
    ;;
    s) size="$OPTARG"
    ;;
    r) ratio="$OPTARG"
    ;;
    b) brokers="$OPTARG"
    ;;
    u) username="$OPTARG"
    ;;
    p) password="$OPTARG"
    ;;
    l) location="$OPTARG"
    ;;
    i) instances="$OPTARG"
    ;;
    o) reportOnly=1
       reportPath="$OPTARG"
    ;;
    h) echo usage
        echo Required:
        echo -b bootstrap servers DNS, with port, for your Confluent Cloud cluster
        echo -u cluster API key
        echo -p cluster API secret

        echo Optional:
        echo -t topic to send to: default "mytopic"
        echo -c count of messages to send from each instance: default 100000
        echo -s size of each message: default 1024 1kb
        echo -r ratio of reads to write: default 3x
        echo -l location of the Azure region to run in. Use "az account list-locations" to get the name of a region: default eastus
        echo -i instances number of send instances to use: default 3
        echo -o report only takes a file of a previous run log and reports the output
    ;;
    \?) echo "Invalid option -$OPTARG use -h for help" >&2
    ;;
  esac
done

echo "------------------------------------------------------------------------------------------------------------------------------------------------------"

if [[ $reportOnly -eq 1 ]]; then
 echo "|                                                      KAFKA BENCHMARK REPORT                                                                        |"
 report $reportPath
 exit 0
fi

rgname=kafkabenchmark$RANDOM

#still need to create to create topics

echo "|                                                      KAFKA BENCHMARK TEST STARTED                                                                  |"
az group create --name $rgname --location $location -o table
reportDate=$(date +%Y-%m-%d_%H:%M)
echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
echo "Test started at: $reportDate Topic:$topic Per Instance Message Count:$count Message Size:$size Brokers:$brokers Send Instances:$instances Ratio:$ratio Location:$location" > ${reportDate}_log.txt
#start the containers
totalInstances="$(echo "$instances+$instances*$ratio" | bc -l)"
for (( i=1; i<=$totalInstances; i++ ))
do 
   consumerGroup=$(echo $(($i%$ratio))) 
   name=benchmark$i
   mode="send"
   if [[ $i -gt $instances ]];
   then
     mode="receive"
   fi
   az container create --resource-group $rgname --name $name --no-wait --restart-policy Never --image confluentinc/cp-kafka --command-line "/bin/bash -c 'bash <( curl https://raw.githubusercontent.com/djrosanova/kafkabenchmarks/master/benchmark.sh ) -b $brokers -u $username -p $password -t $topic -c $count -m $mode -s $size -r $rate -g $consumerGroup'"
done    

#cycle through containers to get results
for (( i=1; i<=$totalInstances; i++ ))
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
report ${reportDate}_log.txt 
