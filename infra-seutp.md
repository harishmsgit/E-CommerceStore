# Infrastructure Setup Guide

This guide keeps only the used deployment path: deploy containers on your existing EC2 using Terraform.

## Prerequisites

- AWS CLI configured with account 495013583028
- Terraform installed and available in PATH
- Docker images available on DockerHub under your namespace
- SSH private key file for EC2 access

## Used Infrastructure

Use this for your provided resources:

- region: ap-south-1
- instance_id: i-0523c91cfc25de02b
- vpc_id: vpc-0714e469a68ae1721
- subnet_id: subnet-00bf4ffcdb135dfba
- security_group_id: sg-0fe408481fc8b427d

Set these in terraform/terraform.tfvars:

```hcl
deployment_mode      = "existing"
aws_region           = "ap-south-1"
account_id           = "495013583028"
instance_id          = "i-0523c91cfc25de02b"
vpc_id               = "vpc-0714e469a68ae1721"
subnet_id            = "subnet-00bf4ffcdb135dfba"
security_group_id    = "sg-0fe408481fc8b427d"
dockerhub_username   = "harsen"
image_tag            = "latest"
ssh_user             = "ec2-user"
ssh_private_key_path = "/home/harish/.ssh/capstone-project-KP-openssh.pem"
open_frontend_port   = false
```

Note: `ssh_private_key_path` must point to the matching private key for instance `i-0523c91cfc25de02b`.

## Apply Terraform

Run from repository root:

```bash
cd terraform
terraform init
terraform fmt
terraform plan
terraform apply -auto-approve
```

## What Terraform Configures

- Security rules for frontend HTTP (80) and service communication (3001-3004)
- Docker installation on EC2
- Container deployment for:
  - user-service (3001)
  - product-service (3002)
  - cart-service (3003)
  - order-service (3004)
  - frontend (80)
  - mongo (27017)

## Verify Deployment

```bash
terraform output frontend_url
terraform output service_urls
```

Then test:

- frontend: http://<PUBLIC_IP>
- user: http://<PUBLIC_IP>:3001
- product: http://<PUBLIC_IP>:3002
- cart: http://<PUBLIC_IP>:3003
- order: http://<PUBLIC_IP>:3004
