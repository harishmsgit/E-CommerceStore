# Deployment Guide

This document contains the container deployment steps for the e-commerce microservices app.

## Services and Ports

- user-service -> 3001
- product-service -> 3002
- cart-service -> 3003
- order-service -> 3004
- frontend (nginx) -> 80

## Prerequisites

- Docker Desktop installed and running
- Docker Hub account
- Internet access for image push

## 1. Build Docker Images

Run from repository root:

```bash
docker build -t ecommerce-user-service:latest ./backend/user-service
docker build -t ecommerce-product-service:latest ./backend/product-service
docker build -t ecommerce-cart-service:latest ./backend/cart-service
docker build -t ecommerce-order-service:latest ./backend/order-service
docker build -t ecommerce-frontend:latest ./frontend
```

## 2. Run and Test Locally

```bash
docker run -d --name user-service -p 3001:3001 ecommerce-user-service:latest
docker run -d --name product-service -p 3002:3002 ecommerce-product-service:latest
docker run -d --name cart-service -p 3003:3003 ecommerce-cart-service:latest
docker run -d --name order-service -p 3004:3004 ecommerce-order-service:latest
docker run -d --name frontend -p 80:80 ecommerce-frontend:latest
```

Verify backend sample responses:

```bash
curl http://localhost:3001/
curl http://localhost:3002/
curl http://localhost:3003/
curl http://localhost:3004/
```

## 3. Tag and Push to Docker Hub

Replace YOUR_DOCKERHUB_USERNAME before running:

```bash
docker tag ecommerce-user-service:latest harsen/ecommerce-user-service:latest
docker tag ecommerce-product-service:latest harsen/ecommerce-product-service:latest
docker tag ecommerce-cart-service:latest harsen/ecommerce-cart-service:latest
docker tag ecommerce-order-service:latest harsen/ecommerce-order-service:latest
docker tag ecommerce-frontend:latest harsen/ecommerce-frontend:latest

docker login
docker push harsen/ecommerce-user-service:latest
docker push harsen/ecommerce-product-service:latest
docker push harsen/ecommerce-cart-service:latest
docker push harsen/ecommerce-order-service:latest
docker push harsen/ecommerce-frontend:latest
```

## 4. Cleanup Local Containers (Optional)

```bash
docker stop user-service product-service cart-service order-service frontend
docker rm user-service product-service cart-service order-service frontend
```

## 5. Deploy to Existing EC2 with Terraform

Terraform files are already created under `terraform/` in this repository.

Edit only `terraform/terraform.tfvars` with your real key path:

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
ssh_private_key_path = "/mnt/c/path/to/your-key.pem"
open_frontend_port   = false
```

Run from WSL or Linux shell:

```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
terraform output frontend_url
terraform output service_urls
```

## 6. Verify Deployment on EC2

```bash
ssh -i /path/to/key.pem ec2-user@<EC2_PUBLIC_IP>
docker ps
curl http://localhost:3001/
curl http://localhost:3002/
curl http://localhost:3003/
curl http://localhost:3004/
curl http://localhost/
```
