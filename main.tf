terraform {
  required_providers {
    aws ={
        source = "hashicorp/aws"
    }
  }
  backend "s3" {  // make the terraform state saved at aws s3 bucket for secure
    bucket = "my-terraform-state-bucket-koneckta"
    key = "Task5/terraform.tfstate"
    region = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt = true
    
  }
  }
  provider "aws" {       #The provider
    region = var.region  
  }
  resource "aws_vpc" "main" { #creating the vpc
  cidr_block = "10.0.0.0/16"
   tags = {
    Name = "main"
  }
}
resource "aws_internet_gateway" "gw" { #creating the internet gateway and add it to vpc
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}
resource "aws_subnet" "subnet" {  #creating first subnet and add it to the vpc
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "subnet-1"
  }
}
resource "aws_subnet" "subnet2" { #creating second subnet and add it to the vpc
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "subnet-2"
  }
}
resource "aws_subnet" "subnet3" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.3.0/24"
     map_public_ip_on_launch = true  # ensures all instances get a public ip
    tags = {
      Name = "subnet-3"
    }
}
resource "aws_eip" "nat" {  #Elastic ip for NAT Gateway
  domain = "vpc"
}
resource "aws_nat_gateway" "nat" { #creating nat gateway and add it to the first subnet
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.subnet.id

  tags = {
    Name = "main-nat"
  }
    lifecycle {
    prevent_destroy = true
  }
  depends_on = [aws_internet_gateway.gw]
}
resource "aws_route_table" "public_rt" { #creating puplic route table and add it to vpc
    vpc_id = aws_vpc.main.id
    route {
    cidr_block = "0.0.0.0/0"   
    gateway_id = aws_internet_gateway.gw.id
  }
    tags = {
    Name = "public-route-table"
  }
  
}

resource "aws_route_table_association" "public_assoc" {   # associate public Subnet with public route table
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc2" {   # associate public Subnet3 with public route table
  subnet_id      = aws_subnet.subnet3.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table" "private_rt" { #creating private route table and add it to vpc
    vpc_id = aws_vpc.main.id
    route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
    tags = {
    Name = "private-route-table"
  }
  
}
resource "aws_route_table_association" "private_assoc" {  # associate private Subnet with private route table
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_security_group" "security_group" {   #create security group to allow http and ssh 
    vpc_id = aws_vpc.main.id
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "my security group"
    }
}
resource "aws_key_pair" "my_key" {   #creating aws key pair 
  key_name   = "my-key"  
  public_key = file(var.public_key_path) 
}
resource "aws_instance" "private"{ #creating my instance
    ami = var.ami_id
    instance_type= var.instance_type
    subnet_id= aws_subnet.subnet2.id
    key_name= var.key_name
    tags = {
      Name = "private instance"
    }
}
resource "aws_instance" "public" { #creating nginx instance
    ami = var.ami_id
    instance_type = var.instance_type
    subnet_id = aws_subnet.subnet3.id
    key_name = var.key_name
    vpc_security_group_ids = [aws_security_group.security_group.id]
    associate_public_ip_address = true
    user_data =  <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install nginx -y
              sudo systemctl enable nginx
              sudo systemctl start nginx
              EOF  
    tags = {
      Name = "public instance"
    }
  
}
resource "aws_s3_bucket" "terraform_state" {  #create an s3 bucket to save the state file on it
  bucket = "my-terraform-state-bucket-koneckta"
  lifecycle {
    prevent_destroy = true
  }
}
resource "aws_s3_bucket_versioning" "versioning" { #ensure that every change is stored as a new verison
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_public_access_block" "public_access" { #make it private and secure
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_dynamodb_table" "terraform_locks" { # create dynamodb table to enable state locking
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}