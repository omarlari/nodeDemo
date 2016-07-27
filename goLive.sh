#!/bin/bash
# Get the stack prefix from the vars file
AWS_STACK_PREFIX=$(cat ~/nodeDemo/vars/env99.yml | grep stackPrefix | cut -d: -f2)

# Get the ID of the stack that was created in the previous step
AWS_STACK_NO=$(aws cloudformation describe-stacks --stack-name $AWS_STACK_PREFIX-serverCluster --query 'Stacks[*].StackId' --output text)

# Find out what the ID of the hosted zone is that we're updating
AWS_EXT_DNS=$(aws route53 list-hosted-zones | grep -B 1 aws.omarlari.com | grep Id | awk -F\/ '{ print $3 }' | cut -d\" -f 1 | sed 2d)

# Get the name of the ELB that was created by CFN
AWS_STACK_ELB=$(aws cloudformation list-stack-resources --stack-name $AWS_STACK_NO | grep -C 3 AWS::Elastic | grep Physical | awk -F\" '{ print $4 }')

# Get the HostedZoneId of the ELB that was created
AWS_ELB_HOSTEDID=$(aws elb describe-load-balancers --load-balancer-names $AWS_STACK_ELB | grep CanonicalHostedZoneNameID | awk -F\" '{ print $4 }')

# Get the DNS Name of the Load Balancer
AWS_ELB_DNSNAME=$(aws elb describe-load-balancers --load-balancer-names $AWS_STACK_ELB | grep DNSName | awk -F\" '{ print $4 }')

# Create a temporary JSON file that is used to update DNS, leave the values that you are going to add blank

cat > modify-dns.json << EOF
{
  "Comment": "create the records for the stack.",
  "Changes": [
    {
      "Action": "",
      "ResourceRecordSet": {
        "Name": "nodedemo.aws.omarlari.com.",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "",
          "DNSName": "",
          "EvaluateTargetHealth": false
        }
      }
    }
  ]
}
EOF

# Check if the name record already exists
AWS_DNS=$(aws route53 list-resource-record-sets --hosted-zone-id $AWS_EXT_DNS | grep nodedemo.aws.omarlari.com | awk -F\" '{ print $4 }')

# Use the result of the DNS Query to control the type of DNS update
if [ -n "$AWS_DNS" ]; then
  sed -i 's/Action\": \"/&UPSERT/' modify-dns.json
  sed -i 's/HostedZoneId\": \"/&'$AWS_ELB_HOSTEDID'/' modify-dns.json
  sed -i 's/DNSName\": \"/&'$AWS_ELB_DNSNAME'/' modify-dns.json
else
  sed -i 's/Action\": \"/&CREATE/' modify-dns.json
  sed -i 's/HostedZoneId\": \"/&'$AWS_ELB_HOSTEDID'/' modify-dns.json
  sed -i 's/DNSName\": \"/&'$AWS_ELB_DNSNAME'/' modify-dns.json
fi

# Use the JSON formatted text to update the record
aws route53 change-resource-record-sets --hosted-zone-id $AWS_EXT_DNS --change-batch file://modify-dns.json
