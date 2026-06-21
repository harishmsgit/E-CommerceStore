variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "deployment_mode" {
  description = "Deployment mode: existing (use given ids) or provision (create new infra)"
  type        = string
  default     = "existing"

  validation {
    condition     = contains(["existing", "provision"], var.deployment_mode)
    error_message = "deployment_mode must be either existing or provision."
  }
}

variable "account_id" {
  description = "Expected AWS account id for safety check"
  type        = string
  default     = "495013583028"
}

variable "instance_id" {
  description = "Existing EC2 instance id where containers will be deployed"
  type        = string
  default     = "i-0523c91cfc25de02b"
}

variable "vpc_id" {
  description = "Existing VPC id"
  type        = string
  default     = "vpc-0714e469a68ae1721"
}

variable "subnet_id" {
  description = "Existing public subnet id"
  type        = string
  default     = "subnet-00bf4ffcdb135dfba"
}

variable "security_group_id" {
  description = "Existing security group id attached to EC2"
  type        = string
  default     = "sg-0fe408481fc8b427d"
}

variable "instance_type" {
  description = "EC2 instance type used in provision mode"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "EC2 key pair name used only in provision mode"
  type        = string
  default     = ""
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR used in provision mode"
  type        = string
  default     = "10.10.1.0/24"
}

variable "vpc_cidr" {
  description = "VPC CIDR used in provision mode"
  type        = string
  default     = "10.10.0.0/16"
}

variable "dockerhub_username" {
  description = "DockerHub namespace that stores all images"
  type        = string
  default     = "harsen"
}

variable "image_tag" {
  description = "Tag used for all images"
  type        = string
  default     = "latest"
}

variable "ssh_user" {
  description = "SSH username for EC2"
  type        = string
  default     = "ec2-user"
}

variable "ssh_private_key_path" {
  description = "Absolute path to SSH private key (.pem) for EC2 access"
  type        = string

  validation {
    condition     = can(file(var.ssh_private_key_path))
    error_message = "ssh_private_key_path must point to an existing readable private key file on the machine running Terraform."
  }
}

variable "open_frontend_port" {
  description = "If true, add inbound 80 rule from 0.0.0.0/0 on the SG"
  type        = bool
  default     = false
}

variable "open_ssh_port" {
  description = "If true in existing mode, add inbound 22 rule for Terraform remote-exec"
  type        = bool
  default     = true
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH into the EC2 instance"
  type        = string
  default     = "0.0.0.0/0"
}

variable "open_service_ports" {
  description = "If true in existing mode, add public ingress for backend service ports 3001-3004"
  type        = bool
  default     = false
}

variable "service_ports_allowed_cidr" {
  description = "CIDR allowed to access backend service ports 3001-3004"
  type        = string
  default     = "0.0.0.0/0"
}
