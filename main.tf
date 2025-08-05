# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# --- VPC and Networking Resources ---

# 1. Create a VPC
resource "aws_vpc" "security_project_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "Security-Project-VPC"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.security_project_vpc.id
  tags = {
    Name = "Security-Project-IGW"
  }
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id              = aws_vpc.security_project_vpc.id
  cidr_block          = var.public_subnet_cidr
  availability_zone   = var.aws_region_az
  map_public_ip_on_launch = true
  tags = {
    Name = "Security-Project-Public-Subnet"
  }
}

# Create a private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.security_project_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.aws_region_az
  tags = {
    Name = "Security-Project-Private-Subnet"
  }
}

# Create an Elastic IP for the NAT Gateway
resource "aws_eip" "nat_gateway_eip" {
  tags = {
    Name = "nat_gateway_eip"
  }
}

# Create a NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags = {
    Name = "Security-Project-NAT-Gateway"
  }
}

# Create a route table for the public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.security_project_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "Security-Project-Public-RT"
  }
}

# Associate the public route table with the public subnet
resource "aws_route_table_association" "public_rt_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Create a route table for the private subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.security_project_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name = "Security-Project-Private-RT"
  }
}

# Associate the private route table with the private subnet
resource "aws_route_table_association" "private_rt_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# Security group for the EC2 instance
resource "aws_security_group" "ec2_sg" {
  name        = "security-project-ec2-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.security_project_vpc.id
  
  # Allow SSH from any IP (for testing)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instance for the Web Server
resource "aws_instance" "web_server_instance" {
  ami           = "ami-0557a3743cba600c0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  tags = {
    Name = "Web-Server-Instance"
  }
}

# EC2 instance for the User
resource "aws_instance" "user_instance" {
  ami           = "ami-0557a3743cba600c0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  tags = {
    Name = "User-Instance"
  }
}

# EC2 instance for the Attacker
resource "aws_instance" "attacker_instance" {
  ami           = "ami-0557a3743cba600c0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  tags = {
    Name = "Attacker-Instance"
  }
}

# --- VPC Flow Logs Resources to CloudWatch Logs ---

# Data source to reference the existing IAM Role
data "aws_iam_role" "existing_flow_log_role" {
  name = "VPCFlowLogRole"
}

# Data source to retrieve the existing CloudWatch Log Group
data "aws_cloudwatch_log_group" "existing_log_group" {
  name = "security-project-flow-logs"
}

# Create a VPC Flow Log to publish to CloudWatch
resource "aws_flow_log" "security_project_flow_log" {
  iam_role_arn         = data.aws_iam_role.existing_flow_log_role.arn
  log_destination_type = "cloud-watch-logs"
  log_destination      = data.aws_cloudwatch_log_group.existing_log_group.arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.security_project_vpc.id
}
