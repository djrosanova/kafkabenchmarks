# kafkabenchmarks

## Azure
First create a Confluent Cloud account: https://azuremarketplace.microsoft.com/en-us/marketplace/apps/confluentinc.confluent-cloud-kafka-service-azure 

Create a cluster, a topic, and an API Key

Download the test harness script
```bash
curl -s https://raw.githubusercontent.com/djrosanova/kafkabenchmarks/master/azureharness.sh -o azureharness.sh
```
Make the script executable
```bash
chmod +x azureharness.sh
```
Run the script
```bash
./azureharness.sh -t $topic -u $apikey -p $apisecret -b $bootstrapservers
```
Look at the file [DateOfRun]_log.txt in your current directory for your test results

### Parameters
```
Required:
        echo -b bootstrap servers DNS, with port, for your Confluent Cloud cluster
        echo -u cluster API key
        echo -p cluster API secret

Optional:
        -t topic to send to: default "mytopic"
        -c count of messages to send from each instance: default 100000
        -s size of each message: default 1024 1kb
        -r ratio of reads to write: default 3x
        -l location of the Azure region to run in. Use "az account list-locations" to get the name of a region: default eastus
        
        -i instances number of send instances to use: default 3
        -o report only takes a file of a previous run log and reports the output
```
