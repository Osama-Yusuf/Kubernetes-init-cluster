provider "aws" {
  region = var.region
}

resource "aws_vpc" "custom_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "CustomVPC"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name = "MainInternetGateway"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route_table_association" "public_route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "my_key" {
  key_name   = var.ssh_key_name
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "local_file" "my_key" {
  content         = tls_private_key.rsa.private_key_pem
  filename        = var.ssh_key_name
  file_permission = "0400"
}

resource "aws_security_group" "public_sg" {
  name        = "public_sg"
  description = "Security group for public access"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PublicSecurityGroup"
  }
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  for_each = toset(["master", "worker1", "worker2"])

  name = "k8s-${each.key}"

  ami                    = var.ubuntu_ami
  instance_type          = "t2.xlarge"
  key_name               = aws_key_pair.my_key.key_name
  monitoring             = true
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  subnet_id              = aws_subnet.public_subnet.id

  root_block_device = [
    {
      volume_size = 20
    }
  ]
  user_data = file("../nodes_config/k8s_init.sh") # Use the user data script from userdata.sh

  ebs_block_device = [
    {
      device_name           = "/dev/xvda"
      volume_type           = "gp2"
      volume_size           = 20
      delete_on_termination = true
      snapshot_on_create    = true
    }
  ]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
