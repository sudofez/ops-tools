#!/bin/bash
# createcloudaccount dsmuser dsmFQDNorIP connectorName newAwsUserToCreate (TenantID if needed)
if [[ $1 == *"help"* ]]
then
  echo -e "## usage:\n## create-iam-cloudaccount <managerUsername> <managerUrl:port> Amazon <newAwsUserToCreate>\n"
  echo -e "## example to create User and Cloud account on a DeepSecurity Manager:\n"
  echo -e "## create-iam-cloudaccount administrator dsm.example.local:443 Amazon DsmSyncUser"
  echo -e "## example to create User and Cloud account in DSaaS\n"
  echo -e "## create-iam-cloudaccount administrator app.deepsecurity.trendmicro.com:443 DsmSyncUser CustomerTenant\n"
  exit 0
fi

command -v aws >/dev/null 2>&1 || { echo >&2 "This script requires AWS CLI. Please install AWS CLI before proceeding."; exit 1; }


if [ ! -f ~/.aws/credentials ]
  then
    echo “please run aws configure before using this script”
    exit 2
fi

username=$1
DSMFQDN=$2
AWSKEYS=
tempDSSID=

read -sr -p $'Password: ' password

echo " "


# Remove regions you don't want from this list
REGIONS=(useast1 uswest1 uswest2 euwest1 apsoutheast1 apsoutheast2 apnortheast1 saeast1 eucentral1)

# map aws regions to dsm region keys
useast1=amazon.cloud.region.key.1
uswest2=amazon.cloud.region.key.2
uswest1=amazon.cloud.region.key.3
euwest1=amazon.cloud.region.key.4
apsoutheast1=amazon.cloud.region.key.5
apnortheast1=amazon.cloud.region.key.6
saeast1=amazon.cloud.region.key.7
apsoutheast2=amazon.cloud.region.key.8
eucentral1=amazon.cloud.region.key.9
#apnortheast2=amazon.cloud.region.key.12

# map aws regions to ec2 endpoints
useast1ep=ec2.us-east-1.amazonaws.com
uswest2ep=ec2.us-west-2.amazonaws.com
uswest1ep=ec2.us-west-1.amazonaws.com
euwest1ep=ec2.eu-west-1.amazonaws.com
apsoutheast1ep=ec2.ap-southeast-1.amazonaws.com
apnortheast1ep=ec2.ap-northeast-1.amazonaws.com
saeast1ep=ec2.sa-east-1.amazonaws.com
apsoutheast2ep=ec2.ap-southeast-2.amazonaws.com
eucentral1ep=ec2.eu-central-1.amazonaws.com
#apnortheast2ep=ec2.ap-northeast-2.amazonaws.com


echo "#####Creating user"
aws iam create-user --user-name $4

echo "#####Putting user policy"
aws iam put-user-policy --user-name $4 --policy-name DSMUserRole --policy-document '{"Statement" : [{"Effect" : "Allow","Action" : ["ec2:DescribeInstances","ec2:DescribeImages","ec2:DescribeTags"],"Resource" : "*"}]}'
echo "#####Creating accesskeys"
AWSKEYS=($(aws iam create-access-key --user-name $4 --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text))

echo "#####Login to DSM"
#tempDSSID=$(curl -ks -H "Content-Type: application/json" -X POST "https://$DSMFQDN/rest/authentication/login/primary" -d "{"dsCredentials":{"userName":"$username","password":"$password"}}")

if [[ -z $5 ]]
  then
    tempDSSID=`curl -ks -H "Content-Type: application/json" -X POST "https://${DSMFQDN}/rest/authentication/login/primary" -d '{"dsCredentials":{"userName":"'${1}'","password":"'${password}'"}}'`
  else
    tempDSSID=`curl -ks -H "Content-Type: application/json" -X POST "https://${DSMFQDN}/rest/authentication/login" -d '{"dsCredentials":{"userName":"'${1}'","password":"'${password}'","tenantName":"'${5}'"}}'`
fi



echo "#####Looping through regions to create connectors"
for region in "${REGIONS[@]}"
do
	echo "##### creating connector for $region region"
	curl -ks -H "Content-Type: application/json" "Accept: application/json" -X POST "https://$DSMFQDN/rest/cloudaccounts" -d '{"createCloudAccountRequest":{"cloudAccountElement":{"accessKey":"'${AWSKEYS[0]}'","cloudRegion":"'${!region}'","cloudType":"AMAZON","name":"'$3$region'","secretKey":"'${AWSKEYS[1]}'","endpoint":"'${!endpoint}'","azureCertificate":"-"},"sessionId":"'$tempDSSID'"}}'
done

curl -k -X DELETE https://$DSMFQDN/rest/authentication/logout?sID=$tempDSSID

unset AWSKEYS
unset tempDSSID
unset username
unset password


