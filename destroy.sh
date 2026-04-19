#!/bin/bash

set -e

echo "Destroying EKS..."
cd 80-eks && terraform destroy -auto-approve

echo "Destroying ALB..."
cd ../70-ingress-alb && terraform destroy -auto-approve

echo "Destroying ACM..."
cd ../60-acm && terraform destroy -auto-approve

echo "Destroying Bastion..."
cd ../20-bastion && terraform destroy -auto-approve

echo "Destroying Security Groups..."
cd ../10-sg && terraform destroy -auto-approve

echo "Destroying VPC..."
cd ../00-VPC && terraform destroy -auto-approve

echo "All resources destroyed successfully."