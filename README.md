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
Look at the file log.txt in your current directory for your test results
