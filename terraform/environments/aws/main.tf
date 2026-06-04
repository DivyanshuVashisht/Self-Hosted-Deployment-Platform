terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t3.small"
}

variable "ssh_public_key" {
  description = "Paste your SSH public key here to add it to the EC2 instance"
  type        = string
  default     = "" # If empty, var.key_name must refer to an existing key in AWS
}

variable "key_name" {
  description = "Name of the SSH key to use in AWS"
  type        = string
  default     = "self-hosted-platform-key"
}

module "k3s_infrastructure" {
  source         = "../../modules/aws_k3s"
  aws_region     = var.aws_region
  environment    = var.environment
  instance_type  = var.instance_type
  key_name       = var.key_name
  ssh_public_key = var.ssh_public_key
}

output "k3s_public_ip" {
  description = "Elastic IP of the K3s server"
  value       = module.k3s_infrastructure.k3s_public_ip
}

output "ssh_instruction" {
  description = "How to SSH into the K3s server"
  value       = module.k3s_infrastructure.ssh_instruction
}

output "kubeconfig_instruction" {
  description = "How to download the Kubeconfig file"
  value       = module.k3s_infrastructure.kubeconfig_instruction
}
