# terraform-aws-eks

Overview
Terraform configuration to provision an EKS cluster and supporting resources for Roboshop.

Why this exists
To create reproducible, versioned Kubernetes clusters for running applications.

Workflows
- Configure VPC and IAM
- terraform apply for cluster resources
- Deploy apps via ArgoCD or kubectl

Actions (quick start)
1. Install Terraform, AWS CLI, kubectl, eksctl (optional).
2. terraform init && terraform apply
3. Configure kubeconfig and deploy applications.

Key files
- 00-VPC..80-eks, apply.sh, destroy.sh, terraform.tfstate

Notes
- Use node group autoscaling and proper IAM roles for production.
