#VPC
provider "aws" {
  region = "us-east-1" 
  
}

# resource "aws_vpc" "main_vpc" {
#   cidr_block = "10.0.0.0/16"
# }

# # Internet Gateway
# resource "aws_internet_gateway" "igw" {
#   vpc_id = aws_vpc.main_vpc.id
# }

# # Subnet
# resource "aws_subnet" "main_subnet" {
#   vpc_id     = aws_vpc.main_vpc.id
#   cidr_block = "10.0.1.0/24"
# }

# # Route Table
# resource "aws_route_table" "public_rt" {
#   vpc_id = aws_vpc.main_vpc.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.igw.id
#   }
# }

# # Associate Route Table with Subnet
# resource "aws_route_table_association" "public_rt_assoc" {
#   subnet_id      = aws_subnet.main_subnet.id
#   route_table_id = aws_route_table.public_rt.id
# }

# Security Group
resource "aws_security_group" "instance_sg" {
  # vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22000
    to_port     = 22000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1     
    to_port     = -1     
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Create database Master
resource "aws_instance" "dbMaster" {
  ami           = "ami-04505e74c0741db8d"  # Ubuntu 22.04 AMI for us-east-1
  instance_type = "t2.micro"
  # subnet_id     = aws_subnet.main_subnet.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  key_name      = "Adsiser"


  associate_public_ip_address = true

  tags = {
    Name = "P-Database-Master"
  }
  
  provisioner "file" {
      source      = "/home/ubuntu/Adsiser.pem" # File lokal Anda
      destination = "/home/ubuntu/Adsiser.pem" # Lokasi di instance EC2
  }

  connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("/home/ubuntu/Adsiser.pem") 
      host        = self.public_ip
  }

}

resource "null_resource" "inventory_dbMaster" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "[dbMaster]" >> ../ansible/inventory.txt
      echo "dbMaster ansible_host=${aws_instance.dbMaster.public_ip} ansible_ssh_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/Adsiser.pem private_ip=${aws_instance.dbMaster.private_ip}" >> ../ansible/inventory.txt
    EOT
  }
}

# Create Database Slave
resource "aws_instance" "dbSlave" {
  ami           = "ami-04505e74c0741db8d"  # Ubuntu 22.04 AMI for us-east-1
  instance_type = "t2.micro"
  count         = 2
  # subnet_id     = aws_subnet.main_subnet.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  key_name      = "Adsiser"


  associate_public_ip_address = true

  tags = {
    Name = "P-Database-Slave-${count.index+1}"
  }
  
}

resource "null_resource" "inventory_dbSlave" { 
  provisioner "local-exec" {
    command = <<EOT
    echo "[dbSlave]" >> ../ansible/inventory.txt
    x=0
    %{ for instance in aws_instance.dbSlave }
    x=$((x + 1))
    echo "dbSlave$x ansible_host=${instance.public_ip} ansible_ssh_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/Adsiser.pem private_ip=${instance.private_ip}" >> ../ansible/inventory.txt
    %{ endfor }
    EOT
  }

}

# Create an EC2 instance
resource "aws_instance" "phpMyAdmin" {
  ami           = "ami-04505e74c0741db8d"  # Ubuntu 22.04 AMI for us-east-1
  instance_type = "t2.micro"
  # subnet_id     = aws_subnet.main_subnet.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  key_name      = "Adsiser"


  associate_public_ip_address = true

  tags = {
    Name = "P-PhpMyAdmin"
  }
  
}

# Save inventory with Elastic IP
resource "null_resource" "inventory_phpMyAdmin" {
  provisioner "local-exec" {
    command = <<EOT
    echo "[phpMyAdmin]" >> ../ansible/inventory.txt
    echo "phpMyAdmin ansible_host=${aws_instance.phpMyAdmin.public_ip} ansible_ssh_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/Adsiser.pem private_ip=${aws_instance.phpMyAdmin.private_ip}" >> ../ansible/inventory.txt
    EOT
  }

}

output "instance_public_ip" {
  value = aws_instance.phpMyAdmin.public_ip
}