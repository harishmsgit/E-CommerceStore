data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_vpc" "selected" {
  count = var.deployment_mode == "existing" ? 1 : 0
  id    = var.vpc_id
}

data "aws_subnet" "selected" {
  count = var.deployment_mode == "existing" ? 1 : 0
  id    = var.subnet_id
}

data "aws_instance" "target" {
  count       = var.deployment_mode == "existing" ? 1 : 0
  instance_id = var.instance_id
}

resource "aws_vpc" "app" {
  count                = var.deployment_mode == "provision" ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = "ecommerce-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  count  = var.deployment_mode == "provision" ? 1 : 0
  vpc_id = aws_vpc.app[0].id

  tags = {
    Name = "ecommerce-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = var.deployment_mode == "provision" ? 1 : 0
  vpc_id                  = aws_vpc.app[0].id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "ecommerce-public-subnet"
  }
}

resource "aws_route_table" "public" {
  count  = var.deployment_mode == "provision" ? 1 : 0
  vpc_id = aws_vpc.app[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[0].id
  }

  tags = {
    Name = "ecommerce-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = var.deployment_mode == "provision" ? 1 : 0
  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_security_group" "app" {
  count       = var.deployment_mode == "provision" ? 1 : 0
  name        = "ecommerce-sg"
  description = "Allow SSH, frontend HTTP and service ports"
  vpc_id      = aws_vpc.app[0].id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 3001
    to_port   = 3004
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecommerce-sg"
  }
}

resource "aws_instance" "app_server" {
  count                  = var.deployment_mode == "provision" ? 1 : 0
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.app[0].id]

  tags = {
    Name = "ecommerce-ec2"
  }

  lifecycle {
    precondition {
      condition     = length(var.key_name) > 0
      error_message = "key_name is required in provision mode."
    }
  }
}

resource "aws_security_group_rule" "services_internal_existing" {
  count             = var.deployment_mode == "existing" ? 1 : 0
  type              = "ingress"
  from_port         = 3001
  to_port           = 3004
  protocol          = "tcp"
  security_group_id = var.security_group_id
  self              = true

  description = "Allow internal service communication on 3001-3004"
}

resource "aws_security_group_rule" "ssh_existing" {
  count             = var.deployment_mode == "existing" && var.open_ssh_port ? 1 : 0
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = var.security_group_id
  cidr_blocks       = [var.ssh_allowed_cidr]

  description = "Allow SSH access for Terraform remote-exec"
}

resource "aws_security_group_rule" "frontend_http_existing" {
  count             = var.deployment_mode == "existing" && var.open_frontend_port ? 1 : 0
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = var.security_group_id
  cidr_blocks       = ["0.0.0.0/0"]

  description = "Allow public HTTP access to frontend"
}

resource "aws_security_group_rule" "services_public_existing" {
  count             = var.deployment_mode == "existing" && var.open_service_ports ? 1 : 0
  type              = "ingress"
  from_port         = 3001
  to_port           = 3004
  protocol          = "tcp"
  security_group_id = var.security_group_id
  cidr_blocks       = [var.service_ports_allowed_cidr]

  description = "Allow public access to backend service ports"
}

locals {
  target_instance_id = var.deployment_mode == "existing" ? data.aws_instance.target[0].id : aws_instance.app_server[0].id
  target_public_ip   = var.deployment_mode == "existing" ? data.aws_instance.target[0].public_ip : aws_instance.app_server[0].public_ip
}

resource "null_resource" "deploy_containers" {
  triggers = {
    deployment_mode    = var.deployment_mode
    instance_id        = local.target_instance_id
    dockerhub_username = var.dockerhub_username
    image_tag          = var.image_tag
  }

  connection {
    type        = "ssh"
    host        = local.target_public_ip
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "if command -v dnf >/dev/null 2>&1; then sudo dnf update -y && sudo dnf install -y docker; elif command -v apt-get >/dev/null 2>&1; then sudo apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io; else echo 'No supported package manager found. Expected dnf or apt-get.' >&2; exit 1; fi",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo usermod -aG docker ${var.ssh_user}",
      "sudo docker network create ecommerce-net || true",
      "sudo docker rm -f frontend order-service cart-service product-service user-service mongo || true",
      "sudo docker pull mongo:7",
      "sudo docker pull ${var.dockerhub_username}/ecommerce-user-service:${var.image_tag}",
      "sudo docker pull ${var.dockerhub_username}/ecommerce-product-service:${var.image_tag}",
      "sudo docker pull ${var.dockerhub_username}/ecommerce-cart-service:${var.image_tag}",
      "sudo docker pull ${var.dockerhub_username}/ecommerce-order-service:${var.image_tag}",
      "sudo docker pull ${var.dockerhub_username}/ecommerce-frontend:${var.image_tag}",
      "sudo docker run -d --name mongo --network ecommerce-net -p 27017:27017 mongo:7",
      "sudo docker run -d --name user-service --network ecommerce-net -p 3001:3001 -e PORT=3001 -e MONGODB_URI=mongodb://mongo:27017/ecommerce_users ${var.dockerhub_username}/ecommerce-user-service:${var.image_tag}",
      "sudo docker run -d --name product-service --network ecommerce-net -p 3002:3002 -e PORT=3002 -e MONGODB_URI=mongodb://mongo:27017/ecommerce_products ${var.dockerhub_username}/ecommerce-product-service:${var.image_tag}",
      "sudo docker run -d --name cart-service --network ecommerce-net -p 3003:3003 -e PORT=3003 -e MONGODB_URI=mongodb://mongo:27017/ecommerce_carts -e PRODUCT_SERVICE_URL=http://product-service:3002 ${var.dockerhub_username}/ecommerce-cart-service:${var.image_tag}",
      "sudo docker run -d --name order-service --network ecommerce-net -p 3004:3004 -e PORT=3004 -e MONGODB_URI=mongodb://mongo:27017/ecommerce_orders -e CART_SERVICE_URL=http://cart-service:3003 -e PRODUCT_SERVICE_URL=http://product-service:3002 -e USER_SERVICE_URL=http://user-service:3001 ${var.dockerhub_username}/ecommerce-order-service:${var.image_tag}",
      "sudo docker run -d --name frontend --network ecommerce-net -p 80:80 ${var.dockerhub_username}/ecommerce-frontend:${var.image_tag}",
      "sudo docker ps"
    ]
  }

  depends_on = [
    aws_security_group_rule.services_internal_existing,
    aws_security_group_rule.ssh_existing,
    aws_security_group_rule.frontend_http_existing,
    aws_security_group_rule.services_public_existing,
    aws_instance.app_server,
    aws_route_table_association.public
  ]

  lifecycle {
    precondition {
      condition     = data.aws_caller_identity.current.account_id == var.account_id
      error_message = "AWS account id mismatch. Update var.account_id or your active credentials."
    }
  }
}
