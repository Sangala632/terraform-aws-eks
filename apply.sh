#!/bin/bash

set -e

echo "Creating VPC..."
cd 00-VPC && terraform apply -auto-approve

echo "Creating Security Groups..."
cd ../10-sg && terraform apply -auto-approve

echo "Creating Bastion..."
cd ../20-bastion && terraform apply -auto-approve

echo "Creating ecr..."
cd ../30-ecr && terraform apply -auto-approve


echo "Creating ACM certificate..."
cd ../60-acm && terraform apply -auto-approve

echo "Creating ALB..."
cd ../70-ingress-alb && terraform apply -auto-approve

echo "Creating EKS..."
cd ../80-eks && terraform apply -auto-approve

echo "Infrastructure created successfully."