#!/bin/bash

############################################

# ENVIRONMENT VARIABLES

############################################

REGION_CODE=us-east-1
CLUSTER_NAME=roboshop-dev
ACC_ID=838180513114

############################################

# PACKAGE INSTALLATION

############################################

yum install -y yum-utils unzip git jq

sudo yum-config-manager 
--add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

yum -y install terraform

############################################

# STORAGE EXTENSION

############################################

growpart /dev/nvme0n1 4

lvextend -L +20G /dev/RootVG/rootVol
lvextend -L +10G /dev/RootVG/homeVol

xfs_growfs /
xfs_growfs /home

############################################

# DOCKER INSTALLATION

############################################

dnf -y install dnf-plugins-core

dnf config-manager 
--add-repo https://download.docker.com/linux/rhel/docker-ce.repo

dnf install -y 
docker-ce 
docker-ce-cli 
containerd.io 
docker-buildx-plugin 
docker-compose-plugin

systemctl enable docker
systemctl start docker

usermod -aG docker ec2-user

############################################

# AWS CLI INSTALLATION

############################################

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" 
-o "awscliv2.zip"

unzip awscliv2.zip

./aws/install

############################################

# EKSCTL INSTALLATION

############################################

ARCH=amd64
PLATFORM=$(uname -s)_$ARCH

curl -sLO 
"https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"

tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp

sudo install -m 0755 /tmp/eksctl /usr/local/bin

rm -rf eksctl_$PLATFORM.tar.gz /tmp/eksctl

############################################

# KUBECTL INSTALLATION

############################################

curl -O 
https://s3.us-west-2.amazonaws.com/amazon-eks/1.33.8/2026-02-27/bin/linux/amd64/kubectl

chmod +x kubectl

mv kubectl /usr/local/bin/

############################################

# HELM INSTALLATION

############################################

curl -fsSL -o get_helm.sh 
https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

chmod 700 get_helm.sh

./get_helm.sh

############################################

# KUBECTX / KUBENS INSTALLATION

############################################

git clone https://github.com/ahmetb/kubectx /opt/kubectx

ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx

ln -s /opt/kubectx/kubens /usr/local/bin/kubens

############################################

# VERIFY INSTALLATIONS

############################################

aws --version
terraform version
docker --version
eksctl version
kubectl version --client
helm version

############################################

# VERIFY AWS ACCESS

############################################

aws sts get-caller-identity

############################################

# OIDC PROVIDER

############################################

eksctl utils associate-iam-oidc-provider 
--region $REGION_CODE 
--cluster $CLUSTER_NAME 
--approve

############################################

# AWS LOAD BALANCER IAM POLICY

############################################

curl -o iam-policy.json 
https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy 
--policy-name AWSLoadBalancerControllerIAMPolicy 
--policy-document file://iam-policy.json || true

############################################

# AWS LOAD BALANCER SERVICE ACCOUNT

############################################

eksctl create iamserviceaccount 
--cluster=$CLUSTER_NAME 
--namespace=kube-system 
--name=aws-load-balancer-controller 
--attach-policy-arn=arn:aws:iam::$ACC_ID:policy/AWSLoadBalancerControllerIAMPolicy 
--region $REGION_CODE 
--approve

############################################

# GET VPC ID

############################################

VPC_ID=$(aws eks describe-cluster 
--name $CLUSTER_NAME 
--region $REGION_CODE 
--query "cluster.resourcesVpcConfig.vpcId" 
--output text)

echo $VPC_ID

############################################

# AWS LOAD BALANCER CONTROLLER

############################################

helm repo add eks https://aws.github.io/eks-charts

helm repo update

helm install aws-load-balancer-controller 
eks/aws-load-balancer-controller 
-n kube-system 
--set clusterName=$CLUSTER_NAME 
--set serviceAccount.create=false 
--set serviceAccount.name=aws-load-balancer-controller 
--set region=$REGION_CODE 
--set vpcId=$VPC_ID

############################################

# VERIFY ALB CONTROLLER

############################################

kubectl rollout status deployment 
aws-load-balancer-controller 
-n kube-system

kubectl get pods -n kube-system

############################################

# EBS CSI DRIVER

############################################

eksctl create iamserviceaccount 
--name ebs-csi-controller-sa 
--namespace kube-system 
--cluster $CLUSTER_NAME 
--role-name AmazonEKS_EBS_CSI_DriverRole 
--attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy 
--approve

helm repo add aws-ebs-csi-driver 
https://kubernetes-sigs.github.io/aws-ebs-csi-driver

helm repo update

helm install aws-ebs-csi-driver 
aws-ebs-csi-driver/aws-ebs-csi-driver 
--namespace kube-system

############################################

# VERIFY EBS CSI

############################################

kubectl get pods -n kube-system | grep ebs

############################################

# ARGO CD INSTALLATION

############################################

kubectl create namespace argocd

kubectl apply -n argocd 
-f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

############################################

# WAIT FOR ARGO CD

############################################

kubectl rollout status deployment/argocd-server 
-n argocd

############################################

# ARGOCD CLI INSTALLATION

############################################

curl -sSL -o argocd-linux-amd64 
https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

rm argocd-linux-amd64

############################################

# EXPOSE ARGO CD

############################################

kubectl patch svc argocd-server 
-n argocd 
-p '{"spec": {"type": "LoadBalancer"}}'

############################################

# VERIFY

############################################

kubectl get nodes

kubectl get pods -A

kubectl get svc -n argocd
