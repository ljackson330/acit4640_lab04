# configure version of aws provider plugin
# https://developer.hashicorp.com/terraform/language/terraform#terraform
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-west-2"
}

# https://developer.hashicorp.com/terraform/language/values/locals
locals {
  project_name = "lab_week_4"
}

# get the most recent ami for Ubuntu 24.04 owned by amazon
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# Create a VPC
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
resource "aws_vpc" "web" {
  cidr_block = "10.0.0.0/16"
  # Enable DNS resolution within the VPC
  enable_dns_support = true
  # Allow public DNS hostnames
  enable_dns_hostnames = true

  tags = {
    Name    = "project_vpc"
    Project = local.project_name
  }
}

# Create a public subnet
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
# To use the free tier t2.micro ec2 instance you have to declare an AZ
# Some AZs do not support this instance type
resource "aws_subnet" "web" {
  vpc_id     = aws_vpc.web.id
  cidr_block = "10.0.1.0/24"
  # Define an AZ within the us-west region
  availability_zone = "us-west-2a"
  # Automatically provide public IP addresses to VMs connected to this subnet
  map_public_ip_on_launch = true

  tags = {
    Name    = "Web"
    Project = local.project_name
  }
}

# Create internet gateway for VPC
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
resource "aws_internet_gateway" "web-gw" {
  # Associate with the web vpc
  vpc_id = aws_vpc.web.id

  tags = {
    Name    = "Web"
    Project = local.project_name
  }
}

# create route table for web VPC 
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
resource "aws_route_table" "web" {
  # Associate with the web VPC
  vpc_id = aws_vpc.web.id

  tags = {
    Name    = "web-route"
    Project = local.project_name
  }
}

# add route to to route table
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.web.id
  destination_cidr_block = "0.0.0.0/0"
  # Associate with the web-gw gateway
  gateway_id = aws_internet_gateway.web-gw.id
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
resource "aws_route_table_association" "web" {
  # Associate with the web subnet
  subnet_id      = aws_subnet.web.id
  route_table_id = aws_route_table.web.id
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "web" {
  name        = "allow_ssh"
  description = "allow ssh from home and work"
  # Associate with the web vpc
  vpc_id = aws_vpc.web.id

  tags = {
    Name    = "Web"
    Project = local.project_name
  }
}

# Allow ssh
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule
resource "aws_vpc_security_group_ingress_rule" "web-ssh" {
  security_group_id = aws_security_group.web.id
  # Allow inbound TCP traffic over port 22 from anywhere
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
}

# allow http
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule
resource "aws_vpc_security_group_ingress_rule" "web-http" {
  security_group_id = aws_security_group.web.id
  # Allow inbound HTTP traffic over port 80 from anywhere
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

# allow all out
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule
resource "aws_vpc_security_group_egress_rule" "web-egress" {
  security_group_id = aws_security_group.web.id
  # Allow outbound traffic to any destination over any port/protocol
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# use an existing key pair on host machine with file func
# if we weren't adding the public key in the cloud-init script we could import a public 
# using the aws_key_pair resource block
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair
# resource "aws_key_pair" "local_key" {
#   key_name   = "web-key"
#   public_key = file("~/.ssh/aws.pub")
# }

# create the ec2 instance
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
resource "aws_instance" "web" {
  # Use the AMI defined in the data block
  ami = data.aws_ami.ubuntu.id
  # Assign instance type t2.micro
  instance_type = "t2.micro"
  # Pull user data from scripts/cloud-config.yaml 
  user_data = file("scripts/cloud-config.yaml")
  # Assign the web security group to this VM
  vpc_security_group_ids = [aws_security_group.web.id]
  # Connect it to the web subnet
  subnet_id = aws_subnet.web.id

  tags = {
    Name    = "Web"
    Project = local.project_name
  }
}

# print public ip and dns to terminal
# https://developer.hashicorp.com/terraform/language/values/outputs
output "instance_ip_addr" {
  description = "The public IP and dns of the web ec2 instance."
  value = {
    "public_ip" = aws_instance.web.public_ip
    "dns_name"  = aws_instance.web.public_dns
  }
}
