# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# --- VPC and Networking Resources ---

# 1. Create a VPC
resource "aws_vpc" "security_project_vpc" {
  cidr_block         = var.vpc_cidr
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
  vpc_id            = aws_vpc.security_project_vpc.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = var.aws_region_az
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

# --- Security Groups ---

# Security group for the EC2 instances
resource "aws_security_group" "ec2_sg" {
  name        = "security-project-ec2-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.security_project_vpc.id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Quarantine security group for isolated instances
resource "aws_security_group" "quarantine_sg" {
  name        = "quarantine-sg"
  description = "Quarantine security group with no rules"
  vpc_id      = aws_vpc.security_project_vpc.id
}

# Security group for pfSense (allow WAN/LAN traffic)
resource "aws_security_group" "pfsense_sg" {
  name        = "pfsense-sg"
  description = "Allow WAN/LAN traffic for pfSense"
  vpc_id      = aws_vpc.security_project_vpc.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- EC2 Instances ---

# Web Server
resource "aws_instance" "web_server_instance" {
  ami           = "ami-0779caf41f9ba54f0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  tags = { Name = "Web-Server-Instance" }
}

# Sysloger (old user_instance)
resource "aws_instance" "sysloger_instance" {
  ami           = "ami-0779caf41f9ba54f0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data = <<-EOF
    #!/bin/bash
	sudo apt-get update
	sudo apt-get install -y rsyslog amazon-cloudwatch-agent
    systemctl enable rsyslog
    systemctl start rsyslog
    cat <<CWAGENTCONFIG > /opt/aws/amazon-cloudwatch-agent/bin/config.json
    {
      "agent": {
        "run_as_user": "root"
      },
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/pfsense.log",
                "log_group_class": "STANDARD",
                "log_group_name": "pfsense-firewall-logs",
                "log_stream_name": "{hostname}",
                "retention_in_days": 5
              }
            ]
          }
        }
      }
    }
CWAGENTCONFIG
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
  EOF
  tags = { Name = "Sysloger-Instance" }
}

# Attacker Instance
resource "aws_instance" "attacker_instance" {
  ami           = "ami-0779caf41f9ba54f0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  tags = { Name = "Attacker-Instance" }
}

# pfSense EC2 Instance
resource "aws_instance" "pfsense_instance" {
  ami           = var.pfsense_ami_id
  instance_type = "t3.medium"
  key_name      = var.key_pair_name
  subnet_id     = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.pfsense_sg.id]
  tags = { Name = "pfSense-Instance" }
}

# --- VPC Flow Logs Resources to CloudWatch Logs ---
data "aws_iam_role" "existing_flow_log_role" {
  name = "VPCFlowLogRole"
}

data "aws_cloudwatch_log_group" "existing_log_group" {
  name = "security-project-flow-logs"
}

resource "aws_flow_log" "security_project_flow_log" {
  iam_role_arn         = data.aws_iam_role.existing_flow_log_role.arn
  log_destination_type = "cloud-watch-logs"
  log_destination      = data.aws_cloudwatch_log_group.existing_log_group.arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.security_project_vpc.id
}
