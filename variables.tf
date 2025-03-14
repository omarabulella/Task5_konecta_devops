variable "region" {
  description = "AWS region"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "Instance type for EC2"
  type        = string
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "public_key_path" {
  description = "Path to the public SSH key"
  type        = string
}