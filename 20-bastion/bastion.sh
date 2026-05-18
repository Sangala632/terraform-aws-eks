#!/bin/bash

# ENVIRONMENT VARIABLES

REGION_CODE=us-east-1
CLUSTER_NAME=roboshop-dev
ACC_ID=838180513114

# PACKAGE INSTALLATION

yum install -y yum-utils unzip git

sudo yum-config-manager \
    --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

yum -y install terraform


# STORAGE EXTENSION

growpart /dev/nvme0n1 4

lvextend -L +20G /dev/RootVG/rootVol
lvextend -L +10G /dev/RootVG/homeVol

xfs_growfs /
xfs_growfs /home


# DOCKER INSTALLATION

dnf -y install dnf-plugins-core

dnf config-manager \
    --add-repo https://download.docker.com/linux/rhel/docker-ce.repo

dnf install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

systemctl start docker
systemctl enable docker

usermod -aG docker ec2-user


# AWS CLI INSTALLATION

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
-o "awscliv2.zip"

unzip awscliv2.zip

./aws/install


# EKSCTL INSTALLATION

ARCH=amd64
PLATFORM=$(uname -s)_$ARCH

curl -sLO \
"https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"

curl -sL \
"https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" \
| grep $PLATFORM \
| sha256sum --check

tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp

rm eksctl_$PLATFORM.tar.gz

sudo install -m 0755 /tmp/eksctl /usr/local/bin

rm /tmp/eksctl


# KUBECTL INSTALLATION

curl -O \
https://s3.us-west-2.amazonaws.com/amazon-eks/1.33.8/2026-02-27/bin/linux/amd64/kubectl

chmod +x kubectl

mv kubectl /usr/local/bin/kubectl


# HELM INSTALLATION

curl -fsSL -o get_helm.sh \
https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4

chmod 700 get_helm.sh

./get_helm.sh


# KUBECTX / KUBENS INSTALLATION

git clone https://github.com/ahmetb/kubectx /opt/kubectx

ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx

ln -s /opt/kubectx/kubens /usr/local/bin/kubens


# K9S INSTALLATION

curl -sS https://webinstall.dev/k9s | bash


# VERIFY INSTALLATIONS

aws --version
terraform version
docker --version
eksctl version
kubectl version --client
helm version


# ENVIRONMENT VARIABLES

REGION_CODE=us-east-1
CLUSTER_NAME=roboshop-dev
ACC_ID=838180513114


# VERIFY AWS ACCESS

aws sts get-caller-identity


# EKS OIDC PROVIDER ASSOCIATION

eksctl utils associate-iam-oidc-provider \
    --region $REGION_CODE \
    --cluster $CLUSTER_NAME \
    --approve


# AWS LOAD BALANCER CONTROLLER INSTALLATION

eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --attach-policy-arn=arn:aws:iam::$ACC_ID:policy/AWSLoadBalancerControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --region $REGION_CODE \
    --approve

helm repo add eks https://aws.github.io/eks-charts

helm repo update

VPC_ID=$(aws eks describe-cluster \
    --name $CLUSTER_NAME \
    --region $REGION_CODE \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)

helm upgrade --install aws-load-balancer-controller \
    eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=$REGION_CODE \
    --set vpcId=$VPC_ID


# MYSQL SECRET READER IAM SERVICE ACCOUNT

eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --namespace=roboshop \
    --name=roboshop-mysql-secret-reader \
    --attach-policy-arn=arn:aws:iam::$ACC_ID:policy/RoboShopMySQLSecretReader \
    --override-existing-serviceaccounts \
    --region $REGION_CODE \
    --approve


# AWS EBS CSI DRIVER INSTALLATION

kubectl apply -k \
"github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.59"

helm repo add aws-ebs-csi-driver \
https://kubernetes-sigs.github.io/aws-ebs-csi-driver

helm repo update

helm upgrade --install aws-ebs-csi-driver \
    aws-ebs-csi-driver/aws-ebs-csi-driver \
    --namespace kube-system


# EBS CSI IAM SERVICE ACCOUNT

eksctl create iamserviceaccount \
    --name ebs-csi-controller-sa \
    --namespace kube-system \
    --cluster $CLUSTER_NAME \
    --role-name AmazonEKS_EBS_CSI_DriverRole \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --approve \
    --override-existing-serviceaccounts


# RESTART EBS CSI CONTROLLER

kubectl rollout restart deployment ebs-csi-controller \
    -n kube-system


# VERIFY AWS LOAD BALANCER CONTROLLER

kubectl get deployment \
-n kube-system aws-load-balancer-controller

kubectl get pods -n kube-system \
| grep aws-load-balancer-controller


# VERIFY EBS CSI DRIVER

kubectl get pods -n kube-system \
| grep ebs


# VERIFY STORAGE CLASS

kubectl get sc


# VERIFY NODES

kubectl get nodes


# VERIFY ALL SYSTEM PODS

kubectl get pods -A

#argocd install
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
service/argocd-server patched
rm argocd-linux-amd64