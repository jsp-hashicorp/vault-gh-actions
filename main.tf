terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "=3.42.0"
    }
  }
}

provider "aws" {
  region  = var.region
}


resource "aws_vpc" "snapshot" {
  cidr_block           = var.address_space
  enable_dns_hostnames = true

  tags = {
    name = "${var.prefix}-vpc-${var.region}"
    environment = "snapshot"
  }
}

resource "aws_subnet" "snapshot" {
  vpc_id     = aws_vpc.snapshot.id
  cidr_block = var.subnet_prefix

  tags = {
    name = "${var.prefix}-subnet"
  }
}

resource "aws_security_group" "snapshot" {
  name = "${var.prefix}-sg"

  vpc_id = aws_vpc.snapshot.id

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

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.prefix}-sg"
  }
}

resource "aws_internet_gateway" "snapshot" {
  vpc_id = aws_vpc.snapshot.id

  tags = {
    Name = "${var.prefix}-internet-gateway"
  }
}

resource "aws_route_table" "snapshot" {
  vpc_id = aws_vpc.snapshot.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.snapshot.id
  }
}

resource "aws_route_table_association" "snapshot" {
  subnet_id      = aws_subnet.snapshot.id
  route_table_id = aws_route_table.snapshot.id
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "name"
    #values = ["ubuntu/images/hvm-ssd/ubuntu-disco-19.04-amd64-server-*"]
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_eip" "snapshot" {
  instance = aws_instance.snapshot.id
  vpc      = true
}

resource "aws_eip_association" "snapshot" {
  instance_id   = aws_instance.snapshot.id
  allocation_id = aws_eip.snapshot.id
}

resource "aws_instance" "snapshot" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.snapshot.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.snapshot.id
  vpc_security_group_ids      = [aws_security_group.snapshot.id]

  tags = {
    Name = "${var.prefix}-snapshot-instance"
    Department = "devops"
    Billable = "true"
  }
}

# We're using a little trick here so we can run the provisioner without
# destroying the VM. Do not do this in production.

# If you need ongoing management (Day N) of your virtual machines a tool such
# as Chef or Puppet is a better choice. These tools track the state of
# individual files and can keep them in the correct configuration.

# Here we do the following steps:
# Sync everything in files/ to the remote VM.
# Set up some environment variables for our script.
# Add execute permissions to our scripts.
# Run the deploy_app.sh script.
resource "null_resource" "configure-ss-app" {
  depends_on = [aws_eip_association.snapshot]

  triggers = {
    build_number = timestamp()
  }

  provisioner "file" {
    source      = "files/"
    destination = "/home/ubuntu/"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.snapshot.private_key_pem
      host        = aws_eip.snapshot.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt -y update",
      "sleep 15",
      "sudo apt -y update",
      "sudo apt -y install apache2",
      "sudo systemctl start apache2",
      "sudo chown -R ubuntu:ubuntu /var/www/html",
      "chmod +x *.sh",
      "PLACEHOLDER=${var.placeholder} WIDTH=${var.width} HEIGHT=${var.height} PREFIX=${var.prefix} REGION=${var.region} ./deploy_app.sh",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.snapshot.private_key_pem
      host        = aws_eip.snapshot.public_ip
    }
  }
}

resource "tls_private_key" "snapshot" {
  algorithm = "RSA"
}

locals {
  private_key_filename = "${var.prefix}-ssh-key.pem"
}

resource "aws_key_pair" "snapshot" {
  key_name   = local.private_key_filename
  public_key = tls_private_key.snapshot.public_key_openssh
}
