####################
#      Network
####################

# Main VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "vpc-${var.name_prefix}"
  }
}

# Two Subnets in different AZ - Public IP on launch
resource "aws_subnet" "public" {
  count = length(var.subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = var.az[count.index]

  tags = {
    Name = "subnet-${var.name_prefix}-${count.index}"
  }
}


####################
#     Security
####################

# SG - EC2 SSH And Database connection
resource "aws_security_group" "ec2_sg" {
  name        = var.ec2_name
  description = "Allows SSH and outbound connection"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress - Internet
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "EC2-SG-${var.name_prefix}"
  }
}

####################
#  Virtual-Machine
####################

# Setting AWS Datasource - AMI (Latest Ubuntu Image)
data "aws_ami" "server_ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"] # Pulls the most recent AMI - set by *
  }
}

# EC2 Instance within 2 AZ's
resource "aws_instance" "ec2" {
  count = length(var.subnet_cidrs)

  instance_type          = "t2.micro"
  ami                    = data.aws_ami.server_ami.id
  key_name               = aws_key_pair.auth.id
  subnet_id              = aws_subnet.public[count.index].id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data              = <<EOF
  #! /bin/bash
  sudo apt-get update
  sudo apt-get install -y apache2
  sudo systemctl start apache2
  sudo systemctl enable apache2
  echo "The page was created by the user data" | sudo tee /var/www/html/index.html
  EOF

  tags = {
    Name = "ubuntu-${var.name_prefix}-${count.index}"
  }
}

# VM Key pair
resource "aws_key_pair" "auth" {
  key_name   = var.key_pair_name
  public_key = file("~/.ssh/${var.ssh_file_name}.pub")
}