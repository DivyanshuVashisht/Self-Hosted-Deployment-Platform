provider "aws" {
  region = var.aws_region
}

# Fetch the latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC setup
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "self-hosted-vpc-${var.environment}"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "self-hosted-igw-${var.environment}"
    Environment = var.environment
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "self-hosted-public-subnet-${var.environment}"
    Environment = var.environment
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name        = "self-hosted-public-rt-${var.environment}"
    Environment = var.environment
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "k3s" {
  name        = "self-hosted-k3s-sg-${var.environment}"
  description = "Allow K3s and SSH traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Hardened setups would restrict to admin IP
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Hardened setups would restrict to admin IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "self-hosted-k3s-sg-${var.environment}"
    Environment = var.environment
  }
}

# Pre-allocated Elastic IP to bind static IP to cluster
resource "aws_eip" "k3s" {
  domain = "vpc"

  tags = {
    Name        = "self-hosted-k3s-eip-${var.environment}"
    Environment = var.environment
  }
}

# Key Pair (optional)
resource "aws_key_pair" "ssh" {
  count      = var.ssh_public_key != "" ? 1 : 0
  key_name   = var.key_name
  public_key = var.ssh_public_key
}

# EC2 Instance
resource "aws_instance" "k3s" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.k3s.id]
  key_name               = var.ssh_public_key != "" ? aws_key_pair.ssh[0].key_name : var.key_name

  # Pass Elastic IP in User Data template to avoid boot cycle
  user_data = templatefile("${path.module}/templates/k3s_install.sh", {
    public_ip = aws_eip.k3s.public_ip
  })

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name        = "self-hosted-k3s-instance-${var.environment}"
    Environment = var.environment
  }
}

# Associate EIP with EC2 instance
resource "aws_eip_association" "k3s_assoc" {
  instance_id   = aws_instance.k3s.id
  allocation_id = aws_eip.k3s.id
}
