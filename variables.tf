variable "aws_region" {
  description = "The AWS region to create resources in"
  type        = string
  default     = "us-east-1"
}

variable "aws_region_az" {
  description = "An Availability Zone in the specified region"
  type        = string
  default     = "us-east-1a"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "192.168.0.0/24"
}

variable "public_subnet_cidr" {
  description = "The CIDR block for the public subnet"
  type        = string
  default     = "192.168.0.0/25"
}

variable "private_subnet_cidr" {
  description = "The CIDR block for the private subnet"
  type        = string
  default     = "192.168.0.128/25"
}

variable "key_pair_name" {
  description = "The name of an existing EC2 Key Pair to allow SSH access to the instance"
  type        = string
}

variable "pfsense_ami_id" {
  description = "The AMI ID for the pfSense EC2 instance"
  type        = string
}
