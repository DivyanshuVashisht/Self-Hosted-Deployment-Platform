variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 Instance type for running K3s"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Name of the SSH key pair. If ssh_public_key is empty, this key pair must already exist in AWS."
  type        = string
  default     = "self-hosted-platform-key"
}

variable "ssh_public_key" {
  description = "Raw public key content for SSH access. If provided, a new AWS key pair will be created."
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}
