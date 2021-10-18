#!/bin/bash

EKS_CLUSTER_NAME=eks-alb-2048game

# Sync time
sudo service ntpd stop
sudo ntpdate pool.ntp.org
sudo service ntpd start
sleep 10
sudo ntpstat || true

# Upgrade awscli

echo "Upgrade awscli"

pip3 install --upgrade --user awscli
echo 'PATH=$HOME/.local/bin:$PATH' >> ~/.bash_profile
source ~/.bash_profile

# Install kubectl, eksctl, aws-iam-authenticator, create a key pair, and confirm the AWS CLI version

echo "Installing kubectl"

curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/linux/amd64/kubectl
chmod +x ./kubectl
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin
kubectl version --short --client

echo "Installing eksctl"

curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version

# Installing jq, it's overkill for the job, but useful elsewhere
sudo yum -q install jq -y

# Set region and setup CLI
REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
aws configure set region $REGION

echo "Creating SSH Key Pair"

ssh-keygen -N "" -f ~/.ssh/id_rsa > /dev/null

# Clearing Cloud9 temporary credentials
rm -vf ~/.aws/credentials

echo "AWS CLI version:"

aws --version

echo; echo "AWS identity:"

aws sts get-caller-identity | jq -r '.Arn'

echo; echo "You should expect to see the IAM Role we attached earlier, with an instance ID on the end"
echo; echo "For example: arn:aws:sts::1234567890:assumed-role/cloud9-AdminRole-1VFO62P60OPQ1/i-07dfdf99d48eb10b0"

if [ "$REGION" == "us-east-1" ]; then
    # exclude use1-az3 from us-east-1 region due to unavailability
    AZs=$(aws ec2 describe-availability-zones --filters "Name=zone-id,Values=use1-az1,use1-az2,use1-az4,use1-az5,use1-az6" --query "AvailabilityZones[0:2].ZoneName" --output text | tr "\\t" ",")
    ZONES="--zones=$AZs"
fi

# eksctl create cluster --ssh-access --node-type t3.medium --node-private-networking --name=$EKS_CLUSTER_NAME $ZONES

# Setup IRSA for ALB Ingress Controller

# eksctl utils associate-iam-oidc-provider --cluster $EKS_CLUSTER_NAME --approve

POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='ALBIngressControllerIAMPolicy'].Arn" --output text)

if [ "$POLICY_ARN" == "" ]; then
    aws iam create-policy \
        --policy-name ALBIngressControllerIAMPolicy \
        --policy-document https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.4/docs/examples/iam-policy.json

    POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='ALBIngressControllerIAMPolicy'].Arn" --output text)
fi

echo; echo "Lab is ready to use."